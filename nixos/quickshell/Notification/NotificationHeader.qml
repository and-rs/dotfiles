import QtQuick
import qs.Bar

Item {
  id: header
  width: parent.width
  height: mainRow.implicitHeight

  property string appName: ""
  property string appIcon: ""
  property string appImage: ""
  property string body: ""
  property string desktopEntry: ""
  property real bodyTextImplicitHeight: 0
  property bool bodyExpanded: false

  readonly property string effectiveSource: appImage || appIcon

  signal expandBody
  signal collapseBody

  Row {
    id: mainRow
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: Config.spacing.normal

    Rectangle {
      id: iconContainer
      width: 60
      height: 60
      radius: Config.radius.normal
      color: "transparent"
      visible: effectiveSource !== "" || appName !== ""

      Image {
        id: appIconImage
        anchors.fill: parent
        anchors.margins: 2
        source: header.effectiveSource
        fillMode: Image.PreserveAspectFit
        asynchronous: !source.toString().startsWith("image://")
        visible: status === Image.Ready
        cache: false

        onStatusChanged: {
          if (status === Image.Error) {
            console.warn("Failed to load icon from:", source);
          }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: header.effectiveSource === "" || appIconImage.status === Image.Error
        text: appName.charAt(0).toUpperCase()
        font.pixelSize: Config.sizes.extraLarge
        font.weight: Font.Bold
        color: Config.colors.light
      }
    }

    Text {
      id: appNameText
      text: appName
      font.pixelSize: Config.sizes.normal
      font.weight: Font.Medium
      color: Config.colors.light
      visible: text !== ""
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Row {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Config.spacing.small
    visible: body !== "" && bodyTextImplicitHeight > (Config.sizes.normal * 2.5)

    Rectangle {
      width: 22
      height: 22
      color: "transparent"

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: bodyExpanded ? header.collapseBody() : header.expandBody()
      }
    }
  }
}
