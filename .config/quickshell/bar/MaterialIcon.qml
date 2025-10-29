import QtQuick

Text {
  property string icon: ""
  property color iconColor: Config.colors.fg
  property int iconSize: 20
  property int verticalOffset: -5

  anchors.horizontalCenter: parent.horizontalCenter
  text: icon
  font.family: "Material Symbols Rounded"
  font.pointSize: iconSize
  color: iconColor
  y: verticalOffset
}
