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

  PopupWindow {
    id: trayPopup
    anchor.window: trayRect.window
    grabFocus: true

    onVisibleChanged: {
      if (!visible && window.activePopup === "tray")
        window.activePopup = "";
    }

    anchor.rect.x: {
      window.width; // idk why this works this way but we need to reference
      trayRect.width;
      var pos = trayRect.mapToItem(window.contentItem, 0, 0);
      return pos.x - (width / 2) + (trayRect.width / 2);
    }
    anchor.rect.y: window.height + 6

    implicitWidth: trayItem.rowWidth + 8
    implicitHeight: trayRect.width + 2
    visible: popupVisible
    color: "transparent"

    TrayItem {
      id: trayItem
      popupVisible: trayRect.popupVisible
    }
  }
}
