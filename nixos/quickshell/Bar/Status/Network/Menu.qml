import QtQuick
import QtQuick.Controls
import qs.Bar

Column {
  id: root

  readonly property var connectedNetwork: NetworkService.connectedNetwork
  property alias debugHeroStatus: heroStatus
  property alias debugHeroTitle: heroTitle
  property alias debugNetworkList: networkList
  property var passwordNetwork: null
  property string passwordText: ""
  readonly property var wifiDevice: NetworkService.wifiDevice
  readonly property var wiredDevice: NetworkService.wiredDevice

  function activateNetwork(network) {
    if (!network)
      return;
    if (network.security === "Open" || NetworkService.backend === "iwctl") {
      NetworkService.connect(network, "");
      return;
    }
    passwordNetwork = network;
    passwordText = "";
  }
  function detailText(label, value) {
    return value ? label + "\n" + value : "";
  }
  function submitPassword() {
    if (!passwordNetwork || passwordText.length === 0)
      return;
    NetworkService.connect(passwordNetwork, passwordText);
    passwordText = "";
    passwordNetwork = null;
  }

  spacing: Config.spacing.normal
  width: parent ? parent.width : Config.networkPanel.width - Config.padding.large * 2

  Item {
    implicitHeight: Math.max(heroIcon.implicitHeight, heroTitle.implicitHeight + heroStatus.implicitHeight + Config.padding.micro, wifiToggle.implicitHeight)
    width: parent.width

    MaterialIcon {
      id: heroIcon

      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      centered: false
      code: root.wiredDevice && root.wiredDevice.hasLink ? 0xEDDE : root.connectedNetwork ? 0xE4EA : 0xE4F2
      iconColor: NetworkService.connectivity === "Full" ? Config.colors.primary : Config.colors.surface4
      iconSize: 30
    }
    Text {
      id: heroTitle

      anchors.left: heroIcon.right
      anchors.leftMargin: Config.spacing.normal
      anchors.right: wifiToggle.left
      anchors.rightMargin: Config.spacing.normal
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -(heroStatus.implicitHeight + Config.padding.micro) / 2
      color: Config.colors.fg
      elide: Text.ElideRight
      font.pointSize: 12
      font.weight: 600
      text: !NetworkService.available ? "Network unavailable" : root.connectedNetwork ? root.connectedNetwork.name : root.wiredDevice && root.wiredDevice.hasLink ? "Ethernet" : root.wifiDevice ? "Wi-Fi" : "No network device"
    }
    Text {
      id: heroStatus

      anchors.left: heroTitle.left
      anchors.right: heroTitle.right
      anchors.top: heroTitle.bottom
      anchors.topMargin: Config.padding.micro
      color: NetworkService.stale ? Config.colors.destructive : Config.colors.surface5
      elide: Text.ElideRight
      font.pointSize: 8
      font.weight: 500
      text: (NetworkService.stale ? "STALE · " : "") + NetworkService.connectivity.toUpperCase() + " · " + NetworkService.backend.toUpperCase()
    }
    Rectangle {
      id: wifiToggle

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      color: NetworkService.wifiEnabled ? Config.colors.primary : Config.colors.surface3
      height: 24
      radius: height / 2
      visible: root.wifiDevice !== null
      width: 44

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        color: Config.colors.base
        height: 18
        radius: height / 2
        width: height
        x: NetworkService.wifiEnabled ? parent.width - width - 3 : 3
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: NetworkService.actionState === "idle"

        onClicked: NetworkService.toggleWifi(!NetworkService.wifiEnabled)
      }
    }
  }
  Rectangle {
    color: Config.colors.surface2
    height: 1
    width: parent.width
  }
  Grid {
    columnSpacing: Config.spacing.large
    columns: 3
    rowSpacing: Config.spacing.normal
    width: parent.width

    Repeater {
      model: [root.detailText("INTERFACE", root.wifiDevice ? root.wifiDevice.name : root.wiredDevice ? root.wiredDevice.name : ""), root.detailText("SIGNAL", root.connectedNetwork ? Math.round(root.connectedNetwork.signalStrength * 100) + "%" : ""), root.detailText("SECURITY", root.connectedNetwork ? root.connectedNetwork.security : ""), root.detailText("ADAPTER", root.wifiDevice ? root.wifiDevice.address : ""), root.detailText("ETHERNET", root.wiredDevice && root.wiredDevice.hasLink ? root.wiredDevice.linkSpeed > 0 ? root.wiredDevice.linkSpeed + " Mbps" : "Connected" : ""), root.detailText("STATUS", NetworkService.connectivity)]

      delegate: Text {
        required property string modelData

        color: Config.colors.surface5
        font.pointSize: 8
        font.weight: 500
        text: modelData
        visible: text !== ""
        width: (parent.width - parent.columnSpacing * 2) / 3
      }
    }
  }
  Rectangle {
    color: Config.colors.surface2
    height: 1
    visible: root.wifiDevice !== null && NetworkService.wifiEnabled
    width: parent.width
  }
  Item {
    height: visible ? 22 : 0
    visible: root.wifiDevice !== null && NetworkService.wifiEnabled
    width: parent.width

    NetworkSectionHeader {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: NetworkService.scanState === "scanning" ? "SCANNING WI-FI" : "WI-FI NETWORKS"
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      color: Config.colors.primary
      font.pointSize: 8
      font.weight: 600
      text: NetworkService.scanState === "scanning" ? "SCANNING" : "REFRESH"

      MouseArea {
        anchors.fill: parent
        anchors.margins: -Config.padding.small
        cursorShape: Qt.PointingHandCursor
        enabled: NetworkService.scanState !== "scanning" && NetworkService.actionState === "idle"

        onClicked: NetworkService.scan()
      }
    }
  }
  ListView {
    id: networkList

    clip: true
    height: Math.min(contentHeight, Config.networkPanel.listHeight)
    interactive: contentHeight > height
    model: root.wifiDevice && NetworkService.wifiEnabled ? NetworkService.wifiNetworks : []
    spacing: Config.spacing.extraSmall
    width: parent.width

    ScrollBar.vertical: ScrollBar {
      policy: ScrollBar.AsNeeded
    }
    delegate: Item {
      readonly property bool firstKnown: modelData.known && (index === 0 || !NetworkService.wifiNetworks[index - 1].known)
      readonly property bool firstOther: !modelData.known && (index === 0 || NetworkService.wifiNetworks[index - 1].known)
      required property int index
      required property var modelData

      height: rowColumn.implicitHeight
      width: ListView.view.width

      Column {
        id: rowColumn

        spacing: Config.spacing.extraSmall
        width: parent.width

        NetworkSectionHeader {
          text: parent.parent.firstKnown ? "KNOWN NETWORKS" : parent.parent.firstOther ? "OTHER NETWORKS" : ""
          visible: text !== ""
        }
        NetworkRow {
          network: modelData
          panel: root
          width: parent.width
        }
      }
    }
  }
  Text {
    color: Config.colors.surface3
    font.pointSize: 9
    text: root.wifiDevice === null ? "No Wi-Fi device found" : !NetworkService.wifiEnabled ? "Wi-Fi is disabled" : NetworkService.scanState === "idle" && NetworkService.wifiNetworks.length === 0 ? "No networks found" : ""
    visible: text !== ""
  }
  Text {
    color: Config.colors.destructive
    font.pointSize: 8
    text: NetworkService.lastError
    visible: text !== ""
    width: parent.width
    wrapMode: Text.Wrap
  }
}
