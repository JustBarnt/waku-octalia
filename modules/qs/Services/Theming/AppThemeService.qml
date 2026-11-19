pragma Singleton

import QtQuick 6.10
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.compat

Singleton {
  id: root

  Connections {
    target: WallpaperService

    // When the wallpaper changes, regenerate theme if necessary
    function onWallpaperChanged(screenName, path) {
      if (WallpaperEngineService.active)
        return;
      var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
      if (effectiveMonitor === "" || effectiveMonitor === undefined) {
        effectiveMonitor = Screen.name;
      }

      if (screenName !== effectiveMonitor)
        return;

      if (Settings.data.colorSchemes.useWallpaperColors) {
        generateFromWallpaper();
      } else if (ColorSchemeService.lastPredefinedSchemeData) {
        // Regenerate templates only; skip applyScheme so colors.json and scheme reload stay untouched
        // when outputs are unchanged (see template processor skip-identical writes).
        generateFromPredefinedScheme(ColorSchemeService.lastPredefinedSchemeData);
      } else {
        ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
      }
    }
  }

  Connections {
    target: WallpaperEngineService
    function onCurrentPreviewChanged() {
      if (WallpaperEngineService.active && Settings.data.colorSchemes.useWallpaperColors)
        root.generateFromWallpaper();
    }
    function onActiveChanged() {
      root.generate();
    }
  }

  Connections {
    target: Settings.data.colorSchemes
    function onDarkModeChanged() {
      Logger.d("AppThemeService", "Detected dark mode change");
      generate();
    }
    function onMonitorForColorsChanged() {
      if (Settings.data.colorSchemes.useWallpaperColors) {
        Logger.d("AppThemeService", "Monitor for colors changed to:", Settings.data.colorSchemes.monitorForColors);
        generateFromWallpaper();
      }
    }
    function onGenerationMethodChanged() {
      Logger.d("AppThemeService", "Generation method changed to:", Settings.data.colorSchemes.generationMethod);
      generate();
    }
  }

  // PUBLIC FUNCTIONS
  function init() {
    Logger.i("AppThemeService", "Service started");
  }

  function generate() {
    if (Settings.data.colorSchemes.useWallpaperColors) {
      generateFromWallpaper();
    } else {
      // applyScheme will trigger template generation via schemeReader.onLoaded
      ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
    }
  }

  function generateFromWallpaper() {
    if (WallpaperEngineService.active) {
      // Wallpaper Engine's preview image stands in for the moving wallpaper.
      const preview = WallpaperEngineService.currentPreview;
      if (preview === "") {
        Logger.d("AppThemeService", "No Wallpaper Engine preview yet");
        return;
      }
      TemplateProcessor.processWallpaperColors(preview, Settings.data.colorSchemes.darkMode ? "dark" : "light");
      return;
    }
    var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Screen.name;
    }

    const wp = WallpaperService.getWallpaper(effectiveMonitor);
    if (!wp) {
      Logger.e("AppThemeService", "No wallpaper found for monitor:", effectiveMonitor);
      return;
    }
    const mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    TemplateProcessor.processWallpaperColors(wp, mode);
  }

  function generateFromPredefinedScheme(schemeData) {
    Logger.i("AppThemeService", "Generating templates from predefined color scheme");
    const mode = Settings.data.colorSchemes.darkMode ? "dark" : "light";
    var effectiveMonitor = Settings.data.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Screen.name;
    }
    const wallpaperPath = WallpaperService.getWallpaper(effectiveMonitor) || "";
    TemplateProcessor.processPredefinedScheme(schemeData, mode, wallpaperPath);
  }
}
