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
      implicitHeight: listView.height
      color: "transparent"

      required property var modelData
      screen: modelData

      readonly property int animDuration: 75
      readonly property int animEasing: Easing.OutExpo

      margins.top: notifScope.mainHeight + Config.spacing.small
      margins.right: Config.spacing.small
      anchors.top: true
      anchors.right: true

      Component.onCompleted: {
        if (WlrLayershell != null) {
          WlrLayershell.namespace = "quickshell-hidden";
          WlrLayershell.layer = WlrLayer.Overlay;
        }
      }

      NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
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

      ListView {
        id: listView
        width: parent.width
        interactive: false
        clip: true

        HoverHandler {
          id: hoverHandler
        }

        property int maxStacked: 3
        property real firstHeight: 0
        property int stackTailHeight: 10
        property real collapsedStackOpacity: 0.85
        property bool isExpanded: hoverHandler.hovered

        height: isExpanded ? contentHeight : count > 0 ? firstHeight + Math.min(count - 1, maxStacked) * stackTailHeight : 0
        spacing: isExpanded ? Config.spacing.normal : 0
        opacity: isExpanded ? 1.0 : collapsedStackOpacity

        Behavior on spacing {
          NumberAnimation {
            duration: root.animDuration
            easing.type: root.animEasing
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: root.animDuration
            easing.type: root.animEasing
          }
        }

        add: Transition {
          NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: root.animDuration
            easing.type: root.animEasing
          }

          NumberAnimation {
            property: "x"
            from: 20
            to: 0
            duration: root.animDuration
            easing.type: root.animEasing
          }
        }

        remove: Transition {
          NumberAnimation {
            property: "opacity"
            to: 0
            duration: root.animDuration
            easing.type: root.animEasing
          }

          NumberAnimation {
            property: "scale"
            to: 0.92
            duration: root.animDuration
            easing.type: root.animEasing
          }
        }

        displaced: Transition {
          NumberAnimation {
            property: "y"
            duration: root.animDuration
            easing.type: root.animEasing
          }
        }

        model: server.trackedNotifications

        delegate: Item {
          id: wrapper
          width: listView.width
          z: 100 - index

          property var cardModel: modelData
          property bool isExpanded: listView.isExpanded
          property bool isFirst: index === 0
          property bool isVisibleInStack: index <= listView.maxStacked
          property bool shouldClip: !isExpanded && !isFirst && isVisibleInStack

          clip: shouldClip

          height: isExpanded ? card.height : isFirst ? card.height : isVisibleInStack ? listView.stackTailHeight : 0

          Behavior on height {
            NumberAnimation {
              duration: root.animDuration
              easing.type: root.animEasing
            }
          }

          onIsFirstChanged: {
            if (isFirst)
              listView.firstHeight = card.height;
          }

          Connections {
            target: card

            function onHeightChanged() {
              if (wrapper.isFirst)
                listView.firstHeight = card.height;
            }
          }

          Component.onCompleted: {
            if (isFirst)
              listView.firstHeight = card.height;
          }

          NotificationCard {
            id: card
            width: parent.width
            modelData: wrapper.cardModel

            onDismissRequested: server.dismiss(wrapper.cardModel.id)

            scale: isExpanded ? 1.0 : Math.max(0.85, 1.0 - index * 0.05)
            opacity: isExpanded ? 1.0 : index <= listView.maxStacked ? 1.0 - index * 0.1 : 0.0
            transformOrigin: Item.Bottom

            Behavior on scale {
              NumberAnimation {
                duration: root.animDuration
                easing.type: root.animEasing
              }
            }

            Behavior on opacity {
              NumberAnimation {
                duration: root.animDuration
                easing.type: root.animEasing
              }
            }

            property real desiredAbsY: {
              if (isExpanded || wrapper.isFirst)
                return wrapper.y;
              return (listView.firstHeight + index * listView.stackTailHeight - card.height);
            }

            transform: Translate {
              y: card.desiredAbsY - wrapper.y

              Behavior on y {
                NumberAnimation {
                  duration: root.animDuration
                  easing.type: root.animEasing
                }
              }
            }
          }
        }
      }
    }
  }
}
