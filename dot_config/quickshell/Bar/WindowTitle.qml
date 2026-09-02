import QtQuick
import qs.Bar
import qs.Config

Row {
	id: root

	property var focusedWindow: NiriService.instance.focusedWindow

	anchors.verticalCenter: parent.verticalCenter
	spacing: Config.spacing.small

	Text {
		anchors.verticalCenter: parent.verticalCenter
		color: Config.colors.fg
		elide: Text.ElideRight
		font.pointSize: 10
		font.weight: 500
		maximumLineCount: 1
		text: root.focusedWindow ? root.focusedWindow.title : ""
		width: Math.min(implicitWidth, 250)
	}
	Text {
		anchors.verticalCenter: parent.verticalCenter
		color: Config.colors.surface5
		font.pointSize: 10
		font.weight: 500
		text: root.focusedWindow ? root.focusedWindow.appId : ""
	}
}
