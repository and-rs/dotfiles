import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

Rectangle {
  id: bluetooth
  width: window.implicitHeight
  height: window.implicitHeight
  anchors.verticalCenter: parent.verticalCenter
  color: "transparent"

  required property PanelWindow window
  readonly property bool popupVisible: window.activePopup === "bluetooth"

  readonly property var adapter: {
    let adapters = Bluetooth.adapters.values ?? [];
    return adapters.length > 0 ? adapters[0] : null;
  }

  readonly property bool isEnabled: adapter && adapter.enabled
  readonly property bool hasConnectedDevice: {
    let devs = Bluetooth.devices.values ?? [];
    for (let i = 0; i < devs.length; i++) {
      if (devs[i] && devs[i].connected)
        return true;
    }
    return false;
  }

  readonly property int iconCode: {
    if (!isEnabled)
      return 0xE0DE;
    if (hasConnectedDevice)
      return 0xE0DC;
    return 0xE0DA;
  }

  readonly property color iconColor: {
    if (!isEnabled)
      return Config.colors.bright;
    if (hasConnectedDevice)
      return Config.colors.primary;
    return Config.colors.fg;
  }

  MaterialIcon {
    code: bluetooth.iconCode
    iconColor: bluetooth.iconColor
    iconSize: 16
  }

  MouseArea {
    anchors.fill: parent
    onClicked: window.switchPopup("bluetooth")
  }

  PopupPanel {
    anchor_item: bluetooth
    window: bluetooth.window
    popupVisible: bluetooth.popupVisible

      // Header
      Text {
        text: "Bluetooth"
        color: Config.colors.fg
        font.pointSize: 10
        font.weight: 700
      }

      // Separator
      Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.muted
      }

      // Power toggle
      Rectangle {
        width: parent.width
        height: 28
        radius: Config.radius.small
        color: btToggleHover.hovered ? Config.colors.muted : Config.colors.dim

        HoverHandler {
          id: btToggleHover
        }

        Text {
          text: "Power"
          color: Config.colors.fg
          font.pointSize: 9
          font.weight: 500
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Config.padding.small
        }

        Text {
          text: isEnabled ? "On" : "Off"
          color: isEnabled ? Config.colors.light_green : Config.colors.bright
          font.pointSize: 9
          font.weight: 500
          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.right
          anchors.rightMargin: Config.padding.small
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            btToggleProc.command = bluetooth.isEnabled
              ? ["sh", "-c", "bluetoothctl power off && rfkill block bluetooth"]
              : ["sh", "-c", "rfkill unblock bluetooth && bluetoothctl power on"];
            btToggleProc.running = true;
          }
        }
      }

      // Scan toggle
      Rectangle {
        width: parent.width
        height: 28
        radius: Config.radius.small
        color: btScanHover.hovered ? Config.colors.muted : Config.colors.dim
        visible: isEnabled

        HoverHandler {
          id: btScanHover
        }

        Text {
          text: "Scanning"
          color: Config.colors.fg
          font.pointSize: 9
          font.weight: 500
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Config.padding.small
        }

        Text {
          text: bluetooth.adapter && bluetooth.adapter.discovering ? "On" : "Off"
          color: bluetooth.adapter && bluetooth.adapter.discovering ? Config.colors.primary : Config.colors.bright
          font.pointSize: 9
          font.weight: 500
          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.right
          anchors.rightMargin: Config.padding.small
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (bluetooth.adapter)
              bluetooth.adapter.discovering = !bluetooth.adapter.discovering;
          }
        }
      }

      // Adapter info
      Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: bluetooth.adapter !== null && isEnabled

        Rectangle {
          width: parent.width
          height: 1
          color: Config.colors.muted
        }

        Row {
          spacing: Config.spacing.small
          Text {
            text: "Adapter"
            color: Config.colors.accent
            font.pointSize: 9
          }
          Text {
            text: bluetooth.adapter ? bluetooth.adapter.name : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }

        Row {
          spacing: Config.spacing.small
          Text {
            text: "State"
            color: Config.colors.accent
            font.pointSize: 9
          }
          Text {
            text: bluetooth.adapter ? BluetoothAdapterState.toString(bluetooth.adapter.state) : ""
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 600
          }
        }
      }

      // Connected devices
      Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.muted
        visible: isEnabled
      }

      Text {
        text: "Connected"
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 700
        visible: isEnabled && bluetooth.hasConnectedDevice
      }

      Flickable {
        width: parent.width
        height: Math.min(connectedCol.implicitHeight, 100)
        contentHeight: connectedCol.implicitHeight
        clip: true
        visible: isEnabled && bluetooth.hasConnectedDevice

        Column {
          id: connectedCol
          width: parent.width
          spacing: Config.spacing.extraSmall

          Repeater {
            model: Bluetooth.devices

            delegate: Rectangle {
              required property var modelData
              width: connectedCol.width
              height: modelData.connected ? 36 : 0
              radius: Config.radius.small
              color: Config.colors.muted
              visible: modelData.connected

              Text {
                text: modelData.name || "Unknown"
                color: Config.colors.primary
                font.pointSize: 9
                font.weight: 700
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Config.padding.small
              }

              Text {
                text: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "Connected"
                color: modelData.batteryAvailable ? (modelData.battery < 0.2 ? Config.colors.destructive : Config.colors.fg) : Config.colors.light_green
                font.pointSize: 8
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Config.padding.small
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.disconnect()
              }
            }
          }
        }
      }

      // Available devices
      Text {
        text: "Available"
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 700
        visible: isEnabled
      }

      Flickable {
        width: parent.width
        height: Math.min(availableCol.implicitHeight, 150)
        contentHeight: availableCol.implicitHeight
        clip: true
        visible: isEnabled

        Column {
          id: availableCol
          width: parent.width
          spacing: Config.spacing.extraSmall

          Repeater {
            model: Bluetooth.devices

            delegate: Rectangle {
              required property var modelData
              width: availableCol.width
              height: !modelData.connected ? 36 : 0
              radius: Config.radius.small
              color: Config.colors.dim
              visible: !modelData.connected

              Text {
                text: modelData.name || "Unknown"
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 500
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Config.padding.small
              }

              Text {
                text: modelData.paired ? "Paired" : "New"
                color: modelData.paired ? Config.colors.accent : Config.colors.bright
                font.pointSize: 8
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Config.padding.small
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelData.connect()
              }
            }
          }
        }
      }

      // Disabled state
      Text {
        visible: !isEnabled
        text: "Bluetooth is off"
        color: Config.colors.bright
        font.pointSize: 9
      }

      // No devices found
      Text {
        visible: isEnabled && (Bluetooth.devices.values ?? []).length === 0
        text: "No devices found"
        color: Config.colors.bright
        font.pointSize: 9
      }
  }

  Process {
    id: btToggleProc
    stdout: StdioCollector {
      onStreamFinished: console.log("[BT] bluetoothctl:", this.text.trim())
    }
  }
}
