import Quickshell
import QtQuick
import qs.Bar

Rectangle {
  id: trayRect
  width: 22
  height: 22
  color: "transparent"

  required property PanelWindow window
  readonly property bool hasItems: trayItem.itemCount > 0

  MaterialIcon {
    id: trayIcon
    code: !hasItems ? 0xe15b : popupVisible ? 0xf508 : 0xe69b
    y: -4
    iconColor: !hasItems ? Config.colors.bright : popupVisible ? Config.colors.destructive : Config.colors.fg
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

    anchor.rect.x: parent.x + trayRect.width / 2 - implicitWidth / 2
    anchor.rect.y: parentWindow.height + 4

    implicitWidth: trayItem.rowWidth + 16
    implicitHeight: trayItem.rowHeight + 16
    visible: popupVisible || trayItem.opacity > 0
    color: "transparent"

    TrayItem {
      id: trayItem
      popupVisible: trayRect.popupVisible
    }
  }
}
