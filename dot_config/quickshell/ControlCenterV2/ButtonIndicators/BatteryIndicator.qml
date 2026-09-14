import QtQuick
import Quickshell.Services.UPower
import qs.Bar
import qs.Config as SC

Row {
	id: root

	readonly property int borderWidth: 2
	readonly property var device: UPower.displayDevice
	readonly property bool charging: device && device.ready && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
	readonly property color fillColor: fillLevel < 0.2 ? SC.Config.colors.destructive : charging ? SC.Config.colors.success : SC.Config.colors.fg
	readonly property real fillLevel: Math.max(0, Math.min(1, percentage))
	readonly property real percentage: device && device.ready ? device.percentage : 0

	readonly property bool hasBattery: {
		const devices = UPower.devices.values ?? [];
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].isLaptopBattery)
				return true;
		}
		return false;
	}

	anchors.verticalCenter: parent.verticalCenter
	spacing: SC.Config.spacing.extraSmall
	visible: root.hasBattery

	Text {
		anchors.verticalCenter: parent.verticalCenter
		text: String(Math.round(root.fillLevel * 100)) + "%"
		color: SC.Config.colors.fg
		font.pointSize: 10
		font.weight: 600
	}
	Row {
		anchors.verticalCenter: parent.verticalCenter

		Item {
			id: batteryShell

			anchors.verticalCenter: parent.verticalCenter
			height: 16
			width: 30

			Item {
				id: fillClip

				anchors.fill: parent
				anchors.margins: root.borderWidth
				clip: true

				Rectangle {
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					anchors.top: parent.top
					color: root.fillColor
					radius: Math.max(0, SC.Config.radius.small - root.borderWidth)
					width: parent.width * root.fillLevel
				}
			}
			Rectangle {
				anchors.fill: parent
				border.color: SC.Config.colors.surface3
				border.width: root.borderWidth
				color: "transparent"
				radius: SC.Config.radius.small
			}
			PhosphorFillIcon {
				anchors.centerIn: parent
				code: 0xE2DE
				iconColor: SC.Config.colors.bg
				iconSize: 10
				opacity: root.charging ? 1 : 0

				Behavior on opacity {
					NumberAnimation {
						duration: SC.Config.durations.normal
						easing.type: SC.Config.curve
					}
				}
			}
		}
		Rectangle {
			anchors.verticalCenter: parent.verticalCenter
			bottomRightRadius: SC.Config.radius.small
			color: SC.Config.colors.surface3
			height: (batteryShell.height - root.borderWidth / 2) / 2
			topRightRadius: SC.Config.radius.small
			width: 2.5
		}
	}
}
