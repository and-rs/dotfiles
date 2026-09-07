import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Bar
import qs.Config

ClippingRectangle {
	id: root

	readonly property string activeImage: notificationImage || appIcon
	required property string appIcon
	required property string fallbackText
	readonly property bool hasNotificationImage: imageLooksLoadable(notificationImage)
	readonly property bool backgroundReady: backgroundImage.status === Image.Ready && backgroundImage.implicitWidth > 2 && backgroundImage.implicitHeight > 2
	readonly property bool imageReady: foregroundImage.status === Image.Ready && foregroundImage.implicitWidth > 2 && foregroundImage.implicitHeight > 2
	required property string notificationImage
	property int size: 56

	function imageLooksLoadable(value: string): bool {
		return value !== "" && (value.startsWith("file:") || value.startsWith("/") || value.startsWith("qrc:") || value.startsWith("http:") || value.startsWith("https:") || value.startsWith("data:") || value.startsWith("image://"));
	}

	border.width: 0
	color: Config.colors.surface1
	height: size
	radius: Config.radius.normal
	width: size

	Text {
		anchors.centerIn: parent
		color: Config.colors.surface5
		font.pixelSize: Config.sizes.extraLarge
		font.weight: Font.Bold
		text: root.fallbackText
		visible: !root.imageReady
	}
	Image {
		id: backgroundImage

		asynchronous: true
		cache: true
		fillMode: root.hasNotificationImage ? Image.PreserveAspectCrop : Image.PreserveAspectFit
		source: root.imageLooksLoadable(root.activeImage) ? root.activeImage : ""
		sourceSize.height: root.size * 2
		sourceSize.width: root.size * 2
		visible: false
	}
	MultiEffect {
		anchors.fill: parent
		autoPaddingEnabled: false
		blur: 1
		blurEnabled: root.hasNotificationImage
		blurMax: 8
		source: backgroundImage
		visible: root.backgroundReady && root.hasNotificationImage
	}
	Image {
		id: foregroundImage

		anchors.fill: parent
		asynchronous: true
		cache: true
		fillMode: root.hasNotificationImage ? Image.PreserveAspectFit : Image.PreserveAspectFit
		source: root.imageLooksLoadable(root.activeImage) ? root.activeImage : ""
		sourceSize.height: root.size * 2
		sourceSize.width: root.size * 2
		visible: root.imageReady
	}
	Rectangle {
		anchors.fill: parent
		color: Qt.alpha(Config.colors.bg, 0.12)
		visible: root.imageReady && root.hasNotificationImage
	}
}
