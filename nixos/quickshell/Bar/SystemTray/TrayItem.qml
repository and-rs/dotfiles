import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import qs.Bar

Item {
  id: content
  anchors.fill: parent
  opacity: popupVisible ? 1 : 0

  required property bool popupVisible
  readonly property int itemCount: trayRepeater.count
  readonly property int rowWidth: trayRow.implicitWidth
  readonly property int rowHeight: trayRow.implicitHeight

  Behavior on opacity {
    NumberAnimation {
      duration: Config.durations.fast
      easing.type: Config.curves.standard
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Config.colors.bg
    border.color: Config.colors.accent
    border.width: 2
    radius: Config.radius.small
  }

  Row {
    id: trayRow
    anchors.centerIn: parent
    spacing: 4

    Repeater {
      id: trayRepeater
      model: SystemTray.items
      delegate: Row {
        padding: Config.padding.extraSmall

        Image {
          readonly property string resolvedIcon: {
            const icon = modelData.icon;
            if (!icon || !icon.includes("?path="))
              return icon;
            const [name, path] = icon.split("?path=");
            return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
          }
          source: resolvedIcon
          width: 18
          height: 18
          sourceSize.width: 32
          sourceSize.height: 32
          smooth: true
          antialiasing: true
        }
      }
    }
  }
}
