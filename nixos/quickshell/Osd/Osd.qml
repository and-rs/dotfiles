import Quickshell.Wayland
import Quickshell.Io
import Quickshell
import QtQuick
import qs.Bar

Scope {
  id: osdScope

  property int currentValue: 0
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
  property bool isMuted: false
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
  readonly property int maxLimit: mode === "mic" ? 140 : 100
  property string mode: "volume" // "volume" | "mic" | "brightness" | "kbd"
  property bool visible: false

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
    function adjustBrightness(step: string): void {
      osdScope.mode = "brightness";
      osdExec.command = ["sh", "-c", "brightnessctl set " + step + " -q && brightnessctl -m | awk -F, '{printf \"%d\\n\", int($3/$5*100+0.5)}'"];
      osdExec.running = true;
    }
    function adjustKbdBrightness(step: string): void {
      osdScope.mode = "kbd";
      osdExec.command = ["sh", "-c", "brightnessctl -d asus::kbd_backlight set " + step + " -q && brightnessctl -d asus::kbd_backlight -m | awk -F, '{printf \"%d\\n\", int($3/$5*100+0.5)}'"];
      osdExec.running = true;
    }
    function adjustMic(step: string): void {
      osdScope.mode = "mic";
      osdExec.command = ["sh", "-c", "wpctl set-volume @DEFAULT_SOURCE@ " + step + " -l 1.4 && wpctl get-volume @DEFAULT_SOURCE@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }
    function adjustVolume(step: string): void {
      osdScope.mode = "volume";
      osdExec.command = ["sh", "-c", "wpctl set-volume @DEFAULT_SINK@ " + step + " -l 1.0 && wpctl get-volume @DEFAULT_SINK@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }
    function toggleMicMute(): void {
      osdScope.mode = "mic";
      osdExec.command = ["sh", "-c", "wpctl set-mute @DEFAULT_SOURCE@ toggle && wpctl get-volume @DEFAULT_SOURCE@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }
    function toggleMute(): void {
      osdScope.mode = "volume";
      osdExec.command = ["sh", "-c", "wpctl set-mute @DEFAULT_SINK@ toggle && wpctl get-volume @DEFAULT_SINK@ | awk '{print $2 * 100, $3}'"];
      osdExec.running = true;
    }

    target: "osd"
  }
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: osdWindow

      required property var modelData

      color: "transparent"
      exclusiveZone: -1
      screen: modelData
      visible: osdScope.visible

      mask: Region {
        Region {
          height: 80
          width: 300
          x: (osdWindow.width - 300) / 2
          y: (osdWindow.height - 80) / 2
        }
      }

      Component.onCompleted: {
        if (WlrLayershell != null) {
          WlrLayershell.namespace = "quickshell-osd";
          WlrLayershell.layer = WlrLayer.Overlay;
        }
      }

      anchors {
        bottom: true
        left: true
        right: true
        top: true
      }
      Rectangle {
        anchors.centerIn: parent
        border.color: Config.colors.surface4
        border.width: 2
        color: Config.colors.surface1
        height: 80
        radius: Config.radius.normal
        width: 300

        Column {
          anchors.centerIn: parent
          spacing: Config.spacing.small
          width: 260

          Row {
            spacing: Config.spacing.small
            width: parent.width

            Rectangle {
              color: "transparent"
              height: osdIcon.height
              width: osdIcon.width

              MaterialIcon {
                id: osdIcon

                code: osdScope.iconCode
                color: osdScope.isMuted ? Config.colors.surface2 : Config.colors.fg
              }
            }
            Text {
              color: osdScope.isMuted ? Config.colors.surface2 : Config.colors.fg
              font.pixelSize: Config.sizes.normal
              font.weight: Font.Medium
              text: osdScope.label + ": " + (osdScope.isMuted ? "Muted" : osdScope.currentValue + "%")
            }
          }
          Rectangle {
            color: Config.colors.base
            height: Config.spacing.small
            radius: Config.radius.full
            width: parent.width

            Rectangle {
              color: osdScope.isMuted ? Config.colors.surface2 : Config.colors.primary
              height: parent.height
              radius: Config.radius.full
              // Fix: Divide by dynamic maxLimit (100 or 140)
              width: parent.width * Math.min(osdScope.currentValue / osdScope.maxLimit, 1)

              Behavior on color {
                ColorAnimation {
                  duration: Config.durations.extraFast
                }
              }
              Behavior on width {
                NumberAnimation {
                  duration: Config.durations.extraFast
                  easing.type: Config.curve
                }
              }
            }
          }
        }
      }
    }
  }
}
