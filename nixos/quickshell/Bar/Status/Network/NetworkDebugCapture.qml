import Quickshell
import Quickshell.Io
import QtQuick

Item {
  id: root

  property int attempts: 0
  required property var controller
  required property Item menu
  property string outputDirectory: ""

  function capture(directory: string): void {
    if (!directory) {
      console.warn("[NetworkDebugCapture] A destination directory is required");
      return;
    }

    outputDirectory = directory;
    attempts = 0;
    if (controller.activeMenu !== "network")
      controller.switchMenu("network");
    captureTimer.restart();
  }
  function captureItem(item: Item, name: string): void {
    const text = item && item.text !== undefined ? String(item.text) : "";
    const bounds = item ? Math.round(item.x) + "," + Math.round(item.y) + " " + Math.round(item.width) + "x" + Math.round(item.height) : "missing";
    console.info("[NetworkDebugCapture] " + name + " text=" + JSON.stringify(text) + " bounds=" + bounds + " visible=" + (item && item.visible) + " opacity=" + (item && item.opacity));
    if (!item || item.width <= 0 || item.height <= 0) {
      console.warn("[NetworkDebugCapture] Skipped " + name + ": item is not renderable");
      return;
    }

    item.grabToImage(function (result) {
      if (!result.saveToFile(root.outputDirectory + "/" + name + ".png"))
        console.warn("[NetworkDebugCapture] Could not save " + name + ".png");
    });
  }
  function close(): void {
    controller.closeMenus();
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
      root.captureItem(root.menu, "menu");
      root.captureItem(root.menu.debugHeroTitle, "hero-title");
      root.captureItem(root.menu.debugHeroStatus, "hero-status");
      root.captureItem(root.menu.debugNetworkList, "network-list");
    }
  }
  IpcHandler {
    function capture(directory: string): void {
      root.capture(directory);
    }
    function close(): void {
      root.close();
    }

    target: "network-debug"
  }
}
