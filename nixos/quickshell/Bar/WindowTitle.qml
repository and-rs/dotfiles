import Quickshell
import QtQuick

Row {
  id: root

  property var focusedWindow: NiriService.instance.focusedWindow

  anchors.verticalCenter: parent.verticalCenter
  spacing: Config.spacing.small

  Text {
    anchors.verticalCenter: parent.verticalCenter
    color: Config.colors.fg
    elide: Text.ElideRight
    font.pointSize: 10
    font.weight: 500
    maximumLineCount: 1
    text: focusedWindow ? focusedWindow.title : ""
    width: Math.min(implicitWidth, 250)
  }
  Text {
    anchors.verticalCenter: parent.verticalCenter
    color: Config.colors.surface4
    font.pointSize: 10
    font.weight: 500
    text: focusedWindow ? focusedWindow.appId : ""
  }
}
