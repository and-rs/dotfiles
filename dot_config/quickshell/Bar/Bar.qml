pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Bar
import qs.Bar.Recording
import qs.Config as SC
import qs.ControlCenterV2
import qs.NotificationV2

Scope {
	id: barScope

	required property var mainHeight

	Variants {
		model: Quickshell.screens

		PanelWindow {
			id: main

			required property var modelData

			aboveWindows: true
			color: "transparent"
			implicitHeight: barScope.mainHeight
			screen: modelData

			anchors {
				left: true
				right: true
				top: true
			}
			Item {
				id: barContent

				readonly property bool hidden: {
					let win = ToplevelManager.activeToplevel;
					if (!win || !win.fullscreen)
						return false;

					let screens = win.screens;
					if (!screens || screens.length === 0)
						return true;

					for (let screen of screens) {
						if (screen === main.screen)
							return true;
					}

					return false;
				}

				height: barScope.mainHeight
				opacity: hidden ? 0 : 1
				width: parent.width
				y: hidden ? -barScope.mainHeight - 6 : 0

				Behavior on opacity {
					NumberAnimation {
						duration: 180
						easing.type: SC.Config.curve
					}
				}
				Behavior on y {
					NumberAnimation {
						duration: 180
						easing.type: SC.Config.curve
					}
				}

				Rectangle {
					id: background

					anchors.fill: parent
					color: SC.Config.colors.bg

					Rectangle {
						id: bottomBorder

						anchors.bottom: parent.bottom
						anchors.left: parent.left
						anchors.right: parent.right
						color: SC.Config.colors.surface1
						height: 2
					}
				}
				Row {
					padding: SC.Config.padding.micro
					spacing: SC.Config.spacing.normal

					Workspaces {}
					WindowTitle {}
				}
				Row {
					id: rightRect

					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					rightPadding: SC.Config.padding.large
					spacing: SC.Config.spacing.normal

					Row {
						id: buttons

						anchors.verticalCenter: parent.verticalCenter
						spacing: SC.Config.spacing.small

						Recording {}
						Caffeine {
							id: caffeine

							window: main
						}
						LockButton {
							id: lockButton

							window: main
						}
						NotificationButton {
							window: main
						}
						Rectangle {
							anchors.verticalCenter: parent.verticalCenter
							color: SC.Config.colors.surface2
							height: SC.Config.sizes.small
							// separator
							width: 2
						}
						ControlCenterButton {
							window: main
						}
					}
					Item {
						id: timeSlot

						anchors.verticalCenter: parent.verticalCenter
						height: implicitHeight
						implicitHeight: timeText.implicitHeight
						implicitWidth: timeMetrics.width
						width: implicitWidth

						TextMetrics {
							id: timeMetrics

							// this is just a placeholder for width
							font: timeText.font
							text: "Wed 31 May 23:59"
						}
						Text {
							id: timeText

							anchors.centerIn: parent
							color: SC.Config.colors.fg
							font.pointSize: 10
							font.weight: 500
							text: Time.format("ddd d MMM hh:mm")
						}
					}
				}
			}
		}
	}
}
