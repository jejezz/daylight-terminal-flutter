import 'dart:convert';
import 'dart:io';

import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/services/shell_integration.dart';
import 'package:daylight_terminal/state/local_shell_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_pty.dart';

const _pwsh = LocalShell(
  id: 'pwsh',
  name: 'PowerShell 7',
  executable: 'pwsh.exe',
  kind: ShellKind.powershell,
  arguments: ['-NoLogo'],
);
const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix, arguments: ['-l']);

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('ShellIntegration', () {
    test('adds the script to PowerShell only, after the existing arguments', () {
      final applied = ShellIntegration.apply(_pwsh);
      expect(applied.arguments.take(3), ['-NoLogo', '-NoExit', '-EncodedCommand']);
      expect(applied.arguments, hasLength(4));
      expect(ShellIntegration.apply(_bash), same(_bash));
    });

    test('the encoded command round-trips to the script (UTF-16LE base64)', () {
      final encoded = ShellIntegration.powershellArguments().last;
      final bytes = base64.decode(encoded);
      final units = [for (var i = 0; i < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8)];
      expect(String.fromCharCodes(units), ShellIntegration.powershellScript);
    });

    test('bash and Git Bash get the script through the environment, others get nothing', () {
      const gitBash = LocalShell(
        id: 'git-bash',
        name: 'Git Bash',
        executable: r'C:\Program Files\Git\bin\bash.exe',
        kind: ShellKind.gitBash,
        arguments: ['--login', '-i'],
      );
      const zsh = LocalShell(id: 'zsh', name: 'zsh', executable: '/bin/zsh', kind: ShellKind.posix);
      for (final shell in [_bash, gitBash]) {
        final env = ShellIntegration.environment(shell, const {});
        expect(env['PROMPT_COMMAND'], ShellIntegration.bashPromptCommand);
        expect(env['__DL_SI'], ShellIntegration.bashScript);
      }
      expect(ShellIntegration.environment(zsh, const {}), isEmpty);
      expect(ShellIntegration.environment(_pwsh, const {}), isEmpty);
      // 이미 있는 PROMPT_COMMAND는 이어서 부르고, 한 번 넣은 것을 다시 감싸지 않는다.
      expect(
        ShellIntegration.environment(_bash, const {'PROMPT_COMMAND': 'history -a'})['PROMPT_COMMAND'],
        '${ShellIntegration.bashPromptCommand}; history -a',
      );
      expect(
        ShellIntegration.environment(_bash, {'PROMPT_COMMAND': ShellIntegration.bashPromptCommand})['PROMPT_COMMAND'],
        ShellIntegration.bashPromptCommand,
      );
    });

    test('unescapes backslashes and \\xHH', () {
      expect(ShellIntegration.unescapeCommand(r'echo a\x3b b'), 'echo a; b');
      expect(ShellIntegration.unescapeCommand(r'C:\\Users\\me'), r'C:\Users\me');
      expect(ShellIntegration.unescapeCommand('plain'), 'plain');
      expect(ShellIntegration.unescapeCommand(r'bad \xZZ'), r'bad \xZZ');
      expect(ShellIntegration.unescapeCommand(r'end\x'), r'end\x');
    });
  });

  group('session tracks what the shell reports', () {
    late Directory tmp;
    late FakePtyFactory ptys;
    late LocalShellSession session;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('dt_si_');
      ptys = FakePtyFactory();
      session = LocalShellSession(_pwsh, ptyFactory: ptys.call, startDirectory: tmp.path);
      await session.start();
    });

    tearDown(() async {
      session.dispose();
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    test('launches PowerShell with the integration arguments', () {
      expect(ptys.calls.single.shell.arguments, contains('-EncodedCommand'));
    });

    test('follows the folder from OSC 7 at each prompt', () async {
      var notified = 0;
      session.addListener(() => notified++);
      ptys.last.emit('\x1b]7;file://PC/C:/Users/jejez\x1b\\');
      await pump();
      expect(session.reportedCwd, '/C:/Users/jejez');
      final after = notified;
      ptys.last.emit('\x1b]7;file://PC/C:/Users/jejez\x1b\\'); // 같은 값은 다시 알리지 않는다
      await pump();
      expect(notified, after);
      ptys.last.emit('\x1b]7;file://PC/C:/Work/app%25x\x1b\\');
      await pump();
      expect(session.reportedCwd, '/C:/Work/app%x');
    });

    test('running command shows between OSC 133;C and 133;D, with the exit code', () async {
      expect(session.commandRunning, isFalse);
      ptys.last.emit('\x1b]633;E;flutter run -d windows\x1b\\\x1b]133;C\x1b\\');
      await pump();
      expect(session.commandRunning, isTrue);
      expect(session.runningCommand, 'flutter run -d windows');

      ptys.last.emit('\x1b]133;D;2\x1b\\');
      await pump();
      expect(session.commandRunning, isFalse);
      expect(session.runningCommand, isNull);
      expect(session.lastExitCode, 2);
    });

    test('a command containing ; and \\ arrives intact', () async {
      ptys.last.emit('\x1b]633;E;echo a\\x3b b \\\\ c\x1b\\\x1b]133;C\x1b\\');
      await pump();
      expect(session.runningCommand, r'echo a; b \ c');
    });

    test('state is cleared when the shell ends', () async {
      ptys.last.emit('\x1b]7;file://PC/C:/x\x1b\\\x1b]633;E;sleep 9\x1b\\\x1b]133;C\x1b\\');
      await pump();
      expect(session.commandRunning, isTrue);
      await session.disconnect();
      expect(session.commandRunning, isFalse);
      expect(session.reportedCwd, isNull);
    });
  });
}
