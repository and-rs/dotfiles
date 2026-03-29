import QtQuick
import qs.Bar

Rectangle {
  id: root
  required property var modelData
  property var notification: modelData
  signal dismissRequested

  width: parent.width - Config.spacing.small
  height: contentCol.implicitHeight + Config.padding.large * 2
  color: Config.colors.bg

  border.width: 2
  border.color: Config.colors.muted
  radius: Config.radius.normal

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.dismissRequested();
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
        image: root.notification?.image || root.notification?.appIcon || ""
        fallbackText: root.notification?.appName ? root.notification.appName.charAt(0).toUpperCase() : ""
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
            visible: (root.notification?.image || "") !== "" && (root.notification?.appIcon || "") !== "" && appIconImage.status !== Image.Error
            anchors.verticalCenter: parent.verticalCenter

            Image {
              id: appIconImage
              width: Config.sizes.normal
              height: Config.sizes.normal
              source: root.notification?.appIcon || ""
              fillMode: Image.PreserveAspectFit
              visible: status === Image.Ready
            }
          }

          Text {
            text: root.notification?.appName || ""
            font.pixelSize: Config.sizes.normal
            font.weight: Font.Medium
            color: Config.colors.primary
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Text {
          width: parent.width
          text: root.notification?.summary || ""
          font.pixelSize: Config.sizes.normal
          font.weight: Font.Medium
          color: Config.colors.fg
          elide: Text.ElideRight
        }
      }
    }

    Text {
      width: parent.width
      text: root.notification?.body
      visible: text !== ""
      linkColor: Config.colors.primary
      onLinkActivated: link => Qt.openUrlExternally(link)
      font.pixelSize: Config.sizes.normal
      color: Config.colors.fg
      wrapMode: Text.Wrap
    }
  }
}
