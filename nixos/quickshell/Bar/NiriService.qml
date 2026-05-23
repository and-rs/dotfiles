pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Niri 0.1

Singleton {
  id: root

  property Niri instance: Niri {
    Component.onCompleted: connect()
    onErrorOccurred: error => console.error("Error:", error)
  }

  property int _stableWorkspaceId: -1
  property int focusedWorkspaceId: instance.focusedWindow ? instance.focusedWindow.workspaceId : _stableWorkspaceId

  Connections {
    target: instance
    function onFocusedWindowChanged() {
      if (instance.focusedWindow)
        root._stableWorkspaceId = instance.focusedWindow.workspaceId;
    }
  }

  property var windowLayoutData: []

  Process {
    id: initialFetch
    command: ["sh", "-c", "niri msg --json windows | jq -c '.[] | {id, workspace_id, pos: .layout.pos_in_scrolling_layout, app_id, title, is_floating}'"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        let lines = this.text.split('\n').filter(l => l.trim());
        let data = [];
        for (let line of lines) {
          try { data.push(JSON.parse(line)); } catch (e) {}
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

      if (event.WindowsChanged) {
        current = event.WindowsChanged.windows.map(w => ({
          id: w.id,
          workspace_id: w.workspace_id,
          pos: w.layout ? w.layout.pos_in_scrolling_layout : null,
          app_id: w.app_id,
          title: w.title,
          is_floating: w.is_floating
        }));
        changed = true;
      }

      if (event.WindowOpenedOrChanged) {
        let w = event.WindowOpenedOrChanged.window;
        current = current.filter(x => x.id !== w.id);
        current.push({
          id: w.id,
          workspace_id: w.workspace_id,
          pos: w.layout ? w.layout.pos_in_scrolling_layout : null,
          app_id: w.app_id,
          title: w.title,
          is_floating: w.is_floating
        });
        changed = true;
      }

      if (event.WindowClosed) {
        let before = current.length;
        current = current.filter(x => x.id !== event.WindowClosed.id);
        if (current.length !== before)
          changed = true;
      }

      if (event.WindowLayoutsChanged) {
        for (let item of event.WindowLayoutsChanged.changes) {
          let idx = current.findIndex(x => x.id === item[0]);
          if (idx !== -1) {
            let w = current[idx];
            current[idx] = { id: w.id, workspace_id: w.workspace_id, app_id: w.app_id, title: w.title, is_floating: w.is_floating, pos: item[1].pos_in_scrolling_layout };
            changed = true;
          }
        }
      }

      if (changed)
        root.windowLayoutData = current;
    }
  }

  property var currentWorkspaceWindows: {
    let wsId = focusedWorkspaceId;
    if (wsId < 0)
      return [];
    let wins = windowLayoutData.filter(w => w.workspace_id === wsId);
    wins.sort((a, b) => (a.pos ? a.pos[0] : 0) - (b.pos ? b.pos[0] : 0));
    return wins;
  }

  property int focusedWindowIndex: {
    if (!instance.focusedWindow)
      return -1;
    let focusedId = instance.focusedWindow.id;
    let wins = currentWorkspaceWindows;
    for (let i = 0; i < wins.length; i++) {
      if (wins[i].id === focusedId)
        return i;
    }
    return -1;
  }

  property bool overlayActive: currentWorkspaceWindows.length > 0 && !instance.focusedWindow
}
