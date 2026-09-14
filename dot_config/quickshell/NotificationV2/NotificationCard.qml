import QtQuick
import qs.Bar
import qs.Config as SC

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
	readonly property var notification: entry ? entry.notification : null
	readonly property int notificationId: entry ? entry.id : -1
	property int previewIconSize: 56
	property bool showActivateButton: entry ? NotificationData.defaultActionIndex(entry.notification?.actions) !== -1 && !entry.closed : false
	property bool showCloseButton: false
	property bool showClosedLabel: false
	property bool showInlineReply: true
	readonly property string summary: entry ? entry.summary : ""
	property int summaryLineLimit: compact ? 2 : 3

	signal actionRequested(notificationId: int, actionIndex: int)
	signal activateRequested(notificationId: int)
	signal closeRequested(notificationId: int)
	signal inlineReplyRequested(notificationId: int, text: string)
	signal linkActivated(link: string)

	function resetTransientState(): void {
		notificationActions.resetTransientState();
	}

	border.color: SC.Config.colors.surface2
	border.width: 2
	color: SC.Config.colors.bg
	implicitHeight: contentColumn.implicitHeight + SC.Config.padding.large * 2 + bottomInset
	radius: SC.Config.radius.normal

	Column {
		id: contentColumn

		anchors.bottomMargin: SC.Config.padding.large + root.bottomInset
		anchors.fill: parent
		anchors.margins: SC.Config.padding.large
		spacing: SC.Config.spacing.normal

		Row {
			spacing: SC.Config.spacing.normal
			width: parent.width

			NotificationIconFallback {
				id: previewIcon

				appIcon: root.appIcon
				fallbackText: root.appName ? root.appName.charAt(0).toUpperCase() : ""
				notificationImage: root.image
				size: root.previewIconSize
			}
			Column {
				spacing: SC.Config.spacing.extraSmall
				width: parent.width - previewIcon.width - closeButtonLoader.width - activateButtonLoader.width - parent.spacing * (1 + (closeButtonLoader.active ? 1 : 0) + (activateButtonLoader.active ? 1 : 0))

				Text {
					color: SC.Config.colors.primary
					elide: Text.ElideRight
					font.pixelSize: SC.Config.sizes.small
					font.weight: Font.Medium
					text: root.appName
					textFormat: Text.PlainText
					visible: text !== ""
					width: parent.width
				}
				Text {
					color: SC.Config.colors.fg
					elide: Text.ElideRight
					font.pixelSize: SC.Config.sizes.normal
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
					color: activateArea.containsMouse ? SC.Config.colors.surface3 : SC.Config.colors.surface1
					radius: SC.Config.radius.full

					MaterialIcon {
						anchors.centerIn: parent
						code: root.activateIconCode
						iconColor: activateArea.containsMouse ? SC.Config.colors.bg : SC.Config.colors.primary
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
					color: closeArea.containsMouse ? SC.Config.colors.surface3 : SC.Config.colors.surface1
					radius: SC.Config.radius.full

					MaterialIcon {
						anchors.centerIn: parent
						code: 0xE4F6
						iconColor: closeArea.containsMouse ? SC.Config.colors.bg : SC.Config.colors.primary
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
			color: SC.Config.colors.fg
			elide: Text.ElideRight
			font.pixelSize: SC.Config.sizes.normal
			linkColor: SC.Config.colors.primary
			maximumLineCount: root.bodyLineLimit
			text: root.body
			textFormat: Text.StyledText
			visible: text !== ""
			width: parent.width
			wrapMode: Text.Wrap

			onLinkActivated: link => root.linkActivated(link)
		}
		NotificationActions {
			id: notificationActions

			allowInlineReply: root.showInlineReply
			compact: root.compact
			notification: root.notification
			width: parent.width

			onActionRequested: actionIndex => root.actionRequested(root.notificationId, actionIndex)
			onInlineReplyRequested: text => root.inlineReplyRequested(root.notificationId, text)
		}
		Text {
			color: SC.Config.colors.surface4
			font.pixelSize: SC.Config.sizes.small
			font.weight: Font.Medium
			text: "Closed notification"
			textFormat: Text.PlainText
			visible: root.showClosedLabel && root.isClosed
			width: parent.width
		}
	}
}
