import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Bar
import qs.Config as SC

Column {
	id: root

	readonly property var adapter: {
		let adapters = Bluetooth.adapters.values ?? [];
		return adapters.length > 0 ? adapters[0] : null;
	}
	readonly property bool hasConnectedDevice: {
		let devs = Bluetooth.devices.values ?? [];
		for (let i = 0; i < devs.length; i++) {
			if (devs[i] && devs[i].connected)
				return true;
		}
		return false;
	}
	readonly property bool isEnabled: adapter && adapter.enabled

	spacing: SC.Config.spacing.small
	width: parent ? parent.width : 0

	Text {
		color: SC.Config.colors.fg
		font.pointSize: 10
		font.weight: 700
		text: "Bluetooth"
	}
	Rectangle {
		color: SC.Config.colors.surface2
		height: 1
		width: parent.width
	}
	Rectangle {
		color: btToggleHover.hovered ? SC.Config.colors.surface2 : SC.Config.colors.surface1
		height: 28
		radius: SC.Config.radius.small
		width: parent.width

		HoverHandler {
			id: btToggleHover
		}
		Text {
			anchors.left: parent.left
			anchors.leftMargin: SC.Config.padding.small
			anchors.verticalCenter: parent.verticalCenter
			color: SC.Config.colors.fg
			font.pointSize: 9
			font.weight: 500
			text: "Power"
		}
		Text {
			anchors.right: parent.right
			anchors.rightMargin: SC.Config.padding.small
			anchors.verticalCenter: parent.verticalCenter
			color: root.isEnabled ? SC.Config.colors.success : SC.Config.colors.surface4
			font.pointSize: 9
			font.weight: 500
			text: root.isEnabled ? "On" : "Off"
		}
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: {
				btToggleProc.command = root.isEnabled ? ["sh", "-c", "bluetoothctl power off && rfkill block bluetooth"] : ["sh", "-c", "rfkill unblock bluetooth && bluetoothctl power on"];
				btToggleProc.running = true;
			}
		}
	}
	Rectangle {
		color: btScanHover.hovered ? SC.Config.colors.surface3 : SC.Config.colors.surface2
		height: 28
		radius: SC.Config.radius.small
		visible: root.isEnabled
		width: parent.width

		HoverHandler {
			id: btScanHover
		}
		Text {
			anchors.left: parent.left
			anchors.leftMargin: SC.Config.padding.small
			anchors.verticalCenter: parent.verticalCenter
			color: SC.Config.colors.fg
			font.pointSize: 9
			font.weight: 500
			text: "Scanning"
		}
		Text {
			anchors.right: parent.right
			anchors.rightMargin: SC.Config.padding.small
			anchors.verticalCenter: parent.verticalCenter
			color: root.adapter && root.adapter.discovering ? SC.Config.colors.primary : SC.Config.colors.surface3
			font.pointSize: 9
			font.weight: 500
			text: root.adapter && root.adapter.discovering ? "On" : "Off"
		}
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: {
				if (root.adapter)
					root.adapter.discovering = !root.adapter.discovering;
			}
		}
	}
	Column {
		spacing: SC.Config.spacing.small
		visible: root.adapter !== null && root.isEnabled
		width: parent.width

		Rectangle {
			color: SC.Config.colors.surface3
			height: 1
			width: parent.width
		}
		Row {
			spacing: SC.Config.spacing.small

			Text {
				color: SC.Config.colors.surface4
				font.pointSize: 9
				text: "Adapter"
			}
			Text {
				color: SC.Config.colors.fg
				font.pointSize: 9
				font.weight: 600
				text: root.adapter ? root.adapter.name : ""
			}
		}
		Row {
			spacing: SC.Config.spacing.small

			Text {
				color: SC.Config.colors.surface4
				font.pointSize: 9
				text: "State"
			}
			Text {
				color: SC.Config.colors.fg
				font.pointSize: 9
				font.weight: 600
				text: root.adapter ? BluetoothAdapterState.toString(root.adapter.state) : ""
			}
		}
	}
	Rectangle {
		color: SC.Config.colors.surface3
		height: 1
		visible: root.isEnabled
		width: parent.width
	}
	Text {
		color: SC.Config.colors.fg
		font.pointSize: 9
		font.weight: 700
		text: "Connected"
		visible: root.isEnabled && root.hasConnectedDevice
	}
	Flickable {
		clip: true
		contentHeight: connectedCol.implicitHeight
		height: Math.min(connectedCol.implicitHeight, 100)
		visible: root.isEnabled && root.hasConnectedDevice
		width: parent.width

		Column {
			id: connectedCol

			spacing: SC.Config.spacing.extraSmall
			width: parent.width

			Repeater {
				model: Bluetooth.devices

				delegate: Rectangle {
					required property var modelData

					color: SC.Config.colors.surface3
					height: modelData.connected ? 36 : 0
					radius: SC.Config.radius.small
					visible: modelData.connected
					width: connectedCol.width

					Text {
						anchors.left: parent.left
						anchors.leftMargin: SC.Config.padding.small
						anchors.verticalCenter: parent.verticalCenter
						color: SC.Config.colors.primary
						font.pointSize: 9
						font.weight: 700
						text: modelData.name || "Unknown"
					}
					Text {
						anchors.right: parent.right
						anchors.rightMargin: SC.Config.padding.small
						anchors.verticalCenter: parent.verticalCenter
						color: modelData.batteryAvailable ? (modelData.battery < 0.2 ? SC.Config.colors.destructive : SC.Config.colors.fg) : SC.Config.colors.success
						font.pointSize: 8
						text: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "Connected"
					}
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor

						onClicked: modelData.disconnect()
					}
				}
			}
		}
	}
	Text {
		color: SC.Config.colors.fg
		font.pointSize: 9
		font.weight: 700
		text: "Available"
		visible: root.isEnabled
	}
	Flickable {
		clip: true
		contentHeight: availableCol.implicitHeight
		height: Math.min(availableCol.implicitHeight, 150)
		visible: root.isEnabled
		width: parent.width

		Column {
			id: availableCol

			spacing: SC.Config.spacing.extraSmall
			width: parent.width

			Repeater {
				model: Bluetooth.devices

				delegate: Rectangle {
					required property var modelData

					color: SC.Config.colors.surface2
					height: !modelData.connected ? 36 : 0
					radius: SC.Config.radius.small
					visible: !modelData.connected
					width: availableCol.width

					Text {
						anchors.left: parent.left
						anchors.leftMargin: SC.Config.padding.small
						anchors.verticalCenter: parent.verticalCenter
						color: SC.Config.colors.fg
						font.pointSize: 9
						font.weight: 500
						text: modelData.name || "Unknown"
					}
					Text {
						anchors.right: parent.right
						anchors.rightMargin: SC.Config.padding.small
						anchors.verticalCenter: parent.verticalCenter
						color: modelData.paired ? SC.Config.colors.surface5 : SC.Config.colors.surface4
						font.pointSize: 8
						text: modelData.paired ? "Paired" : "New"
					}
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor

						onClicked: modelData.connect()
					}
				}
			}
		}
	}
	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: "Bluetooth is off"
		visible: !root.isEnabled
	}
	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: "No devices found"
		visible: root.isEnabled && (Bluetooth.devices.values ?? []).length === 0
	}
	Process {
		id: btToggleProc

		stdout: StdioCollector {}
	}
}
