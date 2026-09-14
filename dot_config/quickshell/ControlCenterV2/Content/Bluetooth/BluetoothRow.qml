pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	readonly property bool busy: root.device.pairing || root.device.state === BluetoothDeviceState.Connecting || root.device.state === BluetoothDeviceState.Disconnecting
	readonly property bool canAutoconnect: root.device.paired || root.device.bonded
	readonly property bool canForget: root.canAutoconnect && !root.device.connected
	required property BluetoothDevice device
	readonly property string statusTail: {
		if (root.busy)
			return root.device.pairing ? "Pairing…" : BluetoothDeviceState.toString(root.device.state) + "…";
		if (root.device.connected && root.device.batteryAvailable)
			return Math.round(root.device.battery * 100) + "%";
		if (!root.canAutoconnect)
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

	color: SC.Config.colors.surface1
	height: 48
	radius: SC.Config.radius.small
	width: parent ? parent.width : 0

	Row {
		id: actions

		anchors.right: parent.right
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		spacing: SC.Config.spacing.extraSmall

		SquareButton {
			busy: root.busy
			code: root.device.connected ? 0xE0DE : root.device.paired ? 0xEB56 : 0xE0DA
			enabled: !root.busy
			iconColor: root.device.connected ? SC.Config.colors.destructive : SC.Config.colors.surface5

			onClicked: root.activate()
		}
		SquareButton {
			code: 0xE4F6
			enabled: !root.busy
			iconColor: SC.Config.colors.surface5
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
			anchors.top: parent.top
			color: root.device.connected ? SC.Config.colors.primary : SC.Config.colors.fg
			elide: Text.ElideRight
			font.pointSize: 9
			font.weight: root.device.connected ? Font.DemiBold : Font.Normal
			text: root.device.name || root.device.deviceName || root.device.address
		}
		Item {
			id: subtitle

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: deviceName.bottom
			anchors.topMargin: 1
			height: Math.max(autoconnectBox.height, autoconnectLabel.implicitHeight, statusLabel.implicitHeight)

			AutoconnectBox {
				id: autoconnectBox

				anchors.left: parent.left
				anchors.verticalCenter: parent.verticalCenter
				checked: root.device.trusted
				visible: root.canAutoconnect

				onToggled: root.device.trusted = !root.device.trusted
			}
			Text {
				id: autoconnectLabel

				anchors.left: autoconnectBox.right
				anchors.leftMargin: SC.Config.spacing.extraSmall
				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.surface5
				font.pointSize: 8
				text: "Autoconnect"
				visible: root.canAutoconnect
			}
			Text {
				id: statusLabel

				anchors.left: autoconnectLabel.visible ? autoconnectLabel.right : parent.left
				anchors.leftMargin: autoconnectLabel.visible && root.statusTail !== "" ? SC.Config.spacing.extraSmall : 0
				anchors.right: parent.right
				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.surface5
				elide: Text.ElideRight
				font.pointSize: 8
				text: root.statusTail
				visible: root.statusTail !== ""
			}
		}
	}
	Connections {
		function onPairingChanged() {
			if (!root.device.pairing && root.device.paired && !root.device.connected)
				root.device.connect();
		}

		target: root.device
	}

	component AutoconnectBox: Rectangle {
		id: box

		property bool checked: false

		signal toggled

		border.color: box.checked ? SC.Config.colors.primary : SC.Config.colors.surface4
		border.width: 1
		color: box.checked ? SC.Config.colors.primary : "transparent"
		height: 12
		radius: 2
		width: 12

		MouseArea {
			anchors.fill: parent
			anchors.margins: -SC.Config.padding.micro
			cursorShape: Qt.PointingHandCursor

			onClicked: box.toggled()
		}
	}
	component SquareButton: Rectangle {
		id: button

		property bool busy: false
		property int code: 0
		property bool enabled: true
		property color iconColor: SC.Config.colors.primary

		signal clicked

		border.color: buttonMouse.containsMouse && button.enabled ? SC.Config.colors.surface5 : SC.Config.colors.surface2
		border.width: 2
		color: buttonMouse.containsMouse && button.enabled ? SC.Config.colors.surface1 : SC.Config.colors.surface2
		height: 32
		radius: SC.Config.radius.small
		width: 32

		MaterialIcon {
			code: button.code
			iconColor: button.iconColor
			iconSize: 16
			visible: !button.busy
		}
		LoaderIcon {
			iconColor: button.iconColor
			iconSize: 16
			visible: button.busy
		}
		MouseArea {
			id: buttonMouse

			anchors.fill: parent
			cursorShape: button.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
			enabled: button.enabled
			hoverEnabled: true

			onClicked: button.clicked()
		}
	}
}
