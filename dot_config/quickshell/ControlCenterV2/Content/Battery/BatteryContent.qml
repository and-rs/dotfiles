pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import qs.Bar
import qs.Config as SC
import qs.ControlCenterV2.Content.Network as NetworkUi

Column {
	id: root

	readonly property var activeHold: {
		const holds = PowerProfiles.holds ?? [];
		return holds.length > 0 ? holds[0] : null;
	}
	readonly property bool charging: root.ready && (root.device.state === UPowerDeviceState.Charging || root.device.state === UPowerDeviceState.PendingCharge)
	readonly property var details: [root.detailText("CHARGE", root.ready ? root.percentInt + "%" : ""), root.detailText("STATE", root.ready ? UPowerDeviceState.toString(root.device.state) : ""), root.detailText("TIME", root.etaText), root.detailText("RATE", root.rateWatts > 0 ? root.rateWatts.toFixed(1) + " W" : ""), root.detailText("ENERGY", root.ready ? root.energyNow.toFixed(1) + " / " + root.energyCapacity.toFixed(1) + " Wh" : ""), root.detailText("HEALTH", root.healthSupported ? root.healthPercent + "%" : "")].filter(text => text !== "")
	readonly property var device: UPower.displayDevice
	readonly property bool discharging: root.ready && (root.device.state === UPowerDeviceState.Discharging || root.device.state === UPowerDeviceState.PendingDischarge)
	readonly property real energyCapacity: root.ready ? root.device.energyCapacity : 0
	readonly property real energyNow: root.ready ? root.device.energy : 0
	readonly property string etaText: {
		if (!root.charging && !root.discharging)
			return "";
		const text = root.charging ? root.formatDuration(root.device.timeToFull) : root.formatDuration(root.device.timeToEmpty);
		return text === "—" ? "" : text;
	}
	readonly property bool hasBattery: {
		const devices = UPower.devices.values ?? [];
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].isLaptopBattery)
				return true;
		}
		return false;
	}
	readonly property int healthPercent: root.healthSupported ? Math.round(root.device.healthPercentage * 100) : 0
	readonly property bool healthSupported: root.ready && root.device.healthSupported
	readonly property int percentInt: Math.round(Math.max(0, Math.min(1, root.percentage)) * 100)
	readonly property real percentage: root.ready ? root.device.percentage : 0
	readonly property real rateWatts: root.ready ? Math.abs(root.device.changeRate) : 0
	readonly property bool ready: root.device && root.device.ready

	function detailText(label, value) {
		return value ? label + "\n" + value : "";
	}
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

	spacing: SC.Config.spacing.small
	width: parent ? parent.width : SC.Config.networkPanel.width - SC.Config.padding.large * 2

	Item {
		id: hero

		height: implicitHeight
		implicitHeight: Math.max(heroIcon.implicitHeight, title.implicitHeight + status.implicitHeight + SC.Config.padding.micro)
		width: parent.width

		MaterialIcon {
			id: heroIcon

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			centered: false
			code: !root.hasBattery ? 0xE0BE : root.charging ? 0xE2DE : root.percentInt < 20 ? 0xE0C8 : root.percentInt < 50 ? 0xE0C6 : root.percentInt < 80 ? 0xE0C2 : 0xE0C0
			iconColor: !root.hasBattery || !root.ready ? SC.Config.colors.surface4 : root.percentInt < 20 ? SC.Config.colors.destructive : root.charging ? SC.Config.colors.primary : SC.Config.colors.surface4
			iconSize: 30
		}
		Text {
			id: title

			anchors.left: heroIcon.right
			anchors.leftMargin: SC.Config.spacing.normal
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			anchors.verticalCenterOffset: -(status.implicitHeight + SC.Config.padding.micro) / 2
			color: SC.Config.colors.fg
			elide: Text.ElideRight
			font.pointSize: 12
			font.weight: Font.DemiBold
			text: !root.hasBattery ? "No battery" : !root.ready ? "Battery" : root.percentInt + "%"
		}
		Text {
			id: status

			anchors.left: title.left
			anchors.right: title.right
			anchors.top: title.bottom
			anchors.topMargin: SC.Config.padding.micro
			color: root.percentInt < 20 && root.ready ? SC.Config.colors.destructive : SC.Config.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			font.weight: Font.Medium
			text: {
				if (!root.hasBattery)
					return "NO BATTERY";
				if (!root.ready)
					return "LOADING";
				const state = UPowerDeviceState.toString(root.device.state).toUpperCase();
				return root.etaText !== "" ? state + " · " + root.etaText.toUpperCase() : state;
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
		visible: root.hasBattery && root.ready
		width: parent.width
	}
	NetworkUi.NetworkSectionHeader {
		text: "POWER MODE"
		visible: root.hasBattery && root.ready
	}
	Column {
		id: profileList

		spacing: SC.Config.spacing.extraSmall
		visible: root.hasBattery && root.ready
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
					icon: 0xE46E,
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

			delegate: BatteryProfileRow {
				required property var modelData

				available: modelData.available
				icon: modelData.icon
				label: modelData.label
				profile: modelData.value
				width: profileList.width
			}
		}
	}
	Text {
		color: SC.Config.colors.surface4
		font.pointSize: 8
		text: root.activeHold ? "Held by " + (root.activeHold.applicationId || "unknown") : ""
		visible: root.hasBattery && root.ready && root.activeHold !== null
		width: parent.width
		wrapMode: Text.Wrap
	}
	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: !root.hasBattery ? "No battery detected" : !root.ready ? "Loading…" : ""
		visible: text !== ""
	}
}
