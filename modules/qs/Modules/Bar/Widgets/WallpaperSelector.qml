import QtQuick 6.10
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property string iconColorKey: widgetSettings.iconColor !== undefined ? widgetSettings.iconColor : widgetMetadata.iconColor

  enabled: Settings.data.wallpaper.enabled
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  icon: "wallpaper-selector"
  colorBg: Style.capsuleColor
  colorFg: Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  readonly property bool engineMode: Settings.data.wallpaper.backend === "wallpaperEngine"

  NPopupContextMenu {
    id: contextMenu

    model: {
      var items = [];
      if (root.engineMode && WallpaperEngineService.available) {
        items.push({
                     "label": WallpaperEngineService.paused ? I18n.tr("actions.wallpaper-engine-play") : I18n.tr("actions.wallpaper-engine-pause"),
                     "action": "engine-pause",
                     "icon": WallpaperEngineService.paused ? "media-play" : "media-pause"
                   });
        items.push({
                     "label": WallpaperEngineService.muted ? I18n.tr("actions.wallpaper-engine-unmute") : I18n.tr("actions.wallpaper-engine-mute"),
                     "action": "engine-mute",
                     "icon": WallpaperEngineService.muted ? "volume" : "volume-mute"
                   });
        items.push({
                     "label": I18n.tr("actions.wallpaper-engine-stop"),
                     "action": "engine-stop",
                     "icon": "player-stop"
                   });
      }
      items.push({
                   "label": I18n.tr("actions.random-wallpaper"),
                   "action": "random-wallpaper",
                   "icon": "dice"
                 });
      items.push({
                   "label": root.engineMode ? I18n.tr("actions.use-windows-wallpaper") : I18n.tr("actions.use-wallpaper-engine"),
                   "action": "switch-backend",
                   "icon": "wallpaper-selector"
                 });
      items.push({
                   "label": I18n.tr("actions.widget-settings"),
                   "action": "widget-settings",
                   "icon": "settings"
                 });
      return items;
    }

    onTriggered: action => {
                   contextMenu.close();
                   PanelService.closeContextMenu(screen);

                   if (action === "engine-pause") {
                     WallpaperEngineService.togglePause();
                   } else if (action === "engine-mute") {
                     WallpaperEngineService.toggleMute();
                   } else if (action === "engine-stop") {
                     WallpaperEngineService.stop();
                   } else if (action === "switch-backend") {
                     Settings.data.wallpaper.backend = root.engineMode ? "windows" : "wallpaperEngine";
                   } else if (action === "random-wallpaper") {
                     if (root.engineMode)
                       WallpaperEngineService.applyRandom();
                     else
                       WallpaperService.setRandomWallpaper();
                   } else if (action === "widget-settings") {
                     BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                   }
                 }
  }

  onClicked: {
    var wallpaperPanel = PanelService.getPanel("wallpaperPanel", screen);
    if (Settings.data.wallpaper.panelPosition === "follow_bar") {
      wallpaperPanel?.toggle(this);
    } else {
      wallpaperPanel?.toggle();
    }
  }
  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
