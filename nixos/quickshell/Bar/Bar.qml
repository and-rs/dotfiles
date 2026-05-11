import Quickshell
import QtQuick
import qs.Lock
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
      readonly property bool popupsBlocked: LockService.locked

      function closePopups() {
        _pendingPopup = "";
        activePopup = "";
      }

      function switchPopup(id) {
        if (popupsBlocked) {
          closePopups();
          return;
        }
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

      Connections {
        target: LockService

        function onLockedChanged() {
          if (LockService.locked)
            main.closePopups();
        }
      }

      Timer {
        interval: 50
        running: main._pendingPopup !== "" && !main.popupsBlocked
        onTriggered: {
          if (main.popupsBlocked) {
            main._pendingPopup = "";
            return;
          }
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
        color: Config.colors.base
        Rectangle {
          id: bottomBorder
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 2
          color: Config.colors.surface1
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
            color: Config.colors.surface2
            anchors.verticalCenter: parent.verticalCenter
          }
          Tray {
            id: tray
            window: main
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
