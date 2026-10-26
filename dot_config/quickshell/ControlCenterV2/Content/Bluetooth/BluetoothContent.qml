pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.Bar
import qs.Config as SC
import qs.ControlCenterV2.Content.Network as NetworkUi

Column {
	id: root

	readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
	readonly property bool blocked: root.adapter !== null && root.adapter.state === BluetoothAdapterState.Blocked
	readonly property bool canScan: root.enabled && !root.blocked && !root.toggling && !root.discovering
	readonly property BluetoothDevice connectedDevice: {
		const devices = root.devices;
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].connected)
				return devices[i];
		}
		return null;
	}
	readonly property var details: root.buildDetails()
	readonly property int deviceRowHeight: 48
	readonly property var devices: {
		if (!root.adapter)
			return [];

		return root.adapter.devices.values.slice().sort(root.compareDevices);
	}
	readonly property bool discovering: root.adapter !== null && root.adapter.discovering
	readonly property bool enabled: root.adapter && root.adapter.enabled
	readonly property bool toggling: root.adapter && (root.adapter.state === BluetoothAdapterState.Enabling || root.adapter.state === BluetoothAdapterState.Disabling)

	function buildDetails() {
		if (!root.adapter)
			return [];

		const values = [root.detail("ADAPTER", root.adapter.name || root.adapter.adapterId), root.detail("ID", root.adapter.adapterId), root.detail("STATE", BluetoothAdapterState.toString(root.adapter.state))];
		if (root.connectedDevice) {
			values.push(root.detail("CONNECTED", root.connectedDevice.name || root.connectedDevice.deviceName || "1"));
			if (root.connectedDevice.batteryAvailable)
				values.push(root.detail("BATTERY", Math.round(root.connectedDevice.battery * 100) + "%"));
		} else if (root.enabled) {
			values.push(root.detail("CONNECTED", "0"));
		}

		return values.filter(detail => {
			return detail !== null;
		});
	}

	function compareDevices(a, b) {
		if (root.isPaired(a) !== root.isPaired(b)) {
			if (root.isPaired(a))
				return -1;

			return 1;
		}
		if (a.connected !== b.connected) {
			if (a.connected)
				return -1;

			return 1;
		}
		const an = (a.name || a.deviceName || a.address || "").toLowerCase();
		const bn = (b.name || b.deviceName || b.address || "").toLowerCase();
		return an.localeCompare(bn);
	}

	function detail(label, value) {
		if (!value)
			return null;

		return {
			label: label,
			value: value
		};
	}

	function deviceListHeight(limit) {
		const count = Math.min(limit, root.devices.length);
		let height = count * root.deviceRowHeight + Math.max(0, count - 1) * SC.Config.spacing.extraSmall;
		for (let index = 0; index < count; index++) {
			if (index === 0 || root.isPaired(root.devices[index]) !== root.isPaired(root.devices[index - 1]))
				height += SC.Config.sizes.normal + SC.Config.spacing.extraSmall;
		}

		return height;
	}

	function emptyMessage() {
		if (!root.adapter)
			return "No Bluetooth adapter found";

		if (root.blocked)
			return "Bluetooth is blocked";

		if (!root.enabled)
			return "Bluetooth is disabled";

		if (!root.discovering && root.devices.length === 0)
			return "No devices found";

		return "";
	}

	function isPaired(device) {
		return device.paired || device.bonded;
	}

	function scan() {
		if (!root.canScan)
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
	width: {
		if (parent)
			return parent.width;

		return SC.Config.networkPanel.width - SC.Config.padding.large * 2;
	}

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
			code: {
				if (!root.enabled)
					return 0xE0DE;

				if (root.connectedDevice)
					return 0xE0DC;

				return 0xE0DA;
			}
			iconColor: {
				if (root.connectedDevice)
					return SC.Config.colors.primary;

				return SC.Config.colors.surface5;
			}
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
			text: {
				if (!root.adapter)
					return "Bluetooth unavailable";

				if (root.connectedDevice)
					return root.connectedDevice.name || root.connectedDevice.deviceName;

				return "Bluetooth";
			}
		}

		Text {
			id: status

			anchors.left: title.left
			anchors.right: title.right
			anchors.top: title.bottom
			anchors.topMargin: SC.Config.padding.micro
			color: {
				if (root.blocked)
					return SC.Config.colors.destructive;

				return SC.Config.colors.surface5;
			}
			elide: Text.ElideRight
			font.pointSize: 8
			font.weight: Font.Medium
			text: {
				if (!root.adapter)
					return "NO ADAPTER";

				let text = BluetoothAdapterState.toString(root.adapter.state).toUpperCase();
				if (root.adapter.adapterId)
					text += " · " + root.adapter.adapterId.toUpperCase();

				return text;
			}
		}

		Rectangle {
			id: bluetoothToggle

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			color: {
				if (root.enabled)
					return SC.Config.colors.primary;

				return SC.Config.colors.surface3;
			}
			height: 24
			radius: height / 2 * SC.Config.radius.multiplier
			visible: root.adapter !== null
			width: 44

			Rectangle {
				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.bg
				height: 18
				radius: height / 2 * SC.Config.radius.multiplier
				width: height
				x: {
					if (root.enabled)
						return parent.width - width - 3;

					return 3;
				}
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				enabled: root.adapter !== null && !root.toggling && !root.blocked

				onClicked: {
					root.adapter.enabled = !root.adapter.enabled;
				}
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
				required property var modelData

				color: SC.Config.colors.surface5
				font.pointSize: 8
				font.weight: Font.Medium
				text: modelData.label + "\n" + modelData.value
				width: (parent.width - parent.columnSpacing * 2) / 3
			}
		}

		Column {
			visible: root.adapter !== null
			width: (parent.width - parent.columnSpacing * 2) / 3

			Text {
				id: scanHeading

				color: SC.Config.colors.surface5
				font.pointSize: 8
				font.weight: Font.Medium
				text: "DISCOVERY"
			}

			Item {
				height: Math.max(scanLabel.implicitHeight, scanLoader.iconSize)
				width: parent.width

				Row {
					id: scanAction

					height: parent.height
					opacity: {
						if (root.canScan || root.discovering)
							return 1;

						return 0.5;
					}
					spacing: SC.Config.spacing.extraSmall

					Item {
						height: scanLoader.iconSize
						visible: root.discovering
						width: height

						LoaderIcon {
							id: scanLoader

							iconColor: scanLabel.color
							visible: root.discovering
						}
					}

					Text {
						id: scanLabel

						anchors.verticalCenter: parent.verticalCenter
						color: SC.Config.colors.primary
            font.underline: true

						text: {
							if (root.discovering)
								return "Scanning…";

							return "Scan";
						}
					}
				}

				MouseArea {
					anchors.fill: scanAction
					cursorShape: Qt.PointingHandCursor
					enabled: root.canScan

					onClicked: root.scan()
				}
			}
		}
	}

	Rectangle {
		color: SC.Config.colors.surface2
		height: 1
		visible: root.enabled
		width: parent.width
	}

	DirectScrollList {
		id: deviceList

		clip: true
		height: root.deviceListHeight(3)
		model: root.devices.map(device => {
			let group = "OTHER DEVICES";
			if (root.isPaired(device))
				group = "PAIRED DEVICES";

			return {
				device: device,
				group: group
			};
		})
		section.property: "group"
		spacing: SC.Config.spacing.extraSmall
		visible: root.enabled && count > 0
		width: parent.width

		delegate: BluetoothRow {
			required property var modelData

			colors: SC.Config.colors
			device: modelData.device
			rowHeight: root.deviceRowHeight
			width: ListView.view.width
		}
		section.delegate: Item {
			id: deviceGroup

			required property string section

			height: SC.Config.sizes.normal + SC.Config.spacing.extraSmall
			width: deviceList.width

			NetworkUi.NetworkSectionHeader {
				anchors.left: parent.left
				anchors.leftMargin: SC.Config.padding.small
				anchors.top: parent.top
				height: SC.Config.sizes.normal
				text: deviceGroup.section
				verticalAlignment: Text.AlignVCenter
			}
		}
	}

	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: root.emptyMessage()
		visible: text !== ""
	}
}
