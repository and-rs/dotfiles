import Quickshell.Services.SystemTray
import QtQuick
import qs.Bar
import qs.Config
import qs.Bar.Status as Status

Rectangle {
	id: trayRect

	readonly property bool active: controller.activeMenu === "tray"
	required property Status.StatusMenus controller
	readonly property bool hasItems: (SystemTray.items.values ?? []).length > 0
	readonly property real horizontalPadding: controller.buttonHorizontalPadding

	color: "transparent"
	height: controller.window.implicitHeight
	width: controller.window.implicitHeight + horizontalPadding * 2

	MaterialIcon {
		id: trayIcon

		code: !trayRect.hasItems ? 0xECE0 : trayRect.active ? 0xE13C : 0xE136
		iconColor: !trayRect.hasItems ? Config.colors.surface4 : trayRect.active ? Config.colors.destructive : Config.colors.fg
		iconSize: 18
	}
	MouseArea {
		anchors.fill: parent

		onClicked: if (trayRect.hasItems)
			trayRect.controller.switchMenu("tray")
	}
}
