import Quickshell
import QtQuick

Row {
  id: root
  spacing: Config.spacing.small
  anchors.verticalCenter: parent.verticalCenter

  Repeater {
    model: NiriService.currentWorkspaceWindows.length

    delegate: Rectangle {
      width: 8
      height: 8
      radius: Config.radius.small
      anchors.verticalCenter: parent.verticalCenter

      color: {
        if (NiriService.currentWorkspaceWindows.length === 1) {
          return Config.colors.primary;
        }

        return index === NiriService.focusedWindowIndex ? Config.colors.primary : Config.colors.bright;
      }
    }
  }
}
