import QtQuick

Text {
  property int code: 0
  property string icon: ""
  property color iconColor: Config.colors.fg
  property int iconSize: 20
  property int verticalOffset: -5

  anchors.horizontalCenter: parent.horizontalCenter
  text: icon !== "" ? icon : String.fromCodePoint(code)
  font.family: "Material Symbols Rounded"
  font.pointSize: iconSize
  color: iconColor
  y: verticalOffset
}
