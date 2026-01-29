import Quickshell
import Quickshell.Io
import QtQuick
import qs.Bar

Scope {
  id: osdScope

  property string mode: "volume" // "volume" | "mic" | "brightness" | "kbd"
  property int currentValue: 0
  property bool isMuted: false
  property bool visible: false

  readonly property int maxLimit: mode === "mic" ? 140 : 100

  readonly property string label: {
    switch (mode) {
    case "volume":
      return "Volume";
    case "mic":
      return "Microphone";
    case "kbd":
      return "Keyboard";
    default:
      return "Brightness";
    }
  }

  readonly property int iconCode: {
    // Volume Logic
    if (mode === "volume") {
      if (isMuted)
        return 0xE456;
      if (currentValue < 33)
        return 0xE454;
      if (currentValue < 66)
        return 0xE452;
      return 0xE450;
    }

    // Mic Logic
    if (mode === "mic") {
      return isMuted ? 0xE328 : 0xE326;
    }

    // Brightness/Kbd Logic (Shared)
    const thresholds = [
      {
        limit: 25,
        icon: 0xE330
      },
      {
        limit: 50,
        icon: 0xE58E
      },
      {
        limit: 75,
        icon: 0xE474
      },
    ];
    const match = thresholds.find(t => currentValue < t.limit);
    return match ? match.icon : 0xE472;
  }

  Timer {
    id: hideTimer
    interval: Config.durations.slow
    onTriggered: osdScope.visible = false
  }

  Process {
    id: osdExec
    command: []
    stdout: StdioCollector {
      onStreamFinished: {
        const parts = this.text.trim().split(" ");
        osdScope.currentValue = Math.round(parseFloat(parts[0]));
        osdScope.isMuted = parts.length > 1 && (parts[1] === "[MUTED]" || parts[1] === "[OFF]");
        osdScope.visible = true;
        hideTimer.restart();
      }
    }
  }

  IpcHandler {
    target: "osd"

    function adjustVolume(step: string): void {
      osdScope.mode = "volume";
      osdExec.command = ["sh", "-c", "wpctl set-volume @DEFAULT_SINK@ " + step + " -l 1.0 && wpctl get-volume @DEFAULT_SINK@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }

    function toggleMute(): void {
      osdScope.mode = "volume";
      osdExec.command = ["sh", "-c", "wpctl set-mute @DEFAULT_SINK@ toggle && wpctl get-volume @DEFAULT_SINK@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }

    function adjustMic(step: string): void {
      osdScope.mode = "mic";
      osdExec.command = ["sh", "-c", "wpctl set-volume @DEFAULT_SOURCE@ " + step + " -l 1.4 && wpctl get-volume @DEFAULT_SOURCE@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }

    function toggleMicMute(): void {
      osdScope.mode = "mic";
      osdExec.command = ["sh", "-c", "wpctl set-mute @DEFAULT_SOURCE@ toggle && wpctl get-volume @DEFAULT_SOURCE@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }

    function adjustBrightness(step: string): void {
      osdScope.mode = "brightness";
      osdExec.command = ["sh", "-c", "brightnessctl set " + step + " -q && brightnessctl -m | awk -F, '{print substr($4, 1, length($4)-1)}'"];
      osdExec.running = true;
    }

    function adjustKbdBrightness(step: string): void {
      osdScope.mode = "kbd";
      osdExec.command = ["sh", "-c", "brightnessctl -d asus::kbd_backlight set " + step + " -q && brightnessctl -d asus::kbd_backlight -m | awk -F, '{print substr($4, 1, length($4)-1)}'"];
      osdExec.running = true;
    }
  }

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: osdWindow
      required property var modelData
      screen: modelData
      color: "transparent"
      exclusiveZone: -1
      visible: osdScope.visible
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      mask: Region {
        Region {
          x: (osdWindow.width - 300) / 2
          y: (osdWindow.height - 80) / 2
          width: 300
          height: 80
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: 300
        height: 80
        color: Config.colors.dim
        radius: Config.radius.normal
        border.color: Config.colors.accent
        border.width: 2

        Column {
          anchors.centerIn: parent
          spacing: Config.spacing.small
          width: 260

          Row {
            spacing: Config.spacing.small
            width: parent.width

            Rectangle {
              width: osdIcon.width
              height: osdIcon.height
              color: "transparent"
              MaterialIcon {
                id: osdIcon
                code: osdScope.iconCode
                color: osdScope.isMuted ? Config.colors.muted : Config.colors.fg
              }
            }

            Text {
              text: osdScope.label + ": " + (osdScope.isMuted ? "Muted" : osdScope.currentValue + "%")
              color: osdScope.isMuted ? Config.colors.muted : Config.colors.fg
              font.pixelSize: Config.sizes.normal
              font.weight: Font.Medium
            }
          }

          Rectangle {
            width: parent.width
            height: Config.spacing.small
            color: Config.colors.bg
            radius: Config.radius.full

            Rectangle {
              height: parent.height
              // Fix: Divide by dynamic maxLimit (100 or 140)
              width: parent.width * Math.min(osdScope.currentValue / osdScope.maxLimit, 1)
              color: osdScope.isMuted ? Config.colors.muted : Config.colors.primary
              radius: Config.radius.full

              Behavior on width {
                NumberAnimation {
                  duration: Config.durations.extraFast
                  easing.type: Easing.OutCubic
                }
              }
              Behavior on color {
                ColorAnimation {
                  duration: Config.durations.extraFast
                }
              }
            }
          }
        }
      }
    }
  }
}
