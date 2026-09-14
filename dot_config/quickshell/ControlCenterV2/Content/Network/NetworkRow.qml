import QtQuick
import qs.Bar
import qs.Config as SC

Rectangle {
	id: root

	readonly property bool busy: NetworkService.actionNetworkId === network.id && NetworkService.actionState !== "idle"
	readonly property bool canConnect: network.known && !network.connected
	readonly property bool interactive: !busy && NetworkService.actionState === "idle" && (network.connected || canConnect)
	required property var network

	color: root.interactive && mouse.containsMouse ? SC.Config.colors.surface2 : root.interactive ? SC.Config.colors.surface1 : SC.Config.colors.surface1
	height: 48
	radius: SC.Config.radius.small
	width: parent ? parent.width : 0

	Item {
		id: signalIcon

		anchors.left: parent.left
		anchors.leftMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: signalFill.implicitHeight
		width: signalFill.implicitWidth

		MaterialIcon {
			code: 0xE4EA
			iconColor: SC.Config.colors.surface4
			iconSize: 18
			opacity: 0.55
		}
		MaterialIcon {
			id: signalFill

			code: root.network.signalStrength > 0.75 ? 0xE4EA : root.network.signalStrength > 0.5 ? 0xE4EE : root.network.signalStrength > 0.25 ? 0xE4EC : 0xE4F0
			iconColor: SC.Config.colors.surface5
			iconSize: 18
		}
	}
	Text {
		id: actionLabel

		anchors.right: parent.right
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		color: root.network.connected ? SC.Config.colors.success : SC.Config.colors.primary
		font.pointSize: 8
		font.weight: Font.Medium
		text: root.busy ? "…" : root.network.connected ? "Connected" : root.canConnect ? "Connect" : ""
	}
	Item {
		id: labels

		anchors.left: signalIcon.right
		anchors.leftMargin: SC.Config.padding.small
		anchors.right: actionLabel.left
		anchors.rightMargin: SC.Config.padding.small
		anchors.verticalCenter: parent.verticalCenter
		height: networkName.implicitHeight + subtitle.implicitHeight + 1

		Text {
			id: networkName

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			color: root.network.connected ? SC.Config.colors.primary : SC.Config.colors.fg
			elide: Text.ElideRight
			font.pointSize: 9
			font.weight: root.network.connected ? Font.DemiBold : Font.Normal
			text: root.network.name
		}
		Text {
			id: subtitle

			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: networkName.bottom
			anchors.topMargin: 1
			color: SC.Config.colors.surface5
			elide: Text.ElideRight
			font.pointSize: 8
			text: root.busy ? NetworkService.actionState + "…" : root.network.connected ? "Connected" : root.network.security + (root.network.known ? " · saved" : "")
		}
	}
	MouseArea {
		id: mouse

		anchors.fill: parent
		cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
		enabled: root.interactive
		hoverEnabled: root.interactive

		onClicked: {
			if (root.network.connected)
				NetworkService.disconnect();
			else
				NetworkService.connect(root.network);
		}
	}
}
