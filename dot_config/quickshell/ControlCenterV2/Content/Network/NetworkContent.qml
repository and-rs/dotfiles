pragma ComponentBehavior: Bound

import QtQuick
import QtQml
import Quickshell.Networking
import qs.Bar
import qs.Config as SC

Column {
	id: root

	readonly property var connectedNetwork: NetworkService.connectedNetwork
	property alias debugHeroStatus: status
	property alias debugHeroTitle: title
	property alias debugNetworkList: networkList
	readonly property var details: root.buildDetails()
	readonly property bool discoveryEnabled: root.wifiDevice !== null && root.wifiDevice.scannerEnabled
	readonly property int networkRowHeight: 48
	readonly property bool searchingNetworks: root.discoveryEnabled && NetworkService.wifiNetworks.length === 0
	readonly property var wifiDevice: NetworkService.wifiDevice
	readonly property var wiredDevice: NetworkService.wiredDevice

	function buildDetails() {
		const values = [];
		let interfaceName = "";
		let adapterAddress = "";

		if (root.wiredDevice && root.wiredDevice.hasLink) {
			interfaceName = root.wiredDevice.name;
			adapterAddress = root.wiredDevice.address;
		} else if (root.wifiDevice) {
			interfaceName = root.wifiDevice.name;
			adapterAddress = root.wifiDevice.address;
		}

		values.push(root.detailText("INTERFACE", interfaceName));
		let signal = "";
		let security = "";
		if (root.connectedNetwork) {
			signal = Math.round(root.connectedNetwork.signalStrength * 100) + "%";
			security = WifiSecurityType.toString(root.connectedNetwork.security);
		}

		values.push(root.detailText("WI-FI SIGNAL", signal));
		values.push(root.detailText("WI-FI SECURITY", security));
		values.push(root.detailText("ADAPTER", adapterAddress));

		if (root.wiredDevice && root.wiredDevice.hasLink) {
			let speed = "Connected";
			if (root.wiredDevice.linkSpeed > 0)
				speed = root.wiredDevice.linkSpeed + " Mbps";

			values.push(root.detailText("ETHERNET", speed));
		}

		values.push(root.detailText("HOST INTERNET", NetworkConnectivity.toString(Networking.connectivity)));
		return values.filter(text => {
			return text !== "";
		});
	}

	function detailText(label, value) {
		if (!value)
			return "";

		return label + "\n" + value;
	}

	function emptyNetworkMessage() {
		if (!NetworkService.available)
			return "";

		if (!root.wifiDevice)
			return "No Wi-Fi device found";

		if (!NetworkService.wifiEnabled)
			return "Wi-Fi is disabled";

		if (root.searchingNetworks)
			return "";

		if (NetworkService.wifiNetworks.length === 0)
			return "No networks found";

		return "";
	}

	function heroIconCode() {
		if (root.wiredDevice && root.wiredDevice.hasLink)
			return 0xEDDE;

		if (!root.connectedNetwork)
			return 0xE4F2;

		if (root.connectedNetwork.signalStrength > 0.75)
			return 0xE4EA;

		if (root.connectedNetwork.signalStrength > 0.5)
			return 0xE4EE;

		if (root.connectedNetwork.signalStrength > 0.25)
			return 0xE4EC;

		return 0xE4F0;
	}

	function heroTitle() {
		if (!NetworkService.available)
			return "Network unavailable";

		if (root.wiredDevice && root.wiredDevice.hasLink)
			return "Ethernet";

		if (root.connectedNetwork)
			return root.connectedNetwork.name;

		if (root.wifiDevice)
			return "Wi-Fi";

		return "No network device";
	}

	function networkListHeight(limit) {
		const networks = NetworkService.wifiNetworks;
		const count = Math.min(limit, networks.length);
		let height = count * root.networkRowHeight + Math.max(0, count - 1) * SC.Config.spacing.extraSmall;
		for (let index = 0; index < count; index++) {
			if (index === 0 || networks[index].known !== networks[index - 1].known)
				height += SC.Config.sizes.normal + SC.Config.spacing.extraSmall;
		}

		return height;
	}

	spacing: SC.Config.spacing.small
	width: {
		if (parent)
			return parent.width;

		return SC.Config.networkPanel.width - SC.Config.padding.large * 2;
	}

	Binding {
		// Discovery follows this panel's Loader lifetime and Wi-Fi state.
		property: "scannerEnabled"
		restoreMode: Binding.RestoreBindingOrValue
		target: root.wifiDevice
		value: NetworkService.wifiEnabled
		when: root.wifiDevice !== null
	}

	Item {
		id: hero

		height: implicitHeight
		implicitHeight: Math.max(heroIcon.implicitHeight, title.implicitHeight + status.implicitHeight + SC.Config.padding.micro, wifiToggle.height)
		width: parent.width

		MaterialIcon {
			id: heroIcon

			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			centered: false
			code: root.heroIconCode()
			iconColor: {
				if (root.connectedNetwork || (root.wiredDevice && root.wiredDevice.connected))
					return SC.Config.colors.primary;

				return SC.Config.colors.surface4;
			}
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
			text: root.heroTitle()
		}

		Text {
			id: status

			anchors.left: title.left
			anchors.right: title.right
			anchors.top: title.bottom
			anchors.topMargin: SC.Config.padding.micro
			color: SC.Config.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			font.weight: Font.Medium
			text: {
				if (!NetworkService.available)
					return "Networking backend unavailable";

				if (root.wiredDevice && root.wiredDevice.hasLink)
					return ConnectionState.toString(root.wiredDevice.state);

				if (!NetworkService.wifiEnabled)
					return "Wi-Fi is disabled";

				if (root.wifiDevice)
					return ConnectionState.toString(root.wifiDevice.state);

				return "No adapter available";
			}
		}

		Rectangle {
			id: wifiToggle

			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			color: {
				if (NetworkService.wifiEnabled)
					return SC.Config.colors.primary;

				return SC.Config.colors.surface3;
			}
			height: 24
			radius: height / 2 * SC.Config.radius.multiplier
			visible: root.wifiDevice !== null
			width: 44

			Rectangle {
				anchors.verticalCenter: parent.verticalCenter
				color: SC.Config.colors.bg
				height: 18
				radius: height / 2 * SC.Config.radius.multiplier
				width: height
				x: {
					if (NetworkService.wifiEnabled)
						return parent.width - width - 3;

					return 3;
				}
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor

				onClicked: {
					NetworkService.lastError = "";
					Networking.wifiEnabled = !Networking.wifiEnabled;
				}
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
		visible: root.wifiDevice !== null && NetworkService.wifiEnabled
		width: parent.width
	}

	Column {
		id: networkSection

		spacing: SC.Config.spacing.extraSmall
		visible: root.wifiDevice !== null && NetworkService.wifiEnabled
		width: parent.width

		Item {
			height: SC.Config.sizes.normal
			visible: root.searchingNetworks
			width: parent.width

			Row {
				anchors.right: parent.right
				anchors.rightMargin: SC.Config.padding.small
				anchors.verticalCenter: parent.verticalCenter
				spacing: SC.Config.spacing.extraSmall

				LoaderIcon {
					id: scanLoader

					anchors.verticalCenter: parent.verticalCenter
					centered: false
					iconColor: scanLabel.color
				}

				Text {
					id: scanLabel

					anchors.verticalCenter: parent.verticalCenter
					color: SC.Config.colors.primary
					font.pointSize: 8
					font.weight: Font.DemiBold
					text: "SEARCHING"
				}
			}
		}

		DirectScrollList {
			id: networkList

			clip: true
			height: root.networkListHeight(3)
			model: NetworkService.wifiNetworks
			section.property: "known"
			spacing: SC.Config.spacing.extraSmall
			visible: count > 0
			width: parent.width

			delegate: NetworkRow {
				required property WifiNetwork modelData

				colors: SC.Config.colors
				network: modelData
				rowHeight: root.networkRowHeight
				width: ListView.view.width
			}
			section.delegate: Item {
				id: networkGroup

				required property string section

				height: SC.Config.sizes.normal + SC.Config.spacing.extraSmall
				width: networkList.width

				NetworkSectionHeader {
					anchors.left: parent.left
					anchors.leftMargin: SC.Config.padding.small
					anchors.top: parent.top
					height: SC.Config.sizes.normal
					text: {
						if (networkGroup.section === "true")
							return "SAVED NETWORKS";

						return "OTHER NETWORKS";
					}
					verticalAlignment: Text.AlignVCenter
				}
			}
		}
	}

	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: root.emptyNetworkMessage()
		visible: text !== ""
	}

	Text {
		color: SC.Config.colors.destructive
		font.pointSize: 8
		text: NetworkService.lastError
		visible: text !== ""
		width: parent.width
		wrapMode: Text.Wrap
	}
}
