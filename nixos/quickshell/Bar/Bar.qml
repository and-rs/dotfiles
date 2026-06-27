import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Bar.Recording
import qs.Bar.Status

Scope {
  id: barScope
  required property var mainHeight

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: main
      required property var modelData

      screen: modelData
      aboveWindows: true
      implicitHeight: barScope.mainHeight
      color: "transparent"

      anchors {
        top: true
        left: true
        right: true
      }

      Item {
        id: barContent
        readonly property bool hidden: {
          let win = ToplevelManager.activeToplevel;
          if (!win || !win.fullscreen)
            return false;

          let screens = win.screens;
          if (!screens || screens.length === 0)
            return true;

          for (let screen of screens) {
            if (screen === main.screen)
              return true;
          }

          return false;
        }

        width: parent.width
        height: barScope.mainHeight
        y: hidden ? -barScope.mainHeight - 6 : 0
        opacity: hidden ? 0 : 1

        Behavior on y {
          NumberAnimation {
            duration: 180
            easing.type: Config.curve
          }
        }

        Behavior on opacity {
          NumberAnimation {
            duration: 180
            easing.type: Config.curve
          }
        }

        Rectangle {
          id: background
          anchors.fill: parent
          color: Config.colors.base

          Rectangle {
            id: bottomBorder
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Config.colors.surface1
          }
        }

        Row {
          spacing: Config.spacing.normal
          padding: Config.padding.micro
          Workspaces {}
          WindowTitle {}
        }

        Row {
          id: rightRect
          spacing: Config.spacing.large
          rightPadding: Config.padding.large
          anchors.verticalCenter: parent.verticalCenter
          anchors.right: parent.right

          Row {
            id: buttons
            spacing: Config.spacing.small
            anchors.verticalCenter: parent.verticalCenter

            Recording {}

            Caffeine {
              id: caffeine
              window: main
            }

            LockButton {
              id: lockButton
              window: main
            }

            Rectangle {
              width: 2
              height: Config.sizes.small
              color: Config.colors.surface2
              anchors.verticalCenter: parent.verticalCenter
            }

            StatusMenus {
              id: statusMenus
              window: main
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Config.colors.fg
            text: Time.format("ddd d MMM hh:mm")
            font.weight: 500
            font.pointSize: 10
          }
        }
      }
    }
  }
}
