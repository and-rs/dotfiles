import QtQuick
import Quickshell
import qs.Bar
import qs.Lock
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

    function switchMenu(id) {
        if (menusBlocked) {
            closeMenus();
            return;
        }
        activeMenu = activeMenu === id ? "" : id;
    }

    Connections {
        target: LockService

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
