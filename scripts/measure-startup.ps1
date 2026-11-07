# 앱 시작 시간 측정 (Windows).
#
# exe를 실행해서 창이 보일 때까지 걸린 시간과, 프로세스 시작 → main() 진입(엔진·로더 구간)을 보여 준다.
# main() 이후 구간은 진단 기록(diagnostics.log)의 `startup ...` 줄에 있다.
#
# 사용:
#   pwsh scripts/measure-startup.ps1 -Exe "C:\경로\daylight_terminal.exe" -Runs 6
#   (처음 한 번이 콜드, 나머지가 웜. 실행마다 앱을 자동으로 닫는다.)
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [int]$Runs = 6,
  [int]$TimeoutSeconds = 20
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Exe)) { throw "exe를 찾을 수 없습니다: $Exe" }
$log = Join-Path $env:LOCALAPPDATA 'Daylight Terminal\logs\diagnostics.log'

$rows = @()
for ($i = 1; $i -le $Runs; $i++) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process $Exe -PassThru
  while ($p.MainWindowHandle -eq 0 -and $sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    Start-Sleep -Milliseconds 20
    $p.Refresh()
  }
  $visibleMs = $sw.ElapsedMilliseconds
  $start = $p.StartTime

  # 방금 실행의 `start version=` 줄 (main 진입 시각).
  Start-Sleep -Milliseconds 300
  $enginePart = $null
  $line = Get-Content $log | Select-String 'start version=' | Select-Object -Last 1
  if ($line) {
    $mainAt = [datetime]::Parse(($line.Line -split ' ')[0])
    $enginePart = [int]($mainAt - $start).TotalMilliseconds
  }

  $rows += [pscustomobject]@{
    Run = $i
    Kind = if ($i -eq 1) { '콜드' } else { '웜' }
    '창 보일 때까지(ms)' = $visibleMs
    '시작→main(ms)' = $enginePart
  }

  Start-Sleep -Seconds 1
  if (-not $p.HasExited) { $null = $p.CloseMainWindow(); Start-Sleep -Milliseconds 500 }
  if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }
  Start-Sleep -Seconds 1
}

$rows | Format-Table -AutoSize
Write-Host "main() 이후 구간(마지막 실행):"
Get-Content $log | Select-String 'startup ' | Select-Object -Last 14 | ForEach-Object { $_.Line }
