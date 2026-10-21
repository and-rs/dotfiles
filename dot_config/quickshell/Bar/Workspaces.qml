pragma ComponentBehavior: Bound
import QtQuick
import qs.Bar
import qs.Config as SC

Row {
	id: mainRow

	anchors.verticalCenter: parent.verticalCenter
	spacing: SC.Config.spacing.extraSmall - 3

	Repeater {
		id: repeater

		model: NiriService.instance.workspaces

		delegate: Rectangle {
			id: rect

			required property int id
			required property int index
			required property bool isFocused
			required property bool isEmpty
			readonly property real collapsedWidth: SC.Config.sizes.extraLarge
			readonly property real expandedWidth: Math.max(collapsedWidth, focusedContent.implicitWidth + SC.Config.padding.extraSmall * 2)
			readonly property bool focused: rect.isFocused

			function borderColor(): color {
				if (rect.focused)
					return Qt.alpha(SC.Config.colors.primary, 0.55);

				if (rect.isEmpty)
					return SC.Config.colors.surface1;

				return SC.Config.colors.surface2;
			}

			function fillColor(): color {
				if (rect.focused)
					return Qt.alpha(SC.Config.colors.primary, 0.12);

				if (rect.isEmpty)
					return SC.Config.colors.surface1;

				return SC.Config.colors.surface2;
			}

			function textColor(): color {
				if (rect.focused)
					return SC.Config.colors.primary;

				if (rect.isEmpty)
					return SC.Config.colors.surface4;

				return SC.Config.colors.fg;
			}

			function currentWidth(): real {
				if (rect.focused && !rect.isEmpty)
					return rect.expandedWidth;

				return rect.collapsedWidth;
			}

			function labelWeight(): int {
				if (rect.focused)
					return 600;

				return 500;
			}

			function borderWidth(): int {
				if (rect.focused)
					return 2;

				return 1;
			}

			border.color: rect.borderColor()
			border.width: rect.borderWidth()
			color: rect.fillColor()
			height: SC.Config.sizes.extraLarge
			radius: SC.Config.radius.small
			width: rect.currentWidth()

			Behavior on width {
				NumberAnimation {
					duration: SC.Config.durations.fast
					easing.type: SC.Config.curve
				}
			}

			Row {
				id: focusedContent

				anchors.centerIn: parent
				spacing: SC.Config.spacing.extraSmall - 1
				visible: rect.focused && !rect.isEmpty

				Rectangle {
					color: "transparent"
					height: focusedContent.height
					width: 18

					Text {
						anchors.centerIn: parent
						anchors.verticalCenterOffset: 0.5
						color: SC.Config.colors.primary
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
				color: rect.textColor()
				font.pointSize: 10
				font.weight: rect.labelWeight()
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
