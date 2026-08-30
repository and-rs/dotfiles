import Quickshell
import QtQuick
import qs.Bar

Column {
  id: root

  required property Item controller

  spacing: Config.spacing.small
  width: parent ? parent.width : Config.popup.width

  onVisibleChanged: {
    if (!visible)
      itemList.expandedIndex = -1;
  }

  Text {
    color: Config.colors.fg
    font.pointSize: 10
    font.weight: 700
    text: "System Tray"
  }
  Rectangle {
    color: Config.colors.surface2
    height: 1
    width: parent.width
  }
  ItemList {
    id: itemList

    controller: root.controller
    width: parent.width
  }
}
