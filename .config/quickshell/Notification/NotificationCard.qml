import QtQuick
import qs.Bar

Rectangle {
  id: card

  property int notifId: 0
  property string summary: ""
  property string body: ""
  property string appName: ""
  property string appIcon: ""
  property string appImage: ""
  property string desktopEntry: ""
  property var actions: []

  property int autoCloseDuration: 3000
  property bool isHovered: false
  property real progress: 0
  property bool isActiveCard: false

  property real swipeThreshold: 80
  property bool isDragging: false

  signal dismissed
  signal actionInvoked(actionId: string)

  width: parent ? parent.width : 360
  height: contentColumn.height + Config.padding.large * 2
  color: Config.colors.dim
  radius: Config.radius.normal
  x: 0

  Behavior on x {
    enabled: !isDragging
    NumberAnimation {
      duration: Config.durations.fast
      easing.type: Config.curves.standard | update
    }
  }

  Behavior on opacity {
    enabled: !isDragging
    NumberAnimation {
      duration: Config.durations.fast
      easing.type: Config.curves.standard | update
    }
  }

  function startTimer() {
    card.progress = 0;
    autoCloseTimer.start();
  }

  function stopTimer() {
    autoCloseTimer.stop();
  }

  onIsActiveCardChanged: {
    if (isActiveCard) {
      startTimer();
    } else {
      stopTimer();
      card.progress = 0;
    }
  }

  Component.onCompleted: {
    showAnimation.start();
  }

  Timer {
    id: autoCloseTimer
    interval: 50
    repeat: true
    running: false

    onTriggered: {
      if (!card.isActiveCard) {
        stop();
        return;
      }

      if (!card.isHovered && !card.isDragging) {
        card.progress += 50 / card.autoCloseDuration;
        if (card.progress >= 1.0) {
          autoCloseTimer.stop();
          hideAnimation.start();
        }
      }
    }
  }

  ParallelAnimation {
    id: showAnimation
    NumberAnimation {
      target: card
      property: "opacity"
      from: 0
      to: 1
      duration: Config.durations.fast
      easing.type: Config.curves.standard | update
    }
    NumberAnimation {
      target: card
      property: "scale"
      from: 0.9
      to: 1.0
      duration: 350
      easing.type: Config.curves.standard | update
    }
  }

  SequentialAnimation {
    id: hideAnimation
    ParallelAnimation {
      NumberAnimation {
        target: card
        property: "x"
        to: card.x < 0 ? -600 : 600
        duration: Config.durations.fast
        easing.type: Config.curves.standard | update
      }
      NumberAnimation {
        target: card
        property: "opacity"
        to: 0
        duration: Config.durations.fast
        easing.type: Config.curves.standard | update
      }
    }
    ScriptAction {
      script: {
        NotificationService.dismiss(card.notifId);
        card.dismissed();
      }
    }
  }

  MouseArea {
    id: dragArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
    preventStealing: true

    property real pressX: 0
    property real startX: 0

    onEntered: {
      card.isHovered = true;
    }

    onExited: {
      card.isHovered = false;
    }

    onPressed: function (mouse) {
      if (mouse.button === Qt.LeftButton) {
        pressX = mouse.x;
        startX = card.x;
        card.isDragging = true;
      }
    }

    onPositionChanged: function (mouse) {
      if (card.isDragging && (mouse.buttons & Qt.LeftButton)) {
        var delta = mouse.x - pressX;
        card.x = startX + delta;

        var swipeDistance = Math.abs(card.x);
        var normalizedDistance = Math.min(swipeDistance / 150, 1.0);
        card.opacity = 1 - (normalizedDistance * 0.7);
      }
    }

    onReleased: function (mouse) {
      if (mouse.button === Qt.LeftButton && card.isDragging) {
        card.isDragging = false;

        var swipeDistance = Math.abs(card.x);

        if (swipeDistance > swipeThreshold) {
          hideAnimation.start();
        } else {
          card.x = 0;
          card.opacity = 1;
        }
      }
    }

    onClicked: function (mouse) {
      if (mouse.button === Qt.RightButton) {
        autoCloseTimer.stop();
        hideAnimation.start();
      }
    }
  }

  Column {
    id: contentColumn
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Config.padding.large
    spacing: Config.spacing.normal

    NotificationProgress {
      progress: card.progress
      visible: card.isActiveCard
    }

    NotificationHeader {
      appName: card.appName
      appIcon: card.appIcon
      appImage: card.appImage
      desktopEntry: card.desktopEntry

      body: card.body
      bodyTextImplicitHeight: cardContent.height
      bodyExpanded: cardContent.bodyCarouselContainer.expanded

      onExpandBody: {
        cardContent.bodyCarouselContainer.expanded = true;
      }

      onCollapseBody: {
        cardContent.bodyCarouselContainer.expanded = false;
      }
    }

    NotificationContent {
      id: cardContent
      summary: card.summary
      body: card.body
    }
  }
}
