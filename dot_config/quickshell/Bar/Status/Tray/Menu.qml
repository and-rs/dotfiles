import QtQuick
import qs.Bar
import qs.Config
import qs.Bar.Status as Status

Column {
	id: root

	required property Status.StatusMenus controller

	spacing: Config.spacing.small
	width: parent ? parent.width : Config.popup.width

	onVisibleChanged: {
		if (!visible)
			itemList.expandedIndex = -1;
	}

	Text {
		color: Config.colors.fg
		font.pointSize: 10
		font.weight: 600
		text: "System Tray"
	}
	Rectangle {
		color: Config.colors.surface2
		height: 1
		width: parent.width
	}
	ItemList {
		id: itemList

		controller: root.controller
		width: parent.width
	}
}
