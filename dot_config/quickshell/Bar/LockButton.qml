import Quickshell
import QtQuick
import qs.Config

Rectangle {
	id: lockButton

	required property PanelWindow window

	anchors.verticalCenter: parent.verticalCenter
	color: "transparent"
	height: window.implicitHeight
	width: window.implicitHeight

	MaterialIcon {
		code: 0xE308
		iconColor: Config.colors.surface4
	}
	MouseArea {
		anchors.fill: parent

		onClicked: Quickshell.execDetached({
			command: ["sh", "-c", "~/.config/hypr/hyprlock-launch"]
		})
	}
}
