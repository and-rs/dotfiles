import QtQuick
import qs.Bar

Rectangle {
  id: root

  property int activateIconCode: 0xE092
  property int activateIconSize: 11
  readonly property string appIcon: entry ? entry.appIcon : ""
  readonly property string appName: entry ? entry.appName : ""
  readonly property string body: entry ? entry.body : ""
  property int bodyLineLimit: compact ? 4 : 10
  property int bottomInset: 0
  property bool compact: false
  required property var entry
  readonly property string image: entry ? entry.image : ""
  readonly property bool isClosed: entry ? entry.closed : false
  readonly property int notificationId: entry ? entry.id : -1
  property int previewIconSize: compact ? 48 : 56
  property bool showActivateButton: entry ? entry.hasDefaultAction && !entry.closed : false
  property bool showCloseButton: false
  property bool showClosedLabel: false
  property bool showInlineReply: true
  readonly property string summary: entry ? entry.summary : ""
  property int summaryLineLimit: compact ? 2 : 3

  signal actionRequested(notificationId: int, actionIndex: int)
  signal activateRequested(notificationId: int)
  signal closeRequested(notificationId: int)
  signal inlineReplyRequested(notificationId: int, text: string)

  border.color: Config.colors.surface2
  border.width: 2
  color: Config.colors.base
  implicitHeight: contentColumn.implicitHeight + Config.padding.large * 2 + bottomInset
  radius: Config.radius.normal

  Column {
    id: contentColumn

    anchors.bottomMargin: Config.padding.large + root.bottomInset
    anchors.fill: parent
    anchors.margins: Config.padding.large
    spacing: Config.spacing.normal

    Row {
      spacing: Config.spacing.normal
      width: parent.width

      NotificationIconFallback {
        id: previewIcon

        expandToAspect: true
        fallbackText: root.appName ? root.appName.charAt(0).toUpperCase() : ""
        image: root.image || root.appIcon
        size: root.previewIconSize
      }
      Column {
        spacing: Config.spacing.extraSmall
        width: parent.width - previewIcon.width - closeButtonLoader.width - activateButtonLoader.width - parent.spacing * (1 + (closeButtonLoader.active ? 1 : 0) + (activateButtonLoader.active ? 1 : 0))

        Text {
          color: Config.colors.primary
          elide: Text.ElideRight
          font.pixelSize: Config.sizes.small
          font.weight: Font.Medium
          text: root.appName
          textFormat: Text.PlainText
          visible: text !== ""
          width: parent.width
        }
        Text {
          color: Config.colors.fg
          elide: Text.ElideRight
          font.pixelSize: Config.sizes.normal
          font.weight: Font.Medium
          maximumLineCount: root.summaryLineLimit
          text: root.summary
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.Wrap
        }
      }
      Loader {
        id: activateButtonLoader

        active: root.showActivateButton
        height: active ? 20 : 0
        width: active ? 20 : 0

        sourceComponent: Rectangle {
          color: activateArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1
          radius: Config.radius.full

          MaterialIcon {
            anchors.centerIn: parent
            code: root.activateIconCode
            iconColor: activateArea.containsMouse ? Config.colors.base : Config.colors.primary
            iconSize: root.activateIconSize
          }
          MouseArea {
            id: activateArea

            anchors.fill: parent
            hoverEnabled: true

            onClicked: root.activateRequested(root.notificationId)
          }
        }
      }
      Loader {
        id: closeButtonLoader

        active: root.showCloseButton
        height: active ? 20 : 0
        width: active ? 20 : 0

        sourceComponent: Rectangle {
          color: closeArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1
          radius: Config.radius.full

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
    }
    Text {
      color: Config.colors.fg
      font.pixelSize: Config.sizes.normal
      maximumLineCount: root.bodyLineLimit
      text: root.body
      textFormat: Text.RichText
      visible: text !== ""
      width: parent.width
      wrapMode: Text.Wrap
    }
    NotificationActions {
      allowInlineReply: root.showInlineReply
      compact: root.compact
      entry: root.entry
      width: parent.width

      onActionRequested: actionIndex => root.actionRequested(root.notificationId, actionIndex)
      onInlineReplyRequested: text => root.inlineReplyRequested(root.notificationId, text)
    }
    Text {
      color: Config.colors.surface4
      font.pixelSize: Config.sizes.small
      font.weight: Font.Medium
      text: "Closed notification"
      textFormat: Text.PlainText
      visible: root.showClosedLabel && root.isClosed
      width: parent.width
    }
  }
}
