import QtQuick
import Quickshell.Networking
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	required property SC.Config.Colors colors
	readonly property color actionColor: {
		if (root.network.connected)
			return root.colors.success;

		return root.colors.primary;
	}
	readonly property color nameColor: {
		if (root.network.connected)
			return root.colors.primary;

		return root.colors.fg;
	}

	readonly property bool busy: root.network.stateChanging
	readonly property bool canConnect: root.network.known && !root.network.connected
	readonly property bool interactive: NetworkService.canAct(root.network) && (root.network.connected || root.canConnect)
	required property WifiNetwork network
	required property int rowHeight

	color: {
		if (root.interactive && mouse.containsMouse)
			return root.colors.surface2;

		return root.colors.surface1;
	}
	height: root.rowHeight
	radius: SC.Config.radius.small
	width: {
		if (parent)
			return parent.width;

		return 0;
	}

	Item {
		id: signalIcon

		anchors.left: parent.left
		anchors.leftMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: signalFill.implicitHeight
		width: signalFill.implicitWidth

		MaterialIcon {
			code: 0xE4EA
			iconColor: root.colors.surface4
			iconSize: 18
			opacity: 0.55
		}

		MaterialIcon {
			id: signalFill

			code: {
				if (root.network.signalStrength > 0.75)
					return 0xE4EA;

				if (root.network.signalStrength > 0.5)
					return 0xE4EE;

				if (root.network.signalStrength > 0.25)
					return 0xE4EC;

				return 0xE4F0;
			}
			iconColor: root.colors.surface5
			iconSize: 18
		}
	}

	Row {
		id: actionFeedback

		anchors.right: parent.right
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: Math.max(actionLabel.implicitHeight, actionLoader.iconSize)
		spacing: SC.Config.spacing.extraSmall

		LoaderIcon {
			id: actionLoader

			anchors.verticalCenter: parent.verticalCenter
			centered: false
			iconColor: root.actionColor
			visible: root.busy
		}

		Text {
			id: actionLabel

			anchors.verticalCenter: parent.verticalCenter
			color: root.actionColor
			font.pointSize: 8
			font.weight: Font.Medium
			text: {
				if (root.busy)
					return ConnectionState.toString(root.network.state) + "…";

				if (root.network.connected)
					return "Connected";

				if (root.canConnect)
					return "Connect";

				return "";
			}
		}
	}

	Item {
		id: labels

		anchors.left: signalIcon.right
		anchors.leftMargin: SC.Config.padding.small
		anchors.right: actionFeedback.left
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: networkName.implicitHeight + subtitle.implicitHeight + 1

		Text {
			id: networkName

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			color: root.nameColor
			elide: Text.ElideRight
			font.pointSize: 9
			font.weight: {
				if (root.network.connected)
					return Font.DemiBold;

				return Font.Normal;
			}
			text: root.network.name
		}

		Text {
			id: subtitle

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: networkName.bottom
			anchors.topMargin: 1
			color: root.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			text: {
				if (root.network.connected)
					return "Connected";

				let text = WifiSecurityType.toString(root.network.security);
				if (root.network.known)
					text += " · saved";

				return text;
			}
		}
	}

	MouseArea {
		id: mouse

		anchors.fill: parent
		cursorShape: {
			if (root.interactive)
				return Qt.PointingHandCursor;

			return Qt.ArrowCursor;
		}
		enabled: root.interactive
		hoverEnabled: root.interactive

		onClicked: {
			if (root.network.connected)
				NetworkService.disconnect(root.network);
			else
				NetworkService.connect(root.network);
		}
	}
}
