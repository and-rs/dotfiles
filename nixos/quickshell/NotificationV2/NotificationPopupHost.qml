import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import qs.Bar

Scope {
  id: root

  property real contentOffset: 0
  property real contentOpacity: 1
  property var displayedEntry: NotificationStore.popupEntry
  required property int mainHeight
  property var pendingEntry: null
  property bool popupShown: popupVisible
  readonly property bool popupVisible: NotificationStore.popupEntry !== null
  property bool popupWindowVisible: popupVisible

  function handlePopupEntryChanged(): void {
    const nextEntry = NotificationStore.popupEntry;
    if (!nextEntry)
      return;
    if (!popupWindowVisible || !displayedEntry || displayedEntry.id === nextEntry.id) {
      displayedEntry = nextEntry;
      return;
    }
    pendingEntry = nextEntry;
    popupSwapAnimation.restart();
  }

  onPopupVisibleChanged: {
    if (popupVisible) {
      displayedEntry = NotificationStore.popupEntry;
      pendingEntry = null;
      contentOpacity = 1;
      contentOffset = 0;
      popupWindowVisible = true;
      popupShown = true;
    } else {
      popupShown = false;
    }
  }

  Connections {
    function onPopupEntryChanged(): void {
      root.handlePopupEntryChanged();
    }

    target: NotificationStore
  }
  NotificationServer {
    id: server

    actionIconsSupported: true
    actionsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true
    bodySupported: true
    imageSupported: true
    inlineReplySupported: true
    persistenceSupported: true

    onNotification: notification => NotificationStore.addNotification(notification)
  }
  PanelWindow {
    id: popupWindow

    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusiveZone: 0
    implicitHeight: popupFrame.implicitHeight
    implicitWidth: Config.notifications.popupWidth
    margins.right: Config.spacing.small
    margins.top: Config.spacing.small
    visible: root.popupWindowVisible

    Component.onCompleted: {
      if (WlrLayershell != null) {
        WlrLayershell.namespace = "quickshell-notification-v2-popup";
        WlrLayershell.layer = WlrLayer.Overlay;
      }
    }

    Item {
      id: popupFrame

      height: popupCard.implicitHeight
      implicitHeight: height
      opacity: root.popupShown ? 1 : 0
      width: Config.notifications.popupWidth
      x: root.popupShown ? 0 : width + Config.spacing.small

      Behavior on opacity {
        NumberAnimation {
          duration: Config.durations.extraFast
          easing.type: Config.curve
        }
      }
      Behavior on x {
        NumberAnimation {
          duration: Config.durations.fast
          easing.type: Config.curve

          onRunningChanged: {
            if (!running && !root.popupShown) {
              root.popupWindowVisible = false;
              root.displayedEntry = null;
            }
          }
        }
      }

      SequentialAnimation {
        id: popupSwapAnimation

        NumberAnimation {
          duration: Config.durations.instant
          easing.type: Config.curve
          property: "contentOpacity"
          target: root
          to: 0
        }
        NumberAnimation {
          duration: Config.durations.instant
          easing.type: Config.curve
          property: "contentOffset"
          target: root
          to: -Config.spacing.normal
        }
        ScriptAction {
          script: {
            root.displayedEntry = root.pendingEntry;
            root.pendingEntry = null;
            root.contentOffset = Config.spacing.normal;
          }
        }
        ParallelAnimation {
          NumberAnimation {
            duration: Config.durations.extraFast
            easing.type: Config.curve
            property: "contentOpacity"
            target: root
            to: 1
          }
          NumberAnimation {
            duration: Config.durations.extraFast
            easing.type: Config.curve
            property: "contentOffset"
            target: root
            to: 0
          }
        }
      }
      Item {
        id: popupContent

        height: popupCard.implicitHeight
        opacity: root.contentOpacity
        width: parent.width
        x: root.contentOffset

        NotificationCard {
          id: popupCard

          bodyLineLimit: 4
          bottomInset: timeoutBar.height + Config.spacing.small
          compact: true
          entry: root.displayedEntry
          previewIconSize: 52
          showActivateButton: root.displayedEntry ? root.displayedEntry.hasDefaultAction : false
          showInlineReply: false
          summaryLineLimit: 2
          width: parent.width

          onActionRequested: (notificationId, actionIndex) => NotificationStore.invokeVisibleAction(notificationId, actionIndex)
          onActivateRequested: notificationId => NotificationStore.invokeDefaultAction(notificationId)
          onInlineReplyRequested: (notificationId, text) => NotificationStore.sendInlineReply(notificationId, text)
        }
        MouseArea {
          acceptedButtons: Qt.LeftButton
          anchors.fill: popupCard
          propagateComposedEvents: true

          onClicked: mouse => {
            NotificationStore.hideActivePopup();
            mouse.accepted = false;
          }
        }
        NotificationTimeoutBar {
          id: timeoutBar

          anchors.bottom: popupCard.bottom
          anchors.bottomMargin: popupCard.border.width + Config.padding.small
          anchors.left: parent.left
          anchors.leftMargin: popupCard.border.width + Config.padding.small
          anchors.right: parent.right
          anchors.rightMargin: popupCard.border.width + Config.padding.small
          durationMs: root.displayedEntry ? root.displayedEntry.popupDurationMs : 0
          notificationId: root.displayedEntry ? root.displayedEntry.id : -1
          running: root.popupShown

          onExpired: notificationId => NotificationStore.expirePopup(notificationId)
        }
      }
    }
  }
}
