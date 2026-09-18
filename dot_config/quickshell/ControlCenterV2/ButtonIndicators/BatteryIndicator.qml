import QtQuick
import Quickshell.Services.UPower
import qs.Config as SC

Row {
	id: root

	readonly property string boltBorderColor: Qt.alpha(SC.Config.colors.fg, 0.7)
	readonly property string borderColor: SC.Config.colors.surface3
	readonly property string chargingColor: Qt.alpha(Qt.lighter(SC.Config.colors.success, 1.6), 0.6)
	//readonly property string chargingColor: SC.Config.colors.success

	readonly property int borderWidth: 2
	readonly property bool charging: device && device.ready && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
	readonly property var device: UPower.displayDevice
	readonly property color fillColor: fillLevel < 0.2 ? SC.Config.colors.destructive : charging ? chargingColor : SC.Config.colors.fg
	readonly property real fillLevel: Math.max(0, Math.min(1, percentage))
	readonly property bool hasBattery: {
		const devices = UPower.devices.values ?? [];
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].isLaptopBattery)
				return true;
		}
		return false;
	}
	readonly property real percentage: device && device.ready ? device.percentage : 0

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
				borderColor: root.boltBorderColor

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
