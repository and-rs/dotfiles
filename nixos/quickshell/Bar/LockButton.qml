import Quickshell
import QtQuick
import qs.Lock

Rectangle {
  id: lockButton
  width: window.implicitHeight
  height: window.implicitHeight
  anchors.verticalCenter: parent.verticalCenter
  color: "transparent"

  required property PanelWindow window

  MaterialIcon {
    code: 0xE306
    iconColor: Config.colors.fg
    iconSize: 16
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      console.log("[LockButton] clicked, locking session");
      LockService.locked = true;
    }
  }
}
