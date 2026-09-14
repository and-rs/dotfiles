import QtQuick
import qs.Bar
import qs.Config as SC

Column {
	id: root

	readonly property int actionCount: visibleActions ? visibleActions.length : 0
	property bool allowInlineReply: true
	property bool compact: false
	readonly property bool hasInlineReply: allowInlineReply && inlineReplyAvailable
	readonly property bool inlineReplyAvailable: notification ? Boolean(notification.hasInlineReply) : false
	readonly property string inlineReplyPlaceholder: notification ? String(notification.inlineReplyPlaceholder || "Reply") : "Reply"
	required property var notification
	readonly property bool showInlineReplyIndicator: !allowInlineReply && inlineReplyAvailable
	readonly property bool usable: notification !== null
	readonly property var visibleActions: NotificationData.visibleActions(notification?.actions)

	signal actionRequested(actionIndex: int)
	signal inlineReplyRequested(text: string)

	function resetTransientState(): void {
		inlineReply.reset();
	}

	height: visible ? implicitHeight : 0
	spacing: SC.Config.spacing.small
	visible: usable && (actionCount > 0 || hasInlineReply || showInlineReplyIndicator)

	Flow {
		spacing: SC.Config.spacing.small
		visible: root.actionCount > 0
		width: parent.width

		Repeater {
			model: root.actionCount

			Rectangle {
				required property int index

				color: actionArea.containsMouse ? SC.Config.colors.surface3 : SC.Config.colors.surface1
				implicitHeight: actionText.implicitHeight + SC.Config.padding.small * 2
				implicitWidth: actionText.implicitWidth + SC.Config.padding.normal * 2
				radius: SC.Config.radius.normal

				Text {
					id: actionText

					anchors.centerIn: parent
					color: actionArea.containsMouse ? SC.Config.colors.bg : SC.Config.colors.fg
					elide: Text.ElideRight
					font.pixelSize: SC.Config.sizes.small
					font.weight: Font.Medium
					text: root.visibleActions[index]?.text ?? "Action"
					textFormat: Text.PlainText
				}
				MouseArea {
					id: actionArea

					anchors.fill: parent
					hoverEnabled: true

					onClicked: root.actionRequested(root.visibleActions[index].index)
				}
			}
		}
	}
	Rectangle {
		color: SC.Config.colors.surface1
		implicitHeight: replyIndicatorText.implicitHeight + SC.Config.padding.small * 2
		implicitWidth: replyIndicatorText.implicitWidth + SC.Config.padding.normal * 2
		radius: SC.Config.radius.normal
		visible: root.showInlineReplyIndicator

		Text {
			id: replyIndicatorText

			anchors.centerIn: parent
			color: SC.Config.colors.surface4
			font.pixelSize: SC.Config.sizes.small
			font.weight: Font.Medium
			text: "Reply in sidebar"
			textFormat: Text.PlainText
		}
	}
	NotificationInlineReply {
		id: inlineReply

		compact: root.compact
		placeholder: root.inlineReplyPlaceholder
		visible: root.hasInlineReply
		width: parent.width

		onSendRequested: text => root.inlineReplyRequested(text)
	}
}
