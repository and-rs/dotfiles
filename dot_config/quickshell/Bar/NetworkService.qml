pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "NetworkModel.js" as NetworkModel

Singleton {
	id: root

	property string _operation: ""
	property string _output: ""
	property bool _scanRequested: false
	property string actionNetworkId: ""
	property string actionState: "idle"
	property bool available: false
	property string backend: "none"
	readonly property string backendScript: Quickshell.shellDir + "/Bar/NetworkBackend.sh"
	property var connectedNetwork: null
	property string connectivity: "Unknown"
	property string lastError: ""
	property bool panelOpen: false
	property string scanState: "idle"
	property bool stale: false
	property var wifiDevice: null
	property bool wifiEnabled: false
	property var wifiNetworks: []
	property var wiredDevice: null

	function applySnapshot(next, preserveNetworks) {
		if (!next)
			return;

		backend = next.backend;
		available = next.available;
		connectivity = next.connectivity;
		wifiEnabled = next.wifiEnabled;
		wifiDevice = next.wifiDevice;
		wiredDevice = next.wiredDevice;
		connectedNetwork = next.connectedNetwork;
		if (!preserveNetworks)
			wifiNetworks = next.wifiNetworks;
		stale = false;
		lastError = next.error;
	}
	function closePanel() {
		panelOpen = false;
		_scanRequested = false;
	}
	function complete(exitCode) {
		const operation = _operation;
		_operation = "";
		const output = _output;
		_output = "";

		if (operation === "status") {
			const next = NetworkModel.parseSnapshot(output);
			if (exitCode === 0 && next)
				applySnapshot(next, panelOpen && wifiNetworks.length > 0);
			else
				fail("Network status probe failed");
			if (panelOpen && _scanRequested && wifiDevice)
				startScan();
			return;
		}

		const result = NetworkModel.parseResult(output);
		if (!result) {
			fail(operation === "scan" ? "Wi-Fi scan failed" : "Network action failed");
		} else if (!result.ok) {
			lastError = result.error || "Network action failed";
		} else {
			lastError = "";
			if (result.snapshot)
				applySnapshot(result.snapshot, operation === "scan");
			if (operation === "scan") {
				wifiNetworks = result.wifiNetworks.filter(function (network) {
					return !connectedNetwork || network.name !== connectedNetwork.name;
				});
			}
		}

		if (operation === "scan")
			scanState = "idle";
		else {
			actionState = "idle";
			actionNetworkId = "";
			refresh();
		}
	}
	function connect(network) {
		if (!network || !network.known || !wifiDevice || networkProcess.running)
			return;
		actionState = "connecting";
		actionNetworkId = network.id;
		start("action", ["connect", wifiDevice.name, network.name]);
	}
	function disconnect() {
		if (!wifiDevice || networkProcess.running)
			return;
		actionState = "disconnecting";
		actionNetworkId = connectedNetwork ? connectedNetwork.id : "";
		start("action", ["disconnect", wifiDevice.name]);
	}
	function fail(message) {
		stale = available;
		lastError = message || "Network status unavailable";
	}
	function openPanel() {
		panelOpen = true;
		refresh();
		scan();
	}
	function refresh() {
		if (!networkProcess.running)
			start("status", []);
	}
	function scan() {
		_scanRequested = true;
		if (networkProcess.running || !wifiDevice)
			return;
		startScan();
	}
	function start(operation, args) {
		_operation = operation;
		_output = "";
		networkProcess.command = ["bash", backendScript, operation].concat(args || []);
		networkProcess.running = true;
	}
	function startScan() {
		scanState = "scanning";
		_scanRequested = false;
		start("scan", []);
	}
	function toggleWifi(enabled) {
		if (!wifiDevice || networkProcess.running)
			return;
		actionState = "toggling";
		start("action", [enabled ? "wifi-on" : "wifi-off", wifiDevice.name]);
	}

	Component.onCompleted: refresh()

	Timer {
		interval: 3000
		repeat: true
		running: true

		onTriggered: root.refresh()
	}
	Process {
		id: networkProcess

		stdout: StdioCollector {
			waitForEnd: true

			onStreamFinished: root._output = text
		}

		onExited: function (exitCode) {
			root.complete(exitCode);
		}
	}
}
