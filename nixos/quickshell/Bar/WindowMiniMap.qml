import QtQuick

Item {
    id: root

    readonly property var columns: NiriService.currentWorkspaceColumns
    readonly property var focusedWindow: NiriService.instance.focusedWindow
    property real focusFlash: 0

    readonly property int mapHeight: Config.sizes.small + 2
    readonly property int columnGap: 2
    readonly property int tileGap: 1
    readonly property int minColumnWidth: 8
    readonly property int tileRadius: Math.max(1, Config.radius.small - 2)
    readonly property real layoutHeight: {
        let maxHeight = 1;

        for (let column of columns)
            maxHeight = Math.max(maxHeight, sourceColumnHeight(column));

        return maxHeight;
    }

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: mapWidth()
    implicitHeight: mapHeight
    width: implicitWidth
    height: implicitHeight
    visible: columns.length > 0

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

    function scaleFactor() {
        return mapHeight / layoutHeight;
    }

    function columnWidth(column) {
        return Math.max(minColumnWidth, Math.round(sourceColumnWidth(column) * scaleFactor()));
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

    function isFocused(win) {
        return focusedWindow && win.id === focusedWindow.id;
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            let x = 0;
            for (let column of root.columns) {
                let columnW = root.columnWidth(column);
                let heights = root.tileHeights(column);
                let columnH = 0;

                for (let i = 0; i < heights.length; i++)
                    columnH += heights[i];
                columnH += root.tileGap * Math.max(0, heights.length - 1);

                let y = Math.round((root.mapHeight - columnH) / 2);
                for (let i = 0; i < column.length; i++) {
                    let win = column[i];
                    let focused = root.isFocused(win);
                    let tileH = heights[i];

                    let flashInset = focused ? root.focusFlash : 0;
                    ctx.globalAlpha = focused ? 1 : 0.9;
                    ctx.fillStyle = focused ? Config.colors.primary : Config.colors.surface3;
                    ctx.beginPath();
                    ctx.roundedRect(x - flashInset, y - flashInset, columnW + flashInset * 2, tileH + flashInset * 2, root.tileRadius, root.tileRadius);
                    ctx.fill();

                    if (!focused) {
                        ctx.globalAlpha = 0.18;
                        ctx.strokeStyle = Config.colors.base;
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }

                    if (focused && root.focusFlash > 0) {
                        ctx.globalAlpha = 0.22 * root.focusFlash;
                        ctx.strokeStyle = Config.colors.primary;
                        ctx.lineWidth = 1;
                        ctx.stroke();
                    }

                    y += tileH + root.tileGap;
                }

                x += columnW + root.columnGap;
            }

            ctx.globalAlpha = 1;
        }
    }

    NumberAnimation {
        id: focusFlashAnimation
        target: root
        property: "focusFlash"
        from: 1
        to: 0
        duration: 130
        easing.type: Easing.OutQuad
    }

    onColumnsChanged: canvas.requestPaint()
    onFocusFlashChanged: canvas.requestPaint()
    onFocusedWindowChanged: {
        focusFlashAnimation.restart();
        canvas.requestPaint();
    }
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}
