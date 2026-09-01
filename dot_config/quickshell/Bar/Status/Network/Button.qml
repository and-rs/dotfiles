import QtQuick
import qs.Bar
import qs.Config
import qs.Bar.Status as Status

Rectangle {
	id: network

	readonly property var connectedNetwork: NetworkService.connectedNetwork
	readonly property var connectedWiredNetwork: wiredDevice && wiredDevice.hasLink ? wiredDevice.network : null
	required property Status.StatusMenus controller
	readonly property bool hasInternet: NetworkService.connectivity === "Full"
	readonly property real horizontalPadding: controller.buttonHorizontalPadding
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
			return hasInternet ? Config.colors.fg : Config.colors.destructive;
		if (!wifiEnabled || !connectedNetwork)
			return Config.colors.surface4;
		if (!hasInternet)
			return Config.colors.destructive;
		return Config.colors.fg;
	}
	readonly property bool showWifiGhost: !connectedWiredNetwork && wifiDevice !== null
	readonly property real signalStrength: connectedNetwork ? connectedNetwork.signalStrength : 0
	readonly property var wifiDevice: NetworkService.wifiDevice
	readonly property bool wifiEnabled: NetworkService.wifiEnabled
	readonly property var wiredDevice: NetworkService.wiredDevice

	color: "transparent"
	height: controller.window.implicitHeight
	width: controller.window.implicitHeight + horizontalPadding * 2

	MaterialIcon {
		code: 0xE4EA
		iconColor: Config.colors.surface4
		iconSize: 16
		opacity: 0.55
		visible: network.showWifiGhost
	}
	MaterialIcon {
		code: network.iconCode
		iconColor: network.iconColor
		iconSize: 16
	}
	MouseArea {
		anchors.fill: parent

		onClicked: controller.switchMenu("network")
	}
}
