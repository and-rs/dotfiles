import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import qs.Bar

Column {
  id: root
  width: Config.popup.width
  spacing: 2

  readonly property int itemCount: trayRepeater.count
  property int expandedIndex: -1

  function resolveIcon(icon) {
    if (!icon || !icon.includes("?path="))
      return icon ?? "";
    const [name, path] = icon.split("?path=");
    return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
  }

  Repeater {
    id: trayRepeater
    model: SystemTray.items

    delegate: Column {
      id: itemDelegate
      width: root.width
      clip: true

      required property var modelData
      required property int index

      readonly property bool isExpanded: root.expandedIndex === index
      readonly property bool otherExpanded: root.expandedIndex !== -1 && !isExpanded
      readonly property bool hasMenuEntries: {
        if (!itemDelegate.modelData.hasMenu || !itemDelegate.modelData.menu)
          return false;
        const raw = menuOpener.children.values ?? [];
        for (const item of raw) {
          if (!item.isSeparator && !item.hasChildren && (item.text ?? "") !== "")
            return true;
        }
        return false;
      }

      property bool animationsReady: false
      Component.onCompleted: animationsReady = true

      opacity: otherExpanded ? 0 : 1
      height: otherExpanded ? 0 : implicitHeight

      Behavior on opacity {
        enabled: itemDelegate.animationsReady
        NumberAnimation {
          duration: 75
          easing.type: Config.curves.snap
        }
      }

      Behavior on height {
        enabled: itemDelegate.animationsReady
        NumberAnimation {
          duration: 75
          easing.type: Config.curves.snap
        }
      }

      // Header row
      Rectangle {
        width: parent.width
        height: Config.sizes.large + Config.padding.normal
        radius: Config.radius.small
        color: headerHover.hovered ? Config.colors.primary : Config.colors.muted

        HoverHandler {
          id: headerHover
        }

        Row {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Config.padding.small
          anchors.rightMargin: Config.padding.small
          spacing: Config.spacing.small

          Item {
            width: Config.sizes.normal + 2
            height: Config.sizes.normal + 2
            anchors.verticalCenter: parent.verticalCenter

            Image {
              id: headerIcon
              anchors.fill: parent
              source: root.resolveIcon(itemDelegate.modelData.icon)
              sourceSize.width: 32
              sourceSize.height: 32
              smooth: true
              antialiasing: true
              visible: status === Image.Ready
            }

            MaterialIcon {
              anchors.centerIn: parent
              code: 0xE3E8
              iconSize: Config.sizes.normal
              iconColor: Config.colors.accent
              visible: headerIcon.status !== Image.Ready
            }
          }

          Text {
            text: itemDelegate.modelData.title || itemDelegate.modelData.id || "Unknown"
            color: headerHover.hovered ? Config.colors.bg : Config.colors.fg
            font.pointSize: 9
            font.weight: 600
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: parent.width - (Config.sizes.normal + 2) - chevronContainer.width - Config.spacing.small * 2
          }

          Item {
            id: chevronContainer
            width: itemDelegate.hasMenuEntries ? Config.sizes.small + 2 : 0
            height: Config.sizes.small + 2
            anchors.verticalCenter: parent.verticalCenter

            MaterialIcon {
              anchors.centerIn: parent
              code: itemDelegate.isExpanded ? 0xE136 : 0xE13A
              iconSize: Config.sizes.small + 2
              iconColor: headerHover.hovered ? Config.colors.bg : Config.colors.fg
              visible: itemDelegate.hasMenuEntries
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (itemDelegate.hasMenuEntries) {
              root.expandedIndex = itemDelegate.isExpanded ? -1 : itemDelegate.index;
            } else {
              itemDelegate.modelData.activate();
            }
          }
        }
      }

      // Menu entries
      Column {
        id: menuContent
        width: parent.width
        visible: itemDelegate.isExpanded && itemDelegate.hasMenuEntries
        clip: true
        spacing: 2
        topPadding: 2
        bottomPadding: 2

        QsMenuOpener {
          id: menuOpener
          menu: itemDelegate.modelData.hasMenu ? itemDelegate.modelData.menu : null
        }

        readonly property var filteredEntries: {
          const raw = menuOpener.children.values ?? [];
          const result = [];
          for (const item of raw) {
            if (item.isSeparator || item.hasChildren)
              continue;
            const txt = item.text ?? "";
            if (txt !== "")
              result.push(item);
          }
          return result;
        }

        Repeater {
          model: menuContent.filteredEntries

          delegate: Rectangle {
            id: entryDelegate
            width: menuContent.width
            height: Config.sizes.large + Config.padding.extraSmall + 3
            color: entryHover.hovered && modelData.enabled ? Config.colors.muted : Config.colors.dim
            radius: Config.radius.small

            required property var modelData
            required property int index

            HoverHandler {
              id: entryHover
            }

            Row {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: Config.padding.small
              anchors.rightMargin: Config.padding.small
              spacing: Config.spacing.small

              Rectangle {
                property bool hasButton: modelData.buttonType !== QsMenuButtonType.None
                property bool isChecked: modelData.checkState === Qt.Checked
                visible: hasButton
                width: hasButton ? Config.sizes.small + 2 : 0
                height: Config.sizes.small + 2
                radius: modelData.buttonType === QsMenuButtonType.RadioButton ? Config.radius.full : 3
                color: isChecked ? Config.colors.primary : "transparent"
                border.width: 2
                border.color: Config.colors.bright
                anchors.verticalCenter: parent.verticalCenter
              }

              Item {
                width: visible ? Config.sizes.small + 2 : 0
                height: Config.sizes.small + 2
                visible: modelData.icon !== undefined && modelData.icon !== ""
                anchors.verticalCenter: parent.verticalCenter

                Image {
                  id: entryIcon
                  anchors.fill: parent
                  source: root.resolveIcon(modelData.icon)
                  sourceSize.width: Config.sizes.normal
                  sourceSize.height: Config.sizes.normal
                  visible: status === Image.Ready
                }

                MaterialIcon {
                  anchors.centerIn: parent
                  code: 0xE3E8
                  iconSize: Config.sizes.small
                  iconColor: Config.colors.accent
                  visible: entryIcon.status !== Image.Ready
                }
              }

              Text {
                text: modelData.text || ""
                color: modelData.enabled ? Config.colors.fg : Config.colors.bright
                font.pointSize: 9
                font.weight: 500
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: Math.min(implicitWidth, Config.popup.width - Config.padding.small * 4)
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              enabled: modelData.enabled
              onClicked: modelData.triggered()
            }
          }
        }
      }
    }
  }
}

