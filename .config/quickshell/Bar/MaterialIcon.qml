import QtQuick

Text {
  property int code: 0
  property string icon: ""
  property color iconColor: Config.colors.fg
  property int iconSize: 16
  property var yOffset: 0.6

  anchors.horizontalCenter: parent.horizontalCenter
  anchors.verticalCenter: parent.verticalCenter
  anchors.verticalCenterOffset: yOffset
  anchors.horizontalCenterOffset: -yOffset

  FontLoader {
    id: lucideFont
    source: "file:///home/and-rs/Downloads/Fonts/bold/Phosphor-Bold.ttf"
  }

  font.family: lucideFont.name
  text: icon !== "" ? icon : String.fromCodePoint(code)
  font.pointSize: iconSize
  color: iconColor
  font.variableAxes: {
    "wgth": 800
  }
}
