import QtQuick
import qs.Bar

Rectangle {
  id: root

  readonly property bool busy: NetworkService.actionNetworkId === network.id && NetworkService.actionState !== "idle"
  readonly property bool canForget: network.known && !network.connected
  required property var network
  required property var panel

  color: mouse.containsMouse ? Config.colors.surface2 : Config.colors.surface1
  height: passwordArea.visible ? 98 : 48
  radius: Config.radius.small
  width: parent ? parent.width : 0

  MaterialIcon {
    id: signalIcon

    anchors.left: parent.left
    anchors.leftMargin: Config.padding.small
    anchors.top: parent.top
    anchors.topMargin: Config.padding.small
    centered: false
    code: root.network.signalStrength > 0.75 ? 0xE4EA : root.network.signalStrength > 0.5 ? 0xE4EE : root.network.signalStrength > 0.25 ? 0xE4EC : 0xE4F0
    iconColor: root.network.connected ? Config.colors.primary : Config.colors.surface4
    iconSize: 18
  }
  Text {
    id: actionLabel

    anchors.right: parent.right
    anchors.rightMargin: Config.padding.small
    anchors.top: signalIcon.top
    color: root.network.connected ? Config.colors.success : Config.colors.primary
    font.pointSize: 8
    font.weight: 500
    text: root.busy ? "…" : root.network.connected ? "Connected" : "Connect"
  }
  Text {
    id: networkName

    anchors.left: signalIcon.right
    anchors.leftMargin: Config.padding.small
    anchors.right: actionLabel.left
    anchors.rightMargin: Config.padding.small
    anchors.top: signalIcon.top
    color: root.network.connected ? Config.colors.primary : Config.colors.fg
    elide: Text.ElideRight
    font.pointSize: 9
    font.weight: root.network.connected ? 600 : 400
    text: root.network.name
  }
  Text {
    anchors.left: networkName.left
    anchors.right: networkName.right
    anchors.top: networkName.bottom
    anchors.topMargin: 1
    color: Config.colors.surface5
    elide: Text.ElideRight
    font.pointSize: 8
    text: root.busy ? NetworkService.actionState + "…" : root.network.connected ? "Connected" : root.network.security + (root.network.known ? " · saved" : "")
  }
  MouseArea {
    id: mouse

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    cursorShape: Qt.PointingHandCursor
    enabled: !root.busy && NetworkService.actionState === "idle"
    height: 48
    hoverEnabled: true

    onClicked: {
      if (root.network.connected)
        NetworkService.disconnect();
      else
        root.panel.activateNetwork(root.network);
    }
  }
  Text {
    anchors.right: actionLabel.right
    anchors.top: actionLabel.bottom
    color: Config.colors.surface5
    font.pointSize: 8
    font.weight: 500
    text: "Forget"
    visible: root.canForget

    MouseArea {
      anchors.fill: parent
      anchors.margins: -Config.padding.small
      cursorShape: Qt.PointingHandCursor
      enabled: NetworkService.actionState === "idle"

      onClicked: NetworkService.forget(root.network)
    }
  }
  Item {
    id: passwordArea

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.margins: Config.padding.small
    anchors.right: parent.right
    height: visible ? 38 : 0
    visible: root.panel.passwordNetwork && root.panel.passwordNetwork.id === root.network.id

    onVisibleChanged: if (visible)
      passwordInput.forceActiveFocus()

    TextInput {
      id: passwordInput

      anchors.left: parent.left
      anchors.right: submit.left
      anchors.rightMargin: Config.padding.small
      anchors.verticalCenter: parent.verticalCenter
      color: Config.colors.fg
      echoMode: TextInput.Password
      font.pointSize: 9
      height: parent.height
      passwordCharacter: "*"
      selectByMouse: true
      text: root.panel.passwordText

      onAccepted: root.panel.submitPassword()
      onTextChanged: root.panel.passwordText = text
    }
    Text {
      id: submit

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      color: root.panel.passwordText.length > 0 ? Config.colors.primary : Config.colors.surface3
      font.pointSize: 8
      font.weight: 600
      text: "CONNECT"

      MouseArea {
        anchors.fill: parent
        anchors.margins: -Config.padding.small
        cursorShape: Qt.PointingHandCursor
        enabled: root.panel.passwordText.length > 0

        onClicked: root.panel.submitPassword()
      }
    }
  }
}
