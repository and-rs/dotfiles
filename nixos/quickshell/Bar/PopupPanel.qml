import Quickshell
import QtQuick
import qs.Bar
import qs.Lock

PopupWindow {
  id: popup

  required property Item anchor_item
  required property PanelWindow window
  required property bool popupVisible

  default property alias content: contentColumn.data

  grabFocus: true
  anchor.window: popup.window
  visible: popupVisible && !LockService.locked
  color: "transparent"

  implicitWidth: Config.popup.width
  implicitHeight: contentColumn.implicitHeight + Config.padding.large * 2

  anchor.rect.x: {
    window.width;
    anchor_item.width;
    var pos = anchor_item.mapToItem(window.contentItem, 0, 0);
    return pos.x - (width / 2) + (anchor_item.width / 2);
  }
  anchor.rect.y: window.height + Config.popup.gap

  onVisibleChanged: {
    if (!visible && window.activePopup !== "")
      window.activePopup = "";
  }

  Item {
    id: wrapper
    anchors.fill: parent
    opacity: 0

    states: State {
      name: "visible"
      when: popup.popupVisible
      PropertyChanges { target: wrapper; opacity: 1 }
    }

    transitions: Transition {
      to: "visible"
      NumberAnimation {
        property: "opacity"
        duration: Config.durations.fast
        easing.type: Config.curves.standard
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Config.colors.bg
      border.color: Config.colors.accent
      border.width: Config.popup.borderWidth
      radius: Config.radius.normal
    }

    Column {
      id: contentColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Config.padding.large
      spacing: Config.spacing.small
    }
  }
}
