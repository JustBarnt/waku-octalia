# Octalia's environment and waku flags, in one place: start.ps1 applies them to the waku it starts,
# install-startup.ps1 stores the variables in the user environment for the sign-in task. Dot-source
# it; it only sets variables in the caller's scope:
#   $OctaliaRoot   this folder (the config home: shell.qml is here)
#   $OctaliaEnv    the environment variables Octalia reads (an ordered hashtable)
#   $OctaliaFlags  the waku arguments Octalia needs, besides --config-home
$OctaliaRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Octalia keeps its config and cache inside this folder (state\ is not tracked by git).
$OctaliaEnv = [ordered]@{
  OCTALIA_CONFIG_DIR = Join-Path $OctaliaRoot 'state\config'
  OCTALIA_CACHE_DIR  = Join-Path $OctaliaRoot 'state\cache'
}
# --import-path: the qs.* modules live in modules\. directwrite: Octalia's fonts use variable axes.
$OctaliaFlags = @('--import-path', (Join-Path $OctaliaRoot 'modules'), '--font-engine=directwrite')

# waku.exe: -Waku, else $env:WAKU_EXE, else the one on PATH. Empty when none is found.
function Find-Waku([string]$Waku) {
  if ($Waku) { return $Waku }
  if ($env:WAKU_EXE) { return $env:WAKU_EXE }
  $found = Get-Command waku.exe -ErrorAction SilentlyContinue
  if ($found) { return $found.Source }
  return ''
}

# Start-Process joins an argument array with spaces and quotes nothing; quote what has a space.
function Join-Arguments([string[]]$Arguments) {
  ($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
}
