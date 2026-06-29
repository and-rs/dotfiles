import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Bar

Rectangle {
  id: bluetooth

  readonly property var adapter: {
    let adapters = Bluetooth.adapters.values ?? [];
    return adapters.length > 0 ? adapters[0] : null;
  }
  required property Item controller
  readonly property bool hasConnectedDevice: {
    let devs = Bluetooth.devices.values ?? [];
    for (let i = 0; i < devs.length; i++) {
      if (devs[i] && devs[i].connected)
        return true;
    }
    return false;
  }
  readonly property real horizontalPadding: controller.buttonHorizontalPadding
  readonly property int iconCode: {
    if (!isEnabled)
      return 0xE0DE;
    if (hasConnectedDevice)
      return 0xE0DC;
    return 0xE0DA;
  }
  readonly property color iconColor: {
    if (!isEnabled)
      return Config.colors.surface3;
    if (hasConnectedDevice)
      return Config.colors.primary;
    return Config.colors.fg;
  }
  readonly property bool isEnabled: adapter && adapter.enabled

  color: "transparent"
  height: controller.window.implicitHeight
  width: controller.window.implicitHeight + horizontalPadding * 2

  MaterialIcon {
    code: bluetooth.iconCode
    iconColor: bluetooth.iconColor
    iconSize: 16
  }
  MouseArea {
    anchors.fill: parent

    onClicked: controller.switchMenu("bluetooth")
  }
}
