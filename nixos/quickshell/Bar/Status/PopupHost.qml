import Quickshell
import QtQuick
import qs.Bar
import qs.Lock

PopupWindow {
    id: popup

    required property Item controller
    required property Item hostItem
    required property Item activeButton
    required property Item batteryButton
    required property Item trayButton
    required property Item bluetoothButton
    required property Item networkButton
    required property PanelWindow window
    required property bool popupVisible

    default property alias content: contentColumn.data

  readonly property point hostPos: {
    window.windowTransform;
    hostItem.x;
    hostItem.y;
    hostItem.width;
    hostItem.height;
    return hostItem.mapToItem(window.contentItem, 0, 0);
  }
  readonly property real batteryPanelXInHost: batteryButton.x - (Config.popup.width / 2) + (batteryButton.width / 2)
  readonly property real trayPanelXInHost: trayButton.x - (Config.popup.width / 2) + (trayButton.width / 2)
  readonly property real bluetoothPanelXInHost: bluetoothButton.x - (Config.popup.width / 2) + (bluetoothButton.width / 2)
  readonly property real networkPanelXInHost: networkButton.x - (Config.popup.width / 2) + (networkButton.width / 2)
  readonly property real panelXInHost: activeButton.x - (Config.popup.width / 2) + (activeButton.width / 2)
  readonly property real leftEdge: Math.min(0, batteryPanelXInHost, trayPanelXInHost, bluetoothPanelXInHost, networkPanelXInHost)
  readonly property real rightEdge: Math.max(hostItem.width, batteryPanelXInHost + Config.popup.width, trayPanelXInHost + Config.popup.width, bluetoothPanelXInHost + Config.popup.width, networkPanelXInHost + Config.popup.width)
  readonly property real stripX: -leftEdge
  readonly property real panelX: panelXInHost - leftEdge
  readonly property real panelY: window.height + Config.popup.gap

  property bool keepAlive: false
  property string lastActive: ""

  grabFocus: true
  anchor.item: hostItem
  visible: !LockService.locked && (popupVisible || keepAlive)
  color: "transparent"

  implicitWidth: rightEdge - leftEdge
  implicitHeight: panelY + panelFrame.height

  anchor.rect.x: leftEdge
  anchor.rect.y: 0

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
    readonly property real batteryPanelXInHost: batteryButton.x - (Config.popup.width / 2) + (batteryButton.width / 2)
    readonly property real trayPanelXInHost: trayButton.x - (Config.popup.width / 2) + (trayButton.width / 2)
    readonly property real bluetoothPanelXInHost: bluetoothButton.x - (Config.popup.width / 2) + (bluetoothButton.width / 2)
    readonly property real networkPanelXInHost: networkButton.x - (Config.popup.width / 2) + (networkButton.width / 2)
    readonly property real panelXInHost: activeButton.x - (Config.popup.width / 2) + (activeButton.width / 2)
    readonly property real leftEdge: Math.min(0, batteryPanelXInHost, trayPanelXInHost, bluetoothPanelXInHost, networkPanelXInHost)
    readonly property real rightEdge: Math.max(hostItem.width, batteryPanelXInHost + Config.popup.width, trayPanelXInHost + Config.popup.width, bluetoothPanelXInHost + Config.popup.width, networkPanelXInHost + Config.popup.width)
    readonly property real stripX: -leftEdge
    readonly property real panelX: panelXInHost - leftEdge
    readonly property real panelY: window.height + Config.popup.gap

    property bool keepAlive: false

    grabFocus: true
    anchor.item: hostItem
    visible: !LockService.locked && (popupVisible || keepAlive)
    color: "transparent"

    implicitWidth: rightEdge - leftEdge
    implicitHeight: panelY + panelFrame.height

  Connections {
    target: controller

    function onActiveMenuChanged() {
      if (controller.activeMenu !== "")
        lastActive = controller.activeMenu;
    }
  }
  Item {
    anchors.fill: parent

    onPopupVisibleChanged: {
        if (popupVisible) {
            keepAlive = true;
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

    NumberAnimation {
        id: openAnim
        target: panelFrame
        property: "opacity"
        to: 1
        duration: Config.durations.instant
        easing.type: Config.curves.snap
    }

    NumberAnimation {
        id: closeAnim
        target: panelFrame
        property: "opacity"
        to: 0
        duration: Config.durations.instant
        easing.type: Config.curves.snap
        onFinished: {
            if (!popupVisible)
                keepAlive = false;
        }
    }

    Item {
      id: panelFrame
      x: popup.panelX
      y: popup.panelY
      width: Config.popup.width
      height: contentColumn.implicitHeight + Config.padding.large * 2
      opacity: 1

      Behavior on x {
        NumberAnimation {
          duration: Config.durations.instant
          easing.type: Easing.OutQuart
        }
      }

      Rectangle {
        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: controller.closeMenus()
        }

        MouseArea {
            x: popup.stripX + batteryButton.x
            y: batteryButton.y
            width: batteryButton.width
            height: batteryButton.height
            onClicked: controller.switchMenu("battery")
        }

        MouseArea {
            x: popup.stripX + trayButton.x
            y: trayButton.y
            width: trayButton.width
            height: trayButton.height
            onClicked: controller.switchMenu("tray")
        }

        MouseArea {
            x: popup.stripX + bluetoothButton.x
            y: bluetoothButton.y
            width: bluetoothButton.width
            height: bluetoothButton.height
            onClicked: controller.switchMenu("bluetooth")
        }

        MouseArea {
            x: popup.stripX + networkButton.x
            y: networkButton.y
            width: networkButton.width
            height: networkButton.height
            onClicked: controller.switchMenu("network")
        }

        Rectangle {
            visible: Config.popup.debug
            x: popup.stripX
            y: 0
            width: popup.hostItem.width
            height: popup.window.height
            color: "transparent"
            border.width: 1
            border.color: "#66ffcc00"
        }

        Repeater {
            model: [batteryButton, trayButton, bluetoothButton, networkButton]

            delegate: Rectangle {
                required property var modelData
                visible: Config.popup.debug
                x: popup.stripX + modelData.x
                y: modelData.y
                width: modelData.width
                height: modelData.height
                color: "transparent"
                border.width: 1
                border.color: "#66ff00ff"
            }
        }

        Item {
            id: panelFrame
            x: popup.panelX
            y: popup.panelY
            width: Config.popup.width
            height: contentColumn.implicitHeight + Config.padding.large * 2
            opacity: 1

            Behavior on x {
                NumberAnimation {
                    duration: Config.durations.instant
                    easing.type: Config.curves.snap
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Config.colors.base
                border.color: Config.popup.debug ? "#ff4444" : Config.colors.surface4
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
}
