import Quickshell
import QtQuick

Row {
  id: root
  spacing: Config.spacing.small
  anchors.verticalCenter: parent.verticalCenter
  property var focusedWindow: NiriService.instance.focusedWindow

  function elide(str, len): string {
    if (!str)
      return "";
    if (str.length > len)
      return str.slice(0, len) + "...";
    return str;
  }

  Text {
    text: root.elide(focusedWindow ? focusedWindow.title : "", 28)
    anchors.verticalCenter: parent.verticalCenter
    color: Config.colors.fg
    font.pointSize: 10
    font.weight: 500
  }

  Text {
    text: focusedWindow ? focusedWindow.appId : ""
    anchors.verticalCenter: parent.verticalCenter
    color: Config.colors.accent
    font.pointSize: 10
    font.weight: 500
  }
}
