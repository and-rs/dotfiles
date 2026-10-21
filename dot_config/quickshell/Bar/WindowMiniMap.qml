pragma ComponentBehavior: Bound

import QtQuick
import qs.Bar
import qs.Config as SC

Item {
	id: root

	readonly property var columns: NiriService.instance.miniMapColumns

	function tileColor(focused: bool): color {
		if (focused)
			return SC.Config.colors.primary;

		return Qt.alpha(SC.Config.colors.primary, 0.3);
	}

	anchors.verticalCenter: parent.verticalCenter
	height: NiriService.instance.miniMapHeight
	implicitHeight: NiriService.instance.miniMapHeight
	implicitWidth: NiriService.instance.miniMapWidth
	visible: columns.length > 0
	width: implicitWidth

	Repeater {
		model: root.columns

		delegate: Item {
			id: columnDelegate

			required property var modelData

			height: root.height
			width: columnDelegate.modelData.width
			x: columnDelegate.modelData.x

			Repeater {
				model: columnDelegate.modelData.tiles

				delegate: Rectangle {
					required property var modelData

					color: root.tileColor(modelData.focused)
					height: modelData.height
					radius: SC.Config.radius.tiny
					width: columnDelegate.width
					y: modelData.y
				}
			}
		}
	}
}
