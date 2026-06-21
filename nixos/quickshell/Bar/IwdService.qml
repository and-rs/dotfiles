pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool available: false
    property bool wifiEnabled: false
    property bool connected: false
    property string deviceName: ""
    property string state: "unknown"
    property string ssid: ""
    property string ipv4Address: ""
    property string bssid: ""
    property string security: ""
    property int rssi: -100
    property real signalStrength: 0
    property bool scanning: false
    property string connectivity: connected && ipv4Address ? "Full" : connected ? "Local" : "None"
    property bool canCheckConnectivity: true
    property var connectedNetwork: connected ? ({
        name: ssid,
        connected: true,
        known: true,
        security: security,
        signalStrength: signalStrength
    }) : null
    property var wifiDevice: available ? ({
        name: deviceName,
        type: "wifi",
        state: state,
        address: bssid,
        hasLink: connected,
        network: connectedNetwork,
        networks: {
            values: connectedNetwork ? [connectedNetwork] : []
        }
    }) : null

    function refresh(): void {
        if (!refreshProc.running)
            refreshProc.running = true;
    }

    function valueFor(text: string, label: string): string {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.indexOf(label) === 0)
                return line.slice(label.length).trim();
        }
        return "";
    }

    function parseRssi(value: string): int {
        const match = value.match(/-?\d+/);
        return match ? Number(match[0]) : -100;
    }

    function strengthFromRssi(value: int): real {
        return Math.max(0, Math.min(1, (value + 90) / 60));
    }

    function applyOutput(text: string): void {
        const station = valueFor(text, "Station:");
        const nextAvailable = station.length > 0;
        const nextState = valueFor(text, "State").toLowerCase();
        const nextSsid = valueFor(text, "Connected network");
        const nextIpv4Address = valueFor(text, "IPv4 address");
        const nextBssid = valueFor(text, "ConnectedBss");
        const nextSecurity = valueFor(text, "Security");
        const nextRssi = parseRssi(valueFor(text, "RSSI"));

        available = nextAvailable;
        wifiEnabled = nextAvailable;
        connected = nextState === "connected";
        deviceName = station;
        state = nextState || "unknown";
        ssid = nextSsid;
        ipv4Address = nextIpv4Address;
        bssid = nextBssid;
        security = nextSecurity;
        rssi = nextRssi;
        signalStrength = strengthFromRssi(nextRssi);
        scanning = valueFor(text, "Scanning") === "yes";
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: refreshProc
        command: ["sh", "-c", "dev=$(iwctl station list 2>/dev/null | sed -r 's/\\x1B\\[[0-9;]*[mK]//g' | sed -n 's/^ *\\([^ ]*\\)  *\\(connected\\|disconnected\\|connecting\\).*/\\1/p;T;q'); if [ -n \"$dev\" ]; then iwctl station \"$dev\" show 2>/dev/null | sed -r 's/\\x1B\\[[0-9;]*[mK]//g'; fi"]
        stdout: StdioCollector {
            onStreamFinished: root.applyOutput(this.text)
        }
        stderr: StdioCollector {}
    }
}
