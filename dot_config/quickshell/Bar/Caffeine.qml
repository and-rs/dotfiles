import Quickshell
import Quickshell.Io
import QtQuick

Rectangle {
  id: caffeine

  property bool isActive: false
  required property PanelWindow window

  anchors.verticalCenter: parent.verticalCenter
  color: "transparent"
  height: window.implicitHeight
  width: window.implicitHeight

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

    command: ["systemd-inhibit", "--what=idle:sleep", "--why=Caffeine", "sleep", "infinity"]
    running: caffeine.isActive

    stderr: StdioCollector {
      onStreamFinished: {
        if (this.text.trim())
          console.warn("[Caffeine] stderr: " + this.text.trim());
      }
    }

    onExited: (code, status) => {
      if (caffeine.isActive && code !== 0)
        caffeine.isActive = false;
    }
  }
}
