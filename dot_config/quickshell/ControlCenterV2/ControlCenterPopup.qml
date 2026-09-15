pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Config as SC
import qs.ControlCenterV2.Content.Battery as BatteryContent
import qs.ControlCenterV2.Content.Bluetooth as BluetoothContent
import qs.ControlCenterV2.Content.Network as NetworkContent
import qs.ControlCenterV2.Content.Tray as TrayContent

PopupWindow {
	id: popup

	readonly property var activeTab: tabDefinitions.find(tab => tab.id === contentTab) || tabDefinitions[0]
	required property Item anchorButton
	readonly property Item batteryContent: batteryContentLoader.item
	readonly property Item bluetoothContent: bluetoothContentLoader.item

	readonly property int contentHeight: {
		if (activeTab.id === "network" && networkContentLoader.item)
			return networkContentLoader.item.implicitHeight;
		if (activeTab.id === "bluetooth" && bluetoothContentLoader.item)
			return bluetoothContentLoader.item.implicitHeight;
		if (activeTab.id === "battery" && batteryContentLoader.item)
			return batteryContentLoader.item.implicitHeight;
		if (activeTab.id === "tray" && trayContentLoader.item)
			return trayContentLoader.item.implicitHeight;
		return 0;
	}
	property string contentTab: "tray"
	property bool closeNotified: false
	property bool leaving: false
	readonly property Item networkContent: networkContentLoader.item
	required property bool open
	property var pendingAction: null
	property string selectedTab: "tray"
	readonly property var tabDefinitions: [
		{
			id: "tray",
			label: "Tray"
		},
		{
			id: "bluetooth",
			label: "Bluetooth"
		},
		{
			id: "network",
			label: "Network"
		},
		{
			id: "battery",
			label: "Battery"
		}
	]
	readonly property Item trayContent: trayContentLoader.item
	required property PanelWindow window

	signal closeRequested

	function deferAction(action) {
		popup.pendingAction = action;
		popup.dismiss();
	}
	function dismiss() {
		if (popup.leaving)
			return;
		popup.closeNotified = false;
		popup.leaving = true;
		animations.hide();
	}
	function selectTab(id) {
		if (id === selectedTab)
			return;
		selectedTab = id;
		animations.switchContent();
	}

	anchor.adjustment: PopupAdjustment.None
	anchor.edges: Edges.Top
	anchor.gravity: Edges.Bottom
	anchor.item: anchorButton
	color: "transparent"
	grabFocus: true
	implicitHeight: frame.y + frame.height
	implicitWidth: frame.width
	visible: open || leaving

	onContentHeightChanged: {
		if (!open)
			return;
		animations.updateContentHeight(contentHeight);
	}
	onOpenChanged: {
		if (open) {
			closeNotified = false;
			contentTab = selectedTab;
			leaving = false;
			animations.show(contentHeight);
		} else if (!leaving && visible) {
			dismiss();
		}
	}
	onVisibleChanged: {
		if (!visible && !closeNotified) {
			closeNotified = true;
			closeRequested();
		}
	}

	ControlCenterAnimations {
		id: animations

		swapContent: () => popup.contentTab = popup.selectedTab

		onLeaveFinished: {
			const action = popup.pendingAction;
			popup.pendingAction = null;
			popup.closeNotified = true;
			popup.closeRequested();
			popup.leaving = false;
			if (action)
				action();
		}
	}
	Item {
		id: frame

		height: (popup.window.screen ? popup.window.screen.height : 0) - popup.window.height - SC.Config.popup.gap
		width: SC.Config.networkPanel.width
		x: 0
		y: popup.window.height + SC.Config.popup.gap

		MouseArea {
			anchors.fill: parent

			onClicked: popup.dismiss()
		}
		MouseArea {
			height: popup.anchorButton.height
			width: popup.anchorButton.width
			x: (frame.width - width) / 2
			y: -frame.y

			onClicked: popup.dismiss()
		}
		Rectangle {
			id: card

			anchors.left: parent.left
			anchors.right: parent.right
			border.color: SC.Config.colors.surface4
			border.width: SC.Config.popup.borderWidth
			color: SC.Config.colors.bg
			height: tabs.implicitHeight + contentViewport.height + SC.Config.padding.large * 2 + SC.Config.spacing.small
			opacity: animations.cardOpacity
			radius: SC.Config.radius.normal

			MouseArea {
				anchors.fill: parent
			}
			Column {
				anchors.fill: parent
				anchors.margins: SC.Config.padding.large
				spacing: SC.Config.spacing.small

				Row {
					id: tabs

					spacing: SC.Config.spacing.extraSmall
					width: parent.width
					Repeater {
						model: popup.tabDefinitions

						delegate: TabButton {
							required property var modelData
							tab: modelData
							width: (tabs.width - tabs.spacing * 3) / 4
						}
					}
				}
				Item {
					id: contentViewport

					height: animations.contentHeight
					opacity: animations.contentOpacity
					width: parent.width

					Loader {
						id: trayContentLoader

						active: (popup.open || popup.leaving) && popup.contentTab === "tray"
						anchors.fill: parent
						sourceComponent: Component {
							TrayContent.TrayContent {
								deferAction: action => popup.deferAction(action)
							}
						}
					}
					Loader {
						id: bluetoothContentLoader

						active: (popup.open || popup.leaving) && popup.contentTab === "bluetooth"
						anchors.fill: parent
						sourceComponent: Component {
							BluetoothContent.BluetoothContent {}
						}
					}
					Loader {
						id: networkContentLoader

						active: (popup.open || popup.leaving) && popup.contentTab === "network"
						anchors.fill: parent
						sourceComponent: Component {
							NetworkContent.NetworkContent {}
						}
					}
					Loader {
						id: batteryContentLoader

						active: (popup.open || popup.leaving) && popup.contentTab === "battery"
						anchors.fill: parent
						sourceComponent: Component {
							BatteryContent.BatteryContent {}
						}
					}
				}
			}
		}
	}

	component TabButton: Rectangle {
		id: tabButton
		required property var tab

		color: popup.selectedTab === tab.id ? SC.Config.colors.surface5 : SC.Config.colors.surface1
		height: label.implicitHeight + SC.Config.padding.small * 2
		radius: SC.Config.radius.small

		Text {
			id: label

			anchors.centerIn: parent
			color: popup.selectedTab === tabButton.tab.id ? SC.Config.colors.bg : SC.Config.colors.fg
			font.pointSize: 9
			font.weight: Font.DemiBold
			text: parent.tab.label
		}
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: popup.selectTab(parent.tab.id)
		}
	}
}
