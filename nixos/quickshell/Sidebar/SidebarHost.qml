import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Bar

PanelWindow {
  id: root

  readonly property real closedPanelX: screen.width
  default property alias content: panelBody.data
  required property bool open
  readonly property real openPanelX: screen.width - panelWidth
  property int panelWidth: Config.sidebar.width
  property string title: ""
  required property PanelWindow window

  signal closeRequested

  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.layer: WlrLayer.Overlay
  color: "transparent"
  exclusiveZone: -1
  screen: window.screen
  visible: false

  Component.onCompleted: {
    if (open)
      visible = true;
  }
  onOpenChanged: {
    if (open)
      visible = true;
  }

  anchors {
    bottom: true
    left: true
    right: true
    top: true
  }
  margins {
    bottom: 0
    left: 0
    right: 0
    top: root.window.height
  }
  Item {
    anchors.fill: parent

    MouseArea {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: panelFrame.left
      anchors.top: parent.top

      onClicked: root.closeRequested()
    }
    Rectangle {
      id: panelFrame

      border.width: 0
      color: Config.colors.base
      height: parent.height
      opacity: root.open ? 1 : 0
      radius: 0
      width: root.panelWidth
      x: root.open ? root.openPanelX : root.closedPanelX
      y: 0

      Behavior on opacity {
        NumberAnimation {
          duration: Config.durations.normal
          easing.type: Config.curve
        }
      }
      Behavior on x {
        NumberAnimation {
          duration: Config.durations.normal
          easing.type: Config.curve

          onRunningChanged: {
            if (!running && !root.open)
              root.visible = false;
          }
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        color: Config.colors.primary
        width: 2
      }
      MouseArea {
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        anchors.fill: parent
        propagateComposedEvents: true
        z: -1
      }
      Column {
        anchors.fill: parent
        anchors.margins: Config.padding.large
        spacing: Config.spacing.normal

        Row {
          spacing: Config.spacing.small
          width: parent.width

          Text {
            color: Config.colors.fg
            elide: Text.ElideRight
            font.pixelSize: Config.sizes.large
            font.weight: Font.Medium
            text: root.title
            textFormat: Text.PlainText
            verticalAlignment: Text.AlignVCenter
            width: parent.width - closeButton.width - parent.spacing
          }
          Rectangle {
            id: closeButton

            color: closeArea.containsMouse ? Config.colors.surface3 : Config.colors.surface1
            height: 24
            radius: Config.radius.full
            width: 24

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

          height: parent.height - y
          width: parent.width
        }
      }
    }
  }
}
