import Quickshell
import QtQuick
import qs.Lock

Rectangle {
  id: lockButton

  required property PanelWindow window

  anchors.verticalCenter: parent.verticalCenter
  color: "transparent"
  height: window.implicitHeight
  width: window.implicitHeight

  MaterialIcon {
    code: 0xE308
    iconColor: Config.colors.surface3
  }
  MouseArea {
    anchors.fill: parent

    onClicked: LockService.locked = true
  }
}
