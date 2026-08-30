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

      aboveWindows: true
      color: "transparent"
      implicitHeight: barScope.mainHeight
      screen: modelData

      anchors {
        left: true
        right: true
        top: true
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

        height: barScope.mainHeight
        opacity: hidden ? 0 : 1
        width: parent.width
        y: hidden ? -barScope.mainHeight - 6 : 0

        Behavior on opacity {
          NumberAnimation {
            duration: 180
            easing.type: Config.curve
          }
        }
        Behavior on y {
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

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            color: Config.colors.surface1
            height: 2
          }
        }
        Row {
          padding: Config.padding.micro
          spacing: Config.spacing.normal

          Workspaces {
          }
          WindowTitle {
          }
        }
        Row {
          id: rightRect

          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          rightPadding: Config.padding.large
          spacing: Config.spacing.large

          Row {
            id: buttons

            anchors.verticalCenter: parent.verticalCenter
            spacing: Config.spacing.small

            Recording {
            }
            Caffeine {
              id: caffeine

              window: main
            }
            LockButton {
              id: lockButton

              window: main
            }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              color: Config.colors.surface2
              height: Config.sizes.small
              width: 2
            }
            StatusMenus {
              id: statusMenus

              window: main
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Config.colors.fg
            font.pointSize: 10
            font.weight: 500
            text: Time.format("ddd d MMM hh:mm")
          }
        }
      }
    }
  }
}
