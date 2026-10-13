// 수동 통합 테스트: 진짜 pty(Windows는 ConPTY)로 이 PC의 실제 셸을 띄운다. TEST_PTY=1일 때만 돈다.
//
// flutter_pty의 네이티브 라이브러리(flutter_pty.dll 등)가 PATH에 있어야 한다. 먼저 한 번 빌드한 뒤:
//
//   flutter build windows --debug
//   PATH="$PATH:build/windows/x64/runner/Debug" TEST_PTY=1 flutter test test/local_pty_e2e_test.dart
import 'dart:io';

import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/services/local_shell_finder.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<void> waitFor(bool Function() ok, {int seconds = 15, String? reason}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (!ok() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(ok(), isTrue, reason: reason ?? 'timeout');
}

void main() {
  final enabled = Platform.environment['TEST_PTY'] == '1';
  final skip = enabled ? null : 'TEST_PTY=1 이 아님';
  late Directory tmp;
  late List<LocalShell> shells;

  setUpAll(() async {
    if (!enabled) return;
    shells = await LocalShellFinder().find();
    // ignore: avoid_print
    print('shells on this machine: ${shells.map((s) => s.id).join(', ')}');
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dt_pty_');
  });

  tearDown(() async {
    if (tmp.existsSync()) {
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // 셸이 아직 이 폴더에 있어 못 지우면 다음에 OS가 임시 폴더를 비운다.
      }
    }
  });

  LocalShell? find(String id) => shells.where((s) => s.id == id).firstOrNull;

  String screen(LocalShellSession s) => s.terminal.buffer.getText();

  test('finds at least one real shell on this machine', () {
    expect(shells, isNotEmpty);
  }, skip: skip);

  test(
    'cmd: real shell starts in the folder, runs a command, prints, exits with its code',
    () async {
      final cmd = find('cmd');
      if (cmd == null) return;
      final s = LocalShellSession(cmd, startDirectory: tmp.path);
      await s.start();
      expect(s.connected, isTrue, reason: s.startError);
      await waitFor(() => screen(s).contains('>'), reason: 'prompt never appeared: ${screen(s)}');
      expect(screen(s), contains(tmp.path)); // 시작 폴더가 프롬프트에 보인다

      s.send('echo hello-from-pty');
      await waitFor(() => 'hello-from-pty'.allMatches(screen(s)).length >= 2, reason: screen(s)); // 입력 에코 + 출력

      s.send('exit 5');
      await waitFor(() => s.exitCode != null);
      expect(s.exitCode, 5);
      expect(s.connected, isFalse);
      s.dispose();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'powershell: Korean output, resize, and BOTH path menus against the real shell',
    () async {
      final ps = find('pwsh') ?? find('powershell');
      if (ps == null) return;
      final target = Directory(p.join(tmp.path, '대상 폴더 (it\'s)'))..createSync(recursive: true);
      final s = LocalShellSession(ps, startDirectory: tmp.path);
      await s.start();
      expect(s.connected, isTrue, reason: s.startError);
      // 프롬프트 모양은 사용자의 프로필(oh-my-posh 등)마다 달라서, 무언가 그려지기만 기다린다.
      await waitFor(() => screen(s).trim().isNotEmpty, reason: 'nothing was drawn: ${screen(s)}');

      // 한글이 깨지지 않고 나온다.
      s.send('Write-Output "한글-확인-OK"');
      await waitFor(() => '한글-확인-OK'.allMatches(screen(s)).length >= 2, reason: screen(s));

      // 크기 변경이 셸에 전달된다 (화면 폭을 읽어 확인).
      s.terminal.resize(111, 30);
      s.send(r'Write-Output ("WIDTH=" + $Host.UI.RawUI.WindowSize.Width)');
      await waitFor(() => screen(s).contains('WIDTH=111'), reason: screen(s));

      // 메뉴 1: 터미널을 이 폴더로 이동 — 공백·작은따옴표·한글이 든 경로 (자동으로는 따라가지 않는다)
      await s.loadFolder(target.path);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(screen(s).contains('대상 폴더'), isFalse, reason: '폴더 뷰를 옮겼다고 터미널이 따라가면 안 된다');
      s.moveTerminalTo(target.path);
      s.send(r'Write-Output ("CWD=" + (Get-Location).ProviderPath)');
      await waitFor(() => screen(s).contains('CWD=') && screen(s).contains('대상 폴더'), reason: screen(s));

      // 메뉴 2: 탐색기를 터미널 경로로 이동 — 진짜 PowerShell이 OSC 7을 돌려준다.
      await s.loadFolder(tmp.path);
      expect(p.equals(s.folderPath, tmp.path), isTrue);
      expect(await s.syncExplorerToTerminal(), isTrue, reason: screen(s));
      expect(p.equals(s.folderPath, target.path), isTrue, reason: '폴더 뷰: ${s.folderPath}');

      s.dispose();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'wsl: a real Linux shell — Windows path in, Linux path out, both directions',
    () async {
      final wsl = shells.where((s) => s.kind == ShellKind.wsl).firstOrNull;
      if (wsl == null) return;
      final target = Directory(p.join(tmp.path, 'wsl dir'))..createSync(recursive: true);
      final s = LocalShellSession(wsl, startDirectory: tmp.path);
      await s.start();
      expect(s.connected, isTrue, reason: s.startError);
      await waitFor(() => screen(s).trim().isNotEmpty, seconds: 30, reason: 'nothing was drawn: ${screen(s)}');

      s.moveTerminalTo(target.path); // 윈도 경로 → wslpath -u 로 변환되어 cd
      s.send('pwd');
      await waitFor(() => screen(s).contains('/mnt/') && screen(s).contains('wsl dir'), reason: screen(s));

      await s.loadFolder(tmp.path);
      expect(await s.syncExplorerToTerminal(), isTrue, reason: screen(s));
      expect(p.equals(s.folderPath, target.path), isTrue, reason: '폴더 뷰: ${s.folderPath}');
      s.dispose();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 120)),
  );

  test(
    'git bash: MSYS paths — Windows path in (C:/...), /c/... out, both directions',
    () async {
      final bash = find('git-bash');
      if (bash == null) return;
      final target = Directory(p.join(tmp.path, 'bash dir'))..createSync(recursive: true);
      final s = LocalShellSession(bash, startDirectory: tmp.path);
      await s.start();
      expect(s.connected, isTrue, reason: s.startError);
      await waitFor(() => screen(s).trim().isNotEmpty, seconds: 20, reason: 'nothing was drawn: ${screen(s)}');

      s.moveTerminalTo(target.path);
      s.send('pwd');
      await waitFor(() => screen(s).contains('bash dir'), reason: screen(s));

      await s.loadFolder(tmp.path);
      expect(await s.syncExplorerToTerminal(), isTrue, reason: screen(s));
      expect(p.equals(s.folderPath, target.path), isTrue, reason: '폴더 뷰: ${s.folderPath}');
      s.dispose();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'a non-ASCII start folder works (flutter_pty used to mangle UTF-8 on Windows)',
    () async {
      final ps = find('pwsh') ?? find('powershell') ?? find('cmd');
      if (ps == null) return;
      final start = Directory(p.join(tmp.path, '시작 폴더 가나다'))..createSync(recursive: true);
      final s = LocalShellSession(ps, startDirectory: start.path);
      await s.start();
      expect(s.connected, isTrue, reason: s.startError);
      await waitFor(() => screen(s).trim().isNotEmpty, reason: 'nothing was drawn: ${screen(s)}');
      if (ps.kind == ShellKind.cmd) {
        s.send('cd');
      } else {
        s.send(r'Write-Output ("HERE=" + (Get-Location).ProviderPath)');
      }
      await waitFor(() => screen(s).contains('시작 폴더 가나다'), reason: screen(s));
      s.dispose();
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'closing the tab kills the real shell process',
    () async {
      final cmd = find('cmd') ?? shells.first;
      final s = LocalShellSession(cmd, startDirectory: tmp.path);
      await s.start();
      expect(s.connected, isTrue, reason: s.startError);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      s.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 500)); // 해제 뒤 늦게 오는 알림에도 오류가 없어야 한다
    },
    skip: skip,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
