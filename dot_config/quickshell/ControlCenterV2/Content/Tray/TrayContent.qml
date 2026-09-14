pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.Bar
import qs.Config as SC
import IconValidation 1.0

Column {
	id: root

	readonly property var actionRows: {
		const rows = [];
		const selected = root.selectedItem;
		if (!selected)
			return rows;
		const raw = menuOpener.children ? menuOpener.children.values ?? [] : [];
		for (let i = 0; i < raw.length; i++) {
			const item = raw[i];
			if (!item || item.isSeparator)
				continue;
			const text = item.text ?? "";
			if (item.hasChildren) {
				rows.push({
					kind: "submenu",
					label: text !== "" ? text : "Menu",
					enabled: true,
					submenu: true,
					hasCheck: false,
					checked: false,
					radio: false,
					icon: item.icon ?? "",
					entry: item
				});
				continue;
			}
			if (text === "")
				continue;
			rows.push({
				kind: "entry",
				label: text,
				enabled: item.enabled,
				submenu: false,
				hasCheck: item.buttonType !== QsMenuButtonType.None,
				checked: item.checkState === Qt.Checked,
				radio: item.buttonType === QsMenuButtonType.RadioButton,
				icon: item.icon ?? "",
				entry: item
			});
		}
		rows.sort((a, b) => {
			if (a.enabled === b.enabled)
				return 0;
			return a.enabled ? -1 : 1;
		});
		return rows;
	}
	readonly property var currentMenu: {
		if (root.menuStack.length > 0)
			return root.menuStack[root.menuStack.length - 1].menu;
		return root.selectedItem && root.selectedItem.hasMenu ? root.selectedItem.menu : null;
	}
	readonly property int actionListHeight: {
		const count = root.actionRows.length;
		if (count === 0)
			return emptyLabel.implicitHeight;
		const height = count * 48 + Math.max(0, count - 1) * SC.Config.spacing.extraSmall;
		return Math.min(height, SC.Config.networkPanel.listHeight);
	}
	required property var deferAction
	readonly property string menuKey: {
		const titles = [];
		for (let i = 0; i < root.menuStack.length; i++)
			titles.push(root.menuStack[i].title);
		return root.selectedId + "\n" + titles.join("\n");
	}
	property var menuStack: []
	property string selectedId: ""
	readonly property var selectedItem: {
		const items = SystemTray.items.values ?? [];
		for (let i = 0; i < items.length; i++) {
			if (items[i] && items[i].id === root.selectedId)
				return items[i];
		}
		return items.length > 0 ? items[0] : null;
	}
	readonly property string selectedTitle: root.menuStack.length > 0 ? root.menuStack[root.menuStack.length - 1].title : root.selectedItem ? root.selectedItem.title || root.selectedItem.id || "Unknown" : ""
	readonly property string trayIds: {
		const items = SystemTray.items.values ?? [];
		const ids = [];
		for (let i = 0; i < items.length; i++) {
			if (items[i] && items[i].id)
				ids.push(items[i].id);
		}
		return ids.join("\n");
	}

	function ensureSelection() {
		const items = SystemTray.items.values ?? [];
		if (items.length === 0) {
			root.selectedId = "";
			root.menuStack = [];
			return;
		}
		for (let i = 0; i < items.length; i++) {
			if (items[i] && items[i].id === root.selectedId)
				return;
		}
		root.selectedId = items[0].id;
		root.menuStack = [];
	}
	function iconIsValid(icon, width, height) {
		return !iconValidator.canValidate(icon) || iconValidator.isValid(icon, width, height);
	}
	function popMenu() {
		if (root.menuStack.length === 0)
			return;
		root.menuStack = root.menuStack.slice(0, -1);
	}
	function pushMenu(entry) {
		root.menuStack = root.menuStack.concat([
			{
				menu: entry,
				title: entry.text || "Menu"
			}
		]);
	}
	function resolveIcon(icon) {
		if (!icon || !icon.includes("?path="))
			return icon ?? "";
		const [name, path] = icon.split("?path=");
		return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
	}
	function selectItem(item) {
		if (!item)
			return;
		root.selectedId = item.id;
		root.menuStack = [];
	}
	function triggerRow(row) {
		if (row.kind === "submenu" && row.entry) {
			root.pushMenu(row.entry);
			return;
		}
		if (row.kind === "entry" && row.entry && row.enabled) {
			const entry = row.entry;
			root.deferAction(() => entry.triggered());
		}
	}

	spacing: SC.Config.spacing.small
	width: parent ? parent.width : SC.Config.networkPanel.width - SC.Config.padding.large * 2

	Component.onCompleted: root.ensureSelection()
	onMenuKeyChanged: {
		if (!actionPane)
			return;
		actionPane.opacity = 0;
		menuFade.restart();
	}
	onTrayIdsChanged: root.ensureSelection()

	IconValidator {
		id: iconValidator
	}
	QsMenuOpener {
		id: menuOpener

		menu: root.currentMenu
	}
	NumberAnimation {
		id: menuFade

		duration: SC.Config.durations.fast
		easing.type: SC.Config.curve
		property: "opacity"
		target: actionPane
		to: 1
	}
	DirectScrollList {
		clip: true
		height: 40
		orientation: ListView.Horizontal
		model: SystemTray.items
		spacing: SC.Config.spacing.extraSmall
		visible: root.trayIds !== ""
		width: parent.width

		delegate: TrayIconButton {
			required property SystemTrayItem modelData

			iconSource: root.resolveIcon(modelData.icon)
			iconValid: root.iconIsValid(modelData.icon, 32, 32)
			selected: root.selectedItem === modelData || (root.selectedItem && root.selectedItem.id === modelData.id)

			onClicked: root.selectItem(modelData)
		}
	}
	Item {
		id: actionPane

		height: visible ? actionColumn.implicitHeight : 0
		visible: root.selectedItem !== null
		width: parent.width

		Column {
			id: actionColumn

			spacing: SC.Config.spacing.small
			width: parent.width

			Item {
				height: Math.max(backIcon.implicitHeight, paneTitle.implicitHeight)
				width: parent.width

				MaterialIcon {
					id: backIcon

					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					centered: false
					code: 0xE138
					iconColor: SC.Config.colors.primary
					iconSize: 16
					visible: root.menuStack.length > 0
				}
				MouseArea {
					anchors.fill: backIcon
					anchors.margins: -SC.Config.padding.small
					cursorShape: Qt.PointingHandCursor
					enabled: root.menuStack.length > 0
					visible: root.menuStack.length > 0

					onClicked: root.popMenu()
				}
				Text {
					id: paneTitle

					anchors.left: backIcon.visible ? backIcon.right : parent.left
					anchors.leftMargin: backIcon.visible ? SC.Config.spacing.extraSmall : 0
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					color: SC.Config.colors.fg
					elide: Text.ElideRight
					font.pointSize: 9
					font.weight: Font.DemiBold
					text: root.selectedTitle
				}
			}
			Item {
				height: root.actionListHeight
				width: parent.width

				DirectScrollList {
					anchors.fill: parent
					clip: true
					model: actionModel
					spacing: SC.Config.spacing.extraSmall
					visible: actionModel.values.length > 0
					width: parent.width

					delegate: TrayActionRow {
						required property var modelData

						checked: modelData.checked
						enabled: modelData.enabled
						hasCheck: modelData.hasCheck
						iconSource: root.resolveIcon(modelData.icon)
						iconValid: modelData.icon ? root.iconIsValid(modelData.icon, SC.Config.sizes.normal, SC.Config.sizes.normal) : true
						label: modelData.label
						radio: modelData.radio
						submenu: modelData.submenu
						width: ListView.view.width

						onClicked: root.triggerRow(modelData)
					}
				}
				Text {
					id: emptyLabel

					anchors.centerIn: parent
					color: SC.Config.colors.surface3
					font.pointSize: 9
					text: "No actions"
					visible: actionModel.values.length === 0
				}
			}
		}
	}
	Text {
		color: SC.Config.colors.surface3
		font.pointSize: 9
		text: "No tray items"
		visible: root.trayIds === ""
	}
	ScriptModel {
		id: actionModel

		values: root.actionRows
	}
}
