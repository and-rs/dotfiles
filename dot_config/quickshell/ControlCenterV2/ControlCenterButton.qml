import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	readonly property var adapter: {
		const adapters = Bluetooth.adapters.values ?? [];
		return adapters.length > 0 ? adapters[0] : null;
	}
	readonly property bool bluetoothConnected: {
		const devices = Bluetooth.devices.values ?? [];
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].connected)
				return true;
		}
		return false;
	}
	readonly property bool bluetoothEnabled: adapter && adapter.enabled
	readonly property int bluetoothIconCode: {
		if (!bluetoothEnabled)
			return 0xE0DE;
		if (bluetoothConnected)
			return 0xE0DC;
		return 0xE0DA;
	}
	readonly property color bluetoothIconColor: {
		if (!bluetoothEnabled)
			return SC.Config.colors.surface4;
		if (bluetoothConnected)
			return SC.Config.colors.primary;
		return SC.Config.colors.fg;
	}
	readonly property bool charging: batteryDevice && batteryDevice.ready && (batteryDevice.state === UPowerDeviceState.Charging || batteryDevice.state === UPowerDeviceState.PendingCharge)
	readonly property var connectedNetwork: NetworkService.connectedNetwork
	readonly property var connectedWiredNetwork: wiredDevice && wiredDevice.hasLink ? wiredDevice.network : null
	readonly property var batteryDevice: UPower.displayDevice
	readonly property color batteryFillColor: batteryFillLevel < 0.2 ? SC.Config.colors.destructive : charging ? SC.Config.colors.success : SC.Config.colors.fg
	readonly property real batteryFillLevel: Math.max(0, Math.min(1, batteryPercentage))
	readonly property bool hasBattery: {
		const devices = UPower.devices.values ?? [];
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].isLaptopBattery)
				return true;
		}
		return false;
	}
	readonly property bool hasInternet: NetworkService.connectivity === "Full"
	readonly property bool hasTrayItems: (SystemTray.items.values ?? []).length > 0
	readonly property int networkIconCode: {
		if (connectedWiredNetwork)
			return hasInternet ? 0xEDDE : 0xEDDA;
		if (!connectedNetwork)
			return 0xE4F2;
		if (!hasInternet)
			return 0xE4F4;
		if (signalStrength > 0.75)
			return 0xE4EA;
		if (signalStrength > 0.50)
			return 0xE4EE;
		if (signalStrength > 0.25)
			return 0xE4EC;
		return 0xE4F0;
	}
	readonly property color networkIconColor: {
		if (connectedWiredNetwork)
			return hasInternet ? SC.Config.colors.fg : SC.Config.colors.destructive;
		if (!wifiEnabled || !connectedNetwork)
			return SC.Config.colors.surface4;
		if (!hasInternet)
			return SC.Config.colors.destructive;
		return SC.Config.colors.fg;
	}
	readonly property real batteryPercentage: batteryDevice && batteryDevice.ready ? batteryDevice.percentage : 0
	readonly property bool showWifiGhost: !connectedWiredNetwork && wifiDevice !== null
	readonly property real signalStrength: connectedNetwork ? connectedNetwork.signalStrength : 0
	readonly property var wifiDevice: NetworkService.wifiDevice
	readonly property bool wifiEnabled: NetworkService.wifiEnabled
	readonly property var wiredDevice: NetworkService.wiredDevice
	required property PanelWindow window

	anchors.verticalCenter: parent.verticalCenter
	color: hover.hovered ? SC.Config.colors.surface2 : SC.Config.colors.surface1
	height: window.implicitHeight - SC.Config.padding.micro
	implicitWidth: content.implicitWidth + SC.Config.padding.small * 2
	radius: SC.Config.radius.small

	HoverHandler {
		id: hover
	}
	Row {
		id: content

		anchors.centerIn: parent
		spacing: SC.Config.spacing.small

		Item {
			implicitHeight: SC.Config.sizes.normal
			implicitWidth: SC.Config.sizes.normal

			MaterialIcon {
				centered: true
				code: root.hasTrayItems ? 0xE136 : 0xECE0
				iconColor: root.hasTrayItems ? SC.Config.colors.fg : SC.Config.colors.surface4
				iconSize: SC.Config.sizes.normal
			}
		}
		Item {
			implicitHeight: SC.Config.sizes.normal
			implicitWidth: SC.Config.sizes.normal

			MaterialIcon {
				centered: true
				code: root.bluetoothIconCode
				iconColor: root.bluetoothIconColor
				iconSize: SC.Config.sizes.normal
			}
		}
		Item {
			implicitHeight: SC.Config.sizes.normal
			implicitWidth: SC.Config.sizes.normal

			MaterialIcon {
				centered: true
				code: 0xE4EA
				iconColor: SC.Config.colors.surface4
				iconSize: SC.Config.sizes.normal
				opacity: 0.55
				visible: root.showWifiGhost
			}
			MaterialIcon {
				centered: true
				code: root.networkIconCode
				iconColor: root.networkIconColor
				iconSize: SC.Config.sizes.normal
			}
		}
		Row {
			anchors.verticalCenter: parent.verticalCenter
			spacing: SC.Config.spacing.extraSmall
			visible: root.hasBattery

			Text {
				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.fg
				font.pointSize: 10
				font.weight: 600
				text: String(Math.round(root.batteryFillLevel * 100))
			}
			Row {
				anchors.verticalCenter: parent.verticalCenter

				Rectangle {
					id: batteryShell

					anchors.verticalCenter: parent.verticalCenter
					border.color: SC.Config.colors.surface2
					border.width: 2
					color: SC.Config.colors.surface2
					height: 15
					radius: SC.Config.radius.small
					width: 28

					Item {
						anchors.bottom: parent.bottom
						anchors.left: parent.left
						anchors.top: parent.top
						clip: true
						width: parent.width * root.batteryFillLevel

						Rectangle {
							border.color: SC.Config.colors.surface2
							border.width: 2
							color: root.batteryFillColor
							height: batteryShell.height
							radius: batteryShell.radius
							width: batteryShell.width
						}
					}
				}
				Rectangle {
					anchors.verticalCenter: parent.verticalCenter
					bottomRightRadius: SC.Config.radius.small
					color: SC.Config.colors.surface2
					height: (batteryShell.height - batteryShell.border.width / 2) / 2
					topRightRadius: SC.Config.radius.small
					width: 2.5
				}
			}
			Item {
				anchors.verticalCenter: parent.verticalCenter
				height: 14
				visible: root.charging
				width: 14

				MaterialIcon {
					anchors.centerIn: parent
					code: 0xE2DE
					iconColor: SC.Config.colors.success
					iconSize: 14
				}
			}
		}
	}
	MouseArea {
		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
	}
}
