import QtQuick
import qs.Config as SC

Text {
	id: root

	property bool centered: true
	property color iconColor: SC.Config.colors.primary
	property int iconSize: 16
	property bool running: visible

	anchors.horizontalCenter: centered ? parent.horizontalCenter : undefined
	anchors.verticalCenter: centered ? parent.verticalCenter : undefined
	color: iconColor
	font.family: "Phosphor-Bold"
	font.pixelSize: iconSize
	height: iconSize
	horizontalAlignment: Text.AlignHCenter
	rotation: 0
	text: String.fromCodePoint(0xE66A)
	verticalAlignment: Text.AlignVCenter
	width: iconSize

	RotationAnimation on rotation {
		duration: SC.Config.durations.extraSlow
		easing.type: Easing.Linear
		from: 0
		loops: Animation.Infinite
		running: root.visible && root.running
		to: 360
	}
}
