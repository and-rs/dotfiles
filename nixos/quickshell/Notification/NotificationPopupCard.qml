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
  function startProgress() {
    progressAnimation.stop();
    timeoutFill.width = root.entry ? timeoutTrack.width : 0;
    if (!root.entry)
      return;
    progressAnimation.from = timeoutTrack.width;
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
    from: timeoutTrack.width
    to: 0
    easing.type: Config.curve
    onFinished: {
      if (root.entry)
        NotificationStore.hideActivePopup();
    }
  }

  implicitHeight: contentColumn.implicitHeight + Config.padding.large * 2 + timeoutTrack.height + border.width
  color: Config.colors.base
  border.width: 2
  border.color: Config.colors.surface2
  radius: Config.radius.normal

  Column {
    id: contentColumn
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
        size: 40
        image: root.image || root.appIcon
        fallbackText: root.appName ? root.appName.charAt(0).toUpperCase() : ""
      }

      Column {
        width: parent.width - previewIcon.width - parent.spacing
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

    }

    Text {
      width: parent.width
      text: root.body
      visible: text !== ""
      color: Config.colors.fg
      font.pixelSize: Config.sizes.normal
      wrapMode: Text.Wrap
      maximumLineCount: 4
      textFormat: Text.PlainText
    }
  }

  Rectangle {
    id: timeoutTrack
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: root.border.width
    anchors.rightMargin: root.border.width
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.border.width
    height: 3
    radius: Config.radius.small
    color: Config.colors.surface1
    clip: true

    Rectangle {
      id: timeoutFill
      width: 0
      height: parent.height
      radius: parent.radius
      color: Config.colors.primary

    }
  }
}
