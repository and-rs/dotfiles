import QtQuick
import Quickshell.Bluetooth
import qs.Bar
import qs.Config as SC

Item {
	id: root

	readonly property var adapter: Bluetooth.defaultAdapter
	readonly property bool connected: {
		const devices = Bluetooth.devices.values ?? [];
		for (let i = 0; i < devices.length; i++) {
			if (devices[i] && devices[i].connected)
				return true;
		}
		return false;
	}
	readonly property bool enabled: adapter && adapter.enabled
	readonly property int iconCode: {
		if (!enabled)
			return 0xE0DE;
		if (connected)
			return 0xE0DC;
		return 0xE0DA;
	}
	readonly property color iconColor: {
		if (!enabled)
			return SC.Config.colors.surface4;
		if (connected)
			return SC.Config.colors.primary;
		return SC.Config.colors.fg;
	}

	implicitHeight: SC.Config.sizes.normal
	implicitWidth: SC.Config.sizes.normal

	MaterialIcon {
		code: root.iconCode
		iconColor: root.iconColor
		iconSize: SC.Config.sizes.normal
	}
}
