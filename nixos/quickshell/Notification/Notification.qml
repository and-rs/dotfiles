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
        popupOffsetX = 56;
        popupOffsetY = -16;
        popupScale = 0.94;
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
        if (NotificationStore.popupEntry) {
            displayedPopupEntry = NotificationStore.popupEntry;
            popupStage = "entering";
            clearDisplayedPopupTimer.stop();
            setEnterState();
            enterPopupTimer.restart();
        } else if (displayedPopupEntry) {
            popupStage = "exiting";
            setExitState();
            clearDisplayedPopupTimer.restart();
        }
    }

    Connections {
        target: NotificationStore
        function onPopupEntryChanged() {
            notifScope.syncPopupState();
        }
    }

    Timer {
        id: clearDisplayedPopupTimer
        interval: Config.durations.normal
        repeat: false
        onTriggered: {
            notifScope.displayedPopupEntry = null;
            notifScope.popupStage = "hidden";
        }
    }

    Timer {
        id: enterPopupTimer
        interval: 16
        repeat: false
        onTriggered: {
            notifScope.popupStage = "shown";
            notifScope.setShownState();
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

            Behavior on x {
                NumberAnimation {
                    duration: Config.durations.normal
                    easing.type: Config.curves.smooth
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: Config.durations.normal
                    easing.type: Config.curves.smooth
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Config.durations.normal
                    easing.type: Config.curves.smooth
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.durations.normal
                    easing.type: Config.curves.smooth
                }
            }

            NotificationPopupCard {
                id: popupCard
                width: parent.width
                entry: notifScope.displayedPopupEntry
            }
        }
    }
}
