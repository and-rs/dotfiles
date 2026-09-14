import QtQuick
import Quickshell
import qs.Config as SC
import qs.ControlCenterV2.ButtonIndicators
import qs.Debug as Debug

Rectangle {
	id: root

	property bool open: false
	required property PanelWindow window

	function close() {
		open = false;
	}
	function toggle() {
		open = !open;
	}

	anchors.verticalCenter: parent.verticalCenter
	border.color: hover.hovered ? SC.Config.colors.surface3 : SC.Config.colors.bg
	border.width: 2
	color: "transparent"
	height: window.implicitHeight - SC.Config.padding.small + 2
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
		id: popup

		anchorButton: root
		open: root.open
		window: root.window

		onCloseRequested: root.close()
	}
	QtObject {
		id: networkDebugTarget

		property Item item: popup.networkContent
		property var items: {
			const content = popup.networkContent;
			return [
				{
					name: "hero-title",
					item: content ? content.debugHeroTitle : null
				},
				{
					name: "hero-status",
					item: content ? content.debugHeroStatus : null
				},
				{
					name: "network-list",
					item: content ? content.debugNetworkList : null
				}
			];
		}
		property string name: "network"

		function close() {
			root.close();
		}
		function open() {
			popup.selectedTab = "network";
			root.open = true;
		}
	}
	Loader {
		active: SC.Config.debug.enabled

		sourceComponent: Component {
			Debug.Capture {
				targets: [networkDebugTarget]
			}
		}
	}
}
