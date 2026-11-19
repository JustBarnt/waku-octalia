pragma Singleton

import QtQuick 6.10
import Quickshell
import Quickshell.Io
import qs.Commons

// Wallpaper Engine as the wallpaper backend: lists the installed wallpapers (Workshop items plus
// Wallpaper Engine's own projects), applies one through its command line, and drives playback.
// Wallpaper Engine has no way to report pause or mute, so those two follow the last command sent.
Singleton {
  id: root

  readonly property bool active: Settings.data.wallpaper.enabled && Settings.data.wallpaper.backend === "wallpaperEngine"

  // Found by refresh(): the install folder (forward slashes) and the exe that takes -control.
  property string installDir: ""
  property string exePath: ""
  readonly property bool available: exePath !== ""

  // [{ id, title, type, source, dir, file, previewPath }], sorted by title. `file` is what
  // openWallpaper takes: the video or index.html for those types, project.json for the rest.
  property var items: []
  property bool scanning: false
  property bool scanned: false

  // The wallpaper Wallpaper Engine shows, from its config.json.
  property string currentFile: ""
  readonly property var currentItem: findItem(currentFile)
  readonly property string currentPreview: currentItem ? currentItem.previewPath : ""

  property bool paused: false
  property bool muted: false

  function init() {
    Logger.i("WallpaperEngine", "Service started");
    if (active)
      refresh();
  }

  onActiveChanged: {
    if (active && !scanned)
      refresh();
  }

  Connections {
    target: Settings.data.wallpaper
    function onWallpaperEngineDirectoryChanged() {
      if (root.active)
        root.refresh();
    }
  }

  function normalize(p) {
    return String(p || "").replace(/\\/g, "/").toLowerCase();
  }

  function findItem(file) {
    var f = normalize(file);
    if (f === "")
      return null;
    for (var i = 0; i < items.length; i++) {
      var dir = normalize(items[i].dir) + "/";
      if (f === normalize(items[i].file) || f.startsWith(dir))
        return items[i];
    }
    return null;
  }

  function nativePath(p) {
    return String(p).replace(/\//g, "\\");
  }

  // -EncodedCommand takes base64 of UTF-16LE, which keeps the script's quotes away from the
  // command-line quoting rules.
  function encodeCommand(script) {
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var bytes = [];
    for (var i = 0; i < script.length; i++) {
      var c = script.charCodeAt(i);
      bytes.push(c & 0xff, c >> 8);
    }
    var out = "";
    for (var j = 0; j < bytes.length; j += 3) {
      var n = (bytes[j] << 16) | ((bytes[j + 1] || 0) << 8) | (bytes[j + 2] || 0);
      out += chars[(n >> 18) & 63] + chars[(n >> 12) & 63];
      out += j + 1 < bytes.length ? chars[(n >> 6) & 63] : "=";
      out += j + 2 < bytes.length ? chars[n & 63] : "=";
    }
    return out;
  }

  function psQuote(s) {
    return "'" + String(s).replace(/'/g, "''") + "'";
  }

  // ---------------------------------------------------------------------------------------------
  // Discovery: the configured folder, else the running Wallpaper Engine, else every Steam library.
  function refresh() {
    if (scanProcess.running)
      return;
    var configured = Settings.preprocessPath(Settings.data.wallpaper.wallpaperEngineDirectory || "");
    var script = `
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$dir = ${psQuote(configured)}
$proc = Get-Process wallpaper64, wallpaper32 -ErrorAction SilentlyContinue | Where-Object { $_.Path } | Select-Object -First 1
if (-not $dir -and $proc) { $dir = Split-Path $proc.Path }
if (-not $dir) {
  $steam = (Get-ItemProperty 'HKCU:\\Software\\Valve\\Steam').SteamPath
  $libs = @()
  if ($steam) {
    $libs += $steam
    $vdf = Join-Path $steam 'steamapps\\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
      $libs += (Select-String -LiteralPath $vdf -Pattern '"path"\\s+"([^"]+)"').Matches | ForEach-Object { $_.Groups[1].Value.Replace('\\\\', '\\') }
    }
  }
  foreach ($l in $libs) {
    $c = Join-Path $l 'steamapps\\common\\wallpaper_engine'
    if (Test-Path -LiteralPath (Join-Path $c 'wallpaper64.exe')) { $dir = $c; break }
  }
}
$exe = ''
$items = New-Object System.Collections.ArrayList
if ($dir -and (Test-Path -LiteralPath $dir)) {
  $dir = (Resolve-Path -LiteralPath $dir).Path
  if ($proc -and ((Split-Path $proc.Path) -eq $dir)) { $exe = $proc.Path }
  elseif (Test-Path -LiteralPath (Join-Path $dir 'wallpaper64.exe')) { $exe = Join-Path $dir 'wallpaper64.exe' }
  elseif (Test-Path -LiteralPath (Join-Path $dir 'wallpaper32.exe')) { $exe = Join-Path $dir 'wallpaper32.exe' }
  $steamapps = Split-Path (Split-Path $dir)
  $roots = @(
    @{ p = (Join-Path $steamapps 'workshop\\content\\431960'); s = 'workshop' },
    @{ p = (Join-Path $dir 'projects\\myprojects'); s = 'mine' },
    @{ p = (Join-Path $dir 'projects\\defaultprojects'); s = 'default' })
  foreach ($r in $roots) {
    Get-ChildItem -LiteralPath $r.p -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $pj = Join-Path $_.FullName 'project.json'
      if (-not (Test-Path -LiteralPath $pj)) { return }
      try { $j = Get-Content -LiteralPath $pj -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return }
      if (-not $j -or -not $j.file) { return }
      $type = ([string]$j.type).ToLower()
      $file = if ($type -eq 'video' -or $type -eq 'web') { Join-Path $_.FullName $j.file } else { $pj }
      $preview = ''
      if ($j.preview) { $pv = Join-Path $_.FullName $j.preview; if (Test-Path -LiteralPath $pv) { $preview = $pv } }
      $title = if ($j.title) { [string]$j.title } else { $_.Name }
      [void]$items.Add(@{ id = $_.Name; title = $title; type = $type; source = $r.s;
        dir = $_.FullName.Replace('\\', '/'); file = $file.Replace('\\', '/'); previewPath = $preview.Replace('\\', '/') })
    }
  }
}
@{ dir = ([string]$dir).Replace('\\', '/'); exe = $exe; items = $items } | ConvertTo-Json -Compress -Depth 4
`;
    scanning = true;
    scanProcess.command = ["powershell", "-NoProfile", "-NonInteractive", "-EncodedCommand", encodeCommand(script)];
    scanProcess.running = true;
  }

  Process {
    id: scanProcess
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: exitCode => {
      root.scanning = false;
      root.scanned = true;
      var out = String(scanProcess.stdout.text || "").trim();
      var result = null;
      try {
        result = out !== "" ? JSON.parse(out) : null;
      } catch (e) {
        Logger.w("WallpaperEngine", "Could not read the scan output:", e);
      }
      if (!result) {
        Logger.w("WallpaperEngine", "Scan failed with code", exitCode, String(scanProcess.stderr.text || "").trim());
        return;
      }
      root.installDir = result.dir || "";
      root.exePath = result.exe || "";
      var list = result.items || [];
      list.sort((a, b) => String(a.title).localeCompare(String(b.title)));
      root.items = list;
      Logger.i("WallpaperEngine", "Found", list.length, "wallpapers in", root.installDir || "(not installed)");
      if (!root.available)
        Logger.w("WallpaperEngine", "wallpaper64.exe not found; set the Wallpaper Engine folder in the wallpaper settings");
    }
  }

  // Wallpaper Engine writes its current wallpaper to config.json; watching it keeps the picker and
  // the colours right when the wallpaper is changed in Wallpaper Engine itself.
  FileView {
    id: configFile
    path: root.installDir !== "" ? root.installDir + "/config.json" : ""
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.readConfig(text())
    onPathChanged: {
      if (path !== "")
        reload();
    }
  }

  function readConfig(text) {
    var cfg;
    try {
      cfg = JSON.parse(text);
    } catch (e) {
      return;
    }
    for (var user in cfg) {
      if (user.startsWith("?"))
        continue;
      var selected = cfg[user]?.general?.wallpaperconfig?.selectedwallpapers;
      if (!selected)
        continue;
      for (var monitor in selected) {
        var file = selected[monitor]?.file;
        if (file) {
          if (normalize(file) !== normalize(currentFile))
            currentFile = file;
          return;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------------------------
  // Commands
  function control(args) {
    if (!available) {
      Logger.w("WallpaperEngine", "Wallpaper Engine not found; command dropped:", args.join(" "));
      return false;
    }
    Quickshell.execDetached([nativePath(exePath), "-control"].concat(args));
    return true;
  }

  function apply(item) {
    if (!item || !control(["openWallpaper", "-file", nativePath(item.file)]))
      return;
    Logger.i("WallpaperEngine", "Applying", item.title, item.file);
    currentFile = item.file;
    paused = false;
  }

  function play() {
    if (control(["play"]))
      paused = false;
  }

  function pause() {
    if (control(["pause"]))
      paused = true;
  }

  function togglePause() {
    paused ? play() : pause();
  }

  function stop() {
    if (control(["stop"]))
      paused = true;
  }

  function toggleMute() {
    if (control([muted ? "unmute" : "mute"]))
      muted = !muted;
  }

  function applyRandom() {
    if (items.length === 0)
      return;
    var pool = items.filter(it => it !== currentItem);
    if (pool.length === 0)
      pool = items;
    apply(pool[Math.floor(Math.random() * pool.length)]);
  }
}
