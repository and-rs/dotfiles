import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell
import QtQuick
import qs.Bar

Scope {
  id: notifScope
  required property var mainHeight
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: root
      exclusiveZone: -1
      implicitWidth: 370
      implicitHeight: cardColumn.implicitHeight
      color: "transparent"

      required property var modelData
      screen: modelData

      margins.top: notifScope.mainHeight + Config.spacing.small
      anchors.top: true
      anchors.right: true

      Component.onCompleted: {
        if (WlrLayershell != null)
          WlrLayershell.namespace = "quickshell-hidden";
      }

      NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
          console.log("New notification:", JSON.stringify(notification, null, 2));
          notification.tracked = true;
        }

        function dismiss(id) {
          for (const n of trackedNotifications.values) {
            if (n.id === id) {
              n.dismiss();
              return;
            }
          }
        }
      }

      Column {
        id: cardColumn
        width: parent.width
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Config.spacing.normal

        Repeater {
          model: server.trackedNotifications
          delegate: NotificationCard {
            onDismissRequested: server.dismiss(modelData.id)
          }
        }
      }
    }
  }
}
