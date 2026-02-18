import QtQuick
import qs.Bar

Column {
  id: content
  width: parent.width
  spacing: Config.spacing.extraSmall

  property string summary: ""
  property string body: ""
  property alias bodyCarouselContainer: bodyCarouselContainer

  Text {
    id: summaryText
    text: summary
    font.pixelSize: Config.sizes.large
    font.weight: Font.Medium
    color: Config.colors.fg
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
          easing.type: Config.curves.standard
        }
      }

      Text {
        id: bodyText
        text: body
        font.pixelSize: Config.sizes.normal
        color: Config.colors.fg
        linkColor: Config.colors.primary
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        width: parent.width
        maximumLineCount: bodyCarouselContainer.expanded ? -1 : 2
        elide: bodyCarouselContainer.expanded ? Text.ElideNone : Text.ElideRight
        onLinkActivated: link => Qt.openUrlExternally(link)
      }
    }
  }
}
