import QtQuick
import qs.Bar
import qs.Config as SC

Item {
	id: root

	readonly property var connectedNetwork: NetworkService.connectedNetwork
	readonly property var connectedWiredNetwork: wiredDevice && wiredDevice.hasLink ? wiredDevice.network : null
	readonly property bool hasInternet: NetworkService.connectivity === "Full"
	readonly property int iconCode: {
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
	readonly property color iconColor: {
		if (connectedWiredNetwork)
			return hasInternet ? SC.Config.colors.fg : SC.Config.colors.destructive;
		if (!wifiEnabled || !connectedNetwork)
			return SC.Config.colors.surface4;
		if (!hasInternet)
			return SC.Config.colors.destructive;
		return SC.Config.colors.fg;
	}
	readonly property bool showWifiGhost: !connectedWiredNetwork && wifiDevice !== null
	readonly property real signalStrength: connectedNetwork ? connectedNetwork.signalStrength : 0
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
