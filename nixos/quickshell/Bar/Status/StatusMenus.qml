import QtQuick
import Quickshell
import qs.Bar
import qs.Lock
import qs.Sidebar
import qs.Notification as Notifications
import qs.Bar.Status.Battery as BatteryStatus
import qs.Bar.Status.Bluetooth as BluetoothStatus
import qs.Bar.Status.Network as NetworkStatus
import qs.Bar.Status.Tray as TrayStatus

Item {
  id: root
  required property PanelWindow window

  readonly property bool menusBlocked: LockService.locked
  readonly property real buttonHorizontalPadding: Config.spacing.small / 3
  property string activeMenu: ""
  property string activePanel: ""

  readonly property Item activeButton: {
    if (activeMenu === "battery")
      return batteryButton;
    if (activeMenu === "bluetooth")
      return bluetoothButton;
    if (activeMenu === "network")
      return networkButton;
    if (activeMenu === "tray")
      return trayButton;
    return batteryButton;
  }

  implicitWidth: buttons.implicitWidth
  implicitHeight: buttons.implicitHeight

  function closeMenus() {
    activeMenu = "";
  }

  function closePanels() {
    activePanel = "";
  }

  function closeAll() {
    closeMenus();
    closePanels();
  }

  function switchMenu(id) {
    if (menusBlocked) {
      closeAll();
      return;
    }
    closePanels();
    activeMenu = activeMenu === id ? "" : id;
  }

  function switchPanel(id) {
    if (menusBlocked) {
      closeAll();
      return;
    }
    closeMenus();
    activePanel = activePanel === id ? "" : id;
  }

  Connections {
    target: LockService

    function onLockedChanged() {
      if (LockService.locked)
        root.closeAll();
    }
  }

  Row {
    id: buttons
    spacing: 0
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      id: notificationsButton
      readonly property bool active: root.activePanel === "notifications"
      readonly property bool hasNotifications: Notifications.NotificationStore.count > 0
      width: root.window.implicitHeight + root.buttonHorizontalPadding * 2
      height: root.window.implicitHeight
      color: "transparent"

      MaterialIcon {
        anchors.centerIn: parent
        code: notificationsButton.hasNotifications ? 0xE5E8 : 0xE0CE
        iconColor: notificationsButton.active ? Config.colors.primary : notificationsButton.hasNotifications ? Config.colors.fg : Config.colors.surface3
      }

      Rectangle {
        visible: Notifications.NotificationStore.count > 0
        width: Math.max(10, badgeText.implicitWidth + Config.padding.micro * 2)
        height: 14
        radius: 2
        color: Config.colors.destructive
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Config.padding.micro
        anchors.rightMargin: Config.padding.micro

        Text {
          id: badgeText
          anchors.centerIn: parent
          text: Notifications.NotificationStore.count > 99 ? "99+" : String(Notifications.NotificationStore.count)
          color: Config.colors.base
          font.pixelSize: Config.sizes.small
          font.weight: Font.Bold
          textFormat: Text.PlainText
        }
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.switchPanel("notifications")
      }
    }

    TrayStatus.Button {
      id: trayButton
      controller: root
    }

    BluetoothStatus.Button {
      id: bluetoothButton
      controller: root
    }

    NetworkStatus.Button {
      id: networkButton
      controller: root
    }

    BatteryStatus.Button {
      id: batteryButton
      controller: root
    }
  }

  PopupHost {
    id: popupHost
    window: root.window
    controller: root
    hostItem: buttons
    activeButton: root.activeButton
    popupVisible: root.activeMenu !== ""
    batteryButton: batteryButton
    trayButton: trayButton
    bluetoothButton: bluetoothButton
    networkButton: networkButton

    BatteryStatus.Menu {
      width: parent.width
      visible: root.activeMenu === "battery" || (popupHost.keepAlive && popupHost.lastActive === "battery")
    }

    TrayStatus.Menu {
      width: parent.width
      controller: root
      visible: root.activeMenu === "tray" || (popupHost.keepAlive && popupHost.lastActive === "tray")
    }

    BluetoothStatus.Menu {
      width: parent.width
      visible: root.activeMenu === "bluetooth" || (popupHost.keepAlive && popupHost.lastActive === "bluetooth")
    }

    NetworkStatus.Menu {
      width: parent.width
      visible: root.activeMenu === "network" || (popupHost.keepAlive && popupHost.lastActive === "network")
    }
  }

  SidebarHost {
    id: sidebarHost
    window: root.window
    open: root.activePanel !== ""
    title: root.activePanel === "notifications" ? "Notifications" : "Sidebar"
    onCloseRequested: root.closePanels()

    Notifications.NotificationPanel {
      visible: root.activePanel === "notifications"
    }
  }
}
