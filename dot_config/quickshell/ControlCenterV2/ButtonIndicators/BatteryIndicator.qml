import QtQuick
import Quickshell.Services.UPower
import qs.Config as SC

Row {
	id: root

	readonly property string borderColor: SC.Config.colors.surface3

	readonly property int borderWidth: 2

	readonly property bool charging: {
		if (!device || !device.ready)
			return false;
		const state = device.state;
		return state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge;
	}
	readonly property var device: UPower.displayDevice

	readonly property color fillColor: {
		if (fillLevel < 0.2)
			return SC.Config.colors.destructive;
		if (!charging)
			return SC.Config.colors.fg;
		const success = Qt.color(SC.Config.colors.success);
		if (Qt.color(SC.Config.colors.bg).hslLightness < 0.5)
			return success;
		const saturation = Math.min(1, success.hslSaturation * 1.08);
		const lightness = Math.min(1, success.hslLightness + 0.15);
		return Qt.hsla(success.hslHue, saturation, lightness, 1);
	}

	readonly property real percentage: device && device.ready ? device.percentage : 0
	readonly property real fillLevel: Math.max(0, Math.min(1, percentage))
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
		color: SC.Config.colors.fg
		font.pointSize: 10
		font.weight: 600
		text: String(Math.round(root.fillLevel * 100)) + "%"
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
				anchors.margins: root.borderWidth - 0.5
				clip: true

				Rectangle {
					anchors.bottom: parent.bottom
					anchors.left: parent.left
					anchors.top: parent.top
					color: root.fillColor
					width: parent.width * root.fillLevel
				}
			}
			Rectangle {
				anchors.fill: parent
				border.color: root.borderColor
				border.width: root.borderWidth
				color: "transparent"
				radius: SC.Config.radius.small
			}
			BatteryBoltIcon {
				anchors.fill: parent
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
			color: root.borderColor
			height: (batteryShell.height - root.borderWidth / 2) / 2
			topRightRadius: SC.Config.radius.small
			width: 2.5
		}
	}
}
