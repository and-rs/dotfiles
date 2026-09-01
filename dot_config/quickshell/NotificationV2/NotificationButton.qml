import QtQuick
import qs.Bar
import qs.Config
import qs.Bar.Status as Status

Rectangle {
	id: root

	readonly property bool active: controller.activePanel === "notifications"
	required property Status.StatusMenus controller
	property int count: 0
	readonly property bool hasNotifications: root.count > 0
	readonly property real horizontalPadding: controller.buttonHorizontalPadding

	color: "transparent"
	height: controller.window.implicitHeight
	width: controller.window.implicitHeight + horizontalPadding * 2

	MaterialIcon {
		anchors.centerIn: parent
		code: root.hasNotifications ? 0xE5E8 : 0xE0CE
		iconColor: root.active ? Config.colors.primary : root.hasNotifications ? Config.colors.fg : Config.colors.surface4
	}
	Rectangle {
		anchors.right: parent.right
		anchors.rightMargin: Config.padding.micro
		anchors.top: parent.top
		anchors.topMargin: Config.padding.micro
		color: Config.colors.destructive
		height: 14
		radius: 2
		visible: root.hasNotifications
		width: Math.max(10, badgeText.implicitWidth + Config.padding.micro * 2)

		Text {
			id: badgeText

			anchors.centerIn: parent
			color: Config.colors.bg
			font.pixelSize: Config.sizes.small
			font.weight: Font.DemiBold
			text: root.count > 99 ? "99+" : String(root.count)
			textFormat: Text.PlainText
		}
	}
	MouseArea {
		anchors.fill: parent

		onClicked: controller.switchPanel("notifications")
	}
}
