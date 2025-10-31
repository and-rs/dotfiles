import Quickshell
import QtQuick

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

      // margins {
      //   top: 8
      //   right: 8
      //   left: 8
      // }

      anchors {
        top: true
        left: true
        right: true
      }

      Rectangle {
        id: background
        anchors.fill: parent
        color: Config.colors.bg
        // border.color: Config.colors.dim
        // border.width: 2
      }

      Workspaces {}

      Row {
        id: rightRect
        spacing: Config.spacing.larger
        rightPadding: Config.spacing.larger
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        Tray {}
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
