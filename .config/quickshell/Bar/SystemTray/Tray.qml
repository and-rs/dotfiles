import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import qs.Bar

Rectangle {
  id: trayRect
  width: 22
  height: 22
  color: "transparent"

  required property PanelWindow window
  readonly property bool hasItems: trayRepeater.count > 0

  TrayIcon {
    condition: hasItems
  }

  PopupWindow {
    id: overlay
    anchor.window: trayRect.window
    implicitWidth: screen.width
    implicitHeight: screen.height
    visible: popupVisible
    color: "transparent"

    Item {
      id: popupHole
      x: trayPopup.anchor.rect.x
      y: trayPopup.anchor.rect.y
      width: trayPopup.width
      height: trayPopup.height
    }

    mask: Region {
      item: popupHole
      intersection: Intersection.Xor
    }

    MouseArea {
      anchors.fill: parent
      onClicked: popupVisible = false
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (hasItems)
      popupVisible = !popupVisible
  }

  property bool popupVisible: false

  PopupWindow {
    id: trayPopup
    anchor.window: trayRect.window

    anchor.rect.x: parent.x + trayRect.width / 2 - implicitWidth / 2
    anchor.rect.y: parentWindow.height + 4

    implicitWidth: trayRow.implicitWidth + 16
    implicitHeight: trayRow.implicitHeight + 16
    visible: popupVisible || content.opacity > 0
    color: "transparent"

    Item {
      id: content
      anchors.fill: parent
      opacity: popupVisible ? 1 : 0

      Behavior on opacity {
        NumberAnimation {
          duration: Config.durations.fast
          easing.type: Easing.OutCubic
        }
      }

      Rectangle {
        anchors.fill: parent
        color: Config.colors.bg
        border.color: Config.colors.accent
        border.width: 2
        radius: 8
      }

      Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 4

        Repeater {
          id: trayRepeater
          model: SystemTray.items
          delegate: Row {
            padding: Config.padding.extraSmall
            Image {
              readonly property string resolvedIcon: {
                const icon = modelData.icon;
                if (!icon || !icon.includes("?path="))
                  return icon;
                const [name, path] = icon.split("?path=");
                return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
              }

              source: resolvedIcon
              width: 18
              height: 18
              sourceSize.width: 32
              sourceSize.height: 32
              smooth: true
              antialiasing: true
            }
          }
        }
      }
    }
  }
}
