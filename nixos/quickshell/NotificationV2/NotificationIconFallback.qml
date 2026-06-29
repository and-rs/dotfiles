import QtQuick
import QtQuick.Effects
import qs.Bar

Rectangle {
  id: root

  property bool expandToAspect: false
  required property string fallbackText
  required property string image
  readonly property real imageAspect: imageHasContent ? sourceImage.sourceSize.width / sourceImage.sourceSize.height : 1
  readonly property bool imageHasContent: sourceImage.sourceSize.width > 2 && sourceImage.sourceSize.height > 2
  readonly property bool imageLooksLoadable: image !== "" && (image.startsWith("file:") || image.startsWith("/") || image.startsWith("qrc:") || image.startsWith("http:") || image.startsWith("https:") || image.startsWith("data:") || image.startsWith("image://"))
  readonly property bool imageReady: imageLooksLoadable && sourceImage.status === Image.Ready && imageHasContent
  property int size: 48

  antialiasing: true
  border.color: Config.colors.surface2
  border.width: 1
  color: Config.colors.surface1
  height: size
  radius: Config.radius.normal
  width: expandToAspect && imageReady ? Math.max(size, Math.round(size * imageAspect)) : size

  Text {
    anchors.centerIn: parent
    color: Config.colors.surface5
    font.pixelSize: Config.sizes.extraLarge
    font.weight: Font.Bold
    text: root.fallbackText
    visible: !maskedImage.visible
  }
  Image {
    id: sourceImage

    anchors.fill: parent
    cache: true
    fillMode: Image.PreserveAspectFit
    layer.enabled: true
    mipmap: true
    smooth: true
    source: root.imageLooksLoadable ? root.image : ""
    visible: false
  }
  Rectangle {
    id: imageMask

    antialiasing: true
    color: "white"
    height: root.height
    layer.enabled: true
    radius: root.radius
    visible: false
    width: root.width
  }
  MultiEffect {
    id: maskedImage

    anchors.fill: parent
    maskEnabled: true
    maskSource: imageMask
    source: sourceImage
    visible: root.imageReady
  }
}
