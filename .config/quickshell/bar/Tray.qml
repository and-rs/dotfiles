import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import QtQuick.Controls

Rectangle {
  id: trayRect
  width: 22
  height: 22
  color: "transparent"

  MaterialIcon {
    id: trayIcon
    text: trayPopup.visible ? "\ue698" : "\ue69b"
  }

  MouseArea {
    anchors.fill: parent
    onClicked: trayPopup.visible = !trayPopup.visible
  }

  PopupWindow {
    id: trayPopup
    anchor.window: main

    anchor.rect.x: parent.x + trayRect.width / 2 - implicitWidth / 2
    anchor.rect.y: parentWindow.height - 2

    implicitWidth: trayRow.width + 8
    implicitHeight: trayRow.height + 8
    visible: false
    color: "transparent"

    Item {
      anchors.fill: parent
      Rectangle {
        anchors.fill: parent
        color: Config.colors.bg

        anchors.topMargin: -border.width
        border.color: Config.colors.dim
        border.width: 2

        bottomRightRadius: 8
        bottomLeftRadius: 8
      }
    }

    Row {
      id: trayRow
      anchors.centerIn: parent
      Repeater {
        model: SystemTray.items
        delegate: Row {
          id: root
          padding: 5
          Image {
            function getTrayIcon(icon: string): string {
              if (icon.includes("?path=")) {
                const [name, path] = icon.split("?path=");
                icon = Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
              }
              return icon;
            }

            source: getTrayIcon(modelData.icon)
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
