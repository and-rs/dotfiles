pragma ComponentBehavior: Bound

import QtQuick
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	property bool checked: false
	property bool enabled: true
	property bool hasCheck: false
	property string iconSource: ""
	property bool iconValid: true
	readonly property bool interactive: root.enabled
	required property string label
	property bool radio: false
	readonly property bool showIcon: root.iconSource !== ""
	property bool submenu: false

	signal clicked

	color: root.interactive && mouse.containsMouse ? SC.Config.colors.surface2 : SC.Config.colors.surface1
	height: 48
	opacity: root.enabled ? 1 : 0.4
	radius: SC.Config.radius.small
	width: parent ? parent.width : 0

	Rectangle {
		id: checkBox

		anchors.left: parent.left
		anchors.leftMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		border.color: SC.Config.colors.surface4
		border.width: 1
		color: root.checked ? SC.Config.colors.primary : "transparent"
		height: 12
		radius: root.radio ? height / 2 : 2
		visible: root.hasCheck
		width: 12
	}
	Item {
		id: entryIcon

		anchors.left: checkBox.visible ? checkBox.right : parent.left
		anchors.leftMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: 18
		visible: root.showIcon
		width: visible ? 18 : 0

		Image {
			id: iconImage

			anchors.fill: parent
			antialiasing: true
			asynchronous: true
			fillMode: Image.PreserveAspectFit
			smooth: true
			source: root.iconSource
			sourceSize.height: SC.Config.sizes.normal
			sourceSize.width: SC.Config.sizes.normal
			visible: status === Image.Ready && root.iconValid
		}
		MaterialIcon {
			anchors.centerIn: parent
			code: 0xE3E8
			iconColor: SC.Config.colors.surface4
			iconSize: SC.Config.sizes.small
			visible: iconImage.status !== Image.Ready || !root.iconValid
		}
	}
	MaterialIcon {
		id: chevron

		anchors.right: parent.right
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		centered: false
		code: 0xE13A
		iconColor: SC.Config.colors.surface5
		iconSize: 16
		visible: root.submenu
	}
	Text {
		id: actionLabel

		anchors.left: entryIcon.visible ? entryIcon.right : checkBox.visible ? checkBox.right : parent.left
		anchors.leftMargin: SC.Config.padding.small
		anchors.right: chevron.visible ? chevron.left : parent.right
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		color: root.enabled ? SC.Config.colors.fg : SC.Config.colors.surface3
		elide: Text.ElideRight
		font.pointSize: 9
		font.weight: Font.Normal
		text: root.label
	}
	MouseArea {
		id: mouse

		anchors.fill: parent
		cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
		enabled: root.interactive
		hoverEnabled: root.interactive

		onClicked: root.clicked()
	}
}
