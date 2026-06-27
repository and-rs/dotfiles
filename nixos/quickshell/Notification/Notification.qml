import Quickshell.Services.Notifications
import Quickshell.Wayland
import Quickshell
import QtQuick
import qs.Bar
import qs.Lock

Scope {
    id: notifScope
    required property var mainHeight
    property var displayedPopupEntry: null
    property string popupStage: "hidden"
    property real popupOffsetX: 0
    property real popupOffsetY: 0
    property real popupScale: 1
    property real popupOpacity: 0

    function setEnterState() {
        popupOffsetX = 72;
        popupOffsetY = -10;
        popupScale = 0.92;
        popupOpacity = 0;
    }

    function setShownState() {
        popupOffsetX = 0;
        popupOffsetY = 0;
        popupScale = 1;
        popupOpacity = 1;
    }

    function setExitState() {
        popupOffsetX = 24;
        popupOffsetY = -10;
        popupScale = 0.98;
        popupOpacity = 0;
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: false
        imageSupported: true

        onNotification: notification => NotificationStore.add(notification)
    }

    function syncPopupState() {
        enterAnimation.stop();
        exitAnimation.stop();
        if (NotificationStore.popupEntry) {
            displayedPopupEntry = NotificationStore.popupEntry;
            popupStage = "entering";
            setEnterState();
            enterAnimation.restart();
        } else if (displayedPopupEntry) {
            popupStage = "exiting";
            exitAnimation.restart();
        }
    }

    Component.onCompleted: syncPopupState()

    Connections {
        target: NotificationStore
        function onPopupEntryChanged() {
            notifScope.syncPopupState();
        }
    }

    SequentialAnimation {
        id: enterAnimation
        ParallelAnimation {
            NumberAnimation { target: notifScope; property: "popupOffsetX"; to: -6; duration: 160; easing.type: Config.curve }
            NumberAnimation { target: notifScope; property: "popupOffsetY"; to: 0; duration: 160; easing.type: Config.curve }
            NumberAnimation { target: notifScope; property: "popupScale"; to: 1.015; duration: 160; easing.type: Config.curve }
            NumberAnimation { target: notifScope; property: "popupOpacity"; to: 1; duration: 110; easing.type: Config.curve }
        }
        ParallelAnimation {
            NumberAnimation { target: notifScope; property: "popupOffsetX"; to: 0; duration: 90; easing.type: Config.curve }
            NumberAnimation { target: notifScope; property: "popupScale"; to: 1; duration: 90; easing.type: Config.curve }
        }
        onFinished: notifScope.popupStage = "shown"
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation { target: notifScope; property: "popupOffsetX"; to: 52; duration: 210; easing.type: Config.curve }
        NumberAnimation { target: notifScope; property: "popupOffsetY"; to: -12; duration: 210; easing.type: Config.curve }
        NumberAnimation { target: notifScope; property: "popupScale"; to: 0.90; duration: 210; easing.type: Config.curve }
        NumberAnimation { target: notifScope; property: "popupOpacity"; to: 0; duration: 180; easing.type: Config.curve }
        onFinished: {
            notifScope.displayedPopupEntry = null;
            notifScope.popupStage = "hidden";
        }
    }

    PanelWindow {
        id: popupWindow
        aboveWindows: true
        exclusiveZone: -1
        implicitWidth: Config.notifications.popupWidth
        implicitHeight: notifScope.displayedPopupEntry ? popupCard.implicitHeight : 0
        visible: notifScope.popupStage !== "hidden" && !LockService.locked
        color: "transparent"

        anchors.top: true
        anchors.right: true
        margins.top: notifScope.mainHeight + Config.spacing.small
        margins.right: Config.spacing.small

        Component.onCompleted: {
            if (WlrLayershell != null) {
                WlrLayershell.namespace = "quickshell-notification-popup";
                WlrLayershell.layer = WlrLayer.Overlay;
            }
        }

        Item {
            id: popupContent
            width: Config.notifications.popupWidth
            height: popupCard.implicitHeight
            x: notifScope.popupOffsetX
            y: notifScope.popupOffsetY
            scale: notifScope.popupScale
            opacity: notifScope.popupOpacity

            NotificationPopupCard {
                id: popupCard
                width: parent.width
                entry: notifScope.displayedPopupEntry
            }
        }
    }
}
