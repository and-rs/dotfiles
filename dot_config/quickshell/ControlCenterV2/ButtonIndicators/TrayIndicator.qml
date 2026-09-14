import QtQuick
import Quickshell.Services.SystemTray
import qs.Bar
import qs.Config as SC

Item {
	id: root

	readonly property bool hasItems: (SystemTray.items.values ?? []).length > 0

	implicitHeight: SC.Config.sizes.normal
	implicitWidth: SC.Config.sizes.normal

	MaterialIcon {
		code: root.hasItems ? 0xE136 : 0xECE0
		iconColor: root.hasItems ? SC.Config.colors.fg : SC.Config.colors.surface4
		iconSize: SC.Config.sizes.normal
	}
}
