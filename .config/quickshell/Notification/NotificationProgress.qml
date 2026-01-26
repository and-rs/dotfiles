import QtQuick
import qs.Bar

Rectangle {
  id: progressBar
  width: parent.width
  height: 3
  color: Config.colors.dim
  radius: Config.radius.small

  property real progress: 0

  Rectangle {
    width: parent.width * progressBar.progress
    height: parent.height
    color: Config.colors.primary
    radius: Config.radius.small

    Behavior on width {
      NumberAnimation {
        duration: 50
        easing.type: Easing.Linear
      }
    }
  }
}
