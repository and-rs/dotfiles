import QtQuick
import qs.Bar
import qs.Notification

Column {
  id: root

  required property var entry
  property bool compact: false
  readonly property int notificationId: entry ? entry.id : -1
  readonly property int actionCount: NotificationStore.actionCount(notificationId)
  readonly property bool hasInlineReply: NotificationStore.hasInlineReplyForId(notificationId)
  readonly property string inlineReplyPlaceholder: NotificationStore.inlineReplyPlaceholderForId(notificationId)
  readonly property bool usable: entry && !entry.closed

  spacing: Config.spacing.small
  visible: usable && (actionCount > 0 || hasInlineReply)
  height: visible ? implicitHeight : 0

  Flow {
    width: parent.width
    spacing: Config.spacing.small
    visible: root.actionCount > 0

    Repeater {
      model: root.actionCount

      Rectangle {
        required property int index
        implicitWidth: actionText.implicitWidth + Config.padding.normal * 2
        implicitHeight: actionText.implicitHeight + Config.padding.small * 2
        radius: Config.radius.normal
        color: actionArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1

        Text {
          id: actionText
          anchors.centerIn: parent
          text: NotificationStore.actionText(root.notificationId, index)
          color: actionArea.containsMouse ? Config.colors.base : Config.colors.fg
          font.pixelSize: Config.sizes.small
          font.weight: Font.Medium
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        MouseArea {
          id: actionArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: NotificationStore.invokeActionByVisibleIndex(root.notificationId, index)
        }
      }
    }
  }

  Row {
    width: parent.width
    spacing: Config.spacing.small
    visible: root.hasInlineReply && !root.compact
    height: visible ? implicitHeight : 0

    Rectangle {
      width: parent.width - sendButton.width - parent.spacing
      height: Math.max(32, replyInput.implicitHeight + Config.padding.small * 2)
      radius: Config.radius.normal
      color: Config.colors.surface1
      border.width: replyInput.activeFocus ? 2 : 0
      border.color: Config.colors.primary

      MouseArea {
        z: 2
        enabled: !replyInput.activeFocus
        anchors.fill: parent
        onClicked: replyInput.forceActiveFocus()
      }

      TextInput {
        id: replyInput
        z: 1
        focus: visible
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Config.padding.normal
        anchors.rightMargin: Config.padding.normal
        color: Config.colors.fg
        selectionColor: Config.colors.primary
        selectedTextColor: Config.colors.base
        font.pixelSize: Config.sizes.small
        clip: true
        text: ""
        echoMode: TextInput.Normal
        activeFocusOnPress: true
        inputMethodHints: Qt.ImhNoPredictiveText
        onAccepted: sendButton.send()

        Text {
          anchors.fill: parent
          text: root.inlineReplyPlaceholder
          visible: replyInput.text === "" && !replyInput.activeFocus
          color: Config.colors.surface4
          font.pixelSize: replyInput.font.pixelSize
          verticalAlignment: Text.AlignVCenter
          textFormat: Text.PlainText
        }
      }
    }

    Rectangle {
      id: sendButton

      width: Math.max(48, sendText.implicitWidth + Config.padding.normal * 2)
      height: 32
      radius: Config.radius.normal
      color: sendArea.containsMouse && replyInput.text.trim() !== "" ? Config.colors.primary : Config.colors.surface2
      opacity: replyInput.text.trim() !== "" ? 1 : 0.6

      function send() {
        const reply = replyInput.text.trim();
        if (reply === "")
          return;
        NotificationStore.sendInlineReply(root.notificationId, reply);
        replyInput.text = "";
      }

      Text {
        id: sendText
        anchors.centerIn: parent
        text: "Send"
        color: sendArea.containsMouse && replyInput.text.trim() !== "" ? Config.colors.base : Config.colors.fg
        font.pixelSize: Config.sizes.small
        font.weight: Font.Medium
        textFormat: Text.PlainText
      }

      MouseArea {
        id: sendArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: replyInput.text.trim() !== ""
        onClicked: sendButton.send()
      }
    }
  }
}
