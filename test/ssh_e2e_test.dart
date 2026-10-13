// 수동 통합 테스트: 실제 SSH 서버가 있어야 한다. 환경 변수가 없으면 건너뛴다.
//
//   TEST_SSH_PORT=2222 TEST_SSH_PASSWORD=... flutter test test/ssh_e2e_test.dart
//
// 서버는 사용자 `tester`로 비밀번호 인증을 받고, SFTP 루트(/)에 `sub/` 폴더가 있어야 한다.
// 셸은 `cd --`와 OSC 7 `printf`에 반응하는 간이 셸이면 된다.
import 'dart:io';

import 'package:daylight_terminal/models/ssh_profile.dart';
import 'package:daylight_terminal/services/drag_staging.dart';
import 'package:daylight_terminal/services/profile_store.dart';
import 'package:daylight_terminal/state/ssh_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final port = int.tryParse(Platform.environment['TEST_SSH_PORT'] ?? '');
  final password = Platform.environment['TEST_SSH_PASSWORD'];
  final skip = port == null || password == null ? 'TEST_SSH_PORT / TEST_SSH_PASSWORD 없음' : null;

  late SshSessionProvider session;
  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = SshSessionProvider(await ProfileStore.load());
    tmp = await Directory.systemTemp.createTemp('dt_e2e_');
  });

  tearDown(() async {
    await session.disconnect();
    session.dispose();
    await tmp.delete(recursive: true);
  });

  SshProfile profile({String user = 'tester'}) =>
      SshProfile(id: '1', host: '127.0.0.1', port: port ?? 22, username: user);

  Future<void> waitFor(bool Function() ok, {int seconds = 5}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!ok() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(ok(), isTrue, reason: 'timeout');
  }

  String screen() => session.terminal.buffer.getText();

  test('connects, lists, and wrong password fails', () async {
    await session.connect(profile(), password: 'wrong');
    expect(session.status, SessionStatus.error);

    final s2 = SshSessionProvider(session.store);
    await s2.connect(profile(), password: password);
    expect(s2.connected, isTrue);
    expect(s2.entries.map((e) => e.name), contains('sub'));
    expect(s2.entries.firstWhere((e) => e.name == 'sub').isDirectory, isTrue);
    await s2.disconnect();
    s2.dispose();
  }, skip: skip);

  test('shell: LineSender send() reaches the shell and output renders', () async {
    await session.connect(profile(), password: password);
    await waitFor(() => screen().contains('ready\$'));
    session.send('hello 한글');
    await waitFor(() => screen().contains('got:hello 한글'));
  }, skip: skip);

  test('hostkey: second connect OK, tampered key is refused', () async {
    await session.connect(profile(), password: password);
    expect(session.connected, isTrue);
    await session.disconnect();
    await session.store.trustHostKey('127.0.0.1', port!, 'ssh-ed25519 00:11');
    await session.connect(profile(), password: password);
    expect(session.status, SessionStatus.error);
    expect(session.error, SessionError.hostKeyMismatch);
  }, skip: skip);

  test('sftp: mkdir, upload (file + folder), download, rename, delete', () async {
    await session.connect(profile(), password: password);
    await session.makeDirectory('work');
    await session.loadDir('/work');
    expect(session.remotePath, '/work');

    final f = File('${tmp.path}/a.txt')..writeAsStringSync('hello sftp');
    final d = Directory('${tmp.path}/dir')..createSync();
    File('${d.path}/b.bin').writeAsBytesSync(List.generate(300000, (i) => i % 251));
    await session.upload([f.path, d.path]);
    expect(session.entries.map((e) => e.name), containsAll(['a.txt', 'dir']));
    expect(
      session.transfers.every((t) => t.status.name == 'done'),
      isTrue,
      reason: '${session.transfers.map((t) => t.error)}',
    );
    expect(session.uploadConflicts([f.path]), ['a.txt']);

    final out = Directory('${tmp.path}/out')..createSync();
    await session.download(session.entries, out.path);
    expect(File('${out.path}/a.txt').readAsStringSync(), 'hello sftp');
    expect(File('${out.path}/dir/b.bin').readAsBytesSync(), File('${d.path}/b.bin').readAsBytesSync());
    expect(session.downloadConflicts(session.entries, out.path), containsAll(['a.txt', 'dir']));

    await session.rename(session.entries.firstWhere((e) => e.name == 'a.txt'), 'c.txt');
    expect(session.entries.map((e) => e.name), contains('c.txt'));
    await session.delete(session.entries.firstWhere((e) => e.name == 'dir'));
    await session.delete(session.entries.firstWhere((e) => e.name == 'c.txt'));
    expect(session.entries, isEmpty);
    await session.loadDir('/');
    await session.delete(session.entries.firstWhere((e) => e.name == 'work'));
  }, skip: skip);

  test('drag out: stageForDrag downloads local copies; the next drag cleans the previous one', () async {
    await session.connect(profile(), password: password);
    await session.makeDirectory('dragsrc');
    await session.loadDir('/dragsrc');
    final f = File('${tmp.path}/one.txt')..writeAsStringSync('stage me');
    final d = Directory('${tmp.path}/folder')..createSync();
    File('${d.path}/inner.txt').writeAsStringSync('inner');
    await session.upload([f.path, d.path]);

    final items = session.entries;
    final first = await session.stageForDrag(items, from: '/dragsrc');
    expect(first, hasLength(2));
    final one = first.firstWhere((p) => p.endsWith('one.txt'));
    expect(File(one).readAsStringSync(), 'stage me');
    expect(File('${first.firstWhere((p) => p.endsWith('folder'))}/inner.txt').readAsStringSync(), 'inner');

    // 끄는 동안 탐색기가 다른 폴더로 가도 원래 폴더(from)의 파일을 받는다.
    await session.loadDir('/');
    final second = await session.stageForDrag([items.firstWhere((e) => e.name == 'one.txt')], from: '/dragsrc');
    expect(File(second.single).readAsStringSync(), 'stage me');
    expect(File(one).existsSync(), isFalse, reason: '이전 드래그의 사본은 지워진다');

    await DragStaging.clean();
    expect(DragStaging.root.existsSync(), isFalse);
    await session.loadDir('/');
    await session.delete(session.entries.firstWhere((e) => e.name == 'dragsrc'));
  }, skip: skip);

  test('path menus: terminal -> folder and explorer -> terminal, only on request', () async {
    await session.connect(profile(), password: password);
    await waitFor(() => screen().contains('ready\$'));

    // 탐색기에서 이동해도 터미널은 따라가지 않는다 (자동 동기화 없음).
    await session.loadDir('/sub');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(screen().contains('cd --'), isFalse);

    // 메뉴: 터미널을 이 폴더로 이동
    session.moveTerminalTo(session.remotePath);
    await waitFor(() => screen().contains("cd -- '/sub'"));

    // 메뉴: 탐색기를 터미널 경로로 이동
    await session.loadDir('/');
    expect(session.remotePath, '/');
    expect(await session.syncExplorerToTerminal(), isTrue);
    expect(session.remotePath, '/sub');
  }, skip: skip);
}
