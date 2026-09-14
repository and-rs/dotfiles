import QtQuick
import Quickshell
import qs.Config as SC
import qs.ControlCenterV2.ButtonIndicators

Rectangle {
	id: root

	required property PanelWindow window

	anchors.verticalCenter: parent.verticalCenter
	color: hover.hovered ? SC.Config.colors.surface2 : SC.Config.colors.bg
	height: window.implicitHeight - SC.Config.padding.micro
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
	}
}
