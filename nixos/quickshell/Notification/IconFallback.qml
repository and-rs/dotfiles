import QtQuick
import QtQuick.Effects
import qs.Bar

Rectangle {
    id: root
    required property string image
    required property string fallbackText
    property int size: 48
    property bool expandToAspect: false
    readonly property bool imageLooksLoadable: image !== "" && (image.startsWith("file:") || image.startsWith("/") || image.startsWith("qrc:") || image.startsWith("http:") || image.startsWith("https:") || image.startsWith("data:") || image.startsWith("image://"))
    readonly property bool imageHasContent: sourceImage.sourceSize.width > 2 && sourceImage.sourceSize.height > 2
    readonly property bool imageReady: imageLooksLoadable && sourceImage.status === Image.Ready && imageHasContent
    readonly property real imageAspect: imageHasContent ? sourceImage.sourceSize.width / sourceImage.sourceSize.height : 1

    width: expandToAspect && imageReady ? Math.max(size, Math.round(size * imageAspect)) : size
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
        source: root.imageLooksLoadable ? root.image : ""
        fillMode: Image.PreserveAspectFit
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
        visible: root.imageReady
        source: sourceImage
        maskEnabled: true
        maskSource: imageMask
    }
}
