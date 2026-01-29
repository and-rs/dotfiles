import Quickshell
import QtQuick

Row {
  spacing: Config.spacing.extraSmall
  anchors.verticalCenter: parent.verticalCenter

  function isWorkspaceEmpty(workspaceId: int): bool {
    for (let i = 0; i < NiriService.instance.windows.count; i++) {
      let item = NiriService.instance.windows.data(NiriService.instance.windows.index(i, 0), Qt.UserRole + 5);
      if (item === workspaceId) {
        return false;
      }
    }
    return true;
  }

  function updateWorkspaceVisuals(rect: Rectangle, model: QtObject) {
    rect.color = rect.updateColors();
    rect.border.color = rect.updateBorderColor();
    if (rect.workspaceText) {
      rect.workspaceText.color = rect.updateTextColor();
    }
  }

  Repeater {
    id: repeater
    model: NiriService.instance.workspaces

    delegate: Rectangle {
      id: rect

      property Text workspaceText: textItem

      gradient: Gradient {
        id: grad
        orientation: Gradient.Vertical
        GradientStop {
          position: 0
          color: Config.colors.bg
        }
        GradientStop {
          position: 4
          color: Config.colors.primary
        }
      }

      color: updateColors()
      border.color: updateBorderColor()

      function updateColors() {
        if (model.isFocused && !isWorkspaceEmpty(model.id)) {
          rect.gradient = grad;
          return "transparent";
        }
        rect.gradient = null;
        return isWorkspaceEmpty(model.id) ? Config.colors.dim : Config.colors.muted;
      }

      function updateBorderColor() {
        return model.isFocused ? Config.colors.primary : isWorkspaceEmpty(model.id) ? Config.colors.dim : Config.colors.muted;
      }

      function updateTextColor() {
        return isWorkspaceEmpty(model.id) ? Config.colors.accent : Config.colors.fg;
      }

      border.width: 2
      height: Config.sizes.extraLarge
      radius: Config.radius.small
      width: model.isFocused ? 52 : Config.sizes.extraLarge

      Behavior on width {
        NumberAnimation {
          duration: Config.durations.normal
          easing.type: Easing.OutQuint
        }
      }

      Text {
        id: textItem
        color: rect.updateTextColor()
        anchors.centerIn: parent
        text: model.index
        font.weight: model.isFocused ? 800 : 500
        font.pointSize: 10
      }

      MouseArea {
        anchors.fill: parent
        onClicked: NiriService.instance.focusWorkspaceById(model.id)
        cursorShape: Qt.PointingHandCursor
      }

      Connections {
        target: NiriService.instance.windows

        function onDataChanged() {
          updateWorkspaceVisuals(rect, model);
        }

        function onRowsInserted() {
          updateWorkspaceVisuals(rect, model);
        }

        function onRowsRemoved() {
          updateWorkspaceVisuals(rect, model);
        }

        function onModelReset() {
          updateWorkspaceVisuals(rect, model);
        }
      }

      Connections {
        target: model

        function onIsFocusedChanged() {
          rect.color = rect.updateColors();
          rect.border.color = rect.updateBorderColor();
        }
      }
    }
  }
}
