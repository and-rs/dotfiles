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

    TrayStatus.Button {
      id: trayButton
      controller: root
    }

    Notifications.Button {
      id: notificationsButton
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
