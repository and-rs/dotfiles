import QtQuick
import Quickshell
import Quickshell.Networking
import qs.Bar

Rectangle {
  id: network
  required property Item controller

  readonly property real horizontalPadding: controller.buttonHorizontalPadding
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
  readonly property bool showWifiGhost: !connectedWiredNetwork && wifiDevice !== null

  width: controller.window.implicitHeight + horizontalPadding * 2
  height: controller.window.implicitHeight
  anchors.verticalCenter: parent.verticalCenter
  color: "transparent"

  MaterialIcon {
    visible: network.showWifiGhost
    code: 0xE4EA
    iconColor: Config.colors.surface4
    iconSize: 16
    opacity: 0.55
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
