import QtQuick
import Quickshell
import qs.Bar
import qs.Config as SC
import qs.Sidebar
import qs.NotificationV2

Rectangle {
	id: root

	readonly property bool hasNotifications: NotificationStore.count > 0
	property bool open: false
	required property PanelWindow window

	function close() {
		sidebarHost.finalizePendingRemovals();
		open = false;
	}
	function toggle() {
		if (open)
			close();
		else
			open = true;
	}

	anchors.verticalCenter: parent.verticalCenter
	color: "transparent"
	height: window.implicitHeight
	width: window.implicitHeight

	MaterialIcon {
		code: root.hasNotifications ? 0xE5E8 : 0xE0CE
		iconColor: root.open ? SC.Config.colors.primary : root.hasNotifications ? SC.Config.colors.fg : SC.Config.colors.surface4
	}
	Rectangle {
		anchors.right: parent.right
		anchors.rightMargin: SC.Config.padding.micro
		anchors.top: parent.top
		anchors.topMargin: SC.Config.padding.micro
		color: SC.Config.colors.destructive
		height: 14
		radius: 2
		visible: root.hasNotifications
		width: Math.max(10, badgeText.implicitWidth + SC.Config.padding.micro * 2)

		Text {
			id: badgeText

			anchors.centerIn: parent
			color: SC.Config.colors.bg
			font.pixelSize: SC.Config.sizes.small
			font.weight: Font.DemiBold
			text: NotificationStore.count > 99 ? "99+" : String(NotificationStore.count)
			textFormat: Text.PlainText
		}
	}
	MouseArea {
		anchors.fill: parent

		onClicked: root.toggle()
	}
	SidebarHost {
		id: sidebarHost

		open: root.open
		title: "Notifications"
		window: root.window

		panel: Component {
			NotificationSidebarActions {
				onClearAllRequested: {
					NotificationStore.clear();
					root.close();
				}
				onCloseRequested: notificationId => NotificationStore.removeNotification(notificationId)
			}
		}

		onCloseRequested: root.close()
	}
}
