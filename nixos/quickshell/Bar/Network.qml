import QtQuick
import Quickshell
import Quickshell.Networking

Rectangle {
  id: network
  width: window.implicitHeight
  height: window.implicitHeight
  anchors.verticalCenter: parent.verticalCenter
  color: "transparent"

  required property PanelWindow window
  readonly property bool popupVisible: window.activePopup === "network"

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

    if (!Networking.wifiEnabled || !connectedNetwork)
      return Config.colors.surface3;

    if (!hasInternet)
      return Config.colors.destructive;

    return Config.colors.fg;
  }

  MaterialIcon {
    code: network.iconCode
    iconColor: network.iconColor
    iconSize: 16
  }

  MouseArea {
    anchors.fill: parent
    onClicked: window.switchPopup("network")
  }

  PopupPanel {
    anchor_item: network
    window: network.window
    popupVisible: network.popupVisible

      // Header
      Text {
        text: "Network"
        color: Config.colors.fg
        font.pointSize: 10
        font.weight: 700
      }

      // Separator
      Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.surface2
      }

      // Connectivity
      Row {
        spacing: Config.spacing.small
        Text {
          text: "Status"
          color: Config.colors.surface4
          font.pointSize: 9
        }
        Text {
          text: Networking.canCheckConnectivity ? NetworkConnectivity.toString(Networking.connectivity) : "Unknown"
          color: network.iconColor
          font.pointSize: 9
          font.weight: 600
        }
      }

      // WiFi enabled
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

      // Connected network info
      Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: connectedNetwork !== null

        Rectangle {
          width: parent.width
          height: 1
          color: Config.colors.surface2
        }

        // SSID
        Row {
          spacing: Config.spacing.small
          Text {
            text: "SSID"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: connectedNetwork ? connectedNetwork.name : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }

        // Signal
        Row {
          spacing: Config.spacing.small
          Text {
            text: "Signal"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: Math.round(signalStrength * 100) + "%"
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }

        // Security
        Row {
          spacing: Config.spacing.small
          Text {
            text: "Security"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: connectedNetwork ? WifiSecurityType.toString(connectedNetwork.security) : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }

        // Known
        Row {
          spacing: Config.spacing.small
          Text {
            text: "Saved"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: connectedNetwork && connectedNetwork.known ? "Yes" : "No"
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }
      }

      // Device info
      Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: wifiDevice !== null

        Rectangle {
          width: parent.width
          height: 1
          color: Config.colors.surface2
        }

        // Device name
        Row {
          spacing: Config.spacing.small
          Text {
            text: "Device"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: wifiDevice ? wifiDevice.name : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }

        // Device state
        Row {
          spacing: Config.spacing.small
          Text {
            text: "State"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: wifiDevice ? ConnectionState.toString(wifiDevice.state) : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }

        // Address
        Row {
          spacing: Config.spacing.small
          Text {
            text: "MAC"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: wifiDevice ? wifiDevice.address : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }
      }

      // Wired info
      Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: wiredDevice !== null

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
            text: wiredDevice && wiredDevice.hasLink ? "Plugged" : "Unplugged"
            color: wiredDevice && wiredDevice.hasLink ? Config.colors.success : Config.colors.surface3
            font.pointSize: 9
            font.weight: 600
          }
        }

        Row {
          spacing: Config.spacing.small
          visible: wiredDevice && wiredDevice.hasLink
          Text {
            text: "Network"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: connectedWiredNetwork ? connectedWiredNetwork.name : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }

        Row {
          spacing: Config.spacing.small
          visible: wiredDevice && wiredDevice.hasLink
          Text {
            text: "Speed"
            color: Config.colors.surface4
            font.pointSize: 9
          }
          Text {
            text: wiredDevice && wiredDevice.linkSpeed > 0 ? wiredDevice.linkSpeed + " Mbps" : "Unknown"
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }
      }

      // Disconnected state
      Text {
        visible: !connectedWiredNetwork && !connectedNetwork && Networking.wifiEnabled
        text: "Not connected"
        color: Config.colors.surface3
        font.pointSize: 9
      }

      Text {
        visible: !connectedWiredNetwork && !Networking.wifiEnabled
        text: "WiFi is disabled"
        color: Config.colors.surface3
        font.pointSize: 9
      }
  }
}