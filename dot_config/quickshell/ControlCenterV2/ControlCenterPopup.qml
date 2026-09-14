import Quickshell
import QtQuick
import qs.Config as SC

PopupWindow {
	id: popup

	required property Item anchorButton
	required property bool open
	property string selectedTab: "Tray"
	required property PanelWindow window

	readonly property int contentHeight: {
		if (selectedTab === "Bluetooth")
			return 180;
		if (selectedTab === "Network")
			return 260;
		if (selectedTab === "Battery")
			return 150;
		return 120;
	}

	signal closeRequested

	component TabButton: Rectangle {
		required property string tab

		color: popup.selectedTab === tab ? SC.Config.colors.surface3 : SC.Config.colors.surface1
		height: label.implicitHeight + SC.Config.padding.small * 2
		radius: SC.Config.radius.small

		Text {
			id: label

			anchors.centerIn: parent
			color: SC.Config.colors.fg
			font.pointSize: 9
			font.weight: Font.DemiBold
			text: parent.tab
		}
		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor

			onClicked: popup.selectedTab = parent.tab
		}
	}

	anchor.item: anchorButton
	anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
	anchor.edges: Edges.Top | Edges.Right
	anchor.gravity: Edges.Bottom | Edges.Left
	color: "transparent"
	grabFocus: true
	implicitHeight: frame.y + frame.height
	implicitWidth: frame.width
	visible: open

	onVisibleChanged: {
		if (!visible)
			closeRequested();
	}

	Item {
		id: frame

		height: card.height
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

			Column {
				anchors.fill: parent
				anchors.margins: SC.Config.padding.large
				spacing: SC.Config.spacing.small

				Row {
					id: tabs

					width: parent.width
					spacing: SC.Config.spacing.extraSmall

					TabButton {
						tab: "Tray"
						width: (parent.width - parent.spacing * 3) / 4
					}
					TabButton {
						tab: "Bluetooth"
						width: (parent.width - parent.spacing * 3) / 4
					}
					TabButton {
						tab: "Network"
						width: (parent.width - parent.spacing * 3) / 4
					}
					TabButton {
						tab: "Battery"
						width: (parent.width - parent.spacing * 3) / 4
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
						text: popup.selectedTab + " placeholder"
					}
				}
			}
		}
	}
}
