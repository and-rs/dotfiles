import Quickshell
import QtQuick
import qs.Bar

Rectangle {
  id: trayRect
  width: window.implicitHeight
  height: window.implicitHeight
  color: "transparent"

  required property PanelWindow window
  readonly property bool hasItems: trayItem.itemCount > 0
  readonly property bool popupVisible: window.activePopup === "tray"

  MaterialIcon {
    id: trayIcon
    code: !hasItems ? 0xECE0 : popupVisible ? 0xE13C : 0xE136
    iconColor: !hasItems ? Config.colors.bright : popupVisible ? Config.colors.destructive : Config.colors.fg
    iconSize: 18
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (hasItems)
      window.switchPopup("tray")
  }

  onPopupVisibleChanged: {
    if (!popupVisible)
      trayItem.expandedIndex = -1;
  }

  PopupPanel {
    anchor_item: trayRect
    window: trayRect.window
    popupVisible: trayRect.popupVisible

    // Header
    Text {
      text: "System Tray"
      color: Config.colors.fg
      font.pointSize: 10
      font.weight: 700
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Config.colors.muted
    }

    TrayItem {
      id: trayItem
      width: parent.width
    }
  }
}
