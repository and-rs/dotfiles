import QtQuick
import qs.Config as SC

Text {
	property bool centered: true
	property int code: 0
	property string icon: ""
	property color iconColor: SC.Config.colors.fg
	property int iconSize: 16

	anchors.horizontalCenter: centered ? parent.horizontalCenter : undefined
	anchors.verticalCenter: centered ? parent.verticalCenter : undefined
	color: iconColor
	font.family: "Phosphor-Fill"
	font.pointSize: iconSize
	text: icon !== "" ? icon : String.fromCodePoint(code)
}
