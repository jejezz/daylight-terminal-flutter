import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/local_shell.dart';

/// 이 컴퓨터에 설치된 셸을 찾는다. 파일 시스템과 환경은 주입할 수 있어서 테스트에서 가짜로 바꾼다.
class LocalShellFinder {
  LocalShellFinder({
    bool? isWindows,
    bool? isMacOS,
    Map<String, String>? environment,
    bool Function(String path)? fileExists,
    Future<List<String>> Function()? wslDistros,
    String Function(String path)? readFile,
  }) : isWindows = isWindows ?? Platform.isWindows,
       isMacOS = isMacOS ?? Platform.isMacOS,
       env = environment ?? Platform.environment,
       _exists = fileExists ?? ((path) => File(path).existsSync()),
       _wslDistros = wslDistros ?? listWslDistros,
       _readFile = readFile ?? ((path) => File(path).readAsStringSync());

  final bool isWindows;
  final bool isMacOS;
  final Map<String, String> env;
  final bool Function(String) _exists;
  final Future<List<String>> Function() _wslDistros;
  final String Function(String) _readFile;

  /// 탭을 열 수 있는 셸 목록. 첫 번째가 기본 셸이다.
  Future<List<LocalShell>> find() => isWindows ? _findWindows() : Future.value(_findUnix());

  // ───────────────────────── Windows ─────────────────────────

  String? _env(String key) {
    // Windows 환경 변수는 대소문자를 구분하지 않는다.
    for (final e in env.entries) {
      if (e.key.toLowerCase() == key.toLowerCase()) return e.value;
    }
    return null;
  }

  /// PATH에서 [exe]를 찾는다.
  String? _which(String exe) {
    for (final dir in (_env('PATH') ?? '').split(';')) {
      if (dir.trim().isEmpty) continue;
      final candidate = p.windows.join(dir.trim(), exe);
      if (_exists(candidate)) return candidate;
    }
    return null;
  }

  Future<List<LocalShell>> _findWindows() async {
    final shells = <LocalShell>[];
    final systemRoot = _env('SystemRoot') ?? r'C:\Windows';
    final programFiles = _env('ProgramFiles') ?? r'C:\Program Files';

    final pwsh = _which('pwsh.exe') ?? _firstExisting([p.windows.join(programFiles, 'PowerShell', '7', 'pwsh.exe')]);
    if (pwsh != null) {
      shells.add(
        LocalShell(
          id: 'pwsh',
          name: 'PowerShell 7',
          executable: pwsh,
          kind: ShellKind.powershell,
          arguments: const ['-NoLogo'],
        ),
      );
    }

    final winPs = p.windows.join(systemRoot, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe');
    if (_exists(winPs)) {
      shells.add(
        LocalShell(
          id: 'powershell',
          name: 'Windows PowerShell',
          executable: winPs,
          kind: ShellKind.powershell,
          arguments: const ['-NoLogo'],
        ),
      );
    }

    final cmd = _env('ComSpec') ?? p.windows.join(systemRoot, 'System32', 'cmd.exe');
    if (_exists(cmd)) {
      shells.add(LocalShell(id: 'cmd', name: 'Command Prompt', executable: cmd, kind: ShellKind.cmd));
    }

    final gitBash = _firstExisting([
      p.windows.join(programFiles, 'Git', 'bin', 'bash.exe'),
      p.windows.join(_env('ProgramFiles(x86)') ?? r'C:\Program Files (x86)', 'Git', 'bin', 'bash.exe'),
    ]);
    if (gitBash != null) {
      shells.add(
        LocalShell(
          id: 'git-bash',
          name: 'Git Bash',
          executable: gitBash,
          kind: ShellKind.gitBash,
          arguments: const ['--login', '-i'],
        ),
      );
    }

    final wsl = p.windows.join(systemRoot, 'System32', 'wsl.exe');
    if (_exists(wsl)) {
      List<String> distros = const [];
      try {
        distros = await _wslDistros();
      } catch (_) {
        // wsl.exe가 있어도 배포판을 못 물어볼 수 있다 (기능이 꺼져 있는 경우 등).
      }
      for (final d in distros) {
        shells.add(
          LocalShell(
            id: 'wsl:$d',
            name: 'WSL: $d',
            executable: wsl,
            kind: ShellKind.wsl,
            arguments: ['-d', d],
            wslDistro: d,
          ),
        );
      }
    }
    return shells;
  }

  String? _firstExisting(List<String> paths) {
    for (final path in paths) {
      if (_exists(path)) return path;
    }
    return null;
  }

  // ───────────────────────── macOS / Linux ─────────────────────────

  List<LocalShell> _findUnix() {
    final seen = <String>{};
    final shells = <LocalShell>[];

    void add(String path) {
      final name = p.posix.basename(path);
      if (!path.startsWith('/') || !seen.add(name) || !_exists(path)) return;
      shells.add(
        LocalShell(
          id: name,
          name: name,
          executable: path,
          kind: ShellKind.posix,
          // macOS의 Terminal.app처럼 로그인 셸로 연다 (.zprofile 등을 읽는다).
          arguments: isMacOS ? const ['-l'] : const [],
        ),
      );
    }

    final login = env['SHELL'];
    if (login != null && login.isNotEmpty) add(login);
    try {
      for (final line in _readFile('/etc/shells').split('\n')) {
        final path = line.trim();
        if (path.isEmpty || path.startsWith('#')) continue;
        final base = p.posix.basename(path);
        if (base == 'nologin' || base == 'false' || base == 'true') continue;
        add(path);
      }
    } catch (_) {
      // /etc/shells가 없으면 로그인 셸만 쓴다.
    }
    return shells;
  }

  // ───────────────────────── WSL 배포판 목록 ─────────────────────────

  /// `wsl.exe -l -q`의 출력(UTF-16LE)에서 배포판 이름을 읽는다.
  static List<String> parseWslList(Uint8List bytes) {
    var text = bytes.length >= 2 && bytes.contains(0)
        ? String.fromCharCodes(
            Uint16List.view(Uint8List.fromList(bytes.length.isOdd ? bytes.sublist(0, bytes.length - 1) : bytes).buffer),
          )
        : utf8.decode(bytes, allowMalformed: true);
    text = text.replaceAll('\uFEFF', '');
    return [
      for (final line in text.split(RegExp(r'\r?\n')))
        if (line.replaceAll('\u0000', '').trim().isNotEmpty) line.replaceAll('\u0000', '').trim(),
    ];
  }

  static Future<List<String>> listWslDistros() async {
    final result = await Process.run(
      'wsl.exe',
      ['-l', '-q'],
      stdoutEncoding: null,
      stderrEncoding: null,
    ).timeout(const Duration(seconds: 4));
    if (result.exitCode != 0) return const [];
    return parseWslList(result.stdout as Uint8List);
  }
}
