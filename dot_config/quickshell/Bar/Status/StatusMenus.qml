import QtQuick
import Quickshell
import qs.Bar
import qs.Debug as Debug
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
	readonly property var debugTargets: [
		{
			name: "network",
			item: networkMenu,
			items: [
				{
					name: "hero-title",
					item: networkMenu.debugHeroTitle
				},
				{
					name: "hero-status",
					item: networkMenu.debugHeroStatus
				},
				{
					name: "network-list",
					item: networkMenu.debugNetworkList
				}
			],
			open: function () {
				root.switchMenu("network");
			},
			close: function () {
				root.closeMenus();
			}
		}
	]
	required property PanelWindow window

	function closeAll() {
		closeMenus();
		closePanels();
	}
	function closeMenus() {
		if (activeMenu === "network")
			NetworkService.closePanel();
		activeMenu = "";
	}
	function closePanels() {
		sidebarHost.finalizePendingRemovals();
		activePanel = "";
	}
	function switchMenu(id) {
		closePanels();
		const nextMenu = activeMenu === id ? "" : id;
		if (activeMenu === "network" && nextMenu !== "network")
			NetworkService.closePanel();
		activeMenu = nextMenu;
		if (activeMenu === "network")
			NetworkService.openPanel();
	}
	function switchPanel(id) {
		closeMenus();
		if (activePanel === id) {
			closePanels();
			return;
		}
		activePanel = id;
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
			id: networkMenu

			visible: root.activeMenu === "network" || (popupHost.keepAlive && popupHost.lastActive === "network")
			width: parent.width
		}
	}
	Loader {
		active: Config.debug.enabled

		sourceComponent: Component {
			Debug.Capture {
				targets: root.debugTargets
			}
		}
	}
	SidebarHost {
		id: sidebarHost

		open: root.activePanel === "notifications"
		title: "Notifications"
		window: root.window

		panel: Component {
			NotificationsV2.NotificationSidebarActions {
				onClearAllRequested: {
					NotificationsV2.NotificationStore.clear();
					root.closePanels();
				}
				onCloseRequested: notificationId => NotificationsV2.NotificationStore.removeNotification(notificationId)
			}
		}

		onCloseRequested: root.closePanels()
	}
}
