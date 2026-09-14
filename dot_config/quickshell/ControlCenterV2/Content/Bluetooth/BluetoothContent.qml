pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Bar
import qs.Config as SC
import qs.ControlCenterV2.Content.Network as NetworkUi

Column {
	id: root

	readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
	readonly property bool blocked: root.adapter ? root.adapter.state === BluetoothAdapterState.Blocked : false
	readonly property var connectedDevice: {
		const devices = root.devices;
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].connected)
				return devices[i];
		}
		return null;
	}
	readonly property var details: [root.detailText("ADAPTER", root.adapter ? root.adapter.name || root.adapter.adapterId : ""), root.detailText("ID", root.adapter ? root.adapter.adapterId : ""), root.detailText("STATE", root.adapter ? BluetoothAdapterState.toString(root.adapter.state) : ""), root.detailText("CONNECTED", root.connectedDevice ? root.connectedDevice.name || root.connectedDevice.deviceName || "1" : root.adapter && root.adapter.enabled ? "0" : ""), root.detailText("BATTERY", root.connectedDevice && root.connectedDevice.batteryAvailable ? Math.round(root.connectedDevice.battery * 100) + "%" : "")].filter(text => text !== "")
	readonly property int deviceListHeight: 48 * 3 + SC.Config.spacing.extraSmall * 2
	readonly property var devices: root.adapter ? [...root.adapter.devices.values] : []
	readonly property bool discovering: root.adapter ? root.adapter.discovering : false
	readonly property bool enabled: root.adapter && root.adapter.enabled
	readonly property int sectionHeaderHeight: Math.max(scanHeader.implicitHeight, scanLabel.implicitHeight, scanLoader.iconSize)
	readonly property bool toggling: root.adapter && (root.adapter.state === BluetoothAdapterState.Enabling || root.adapter.state === BluetoothAdapterState.Disabling)

	function compareDevices(a, b) {
		if (a.connected !== b.connected)
			return a.connected ? -1 : 1;
		const an = (a.name || a.deviceName || a.address || "").toLowerCase();
		const bn = (b.name || b.deviceName || b.address || "").toLowerCase();
		return an.localeCompare(bn);
	}
	function detailText(label, value) {
		return value ? label + "\n" + value : "";
	}
	function scan() {
		if (!root.adapter || root.discovering || !root.enabled)
			return;
		root.adapter.discovering = true;
		scanTimeout.restart();
	}
	function stopScan() {
		scanTimeout.stop();
		if (root.adapter && root.adapter.discovering)
			root.adapter.discovering = false;
	}

	spacing: SC.Config.spacing.small
	width: parent ? parent.width : SC.Config.networkPanel.width - SC.Config.padding.large * 2

	Component.onDestruction: root.stopScan()

	Timer {
		id: scanTimeout

		interval: 15000
		repeat: false

		onTriggered: root.stopScan()
	}
	Item {
		id: hero

		height: implicitHeight
		implicitHeight: Math.max(heroIcon.implicitHeight, title.implicitHeight + status.implicitHeight + SC.Config.padding.micro, bluetoothToggle.height)
		width: parent.width

		MaterialIcon {
			id: heroIcon

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			centered: false
			code: root.enabled ? root.connectedDevice ? 0xE0DC : 0xE0DA : 0xE0DE
			iconColor: root.connectedDevice ? SC.Config.colors.primary : SC.Config.colors.surface5
			iconSize: 30
		}
		Text {
			id: title

			anchors.left: heroIcon.right
			anchors.leftMargin: SC.Config.spacing.normal
			anchors.right: bluetoothToggle.left
			anchors.rightMargin: SC.Config.spacing.normal
			anchors.verticalCenter: parent.verticalCenter
			anchors.verticalCenterOffset: -(status.implicitHeight + SC.Config.padding.micro) / 2
			color: SC.Config.colors.fg
			elide: Text.ElideRight
			font.pointSize: 12
			font.weight: Font.DemiBold
			text: !root.adapter ? "Bluetooth unavailable" : root.connectedDevice ? root.connectedDevice.name || root.connectedDevice.deviceName : "Bluetooth"
		}
		Text {
			id: status

			anchors.left: title.left
			anchors.right: title.right
			anchors.top: title.bottom
			anchors.topMargin: SC.Config.padding.micro
			color: root.blocked ? SC.Config.colors.destructive : SC.Config.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			font.weight: Font.Medium
			text: !root.adapter ? "NO ADAPTER" : BluetoothAdapterState.toString(root.adapter.state).toUpperCase() + (root.adapter.adapterId ? " · " + root.adapter.adapterId.toUpperCase() : "")
		}
		Rectangle {
			id: bluetoothToggle

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			color: root.enabled ? SC.Config.colors.primary : SC.Config.colors.surface3
			height: 24
			radius: height / 2
			visible: root.adapter !== null
			width: 44

			Rectangle {
				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.bg
				height: 18
				radius: height / 2
				width: height
				x: root.enabled ? parent.width - width - 3 : 3
			}
			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				enabled: root.adapter !== null && !root.toggling && !root.blocked

				onClicked: root.adapter.enabled = !root.adapter.enabled
			}
		}
	}
	Rectangle {
		color: SC.Config.colors.surface2
		height: 1
		width: parent.width
	}
	Grid {
		columnSpacing: SC.Config.spacing.large
		columns: 3
		rowSpacing: SC.Config.spacing.normal
		visible: root.details.length > 0
		width: parent.width

		Repeater {
			model: root.details

			delegate: Text {
				required property string modelData

				color: SC.Config.colors.surface5
				font.pointSize: 8
				font.weight: Font.Medium
				text: modelData
				width: (parent.width - parent.columnSpacing * 2) / 3
			}
		}
	}
	Rectangle {
		color: SC.Config.colors.surface2
		height: 1
		visible: root.enabled
		width: parent.width
	}
	Item {
		height: visible ? root.sectionHeaderHeight : 0
		visible: root.enabled
		width: parent.width

		NetworkUi.NetworkSectionHeader {
			id: scanHeader

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			text: root.discovering ? "SCANNING DEVICES" : "BLUETOOTH DEVICES"
		}
		Row {
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: SC.Config.spacing.extraSmall

			LoaderIcon {
				id: scanLoader

				anchors.verticalCenter: parent.verticalCenter
				centered: false
				visible: root.discovering
			}
			Text {
				id: scanLabel

				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.primary
				font.pointSize: 8
				font.weight: Font.DemiBold
				text: root.discovering ? "SCANNING" : "SCAN"

				MouseArea {
					anchors.fill: parent
					anchors.margins: -SC.Config.padding.small
					cursorShape: Qt.PointingHandCursor
					enabled: !root.discovering && !root.toggling

					onClicked: root.scan()
				}
			}
		}
	}
	DirectScrollList {
		clip: true
		height: visible ? root.deviceListHeight : 0
		model: pairedModel
		spacing: SC.Config.spacing.extraSmall
		visible: root.enabled && pairedModel.values.length > 0
		width: parent.width

		delegate: BluetoothRow {
			required property BluetoothDevice modelData

			device: modelData
			width: ListView.view.width
		}
	}
	Item {
		height: visible ? root.sectionHeaderHeight : 0
		visible: root.enabled && otherModel.values.length > 0
		width: parent.width

		NetworkUi.NetworkSectionHeader {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			text: "OTHER DEVICES"
		}
	}
	DirectScrollList {
		clip: true
		height: visible ? root.deviceListHeight : 0
		model: otherModel
		spacing: SC.Config.spacing.extraSmall
		visible: root.enabled && otherModel.values.length > 0
		width: parent.width

		delegate: BluetoothRow {
			required property BluetoothDevice modelData

			device: modelData
			width: ListView.view.width
		}
	}
	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: !root.adapter ? "No Bluetooth adapter found" : root.blocked ? "Bluetooth is blocked" : !root.enabled ? "Bluetooth is disabled" : !root.discovering && pairedModel.values.length === 0 && otherModel.values.length === 0 ? "No devices found" : ""
		visible: text !== ""
	}
	ScriptModel {
		id: pairedModel

		values: root.devices.filter(device => device && (device.paired || device.bonded)).sort(root.compareDevices)
	}
	ScriptModel {
		id: otherModel

		values: root.devices.filter(device => device && !device.paired && !device.bonded).sort(root.compareDevices)
	}
}
