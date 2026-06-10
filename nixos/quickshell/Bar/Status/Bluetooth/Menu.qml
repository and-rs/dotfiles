import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Bar

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: Config.spacing.small

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

    Text {
        text: "Bluetooth"
        color: Config.colors.fg
        font.pointSize: 10
        font.weight: 700
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.surface2
    }

    Rectangle {
        width: parent.width
        height: 28
        radius: Config.radius.small
        color: btToggleHover.hovered ? Config.colors.surface2 : Config.colors.surface1

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
            text: root.isEnabled ? "On" : "Off"
            color: root.isEnabled ? Config.colors.success : Config.colors.surface3
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
                btToggleProc.command = root.isEnabled ? ["sh", "-c", "bluetoothctl power off && rfkill block bluetooth"] : ["sh", "-c", "rfkill unblock bluetooth && bluetoothctl power on"];
                btToggleProc.running = true;
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 28
        radius: Config.radius.small
        color: btScanHover.hovered ? Config.colors.surface2 : Config.colors.surface1
        visible: root.isEnabled

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
            text: root.adapter && root.adapter.discovering ? "On" : "Off"
            color: root.adapter && root.adapter.discovering ? Config.colors.primary : Config.colors.surface3
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
                if (root.adapter)
                    root.adapter.discovering = !root.adapter.discovering;
            }
        }
    }

    Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: root.adapter !== null && root.isEnabled

        Rectangle {
            width: parent.width
            height: 1
            color: Config.colors.surface2
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Adapter"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.adapter ? root.adapter.name : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "State"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.adapter ? BluetoothAdapterState.toString(root.adapter.state) : ""
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.surface2
        visible: root.isEnabled
    }

    Text {
        text: "Connected"
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 700
        visible: root.isEnabled && root.hasConnectedDevice
    }

    Flickable {
        width: parent.width
        height: Math.min(connectedCol.implicitHeight, 100)
        contentHeight: connectedCol.implicitHeight
        clip: true
        visible: root.isEnabled && root.hasConnectedDevice

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
                    color: Config.colors.surface2
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
                        color: modelData.batteryAvailable ? (modelData.battery < 0.2 ? Config.colors.destructive : Config.colors.fg) : Config.colors.success
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

    Text {
        text: "Available"
        color: Config.colors.fg
        font.pointSize: 9
        font.weight: 700
        visible: root.isEnabled
    }

    Flickable {
        width: parent.width
        height: Math.min(availableCol.implicitHeight, 150)
        contentHeight: availableCol.implicitHeight
        clip: true
        visible: root.isEnabled

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
                    color: Config.colors.surface1
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
                        color: modelData.paired ? Config.colors.surface4 : Config.colors.surface3
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

    Text {
        visible: !root.isEnabled
        text: "Bluetooth is off"
        color: Config.colors.surface3
        font.pointSize: 9
    }

    Text {
        visible: root.isEnabled && (Bluetooth.devices.values ?? []).length === 0
        text: "No devices found"
        color: Config.colors.surface3
        font.pointSize: 9
    }

    Process {
        id: btToggleProc
        stdout: StdioCollector {}
    }
}
