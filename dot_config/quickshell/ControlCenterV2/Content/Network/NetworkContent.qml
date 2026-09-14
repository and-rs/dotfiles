pragma ComponentBehavior: Bound

import QtQuick
import qs.Bar
import qs.Config as SC

Column {
	id: root

	readonly property var connectedNetwork: NetworkService.connectedNetwork
	property alias debugHeroStatus: status
	property alias debugHeroTitle: title
	property alias debugNetworkList: networkList
	readonly property var knownNetworks: NetworkService.wifiNetworks.filter(network => network.known)
	readonly property var otherNetworks: NetworkService.wifiNetworks.filter(network => !network.known)
	property var passwordNetwork: null
	property string passwordText: ""
	readonly property var wifiDevice: NetworkService.wifiDevice
	readonly property var wiredDevice: NetworkService.wiredDevice

	function activateNetwork(network) {
		if (!network)
			return;
		if (network.security === "Open" || NetworkService.backend === "iwctl") {
			NetworkService.connect(network, "");
			return;
		}
		passwordNetwork = network;
		passwordText = "";
	}
	function submitPassword() {
		if (!passwordNetwork || passwordText.length === 0)
			return;
		NetworkService.connect(passwordNetwork, passwordText);
		passwordText = "";
		passwordNetwork = null;
	}

	spacing: SC.Config.spacing.small
	width: parent ? parent.width : SC.Config.networkPanel.width - SC.Config.padding.large * 2

	Component.onCompleted: NetworkService.openPanel()
	Component.onDestruction: NetworkService.closePanel()

	Item {
		id: hero

		implicitHeight: 48
		width: parent.width

		MaterialIcon {
			id: heroIcon

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			centered: false
			code: root.wiredDevice && root.wiredDevice.hasLink ? 0xEDDE : root.connectedNetwork ? 0xE4EA : 0xE4F2
			iconColor: NetworkService.connectivity === "Full" ? SC.Config.colors.primary : SC.Config.colors.surface4
			iconSize: 30
		}
		Text {
			id: title

			anchors.left: heroIcon.right
			anchors.leftMargin: SC.Config.spacing.normal
			anchors.right: wifiToggle.left
			anchors.rightMargin: SC.Config.spacing.normal
			anchors.verticalCenter: parent.verticalCenter
			anchors.verticalCenterOffset: -(status.implicitHeight + SC.Config.padding.micro) / 2
			color: SC.Config.colors.fg
			elide: Text.ElideRight
			font.pointSize: 12
			font.weight: Font.DemiBold
			text: !NetworkService.available ? "Network unavailable" : root.connectedNetwork ? root.connectedNetwork.name : root.wiredDevice && root.wiredDevice.hasLink ? "Ethernet" : root.wifiDevice ? "Wi-Fi" : "No network device"
		}
		Text {
			id: status

			anchors.left: title.left
			anchors.right: title.right
			anchors.top: title.bottom
			anchors.topMargin: SC.Config.padding.micro
			color: NetworkService.stale ? SC.Config.colors.destructive : SC.Config.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			font.weight: Font.Medium
			text: (NetworkService.stale ? "STALE · " : "") + NetworkService.connectivity.toUpperCase() + " · " + NetworkService.backend.toUpperCase()
		}
		Rectangle {
			id: wifiToggle

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			color: NetworkService.wifiEnabled ? SC.Config.colors.primary : SC.Config.colors.surface3
			height: 24
			radius: height / 2
			visible: root.wifiDevice !== null
			width: 44

			Rectangle {
				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.bg
				height: 18
				radius: height / 2
				width: height
				x: NetworkService.wifiEnabled ? parent.width - width - 3 : 3
			}
			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				enabled: NetworkService.actionState === "idle"

				onClicked: NetworkService.toggleWifi(!NetworkService.wifiEnabled)
			}
		}
	}
	Rectangle {
		color: SC.Config.colors.surface2
		height: 1
		width: parent.width
	}
	Item {
		height: visible ? Math.max(scanHeader.implicitHeight, scanLabel.implicitHeight, scanLoader.iconSize) : 0
		visible: root.wifiDevice !== null && NetworkService.wifiEnabled
		width: parent.width

		NetworkSectionHeader {
			id: scanHeader

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			text: NetworkService.scanState === "scanning" ? "SCANNING WI-FI" : "WI-FI NETWORKS"
		}
		Row {
			id: scanAction

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			spacing: SC.Config.spacing.extraSmall

			LoaderIcon {
				id: scanLoader

				anchors.verticalCenter: parent.verticalCenter
				centered: false
				visible: NetworkService.scanState === "scanning"
			}
			Text {
				id: scanLabel

				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.primary
				font.pointSize: 8
				font.weight: Font.DemiBold
				text: NetworkService.scanState === "scanning" ? "SCANNING" : "REFRESH"

				MouseArea {
					anchors.fill: parent
					anchors.margins: -SC.Config.padding.small
					cursorShape: Qt.PointingHandCursor
					enabled: NetworkService.scanState !== "scanning" && NetworkService.actionState === "idle"

					onClicked: NetworkService.scan()
				}
			}
		}
	}
	Column {
		id: networkList

		spacing: SC.Config.spacing.extraSmall
		visible: root.wifiDevice !== null && NetworkService.wifiEnabled
		width: parent.width

		DirectScrollList {
			clip: true
			height: visible ? Math.min(contentHeight, root.otherNetworks.length > 0 ? SC.Config.networkPanel.listHeight / 2 : SC.Config.networkPanel.listHeight) : 0
			model: root.knownNetworks
			spacing: SC.Config.spacing.extraSmall
			visible: root.knownNetworks.length > 0
			width: parent.width

			delegate: NetworkRow {
				required property var modelData

				network: modelData
				panel: root
				width: ListView.view.width
			}
		}
		DirectScrollList {
			clip: true
			height: visible ? Math.min(contentHeight, root.knownNetworks.length > 0 ? SC.Config.networkPanel.listHeight / 2 : SC.Config.networkPanel.listHeight) : 0
			model: root.otherNetworks
			spacing: SC.Config.spacing.extraSmall
			visible: root.otherNetworks.length > 0
			width: parent.width

			delegate: NetworkRow {
				required property var modelData

				network: modelData
				panel: root
				width: ListView.view.width
			}
		}
	}
	Text {
		color: NetworkService.lastError !== "" ? SC.Config.colors.destructive : SC.Config.colors.surface3
		font.pointSize: 9
		maximumLineCount: 2
		text: NetworkService.lastError || (root.wifiDevice === null ? "No Wi-Fi device found" : !NetworkService.wifiEnabled ? "Wi-Fi is disabled" : NetworkService.scanState === "idle" && NetworkService.wifiNetworks.length === 0 ? "No networks found" : "")
		visible: text !== ""
		width: parent.width
		wrapMode: Text.Wrap
	}
}
