import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import IconValidation 1.0
import qs.Bar
import qs.Config as SC

ClippingRectangle {
	id: root

	readonly property string activeImage: {
		const source = root.notificationImage || root.appIcon;
		if (!root.imageLooksLoadable(source))
			return "";

		if (iconValidator.canValidate(source) && !iconValidator.isValid(source, root.imageSize, root.imageSize))
			return "";

		return source;
	}
	required property string appIcon
	readonly property bool backgroundReady: backgroundImage.status === Image.Ready && backgroundImage.implicitWidth > 2 && backgroundImage.implicitHeight > 2
	required property string fallbackText
	readonly property bool hasNotificationImage: imageLooksLoadable(notificationImage)
	readonly property bool imageReady: foregroundImage.status === Image.Ready && foregroundImage.implicitWidth > 2 && foregroundImage.implicitHeight > 2
	readonly property int imageSize: root.size * 2
	required property string notificationImage
	property int size: 56

	function imageLooksLoadable(value: string): bool {
		return value !== "" && (value.startsWith("file:") || value.startsWith("/") || value.startsWith("qrc:") || value.startsWith("http:") || value.startsWith("https:") || value.startsWith("data:") || value.startsWith("image://"));
	}

	border.width: 0
	color: SC.Config.colors.surface1
	height: size
	radius: SC.Config.radius.normal
	width: size

	IconValidator {
		id: iconValidator
	}

	Text {
		anchors.centerIn: parent
		color: SC.Config.colors.surface5
		font.pixelSize: SC.Config.sizes.extraLarge
		font.weight: Font.Bold
		text: root.fallbackText
		visible: !root.imageReady
	}

	Image {
		id: backgroundImage

		asynchronous: true
		cache: true
		fillMode: Image.PreserveAspectCrop
		source: {
			if (!root.hasNotificationImage)
				return "";

			return root.activeImage;
		}
		sourceSize.height: root.imageSize
		sourceSize.width: root.imageSize
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
		fillMode: Image.PreserveAspectFit
		source: root.activeImage
		sourceSize.height: root.imageSize
		sourceSize.width: root.imageSize
		visible: root.imageReady
	}

	Rectangle {
		anchors.fill: parent
		color: Qt.alpha(SC.Config.colors.bg, 0.12)
		visible: root.imageReady && root.hasNotificationImage
	}
}
