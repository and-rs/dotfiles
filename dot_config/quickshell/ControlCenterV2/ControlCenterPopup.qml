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

	readonly property var activeTab: tabDefinitions.find(tab => tab.id === selectedTab) || tabDefinitions[0]
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
		return activeTab.contentHeight;
	}
	readonly property int maximumContentHeight: {
		let height = 0;
		for (const tab of tabDefinitions)
			height = Math.max(height, tab.maximumContentHeight);
		return height;
	}
	readonly property Item networkContent: networkContentLoader.item
	required property bool open
	property var pendingAction: null
	property string selectedTab: "tray"

	// Each tab must reserve enough height for its largest content state.
	readonly property var tabDefinitions: [
		{
			id: "tray",
			label: "Tray",
			contentHeight: 400,
			maximumContentHeight: 400
		},
		{
			id: "bluetooth",
			label: "Bluetooth",
			contentHeight: 480,
			maximumContentHeight: 480
		},
		{
			id: "network",
			label: "Network",
			contentHeight: 480,
			maximumContentHeight: 480
		},
		{
			id: "battery",
			label: "Battery",
			contentHeight: 360,
			maximumContentHeight: 360
		}
	]
	readonly property Item trayContent: trayContentLoader.item
	required property PanelWindow window

	signal closeRequested

	function deferAction(action) {
		popup.pendingAction = action;
		popup.closeRequested();
		pendingActionTimer.restart();
	}

	anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
	anchor.edges: Edges.Top
	anchor.gravity: Edges.Bottom
	anchor.item: anchorButton
	color: "transparent"
	grabFocus: true
	implicitHeight: frame.y + frame.height
	implicitWidth: frame.width
	visible: open

	onVisibleChanged: {
		if (!visible)
			closeRequested();
	}

	Timer {
		id: pendingActionTimer

		interval: SC.Config.durations.instant
		repeat: false

		onTriggered: {
			if (!popup.pendingAction)
				return;
			const action = popup.pendingAction;
			action();
			popup.pendingAction = null;
		}
	}
	Item {
		id: frame

		height: tabs.implicitHeight + popup.maximumContentHeight + SC.Config.padding.large * 2 + SC.Config.spacing.small
		width: SC.Config.networkPanel.width
		x: 0
		y: popup.window.height + SC.Config.popup.gap

		MouseArea {
			anchors.fill: parent

			onClicked: popup.closeRequested()
		}
		MouseArea {
			height: popup.anchorButton.height
			width: popup.anchorButton.width
			x: (frame.width - width) / 2
			y: -frame.y

			onClicked: popup.closeRequested()
		}
		Rectangle {
			id: card

			anchors.left: parent.left
			anchors.right: parent.right
			border.color: SC.Config.colors.surface4
			border.width: SC.Config.popup.borderWidth
			color: SC.Config.colors.bg
			height: tabs.implicitHeight + contentViewport.height + SC.Config.padding.large * 2 + SC.Config.spacing.small
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

					height: popup.contentHeight
					width: parent.width

					Behavior on height {
						NumberAnimation {
							duration: SC.Config.durations.normal
							easing.type: SC.Config.curve
						}
					}

					Loader {
						id: trayContentLoader

						active: (popup.open && popup.selectedTab === "tray") || popup.pendingAction !== null
						anchors.fill: parent

						sourceComponent: Component {
							TrayContent.TrayContent {
								deferAction: action => popup.deferAction(action)
							}
						}
					}
					Loader {
						id: bluetoothContentLoader

						active: popup.open && popup.selectedTab === "bluetooth"
						anchors.fill: parent

						sourceComponent: Component {
							BluetoothContent.BluetoothContent {}
						}
					}
					Loader {
						id: networkContentLoader

						active: popup.open && popup.selectedTab === "network"
						anchors.fill: parent

						sourceComponent: Component {
							NetworkContent.NetworkContent {}
						}
					}
					Loader {
						id: batteryContentLoader

						active: popup.open && popup.selectedTab === "battery"
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
		required property var tab

		color: popup.selectedTab === tab.id ? SC.Config.colors.surface3 : SC.Config.colors.surface1
		height: label.implicitHeight + SC.Config.padding.small * 2
		radius: SC.Config.radius.small

		Text {
			id: label

			anchors.centerIn: parent
			color: SC.Config.colors.fg
			font.pointSize: 9
			font.weight: Font.DemiBold
			text: parent.tab.label
		}
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: popup.selectedTab = parent.tab.id
		}
	}
}
