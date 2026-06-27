import QtQuick
import qs.Bar

Rectangle {
  id: root
  required property Item controller

  readonly property real horizontalPadding: controller.buttonHorizontalPadding
  readonly property bool active: controller.activePanel === "notifications"
  readonly property bool hasNotifications: NotificationStore.count > 0

  width: controller.window.implicitHeight + horizontalPadding * 2
  height: controller.window.implicitHeight
  color: "transparent"

  MaterialIcon {
    anchors.centerIn: parent
    code: root.hasNotifications ? 0xE5E8 : 0xE0CE
    iconColor: root.active ? Config.colors.primary : root.hasNotifications ? Config.colors.fg : Config.colors.surface3
  }

  Rectangle {
    visible: root.hasNotifications
    width: Math.max(10, badgeText.implicitWidth + Config.padding.micro * 2)
    height: 14
    radius: 2
    color: Config.colors.destructive
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: Config.padding.micro
    anchors.rightMargin: Config.padding.micro

    Text {
      id: badgeText
      anchors.centerIn: parent
      text: NotificationStore.count > 99 ? "99+" : String(NotificationStore.count)
      color: Config.colors.base
      font.pixelSize: Config.sizes.small
      font.weight: Font.Bold
      textFormat: Text.PlainText
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: controller.switchPanel("notifications")
  }
}
