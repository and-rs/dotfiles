pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Networking
import QtQuick
import QtQml.Models

Singleton {
	id: root

	readonly property bool available: Networking.backend !== NetworkBackendType.None
	readonly property var connectedNetwork: root.connectedWifiNetwork()
	property string lastError: ""
	readonly property var wifiDevice: root.findDevice(DeviceType.Wifi)
	readonly property bool wifiEnabled: Networking.wifiEnabled
	readonly property var wifiNetworks: root.sortedWifiNetworks()
	readonly property var wiredDevice: root.findDevice(DeviceType.Wired)

	function canAct(network) {
		if (!network || network.stateChanging)
			return false;

		const device = network.device;
		if (device.state === ConnectionState.Connecting || device.state === ConnectionState.Disconnecting)
			return false;

		return !device.networks.values.some(candidate => {
			return candidate.stateChanging;
		});
	}

	function connect(network) {
		if (!root.canAct(network) || !network.known || network.connected)
			return;

		root.lastError = "";
		network.connect();
	}

	function connectedWifiNetwork() {
		for (const network of root.wifiNetworks) {
			if (network.connected)
				return network;
		}

		return null;
	}

	function disconnect(network) {
		if (!root.canAct(network) || !network.connected)
			return;

		root.lastError = "";
		network.disconnect();
	}

	function findDevice(type) {
		for (const device of Networking.devices.values) {
			if (device.type === type)
				return device;
		}

		return null;
	}

	function sortedWifiNetworks() {
		if (!root.wifiDevice)
			return [];

		const networks = root.wifiDevice.networks.values.slice();
		networks.sort(function (left, right) {
			if (left.connected && !right.connected)
				return -1;

			if (!left.connected && right.connected)
				return 1;

			if (left.known && !right.known)
				return -1;

			if (!left.known && right.known)
				return 1;

			if (left.signalStrength !== right.signalStrength)
				return right.signalStrength - left.signalStrength;

			return left.name.localeCompare(right.name);
		});

		return networks;
	}

	Instantiator {
		model: root.wifiNetworks

		delegate: Connections {
			required property WifiNetwork modelData

			function onConnectionFailed(reason) {
				root.lastError = modelData.name + ": " + ConnectionFailReason.toString(reason);
			}

			target: modelData
		}
	}
}
