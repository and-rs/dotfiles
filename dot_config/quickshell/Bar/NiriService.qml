pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import Niri 0.1

Singleton {
  id: root

  property int _stableWorkspaceId: -1
  property var currentWorkspaceColumns: {
    let columns = {};
    let ordered = [];

    for (let win of currentWorkspaceWindows) {
      if (win.is_floating || !win.pos || win.pos.length < 2)
        continue;

      let columnIndex = win.pos[0];
      if (!columns[columnIndex])
        columns[columnIndex] = [];

      columns[columnIndex].push(win);
    }

    let keys = Object.keys(columns).map(Number).sort((a, b) => a - b);
    for (let key of keys) {
      let wins = columns[key].slice();
      wins.sort((a, b) => a.pos[1] - b.pos[1]);
      ordered.push(wins);
    }

    return ordered;
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
  property var focusedWindowLayoutData: {
    if (!instance.focusedWindow)
      return null;

    let focusedId = instance.focusedWindow.id;
    for (let win of windowLayoutData) {
      if (win.id === focusedId)
        return win;
    }

    return null;
  }
  property int focusedWorkspaceId: instance.focusedWindow ? instance.focusedWindow.workspaceId : _stableWorkspaceId
  property Niri instance: Niri {
    Component.onCompleted: connect()
    onErrorOccurred: error => console.error("Error:", error)
  }
  property bool overlayActive: currentWorkspaceWindows.length > 0 && !instance.focusedWindow
  property var windowLayoutData: []

  Connections {
    function onFocusedWindowChanged() {
      if (instance.focusedWindow)
        root._stableWorkspaceId = instance.focusedWindow.workspaceId;
    }

    target: instance
  }
  Process {
    id: initialFetch

    command: ["sh", "-c", "niri msg --json windows | jq -c '.[] | {id, workspace_id, pos: .layout.pos_in_scrolling_layout, tile_size: .layout.tile_size, window_size: .layout.window_size, window_offset: .layout.window_offset_in_tile, app_id, title, is_floating}'"]
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
              tile_size: w.layout ? w.layout.tile_size : null,
              window_size: w.layout ? w.layout.window_size : null,
              window_offset: w.layout ? w.layout.window_offset_in_tile : null,
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
          tile_size: w.layout ? w.layout.tile_size : null,
          window_size: w.layout ? w.layout.window_size : null,
          window_offset: w.layout ? w.layout.window_offset_in_tile : null,
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
            current[idx] = {
              id: w.id,
              workspace_id: w.workspace_id,
              app_id: w.app_id,
              title: w.title,
              is_floating: w.is_floating,
              pos: item[1].pos_in_scrolling_layout,
              tile_size: item[1].tile_size ? item[1].tile_size : w.tile_size,
              window_size: item[1].window_size ? item[1].window_size : w.window_size,
              window_offset: item[1].window_offset_in_tile ? item[1].window_offset_in_tile : w.window_offset
            };
            changed = true;
          }
        }
      }

      if (changed)
        root.windowLayoutData = current;
    }

    target: instance
  }
}
