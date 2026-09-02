pragma ComponentBehavior: Bound

import QtQuick
import qs.Bar
import qs.Config

Item {
	id: root

	readonly property int columnGap: 2
	readonly property var columns: NiriService.currentWorkspaceColumns
	readonly property var focusedWindow: NiriService.instance.focusedWindow
	readonly property real layoutHeight: {
		let maxHeight = 1;

		for (let column of columns)
			maxHeight = Math.max(maxHeight, sourceColumnHeight(column));

		return maxHeight;
	}
	readonly property int mapHeight: Config.sizes.small + 2
	readonly property int minColumnWidth: 8
	readonly property int tileGap: 1
	readonly property int tileRadius: Math.max(1, Config.radius.small - 2)

	function columnWidth(column) {
		return Math.max(minColumnWidth, Math.round(sourceColumnWidth(column) * scaleFactor()));
	}
	function columnX(index) {
		let x = 0;
		for (let i = 0; i < index; i++)
			x += columnWidth(columns[i]) + columnGap;
		return x;
	}
	function isFocused(win) {
		return focusedWindow && win.id === focusedWindow.id;
	}
	function mapWidth() {
		let total = 0;
		for (let i = 0; i < columns.length; i++) {
			total += columnWidth(columns[i]);
			if (i < columns.length - 1)
				total += columnGap;
		}
		return total;
	}
	function scaleFactor() {
		return mapHeight / layoutHeight;
	}
	function sourceColumnHeight(column) {
		let total = 0;
		for (let win of column)
			total += win.tile_size && win.tile_size.length > 1 ? win.tile_size[1] : 1;
		return Math.max(1, total);
	}
	function sourceColumnWidth(column) {
		let width = 1;
		for (let win of column)
			width = Math.max(width, win.tile_size && win.tile_size.length > 0 ? win.tile_size[0] : 1);
		return width;
	}
	function tileHeights(column) {
		let count = column.length;
		if (count === 0)
			return [];

		let available = Math.max(count, mapHeight - tileGap * Math.max(0, count - 1));
		let total = sourceColumnHeight(column);
		let heights = [];
		let fractions = [];
		let used = 0;

		for (let i = 0; i < count; i++) {
			let win = column[i];
			let sourceHeight = win.tile_size && win.tile_size.length > 1 ? win.tile_size[1] : 1;
			let raw = available * sourceHeight / total;
			let height = Math.max(1, Math.floor(raw));
			heights.push(height);
			fractions.push(raw - Math.floor(raw));
			used += height;
		}

		while (used < available) {
			let index = 0;
			for (let i = 1; i < fractions.length; i++) {
				if (fractions[i] > fractions[index])
					index = i;
			}
			heights[index]++;
			fractions[index] = 0;
			used++;
		}

		while (used > available) {
			let index = -1;
			for (let i = 0; i < heights.length; i++) {
				if (heights[i] > 1 && (index === -1 || fractions[i] < fractions[index]))
					index = i;
			}
			if (index === -1)
				break;
			heights[index]--;
			used--;
		}

		return heights;
	}
	function tileY(column, index) {
		let heights = tileHeights(column);
		let columnHeight = heights.reduce((total, height) => total + height, 0) + tileGap * Math.max(0, heights.length - 1);

		let y = Math.round((mapHeight - columnHeight) / 2);
		for (let i = 0; i < index; i++)
			y += heights[i] + tileGap;

		return y;
	}

	anchors.verticalCenter: parent.verticalCenter
	height: implicitHeight
	implicitHeight: mapHeight
	implicitWidth: mapWidth()
	visible: columns.length > 0
	width: implicitWidth

	Repeater {
		model: root.columns

		delegate: Item {
			id: columnDelegate

			required property int index
			required property var modelData

			height: root.mapHeight
			width: root.columnWidth(columnDelegate.modelData)
			x: root.columnX(columnDelegate.index)

			Repeater {
				model: columnDelegate.modelData

				delegate: Rectangle {
					required property int index
					required property var modelData

					color: root.isFocused(modelData) ? Config.colors.primary : Qt.alpha(Config.colors.primary, 0.3)
					height: root.tileHeights(columnDelegate.modelData)[index]
					radius: root.tileRadius
					width: columnDelegate.width
					x: 0
					y: root.tileY(columnDelegate.modelData, index)
				}
			}
		}
	}
}
