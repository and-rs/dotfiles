import Quickshell
import QtQuick
import Niri 0.1

Item {
  Niri {
    id: niri
    Component.onCompleted: connect()
    onConnected: console.log("Connected to niri")
    onErrorOccurred: function (error) {
      console.error("Error:", error);
    }
  }

  function isWorkspaceEmpty(workspaceId: int): bool {
    for (let i = 0; i < niri.windows.count; i++) {
      let item = niri.windows.data(niri.windows.index(i, 0), Qt.UserRole + 5);
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

  Row {
    spacing: Config.spacing.small
    padding: 4

    Repeater {
      id: repeater
      model: niri.workspaces

      delegate: Rectangle {
        id: rect

        property Text workspaceText: textItem

        gradient: Gradient {
          id: grad
          orientation: Gradient.Vertical
          GradientStop {
            position: 0
            color: Config.colors.dim
          }
          GradientStop {
            position: 2.2
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
        height: Config.sizes.large
        radius: 4
        width: model.isFocused ? 52 : Config.sizes.large

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
          font.weight: 500
          font.pointSize: 10
        }

        MouseArea {
          anchors.fill: parent
          onClicked: niri.focusWorkspaceById(model.id)
          cursorShape: Qt.PointingHandCursor
        }

        Connections {
          target: niri.windows

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

    Text {
      text: niri.focusedWindow?.title ?? ""
      anchors.verticalCenter: parent.verticalCenter
      color: Config.colors.fg
      leftPadding: 4
      font.weight: 500
      font.pointSize: 10
    }
  }
}
