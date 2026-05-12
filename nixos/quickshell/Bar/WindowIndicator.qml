import Quickshell
import QtQuick

Row {
  id: root
  spacing: Config.spacing.small
  anchors.verticalCenter: parent.verticalCenter

  function iconSourceForWindow(win) {
    let appId = (win.app_id || "").trim();
    if (appId.length === 0)
      return Quickshell.iconPath("application-x-executable", true);
    let entry = DesktopEntries.heuristicLookup(appId) || DesktopEntries.byId(appId);
    if (entry && entry.icon && entry.icon.length > 0)
      return Quickshell.iconPath(entry.icon, "application-x-executable");
    return Quickshell.iconPath(appId, "application-x-executable");
  }

  Repeater {
    model: NiriService.currentWorkspaceWindows

    delegate: Column {
      required property var modelData
      required property int index

      property bool focused: index === NiriService.focusedWindowIndex
      property bool floating: modelData.is_floating

      spacing: 3
      anchors.verticalCenter: parent.verticalCenter

      Image {
        width: 18
        height: 18
        sourceSize.width: 48
        sourceSize.height: 48
        anchors.horizontalCenter: parent.horizontalCenter
        source: iconSourceForWindow(modelData)
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
        opacity: focused ? 1.0 : 0.4

        Behavior on opacity {
          NumberAnimation {
            duration: Config.durations.fast
            easing.type: Config.curves.standard
          }
        }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: focused ? 16 : floating ? 4 : 4
        height: 2
        radius: Config.radius.full
        color: focused ? Config.colors.primary : floating ? Config.colors.surface4 : "transparent"

        Behavior on width {
          NumberAnimation {
            duration: Config.durations.normal
            easing.type: Config.curves.standard
          }
        }

        Behavior on color {
          ColorAnimation {
            duration: Config.durations.fast
            easing.type: Config.curves.standard
          }
        }
      }
    }
  }

  Item {
    visible: NiriService.overlayActive
    width: 18
    height: 24
    anchors.verticalCenter: parent.verticalCenter

    MaterialIcon {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.verticalCenter: undefined
      code: 0xE468
      iconColor: Config.colors.primary
      iconSize: 14
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: 14
      height: 2
      radius: Config.radius.full
      color: Config.colors.primary
    }
  }
}
