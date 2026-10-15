import 'dart:convert';
import 'dart:typed_data';

import 'package:daylight_terminal/models/local_shell.dart';
import 'package:daylight_terminal/services/local_paths.dart';
import 'package:daylight_terminal/services/local_shell_finder.dart';
import 'package:flutter_test/flutter_test.dart';

const _pwsh = LocalShell(id: 'pwsh', name: 'PowerShell 7', executable: 'pwsh.exe', kind: ShellKind.powershell);
const _cmd = LocalShell(id: 'cmd', name: 'cmd', executable: 'cmd.exe', kind: ShellKind.cmd);
const _bash = LocalShell(id: 'bash', name: 'bash', executable: '/bin/bash', kind: ShellKind.posix);
const _gitBash = LocalShell(id: 'git-bash', name: 'Git Bash', executable: 'bash.exe', kind: ShellKind.gitBash);
const _wsl = LocalShell(
  id: 'wsl:Ubuntu',
  name: 'WSL: Ubuntu',
  executable: 'wsl.exe',
  kind: ShellKind.wsl,
  wslDistro: 'Ubuntu',
);

void main() {
  group('LocalPaths.quotePath (파일을 터미널에 끌어놓을 때)', () {
    test('posix: 작은따옴표 인용', () => expect(LocalPaths.quotePath(_bash, "/a b/it's"), "'/a b/it'\\''s'"));
    test('powershell: 작은따옴표를 두 번', () => expect(LocalPaths.quotePath(_pwsh, r"C:\a b\it's"), "'C:\\a b\\it''s'"));
    test('cmd: 큰따옴표', () => expect(LocalPaths.quotePath(_cmd, r'D:\work dir\x'), '"D:\\work dir\\x"'));
    test('git bash: 슬래시로', () => expect(LocalPaths.quotePath(_gitBash, r'C:\Users\me'), "'C:/Users/me'"));
    test('wsl: wslpath로 변환', () {
      expect(LocalPaths.quotePath(_wsl, r'C:\Users\me'), '"\$(wslpath -u \'C:\\Users\\me\')"');
    });
  });

  group('LocalPaths.cdCommand', () {
    test('posix: quoted, leading space keeps it out of history, survives quotes', () {
      expect(LocalPaths.cdCommand(_bash, '/home/me/it\'s here'), " cd -- '/home/me/it'\\''s here'\r");
    });

    test('powershell: Set-Location -LiteralPath with doubled quotes', () {
      expect(LocalPaths.cdCommand(_pwsh, r"C:\Users\me\it's"), "Set-Location -LiteralPath 'C:\\Users\\me\\it''s'\r");
    });

    test('cmd: cd /d so a different drive works', () {
      expect(LocalPaths.cdCommand(_cmd, r'D:\work dir'), 'cd /d "D:\\work dir"\r');
    });

    test('git bash: windows path written with slashes', () {
      expect(LocalPaths.cdCommand(_gitBash, r'C:\Users\me'), " cd -- 'C:/Users/me'\r");
    });

    test('wsl: asks wslpath to convert, so C:\\ and \\\\wsl.localhost both work', () {
      expect(LocalPaths.cdCommand(_wsl, r'C:\Users\me'), ' cd -- "\$(wslpath -u \'C:\\Users\\me\')"\r');
    });
  });

  group('LocalPaths.cwdProbe', () {
    test('every shell except cmd can report its folder', () {
      for (final s in [_bash, _pwsh, _gitBash, _wsl]) {
        expect(LocalPaths.cwdProbe(s), isNotNull, reason: s.id);
        expect(s.canReportCwd, isTrue);
      }
      expect(LocalPaths.cwdProbe(_cmd), isNull);
      expect(_cmd.canReportCwd, isFalse);
    });

    test('the powershell probe prints an OSC 7 with the provider path', () {
      final probe = LocalPaths.cwdProbe(_pwsh)!;
      expect(probe, contains('[char]27'));
      expect(probe, contains(']7;file://'));
      expect(probe, contains('ProviderPath'));
    });
  });

  group('LocalPaths.explorerPathFromTerminal', () {
    test('posix: as reported', () {
      expect(LocalPaths.explorerPathFromTerminal(_bash, '/Users/me/src'), '/Users/me/src');
    });

    test('powershell: /C:/Users/me → C:\\Users\\me; non-filesystem locations are refused', () {
      expect(LocalPaths.explorerPathFromTerminal(_pwsh, '/C:/Users/me'), r'C:\Users\me');
      expect(LocalPaths.explorerPathFromTerminal(_pwsh, '/D:'), r'D:\');
      expect(LocalPaths.explorerPathFromTerminal(_pwsh, '/HKLM:/Software'), isNull);
    });

    test(
      'git bash: the cygpath probe reports /C:/Users/me; the old /c/Users/me form works; MSYS mounts are refused',
      () {
        expect(LocalPaths.explorerPathFromTerminal(_gitBash, '/C:/Users/me/a b'), r'C:\Users\me\a b');
        expect(LocalPaths.explorerPathFromTerminal(_gitBash, '/D:'), r'D:\');
        expect(LocalPaths.explorerPathFromTerminal(_gitBash, '/c/Users/me'), r'C:\Users\me');
        expect(LocalPaths.explorerPathFromTerminal(_gitBash, '/c'), r'C:\');
        expect(LocalPaths.explorerPathFromTerminal(_gitBash, '/tmp/x'), isNull);
      },
    );

    test('wsl: /mnt/c/... maps to the drive, a distro-internal path goes through \\\\wsl.localhost', () {
      expect(LocalPaths.explorerPathFromTerminal(_wsl, '/mnt/c/Users/me'), r'C:\Users\me');
      expect(LocalPaths.explorerPathFromTerminal(_wsl, '/home/me/src'), r'\\wsl.localhost\Ubuntu\home\me\src');
    });

    test('cmd and relative input are refused', () {
      expect(LocalPaths.explorerPathFromTerminal(_cmd, '/C:/x'), isNull);
      expect(LocalPaths.explorerPathFromTerminal(_bash, 'relative'), isNull);
    });
  });

  group('LocalShellFinder (Windows)', () {
    Future<List<LocalShell>> find({required Set<String> existing, List<String> distros = const [], String path = ''}) =>
        LocalShellFinder(
          isWindows: true,
          isMacOS: false,
          environment: {
            'SystemRoot': r'C:\Windows',
            'ProgramFiles': r'C:\Program Files',
            'ComSpec': r'C:\Windows\System32\cmd.exe',
            'Path': path,
          },
          fileExists: existing.contains,
          wslDistros: () async => distros,
        ).find();

    test('finds PowerShell 7 on PATH first, then Windows PowerShell, cmd, Git Bash, WSL distros', () async {
      final shells = await find(
        path: r'C:\Tools;C:\Program Files\PowerShell\7',
        distros: ['Ubuntu-24.04', 'Debian'],
        existing: {
          r'C:\Program Files\PowerShell\7\pwsh.exe',
          r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
          r'C:\Windows\System32\cmd.exe',
          r'C:\Program Files\Git\bin\bash.exe',
          r'C:\Windows\System32\wsl.exe',
        },
      );
      expect(shells.map((s) => s.id), ['pwsh', 'powershell', 'cmd', 'git-bash', 'wsl:Ubuntu-24.04', 'wsl:Debian']);
      expect(shells.map((s) => s.kind), [
        ShellKind.powershell,
        ShellKind.powershell,
        ShellKind.cmd,
        ShellKind.gitBash,
        ShellKind.wsl,
        ShellKind.wsl,
      ]);
      expect(shells.last.arguments, ['-d', 'Debian']);
      expect(shells.last.wslDistro, 'Debian');
    });

    test('a machine with only the built-ins still gets Windows PowerShell and cmd; the default is the first', () async {
      final shells = await find(
        existing: {r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe', r'C:\Windows\System32\cmd.exe'},
      );
      expect(shells.map((s) => s.id), ['powershell', 'cmd']);
    });

    test('wsl.exe without distros (or failing to list them) adds nothing and does not break', () async {
      final bad = LocalShellFinder(
        isWindows: true,
        isMacOS: false,
        environment: {'SystemRoot': r'C:\Windows'},
        fileExists: {r'C:\Windows\System32\wsl.exe', r'C:\Windows\System32\cmd.exe'}.contains,
        wslDistros: () async => throw Exception('wsl not enabled'),
      );
      expect((await bad.find()).map((s) => s.id), ['cmd']);
    });
  });

  group('LocalShellFinder (macOS / Linux)', () {
    LocalShellFinder unix({required bool mac, String? login, String shells = '', Set<String>? existing}) =>
        LocalShellFinder(
          isWindows: false,
          isMacOS: mac,
          environment: {'SHELL': ?login},
          fileExists: (existing ?? {'/bin/zsh', '/bin/bash', '/bin/sh', '/usr/bin/fish'}).contains,
          readFile: (_) => shells,
        );

    test(r'$SHELL first, then /etc/shells without duplicates, comments or nologin; macOS opens login shells', () async {
      final found = await unix(
        mac: true,
        login: '/bin/zsh',
        shells: '# list\n/bin/bash\n/bin/zsh\n/usr/sbin/nologin\n/bin/sh\n/usr/bin/fish\n/usr/bin/false\n',
      ).find();
      expect(found.map((s) => s.name), ['zsh', 'bash', 'sh', 'fish']);
      expect(found.first.executable, '/bin/zsh');
      expect(found.every((s) => s.arguments.length == 1 && s.arguments.single == '-l'), isTrue);
      expect(found.every((s) => s.kind == ShellKind.posix), isTrue);
    });

    test('Linux opens a plain interactive shell; shells that are not installed are skipped', () async {
      final found = await unix(
        mac: false,
        login: '/bin/bash',
        shells: '/bin/bash\n/bin/zsh\n/opt/missing/shell\n',
      ).find();
      expect(found.map((s) => s.name), ['bash', 'zsh']);
      expect(found.first.arguments, isEmpty);
    });

    test('no /etc/shells file: just the login shell', () async {
      final finder = LocalShellFinder(
        isWindows: false,
        isMacOS: false,
        environment: {'SHELL': '/bin/bash'},
        fileExists: {'/bin/bash'}.contains,
        readFile: (_) => throw Exception('no such file'),
      );
      expect((await finder.find()).map((s) => s.name), ['bash']);
    });
  });

  group('WSL list parsing', () {
    Uint8List utf16(String s) {
      final out = BytesBuilder();
      out.add([0xFF, 0xFE]); // BOM
      for (final u in s.codeUnits) {
        out.add([u & 0xFF, u >> 8]);
      }
      return out.toBytes();
    }

    test('decodes the UTF-16LE output of wsl -l -q', () {
      expect(LocalShellFinder.parseWslList(utf16('Ubuntu-24.04\r\ndocker-desktop\r\n')), [
        'Ubuntu-24.04',
        'docker-desktop',
      ]);
    });

    test('also accepts plain UTF-8 and ignores blank lines', () {
      expect(LocalShellFinder.parseWslList(Uint8List.fromList(utf8.encode('Debian\n\n  Arch  \n'))), [
        'Debian',
        'Arch',
      ]);
      expect(LocalShellFinder.parseWslList(Uint8List(0)), isEmpty);
    });
  });
}
