pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	required property SC.Config.Colors colors
	readonly property color actionColor: {
		if (root.device.connected)
			return root.colors.destructive;

		return root.colors.surface5;
	}
	readonly property color nameColor: {
		if (root.device.connected)
			return root.colors.primary;

		return root.colors.fg;
	}

	readonly property int actionSize: 32
	readonly property int actionIconSize: 16
	required property int rowHeight

	readonly property bool busy: root.device.pairing || root.device.state === BluetoothDeviceState.Connecting || root.device.state === BluetoothDeviceState.Disconnecting
	readonly property bool paired: root.device.paired || root.device.bonded
	readonly property bool canForget: root.paired && !root.device.connected
	required property BluetoothDevice device
	readonly property string statusTail: {
		if (root.device.pairing)
			return "Pairing…";

		if (root.busy)
			return BluetoothDeviceState.toString(root.device.state) + "…";

		if (root.device.connected && root.device.batteryAvailable)
			return Math.round(root.device.battery * 100) + "%";
		if (!root.paired)
			return root.device.address || "Available";
		return "";
	}

	function activate() {
		if (root.device.connected)
			root.device.disconnect();
		else if (root.device.paired)
			root.device.connect();
		else
			root.device.pair();
	}

	color: root.colors.surface1
	height: root.rowHeight
	radius: SC.Config.radius.small
	width: {
		if (parent)
			return parent.width;

		return 0;
	}

	Row {
		id: actions

		anchors.right: parent.right
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		spacing: SC.Config.spacing.extraSmall

		SquareButton {
			busy: root.busy
			code: {
				if (root.device.connected)
					return 0xE0DE;

				if (root.device.paired)
					return 0xEB56;

				return 0xE0DA;
			}
			colors: root.colors
			enabled: !root.busy
			iconColor: root.actionColor
			iconSize: root.actionIconSize
			size: root.actionSize

			onClicked: root.activate()
		}

		SquareButton {
			code: 0xE4F6
			colors: root.colors
			enabled: !root.busy
			iconColor: root.colors.surface5
			iconSize: root.actionIconSize
			size: root.actionSize
			visible: root.canForget

			onClicked: root.device.forget()
		}
	}

	Item {
		id: info

		anchors.left: parent.left
		anchors.leftMargin: SC.Config.padding.small
		anchors.right: actions.left
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: deviceName.implicitHeight + subtitle.height + 1

		Text {
			id: deviceName

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			color: root.nameColor
			elide: Text.ElideRight
			font.pointSize: 10
			font.weight: {
				if (root.device.connected)
					return Font.DemiBold;

				return Font.Normal;
			}
			text: root.device.name || root.device.deviceName || root.device.address
		}

		Text {
			id: subtitle

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: deviceName.bottom
			anchors.topMargin: 1
			color: root.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			text: root.statusTail
		}
	}

	Connections {
		function onPairingChanged() {
			if (!root.device.pairing && root.device.paired && !root.device.connected)
				root.device.connect();
		}

		target: root.device
	}

	component SquareButton: Rectangle {
		id: button

		property bool busy: false
		property int code: 0
		required property SC.Config.Colors colors
		required property color iconColor
		required property int iconSize
		required property int size

		signal clicked

		border.color: {
			if (buttonMouse.containsMouse && button.enabled)
				return button.colors.surface5;

			return button.colors.surface2;
		}
		border.width: 2
		color: {
			if (buttonMouse.containsMouse && button.enabled)
				return button.colors.surface1;

			return button.colors.surface2;
		}
		height: button.size
		radius: SC.Config.radius.small
		width: button.size

		MaterialIcon {
			code: button.code
			iconColor: button.iconColor
			iconSize: button.iconSize
			visible: !button.busy
		}

		LoaderIcon {
			iconColor: button.iconColor
			iconSize: button.iconSize
			visible: button.busy
		}

		MouseArea {
			id: buttonMouse

			anchors.fill: parent
			cursorShape: {
				if (button.enabled)
					return Qt.PointingHandCursor;

				return Qt.ArrowCursor;
			}
			enabled: button.enabled
			hoverEnabled: true

			onClicked: button.clicked()
		}
	}
}
