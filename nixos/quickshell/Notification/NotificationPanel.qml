import QtQuick
import qs.Bar
import qs.Notification

Item {
  id: root

  anchors.fill: parent
  property real wheelScrollMultiplier: 7.0
  property real preservedContentY: 0
  property bool pendingScrollRestore: false
  readonly property int seamHeight: 28

  function restoreContentY(): void {
    const maxContentY = Math.max(0, listView.contentHeight - listView.height);
    listView.contentY = Math.max(0, Math.min(maxContentY, preservedContentY));
  }

  component PanelButton: Rectangle {
    id: buttonRoot

    required property string label
    required property var onPress
    property bool enabled: true
    property bool prominent: false

    implicitWidth: labelText.implicitWidth + (prominent ? Config.padding.large : Config.padding.normal) * 2
    implicitHeight: labelText.implicitHeight + (prominent ? Config.padding.normal : Config.padding.small) * 2
    radius: Config.radius.normal
    color: enabled ? Config.colors.surface1 : Config.colors.surface2
    opacity: enabled ? 1 : 0.6

    Text {
      id: labelText
      anchors.centerIn: parent
      text: buttonRoot.label
      color: Config.colors.fg
      font.pixelSize: buttonRoot.prominent ? Config.sizes.normal : Config.sizes.small
      font.weight: Font.Medium
      textFormat: Text.PlainText
    }

    MouseArea {
      anchors.fill: parent
      enabled: buttonRoot.enabled
      onClicked: buttonRoot.onPress()
    }
  }

  Column {
    anchors.fill: parent
    spacing: Config.spacing.normal

    Item {
      width: parent.width
      height: parent.height - y - clearAllButton.implicitHeight - Config.spacing.normal

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

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
          if (!listView.visible)
            return;

          wheel.accepted = true;
          const maxContentY = Math.max(0, listView.contentHeight - listView.height);
          const delta = wheel.pixelDelta.y !== 0
              ? wheel.pixelDelta.y * root.wheelScrollMultiplier
              : (wheel.angleDelta.y / 120) * 24 * root.wheelScrollMultiplier;
          listView.contentY = Math.max(0, Math.min(maxContentY, listView.contentY - delta));
        }
      }

      ListView {
        id: listView
        anchors.fill: parent
        clip: true
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        spacing: Config.spacing.extraSmall
        model: NotificationStore.items
        visible: NotificationStore.count > 0

        onCountChanged: {
          if (root.pendingScrollRestore)
            restoreScrollTimer.restart();
        }

        onContentHeightChanged: {
          if (root.pendingScrollRestore)
            restoreScrollTimer.restart();
        }

        remove: Transition {
          ParallelAnimation {
            NumberAnimation {
              property: "opacity"
              to: 0
              duration: Config.durations.fast
              easing.type: Config.curve
            }
            NumberAnimation {
              property: "scale"
              to: 0.96
              duration: Config.durations.fast
              easing.type: Config.curve
            }
            NumberAnimation {
              property: "x"
              to: 20
              duration: Config.durations.fast
              easing.type: Config.curve
            }
          }
        }

        displaced: Transition {
          NumberAnimation {
            property: "y"
            duration: Config.durations.fast
            easing.type: Config.curve
          }
        }

        header: Item {
          width: listView.width
          height: root.seamHeight
        }

        footer: Item {
          width: listView.width
          height: root.seamHeight
        }

        delegate: Item {
          required property var modelData

          width: listView.width
          height: card.implicitHeight
          opacity: 1
          scale: 1

          NotificationCard {
            id: card
            width: parent.width
            entry: modelData
            compact: false
            onCloseRequested: notificationId => {
              root.preservedContentY = listView.contentY;
              root.pendingScrollRestore = true;
              NotificationStore.dismiss(notificationId);
              restoreScrollTimer.restart();
            }
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: NotificationStore.count === 0
        text: "No saved notifications"
        color: Config.colors.surface4
        font.pixelSize: Config.sizes.normal
        font.weight: Font.Medium
        textFormat: Text.PlainText
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.seamHeight
        visible: listView.visible && listView.contentY > 0
        z: 2
        color: "transparent"

        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop {
            position: 0.0
            color: Config.colors.base
          }
          GradientStop {
            position: 1.0
            color: Qt.rgba(0, 0, 0, 0)
          }
        }
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.seamHeight
        visible: listView.visible && listView.contentY < Math.max(0, listView.contentHeight - listView.height) - 1
        z: 2
        color: "transparent"

        gradient: Gradient {
          orientation: Gradient.Vertical
          GradientStop {
            position: 0.0
            color: Qt.rgba(0, 0, 0, 0)
          }
          GradientStop {
            position: 1.0
            color: Config.colors.base
          }
        }
      }
    }

    Row {
      width: parent.width
      spacing: Config.spacing.normal

      Column {
        width: parent.width - clearAllButton.implicitWidth - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Config.spacing.extraSmall

        Text {
          width: parent.width
          text: NotificationStore.count === 1 ? "1 saved notification" : NotificationStore.count + " saved notifications"
          color: Config.colors.fg
          font.pixelSize: Config.sizes.normal
          font.weight: Font.Medium
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Text {
          width: parent.width
          text: NotificationStore.count > 0 ? "Click cards to review or clear them all" : "All clear"
          color: Config.colors.surface4
          font.pixelSize: Config.sizes.small
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }
      }

      PanelButton {
        id: clearAllButton
        label: "Clear all"
        prominent: true
        enabled: NotificationStore.count > 0
        onPress: () => NotificationStore.clearAll()
      }
    }
  }
}
