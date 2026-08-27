import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property var activeTarget: null
  property int attempts: 0
  property string outputDirectory: ""
  required property var targets

  function capture(name: string, directory: string): void {
    const target = targetFor(name);
    if (!target) {
      console.warn("[DebugCapture] Unknown target: " + name);
      return;
    }
    if (!directory) {
      console.warn("[DebugCapture] A destination directory is required");
      return;
    }

    activeTarget = target;
    outputDirectory = directory;
    attempts = 0;
    target.open();
    captureTimer.restart();
  }
  function captureItem(item: Item, name: string): void {
    const text = item && item.text !== undefined ? String(item.text) : "";
    const bounds = item ? Math.round(item.x) + "," + Math.round(item.y) + " " + Math.round(item.width) + "x" + Math.round(item.height) : "missing";
    console.info("[DebugCapture] " + name + " text=" + JSON.stringify(text) + " bounds=" + bounds + " visible=" + (item && item.visible) + " opacity=" + (item && item.opacity));
    if (!item || item.width <= 0 || item.height <= 0) {
      console.warn("[DebugCapture] Skipped " + name + ": item is not renderable");
      return;
    }

    item.grabToImage(function (result) {
      if (!result.saveToFile(root.outputDirectory + "/" + name + ".png"))
        console.warn("[DebugCapture] Could not save " + name + ".png");
    });
  }
  function close(): void {
    if (activeTarget)
      activeTarget.close();
    activeTarget = null;
  }
  function targetFor(name: string): var {
    for (let index = 0; index < targets.length; index++) {
      if (targets[index].name === name)
        return targets[index];
    }
    return null;
  }

  Timer {
    id: captureTimer

    interval: 100
    repeat: true
    running: false

    onTriggered: {
      root.attempts++;
      if (root.attempts < 5)
        return;

      stop();
      root.captureItem(root.activeTarget.item, root.activeTarget.name);
      for (let index = 0; index < root.activeTarget.items.length; index++) {
        const item = root.activeTarget.items[index];
        root.captureItem(item.item, item.name);
      }
    }
  }
  IpcHandler {
    function capture(name: string, directory: string): void {
      root.capture(name, directory);
    }
    function close(): void {
      root.close();
    }

    target: "debug"
  }
}
