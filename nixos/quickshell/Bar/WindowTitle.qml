import Quickshell
import QtQuick

Row {
  id: root
  spacing: Config.spacing.small
  anchors.verticalCenter: parent.verticalCenter
  property var focusedWindow: NiriService.instance.focusedWindow

  Text {
    text: focusedWindow ? focusedWindow.title : ""
    anchors.verticalCenter: parent.verticalCenter
    color: Config.colors.fg
    font.pointSize: 10
    font.weight: 500
    elide: Text.ElideRight
    maximumLineCount: 1
    width: Math.min(implicitWidth, 250)
  }

  Text {
    text: focusedWindow ? focusedWindow.appId : ""
    anchors.verticalCenter: parent.verticalCenter
    color: Config.colors.surface4
    font.pointSize: 10
    font.weight: 500
  }
}
