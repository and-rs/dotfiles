import QtQuick
import qs.Config as SC

Item {
	id: root

	required property var swapContent
	property real cardOpacity: 1
	property real contentHeight: 0
	property real contentOpacity: 0
	property bool heightReady: false

	signal leaveFinished

	function hide() {
		contentFade.stop();
		contentHeightAnimation.stop();
		leaveFade.restart();
	}
	function show(height) {
		leaveFade.stop();
		contentFade.stop();
		contentHeightAnimation.stop();
		cardOpacity = 1;
		contentHeight = height;
		heightReady = height > 0;
		contentOpacity = height > 0 ? 1 : 0;
	}
	function switchContent() {
		contentFade.restart();
	}
	function updateContentHeight(height) {
		if (height <= 0)
			return;
		if (!heightReady) {
			heightReady = true;
			contentHeight = height;
			contentOpacity = 1;
			return;
		}
		if (contentHeight === height)
			return;
		contentHeightAnimation.to = height;
		contentHeightAnimation.restart();
	}

	SequentialAnimation {
		id: contentFade

		NumberAnimation {
			duration: SC.Config.durations.fast
			easing.type: SC.Config.curve
			property: "contentOpacity"
			target: root
			to: 0
		}
		ScriptAction {
			script: root.swapContent()
		}
		NumberAnimation {
			duration: SC.Config.durations.fast
			easing.type: SC.Config.curve
			property: "contentOpacity"
			target: root
			to: 1
		}
	}
	NumberAnimation {
		id: contentHeightAnimation

		duration: SC.Config.durations.fast
		easing.type: SC.Config.curve
		property: "contentHeight"
		target: root
	}
	NumberAnimation {
		id: leaveFade

		duration: SC.Config.durations.fast
		easing.type: SC.Config.curve
		property: "cardOpacity"
		target: root
		to: 0

		onFinished: root.leaveFinished()
	}
}
