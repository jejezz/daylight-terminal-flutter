/// 셸에 입력하는 작은 명령들. SSH 세션과 로컬 셸 세션이 함께 쓴다.
abstract final class ShellCommands {
  /// sh 계열 셸이 현재 경로를 OSC 7(`ESC ] 7 ; file://호스트/경로 ESC \`)로 출력하게 하는 명령.
  /// 앞의 공백은 히스토리에 남지 않게 한다 (HISTCONTROL=ignorespace).
  static const posixCwdProbe = r''' printf '\033]7;file://%s%s\033\\' "$HOSTNAME" "$PWD"''';

  /// Git Bash(MSYS)용. `$PWD`는 `/tmp/...`처럼 MSYS 마운트 기준 경로라서 윈도 탐색기가 알아듣지 못한다 —
  /// `cygpath -m`으로 `C:/Users/...` 모양의 윈도 경로를 받아, PowerShell과 같은 `file://호스트/C:/경로`로 출력한다.
  static const gitBashCwdProbe = r''' printf '\033]7;file://%s/%s\033\\' "$HOSTNAME" "$(cygpath -m "$PWD")"''';

  /// PowerShell이 현재 폴더를 같은 형식(`file://호스트/C:/경로`)으로 출력하게 하는 명령.
  static const powershellCwdProbe =
      r'''[Console]::Write("$([char]27)]7;file://$($env:COMPUTERNAME)/$((Get-Location).ProviderPath.Replace('\','/'))$([char]27)\")''';

  /// POSIX 셸용 작은따옴표 인용.
  static String posixQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

  /// PowerShell용 작은따옴표 인용 (작은따옴표는 두 번 쓴다).
  static String powershellQuote(String s) => "'${s.replaceAll("'", "''")}'";
}
