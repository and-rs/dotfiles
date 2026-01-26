import QtQuick
import qs.Bar

Item {
  id: header
  width: parent.width
  height: Math.max(iconContainer.height, appNameText.height)

  property string appName: ""
  property string appIcon: ""
  property string desktopEntry: ""
  property string body: ""
  property real bodyTextImplicitHeight: 0
  property bool bodyExpanded: false

  signal expandBody
  signal collapseBody

  function getIconSource() {
    if (appIcon !== "" && (appIcon.startsWith("/") || appIcon.startsWith("file://") || appIcon.startsWith("http://") || appIcon.startsWith("https://"))) {
      return appIcon;
    }
    if (desktopEntry !== "") {
      return "file:///usr/share/icons/hicolor/scalable/apps/" + desktopEntry.toLowerCase() + ".svg";
    }
    if (appIcon !== "") {
      return "file:///usr/share/icons/hicolor/scalable/apps/" + appIcon.toLowerCase() + ".svg";
    }
    return "";
  }

  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: Config.spacing.normal

    Rectangle {
      id: iconContainer
      width: 50
      height: 50
      radius: Config.radius.normal
      color: "transparent"
      visible: appIcon !== "" || appName !== ""

      AnimatedImage {
        id: appIconAnimated
        anchors.fill: parent

        source: header.getIconSource()
        fillMode: Image.PreserveAspectFit
        visible: source !== "" && status === Image.Ready && source.toString().toLowerCase().endsWith(".gif")
        asynchronous: true
        cache: false
        playing: true

        onStatusChanged: {
          if (status === Image.Error) {
            console.log("Failed to load animated icon from:", source);
          }
        }
      }

      Image {
        id: appIconImage
        anchors.fill: parent
        anchors.margins: 4
        source: header.getIconSource()
        fillMode: Image.PreserveAspectFit
        visible: source !== "" && status === Image.Ready && !source.toString().toLowerCase().endsWith(".gif")
        asynchronous: false
        cache: true

        onStatusChanged: {
          if (status === Image.Error) {
            console.log("Failed to load icon from:", source);
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: appName !== "" && (!appIconImage.visible && !appIconAnimated.visible)
        text: appName.charAt(0).toUpperCase()
        font.pixelSize: Config.sizes.large
        font.weight: Font.Bold
        color: Config.colors.accent
      }
    }

    Text {
      id: appNameText
      text: appName
      font.pixelSize: Config.sizes.small
      font.weight: Font.Medium
      color: Config.colors.accent
      opacity: 0.8
      visible: appName !== ""
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Config.spacing.small
    visible: body !== "" && bodyTextImplicitHeight > 13 * 2.5
    z: 100

    Rectangle {
      width: 22
      height: 22
      radius: Config.radius.full
      visible: bodyExpanded
      color: "transparent"

      Behavior on color {
        ColorAnimation {
          duration: Config.durations.fast
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: header.collapseBody()
      }
    }

    Rectangle {
      width: 22
      height: 22
      radius: Config.radius.full
      color: "transparent"
      visible: !bodyExpanded

      Behavior on color {
        ColorAnimation {
          duration: Config.durations.fast
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: header.expandBody()
      }
    }
  }
}
