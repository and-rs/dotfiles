import Quickshell.Wayland
import Quickshell
import QtQuick

Scope {
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: notifPanel
      required property var modelData

      Component.onCompleted: {
        if (this.WlrLayershell != null) {
          this.WlrLayershell.namespace = "quickshell-hidden";
        }
      }

      color: "transparent"
      exclusiveZone: -1
      screen: modelData
      visible: notifWindow.hasNotifications

      anchors {
        top: true
        right: true
      }
      implicitWidth: notifWindow.width
      implicitHeight: notifWindow.height

      mask: Region {
        Region {
          x: notifPanel.width - 400
          y: 0
          width: 400
          height: notifWindow.hasNotifications ? notifWindow.height : 1
        }
      }

      Item {
        anchors.fill: parent

        NotificationWindow {
          id: notifWindow
          anchors.top: parent.top
          anchors.right: parent.right
          property bool hasNotifications: queue.length > 0
        }
      }
    }
  }
}
