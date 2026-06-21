import Quickshell
import QtQuick

Row {
    spacing: Config.spacing.extraSmall - 3
    anchors.verticalCenter: parent.verticalCenter

    // Incremented on windows model changes to trigger binding re-evaluation
    property int windowsRevision: 0
    readonly property int revealDuration: Math.max(90, Math.floor(Config.durations.normal * 0.55))

    Connections {
        target: NiriService.instance.windows
        function onDataChanged() {
            windowsRevision++;
        }
        function onRowsInserted() {
            windowsRevision++;
        }
        function onRowsRemoved() {
            windowsRevision++;
        }
        function onModelReset() {
            windowsRevision++;
        }
    }

    function isWorkspaceEmpty(workspaceId: int): bool {
        for (let i = 0; i < NiriService.instance.windows.count; i++) {
            let item = NiriService.instance.windows.data(NiriService.instance.windows.index(i, 0), Qt.UserRole + 5);
            if (item === workspaceId) {
                return false;
            }
        }
        return true;
    }

    Repeater {
        id: repeater
        model: NiriService.instance.workspaces

        delegate: Rectangle {
            id: rect

            readonly property bool empty: {
                windowsRevision;
                return isWorkspaceEmpty(model.id);
            }
            readonly property bool focused: model.isFocused
            readonly property real collapsedWidth: Config.sizes.extraLarge
            readonly property real expandedWidth: Math.max(46, miniMap.implicitWidth + Config.padding.extraSmall * 2)
            readonly property real miniMapRevealProgress: {
                if (!focused || empty)
                    return 0;

                let span = expandedWidth - collapsedWidth;
                if (span <= 0)
                    return 1;

                return Math.max(0, Math.min(1, (width - collapsedWidth) / span));
            }
            readonly property bool showMiniMap: focused && !empty && miniMapRevealProgress > 0.35

            color: focused
                ? Qt.alpha(Config.colors.primary, Config.darkMode ? 0.16 : 0.12)
                : empty ? Config.colors.surface1 : Config.colors.surface2
            border.color: focused
                ? Qt.alpha(Config.colors.primary, Config.darkMode ? 0.7 : 0.55)
                : empty ? Config.colors.surface1 : Config.colors.surface2
            border.width: focused ? 2 : 1
            height: Config.sizes.extraLarge
            radius: Config.radius.small
            width: focused && !empty ? expandedWidth : collapsedWidth

            Behavior on width {
                NumberAnimation {
                    duration: revealDuration
                    easing.type: Config.curves.standard
                }
            }

            WindowMiniMap {
                id: miniMap
                anchors.centerIn: parent
                visible: rect.focused && !rect.empty
                opacity: rect.miniMapRevealProgress
                scale: 0.92 + rect.miniMapRevealProgress * 0.08

                Behavior on opacity {
                    NumberAnimation {
                        duration: revealDuration
                        easing.type: Config.curves.standard
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: revealDuration
                        easing.type: Config.curves.standard
                    }
                }
            }

            Text {
                id: textItem
                color: rect.focused ? Config.colors.primary : rect.empty ? Config.colors.surface4 : Config.colors.fg
                anchors.centerIn: parent
                visible: !rect.focused || rect.empty || rect.miniMapRevealProgress < 1
                opacity: rect.focused && !rect.empty ? 1 - rect.miniMapRevealProgress : 1
                text: model.index
                font.weight: rect.focused ? 650 : 500
                font.pointSize: 10

                Behavior on opacity {
                    NumberAnimation {
                        duration: revealDuration
                        easing.type: Config.curves.standard
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: NiriService.instance.focusWorkspaceById(model.id)
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}
