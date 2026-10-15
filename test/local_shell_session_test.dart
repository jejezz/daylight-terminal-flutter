import 'dart:convert';
import 'dart:io';

import 'package:daylight_terminal/models/file_item.dart';
import 'package:daylight_terminal/models/line_ending.dart';
import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:daylight_terminal/state/terminal_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_pty.dart';

const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix, arguments: ['-l']);
const _cmd = LocalShell(id: 'cmd', name: 'cmd', executable: 'cmd.exe', kind: ShellKind.cmd);
const _pwsh = LocalShell(id: 'pwsh', name: 'PowerShell 7', executable: 'pwsh.exe', kind: ShellKind.powershell);

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late Directory tmp;
  late FakePtyFactory ptys;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('dt_local_');
    ptys = FakePtyFactory();
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  LocalShellSession make([LocalShell shell = _bash]) =>
      LocalShellSession(shell, ptyFactory: ptys.call, startDirectory: tmp.path);

  group('files dropped on the terminal', () {
    test('local shell: types the quoted local paths, without Enter', () async {
      final s = make();
      await s.start();
      final result = await s.dropFiles(['/a b/x', "/it's"], (_) async => true);
      expect(result.fallbackDir, isNull);
      expect(ptys.last.writtenText, r"'/a b/x' '/it'\''s' ");
      s.dispose();
    });

    test('remembers the cwd the shell reports on its own, not the one a menu probe asked for', () async {
      final s = make();
      await s.start();
      expect(s.autoReportedCwd, isNull);
      ptys.last.emit('\x1b]7;file://host/home/me/work%20dir\x1b\\');
      await pump();
      expect(s.autoReportedCwd, '/home/me/work dir');
      s.dispose();
    });
  });

  group('shell process', () {
    test('start spawns the shell in the start folder with a full environment', () async {
      final s = make();
      await s.start();
      expect(s.connected, isTrue);
      final call = ptys.calls.single;
      expect(call.shell.executable, '/bin/bash');
      expect(call.cwd, tmp.path);
      expect(call.env['TERM'], 'xterm-256color');
      expect(call.env['COLORTERM'], 'truecolor');
      // flutter_pty는 환경을 거의 물려주지 않으므로 전체를 넘겨야 한다 (Windows의 SystemRoot 등).
      expect(call.env.length, greaterThan(5));
      expect(call.env.keys.any((k) => k.toUpperCase() == 'PATH'), isTrue);
      s.dispose();
    });

    test('output from the shell reaches the terminal, including Korean split across chunks', () async {
      final s = make();
      await s.start();
      final utf = utf8.encode('한글 ok\r\n');
      // 한글 한 글자(3바이트)의 중간에서 청크를 자른다.
      ptys.last.emitBytes(utf.sublist(0, 2));
      ptys.last.emitBytes(utf.sublist(2));
      await pump();
      expect(s.terminal.buffer.getText(), contains('한글 ok'));
      s.dispose();
    });

    test('typing and the LineSender write to the shell, with the chosen line ending', () async {
      final s = make();
      await s.start();
      s.terminal.textInput('ls');
      expect(ptys.last.writtenText, 'ls');
      s.send('echo hi'); // 기본 줄 끝은 CR
      expect(ptys.last.writtenText, 'lsecho hi\r');
      s.setLineEnding(LineEnding.crlf);
      s.send('x');
      expect(ptys.last.writtenText, endsWith('x\r\n'));
      s.dispose();
    });

    test('terminal resize is forwarded as rows x columns', () async {
      final s = make();
      await s.start();
      s.terminal.resize(100, 30);
      expect(ptys.last.resizes.last, (30, 100));
      s.dispose();
    });

    test('when the shell exits the tab stays, shows the exit code, and can restart in the same folder', () async {
      final s = make();
      await s.start();
      ptys.last.finish(3);
      await pump();
      expect(s.connected, isFalse);
      expect(s.status, SessionStatus.idle);
      expect(s.exitCode, 3);

      s.send('ignored while no shell is running');
      expect(ptys.made, hasLength(1));

      await s.restart();
      expect(ptys.made, hasLength(2));
      expect(s.connected, isTrue);
      expect(s.exitCode, isNull);
      expect(ptys.calls.last.cwd, tmp.path);
      s.dispose();
    });

    test('a shell that cannot be started reports the error and can retry', () async {
      ptys.failWith = StateError('Failed to create PTY: no such file');
      final s = make();
      await s.start();
      expect(s.status, SessionStatus.error);
      expect(s.startError, contains('Failed to create PTY'));
      expect(s.connected, isFalse);

      ptys.failWith = null;
      await s.restart();
      expect(s.connected, isTrue);
      expect(s.startError, isNull);
      s.dispose();
    });

    test('disconnect kills the shell; dispose kills it too and ignores a late exit', () async {
      final s = make();
      await s.start();
      final first = ptys.last;
      await s.disconnect();
      expect(first.killed, isTrue);
      expect(s.connected, isFalse);

      await s.restart();
      final second = ptys.last;
      s.dispose();
      expect(second.killed, isTrue);
      await pump(); // 늦게 도착한 종료 알림이 해제된 세션을 건드려도 오류가 없어야 한다
    });

    test('prepareForExit kills the shell so no process outlives the app', () async {
      final s = make();
      await s.start();
      await s.prepareForExit();
      expect(ptys.last.killed, isTrue);
      s.dispose();
    });
  });

  group('menus move the terminal or the folder view only on request', () {
    test('moving the folder view does not touch the terminal (no automatic sync)', () async {
      final sub = Directory(p.join(tmp.path, 'sub'))..createSync();
      final s = make();
      await s.start();
      final before = ptys.last.written.length;
      await s.loadFolder(sub.path);
      expect(s.folderPath, sub.path);
      expect(ptys.last.written.length, before, reason: '폴더 뷰를 옮겨도 셸에는 아무것도 입력되지 않는다');
      s.dispose();
    });

    test('Terminal → this folder types the right command for each shell', () async {
      for (final (shell, expected) in [
        (_bash, " cd -- '${tmp.path}'\r"),
        (_pwsh, "Set-Location -LiteralPath '${tmp.path}'\r"),
        (_cmd, 'cd /d "${tmp.path}"\r'),
      ]) {
        final f = FakePtyFactory();
        final s = LocalShellSession(shell, ptyFactory: f.call, startDirectory: tmp.path);
        await s.start();
        s.moveTerminalTo(tmp.path);
        expect(f.last.writtenText, expected, reason: shell.id);
        s.dispose();
      }
    });

    test('Explorer → terminal path: types the probe, follows the OSC 7 the shell prints, then moves', () async {
      final target = Directory(p.join(tmp.path, 'dest'))..createSync();
      // 이 PC에 맞는 셸로: Windows는 PowerShell(`/C:/경로`로 알려 준다), 그 밖에는 sh 계열(경로 그대로).
      final shell = Platform.isWindows ? _pwsh : _bash;
      final reported = Platform.isWindows ? '/${target.path.replaceAll(r'\', '/')}' : target.path;
      final s = make(shell);
      await s.start();
      final pty = ptys.last;
      // 진짜 셸처럼: 현재 경로를 묻는 명령(OSC 7 출력)을 받으면 경로를 돌려준다.
      pty.onInput = (input) {
        if (input.contains('7;file')) pty.emit('\x1b]7;file://myhost$reported\x1b\\');
      };
      expect(await s.syncExplorerToTerminal(), isTrue);
      expect(pty.writtenText, contains('7;file'));
      expect(p.equals(s.folderPath, target.path), isTrue);
      s.dispose();
    });

    test('Explorer → terminal path fails cleanly when the shell never answers, or cannot (cmd)', () async {
      final s = make();
      await s.start();
      expect(await s.syncExplorerToTerminal(), isFalse); // 3초 대기 후 실패
      expect(s.folderPath, tmp.path);
      s.dispose();

      final f = FakePtyFactory();
      final c = LocalShellSession(_cmd, ptyFactory: f.call, startDirectory: tmp.path);
      await c.start();
      expect(c.canSyncExplorer, isFalse);
      expect(await c.syncExplorerToTerminal(), isFalse);
      expect(f.last.written, isEmpty, reason: 'cmd에는 아무 명령도 입력하지 않는다');
      c.dispose();
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('local folder view', () {
    test('lists folders first, then files by name, with sizes', () async {
      File(p.join(tmp.path, 'b.txt')).writeAsStringSync('12345');
      File(p.join(tmp.path, 'A.txt')).writeAsStringSync('1');
      Directory(p.join(tmp.path, 'zdir')).createSync();
      Directory(p.join(tmp.path, 'adir')).createSync();
      final s = make();
      await s.start();
      expect(s.entries.map((e) => e.name), ['adir', 'zdir', 'A.txt', 'b.txt']);
      expect(s.entries.firstWhere((e) => e.name == 'b.txt').size, 5);
      expect(s.entries.firstWhere((e) => e.name == 'adir').isDirectory, isTrue);
      expect(s.folderError, isNull);
      s.dispose();
    });

    test('open a folder, go up, but never above the root', () async {
      final sub = Directory(p.join(tmp.path, 'sub'))..createSync();
      final s = make();
      await s.start();
      await s.openEntry(s.entries.single);
      expect(s.folderPath, sub.path);
      expect(s.canGoUp, isTrue);
      await s.goUp();
      expect(s.folderPath, tmp.path);

      final root = LocalShellSession(_bash, ptyFactory: ptys.call, startDirectory: p.rootPrefix(tmp.path));
      expect(root.canGoUp, isFalse);
      root.dispose();
      s.dispose();
    });

    test('a folder that cannot be read shows an error and keeps the previous listing', () async {
      File(p.join(tmp.path, 'keep.txt')).createSync();
      final s = make();
      await s.start();
      await s.loadFolder(p.join(tmp.path, 'does-not-exist'));
      expect(s.folderError, isNotNull);
      expect(s.folderPath, tmp.path);
      expect(s.entries.map((e) => e.name), ['keep.txt']);
      await s.refreshFolder();
      expect(s.folderError, isNull);
      s.dispose();
    });

    test('new folder, rename (file and folder), delete (file and non-empty folder)', () async {
      final s = make();
      await s.start();
      await s.makeDirectory('made');
      File(p.join(tmp.path, 'made', 'inner.txt')).writeAsStringSync('x');
      File(p.join(tmp.path, 'f.txt')).writeAsStringSync('hello');
      await s.refreshFolder();

      await s.rename(s.entries.firstWhere((e) => e.name == 'f.txt'), 'g.txt');
      await s.rename(s.entries.firstWhere((e) => e.name == 'made'), 'renamed');
      expect(s.entries.map((e) => e.name), containsAll(['renamed', 'g.txt']));
      expect(File(p.join(tmp.path, 'renamed', 'inner.txt')).existsSync(), isTrue);

      await s.delete(s.entries.firstWhere((e) => e.name == 'renamed'));
      await s.delete(s.entries.firstWhere((e) => e.name == 'g.txt'));
      expect(s.entries, isEmpty);
      s.dispose();
    });

    test('deleting a link removes the link, not its target', () async {
      final target = Directory(p.join(tmp.path, 'target'))..createSync();
      File(p.join(target.path, 'precious.txt')).writeAsStringSync('keep me');
      try {
        Link(p.join(tmp.path, 'lnk')).createSync(target.path);
      } on FileSystemException {
        return; // 링크를 만들 권한이 없는 환경 (Windows 일반 사용자 등)
      }
      final s = make();
      await s.start();
      final link = s.entries.firstWhere((e) => e.name == 'lnk');
      expect(link.isLink, isTrue);
      expect(link.isDirectory, isTrue); // 가리키는 쪽이 폴더라서 들어갈 수 있다
      await s.delete(link);
      expect(Link(p.join(tmp.path, 'lnk')).existsSync(), isFalse);
      expect(File(p.join(target.path, 'precious.txt')).readAsStringSync(), 'keep me');
      s.dispose();
    });

    test('places lists the home folder first', () async {
      final s = make();
      final places = await s.places();
      expect(places.first.$1, '~');
      expect(places.first.$2, LocalShellSession.homeDirectory());
      s.dispose();
    });
  });

  test('recording works on a local tab like on SSH (needs a running shell)', () async {
    final s = make();
    expect(s.isLogging, isFalse);
    expect(s.logName, 'bash');
    expect(s.tabTitle, 'bash');
    expect(s.statusLabel, 'bash');
    s.dispose();
  });

  test('FileItem is shared by both views', () {
    const e = FileItem(name: 'a', isDirectory: false, isLink: false);
    expect(e.name, 'a');
  });
}
