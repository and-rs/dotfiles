import QtQuick
import Quickshell
import Quickshell.Io

Scope {
  id: root

  property int status: 0
  property int elapsedSeconds: 0
  property string currentFile: ""
  readonly property string homeDir: Quickshell.env("HOME") ?? "/tmp"

  function getTimestamp() {
    const d = new Date();
    const pad = n => n.toString().padStart(2, '0');
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + "_" + pad(d.getHours()) + "-" + pad(d.getMinutes()) + "-" + pad(d.getSeconds());
  }

  function start() {
    if (status !== 0)
      return;
    status = 1;
    Quickshell.execDetached({
      command: ["sh", "-c", "rm -f /tmp/qs_geo; slurp -b 00000055 -c ff0000 > /tmp/qs_geo || true"]
    });
    slurpWatcher.running = true;
  }

  function stop() {
    if (status === 2) {
      recProc.running = false;
      Quickshell.execDetached({
        command: ["pkill", "-INT", "-x", "wf-recorder"]
      });
    }
  }

  function compress() {
    if (status === 3) {
      status = 4;
      ffmpegProc.running = true;
    }
  }

  function dismiss() {
    status = 0;
    elapsedSeconds = 0;
    slurpWatcher.running = false;
    readGeoProc.running = false;
    recProc.running = false;
    ffmpegProc.running = false;
  }

  function handlePrimaryAction() {
    if (status === 0)
      start();
    else if (status === 2)
      stop();
    else if (status === 3)
      compress();
  }

  function handleSecondaryAction() {
    if (status === 3)
      dismiss();
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.status === 2
    onTriggered: root.elapsedSeconds++
  }

  IpcHandler {
    target: "recorder"
    function toggle() {
      if (root.status === 2) {
        root.stop();
      } else {
        if (root.status !== 0)
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
          root.status = 2;
          root.elapsedSeconds = 0;
          recProc.running = true;
        } else {
          root.status = 0;
        }
      }
    }
  }

  Process {
    id: recProc
    onExited: code => {
      if (root.status === 2) {
        root.status = (code === 0 || code === 255 || code === 2 || code === -15) ? 3 : 0;
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
      root.status = 0;
      root.elapsedSeconds = 0;
    }
    stderr: StdioCollector {
      onStreamFinished: console.log("[REC] ffmpeg log:", this.text)
    }
  }
}
