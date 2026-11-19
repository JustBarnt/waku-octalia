# Starts Octalia when you sign in, with waku's own `wakuc startup enable`: a per-user Scheduled Task
# that runs waku.exe on this folder (and a second one for wakukeys, because keys.conf is here).
# No admin rights are needed.
#
#   .\install-startup.ps1            register the tasks (again: replaces them)
#   .\install-startup.ps1 -Log       the same, and waku writes logs\waku.log on every start
#   .\install-startup.ps1 -Status    show the tasks and the stored environment
#   .\install-startup.ps1 -Remove    remove the tasks and the stored environment
#   .\install-startup.ps1 -DryRun    print what would change, change nothing
#
# The task runs waku.exe directly, not start.ps1, so it cannot set environment variables itself.
# This script stores Octalia's (tools\env.ps1) in your user environment, where the task finds them
# from your next sign-in. waku.exe and wakukeys.exe must be on your PATH; the task runs the ones the
# PATH finds when you sign in.
param(
  [switch]$Log,
  [switch]$Status,
  [switch]$Remove,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'tools\env.ps1')

# The wakuc next to the waku.exe on PATH, so the task and the command come from the same install.
$waku = (Get-Command waku.exe -ErrorAction SilentlyContinue).Source
if (-not $waku) { throw 'waku.exe is not on your PATH. The sign-in task runs the waku.exe the PATH finds; add its folder first.' }
$wakuc = Join-Path (Split-Path $waku) 'wakuc.exe'
if (-not (Test-Path $wakuc)) {
  $wakuc = (Get-Command wakuc.exe -ErrorAction SilentlyContinue).Source
  if (-not $wakuc) { throw "wakuc.exe was found neither next to $waku nor on PATH." }
}

function Show-Environment {
  foreach ($name in $OctaliaEnv.Keys) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
    Write-Host ("{0} = {1}" -f $name, $(if ($value) { $value } else { '(not set)' }))
  }
}

if ($Status) {
  & $wakuc startup status
  Show-Environment
  return
}

if ($Remove) {
  if ($DryRun) {
    Write-Host "would run: `"$wakuc`" startup disable"
    foreach ($name in $OctaliaEnv.Keys) { Write-Host "would remove the user variable $name" }
    return
  }
  & $wakuc startup disable
  foreach ($name in $OctaliaEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $null, 'User') }
  Write-Host 'removed the sign-in tasks and the stored environment'
  return
}

$flags = @() + $OctaliaFlags
if ($Log) { $flags += @('--log-file', (Join-Path $OctaliaRoot 'logs\waku.log')) }
$arguments = @('--config-home', $OctaliaRoot, 'startup', 'enable', '--') + $flags

if ($DryRun) {
  foreach ($e in $OctaliaEnv.GetEnumerator()) { Write-Host "would set the user variable $($e.Key)=$($e.Value)" }
  Write-Host "would run: `"$wakuc`" $(Join-Arguments $arguments)"
  return
}
foreach ($e in $OctaliaEnv.GetEnumerator()) {
  [Environment]::SetEnvironmentVariable($e.Key, $e.Value, 'User')
  Set-Item -Path "env:$($e.Key)" -Value $e.Value  # this session too
}
New-Item -ItemType Directory -Force @($OctaliaEnv.Values) | Out-Null
if ($Log) { New-Item -ItemType Directory -Force (Join-Path $OctaliaRoot 'logs') | Out-Null }
& $wakuc @arguments
if ($LASTEXITCODE -ne 0) { throw "wakuc startup enable failed (exit $LASTEXITCODE)" }
Write-Host ''
Write-Host 'Octalia starts at your next sign-in. Run .\start.ps1 to start it now.'
