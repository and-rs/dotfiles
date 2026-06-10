import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Bar

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: Config.spacing.small

    readonly property var wifiDevice: {
        let devs = Networking.devices.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                return devs[i];
        }
        return null;
    }
    readonly property var wiredDevice: {
        let devs = Networking.devices.values ?? [];
        for (let i = 0; i < devs.length; i++) {
            if (devs[i] && devs[i].type === DeviceType.Wired)
                return devs[i];
        }
        return null;
    }
    readonly property var connectedNetwork: {
        if (!wifiDevice)
            return null;
        let nets = wifiDevice.networks;
        if (!nets)
            return null;
        let list = nets.values ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].connected)
                return list[i];
        }
        return null;
    }
    readonly property var connectedWiredNetwork: wiredDevice && wiredDevice.hasLink ? wiredDevice.network : null
    readonly property real signalStrength: connectedNetwork ? connectedNetwork.signalStrength : 0
    readonly property bool hasInternet: Networking.connectivity === NetworkConnectivity.Full
    readonly property color statusColor: {
        if (connectedWiredNetwork)
            return hasInternet ? Config.colors.fg : Config.colors.destructive;
        if (!Networking.wifiEnabled || !connectedNetwork)
            return Config.colors.surface3;
        if (!hasInternet)
            return Config.colors.destructive;
        return Config.colors.fg;
    }

    Text {
        text: "Network"
        color: Config.colors.fg
        font.pointSize: 10
        font.weight: 700
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.surface2
    }

    Row {
        spacing: Config.spacing.small

        Text {
            text: "Status"
            color: Config.colors.surface4
            font.pointSize: 9
        }

        Text {
            text: Networking.canCheckConnectivity ? NetworkConnectivity.toString(Networking.connectivity) : "Unknown"
            color: root.statusColor
            font.pointSize: 9
            font.weight: 600
        }
    }

    Row {
        spacing: Config.spacing.small

        Text {
            text: "WiFi"
            color: Config.colors.surface4
            font.pointSize: 9
        }

        Text {
            text: Networking.wifiEnabled ? "Enabled" : "Disabled"
            color: Networking.wifiEnabled ? Config.colors.success : Config.colors.surface3
            font.pointSize: 9
            font.weight: 600
        }
    }

    Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: root.connectedNetwork !== null

        Rectangle {
            width: parent.width
            height: 1
            color: Config.colors.surface2
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "SSID"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.connectedNetwork ? root.connectedNetwork.name : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Signal"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: Math.round(root.signalStrength * 100) + "%"
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Security"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.connectedNetwork ? WifiSecurityType.toString(root.connectedNetwork.security) : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Saved"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.connectedNetwork && root.connectedNetwork.known ? "Yes" : "No"
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }
    }

    Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: root.wifiDevice !== null

        Rectangle {
            width: parent.width
            height: 1
            color: Config.colors.surface2
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Device"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.wifiDevice ? root.wifiDevice.name : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "State"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.wifiDevice ? ConnectionState.toString(root.wifiDevice.state) : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "MAC"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.wifiDevice ? root.wifiDevice.address : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }
    }

    Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: root.wiredDevice !== null

        Rectangle {
            width: parent.width
            height: 1
            color: Config.colors.surface2
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Ethernet"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.wiredDevice && root.wiredDevice.hasLink ? "Plugged" : "Unplugged"
                color: root.wiredDevice && root.wiredDevice.hasLink ? Config.colors.success : Config.colors.surface3
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small
            visible: root.wiredDevice && root.wiredDevice.hasLink

            Text {
                text: "Network"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.connectedWiredNetwork ? root.connectedWiredNetwork.name : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small
            visible: root.wiredDevice && root.wiredDevice.hasLink

            Text {
                text: "Speed"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.wiredDevice && root.wiredDevice.linkSpeed > 0 ? root.wiredDevice.linkSpeed + " Mbps" : "Unknown"
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }
    }

    Text {
        visible: !root.connectedWiredNetwork && !root.connectedNetwork && Networking.wifiEnabled
        text: "Not connected"
        color: Config.colors.surface3
        font.pointSize: 9
    }

    Text {
        visible: !root.connectedWiredNetwork && !Networking.wifiEnabled
        text: "WiFi is disabled"
        color: Config.colors.surface3
        font.pointSize: 9
    }
}
