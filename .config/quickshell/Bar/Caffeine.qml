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
    code: isActive ? 0xe8f4 : 0xe8f5
    iconColor: isActive ? Config.colors.fg : Config.colors.bright
  }

  MouseArea {
    anchors.fill: caffeine
    onClicked: {
      caffeine.isActive = !isActive;
    }
  }

  Process {
    id: cmd
    running: caffeine.isActive
    command: ["sh", "-c", "systemd-inhibit --what=idle:sleep --why=no-sleep sleep infinity"]
    stdout: StdioCollector {
      onStreamFinished: console.log(">>> Not inhibiting anymore")
    }
  }
}
