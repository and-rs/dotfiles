import QtQuick
import qs.Bar

Column {
  id: content
  width: parent.width
  spacing: Config.spacing.normal

  property string summary: ""
  property string body: ""
  property alias bodyCarouselContainer: bodyCarouselContainer

  Text {
    id: summaryText
    text: summary
    font.pixelSize: Config.sizes.larger
    font.weight: Font.DemiBold
    antialiasing: false
    color: Config.colors.blue
    wrapMode: Text.Wrap
    maximumLineCount: 2
    elide: Text.ElideRight
    width: parent.width
  }

  Item {
    id: bodyCarouselContainer
    width: parent.width
    height: body === "" ? 0 : (expanded ? bodyText.contentHeight : Math.min(bodyText.contentHeight, bodyText.font.pixelSize * 2.5))
    visible: body !== ""

    property bool expanded: false

    Rectangle {
      id: bodyContainer
      anchors.fill: parent
      clip: true
      color: "transparent"

      Behavior on height {
        NumberAnimation {
          duration: Config.durations.normal
          easing.type: Easing.OutCubic
        }
      }

      Text {
        id: bodyText
        text: body
        font.pixelSize: Config.sizes.normal
        color: Config.colors.fg
        wrapMode: Text.Wrap
        width: parent.width
        maximumLineCount: parent.parent.expanded ? -1 : 2
        elide: parent.parent.expanded ? Text.ElideNone : Text.ElideRight
      }
    }
  }
}
