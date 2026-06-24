import QtQuick
import QtQuick.Effects
import qs.Bar

Rectangle {
    id: root
    required property string image
    required property string fallbackText
    property int size: 48

    width: size
    height: size
    radius: Config.radius.normal
    color: Config.colors.surface1
    border.width: 1
    border.color: Config.colors.surface2
    antialiasing: true

    Text {
        anchors.centerIn: parent
        visible: !maskedImage.visible
        text: root.fallbackText
        font.pixelSize: Config.sizes.extraLarge
        font.weight: Font.Bold
        color: Config.colors.surface5
    }

    Image {
        id: sourceImage
        anchors.fill: parent
        visible: false
        source: root.image
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        cache: true
        layer.enabled: true
    }

    Rectangle {
        id: imageMask
        width: root.width
        height: root.height
        radius: root.radius
        color: "white"
        visible: false
        layer.enabled: true
        antialiasing: true
    }

    MultiEffect {
        id: maskedImage
        anchors.fill: parent
        visible: sourceImage.status === Image.Ready
        source: sourceImage
        maskEnabled: true
        maskSource: imageMask
    }
}
