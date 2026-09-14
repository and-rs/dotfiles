import QtQuick
import qs.Bar
import qs.Config as SC

ListView {
	id: root

	readonly property bool horizontal: root.orientation === ListView.Horizontal
	readonly property bool scrollable: root.horizontal ? root.maximumContentX() > root.minimumContentX() + 1 : root.maximumContentY() > root.minimumContentY() + 1
	property real wheelScrollMultiplier: 10.0

	function clampContentX(value: real): real {
		return Math.max(root.minimumContentX(), Math.min(root.maximumContentX(), value));
	}
	function clampContentY(value: real): real {
		return Math.max(root.minimumContentY(), Math.min(root.maximumContentY(), value));
	}
	function maximumContentX(): real {
		return Math.max(root.minimumContentX(), root.originX + root.contentWidth - root.width + root.rightMargin);
	}
	function maximumContentY(): real {
		return Math.max(root.minimumContentY(), root.originY + root.contentHeight - root.height + root.bottomMargin);
	}
	function minimumContentX(): real {
		return root.originX - root.leftMargin;
	}
	function minimumContentY(): real {
		return root.originY - root.topMargin;
	}

	boundsBehavior: Flickable.StopAtBounds
	boundsMovement: Flickable.StopAtBounds
	interactive: false

	Rectangle {
		anchors.right: root.right
		anchors.rightMargin: SC.Config.padding.micro / 2
		color: SC.Config.colors.surface5
		height: Math.min(root.height, Math.max(SC.Config.padding.large * 2, root.height * root.height / (root.maximumContentY() - root.minimumContentY() + root.height)))
		opacity: 0.8
		parent: root
		radius: width / 2
		visible: root.scrollable && !root.horizontal
		width: SC.Config.padding.micro
		y: {
			const range = root.maximumContentY() - root.minimumContentY();
			if (range <= 0)
				return 0;
			const progress = Math.max(0, Math.min(1, (root.contentY - root.minimumContentY()) / range));
			return progress * (root.height - height);
		}
		z: 2
	}
	Rectangle {
		anchors.bottom: root.bottom
		anchors.bottomMargin: SC.Config.padding.micro / 2
		color: SC.Config.colors.surface5
		height: SC.Config.padding.micro
		opacity: 0.8
		parent: root
		radius: height / 2
		visible: root.scrollable && root.horizontal
		width: Math.min(root.width, Math.max(SC.Config.padding.large * 2, root.width * root.width / (root.maximumContentX() - root.minimumContentX() + root.width)))
		x: {
			const range = root.maximumContentX() - root.minimumContentX();
			if (range <= 0)
				return 0;
			const progress = Math.max(0, Math.min(1, (root.contentX - root.minimumContentX()) / range));
			return progress * (root.width - width);
		}
		z: 2
	}
	WheelHandler {
		acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
		blocking: true
		enabled: root.scrollable
		target: null

		onWheel: event => {
			if (root.horizontal) {
				const pixel = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.pixelDelta.y;
				const angle = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
				const delta = pixel !== 0 ? pixel * root.wheelScrollMultiplier : (angle / 120) * 24 * root.wheelScrollMultiplier;
				root.contentX = root.clampContentX(root.contentX - delta);
				return;
			}
			const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y * root.wheelScrollMultiplier : (event.angleDelta.y / 120) * 24 * root.wheelScrollMultiplier;
			root.contentY = root.clampContentY(root.contentY - delta);
		}
	}
}
