import 'dart:convert';
import 'dart:typed_data';

import '../models/local_shell.dart';

/// 셸 통합: 셸이 프롬프트를 그릴 때마다 현재 폴더(OSC 7)를, 명령을 실행할 때와 끝날 때
/// 실행한 명령(OSC 633;E)·시작(OSC 133;C)·종료 코드(OSC 133;D)를 터미널로 알리게 하는 스크립트.
/// 터미널 탭이 "지금 어느 폴더에서 무슨 명령을 돌리는지" 보여 주는 데 쓴다.
///
/// 로컬 셸을 띄울 때 셸 인자로 넣는다(파일을 만들지 않는다 — Windows PowerShell의 실행 정책이 스크립트 파일을
/// 막을 수 있다). 사용자의 프로필은 그대로 읽고, 그 뒤에 `prompt`와 입력 읽기를 감싼다.
abstract final class ShellIntegration {
  /// [shell]이 통합 스크립트를 받을 수 있는 종류인가. (PowerShell, bash, Git Bash, WSL. zsh·cmd는 아직.)
  static bool supports(LocalShell shell) => shell.kind == ShellKind.powershell || _isBash(shell);

  static bool _isBash(LocalShell shell) {
    // WSL의 기본 셸은 bash다 (다른 셸이면 PROMPT_COMMAND가 무시될 뿐 해롭지 않다).
    if (shell.kind == ShellKind.gitBash || shell.kind == ShellKind.wsl) return true;
    if (shell.kind != ShellKind.posix) return false;
    final base = shell.executable.split(RegExp(r'[\\/]')).last.toLowerCase();
    return base == 'bash' || base == 'bash.exe';
  }

  /// 셸 프로세스에 더해 줄 환경 변수. bash 계열은 인자 대신 환경으로 넣는다: `PROMPT_COMMAND`가 첫 프롬프트에서
  /// 스크립트를 불러 오므로 사용자의 `.bashrc`/`.bash_profile`(로그인 셸 포함)을 모두 읽은 *뒤*에 걸린다.
  /// [base]에 이미 `PROMPT_COMMAND`가 있으면 그것도 이어서 부른다.
  static Map<String, String> environment(LocalShell shell, Map<String, String> base) {
    if (!_isBash(shell)) return const {};
    final existing = base['PROMPT_COMMAND'];
    final hook = existing == null || existing.isEmpty || existing.contains(r'$__DL_SI')
        ? bashPromptCommand
        : '$bashPromptCommand; $existing';
    final env = {'PROMPT_COMMAND': hook, '__DL_SI': bashScript};
    if (shell.kind == ShellKind.wsl) {
      // wsl.exe는 WSLENV에 이름을 올린 환경 변수만 리눅스 쪽으로 넘긴다.
      final names = (base['WSLENV'] ?? '').split(':').where((n) => n.isNotEmpty).toList();
      for (final n in ['PROMPT_COMMAND', '__DL_SI']) {
        if (!names.any((e) => e.split('/').first == n)) names.add(n);
      }
      env['WSLENV'] = names.join(':');
    }
    return env;
  }

  static const bashPromptCommand = r'eval "$__DL_SI"';

  /// 통합 스크립트를 인자로 얹은 셸. PowerShell 말고는 그대로 돌려준다 (bash는 [environment]로 넣는다).
  static LocalShell apply(LocalShell shell) {
    if (shell.kind != ShellKind.powershell) return shell;
    return LocalShell(
      id: shell.id,
      name: shell.name,
      executable: shell.executable,
      kind: shell.kind,
      arguments: [...shell.arguments, ...powershellArguments()],
      wslDistro: shell.wslDistro,
    );
  }

  /// `-NoExit -EncodedCommand <스크립트>`. 인용 문제가 없게 UTF-16LE base64로 넘긴다.
  static List<String> powershellArguments() => ['-NoExit', '-EncodedCommand', encodePowerShell(powershellScript)];

