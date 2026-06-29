import QtQuick
import qs.Bar

Column {
  id: root

  readonly property int actionCount: visibleActions ? visibleActions.length : 0
  property bool allowInlineReply: true
  property bool compact: false
  required property var entry
  readonly property bool hasInlineReply: allowInlineReply && inlineReplyAvailable
  readonly property bool inlineReplyAvailable: entry ? Boolean(entry.hasInlineReply) : false
  readonly property string inlineReplyPlaceholder: entry ? String(entry.inlineReplyPlaceholder || "Reply") : "Reply"
  readonly property bool showInlineReplyIndicator: !allowInlineReply && inlineReplyAvailable
  readonly property bool usable: entry ? !entry.closed : false
  readonly property var visibleActions: parseVisibleActions(entry)

  signal actionRequested(index: int)
  signal inlineReplyRequested(text: string)

  function parseVisibleActions(value: var): var {
    if (!value || !value.visibleActionsJson)
      return [];
    try {
      const parsed = JSON.parse(String(value.visibleActionsJson));
      return Array.isArray(parsed) ? parsed : [];
    } catch (_) {
      return [];
    }
  }

  height: visible ? implicitHeight : 0
  spacing: Config.spacing.small
  visible: usable && (actionCount > 0 || hasInlineReply || showInlineReplyIndicator)

  Flow {
    spacing: Config.spacing.small
    visible: root.actionCount > 0
    width: parent.width

    Repeater {
      model: root.actionCount

      Rectangle {
        required property int index

        color: actionArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1
        implicitHeight: actionText.implicitHeight + Config.padding.small * 2
        implicitWidth: actionText.implicitWidth + Config.padding.normal * 2
        radius: Config.radius.normal

        Text {
          id: actionText

          anchors.centerIn: parent
          color: actionArea.containsMouse ? Config.colors.base : Config.colors.fg
          elide: Text.ElideRight
          font.pixelSize: Config.sizes.small
          font.weight: Font.Medium
          text: root.visibleActions[index]?.text ?? "Action"
          textFormat: Text.PlainText
        }
        MouseArea {
          id: actionArea

          anchors.fill: parent
          hoverEnabled: true

          onClicked: root.actionRequested(index)
        }
      }
    }
  }
  Rectangle {
    color: Config.colors.surface1
    implicitHeight: replyIndicatorText.implicitHeight + Config.padding.small * 2
    implicitWidth: replyIndicatorText.implicitWidth + Config.padding.normal * 2
    radius: Config.radius.normal
    visible: root.showInlineReplyIndicator

    Text {
      id: replyIndicatorText

      anchors.centerIn: parent
      color: Config.colors.surface4
      font.pixelSize: Config.sizes.small
      font.weight: Font.Medium
      text: "Reply in sidebar"
      textFormat: Text.PlainText
    }
  }
  NotificationInlineReply {
    compact: root.compact
    placeholder: root.inlineReplyPlaceholder
    visible: root.hasInlineReply
    width: parent.width

    onSendRequested: text => root.inlineReplyRequested(text)
  }
}
