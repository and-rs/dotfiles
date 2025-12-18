pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.UPower

Row {
  id: root
  spacing: Config.spacing.small
  anchors.verticalCenter: parent.verticalCenter

  Repeater {
    model: UPower.devices
    delegate: Row {
      spacing: Config.spacing.small
      required property UPowerDevice modelData
      property real percentage: modelData.percentage
      visible: modelData.isLaptopBattery

      readonly property real p: Math.max(0, Math.min(1, percentage))
      readonly property string txt: Math.round(p * 100)

      Item {
        readonly property bool active: modelData.state === 1
        width: active ? 14 : 0
        height: 14
        anchors.verticalCenter: parent.verticalCenter
        clip: true

        Behavior on width {
          NumberAnimation {
            duration: Config.durations.normal
            easing.type: Easing.OutCubic
          }
        }

        MaterialIcon {
          anchors.centerIn: parent
          code: 0xea0b
          iconSize: 14
          color: Config.colors.success
          scale: parent.active ? 1 : 0
          opacity: parent.active ? 1 : 0

          Behavior on scale {
            NumberAnimation {
              duration: Config.durations.normal
              easing.type: Easing.OutBack
            }
          }

          Behavior on opacity {
            NumberAnimation {
              duration: Config.durations.normal
            }
          }
        }
      }

      Row {
        spacing: 0
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          id: batShell
          width: 30
          height: 16
          radius: Config.radius.small
          color: Config.colors.accent
          anchors.verticalCenter: parent.verticalCenter

          Item {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * p
            clip: true

            Rectangle {
              width: batShell.width
              height: batShell.height
              radius: batShell.radius
              color: p < 0.2 ? Config.colors.destructive : Config.colors.success
            }
          }

          Text {
            width: batShell.width
            height: batShell.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: txt
            font.weight: 900
            font.pointSize: 10
            color: Config.colors.bg
          }
        }

        Rectangle {
          width: 2.5
          height: 7.5
          color: p < 1 ? Config.colors.accent : Config.colors.success
          topRightRadius: Config.radius.small
          bottomRightRadius: Config.radius.small
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }
  }
}
