pragma ComponentBehavior: Bound

import QtQuick
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	required property string iconSource
	required property bool iconValid
	required property bool selected

	signal clicked
	signal doubleClicked

	border.color: root.selected ? SC.Config.colors.primary : "transparent"
	border.width: 2
	color: mouse.containsMouse ? SC.Config.colors.surface3 : SC.Config.colors.surface3
	height: 40
	radius: SC.Config.radius.small
	width: 40

	Image {
		id: trayIcon

		anchors.centerIn: parent
		antialiasing: true
		asynchronous: true
		fillMode: Image.PreserveAspectFit
		height: 24
		smooth: true
		source: root.iconSource
		sourceSize.height: 32
		sourceSize.width: 32
		visible: status === Image.Ready && root.iconValid
		width: 24
	}
	MaterialIcon {
		anchors.centerIn: parent
		code: 0xE3E8
		iconColor: SC.Config.colors.surface5
		iconSize: SC.Config.sizes.large
		visible: trayIcon.status !== Image.Ready || !root.iconValid
	}
	MouseArea {
		id: mouse

		anchors.fill: parent
		cursorShape: Qt.PointingHandCursor
		hoverEnabled: true

		onClicked: root.clicked()
		onDoubleClicked: root.doubleClicked()
	}
}
