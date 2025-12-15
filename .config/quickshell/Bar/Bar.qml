import Quickshell
import QtQuick
import qs.Bar.SystemTray

Scope {
  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: main
      required property var modelData

      screen: modelData
      aboveWindows: true
      implicitHeight: 32
      color: "transparent"

      anchors {
        top: true
        left: true
        right: true
      }

      Rectangle {
        id: background
        anchors.fill: parent
        color: Config.colors.bg
      }

      Row {
        spacing: Config.spacing.normal
        padding: 4
        Workspaces {}
        WindowIndicator {}
        WindowTitle {}
      }

      Row {
        id: rightRect
        spacing: Config.spacing.large
        rightPadding: Config.spacing.large
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right

        Tray {
          id: tray
          window: main
        }

        Battery {}

        Text {
          anchors.verticalCenter: parent.verticalCenter
          color: Config.colors.fg
          text: Time.format("ddd d MMM hh:mm")
          font.weight: 500
          font.pointSize: 10
        }
      }
    }
  }
}
