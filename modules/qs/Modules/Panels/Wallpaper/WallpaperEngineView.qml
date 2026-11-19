import QtQuick 6.10
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

// The wallpaper panel's Wallpaper Engine page: playback controls over a grid of the installed
// wallpapers. Picking one applies it through Wallpaper Engine.
Item {
  id: root

  property string filterText: ""
  property int columns: 4
  property alias gridView: grid

  ListModel {
    id: engineModel
  }

  function rebuild() {
    var needle = filterText.trim().toLowerCase();
    engineModel.clear();
    var list = WallpaperEngineService.items;
    for (var i = 0; i < list.length; i++) {
      var it = list[i];
      if (needle !== "" && String(it.title).toLowerCase().indexOf(needle) < 0)
        continue;
      engineModel.append({
                           "path": it.file,
                           "title": it.title,
                           "previewPath": it.previewPath,
                           "type": it.type,
                           "isDirectory": false
                         });
    }
  }

  // Same shape as the local view's selectItem, so the panel's Enter key works on either.
  function selectItem(path, isDirectory) {
    var list = WallpaperEngineService.items;
    for (var i = 0; i < list.length; i++) {
      if (list[i].file === path) {
        WallpaperEngineService.apply(list[i]);
        return;
      }
    }
  }

  onFilterTextChanged: rebuild()
  Component.onCompleted: {
    rebuild();
    if (!WallpaperEngineService.scanned)
      WallpaperEngineService.refresh();
  }

  Connections {
    target: WallpaperEngineService
    function onItemsChanged() {
      root.rebuild();
    }
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.marginM

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        elide: Text.ElideRight
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        text: {
          if (!WallpaperEngineService.scanned || WallpaperEngineService.scanning)
            return I18n.tr("wallpaper.engine.scanning");
          if (!WallpaperEngineService.available)
            return I18n.tr("wallpaper.engine.not-found");
          var cur = WallpaperEngineService.currentItem;
          return cur ? cur.title : I18n.tr("wallpaper.engine.count", {
                                              "count": WallpaperEngineService.items.length
                                            });
        }
      }

      NIconButton {
        enabled: WallpaperEngineService.available
        icon: WallpaperEngineService.paused ? "media-play" : "media-pause"
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: WallpaperEngineService.togglePause()
      }

      NIconButton {
        enabled: WallpaperEngineService.available
        icon: WallpaperEngineService.muted ? "volume-mute" : "volume"
        baseSize: Style.baseWidgetSize * 0.8
        colorBg: WallpaperEngineService.muted ? Color.mPrimary : Color.smartAlpha(Color.mSurfaceVariant)
        colorFg: WallpaperEngineService.muted ? Color.mOnPrimary : Color.mPrimary
        onClicked: WallpaperEngineService.toggleMute()
      }

      NIconButton {
        enabled: WallpaperEngineService.available
        icon: "player-stop"
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: WallpaperEngineService.stop()
      }

      NIconButton {
        enabled: WallpaperEngineService.available && WallpaperEngineService.items.length > 0
        icon: "dice"
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: WallpaperEngineService.applyRandom()
      }

      NIconButton {
        enabled: !WallpaperEngineService.scanning
        icon: "refresh"
        baseSize: Style.baseWidgetSize * 0.8
        onClicked: WallpaperEngineService.refresh()
      }
    }

    NGridView {
      id: grid

      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: engineModel.count > 0
      interactive: true
      keyNavigationEnabled: true
      keyNavigationWraps: false
      highlightFollowsCurrentItem: false
      currentIndex: -1
      model: engineModel

      property int columns: root.columns
      property int itemSize: cellWidth

      cellWidth: Math.floor((availableWidth - leftMargin - rightMargin) / columns)
      cellHeight: Math.floor(itemSize * 0.7) + Style.marginXS + Style.fontSizeXS + Style.marginM

      leftMargin: Style.marginS
      rightMargin: Style.marginS
      topMargin: Style.marginS
      bottomMargin: Style.marginS

      onCurrentIndexChanged: {
        if (currentIndex >= 0)
          positionViewAtIndex(currentIndex, GridView.Contain);
      }

      delegate: Item {
        id: cell
        width: grid.cellWidth
        height: grid.cellHeight

        required property int index
        required property string path
        required property string title
        required property string previewPath
        required property string type

        readonly property bool isSelected: {
          var cur = WallpaperEngineService.currentItem;
          return cur !== null && cur.file === cell.path;
        }
        property string cachedPath: ""

        Component.onCompleted: {
          if (previewPath === "")
            return;
          // Thumbnails are still images, so animated previews don't all play at once.
          if (ImageCacheService.initialized) {
            ImageCacheService.getThumbnail(previewPath, function (thumb, success) {
              if (cell)
                cell.cachedPath = success ? thumb : cell.previewPath;
            });
          } else {
            cachedPath = previewPath;
          }
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginXS
          spacing: Style.marginXS

          Item {
            id: imageContainer
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property real imageHeight: Math.round(grid.itemSize * 0.67)

            NImageRounded {
              id: img
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: imageContainer.imageHeight
              imagePath: cell.cachedPath
              radius: Style.radiusM
              borderColor: cell.isSelected ? Color.mSecondary : (grid.currentIndex === cell.index ? Color.mHover : Color.mSurface)
              borderWidth: Math.max(1, Style.borderL * 1.5)
              imageFillMode: Image.PreserveAspectCrop
            }

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: imageContainer.imageHeight
              color: Color.mSurfaceVariant
              radius: Style.radiusM
              visible: cell.cachedPath === "" || img.status === Image.Error

              NIcon {
                icon: "image"
                pointSize: Style.fontSizeL
                color: Color.mOnSurfaceVariant
                anchors.centerIn: parent
              }
            }

            Rectangle {
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: Style.marginS
              width: 28
              height: 28
              radius: width / 2
              z: 6
              color: Color.mSecondary
              border.color: Color.mOutline
              border.width: Style.borderS
              visible: cell.isSelected

              NIcon {
                icon: "check"
                pointSize: Style.fontSizeM
                color: Color.mOnSecondary
                anchors.centerIn: parent
              }
            }

            // Scene, video or web, bottom-left on the preview.
            Rectangle {
              anchors.left: parent.left
              anchors.top: parent.top
              anchors.leftMargin: Style.marginS
              anchors.topMargin: imageContainer.imageHeight - height - Style.marginS
              visible: cell.type !== "" && hover.hovered
              radius: Style.radiusS
              color: Color.mSurface
              opacity: 0.85
              implicitWidth: typeText.implicitWidth + Style.marginM
              implicitHeight: typeText.implicitHeight + Style.marginXS

              NText {
                id: typeText
                anchors.centerIn: parent
                text: cell.type
                pointSize: Style.fontSizeXS
                color: Color.mOnSurface
              }
            }

            HoverHandler {
              id: hover
            }

            TapHandler {
              onTapped: {
                grid.forceActiveFocus();
                grid.currentIndex = cell.index;
                root.selectItem(cell.path, false);
              }
            }
          }

          NText {
            text: cell.title
            visible: !Settings.data.wallpaper.hideWallpaperFilenames
            color: (hover.hovered || cell.isSelected || grid.currentIndex === cell.index) ? Color.mOnSurface : Color.mOnSurfaceVariant
            pointSize: Style.fontSizeXS
            Layout.fillWidth: true
            Layout.leftMargin: Style.marginS
            Layout.rightMargin: Style.marginS
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }

    // Scanning, nothing installed, or nothing matching the search.
    Rectangle {
      visible: engineModel.count === 0
      color: Color.mSurface
      radius: Style.radiusM
      border.color: Color.mOutline
      border.width: Style.borderS
      Layout.fillWidth: true
      Layout.preferredHeight: 130

      NBusyIndicator {
        anchors.centerIn: parent
        visible: WallpaperEngineService.scanning
        running: visible
      }

      ColumnLayout {
        anchors.centerIn: parent
        visible: !WallpaperEngineService.scanning
        spacing: Style.marginS

        NIcon {
          icon: WallpaperEngineService.available ? "image" : "alert-circle"
          pointSize: Style.fontSizeXXL
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignHCenter
        }
        NText {
          text: !WallpaperEngineService.available ? I18n.tr("wallpaper.engine.not-found") : (root.filterText !== "" ? I18n.tr("wallpaper.no-match") : I18n.tr("wallpaper.engine.empty"))
          color: Color.mOnSurface
          font.weight: Style.fontWeightBold
          Layout.alignment: Qt.AlignHCenter
        }
        NText {
          visible: !WallpaperEngineService.available
          text: I18n.tr("wallpaper.engine.not-found-hint")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          Layout.alignment: Qt.AlignHCenter
        }
      }
    }
  }
}
