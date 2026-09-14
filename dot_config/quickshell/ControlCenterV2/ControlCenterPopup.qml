pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.Config as SC
import qs.ControlCenterV2.Content.Network as NetworkContent

PopupWindow {
	id: popup

	required property Item anchorButton
	readonly property Item networkContent: networkContentLoader.item
	required property bool open
	property string selectedTab: "tray"
	required property PanelWindow window

	// Each tab must reserve enough height for its largest content state.
	readonly property var tabDefinitions: [
		{
			id: "tray",
			label: "Tray",
			contentHeight: 120,
			maximumContentHeight: 120
		},
		{
			id: "bluetooth",
			label: "Bluetooth",
			contentHeight: 180,
			maximumContentHeight: 180
		},
		{
			id: "network",
			label: "Network",
			contentHeight: 400,
			maximumContentHeight: 400
		},
		{
			id: "battery",
			label: "Battery",
			contentHeight: 150,
			maximumContentHeight: 150
		}
	]
	readonly property var activeTab: tabDefinitions.find(tab => tab.id === selectedTab) || tabDefinitions[0]
	readonly property int contentHeight: activeTab.id === "network" && networkContentLoader.item ? networkContentLoader.item.implicitHeight : activeTab.contentHeight
	readonly property int maximumContentHeight: {
		let height = 0;
		for (const tab of tabDefinitions)
			height = Math.max(height, tab.maximumContentHeight);
		return height;
	}

	signal closeRequested

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

	anchor.item: anchorButton
	anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
	anchor.edges: Edges.Top | Edges.Right
	anchor.gravity: Edges.Bottom | Edges.Left

	visible: open
	grabFocus: true
	color: "transparent"
	implicitWidth: frame.width
	implicitHeight: frame.y + frame.height

	onVisibleChanged: {
		if (!visible)
			closeRequested();
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
			x: frame.width - width
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

					width: parent.width
					spacing: SC.Config.spacing.extraSmall

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

					Text {
						anchors.centerIn: parent
						color: SC.Config.colors.fg
						font.pointSize: 11
						font.weight: Font.DemiBold
						text: popup.activeTab.label + " placeholder"
						visible: popup.selectedTab !== "network"
					}
					Loader {
						id: networkContentLoader

						active: popup.open && popup.selectedTab === "network"
						anchors.fill: parent
						sourceComponent: Component {
							NetworkContent.NetworkContent {}
						}
					}
				}
			}
		}
	}
}
