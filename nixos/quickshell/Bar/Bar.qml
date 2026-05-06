import Quickshell
import QtQuick
import qs.Bar.SystemTray
import qs.Bar.Recording

Scope {
  id: barScope
  required property var mainHeight

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: main
      required property var modelData
      property string activePopup: ""
      property string _pendingPopup: ""

      function switchPopup(id) {
        if (activePopup === id) {
          activePopup = "";
          return;
        }
        if (activePopup !== "") {
          _pendingPopup = id;
          activePopup = "";
        } else {
          activePopup = id;
        }
      }

      Timer {
        interval: 50
        running: main._pendingPopup !== ""
        onTriggered: {
          main.activePopup = main._pendingPopup;
          main._pendingPopup = "";
        }
      }

      screen: modelData
      aboveWindows: true
      implicitHeight: barScope.mainHeight
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
        Rectangle {
          id: bottomBorder
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 2
          color: Config.colors.dim
        }
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

        Row {
          id: buttons
          spacing: Config.spacing.small
          anchors.verticalCenter: parent.verticalCenter
          Recording {}
          Tray {
            id: tray
            window: main
          }
          Caffeine {
            id: caffeine
            window: main
          }
          LockButton {
            id: lockButton
            window: main
          }
          Rectangle {
            width: 2
            height: parent.height * 0.5
            color: Config.colors.muted
            anchors.verticalCenter: parent.verticalCenter
          }
          Bluetooth {
            id: bt
            window: main
          }
          Network {
            id: network
            window: main
          }
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
