import QtQuick
import qs.Bar
import qs.Config as SC

Row {
	id: root

	property bool compact: false
	required property string placeholder

	signal sendRequested(text: string)

	function reset(): void {
		replyInput.text = "";
		replyInput.focus = false;
	}

	height: visible ? implicitHeight : 0
	spacing: SC.Config.spacing.small
	visible: !root.compact

	Rectangle {
		border.color: SC.Config.colors.primary
		border.width: replyInput.activeFocus ? 2 : 0
		color: SC.Config.colors.surface1
		height: Math.max(32, replyInput.implicitHeight + SC.Config.padding.small * 2)
		radius: SC.Config.radius.normal
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
			anchors.leftMargin: SC.Config.padding.normal
			anchors.right: parent.right
			anchors.rightMargin: SC.Config.padding.normal
			anchors.verticalCenter: parent.verticalCenter
			clip: true
			color: SC.Config.colors.fg
			echoMode: TextInput.Normal
			focus: visible
			font.pixelSize: SC.Config.sizes.small
			inputMethodHints: Qt.ImhNoPredictiveText
			selectedTextColor: SC.Config.colors.bg
			selectionColor: SC.Config.colors.primary
			text: ""
			z: 1

			onAccepted: sendButton.send()

			Text {
				anchors.fill: parent
				color: SC.Config.colors.surface4
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

		color: sendArea.containsMouse && replyInput.text.trim() !== "" ? SC.Config.colors.primary : SC.Config.colors.surface2
		height: 32
		opacity: replyInput.text.trim() !== "" ? 1 : 0.6
		radius: SC.Config.radius.normal
		width: Math.max(48, sendText.implicitWidth + SC.Config.padding.normal * 2)

		Text {
			id: sendText

			anchors.centerIn: parent
			color: sendArea.containsMouse && replyInput.text.trim() !== "" ? SC.Config.colors.bg : SC.Config.colors.fg
			font.pixelSize: SC.Config.sizes.small
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
