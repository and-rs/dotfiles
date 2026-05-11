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

  visible: svc.status !== svc.statusIdle

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

  readonly property color stateColor: statusColors[svc.status] || Config.colors.fg
  readonly property int iconCode: statusIcons[svc.status] || 0xE69C

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
        running: svc.status === svc.statusRecording
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
      color: Config.colors.surface4
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
        visible: svc.status === svc.statusSaving
        anchors.fill: parent
        radius: parent.radius
        color: recordingRoot.stateColor
        opacity: 0.4
      }

      Item {
        id: shimmerLayer
        visible: svc.status === svc.statusSaving
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
            running: svc.status === svc.statusSaving
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
        font.weight: 700
        font.pointSize: 10
        color: Config.colors.base
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
