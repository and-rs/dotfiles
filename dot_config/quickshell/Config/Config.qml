pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
	id: root

	readonly property Colors colors: config.colors
	readonly property var curve: Easing.OutQuint
	readonly property Debug debug: config.debug
	readonly property Durations durations: config.durations
	readonly property NetworkPanel networkPanel: config.networkPanel
	readonly property Notifications notifications: config.notifications
	readonly property Padding padding: config.padding
	readonly property Popup popup: config.popup
	readonly property Radius radius: config.radius
	readonly property Sidebar sidebar: config.sidebar
	readonly property Sizes sizes: config.sizes
	readonly property Spacing spacing: config.spacing
	readonly property Transparency transparency: config.transparency

	FileView {
		id: configFile

		adapter: config
		blockLoading: true
		path: Qt.resolvedUrl("Config.json")
		printErrors: true
	}
	JsonAdapter {
		id: config

		property Colors colors: Colors {}
		property Debug debug: Debug {}
		property Durations durations: Durations {}
		property NetworkPanel networkPanel: NetworkPanel {}
		property Notifications notifications: Notifications {}
		property Padding padding: Padding {}
		property Popup popup: Popup {}
		property Radius radius: Radius {}
		property Sidebar sidebar: Sidebar {}
		property Sizes sizes: Sizes {}
		property Spacing spacing: Spacing {}
		property Transparency transparency: Transparency {}
	}

	component Colors: JsonObject {
		property string bg
		property string destructive
		property string fg
		property string primary
		property string secondary
		property string success
		property string surface1
		property string surface2
		property string surface3
		property string surface4
		property string surface5
	}
	component Debug: JsonObject {
		property bool enabled
	}
	component Durations: JsonObject {
		property int extraFast
		property int extraSlow
		property int fast
		property int instant
		property int normal
		property int slow
	}
	component NetworkPanel: JsonObject {
		property int listHeight
		property int width
	}
	component Notifications: JsonObject {
		property int historyLimit
		property int popupDuration
		property int popupWidth
	}
	component Padding: JsonObject {
		property int extraLarge
		property int extraSmall
		property int large
		property int micro
		property int normal
		property int small
	}
	component Popup: JsonObject {
		property int borderWidth
		property bool debug
		property int gap
		property int width
	}
	component Radius: JsonObject {
		property int full
		property int large
		property int normal
		property int small
	}
	component Sidebar: JsonObject {
		property int borderWidth
		property int gap
		property int maxHeight
		property int rightMargin
		property int width
	}
	component Sizes: JsonObject {
		property int extraLarge
		property int extraSmall
		property int large
		property int normal
		property int small
	}
	component Spacing: JsonObject {
		property int extraLarge
		property int extraSmall
		property int large
		property int normal
		property int small
	}
	component Transparency: JsonObject {
		property real base
		property bool enabled
		property real layers
	}
}