  static String encodePowerShell(String script) {
    final units = script.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xff;
      bytes[i * 2 + 1] = units[i] >> 8;
    }
    return base64.encode(bytes);
  }

  /// PowerShell 7과 Windows PowerShell 5.1 모두에서 도는 스크립트. 어떤 오류가 나도 셸이 평소처럼
  /// 떠야 하므로 전체를 try/catch로 감싼다.
  static const powershellScript = r'''
try {
  if (-not $global:__dlInstalled) {
    $global:__dlInstalled = $true
    $global:__dlRan = $false

    function global:__dlOsc([string]$body) {
      [Console]::Write("$([char]27)]$body$([char]27)\")
    }

    function global:__dlEscape([string]$s) {
      $sb = New-Object System.Text.StringBuilder
      foreach ($ch in $s.ToCharArray()) {
        $n = [int]$ch
        if ($ch -ceq '\') { [void]$sb.Append('\\') }
        elseif ($n -lt 32 -or $n -eq 127 -or $ch -ceq ';') { [void]$sb.Append(('\x{0:x2}' -f $n)) }
        else { [void]$sb.Append($ch) }
      }
      $sb.ToString()
    }

    $global:__dlOrigPrompt = $function:prompt
    function global:prompt {
      $ok = $?
      $code = $global:LASTEXITCODE
      try {
        if ($global:__dlRan) {
          $global:__dlRan = $false
          $exit = 1
          if ($ok) { $exit = 0 } elseif (($code -is [int]) -and ($code -ne 0)) { $exit = $code }
          __dlOsc "133;D;$exit"
        }
        $loc = $executionContext.SessionState.Path.CurrentLocation
        if ($loc.Provider.Name -eq 'FileSystem') {
          $p = $loc.ProviderPath.Replace('\', '/').Replace('%', '%25')
          __dlOsc "7;file://$($env:COMPUTERNAME)/$p"
        }
      } catch {}
      # 프롬프트 함수(starship 등)가 직전 명령의 성공 여부($?)를 읽을 수 있게 되돌려 놓는다.
      if (-not $ok) { Write-Error 'dl' -ErrorAction Ignore }
      & $global:__dlOrigPrompt
    }

    if (Get-Module -Name PSReadLine) {
      $global:__dlOrigReadLine = $function:PSConsoleHostReadLine
      if ($global:__dlOrigReadLine) {
        function global:PSConsoleHostReadLine {
          $line = & $global:__dlOrigReadLine
          try {
            if ($line -and $line.Trim()) {
              $cmd = $line
              if ($cmd.Length -gt 300) { $cmd = $cmd.Substring(0, 300) }
              __dlOsc ('633;E;' + (__dlEscape $cmd))
              __dlOsc '133;C'
              $global:__dlRan = $true
            }
          } catch {}
          $line
        }
      }
    }
  }
} catch {}
''';

  /// bash용 스크립트. `PROMPT_COMMAND`로 프롬프트마다 불리고(처음 한 번 함수를 정의하고 `PS0`를 건다), 직전 명령의 `$?`를
  /// 그대로 되돌려 놓아 다른 프롬프트 설정(starship 등)이 읽을 수 있게 한다. `PS0`(bash 4.4+)가 명령을 읽은 직후
  /// 명령 줄(OSC 633;E)과 시작(133;C)을 알리고, 프롬프트마다 종료 코드(133;D)와 폴더(OSC 7)를 알린다.
  static const bashScript = r'''
__dl_s=$?
if ! declare -F __dl_ps0 >/dev/null 2>&1; then
  __dl_osc() { printf '\033]%s\033\' "$1"; }
  __dl_ret() { return "$1"; }
  __dl_esc() {
    local s=${1:0:300} out= c i
    for ((i = 0; i < ${#s}; i++)); do
      c=${s:i:1}
      case $c in
        '\') out+='\' ;;
        ';') out+='\x3b' ;;
        *) if [[ $c == [[:cntrl:]] ]]; then printf -v c '\x%02x' "'$c"; fi; out+=$c ;;
      esac
    done
    printf '%s' "$out"
  }
  __dl_ps0() {
    local line
    line=$(HISTTIMEFORMAT= builtin history 1)
    line=${line#"${line%%[![:space:]]*}"}
    line=${line#* }
    line=${line#"${line%%[![:space:]]*}"}
    __dl_osc "633;E;$(__dl_esc "$line")"
    __dl_osc '133;C'
  }
  PS0='$(__dl_ps0)'"$PS0"
fi
__dl_osc "133;D;$__dl_s"
if [ "$PWD" != "$__dl_pwd" ]; then
  __dl_pwd=$PWD
  __dl_p=$PWD
  if [ -n "$MSYSTEM" ] && command -v cygpath >/dev/null 2>&1; then __dl_p=/$(cygpath -m "$PWD"); fi
  __dl_p=${__dl_p//%/%25}
  __dl_uri="file://${HOSTNAME}${__dl_p}"
fi
__dl_osc "7;$__dl_uri"
__dl_ret "$__dl_s"
''';

  /// OSC 633;E의 명령 줄에서 `\\`와 `\xHH`를 되돌린다.
  static String unescapeCommand(String s) {
    if (!s.contains(r'\')) return s;
    final out = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c != r'\' || i + 1 >= s.length) {
        out.write(c);
        continue;
      }
      final next = s[i + 1];
      if (next == r'\') {
        out.write(r'\');
        i++;
      } else if (next == 'x' && i + 4 <= s.length) {
        final hex = s.substring(i + 2, i + 4);
        final code = int.tryParse(hex, radix: 16);
        if (code == null) {
          out.write(c);
        } else {
          out.writeCharCode(code);
          i += 3;
        }
      } else {
        out.write(c);
      }
    }
    return out.toString();
  }
}
