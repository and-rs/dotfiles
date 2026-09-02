pragma ComponentBehavior: Bound
import QtQuick
import qs.Bar
import qs.Config

Row {
	id: mainRow

	// Incremented on windows model changes to trigger binding re-evaluation
	property int windowsRevision: 0

	function isWorkspaceEmpty(workspaceId: int): bool {
		for (let i = 0; i < NiriService.instance.windows.count; i++) {
			let item = NiriService.instance.windows.data(NiriService.instance.windows.index(i, 0), Qt.UserRole + 5);
			if (item === workspaceId) {
				return false;
			}
		}
		return true;
	}

	anchors.verticalCenter: parent.verticalCenter
	spacing: Config.spacing.extraSmall - 3

	Connections {
		function onDataChanged() {
			mainRow.windowsRevision++;
		}
		function onModelReset() {
			mainRow.windowsRevision++;
		}
		function onRowsInserted() {
			mainRow.windowsRevision++;
		}
		function onRowsRemoved() {
			mainRow.windowsRevision++;
		}

		target: NiriService.instance.windows
	}
	Repeater {
		id: repeater

		model: NiriService.instance.workspaces

		delegate: Rectangle {
			id: rect

			required property int id
			required property int index
			required property bool isFocused
			readonly property real collapsedWidth: Config.sizes.extraLarge
			readonly property bool empty: {
				mainRow.windowsRevision;
				return mainRow.isWorkspaceEmpty(rect.id);
			}
			readonly property real expandedWidth: Math.max(collapsedWidth, focusedContent.implicitWidth + Config.padding.extraSmall * 2)
			readonly property bool focused: rect.isFocused

			border.color: focused ? Qt.alpha(Config.colors.primary, 0.55) : empty ? Config.colors.surface1 : Config.colors.surface2
			border.width: focused ? 2 : 1
			color: focused ? Qt.alpha(Config.colors.primary, 0.12) : empty ? Config.colors.surface1 : Config.colors.surface2
			height: Config.sizes.extraLarge
			radius: Config.radius.small
			width: focused && !empty ? expandedWidth : collapsedWidth

			Behavior on width {
				NumberAnimation {
					duration: Config.durations.fast
					easing.type: Config.curve
				}
			}

			Row {
				id: focusedContent

				anchors.centerIn: parent
				spacing: Config.spacing.extraSmall - 1
				visible: rect.focused && !rect.empty

				Rectangle {
					color: "transparent"
					height: focusedContent.height
					width: 18

					Text {
						anchors.centerIn: parent
						anchors.verticalCenterOffset: 0.5
						color: Config.colors.primary
						font.pointSize: 10
						font.weight: 600
						text: rect.index
					}
				}
				WindowMiniMap {
					id: miniMap

					anchors.verticalCenter: parent.verticalCenter
				}
			}
			Text {
				id: textItem

				anchors.centerIn: parent
				anchors.verticalCenterOffset: 0.5
				color: rect.focused ? Config.colors.primary : rect.empty ? Config.colors.surface4 : Config.colors.fg
				font.pointSize: 10
				font.weight: rect.focused ? 600 : 500
				text: rect.index
				visible: !focusedContent.visible
			}
			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor

				onClicked: NiriService.instance.focusWorkspaceById(rect.id)
			}
		}
	}
}
