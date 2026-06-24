import Quickshell
import QtQuick
import qs.Bar

PopupWindow {
  id: root

  required property PanelWindow window
  required property bool open
  property string title: ""
  property int panelWidth: Config.sidebar.width
  property int panelHeight: Math.max(1, (window.screen ? window.screen.height : Config.sidebar.maxHeight) - window.height)
  property int hostWidth: window.screen ? window.screen.width : panelWidth
  property real panelOffset: panelWidth

  signal closeRequested

  default property alias content: panelBody.data

  anchor.window: window
  anchor.rect.x: 0
  anchor.rect.y: window.height

  visible: false
  grabFocus: false
  color: "transparent"

  implicitWidth: hostWidth
  implicitHeight: panelHeight

  Component.onCompleted: {
    if (open) {
      visible = true;
      panelOffset = panelWidth;
      openTimer.restart();
    }
  }

  onOpenChanged: {
    if (open) {
      visible = true;
      panelOffset = panelWidth;
      openTimer.restart();
    } else if (visible) {
      panelOffset = panelWidth;
    }
  }

  Timer {
    id: openTimer
    interval: 1
    repeat: false
    onTriggered: root.panelOffset = 0
  }

  Item {
    anchors.fill: parent

    MouseArea {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.right: panelFrame.left
      onClicked: root.closeRequested()
    }

    Rectangle {
      id: panelFrame
      x: parent.width - width + root.panelOffset
      y: 0
      width: root.panelWidth
      height: parent.height
      color: Config.colors.base
      border.width: 0
      radius: 0

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: Config.colors.surface1
      }

      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => mouse.accepted = true
      }

      Behavior on x {
        NumberAnimation {
          duration: Config.durations.normal
          easing.type: Config.curves.standard
          onRunningChanged: {
            if (!running && !root.open && root.panelOffset >= root.panelWidth)
              root.visible = false;
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: Config.padding.large
        spacing: Config.spacing.normal

        Row {
          width: parent.width
          spacing: Config.spacing.small

          Text {
            width: parent.width - closeButton.width - parent.spacing
            text: root.title
            color: Config.colors.fg
            font.pixelSize: Config.sizes.large
            font.weight: Font.Medium
            elide: Text.ElideRight
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
          }

          Rectangle {
            id: closeButton
            width: 24
            height: 24
            radius: Config.radius.full
            color: closeArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1

            MaterialIcon {
              anchors.centerIn: parent
              code: 0xE4F6
              iconColor: closeArea.containsMouse ? Config.colors.base : Config.colors.primary
              iconSize: 12
            }

            MouseArea {
              id: closeArea
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.closeRequested()
            }
          }
        }

        Item {
          id: panelBody
          width: parent.width
          height: parent.height - y
        }
      }
    }
  }
}
