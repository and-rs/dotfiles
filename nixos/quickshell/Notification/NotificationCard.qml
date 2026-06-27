import QtQuick
import qs.Bar
import qs.Notification

Rectangle {
  id: root

  required property var entry
  property bool compact: false
  readonly property string appName: entry ? entry.appName : ""
  readonly property string summary: entry ? entry.summary : ""
  readonly property string body: entry ? entry.body : ""
  readonly property string image: entry ? entry.image : ""
  readonly property string appIcon: entry ? entry.appIcon : ""
  readonly property bool isClosed: entry ? entry.closed : false
  readonly property int notificationId: entry ? entry.id : -1
  readonly property bool hasDefaultAction: NotificationStore.hasDefaultAction(notificationId)
  readonly property int bodyLineLimit: compact ? 4 : 10

  signal closeRequested(notificationId: int)

  implicitHeight: contentColumn.implicitHeight + Config.padding.large * 2
  color: Config.colors.base
  border.width: 2
  border.color: Config.colors.surface2
  radius: Config.radius.normal

  Column {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: Config.padding.large
    spacing: Config.spacing.normal

    Row {
      width: parent.width
      spacing: Config.spacing.normal

      IconFallback {
        id: previewIcon
        size: compact ? 48 : 56
        expandToAspect: true
        image: root.image || root.appIcon
        fallbackText: root.appName ? root.appName.charAt(0).toUpperCase() : ""
      }

      Column {
        width: parent.width - previewIcon.width - closeButton.width - (activateButton.visible ? activateButton.width : 0) - parent.spacing * (activateButton.visible ? 3 : 2)
        spacing: Config.spacing.extraSmall

        Text {
          width: parent.width
          text: root.appName
          visible: text !== ""
          color: Config.colors.primary
          font.pixelSize: Config.sizes.small
          font.weight: Font.Medium
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Text {
          width: parent.width
          text: root.summary
          color: Config.colors.fg
          font.pixelSize: Config.sizes.normal
          font.weight: Font.Medium
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: compact ? 2 : 3
          textFormat: Text.PlainText
        }
      }

      Rectangle {
        id: activateButton
        width: 20
        height: 20
        visible: root.hasDefaultAction && !root.isClosed
        radius: Config.radius.full
        color: activateArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1

        MaterialIcon {
          anchors.centerIn: parent
          code: 0xE5C8
          iconColor: activateArea.containsMouse ? Config.colors.base : Config.colors.primary
          iconSize: 11
        }

        MouseArea {
          id: activateArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: NotificationStore.invokeDefaultAction(root.notificationId)
        }
      }

      Rectangle {
        id: closeButton
        width: 20
        height: 20
        radius: Config.radius.full
        color: closeArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1

        MaterialIcon {
          anchors.centerIn: parent
          code: 0xE4F6
          iconColor: closeArea.containsMouse ? Config.colors.base : Config.colors.primary
          iconSize: 10
        }

        MouseArea {
          id: closeArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.closeRequested(root.notificationId)
        }
      }
    }

    Text {
      width: parent.width
      text: root.body
      visible: text !== ""
      color: Config.colors.fg
      font.pixelSize: Config.sizes.normal
      wrapMode: Text.Wrap
      maximumLineCount: root.bodyLineLimit
      textFormat: Text.RichText
    }

    NotificationActions {
      width: parent.width
      entry: root.entry
      compact: root.compact
    }

    Text {
      width: parent.width
      visible: root.isClosed
      text: "Closed notification"
      color: Config.colors.surface4
      font.pixelSize: Config.sizes.small
      font.weight: Font.Medium
      textFormat: Text.PlainText
    }
  }
}
