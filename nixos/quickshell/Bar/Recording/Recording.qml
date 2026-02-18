import QtQuick
import Quickshell
import QtQuick.Effects
import qs.Bar

Row {
  id: recordingRoot
  spacing: Config.spacing.small
  anchors.verticalCenter: parent.verticalCenter

  RecordingService {
    id: svc
  }

  visible: svc.status !== 0

  readonly property int status_select: 1
  readonly property int status_recording: 2
  readonly property int status_compress_prompt: 3
  readonly property int status_saving: 4

  readonly property var statusColors: ({
      [status_select]: Config.colors.fg,
      [status_recording]: Config.colors.light_red,
      [status_compress_prompt]: Config.colors.secondary,
      [status_saving]: Config.colors.primary
    })

  readonly property var statusIcons: ({
      [status_select]: 0xE69C,
      [status_recording]: 0xE3EE,
      [status_compress_prompt]: 0xEB2A,
      [status_saving]: 0xE6B6
    })

  readonly property color stateColor: statusColors[svc.status] || Config.colors.fg
  readonly property int iconCode: statusIcons[svc.status] || 0xE69C

  readonly property string statusText: {
    switch (svc.status) {
    case status_select:
      return "Select";
    case status_recording:
      {
        const m = Math.floor(svc.elapsedSeconds / 60).toString().padStart(2, "0");
        const s = (svc.elapsedSeconds % 60).toString().padStart(2, "0");
        return m + ":" + s;
      }
    case status_compress_prompt:
      return "Compress?";
    case status_saving:
      return "Saving...";
    default:
      return "";
    }
  }

  Item {
    id: iconContainer
    width: 16
    height: 20
    anchors.verticalCenter: parent.verticalCenter

    MaterialIcon {
      id: statusIcon
      anchors.centerIn: parent
      code: recordingRoot.iconCode
      iconSize: 14
      iconColor: recordingRoot.stateColor

      SequentialAnimation on opacity {
        running: svc.status === status_recording
        loops: Animation.Infinite
        NumberAnimation {
          to: 0.5
          duration: Config.durations.normal
        }
        NumberAnimation {
          to: 1.0
          duration: Config.durations.normal
        }
      }
    }
  }

  Row {
    id: statusDisplay
    spacing: 0
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
      id: shell
      width: label.paintedWidth + 16
      height: 20
      radius: Config.radius.small
      color: Config.colors.accent
      anchors.verticalCenter: parent.verticalCenter
      clip: true

      Behavior on width {
        NumberAnimation {
          duration: Config.durations.normal
          easing.type: Config.curves.standard
        }
      }

      Rectangle {
        id: shellMask
        anchors.fill: parent
        radius: parent.radius
        color: "white"
        antialiasing: true
      }

      ShaderEffectSource {
        id: shellMaskSource
        sourceItem: shellMask
        hideSource: true
        live: true
        smooth: true
      }

      Rectangle {
        id: savingBackground
        visible: svc.status === status_saving
        anchors.fill: parent
        radius: parent.radius
        color: recordingRoot.stateColor
        opacity: 0.4
      }

      Item {
        id: shimmerLayer
        visible: svc.status === status_saving
        anchors.fill: parent

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: shellMaskSource
        }

        Rectangle {
          id: shimmerScan
          width: 40
          height: parent.height * 2
          rotation: 20
          anchors.verticalCenter: parent.verticalCenter

          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
              position: 0.0
              color: "transparent"
            }
            GradientStop {
              position: 0.5
              color: Qt.rgba(1, 1, 1, 0.4)
            }
            GradientStop {
              position: 1.0
              color: "transparent"
            }
          }

          PropertyAnimation on x {
            running: svc.status === status_saving
            loops: Animation.Infinite
            from: -shimmerScan.width
            to: shell.width + shimmerScan.width
            duration: 1200
          }
        }
      }

      Text {
        id: label
        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: recordingRoot.statusText
        font.weight: 800
        font.pointSize: 10
        color: Config.colors.bg
      }

      MouseArea {
        id: shellClickArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
          if (mouse.button === Qt.RightButton) {
            svc.handleSecondaryAction();
          } else {
            svc.handlePrimaryAction();
          }
        }
      }
    }
  }
}
