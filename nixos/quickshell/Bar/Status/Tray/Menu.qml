import Quickshell
import QtQuick
import qs.Bar

Column {
    id: root
    width: parent ? parent.width : Config.popup.width
    required property Item controller
    spacing: Config.spacing.small

    onVisibleChanged: {
        if (!visible)
            itemList.expandedIndex = -1;
    }

    Text {
        text: "System Tray"
        color: Config.colors.fg
        font.pointSize: 10
        font.weight: 700
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.surface2
    }

    ItemList {
        id: itemList
        width: parent.width
        controller: root.controller
    }
}
