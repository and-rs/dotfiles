import Quickshell
import QtQuick

Row {
    spacing: Config.spacing.extraSmall - 2
    anchors.verticalCenter: parent.verticalCenter

    // Incremented on windows model changes to trigger binding re-evaluation
    property int windowsRevision: 0

  Connections {
    target: NiriService.instance.windows
    function onDataChanged() {
      windowsRevision++;
    }
    function onRowsInserted() {
      windowsRevision++;
    }
    function onRowsRemoved() {
      windowsRevision++;
    }
    function onModelReset() {
      windowsRevision++;
    }
  }

  function isWorkspaceEmpty(workspaceId: int): bool {
    for (let i = 0; i < NiriService.instance.windows.count; i++) {
      let item = NiriService.instance.windows.data(NiriService.instance.windows.index(i, 0), Qt.UserRole + 5);
      if (item === workspaceId) {
        return false;
      }
    }

  Repeater {
    id: repeater
    model: NiriService.instance.workspaces

    delegate: Rectangle {
      id: rect

      // Reference windowsRevision to re-evaluate when windows change
      readonly property bool empty: {
        windowsRevision;
        return isWorkspaceEmpty(model.id);
      }

      gradient: model.isFocused && !empty ? grad : null
      color: model.isFocused && !empty ? "transparent" : empty ? Config.colors.surface1 : Config.colors.surface2
      border.color: model.isFocused ? Config.colors.primary : empty ? Config.colors.surface1 : Config.colors.surface2
      border.width: 2
      height: Config.sizes.extraLarge
      radius: Config.radius.small
      width: model.isFocused ? 52 : Config.sizes.extraLarge

      Gradient {
        id: grad
        orientation: Gradient.Vertical
        GradientStop {
          position: 0
          color: Config.colors.base
        }
    }
}
