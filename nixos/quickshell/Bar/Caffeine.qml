import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
    id: caffeine
    width: window.implicitHeight
    height: window.implicitHeight
    anchors.verticalCenter: parent.verticalCenter
    color: "transparent"

    required property PanelWindow window
    property bool isActive: false

    MaterialIcon {
        id: caffeineIcon
        code: isActive ? 0xE220 : 0xE224
        iconColor: isActive ? Config.colors.fg : Config.colors.surface3
        iconSize: 16
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            caffeine.isActive = !isActive;
        }
    }

    Process {
        id: cmd
        running: caffeine.isActive
        command: ["systemd-inhibit", "--what=idle:sleep", "--why=Caffeine", "sleep", "infinity"]

        onExited: (code, status) => {
            if (caffeine.isActive && code !== 0)
                caffeine.isActive = false;
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim())
                    console.warn("[Caffeine] stderr: " + this.text.trim());
            }
        }
    }
}
