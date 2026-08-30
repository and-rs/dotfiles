import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.Bar

Rectangle {
  id: trayRect

  readonly property bool active: controller.activeMenu === "tray"
  required property Item controller
  readonly property bool hasItems: (SystemTray.items.values ?? []).length > 0
  readonly property real horizontalPadding: controller.buttonHorizontalPadding

  color: "transparent"
  height: controller.window.implicitHeight
  width: controller.window.implicitHeight + horizontalPadding * 2

  MaterialIcon {
    id: trayIcon

    code: !hasItems ? 0xECE0 : active ? 0xE13C : 0xE136
    iconColor: !hasItems ? Config.colors.surface3 : active ? Config.colors.destructive : Config.colors.fg
    iconSize: 18
  }
  MouseArea {
    anchors.fill: parent

    onClicked: if (hasItems)
      controller.switchMenu("tray")
  }
}
