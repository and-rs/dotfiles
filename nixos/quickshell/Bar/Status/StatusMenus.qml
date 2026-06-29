import QtQuick
import Quickshell
import qs.Bar
import qs.Lock
import qs.Sidebar
import qs.NotificationV2 as NotificationsV2
import qs.Bar.Status.Battery as BatteryStatus
import qs.Bar.Status.Bluetooth as BluetoothStatus
import qs.Bar.Status.Network as NetworkStatus
import qs.Bar.Status.Tray as TrayStatus

Item {
  id: root

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
  property string activeMenu: ""
  property string activePanel: ""
  readonly property real buttonHorizontalPadding: Config.spacing.small / 3
  readonly property bool menusBlocked: LockService.locked
  required property PanelWindow window

  function closeAll() {
    closeMenus();
    closePanels();
  }
  function closeMenus() {
    activeMenu = "";
  }
  function closePanels() {
    activePanel = "";
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

  implicitHeight: buttons.implicitHeight
  implicitWidth: buttons.implicitWidth

  Connections {
    function onLockedChanged() {
      if (LockService.locked)
        root.closeAll();
    }

    target: LockService
  }
  Row {
    id: buttons

    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    TrayStatus.Button {
      id: trayButton

      controller: root
    }
    NotificationsV2.NotificationButton {
      id: notificationsButton

      controller: root
      count: NotificationsV2.NotificationStore.count
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

    activeButton: root.activeButton
    batteryButton: batteryButton
    bluetoothButton: bluetoothButton
    controller: root
    hostItem: buttons
    networkButton: networkButton
    popupVisible: root.activeMenu !== ""
    trayButton: trayButton
    window: root.window

    BatteryStatus.Menu {
      visible: root.activeMenu === "battery" || (popupHost.keepAlive && popupHost.lastActive === "battery")
      width: parent.width
    }
    TrayStatus.Menu {
      controller: root
      visible: root.activeMenu === "tray" || (popupHost.keepAlive && popupHost.lastActive === "tray")
      width: parent.width
    }
    BluetoothStatus.Menu {
      visible: root.activeMenu === "bluetooth" || (popupHost.keepAlive && popupHost.lastActive === "bluetooth")
      width: parent.width
    }
    NetworkStatus.Menu {
      visible: root.activeMenu === "network" || (popupHost.keepAlive && popupHost.lastActive === "network")
      width: parent.width
    }
  }
  SidebarHost {
    id: sidebarHost

    open: root.activePanel === "notifications"
    title: "Notifications"
    window: root.window

    onCloseRequested: root.closePanels()

    NotificationsV2.NotificationSidebarActions {
      onClearAllRequested: NotificationsV2.NotificationStore.clear()
      onCloseRequested: notificationId => NotificationsV2.NotificationStore.removeNotification(notificationId)
    }
  }
}
