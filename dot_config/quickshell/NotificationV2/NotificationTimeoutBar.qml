import QtQuick
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	required property int durationMs
	required property int notificationId
	property bool running: visible

	signal expired(notificationId: int)

	function restart(): void {
		progressAnimation.stop();
		timeoutFill.width = root.width;
		if (!root.running || root.notificationId === -1 || root.durationMs <= 0)
			return;
		progressAnimation.from = root.width;
		progressAnimation.to = 0;
		progressAnimation.duration = Math.max(1, root.durationMs);
		progressAnimation.start();
	}

	clip: true
	color: SC.Config.colors.surface2
	height: visible ? 3 : 0
	radius: SC.Config.radius.small
	visible: durationMs > 0

	Component.onCompleted: restart()
	onDurationMsChanged: restart()
	onNotificationIdChanged: restart()
	onRunningChanged: restart()
	onWidthChanged: {
		if (!progressAnimation.running)
			timeoutFill.width = root.width;
	}

	Rectangle {
		id: timeoutFill

		height: parent.height
		radius: parent.radius
		width: parent.width

		gradient: Gradient {
			orientation: Gradient.Horizontal

			GradientStop {
				color: SC.Config.colors.primary
				position: 0.0
			}
			GradientStop {
				color: SC.Config.colors.primary
				position: 0.7
			}
			GradientStop {
				color: Qt.lighter(SC.Config.colors.primary, 1.2)
				position: 1.0
			}
		}
	}
	NumberAnimation {
		id: progressAnimation

		property: "width"
		target: timeoutFill

		onFinished: root.expired(root.notificationId)
	}
}
