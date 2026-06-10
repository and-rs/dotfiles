import QtQuick
import Quickshell.Services.UPower
import qs.Bar

Column {
    id: root
    width: parent ? parent.width : 0
    spacing: Config.spacing.small

    readonly property var device: UPower.displayDevice
    readonly property bool ready: device && device.ready
    readonly property bool hasBattery: {
        const devices = UPower.devices.values ?? [];
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].isLaptopBattery)
                return true;
        }
        return false;
    }
    readonly property real percentage: ready ? device.percentage : 0
    readonly property int percentInt: Math.round(Math.max(0, Math.min(1, percentage)) * 100)
    readonly property bool charging: ready && (device.state === UPowerDeviceState.Charging || device.state === UPowerDeviceState.PendingCharge)
    readonly property bool discharging: ready && (device.state === UPowerDeviceState.Discharging || device.state === UPowerDeviceState.PendingDischarge)
    readonly property real rateWatts: ready ? Math.abs(device.changeRate) : 0
    readonly property real energyNow: ready ? device.energy : 0
    readonly property real energyCapacity: ready ? device.energyCapacity : 0
    readonly property bool healthSupported: ready && device.healthSupported
    readonly property int healthPercent: healthSupported ? Math.round(device.healthPercentage * 100) : 0
    readonly property var activeHold: {
        const holds = PowerProfiles.holds ?? [];
        return holds.length > 0 ? holds[0] : null;
    }

    function formatDuration(seconds) {
        const total = Math.max(0, Math.round(seconds || 0));
        if (total <= 0)
            return "—";
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (hours <= 0)
            return `${minutes}m`;
        if (minutes <= 0)
            return `${hours}h`;
        return `${hours}h ${minutes}m`;
    }

    function profileLabel(profile) {
        if (profile === PowerProfile.PowerSaver)
            return "Saver";
        if (profile === PowerProfile.Balanced)
            return "Balanced";
        return "Performance";
    }

    function setProfile(profile) {
        if (profile === PowerProfile.Performance && !PowerProfiles.hasPerformanceProfile)
            return;
        PowerProfiles.profile = profile;
    }

    Text {
        text: "Battery"
        color: Config.colors.fg
        font.pointSize: 10
        font.weight: 700
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Config.colors.surface2
    }

    Text {
        visible: !root.hasBattery
        text: "No battery detected"
        color: Config.colors.surface3
        font.pointSize: 9
    }

    Text {
        visible: root.hasBattery && !root.ready
        text: "Loading…"
        color: Config.colors.surface3
        font.pointSize: 9
    }

    Column {
        width: parent.width
        spacing: Config.spacing.small
        visible: root.hasBattery && root.ready

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Charge"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.percentInt + "%"
                color: root.percentInt < 20 ? Config.colors.destructive : Config.colors.fg
                font.pointSize: 9
                font.weight: 700
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
                text: UPowerDeviceState.toString(device.state)
                color: root.charging ? Config.colors.primary : root.discharging ? Config.colors.fg : Config.colors.surface4
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small
            visible: root.charging || root.discharging

            Text {
                text: root.charging ? "Time to full" : "Time left"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.charging ? root.formatDuration(device.timeToFull) : root.formatDuration(device.timeToEmpty)
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small
            visible: root.rateWatts > 0

            Text {
                text: root.charging ? "Charging rate" : "Drain"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.rateWatts.toFixed(1) + " W"
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small

            Text {
                text: "Energy"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.energyNow.toFixed(1) + " / " + root.energyCapacity.toFixed(1) + " Wh"
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Row {
            spacing: Config.spacing.small
            visible: root.healthSupported

            Text {
                text: "Health"
                color: Config.colors.surface4
                font.pointSize: 9
            }

            Text {
                text: root.healthPercent + "%"
                color: Config.colors.fg
                font.pointSize: 9
                font.weight: 600
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Config.colors.surface2
        }

        Text {
            text: "Power Mode"
            color: Config.colors.fg
            font.pointSize: 9
            font.weight: 700
        }

        Column {
            width: parent.width
            spacing: Config.spacing.extraSmall

            Repeater {
                model: [
                    {
                        label: "Power Saver",
                        icon: 0xE32C,
                        value: PowerProfile.PowerSaver,
                        available: true
                    },
                    {
                        label: "Balanced",
                        icon: 0xE18A,
                        value: PowerProfile.Balanced,
                        available: true
                    },
                    {
                        label: "Performance",
                        icon: 0xE3D6,
                        value: PowerProfile.Performance,
                        available: PowerProfiles.hasPerformanceProfile
                    }
                ]

                delegate: Rectangle {
                    id: profileRow
                    required property var modelData

                    readonly property bool active: PowerProfiles.profile === profileRow.modelData.value
                    readonly property bool available: profileRow.modelData.available

                    width: parent.width
                    height: 32
                    radius: Config.radius.small
                    color: active ? Config.colors.primary : rowHover.hovered && available ? Config.colors.surface2 : Config.colors.surface1
                    opacity: available ? 1 : 0.4

                    HoverHandler {
                        id: rowHover
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Config.padding.small
                        anchors.rightMargin: Config.padding.small
                        spacing: Config.spacing.small

                        Text {
                            width: 16
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            font.family: "Phosphor-Bold"
                            text: String.fromCodePoint(profileRow.modelData.icon)
                            font.pointSize: 12
                            color: active ? Config.colors.base : Config.colors.fg
                        }

                        Text {
                            width: parent.width - 16 - Config.spacing.small
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            text: profileRow.modelData.label
                            color: active ? Config.colors.base : Config.colors.fg
                            font.pointSize: 9
                            font.weight: active ? 700 : 500
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: profileRow.available
                        cursorShape: profileRow.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.setProfile(profileRow.modelData.value)
                    }
                }
            }
        }

        Text {
            visible: root.activeHold !== null
            text: root.activeHold ? "Held by " + (root.activeHold.applicationId || "unknown") : ""
            color: Config.colors.surface4
            font.pointSize: 8
        }
    }
}
