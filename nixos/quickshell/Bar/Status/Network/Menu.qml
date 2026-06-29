import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Bar

Column {
  id: root

  readonly property var connectedNetwork: {
    if (useIwd)
      return IwdService.connectedNetwork;
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
  readonly property bool hasInternet: useIwd ? IwdService.connectivity === "Full" : Networking.connectivity === NetworkConnectivity.Full
  readonly property var networkDevices: Networking.devices.values ?? []
  readonly property var nmWifiDevice: {
    for (let i = 0; i < networkDevices.length; i++) {
      if (networkDevices[i] && networkDevices[i].type === DeviceType.Wifi)
        return networkDevices[i];
    }
    return null;
  }
  readonly property var nmWiredDevice: {
    for (let i = 0; i < networkDevices.length; i++) {
      if (networkDevices[i] && networkDevices[i].type === DeviceType.Wired)
        return networkDevices[i];
    }
    return null;
  }
  readonly property real signalStrength: connectedNetwork ? connectedNetwork.signalStrength : 0
  readonly property color statusColor: {
    if (connectedWiredNetwork)
      return hasInternet ? Config.colors.fg : Config.colors.destructive;
    if (!wifiEnabled || !connectedNetwork)
      return Config.colors.surface3;
    if (!hasInternet)
      return Config.colors.destructive;
    return Config.colors.fg;
  }
  readonly property string statusText: useIwd ? IwdService.connectivity : Networking.canCheckConnectivity ? NetworkConnectivity.toString(Networking.connectivity) : "Unknown"
  readonly property bool useIwd: !nmWifiDevice && !nmWiredDevice && IwdService.available
  readonly property var wifiDevice: useIwd ? IwdService.wifiDevice : nmWifiDevice
  readonly property bool wifiEnabled: useIwd ? IwdService.wifiEnabled : Networking.wifiEnabled
  readonly property var wiredDevice: useIwd ? null : nmWiredDevice

  spacing: Config.spacing.small
  width: parent ? parent.width : 0

  Text {
    color: Config.colors.fg
    font.pointSize: 10
    font.weight: 700
    text: "Network"
  }
  Rectangle {
    color: Config.colors.surface2
    height: 1
    width: parent.width
  }
  Row {
    spacing: Config.spacing.small

    Text {
      color: Config.colors.surface4
      font.pointSize: 9
      text: "Status"
    }
    Text {
      color: root.statusColor
      font.pointSize: 9
      font.weight: 600
      text: root.statusText
    }
  }
  Row {
    spacing: Config.spacing.small

    Text {
      color: Config.colors.surface4
      font.pointSize: 9
      text: "WiFi"
    }
    Text {
      color: root.wifiEnabled ? Config.colors.success : Config.colors.surface3
      font.pointSize: 9
      font.weight: 600
      text: root.wifiEnabled ? "Enabled" : "Disabled"
    }
  }
  Column {
    spacing: Config.spacing.small
    visible: root.connectedNetwork !== null
    width: parent.width

    Rectangle {
      color: Config.colors.surface2
      height: 1
      width: parent.width
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "SSID"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.connectedNetwork ? root.connectedNetwork.name : ""
      }
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "Signal"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: Math.round(root.signalStrength * 100) + "%"
      }
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "Security"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.connectedNetwork ? root.useIwd ? root.connectedNetwork.security : WifiSecurityType.toString(root.connectedNetwork.security) : ""
      }
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "Saved"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.connectedNetwork && root.connectedNetwork.known ? "Yes" : "No"
      }
    }
  }
  Column {
    spacing: Config.spacing.small
    visible: root.wifiDevice !== null
    width: parent.width

    Rectangle {
      color: Config.colors.surface2
      height: 1
      width: parent.width
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "Device"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.wifiDevice ? root.wifiDevice.name : ""
      }
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "State"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.wifiDevice ? root.useIwd ? root.wifiDevice.state : ConnectionState.toString(root.wifiDevice.state) : ""
      }
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "MAC"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.wifiDevice ? root.wifiDevice.address : ""
      }
    }
  }
  Column {
    spacing: Config.spacing.small
    visible: root.wiredDevice !== null
    width: parent.width

    Rectangle {
      color: Config.colors.surface2
      height: 1
      width: parent.width
    }
    Row {
      spacing: Config.spacing.small

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "Ethernet"
      }
      Text {
        color: root.wiredDevice && root.wiredDevice.hasLink ? Config.colors.success : Config.colors.surface3
        font.pointSize: 9
        font.weight: 600
        text: root.wiredDevice && root.wiredDevice.hasLink ? "Plugged" : "Unplugged"
      }
    }
    Row {
      spacing: Config.spacing.small
      visible: root.wiredDevice && root.wiredDevice.hasLink

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "Network"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.connectedWiredNetwork ? root.connectedWiredNetwork.name : ""
      }
    }
    Row {
      spacing: Config.spacing.small
      visible: root.wiredDevice && root.wiredDevice.hasLink

      Text {
        color: Config.colors.surface4
        font.pointSize: 9
        text: "Speed"
      }
      Text {
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 600
        text: root.wiredDevice && root.wiredDevice.linkSpeed > 0 ? root.wiredDevice.linkSpeed + " Mbps" : "Unknown"
      }
    }
  }
  Text {
    color: Config.colors.surface3
    font.pointSize: 9
    text: "Not connected"
    visible: !root.connectedWiredNetwork && !root.connectedNetwork && root.wifiEnabled
  }
  Text {
    color: Config.colors.surface3
    font.pointSize: 9
    text: "WiFi is disabled"
    visible: !root.connectedWiredNetwork && !root.wifiEnabled
  }
}
