import QtQuick
import Quickshell.Services.UPower
import qs.Bar
import qs.Config as SC

Column {
	id: root

	readonly property var activeHold: {
		const holds = PowerProfiles.holds ?? [];
		return holds.length > 0 ? holds[0] : null;
	}
	readonly property bool charging: ready && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
	readonly property var device: UPower.displayDevice
	readonly property bool discharging: ready && (device.state === UPowerDeviceState.Discharging || device.state === UPowerDeviceState.PendingDischarge)
	readonly property real energyCapacity: ready ? device.energyCapacity : 0
	readonly property real energyNow: ready ? device.energy : 0
	readonly property bool hasBattery: {
		const devices = UPower.devices.values ?? [];
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].isLaptopBattery)
				return true;
		}
		return false;
	}
	readonly property int healthPercent: healthSupported ? Math.round(device.healthPercentage * 100) : 0
	readonly property bool healthSupported: ready && device.healthSupported
	readonly property int percentInt: Math.round(Math.max(0, Math.min(1, percentage)) * 100)
	readonly property real percentage: ready ? device.percentage : 0
	readonly property real rateWatts: ready ? Math.abs(device.changeRate) : 0
	readonly property bool ready: device && device.ready

	function formatDuration(seconds) {
		const total = Math.max(0, Math.round(seconds || 0));
		if (total <= 0)
			return "—";
		const hours = Math.floor(total / 3600);
		const minutes = Math.floor((total % 3600) / 60);
		if (hours <= 0)
			return `${minutes}m`;
		if (minutes <= 0)
			return `${hours}h`;
		return `${hours}h ${minutes}m`;
	}
	function profileLabel(profile) {
		if (profile === PowerProfile.PowerSaver)
			return "Saver";
		if (profile === PowerProfile.Balanced)
			return "Balanced";
		return "Performance";
	}
	function setProfile(profile) {
		if (profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
			return;
		PowerProfiles.profile = profile;
	}

	spacing: SC.Config.spacing.small
	width: parent ? parent.width : 0

	Text {
		color: SC.Config.colors.fg
		font.pointSize: 10
		font.weight: 700
		text: "Battery"
	}
	Rectangle {
		color: SC.Config.colors.surface2
		height: 1
		width: parent.width
	}
	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: "No battery detected"
		visible: !root.hasBattery
	}
	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: "Loading…"
		visible: root.hasBattery && !root.ready
	}
	Column {
		spacing: SC.Config.spacing.small
		visible: root.hasBattery && root.ready
		width: parent.width

		Row {
			spacing: SC.Config.spacing.small

			Text {
				color: SC.Config.colors.surface4
				font.pointSize: 9
				text: "Charge"
			}
			Text {
				color: root.percentInt < 20 ? SC.Config.colors.destructive : SC.Config.colors.fg
				font.pointSize: 9
				font.weight: 700
				text: root.percentInt + "%"
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
				color: root.charging ? SC.Config.colors.primary : root.discharging ? SC.Config.colors.fg : SC.Config.colors.surface4
				font.pointSize: 9
				font.weight: 600
				text: UPowerDeviceState.toString(device.state)
			}
		}
		Row {
			spacing: SC.Config.spacing.small
			visible: root.charging || root.discharging

			Text {
				color: SC.Config.colors.surface4
				font.pointSize: 9
				text: root.charging ? "Time to full" : "Time left"
			}
			Text {
				color: SC.Config.colors.fg
				font.pointSize: 9
				font.weight: 600
				text: root.charging ? root.formatDuration(device.timeToFull) : root.formatDuration(device.timeToEmpty)
			}
		}
		Row {
			spacing: SC.Config.spacing.small
			visible: root.rateWatts > 0

			Text {
				color: SC.Config.colors.surface4
				font.pointSize: 9
				text: root.charging ? "Charging rate" : "Drain"
			}
			Text {
				color: SC.Config.colors.fg
				font.pointSize: 9
				font.weight: 600
				text: root.rateWatts.toFixed(1) + " W"
			}
		}
		Row {
			spacing: SC.Config.spacing.small

			Text {
				color: SC.Config.colors.surface4
				font.pointSize: 9
				text: "Energy"
			}
			Text {
				color: SC.Config.colors.fg
				font.pointSize: 9
				font.weight: 600
				text: root.energyNow.toFixed(1) + " / " + root.energyCapacity.toFixed(1) + " Wh"
			}
		}
		Row {
			spacing: SC.Config.spacing.small
			visible: root.healthSupported

			Text {
				color: SC.Config.colors.surface4
				font.pointSize: 9
				text: "Health"
			}
			Text {
				color: SC.Config.colors.fg
				font.pointSize: 9
				font.weight: 600
				text: root.healthPercent + "%"
			}
		}
		Rectangle {
			color: SC.Config.colors.surface2
			height: 1
			width: parent.width
		}
		Text {
			color: SC.Config.colors.fg
			font.pointSize: 9
			font.weight: 700
			text: "Power Mode"
		}
		Column {
			spacing: SC.Config.spacing.extraSmall
			width: parent.width

			Repeater {
				model: [
					{
						label: "Power Saver",
						icon: 0xE32C,
						value: PowerProfile.PowerSaver,
						available: true
					},
					{
						label: "Balanced",
						icon: 0xE18A,
						value: PowerProfile.Balanced,
						available: true
					},
					{
						label: "Performance",
						icon: 0xE3D6,
						value: PowerProfile.Performance,
						available: PowerProfiles.hasPerformanceProfile
					}
				]

				delegate: Rectangle {
					id: profileRow

					readonly property bool active: PowerProfiles.profile === profileRow.modelData.value
					readonly property bool available: profileRow.modelData.available
					required property var modelData

					color: active ? SC.Config.colors.primary : rowHover.hovered && available ? SC.Config.colors.surface2 : SC.Config.colors.surface1
					height: 32
					opacity: available ? 1 : 0.4
					radius: SC.Config.radius.small
					width: parent.width

					HoverHandler {
						id: rowHover
					}
					Row {
						anchors.fill: parent
						anchors.leftMargin: SC.Config.padding.small
						anchors.rightMargin: SC.Config.padding.small
						spacing: SC.Config.spacing.small

						Text {
							color: active ? SC.Config.colors.bg : SC.Config.colors.fg
							font.family: "Phosphor-Bold"
							font.pointSize: 12
							height: parent.height
							text: String.fromCodePoint(profileRow.modelData.icon)
							verticalAlignment: Text.AlignVCenter
							width: 16
						}
						Text {
							color: active ? SC.Config.colors.bg : SC.Config.colors.fg
							elide: Text.ElideRight
							font.pointSize: 9
							font.weight: active ? 700 : 500
							height: parent.height
							text: profileRow.modelData.label
							verticalAlignment: Text.AlignVCenter
							width: parent.width - 16 - SC.Config.spacing.small
						}
					}
					MouseArea {
						anchors.fill: parent
						cursorShape: profileRow.available ? Qt.PointingHandCursor : Qt.ArrowCursor
						enabled: profileRow.available

						onClicked: root.setProfile(profileRow.modelData.value)
					}
				}
			}
		}
		Text {
			color: SC.Config.colors.surface4
			font.pointSize: 8
			text: root.activeHold ? "Held by " + (root.activeHold.applicationId || "unknown") : ""
			visible: root.activeHold !== null
		}
	}
}
