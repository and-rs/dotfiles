import QtQuick
import Quickshell
import QtQuick.Effects
import qs.Bar

Row {
  id: recordingRoot

  readonly property int iconCode: statusIcons[svc.status] || 0xE69C
  readonly property color stateColor: statusColors[svc.status] || Config.colors.fg
  readonly property var statusColors: ({
      [svc.statusSelect]: Config.colors.fg,
      [svc.statusRecording]: Config.colors.destructive,
      [svc.statusCompressPrompt]: Config.colors.secondary,
      [svc.statusSaving]: Config.colors.primary
    })
  readonly property var statusIcons: ({
      [svc.statusSelect]: 0xE69C,
      [svc.statusRecording]: 0xE3EE,
      [svc.statusCompressPrompt]: 0xEB2A,
      [svc.statusSaving]: 0xE6B6
    })
  readonly property string statusText: {
    switch (svc.status) {
    case svc.statusSelect:
      return "Select";
    case svc.statusRecording:
      {
        const m = Math.floor(svc.elapsedSeconds / 60).toString().padStart(2, "0");
        const s = (svc.elapsedSeconds % 60).toString().padStart(2, "0");
        return m + ":" + s;
      }
    case svc.statusCompressPrompt:
      return "Compress?";
    case svc.statusSaving:
      return "Saving...";
    default:
      return "";
    }
  }

  anchors.verticalCenter: parent.verticalCenter
  spacing: Config.spacing.small
  visible: svc.status !== svc.statusIdle

  RecordingService {
    id: svc
  }
  Item {
    id: iconContainer

    anchors.verticalCenter: parent.verticalCenter
    height: 20
    width: 16

    MaterialIcon {
      id: statusIcon

      anchors.centerIn: parent
      code: recordingRoot.iconCode
      iconColor: recordingRoot.stateColor
      iconSize: 14

      SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: svc.status === svc.statusRecording

        NumberAnimation {
          duration: Config.durations.normal
          to: 0.5
        }
        NumberAnimation {
          duration: Config.durations.normal
          to: 1.0
        }
      }
    }
  }
  Row {
    id: statusDisplay

    anchors.verticalCenter: parent.verticalCenter
    spacing: 0

    Rectangle {
      id: shell

      anchors.verticalCenter: parent.verticalCenter
      clip: true
      color: Config.colors.surface4
      height: 20
      radius: Config.radius.small
      width: label.paintedWidth + 16

      Behavior on width {
        NumberAnimation {
          duration: Config.durations.normal
          easing.type: Config.curve
        }
      }

      Rectangle {
        id: shellMask

        anchors.fill: parent
        antialiasing: true
        color: "white"
        radius: parent.radius
      }
      ShaderEffectSource {
        id: shellMaskSource

        hideSource: true
        live: true
        smooth: true
        sourceItem: shellMask
      }
      Rectangle {
        id: savingBackground

        anchors.fill: parent
        color: recordingRoot.stateColor
        opacity: 0.4
        radius: parent.radius
        visible: svc.status === svc.statusSaving
      }
      Item {
        id: shimmerLayer

        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        visible: svc.status === svc.statusSaving

        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: shellMaskSource
        }

        Rectangle {
          id: shimmerScan

          anchors.verticalCenter: parent.verticalCenter
          height: parent.height * 2
          rotation: 20
          width: 40

          gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
              color: "transparent"
              position: 0.0
            }
            GradientStop {
              color: Qt.rgba(1, 1, 1, 0.4)
              position: 0.5
            }
            GradientStop {
              color: "transparent"
              position: 1.0
            }
          }
          PropertyAnimation on x {
            duration: 1200
            from: -shimmerScan.width
            loops: Animation.Infinite
            running: svc.status === svc.statusSaving
            to: shell.width + shimmerScan.width
          }
        }
      }
      Text {
        id: label

        anchors.fill: parent
        color: Config.colors.base
        font.pointSize: 10
        font.weight: 700
        horizontalAlignment: Text.AlignHCenter
        text: recordingRoot.statusText
        verticalAlignment: Text.AlignVCenter
      }
      MouseArea {
        id: shellClickArea

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        anchors.fill: parent

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
