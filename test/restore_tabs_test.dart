import 'dart:io';

import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/models/serial_settings.dart';
import 'package:daylight_terminal/models/ssh_profile.dart';
import 'package:daylight_terminal/services/local_shell_finder.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/services/tab_store.dart';
import 'package:daylight_terminal/settings/restore_prefs.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/serial_session.dart';
import 'package:daylight_terminal/state/sessions_controller.dart';
import 'package:daylight_terminal/state/ssh_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/fake_pty.dart';
import 'helpers/fake_serial.dart';

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);

class _FixedFinder extends LocalShellFinder {
  _FixedFinder(this.shells);
  final List<LocalShell> shells;
  @override
  Future<List<LocalShell>> find() async => shells;
}

const _profile = SshProfile(
  id: 'p1',
  host: 'web-01.example.com',
  port: 2222,
  username: 'deploy',
  keyPath: '/keys/id_ed25519',
  name: 'web-01',
  group: 'Production',
);

void main() {
  late Directory tmp;
  late FakePtyFactory ptys;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dt_restore_');
    ptys = FakePtyFactory();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// 앱을 한 번 켠 것: 저장소와 설정을 새로 읽고 컨트롤러를 만들어 복원한다.
  Future<SessionsController> launch({List<LocalShell> shells = const [_bash], FakeSerialService? serial}) async {
    final c = SessionsController(
      await ProfileStore.load(),
      shellFinder: _FixedFinder(shells),
      ptyFactory: ptys.call,
      serialFactory: serial == null ? null : () => serial,
      tabStore: await TabStore.load(),
      restorePrefs: await RestorePrefs.load(),
    );
    await c.loadShells();
    await c.restoreTabs();
    return c;
  }

  Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('local shell, SSH and serial tabs come back in order, with the last tab selected as before', () async {
    final first = await launch(serial: FakeSerialService());
    first.addLocal(_bash);
    await first.current!.disconnect(); // 셸이 끝나 있어도 탭은 기억한다
    final local = first.current! as LocalShellSession;
    await local.loadFolder(tmp.path);

    first.add();
    (first.current! as SshSessionProvider).prefill(_profile);
    first.addSerial();
    final serial = first.current! as SerialSession;
    serial.setPendingPort('/dev/ttyUSB0');
    serial.setPendingBaud(9600);
    serial.setPendingParity(SerialParity.even);
    first.select(2); // SSH 탭을 보고 있었다 (0번은 처음의 빈 탭이라 저장에서 빠진다)
    await first.prepareForExit();

    final second = await launch(serial: FakeSerialService());
    expect(second.sessions.map((s) => s.runtimeType), [LocalShellSession, SshSessionProvider, SerialSession]);
    expect(second.selected, 1);

    final restoredLocal = second.sessions[0] as LocalShellSession;
    expect(restoredLocal.shell.id, 'bash');
    expect(restoredLocal.folderPath, tmp.absolute.path);
    expect(ptys.made.length, greaterThanOrEqualTo(2), reason: '로컬 셸은 바로 다시 띄운다');

    final ssh = second.sessions[1] as SshSessionProvider;
    expect(ssh.connected, isFalse, reason: '비밀번호가 없으니 자동으로 접속하지 않는다');
    expect(ssh.profile?.host, 'web-01.example.com');
    expect(ssh.profile?.port, 2222);
    expect(ssh.profile?.username, 'deploy');
    expect(ssh.profile?.keyPath, '/keys/id_ed25519');
    expect(ssh.profile?.name, 'web-01');

    final restoredSerial = second.sessions[2] as SerialSession;
    expect(restoredSerial.connected, isFalse, reason: '장치를 자동으로 열지 않는다');
    expect(restoredSerial.pendingPort, '/dev/ttyUSB0');
    expect(restoredSerial.pendingBaud, 9600);
    expect(restoredSerial.pendingParity, SerialParity.even);
    first.dispose();
    second.dispose();
  });

  test('nothing secret is written: only connection details', () async {
    final first = await launch();
    first.add();
    (first.current! as SshSessionProvider).prefill(_profile);
    first.addLocal(_bash);
    await first.prepareForExit();
    final raw = (await SharedPreferences.getInstance()).getString('open_tabs')!;
    expect(raw.toLowerCase(), isNot(contains('password')));
    expect(raw.toLowerCase(), isNot(contains('passphrase')));
    first.dispose();
  });

  test('a blank SSH tab is not remembered, so a fresh start stays a single blank tab', () async {
    final first = await launch();
    first.add();
    await first.prepareForExit();
    first.dispose();
    final second = await launch();
    expect(second.sessions.length, 1);
    expect((second.current! as SshSessionProvider).profile, isNull);
    second.dispose();
  });

  test('a shell that no longer exists is skipped; a vanished folder falls back to home', () async {
    SharedPreferences.setMockInitialValues({
      'open_tabs': SavedTabs([
        const SavedLocalTab('fish', '/'),
        SavedLocalTab('bash', '${tmp.path}/gone'),
      ], 0).encode(),
    });
    final c = await launch();
    expect(c.sessions.length, 1);
    final s = c.current! as LocalShellSession;
    expect(s.shell.id, 'bash');
    expect(s.folderPath, LocalShellSession.homeDirectory());
    c.dispose();
  });

  test('turning the setting off stops remembering and forgets the old tabs', () async {
    final first = await launch();
    first.addLocal(_bash);
    await first.prepareForExit();
    expect((await SharedPreferences.getInstance()).getString('open_tabs'), isNotNull);

    await first.restorePrefs!.setEnabled(false);
    await pump();
    expect((await SharedPreferences.getInstance()).getString('open_tabs'), isNull);
    first.dispose();

    final second = await launch();
    expect(second.sessions.length, 1, reason: '꺼 두면 지난번 탭을 열지 않는다');
    second.dispose();
  });

  test('on by default', () async {
    expect((await RestorePrefs.load()).enabled, isTrue);
  });

  test('a tab the user already used is never replaced by the restore', () async {
    final first = await launch();
    first.addLocal(_bash);
    await first.prepareForExit();
    first.dispose();

    SharedPreferences.setMockInitialValues({
      'open_tabs': SavedTabs([const SavedLocalTab('bash', '/')], 0).encode(),
    });
    final c = SessionsController(
      await ProfileStore.load(),
      shellFinder: _FixedFinder(const [_bash]),
      ptyFactory: ptys.call,
      tabStore: await TabStore.load(),
      restorePrefs: await RestorePrefs.load(),
    );
    await c.loadShells();
    (c.current! as SshSessionProvider).prefill(_profile); // 접속 화면을 이미 만졌다
    await c.restoreTabs();
    expect(c.sessions.length, 1);
    expect(c.current, isA<SshSessionProvider>());
    c.dispose();
  });

  test('before the restore finishes, the blank first tab does not overwrite the saved tabs', () async {
    final saved = SavedTabs([const SavedLocalTab('bash', '/')], 0).encode();
    SharedPreferences.setMockInitialValues({'open_tabs': saved});
    final c = SessionsController(
      await ProfileStore.load(),
      shellFinder: _FixedFinder(const [_bash]),
      ptyFactory: ptys.call,
      tabStore: await TabStore.load(),
      restorePrefs: await RestorePrefs.load(),
    );
    c.add(); // 복원 전에 탭이 바뀌어도
    await pump();
    expect((await SharedPreferences.getInstance()).getString('open_tabs'), saved);
    c.dispose();
  });

  test('broken or unknown saved data never stops the app from starting', () async {
    for (final raw in ['not json', '{"tabs": 5}', '{"tabs":[{"type":"alien"},{"type":"local"}]}', '[]']) {
      SharedPreferences.setMockInitialValues({'open_tabs': raw});
      final c = await launch();
      expect(c.sessions.length, 1, reason: raw);
      c.dispose();
    }
  });
}
