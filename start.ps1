# Starts Octalia: stops any running waku, sets Octalia's environment and starts waku on this folder.
#
#   .\start.ps1                the live setup: tray, app bar, Windows taskbar hidden, keys, tiling
#   .\start.ps1 -Log           also write waku's diagnostics log to logs\waku.log
#   .\start.ps1 -Watch         reload the shell when one of its files changes (waku --watch)
#   .\start.ps1 -DryRun        print what would run, change nothing
#   .\start.ps1 -Waku <path>   a specific waku.exe (default: $env:WAKU_EXE, else waku.exe on PATH)
#
# Without -Watch, `wakuc --config-home <this folder> reload` applies an edit.
param(
  [string]$Waku,
  [switch]$Log,
  [switch]$Watch,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\env.ps1')

# One shell at a time: ask each running waku to quit (the engine puts the taskbar back).
& (Join-Path $PSScriptRoot 'stop.ps1') -DryRun:$DryRun

$Waku = Find-Waku $Waku
if (-not $Waku -or -not (Test-Path $Waku)) {
  throw "engine not found: '$Waku' (pass -Waku, set WAKU_EXE, or put waku.exe on PATH)"
}
$flags = @('--config-home', $OctaliaRoot) + $OctaliaFlags
if ($Log) { $flags += @('--log-file', (Join-Path $OctaliaRoot 'logs\waku.log')) }
if ($Watch) { $flags += '--watch' }

if ($DryRun) {
  foreach ($e in $OctaliaEnv.GetEnumerator()) { Write-Host "would set $($e.Key)=$($e.Value)" }
  Write-Host "would start: `"$Waku`" $(Join-Arguments $flags)"
  return
}
foreach ($e in $OctaliaEnv.GetEnumerator()) { Set-Item -Path "env:$($e.Key)" -Value $e.Value }
New-Item -ItemType Directory -Force @($OctaliaEnv.Values) | Out-Null
if ($Log) { New-Item -ItemType Directory -Force (Join-Path $OctaliaRoot 'logs') | Out-Null }
$p = Start-Process -FilePath $Waku -PassThru -WorkingDirectory (Split-Path $Waku) -ArgumentList (Join-Arguments $flags)
Write-Host "octalia started, pid $($p.Id)"
