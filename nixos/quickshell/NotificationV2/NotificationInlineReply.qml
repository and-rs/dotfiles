import QtQuick
import qs.Bar

Row {
  id: root

  property bool compact: false
  required property string placeholder

  signal sendRequested(text: string)

  height: visible ? implicitHeight : 0
  spacing: Config.spacing.small
  visible: !root.compact

  Rectangle {
    border.color: Config.colors.primary
    border.width: replyInput.activeFocus ? 2 : 0
    color: Config.colors.surface1
    height: Math.max(32, replyInput.implicitHeight + Config.padding.small * 2)
    radius: Config.radius.normal
    width: parent.width - sendButton.width - parent.spacing

    MouseArea {
      anchors.fill: parent
      enabled: !replyInput.activeFocus
      z: 2

      onClicked: replyInput.forceActiveFocus()
    }
    TextInput {
      id: replyInput

      activeFocusOnPress: true
      anchors.left: parent.left
      anchors.leftMargin: Config.padding.normal
      anchors.right: parent.right
      anchors.rightMargin: Config.padding.normal
      anchors.verticalCenter: parent.verticalCenter
      clip: true
      color: Config.colors.fg
      echoMode: TextInput.Normal
      focus: visible
      font.pixelSize: Config.sizes.small
      inputMethodHints: Qt.ImhNoPredictiveText
      selectedTextColor: Config.colors.base
      selectionColor: Config.colors.primary
      text: ""
      z: 1

      onAccepted: sendButton.send()

      Text {
        anchors.fill: parent
        color: Config.colors.surface4
        font.pixelSize: replyInput.font.pixelSize
        text: root.placeholder
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        visible: replyInput.text === "" && !replyInput.activeFocus
      }
    }
  }
  Rectangle {
    id: sendButton

    function send(): void {
      const reply = replyInput.text.trim();
      if (reply === "")
        return;
      root.sendRequested(reply);
      replyInput.text = "";
    }

    color: sendArea.containsMouse && replyInput.text.trim() !== "" ? Config.colors.primary : Config.colors.surface2
    height: 32
    opacity: replyInput.text.trim() !== "" ? 1 : 0.6
    radius: Config.radius.normal
    width: Math.max(48, sendText.implicitWidth + Config.padding.normal * 2)

    Text {
      id: sendText

      anchors.centerIn: parent
      color: sendArea.containsMouse && replyInput.text.trim() !== "" ? Config.colors.base : Config.colors.fg
      font.pixelSize: Config.sizes.small
      font.weight: Font.Medium
      text: "Send"
      textFormat: Text.PlainText
    }
    MouseArea {
      id: sendArea

      anchors.fill: parent
      enabled: replyInput.text.trim() !== ""
      hoverEnabled: true

      onClicked: sendButton.send()
    }
  }
}
