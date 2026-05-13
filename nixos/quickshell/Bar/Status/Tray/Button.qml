import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import qs.Bar

Rectangle {
  id: trayRect
  required property Item controller

  readonly property real horizontalPadding: controller.buttonHorizontalPadding
  readonly property bool active: controller.activeMenu === "tray"
  readonly property bool hasItems: (SystemTray.items.values ?? []).length > 0

  width: controller.window.implicitHeight + horizontalPadding * 2
  height: controller.window.implicitHeight
  color: "transparent"

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
