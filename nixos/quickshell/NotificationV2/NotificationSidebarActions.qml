import QtQuick
import qs.Bar

Item {
  id: root

  property bool clearingAll: false
  readonly property int endInset: seamHeight + Config.padding.normal
  property var pendingRemovals: ({})
  property int removalAnchorId: -1
  property real removalAnchorOffset: 0
  property int removalFallbackId: -1
  readonly property int seamHeight: 28
  property real wheelScrollMultiplier: 10.0

  signal clearAllRequested
  signal closeRequested(notificationId: int)

  function beginClearAll(): void {
    if (root.clearingAll || NotificationStore.count === 0)
      return;

    root.pendingRemovals = ({});
    removalTimer.stop();
    root.resetViewportAnchor();
    root.clearingAll = true;
    clearAllTimer.restart();
  }
  function beginRemoval(id: int): void {
    if (root.clearingAll || root.pendingRemovals[id])
      return;

    const nextRemovals = Object.assign({}, root.pendingRemovals);
    nextRemovals[id] = {
      deadline: Date.now() + Config.notifications.popupDuration
    };
    root.pendingRemovals = nextRemovals;
    root.scheduleNextRemoval();
  }
  function captureViewportAnchor(removingIds: var): void {
    if (root.removalAnchorId !== -1)
      return;

    const firstIndex = listView.indexAt(1, listView.contentY + 1);
    const firstItem = firstIndex >= 0 ? listView.itemAtIndex(firstIndex) : null;
    if (!firstItem)
      return;

    root.removalAnchorOffset = firstItem.y - listView.contentY;
    for (let index = firstIndex; index < NotificationStore.count; index++) {
      const id = NotificationStore.records[index].id;
      if (!removingIds[id]) {
        root.removalAnchorId = id;
        return;
      }
    }
    for (let index = firstIndex - 1; index >= 0; index--) {
      const id = NotificationStore.records[index].id;
      if (!removingIds[id]) {
        root.removalAnchorId = id;
        return;
      }
    }
    root.removalFallbackId = firstItem.notificationId;
  }
  function clampContentY(value: real): real {
    return Math.max(root.minimumContentY(), Math.min(root.maximumContentY(), value));
  }
  function finalizeDueRemovals(): void {
    const now = Date.now();
    const dueIds = [];
    const nextRemovals = {};
    const ids = Object.keys(root.pendingRemovals);
    for (let index = 0; index < ids.length; index++) {
      const id = ids[index];
      if (root.pendingRemovals[id].deadline <= now)
        dueIds.push(Number(id));
      else
        nextRemovals[id] = root.pendingRemovals[id];
    }
    root.captureViewportAnchor(root.pendingRemovals);
    root.pendingRemovals = nextRemovals;
    root.scheduleNextRemoval();
    for (let index = 0; index < dueIds.length; index++)
      root.closeRequested(dueIds[index]);
    if (dueIds.length > 0)
      restoreViewportTimer.restart();
  }
  function finalizePendingRemovals(): void {
    const ids = Object.keys(root.pendingRemovals);
    if (ids.length === 0)
      return;

    root.captureViewportAnchor(root.pendingRemovals);
    root.pendingRemovals = ({});
    removalTimer.stop();
    for (let index = 0; index < ids.length; index++)
      root.closeRequested(Number(ids[index]));
    restoreViewportTimer.restart();
  }
  function indexOfEntry(id: int): int {
    for (let index = 0; index < NotificationStore.count; index++) {
      if (NotificationStore.records[index].id === id)
        return index;
    }
    return -1;
  }
  function maximumContentY(): real {
    return Math.max(root.minimumContentY(), listView.contentHeight - listView.height + listView.bottomMargin);
  }
  function minimumContentY(): real {
    return listView.originY - listView.topMargin;
  }
  function resetViewportAnchor(): void {
    root.removalAnchorId = -1;
    root.removalFallbackId = -1;
    root.removalAnchorOffset = 0;
  }
  function restoreViewport(): void {
    listView.forceLayout();
    let index = root.indexOfEntry(root.removalAnchorId);
    if (index === -1)
      index = root.indexOfEntry(root.removalFallbackId);
    if (index < 0) {
      root.resetViewportAnchor();
      return;
    }

    const item = listView.itemAtIndex(index);
    if (item)
      listView.contentY = root.clampContentY(item.y - root.removalAnchorOffset);
    root.resetViewportAnchor();
  }
  function scheduleNextRemoval(): void {
    let nextDeadline = 0;
    const ids = Object.keys(root.pendingRemovals);
    for (let index = 0; index < ids.length; index++) {
      const deadline = root.pendingRemovals[ids[index]].deadline;
      if (nextDeadline === 0 || deadline < nextDeadline)
        nextDeadline = deadline;
    }
    if (nextDeadline === 0) {
      removalTimer.stop();
      return;
    }

    removalTimer.interval = Math.max(1, nextDeadline - Date.now());
    removalTimer.restart();
  }
  function undoRemoval(id: int): void {
    if (!root.pendingRemovals[id])
      return;

    const nextRemovals = Object.assign({}, root.pendingRemovals);
    delete nextRemovals[id];
    root.pendingRemovals = nextRemovals;
    root.scheduleNextRemoval();
  }

  anchors.fill: parent

  Column {
    anchors.fill: parent
    spacing: Config.spacing.normal

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
    Item {
      height: parent.height - y
      width: parent.width

      Timer {
        id: clearAllTimer

        interval: Config.durations.fast
        repeat: false

        onTriggered: {
          root.clearAllRequested();
          root.clearingAll = false;
        }
      }
      Timer {
        id: removalTimer

        interval: 1
        repeat: false

        onTriggered: root.finalizeDueRemovals()
      }
      Timer {
        id: restoreViewportTimer

        interval: 0
        repeat: false

        onTriggered: root.restoreViewport()
      }
      MouseArea {
        acceptedButtons: Qt.NoButton
        anchors.fill: parent

        onWheel: wheel => {
          if (!listView.visible)
            return;

          wheel.accepted = true;
          const delta = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y * root.wheelScrollMultiplier : (wheel.angleDelta.y / 120) * 24 * root.wheelScrollMultiplier;
          listView.contentY = root.clampContentY(listView.contentY - delta);
        }
      }
      ListView {
        id: listView

        anchors.fill: parent
        bottomMargin: root.endInset
        boundsBehavior: Flickable.StopAtBounds
        boundsMovement: Flickable.StopAtBounds
        clip: true
        interactive: false
        model: NotificationStore.entries
        opacity: root.clearingAll ? 0 : 1
        reuseItems: true
        spacing: Config.spacing.extraSmall
        visible: NotificationStore.count > 0

        add: Transition {
          NumberAnimation {
            duration: Config.durations.fast
            easing.type: Config.curve
            from: 0
            property: "opacity"
            to: 1
          }
        }
        delegate: Item {
          required property var modelData
          readonly property int notificationId: modelData.id
          readonly property bool pendingRemoval: Boolean(root.pendingRemovals[modelData.id])

          ListView.delayRemove: false
          height: card.implicitHeight
          width: listView.width

          ListView.onPooled: card.resetTransientState()
          ListView.onReused: card.resetTransientState()

          NotificationCard {
            id: card

            anchors.fill: parent
            compact: false
            entry: modelData
            showCloseButton: false
            visible: !pendingRemoval
            width: parent.width

            onActionRequested: (notificationId, actionIndex) => NotificationStore.invokeAction(notificationId, actionIndex)
            onActivateRequested: notificationId => NotificationStore.invokeDefaultAction(notificationId)
            onInlineReplyRequested: (notificationId, text) => NotificationStore.sendInlineReply(notificationId, text)
            onLinkActivated: link => Qt.openUrlExternally(link)

            MouseArea {
              acceptedButtons: Qt.RightButton
              anchors.fill: parent

              onClicked: mouse => {
                mouse.accepted = true;
                root.beginRemoval(modelData.id);
              }
            }
          }
          Loader {
            id: undoRow

            active: pendingRemoval
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height

            sourceComponent: Rectangle {
              color: Config.colors.surface1
              height: parent.height
              opacity: 0
              radius: Config.radius.normal
              width: parent.width

              Behavior on opacity {
                NumberAnimation {
                  duration: Config.durations.fast
                  easing.type: Config.curve
                }
              }

              Component.onCompleted: opacity = 1

              Column {
                id: undoContent

                anchors.centerIn: parent
                spacing: Config.spacing.small
                width: parent.width - Config.padding.large * 2

                Row {
                  spacing: Config.spacing.small
                  width: parent.width

                  Text {
                    color: Config.colors.fg
                    font.pixelSize: Config.sizes.small
                    text: "Notification removed"
                    textFormat: Text.PlainText
                    verticalAlignment: Text.AlignVCenter
                    width: parent.width - undoButton.width - parent.spacing
                  }
                  Rectangle {
                    id: undoButton

                    color: undoArea.containsMouse ? Config.colors.primary : Config.colors.surface2
                    height: undoLabel.implicitHeight + Config.padding.extraSmall * 2
                    radius: Config.radius.small
                    width: undoLabel.implicitWidth + Config.padding.normal * 2

                    Text {
                      id: undoLabel

                      anchors.centerIn: parent
                      color: undoArea.containsMouse ? Config.colors.base : Config.colors.primary
                      font.pixelSize: Config.sizes.small
                      font.weight: Font.Medium
                      text: "Undo"
                      textFormat: Text.PlainText
                    }
                    MouseArea {
                      id: undoArea

                      anchors.fill: parent
                      hoverEnabled: true

                      onClicked: root.undoRemoval(modelData.id)
                    }
                  }
                }
                Rectangle {
                  color: Config.colors.surface3
                  height: 2
                  width: parent.width

                  Rectangle {
                    anchors.right: parent.right
                    color: Config.colors.primary
                    height: parent.height
                    width: parent.width

                    NumberAnimation on width {
                      duration: Math.max(1, root.pendingRemovals[modelData.id].deadline - Date.now())
                      easing.type: Easing.Linear
                      from: parent.width
                      running: true
                      to: 0
                    }
                  }
                }
              }
            }
          }
        }
        Behavior on opacity {
          NumberAnimation {
            duration: Config.durations.fast
            easing.type: Config.curve
          }
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
          }
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
        visible: listView.visible && listView.contentY > root.minimumContentY() + 1
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
        visible: listView.visible && listView.contentY < root.maximumContentY() - 1
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
