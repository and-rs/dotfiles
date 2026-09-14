import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Bar
import qs.Config as SC

PanelWindow {
	id: root

	property bool bodyActive: false
	readonly property real closedPanelX: screen.width
	required property bool open
	readonly property real openPanelX: screen.width - panelWidth
	property Component panel
	property int panelWidth: SC.Config.sidebar.width
	property string title: ""
	required property PanelWindow window

	signal closeRequested

	function finalizePendingRemovals(): void {
		if (panelLoader.item && panelLoader.item.finalizePendingRemovals)
			panelLoader.item.finalizePendingRemovals();
	}

	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.layer: WlrLayer.Overlay
	color: "transparent"
	exclusiveZone: -1
	screen: window.screen
	visible: false

	Component.onCompleted: {
		if (open) {
			bodyActive = true;
			visible = true;
		}
	}
	onOpenChanged: {
		if (open) {
			bodyActive = true;
			visible = true;
		}
	}

	anchors {
		bottom: true
		left: true
		right: true
		top: true
	}
	margins {
		bottom: 0
		left: 0
		right: 0
		top: root.window.height
	}
	Item {
		anchors.fill: parent

		MouseArea {
			anchors.bottom: parent.bottom
			anchors.left: parent.left
			anchors.right: panelFrame.left
			anchors.top: parent.top

			onClicked: root.closeRequested()
		}
		Rectangle {
			id: panelFrame

			border.width: 0
			color: SC.Config.colors.bg
			height: parent.height
			opacity: root.open ? 1 : 0
			radius: 0
			width: root.panelWidth
			x: root.open ? root.openPanelX : root.closedPanelX
			y: 0

			Behavior on opacity {
				NumberAnimation {
					duration: SC.Config.durations.normal
					easing.type: SC.Config.curve
				}
			}
			Behavior on x {
				NumberAnimation {
					duration: SC.Config.durations.normal
					easing.type: SC.Config.curve

					onRunningChanged: {
						if (!running && !root.open)
							root.bodyActive = false;
						if (!running && !root.open)
							root.visible = false;
					}
				}
			}

			Rectangle {
				anchors.bottom: parent.bottom
				anchors.left: parent.left
				anchors.top: parent.top
				color: SC.Config.colors.primary
				width: 2
			}
			MouseArea {
				acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
				anchors.fill: parent
				propagateComposedEvents: true
				z: -1
			}
			Column {
				anchors.fill: parent
				anchors.margins: SC.Config.padding.large
				spacing: SC.Config.spacing.normal

				Row {
					spacing: SC.Config.spacing.small
					width: parent.width

					Text {
						color: SC.Config.colors.fg
						elide: Text.ElideRight
						font.pixelSize: SC.Config.sizes.large
						font.weight: Font.Medium
						text: root.title
						textFormat: Text.PlainText
						verticalAlignment: Text.AlignVCenter
						width: parent.width - parent.spacing
					}
				}
				Loader {
					id: panelLoader

					active: root.bodyActive
					asynchronous: true
					height: parent.height - y
					sourceComponent: root.panel
					width: parent.width
				}
			}
		}
	}
}
