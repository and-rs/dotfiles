pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower
import qs.Bar

Rectangle {
  id: root

  readonly property bool charging: device && device.ready && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
  required property Item controller
  readonly property var device: UPower.displayDevice
  readonly property color fillColor: fillLevel < 0.2 ? Config.colors.destructive : charging ? Config.colors.success : Config.colors.fg
  readonly property real fillLevel: Math.max(0, Math.min(1, percentage))
  readonly property bool hasBattery: {
    const devices = UPower.devices.values ?? [];
    for (let i = 0; i < devices.length; i++) {
      if (devices[i] && devices[i].isLaptopBattery)
        return true;
    }
    return false;
  }
  readonly property real horizontalPadding: controller.buttonHorizontalPadding
  readonly property string label: Math.round(fillLevel * 100)
  readonly property real percentage: device && device.ready ? device.percentage : 0

  color: "transparent"
  height: controller.window.implicitHeight
  visible: hasBattery
  width: contentRow.implicitWidth + horizontalPadding * 2

  Row {
    id: contentRow

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    spacing: Config.spacing.extraSmall

    Row {
      anchors.verticalCenter: parent.verticalCenter
      padding: Config.padding.micro
      spacing: 6

      Text {
        color: Config.colors.fg
        font.pointSize: 10
        font.weight: 600
        height: batteryShell.height
        horizontalAlignment: Text.AlignHCenter
        text: root.label
        verticalAlignment: Text.AlignVCenter
      }
      Row {
        Rectangle {
          id: batteryShell

          anchors.verticalCenter: parent.verticalCenter
          border.color: Config.colors.surface2
          border.width: 2
          color: Config.colors.surface2
          height: 15
          radius: Config.radius.small
          width: 28

          Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.top: parent.top
            clip: true
            width: parent.width * fillLevel

            Rectangle {
              border.color: Config.colors.surface2
              border.width: 2
              color: root.fillColor
              height: batteryShell.height
              radius: batteryShell.radius
              width: batteryShell.width
            }
          }
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          bottomRightRadius: Config.radius.small
          color: Config.colors.surface2
          height: (batteryShell.height - (batteryShell.border.width / 2)) / 2
          topRightRadius: Config.radius.small
          width: 2.5
        }
      }
      Item { // Icon
        anchors.verticalCenter: parent.verticalCenter
        height: 14
        width: charging ? 14 : 0

        MaterialIcon {
          anchors.centerIn: parent
          code: 0xE2DE
          iconColor: Config.colors.success
          iconSize: 14
          opacity: charging ? 1 : 0
        }
      }
    }
  }
  MouseArea {
    anchors.fill: parent
    enabled: root.hasBattery

    onClicked: controller.switchMenu("battery")
  }
}
