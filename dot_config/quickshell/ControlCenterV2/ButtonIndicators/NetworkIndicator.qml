import QtQuick
import qs.Bar
import qs.Config as SC

Item {
	id: root

	readonly property var connectedNetwork: NetworkService.connectedNetwork
	readonly property var connectedWiredNetwork: {
		if (root.wiredDevice && root.wiredDevice.hasLink)
			return root.wiredDevice.network;

		return null;
	}
	readonly property int iconCode: {
		if (root.connectedWiredNetwork)
			return 0xEDDE;

		if (!root.connectedNetwork)
			return 0xE4F2;

		if (root.signalStrength > 0.75)
			return 0xE4EA;

		if (root.signalStrength > 0.50)
			return 0xE4EE;

		if (root.signalStrength > 0.25)
			return 0xE4EC;

		return 0xE4F0;
	}
	readonly property color iconColor: {
		if (root.connectedWiredNetwork)
			return SC.Config.colors.fg;

		if (!root.wifiEnabled || !root.connectedNetwork)
			return SC.Config.colors.surface4;

		return SC.Config.colors.fg;
	}
	readonly property bool showWifiGhost: !root.connectedWiredNetwork && root.wifiDevice !== null
	readonly property real signalStrength: {
		if (root.connectedNetwork)
			return root.connectedNetwork.signalStrength;

		return 0;
	}
	readonly property var wifiDevice: NetworkService.wifiDevice
	readonly property bool wifiEnabled: NetworkService.wifiEnabled
	readonly property var wiredDevice: NetworkService.wiredDevice

	implicitHeight: SC.Config.sizes.normal
	implicitWidth: SC.Config.sizes.normal

	MaterialIcon {
		code: 0xE4EA
		iconColor: SC.Config.colors.surface4
		iconSize: SC.Config.sizes.normal
		opacity: 0.55
		visible: root.showWifiGhost
	}

	MaterialIcon {
		code: root.iconCode
		iconColor: root.iconColor
		iconSize: SC.Config.sizes.normal
	}
}
