import QtQuick
import qs.Bar

Rectangle {
  id: root
  required property string image
  required property string fallbackText
  property int size: 48

  width: size
  height: size
  clip: true
  radius: Config.radius.small
  color: Config.colors.dim

  Text {
    anchors.centerIn: parent
    text: root.fallbackText
    font.pixelSize: Config.sizes.extraLarge
    font.weight: Font.Bold
    color: Config.colors.light
  }

  Image {
    anchors.fill: parent
    source: root.image
    visible: status === Image.Ready
  }
}
