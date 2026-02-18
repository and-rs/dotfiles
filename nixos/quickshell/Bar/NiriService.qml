pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Niri 0.1

Singleton {
  id: root

  property Niri instance: Niri {
    Component.onCompleted: connect()
    onConnected: console.log("Connected to niri")
    onErrorOccurred: error => console.error("Error:", error)
  }

  property var windowLayoutData: []

  Process {
    id: initialFetch
    command: ["sh", "-c", "niri msg --json windows | jq -c '.[] | {id, workspace_id, pos: .layout.pos_in_scrolling_layout}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        let lines = this.text.split('\n').filter(l => l.trim());
        let data = [];
        for (let line of lines) {
          try {
            data.push(JSON.parse(line));
          } catch (e) {}
        }
        root.windowLayoutData = data;
      }
    }
  }

  Connections {
    target: instance
    function onRawEventReceived(event) {
      if (!event)
        return;

      let current = root.windowLayoutData.slice();
      let changed = false;

      if (event.WindowOpenedOrChanged) {
        let w = event.WindowOpenedOrChanged.window;
        current = current.filter(x => x.id !== w.id);
        current.push({
          id: w.id,
          workspace_id: w.workspace_id,
          pos: w.layout.pos_in_scrolling_layout
        });
        changed = true;
      }

      if (event.WindowClosed) {
        let idToRemove = event.WindowClosed.id;
        let lenBefore = current.length;
        current = current.filter(x => x.id !== idToRemove);
        if (current.length !== lenBefore)
          changed = true;
      }

      if (event.WindowLayoutsChanged) {
        let changes = event.WindowLayoutsChanged.changes;
        for (let item of changes) {
          let id = item[0];
          let newLayout = item[1];
          let index = current.findIndex(x => x.id === id);
          if (index !== -1) {
            let entry = current[index];
            entry.pos = newLayout.pos_in_scrolling_layout;
            current[index] = entry;
            changed = true;
          }
        }
      }

      if (event.WindowFocusChanged) {
        changed = true;
      }

      if (changed) {
        root.windowLayoutData = current;
      }
    }
  }

  property int focusedWorkspaceId: instance.focusedWindow ? instance.focusedWindow.workspaceId : -1

  property var currentWorkspaceWindows: {
    let wsId = focusedWorkspaceId;
    let wins = windowLayoutData.filter(w => w.workspace_id === wsId);

    wins.sort((a, b) => {
      let posA = a.pos ? a.pos[0] : 0;
      let posB = b.pos ? b.pos[0] : 0;
      return posA - posB;
    });

    return wins;
  }

  property var focusedWindowPosition: {
    if (!instance.focusedWindow) {
      let currentWindows = currentWorkspaceWindows;
      if (currentWindows.length === 1) {
        return currentWindows[0].pos;
      }
      return null;
    }

    let currentId = instance.focusedWindow.id;
    let win = windowLayoutData.find(w => w.id === currentId);
    return win ? win.pos : null;
  }

  property int focusedWindowIndex: {
    if (!focusedWindowPosition)
      return -1;

    let currentWindows = currentWorkspaceWindows;
    for (let i = 0; i < currentWindows.length; i++) {
      if (currentWindows[i].pos && currentWindows[i].pos[0] === focusedWindowPosition[0] && currentWindows[i].pos[1] === focusedWindowPosition[1]) {
        return i;
      }
    }
    return -1;
  }
}
