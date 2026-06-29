import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Bar

Rectangle {
  id: network

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
  required property Item controller
  readonly property bool hasInternet: useIwd ? IwdService.connectivity === "Full" : Networking.connectivity === NetworkConnectivity.Full
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
      return Config.colors.surface3;
    if (!hasInternet)
      return Config.colors.destructive;
    return Config.colors.fg;
  }
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
  readonly property bool showWifiGhost: !connectedWiredNetwork && wifiDevice !== null
  readonly property real signalStrength: connectedNetwork ? connectedNetwork.signalStrength : 0
  readonly property bool useIwd: !nmWifiDevice && !nmWiredDevice && IwdService.available
  readonly property var wifiDevice: useIwd ? IwdService.wifiDevice : nmWifiDevice
  readonly property bool wifiEnabled: useIwd ? IwdService.wifiEnabled : Networking.wifiEnabled
  readonly property var wiredDevice: useIwd ? null : nmWiredDevice

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
