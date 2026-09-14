pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Config as SC
import qs.Bar.Status.Battery as BatteryStatus
import qs.Bar.Status.Bluetooth as BluetoothStatus
import qs.Bar.Status.Tray as TrayStatus

Item {
	id: root

	readonly property Item activeButton: {
		if (activeMenu === "battery")
			return batteryButton;
		if (activeMenu === "bluetooth")
			return bluetoothButton;
		if (activeMenu === "tray")
			return trayButton;
		return batteryButton;
	}
	property string activeMenu: ""
	readonly property real buttonHorizontalPadding: SC.Config.spacing.small / 3
	required property PanelWindow window

	function closeMenus() {
		activeMenu = "";
	}
	function switchMenu(id) {
		activeMenu = activeMenu === id ? "" : id;
	}

	implicitHeight: buttons.implicitHeight
	implicitWidth: buttons.implicitWidth

	Row {
		id: buttons

		anchors.verticalCenter: parent.verticalCenter
		spacing: 0

		TrayStatus.Button {
			id: trayButton

			controller: root
		}
		BluetoothStatus.Button {
			id: bluetoothButton

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
	}
}
