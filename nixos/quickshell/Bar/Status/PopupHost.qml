import Quickshell
import QtQuick
import qs.Bar
import qs.Lock

PopupWindow {
  id: popup

  required property Item activeButton
  required property Item batteryButton
  readonly property real batteryPanelXInHost: batteryButton.x - (Config.popup.width / 2) + (batteryButton.width / 2)
  required property Item bluetoothButton
  readonly property real bluetoothPanelXInHost: bluetoothButton.x - (Config.popup.width / 2) + (bluetoothButton.width / 2)
  default property alias content: contentColumn.data
  required property Item controller
  required property Item hostItem
  readonly property point hostPos: {
    window.windowTransform;
    hostItem.x;
    hostItem.y;
    hostItem.width;
    hostItem.height;
    return hostItem.mapToItem(window.contentItem, 0, 0);
  }
  property bool keepAlive: false
  property string lastActive: ""
  readonly property real leftEdge: Math.min(0, batteryPanelXInHost, trayPanelXInHost, bluetoothPanelXInHost, networkPanelXInHost)
  required property Item networkButton
  readonly property real networkPanelXInHost: networkButton.x - (Config.popup.width / 2) + (networkButton.width / 2)
  readonly property real panelX: panelXInHost - leftEdge
  readonly property real panelXInHost: activeButton.x - (Config.popup.width / 2) + (activeButton.width / 2)
  readonly property real panelY: window.height + Config.popup.gap
  required property bool popupVisible
  readonly property real rightEdge: Math.max(hostItem.width, batteryPanelXInHost + Config.popup.width, trayPanelXInHost + Config.popup.width, bluetoothPanelXInHost + Config.popup.width, networkPanelXInHost + Config.popup.width)
  readonly property real stripX: -leftEdge
  required property Item trayButton
  readonly property real trayPanelXInHost: trayButton.x - (Config.popup.width / 2) + (trayButton.width / 2)
  required property PanelWindow window

  anchor.item: hostItem
  anchor.rect.x: leftEdge
  anchor.rect.y: 0
  color: "transparent"
  grabFocus: true
  implicitHeight: panelY + panelFrame.height
  implicitWidth: rightEdge - leftEdge
  visible: !LockService.locked && (popupVisible || keepAlive)

  onPopupVisibleChanged: {
    if (popupVisible) {
      keepAlive = true;
      if (controller.activeMenu !== "")
        lastActive = controller.activeMenu;
      closeAnim.stop();
      panelFrame.opacity = 0;
      openAnim.restart();
    } else {
      openAnim.stop();
      closeAnim.restart();
    }
  }
  onVisibleChanged: {
    if (!visible)
      controller.closeMenus();
  }

  Connections {
    function onActiveMenuChanged() {
      if (controller.activeMenu !== "")
        lastActive = controller.activeMenu;
    }

    target: controller
  }
  NumberAnimation {
    id: openAnim

    duration: Config.durations.instant
    easing.type: Config.curve
    property: "opacity"
    target: panelFrame
    to: 1
  }
  NumberAnimation {
    id: closeAnim

    duration: Config.durations.instant
    easing.type: Config.curve
    property: "opacity"
    target: panelFrame
    to: 0

    onFinished: {
      if (!popupVisible)
        keepAlive = false;
    }
  }
  Item {
    anchors.fill: parent

    MouseArea {
      anchors.fill: parent

      onClicked: controller.closeMenus()
    }
    MouseArea {
      height: batteryButton.height
      width: batteryButton.width
      x: popup.stripX + batteryButton.x
      y: batteryButton.y

      onClicked: controller.switchMenu("battery")
    }
    MouseArea {
      height: trayButton.height
      width: trayButton.width
      x: popup.stripX + trayButton.x
      y: trayButton.y

      onClicked: controller.switchMenu("tray")
    }
    MouseArea {
      height: bluetoothButton.height
      width: bluetoothButton.width
      x: popup.stripX + bluetoothButton.x
      y: bluetoothButton.y

      onClicked: controller.switchMenu("bluetooth")
    }
    MouseArea {
      height: networkButton.height
      width: networkButton.width
      x: popup.stripX + networkButton.x
      y: networkButton.y

      onClicked: controller.switchMenu("network")
    }
    Rectangle {
      border.color: "#66ffcc00"
      border.width: 1
      color: "transparent"
      height: popup.window.height
      visible: Config.popup.debug
      width: popup.hostItem.width
      x: popup.stripX
      y: 0
    }
    Repeater {
      model: [batteryButton, trayButton, bluetoothButton, networkButton]

      delegate: Rectangle {
        required property var modelData

        border.color: "#66ff00ff"
        border.width: 1
        color: "transparent"
        height: modelData.height
        visible: Config.popup.debug
        width: modelData.width
        x: popup.stripX + modelData.x
        y: modelData.y
      }
    }
    Item {
      id: panelFrame

      height: contentColumn.implicitHeight + Config.padding.large * 2
      opacity: 1
      width: Config.popup.width
      x: popup.panelX
      y: popup.panelY

      Behavior on x {
        NumberAnimation {
          duration: Config.durations.instant
          easing.type: Config.curve
        }
      }

      Rectangle {
        anchors.fill: parent
        border.color: Config.popup.debug ? "#ff4444" : Config.colors.surface4
        border.width: Config.popup.borderWidth
        color: Config.colors.base
        radius: Config.radius.normal
      }
      Column {
        id: contentColumn

        anchors.left: parent.left
        anchors.margins: Config.padding.large
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Config.spacing.small
      }
    }
  }
}
