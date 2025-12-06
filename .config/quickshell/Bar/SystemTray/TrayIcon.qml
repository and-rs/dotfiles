import qs.Bar

MaterialIcon {
  id: trayIcon
  required property bool condition
  code: !condition ? 0xe15b : popupVisible ? 0xf508 : 0xe69b
  iconColor: condition ? Config.colors.fg : Config.colors.bright
}
