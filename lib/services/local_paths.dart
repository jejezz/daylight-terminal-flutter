import '../models/local_shell.dart';
import 'shell_commands.dart';

/// 로컬 폴더 뷰(이 PC의 경로)와 로컬 셸이 쓰는 경로 사이의 변환. 순수 함수라서 테스트할 수 있다.
abstract final class LocalPaths {
  /// 셸이 [path](이 PC의 경로)로 이동하게 하는 명령. 끝의 `\r`은 Enter다.
  static String cdCommand(LocalShell shell, String path) {
    switch (shell.kind) {
      case ShellKind.posix:
        return ' cd -- ${ShellCommands.posixQuote(path)}\r';
      case ShellKind.gitBash:
        // MSYS 셸은 `C:/Users/me`처럼 슬래시로 쓴 윈도 경로를 받는다.
        return ' cd -- ${ShellCommands.posixQuote(path.replaceAll(r'\', '/'))}\r';
      case ShellKind.powershell:
        return 'Set-Location -LiteralPath ${ShellCommands.powershellQuote(path)}\r';
      case ShellKind.cmd:
        return 'cd /d "$path"\r';
      case ShellKind.wsl:
        // wslpath가 C:\Users\me → /mnt/c/Users/me, \\wsl.localhost\배포판\home\me → /home/me 로 바꾼다.
        return ' cd -- "\$(wslpath -u ${ShellCommands.posixQuote(path)})"\r';
    }
  }

  /// 셸에 "현재 경로를 OSC 7로 출력해"라고 시키는 명령. 알려 줄 방법이 없는 셸(cmd)은 null.
  static String? cwdProbe(LocalShell shell) => switch (shell.kind) {
    ShellKind.posix || ShellKind.wsl => ShellCommands.posixCwdProbe,
    ShellKind.gitBash => ShellCommands.gitBashCwdProbe,
    ShellKind.powershell => ShellCommands.powershellCwdProbe,
    ShellKind.cmd => null,
  };

  /// 셸이 알려 준 경로(OSC 7의 경로 부분, `/`로 시작)를 이 PC의 경로로 바꾼다. 바꿀 수 없으면 null.
  static String? explorerPathFromTerminal(LocalShell shell, String reported) {
    if (!reported.startsWith('/')) return null;
    switch (shell.kind) {
      case ShellKind.posix:
        return reported;
      case ShellKind.powershell:
        // `/C:/Users/me` → `C:\Users\me`
        final m = RegExp(r'^/([A-Za-z]:)(.*)$').firstMatch(reported);
        if (m == null) return null;
        return _windowsPath(m.group(1)!, m.group(2)!);
      case ShellKind.gitBash:
        // 프로브가 `cygpath -m`으로 `C:/Users/me`를 보내므로 `/C:/Users/me` 모양으로 온다.
        final drive = RegExp(r'^/([A-Za-z]:)(.*)$').firstMatch(reported);
        if (drive != null) return _windowsPath(drive.group(1)!, drive.group(2)!);
        // 옛 MSYS 모양 `/c/Users/me`도 받는다. `/tmp/...`처럼 마운트 기준 경로는 윈도 경로를 알 수 없다.
        final msys = RegExp(r'^/([A-Za-z])(/.*)?$').firstMatch(reported);
        if (msys == null) return null;
        return _windowsPath('${msys.group(1)!.toUpperCase()}:', msys.group(2) ?? '');
      case ShellKind.wsl:
        // `/mnt/c/Users/me` → `C:\Users\me`, 배포판 안쪽(`/home/me`)은 \\wsl.localhost\배포판\home\me
        final m = RegExp(r'^/mnt/([A-Za-z])(/.*)?$').firstMatch(reported);
        if (m != null) return _windowsPath('${m.group(1)!.toUpperCase()}:', m.group(2) ?? '');
        final distro = shell.wslDistro;
        if (distro == null) return null;
        return '\\\\wsl.localhost\\$distro${reported.replaceAll('/', r'\')}';
      case ShellKind.cmd:
        return null;
    }
  }

  static String _windowsPath(String drive, String rest) {
    final tail = rest.replaceAll('/', r'\');
    return tail.isEmpty ? '$drive\\' : '$drive$tail';
  }
}
