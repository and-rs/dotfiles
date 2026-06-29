import QtQuick
import qs.Bar

Item {
  id: root

  property bool pendingScrollRestore: false
  property real preservedContentY: 0
  readonly property int seamHeight: 28
  property real wheelScrollMultiplier: 7.0
  property bool clearingAll: false

  signal clearAllRequested
  signal closeRequested(notificationId: int)

  function restoreContentY(): void {
    const maxContentY = Math.max(0, listView.contentHeight - listView.height);
    listView.contentY = Math.max(0, Math.min(maxContentY, preservedContentY));
  }

  function beginClearAll(): void {
    if (root.clearingAll || NotificationStore.count === 0)
      return;

    root.preservedContentY = listView.contentY;
    root.pendingScrollRestore = false;
    root.clearingAll = true;
    clearAllTimer.restart();
  }

  anchors.fill: parent

  Column {
    anchors.fill: parent
    spacing: Config.spacing.normal

    Item {
      height: parent.height - y - clearAllButton.implicitHeight - Config.spacing.normal
      width: parent.width

      Timer {
        id: restoreScrollTimer

        interval: 16
        repeat: false

        onTriggered: {
          if (!root.pendingScrollRestore)
            return;
          root.restoreContentY();
          root.pendingScrollRestore = false;
        }
      }
      Timer {
        id: clearAllTimer

        interval: Config.durations.fast
        repeat: false

        onTriggered: {
          root.clearAllRequested();
          root.clearingAll = false;
        }
      }
      MouseArea {
        acceptedButtons: Qt.NoButton
        anchors.fill: parent

        onWheel: wheel => {
          if (!listView.visible)
            return;

          wheel.accepted = true;
          const maxContentY = Math.max(0, listView.contentHeight - listView.height);
          const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y * root.wheelScrollMultiplier : (wheel.angleDelta.y / 120) * 24 * root.wheelScrollMultiplier;
          listView.contentY = Math.max(0, Math.min(maxContentY, listView.contentY - delta));
        }
      }
      ListView {
        id: listView

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        clip: true
        interactive: false
        model: NotificationStore.entries
        spacing: Config.spacing.extraSmall
        visible: NotificationStore.count > 0

        delegate: Item {
          required property var modelData
          property bool closingSelf: false
          property bool closing: root.clearingAll || closingSelf

          height: closing ? 0 : card.implicitHeight
          opacity: closing ? 0 : 1
          scale: closing ? 0.96 : 1
          x: closing ? 20 : 0
          width: listView.width

          Behavior on height {
            NumberAnimation {
              duration: Config.durations.fast
              easing.type: Config.curve
            }
          }
          Behavior on opacity {
            NumberAnimation {
              duration: Config.durations.fast
              easing.type: Config.curve
            }
          }
          Behavior on scale {
            NumberAnimation {
              duration: Config.durations.fast
              easing.type: Config.curve
            }
          }
          Behavior on x {
            NumberAnimation {
              duration: Config.durations.fast
              easing.type: Config.curve
            }
          }

          Timer {
            id: closeTimer

            interval: Config.durations.fast
            repeat: false

            onTriggered: {
              root.closeRequested(modelData.id);
              restoreScrollTimer.restart();
            }
          }
          NotificationCard {
            id: card

            compact: false
            entry: modelData
            showCloseButton: true
            width: parent.width

            onActionRequested: (notificationId, actionIndex) => NotificationStore.invokeVisibleAction(notificationId, actionIndex)
            onActivateRequested: notificationId => NotificationStore.invokeDefaultAction(notificationId)
            onCloseRequested: notificationId => {
              if (root.clearingAll || closingSelf)
                return;
              root.preservedContentY = listView.contentY;
              root.pendingScrollRestore = true;
              closingSelf = true;
              closeTimer.restart();
            }
            onInlineReplyRequested: (notificationId, text) => NotificationStore.sendInlineReply(notificationId, text)
          }
        }
        displaced: Transition {
          NumberAnimation {
            duration: Config.durations.fast
            easing.type: Config.curve
            property: "y"
          }
        }
        footer: Item {
          height: root.seamHeight
          width: listView.width
        }
        header: Item {
          height: root.seamHeight
          width: listView.width
        }
        remove: Transition {
          ParallelAnimation {
            NumberAnimation {
              duration: Config.durations.fast
              easing.type: Config.curve
              property: "opacity"
              to: 0
            }
            NumberAnimation {
              duration: Config.durations.fast
              easing.type: Config.curve
              property: "scale"
              to: 0.96
            }
            NumberAnimation {
              duration: Config.durations.fast
              easing.type: Config.curve
              property: "x"
              to: 20
            }
          }
        }

        onContentHeightChanged: {
          if (root.pendingScrollRestore)
            restoreScrollTimer.restart();
        }
        onCountChanged: {
          if (root.pendingScrollRestore)
            restoreScrollTimer.restart();
        }
      }
      Text {
        anchors.centerIn: parent
        color: Config.colors.surface4
        font.pixelSize: Config.sizes.normal
        font.weight: Font.Medium
        text: "No saved notifications"
        textFormat: Text.PlainText
        visible: NotificationStore.count === 0
      }
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        color: "transparent"
        height: root.seamHeight
        visible: listView.visible && listView.contentY > 0
        z: 2

        gradient: Gradient {
          orientation: Gradient.Vertical

          GradientStop {
            color: Config.colors.base
            position: 0.0
          }
          GradientStop {
            color: Qt.rgba(0, 0, 0, 0)
            position: 1.0
          }
        }
      }
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        color: "transparent"
        height: root.seamHeight
        visible: listView.visible && listView.contentY < Math.max(0, listView.contentHeight - listView.height) - 1
        z: 2

        gradient: Gradient {
          orientation: Gradient.Vertical

          GradientStop {
            color: Qt.rgba(0, 0, 0, 0)
            position: 0.0
          }
          GradientStop {
            color: Config.colors.base
            position: 1.0
          }
        }
      }
    }
    Row {
      spacing: Config.spacing.normal
      width: parent.width

      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.spacing.extraSmall
        width: parent.width - clearAllButton.implicitWidth - parent.spacing

        Text {
          color: Config.colors.fg
          elide: Text.ElideRight
          font.pixelSize: Config.sizes.normal
          font.weight: Font.Medium
          text: NotificationStore.count === 1 ? "1 saved notification" : NotificationStore.count + " saved notifications"
          textFormat: Text.PlainText
          width: parent.width
        }
        Text {
          color: Config.colors.surface4
          elide: Text.ElideRight
          font.pixelSize: Config.sizes.small
          text: NotificationStore.count > 0 ? "Saved in NotificationV2" : "All clear"
          textFormat: Text.PlainText
          width: parent.width
        }
      }
      PanelButton {
        id: clearAllButton

        enabled: NotificationStore.count > 0 && !root.clearingAll
        label: "Clear all"
        prominent: true

        onPress: () => root.beginClearAll()
      }
    }
  }

  component PanelButton: Rectangle {
    id: buttonRoot

    property bool enabled: true
    required property string label
    required property var onPress
    property bool prominent: false

    color: enabled ? Config.colors.surface1 : Config.colors.surface2
    implicitHeight: labelText.implicitHeight + (prominent ? Config.padding.normal : Config.padding.small) * 2
    implicitWidth: labelText.implicitWidth + (prominent ? Config.padding.large : Config.padding.normal) * 2
    opacity: enabled ? 1 : 0.6
    radius: Config.radius.normal

    Text {
      id: labelText

      anchors.centerIn: parent
      color: Config.colors.fg
      font.pixelSize: buttonRoot.prominent ? Config.sizes.normal : Config.sizes.small
      font.weight: Font.Medium
      text: buttonRoot.label
      textFormat: Text.PlainText
    }
    MouseArea {
      anchors.fill: parent
      enabled: buttonRoot.enabled

      onClicked: buttonRoot.onPress()
    }
  }
}
