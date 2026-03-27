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
      implicitHeight: cardColumn.implicitHeight + Config.spacing.normal
      color: "transparent"

      required property var modelData
      screen: modelData

      margins.top: notifScope.mainHeight
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
          // console.log("New notification:", JSON.stringify(notification, null, 2));
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
        anchors.right: parent.right
        anchors.top: parent.top

        Repeater {
          model: server.trackedNotifications

          Rectangle {
            width: root.width
            height: contentCol.implicitHeight + Config.padding.large * 2
            color: Config.colors.bg
            border.width: 2
            border.color: Config.colors.dim

            property string extractedLink: {
              const match = modelData.body.match(/<a[^>]*>([^<]+)<\/a>/);
              return match ? match[1] : "";
            }

            property string plainBody: modelData.body.replace(/<a[^>]*>[^<]*<\/a>/g, "").trim()

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              cursorShape: Qt.PointingHandCursor
              onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                  server.dismiss(modelData.id);
              }
            }

            Column {
              id: contentCol
              anchors.fill: parent
              anchors.margins: Config.padding.large
              spacing: Config.spacing.normal

              Row {
                width: parent.width
                spacing: Config.spacing.normal

                IconFallback {
                  size: 48
                  image: modelData.image || modelData.appIcon
                  fallbackText: modelData.appName.charAt(0).toUpperCase()
                }

                Column {
                  width: parent.width
                  spacing: Config.spacing.extraSmall
                  anchors.verticalCenter: parent.verticalCenter

                  Row {
                    spacing: 8

                    Item {
                      width: appIconImage.width
                      height: appIconImage.height
                      visible: modelData.image !== "" && modelData.appIcon !== "" && appIconImage.status !== Image.Error
                      anchors.verticalCenter: parent.verticalCenter

                      Image {
                        id: appIconImage
                        width: Config.sizes.normal
                        height: Config.sizes.normal
                        source: modelData.appIcon
                        fillMode: Image.PreserveAspectFit
                        visible: status === Image.Ready
                      }
                    }

                    Text {
                      text: modelData.appName
                      font.pixelSize: Config.sizes.normal
                      font.weight: Font.Medium
                      color: Config.colors.primary
                      elide: Text.ElideRight
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      text: extractedLink
                      visible: extractedLink !== ""
                      font.pixelSize: Config.sizes.normal
                      color: Config.colors.accent
                      elide: Text.ElideRight
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  Text {
                    width: parent.width
                    text: modelData.summary
                    font.pixelSize: Config.sizes.normal
                    font.weight: Font.Medium
                    color: Config.colors.fg
                    elide: Text.ElideRight
                  }
                }
              }

              Text {
                width: parent.width
                text: plainBody
                visible: text !== ""
                linkColor: Config.colors.primary
                onLinkActivated: link => Qt.openUrlExternally(link)
                font.pixelSize: Config.sizes.normal
                color: Config.colors.fg
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
              }
            }
          }
        }
      }
    }
  }

  component IconFallback: Rectangle {
    required property string image
    required property string fallbackText
    property int size: 48

    width: size
    height: size
    clip: true
    radius: Config.radius.small
    color: Config.colors.dim

    Image {
      anchors.fill: parent
      source: parent.image
      visible: status === Image.Ready
    }

    Text {
      anchors.centerIn: parent
      text: parent.fallbackText
      font.pixelSize: Config.sizes.large
      font.weight: Font.Bold
      color: Config.colors.light
      visible: !parent.image
    }
  }
}
