import QtQuick
import qs.Bar
import qs.Notification

Rectangle {
  id: root

  required property var entry
  readonly property string appName: entry ? entry.appName : ""
  readonly property string summary: entry ? entry.summary : ""
  readonly property string body: entry ? entry.body : ""
  readonly property string image: entry ? entry.image : ""
  readonly property string appIcon: entry ? entry.appIcon : ""
  readonly property int notificationId: entry ? entry.id : -1
  readonly property bool hasDefaultAction: NotificationStore.hasDefaultAction(notificationId)
  function startProgress() {
    progressAnimation.stop();
    timeoutFill.width = root.entry ? timeoutBar.width : 0;
    if (!root.entry)
      return;
    progressAnimation.from = timeoutBar.width;
    progressAnimation.to = 0;
    progressAnimation.duration = Math.max(1, root.entry.popupDurationMs);
    progressAnimation.start();
  }

  onEntryChanged: startProgress()
  Component.onCompleted: startProgress()

  NumberAnimation {
    id: progressAnimation
    target: timeoutFill
    property: "width"
    from: timeoutBar.width
    to: 0
    onFinished: {
      if (root.entry)
        NotificationStore.hideActivePopup();
    }
  }

  implicitHeight: contentColumn.implicitHeight + Config.padding.large * 2 + timeoutBar.height + border.width
  color: Config.colors.base
  border.width: 2
  border.color: Config.colors.surface2
  radius: Config.radius.normal

  MouseArea {
    anchors.fill: parent
    z: 0
    onClicked: NotificationStore.hideActivePopup()
  }

  Column {
    id: contentColumn
    z: 1
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Config.padding.large
    spacing: Config.spacing.normal

    Row {
      width: parent.width
      spacing: Config.spacing.normal

      IconFallback {
        id: previewIcon
        size: 52
        expandToAspect: true
        image: root.image || root.appIcon
        fallbackText: root.appName ? root.appName.charAt(0).toUpperCase() : ""
      }

      Column {
        width: parent.width - previewIcon.width - (activateButton.visible ? activateButton.width : 0) - parent.spacing * (activateButton.visible ? 2 : 1)
        spacing: Config.spacing.extraSmall

        Text {
          width: parent.width
          text: root.appName
          visible: text !== ""
          color: Config.colors.primary
          font.pixelSize: Config.sizes.small
          font.weight: Font.Medium
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Text {
          width: parent.width
          text: root.summary
          color: Config.colors.fg
          font.pixelSize: Config.sizes.normal
          font.weight: Font.Medium
          wrapMode: Text.Wrap
          maximumLineCount: 2
          textFormat: Text.PlainText
        }
      }

      Rectangle {
        id: activateButton
        width: 20
        height: 20
        visible: root.hasDefaultAction
        radius: Config.radius.full
        color: activateArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1

        MaterialIcon {
          anchors.centerIn: parent
          code: 0xE042
          iconColor: activateArea.containsMouse ? Config.colors.base : Config.colors.primary
          iconSize: 11
        }

        MouseArea {
          id: activateArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: NotificationStore.invokeDefaultAction(root.notificationId)
        }
      }
    }

    Text {
      width: parent.width
      text: root.body
      visible: text !== ""
      color: Config.colors.fg
      font.pixelSize: Config.sizes.normal
      wrapMode: Text.Wrap
      maximumLineCount: 4
      textFormat: Text.RichText
    }

    NotificationActions {
      width: parent.width
      entry: root.entry
      compact: true
    }
  }

  Rectangle {
    id: timeoutBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.border.width + Config.padding.small
    anchors.rightMargin: root.border.width + Config.padding.small
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.border.width + Config.padding.small
    height: 3
    radius: Config.radius.small
    color: Config.colors.surface2
    clip: true

    Rectangle {
      id: timeoutFill
      width: 0
      height: parent.height
      radius: parent.radius

      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
          position: 0.0
          color: Config.colors.primary
        }
        GradientStop {
          position: 0.7
          color: Config.colors.primary
        }
        GradientStop {
          position: 1.0
          color: Qt.lighter(Config.colors.primary, 1.2)
        }
      }
    }
  }
}
