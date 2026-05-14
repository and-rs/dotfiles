pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.UPower
import qs.Bar

Rectangle {
  id: root
  required property Item controller

  readonly property real horizontalPadding: controller.buttonHorizontalPadding
  readonly property var device: UPower.displayDevice
  readonly property bool hasBattery: {
    const devices = UPower.devices.values ?? [];
    for (let i = 0; i < devices.length; i++) {
      if (devices[i] && devices[i].isLaptopBattery)
        return true;
    }
    return false;
  }
  readonly property real percentage: device && device.ready ? device.percentage : 0
  readonly property real fillLevel: Math.max(0, Math.min(1, percentage))
  readonly property string label: Math.round(fillLevel * 100)
  readonly property bool charging: device && device.ready && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
  readonly property color fillColor: fillLevel < 0.2 ? Config.colors.destructive : charging ? Config.colors.success : Config.colors.success

  visible: hasBattery
  width: contentRow.implicitWidth + horizontalPadding * 2
  height: controller.window.implicitHeight
  color: "transparent"

  Row {
    id: contentRow
    spacing: Config.spacing.extraSmall
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    Item {
      width: charging ? 14 : 0
      anchors.verticalCenter: parent.verticalCenter
      height: 14

      MaterialIcon {
        anchors.centerIn: parent
        code: 0xE2DE
        iconSize: 14
        iconColor: Config.colors.success
        opacity: charging ? 1 : 0
      }
    }

    Row {
      spacing: 0
      padding: Config.padding.micro
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        id: batteryShell
        width: 30
        height: 16
        radius: Config.radius.small
        color: Config.colors.surface5
        anchors.verticalCenter: parent.verticalCenter

        Item {
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          width: parent.width * fillLevel
          clip: true

          Rectangle {
            width: batteryShell.width
            height: batteryShell.height
            radius: batteryShell.radius
            color: root.fillColor
          }
        }

        Text {
          width: batteryShell.width
          height: batteryShell.height
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          text: root.label
          font.weight: 900
          font.pointSize: 10
          color: Config.colors.base

          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Config.colors.fg
            shadowBlur: 0.9
            shadowOpacity: 0.8
          }
        }
      }

      Rectangle {
        width: 2.5
        height: 7.5
        color: fillLevel < 1 ? Config.colors.surface5 : root.fillColor
        topRightRadius: Config.radius.small
        bottomRightRadius: Config.radius.small
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.hasBattery
    onClicked: controller.switchMenu("battery")
  }
}
