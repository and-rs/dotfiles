pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.UPower
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	readonly property bool active: PowerProfiles.profile === root.profile
	required property bool available
	required property int icon
	readonly property bool interactive: root.available
	required property string label
	required property var profile

	color: root.interactive && mouse.containsMouse ? SC.Config.colors.surface2 : SC.Config.colors.surface1
	height: 48
	opacity: root.available ? 1 : 0.4
	radius: SC.Config.radius.small
	width: parent ? parent.width : 0

	MaterialIcon {
		id: profileIcon

		anchors.left: parent.left
		anchors.leftMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		centered: false
		code: root.icon
		iconColor: root.active ? SC.Config.colors.primary : SC.Config.colors.fg
		iconSize: 18
	}
	Text {
		id: actionLabel

		anchors.right: parent.right
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		color: root.active ? SC.Config.colors.success : SC.Config.colors.surface5
		font.pointSize: 8
		font.weight: Font.Medium
		text: root.active ? "Active" : root.available ? "" : "Unavailable"
	}
	Item {
		id: labels

		anchors.left: profileIcon.right
		anchors.leftMargin: SC.Config.padding.small
		anchors.right: actionLabel.left
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: profileName.implicitHeight + subtitle.implicitHeight + 1

		Text {
			id: profileName

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			color: root.active ? SC.Config.colors.primary : SC.Config.colors.fg
			elide: Text.ElideRight
			font.pointSize: 9
			font.weight: root.active ? Font.DemiBold : Font.Normal
			text: root.label
		}
		Text {
			id: subtitle

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: profileName.bottom
			anchors.topMargin: 1
			color: SC.Config.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			text: root.active ? "Selected" : root.available ? "Set power mode" : "Not available"
		}
	}
	MouseArea {
		id: mouse

		anchors.fill: parent
		cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
		enabled: root.interactive
		hoverEnabled: root.interactive

		onClicked: {
			if (root.profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
				return;
			PowerProfiles.profile = root.profile;
		}
	}
}
