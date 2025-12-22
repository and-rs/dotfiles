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

  MaterialIcon {
    id: trayIcon
    code: !hasItems ? 0xf88a : popupVisible ? 0xf508 : 0xe313
    iconColor: !hasItems ? Config.colors.bright : popupVisible ? Config.colors.destructive : Config.colors.fg
    iconSize: 24
  }

  PopupWindow {
    id: overlay
    anchor.window: trayRect.window
    implicitWidth: screen.width
    implicitHeight: screen.height
    visible: popupVisible
    color: "transparent"

    Item {
      id: popupHole
      x: trayPopup.anchor.rect.x
      y: trayPopup.anchor.rect.y
      width: trayPopup.width
      height: trayPopup.height
    }

    mask: Region {
      item: popupHole
      intersection: Intersection.Xor
    }

    MouseArea {
      anchors.fill: parent
      onClicked: popupVisible = false
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (hasItems)
      popupVisible = !popupVisible
  }

  property bool popupVisible: false

  PopupWindow {
    id: trayPopup
    anchor.window: trayRect.window

    anchor.rect.x: {
      window.width; // idk why this works this way but we need to reference
      trayRect.width;
      var pos = trayRect.mapToItem(window.contentItem, 0, 0);
      return pos.x - (width / 2) + (trayRect.width / 2);
    }
    anchor.rect.y: window.height + 6

    implicitWidth: trayItem.rowWidth + 8
    implicitHeight: trayRect.width + 2
    visible: popupVisible || trayItem.opacity > 0
    color: "transparent"

    TrayItem {
      id: trayItem
      popupVisible: trayRect.popupVisible
    }
  }
}
