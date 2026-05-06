import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  // Status constants
  readonly property int statusIdle: 0
  readonly property int statusSelect: 1
  readonly property int statusRecording: 2
  readonly property int statusCompressPrompt: 3
  readonly property int statusSaving: 4

  property int status: statusIdle
  property int elapsedSeconds: 0
  property string currentFile: ""
  readonly property string homeDir: Quickshell.env("HOME") ?? "/tmp"

  function getTimestamp() {
    const d = new Date();
    const pad = n => n.toString().padStart(2, '0');
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds());
  }

  function start() {
    if (status !== statusIdle)
      return;
    status = statusSelect;
    Quickshell.execDetached({
      command: ["sh", "-c", "rm -f /tmp/qs_geo; slurp -b 00000055 -c ff0000 > /tmp/qs_geo || true"]
    });
    slurpWatcher.running = true;
  }

  function stop() {
    if (status === statusRecording) {
      recProc.running = false;
      Quickshell.execDetached({
        command: ["pkill", "-INT", "-x", "wf-recorder"]
      });
    }
  }

  function compress() {
    if (status === statusCompressPrompt) {
      status = statusSaving;
      ffmpegProc.running = true;
    }
  }

  function dismiss() {
    status = statusIdle;
    elapsedSeconds = 0;
    slurpWatcher.running = false;
    readGeoProc.running = false;
    recProc.running = false;
    ffmpegProc.running = false;
  }

  function handlePrimaryAction() {
    if (status === statusIdle)
      start();
    else if (status === statusRecording)
      stop();
    else if (status === statusCompressPrompt)
      compress();
  }

  function handleSecondaryAction() {
    if (status === statusCompressPrompt)
      dismiss();
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.status === root.statusRecording
    onTriggered: root.elapsedSeconds++
  }

  IpcHandler {
    target: "recorder"
    function toggle() {
      if (root.status === root.statusRecording) {
        root.stop();
      } else {
        if (root.status !== root.statusIdle)
          root.dismiss();
        root.start();
      }
    }
  }

  Process {
    id: slurpWatcher
    command: ["sh", "-c", "while pgrep -x slurp > /dev/null; do sleep 0.1; done; sleep 0.2"]
    onExited: readGeoProc.running = true
  }

  Process {
    id: readGeoProc
    command: ["cat", "/tmp/qs_geo"]
    stdout: StdioCollector {
      onStreamFinished: {
        const geo = this.text.trim();
        if (geo && geo.length > 0) {
          root.currentFile = root.homeDir + "/recording_" + root.getTimestamp() + ".mp4";
          recProc.command = ["wf-recorder", "-y", "-g", geo, "-c", "libx264rgb", "-p", "crf=18", "-p", "preset=veryfast", "--file=" + root.currentFile];
          root.status = root.statusRecording;
          root.elapsedSeconds = 0;
          recProc.running = true;
        } else {
          root.status = root.statusIdle;
        }
      }
    }
  }

  Process {
    id: recProc
    onExited: code => {
      if (root.status === root.statusRecording) {
        root.status = (code === 0 || code === 255 || code === 2 || code === -15) ? root.statusCompressPrompt : root.statusIdle;
      }
    }
    stderr: StdioCollector {
      onStreamFinished: console.log("[REC] wf-recorder log:", this.text)
    }
  }

  Process {
    id: ffmpegProc
    command: ["ffmpeg", "-y", "-i", root.currentFile, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "22", "-preset", "fast", root.currentFile.slice(0, -4) + "_web.mp4"]
    onExited: code => {
      root.status = root.statusIdle;
      root.elapsedSeconds = 0;
    }
    stderr: StdioCollector {
      onStreamFinished: console.log("[REC] ffmpeg log:", this.text)
    }
  }
}
