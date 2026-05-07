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
    code: 0xE308
    iconColor: Config.colors.bright
  }

  MouseArea {
    anchors.fill: parent
    onClicked: {
      console.log("[LockButton] clicked, locking session");
      LockService.locked = true;
    }
  }
}
