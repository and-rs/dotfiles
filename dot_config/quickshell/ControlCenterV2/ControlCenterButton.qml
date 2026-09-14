import QtQuick
import Quickshell
import qs.Config as SC
import qs.ControlCenterV2.ButtonIndicators

Rectangle {
	id: root

	required property PanelWindow window
	property bool open: false

	function close() {
		open = false;
	}
	function toggle() {
		open = !open;
	}

	anchors.verticalCenter: parent.verticalCenter
	border.width: 2
	border.color: hover.hovered ? SC.Config.colors.surface3 : SC.Config.colors.bg
	color: "transparent"
	height: window.implicitHeight - SC.Config.padding.small
	implicitWidth: content.implicitWidth + SC.Config.padding.small * 2
	radius: SC.Config.radius.small

	HoverHandler {
		id: hover
	}
	Row {
		id: content

		anchors.centerIn: parent
		spacing: SC.Config.spacing.large

		TrayIndicator {}
		BluetoothIndicator {}
		NetworkIndicator {}
		BatteryIndicator {}
	}
	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor

		onClicked: root.toggle()
	}
	ControlCenterPopup {
		anchorButton: root
		open: root.open
		window: root.window

		onCloseRequested: root.close()
	}
}
