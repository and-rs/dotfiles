import QtQuick

Text {
  property int code: 0
  property string icon: ""
  property color iconColor: Config.colors.fg
  property int iconSize: 16

  anchors.horizontalCenter: parent.horizontalCenter
  anchors.verticalCenter: parent.verticalCenter

  font.family: "Phosphor-Bold"
  text: icon !== "" ? icon : String.fromCodePoint(code)
  font.pointSize: iconSize
  color: iconColor
}
