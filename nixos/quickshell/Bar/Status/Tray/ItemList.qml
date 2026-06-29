import Quickshell.Services.SystemTray
import Quickshell
import QtQuick
import qs.Bar

Column {
  id: root

  required property Item controller
  property int expandedIndex: -1
  readonly property int itemCount: trayRepeater.count
  property var pendingAction: null

  function resolveIcon(icon) {
    if (!icon || !icon.includes("?path="))
      return icon ?? "";
    const [name, path] = icon.split("?path=");
    return Qt.resolvedUrl(`${path}/${name.slice(name.lastIndexOf("/") + 1)}`);
  }
  function triggerDeferredAction(action) {
    root.controller.closeMenus();
    root.pendingAction = action;
    actionTimer.restart();
  }

  spacing: 2
  width: parent ? parent.width : Config.popup.width

  Timer {
    id: actionTimer

    interval: Config.durations.instant
    repeat: false

    onTriggered: {
      if (!root.pendingAction)
        return;
      const action = root.pendingAction;
      root.pendingAction = null;
      action();
    }
  }
  Repeater {
    id: trayRepeater

    model: SystemTray.items

    delegate: Column {
      id: itemDelegate

      property bool animationsReady: false
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
      required property int index
      readonly property bool isExpanded: root.expandedIndex === index
      required property var modelData
      readonly property bool otherExpanded: root.expandedIndex !== -1 && !isExpanded

      clip: true
      height: otherExpanded ? 0 : implicitHeight
      opacity: otherExpanded ? 0 : 1
      width: root.width

      Behavior on height {
        enabled: itemDelegate.animationsReady

        NumberAnimation {
          duration: 75
          easing.type: Config.curve
        }
      }
      Behavior on opacity {
        enabled: itemDelegate.animationsReady

        NumberAnimation {
          duration: 75
          easing.type: Config.curve
        }
      }

      Component.onCompleted: animationsReady = true

      Rectangle {
        color: headerHover.hovered ? Config.colors.primary : Config.colors.surface2
        height: Config.sizes.large + Config.padding.normal
        radius: Config.radius.small
        width: parent.width

        HoverHandler {
          id: headerHover
        }
        Row {
          anchors.left: parent.left
          anchors.leftMargin: Config.padding.small
          anchors.right: parent.right
          anchors.rightMargin: Config.padding.small
          anchors.verticalCenter: parent.verticalCenter
          spacing: Config.spacing.small

          Item {
            anchors.verticalCenter: parent.verticalCenter
            height: Config.sizes.normal + 2
            width: Config.sizes.normal + 2

            Image {
              id: headerIcon

              anchors.fill: parent
              antialiasing: true
              smooth: true
              source: root.resolveIcon(itemDelegate.modelData.icon)
              sourceSize.height: 32
              sourceSize.width: 32
              visible: status === Image.Ready
            }
            MaterialIcon {
              anchors.centerIn: parent
              code: 0xE3E8
              iconColor: Config.colors.surface4
              iconSize: Config.sizes.normal
              visible: headerIcon.status !== Image.Ready
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            color: headerHover.hovered ? Config.colors.base : Config.colors.fg
            elide: Text.ElideRight
            font.pointSize: 9
            font.weight: 600
            text: itemDelegate.modelData.title || itemDelegate.modelData.id || "Unknown"
            width: parent.width - (Config.sizes.normal + 2) - chevronContainer.width - Config.spacing.small * 2
          }
          Item {
            id: chevronContainer

            anchors.verticalCenter: parent.verticalCenter
            height: Config.sizes.small + 2
            width: itemDelegate.hasMenuEntries ? Config.sizes.small + 2 : 0

            MaterialIcon {
              anchors.centerIn: parent
              code: itemDelegate.isExpanded ? 0xE136 : 0xE13A
              iconColor: headerHover.hovered ? Config.colors.base : Config.colors.fg
              iconSize: Config.sizes.small + 2
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
              root.triggerDeferredAction(() => itemDelegate.modelData.activate());
            }
          }
        }
      }
      Column {
        id: menuContent

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

        bottomPadding: 2
        clip: true
        spacing: 2
        topPadding: 2
        visible: itemDelegate.isExpanded && itemDelegate.hasMenuEntries
        width: parent.width

        QsMenuOpener {
          id: menuOpener

          menu: itemDelegate.modelData.hasMenu ? itemDelegate.modelData.menu : null
        }
        Repeater {
          model: menuContent.filteredEntries

          delegate: Rectangle {
            id: entryDelegate

            required property int index
            required property var modelData

            color: entryHover.hovered && modelData.enabled ? Config.colors.surface2 : Config.colors.surface1
            height: Config.sizes.large + Config.padding.extraSmall + 3
            radius: Config.radius.small
            width: menuContent.width

            HoverHandler {
              id: entryHover
            }
            Row {
              anchors.left: parent.left
              anchors.leftMargin: Config.padding.small
              anchors.right: parent.right
              anchors.rightMargin: Config.padding.small
              anchors.verticalCenter: parent.verticalCenter
              spacing: Config.spacing.small

              Rectangle {
                property bool hasButton: modelData.buttonType !== QsMenuButtonType.None
                property bool isChecked: modelData.checkState === Qt.Checked

                anchors.verticalCenter: parent.verticalCenter
                border.color: Config.colors.surface3
                border.width: 2
                color: isChecked ? Config.colors.primary : "transparent"
                height: Config.sizes.small + 2
                radius: modelData.buttonType === QsMenuButtonType.RadioButton ? Config.radius.full : 3
                visible: hasButton
                width: hasButton ? Config.sizes.small + 2 : 0
              }
              Item {
                anchors.verticalCenter: parent.verticalCenter
                height: Config.sizes.small + 2
                visible: modelData.icon !== undefined && modelData.icon !== ""
                width: visible ? Config.sizes.small + 2 : 0

                Image {
                  id: entryIcon

                  anchors.fill: parent
                  source: root.resolveIcon(modelData.icon)
                  sourceSize.height: Config.sizes.normal
                  sourceSize.width: Config.sizes.normal
                  visible: status === Image.Ready
                }
                MaterialIcon {
                  anchors.centerIn: parent
                  code: 0xE3E8
                  iconColor: Config.colors.surface4
                  iconSize: Config.sizes.small
                  visible: entryIcon.status !== Image.Ready
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.enabled ? Config.colors.fg : Config.colors.surface3
                elide: Text.ElideRight
                font.pointSize: 9
                font.weight: 500
                text: modelData.text || ""
                width: Math.min(implicitWidth, Config.popup.width - Config.padding.small * 4)
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              enabled: modelData.enabled

              onClicked: {
                root.triggerDeferredAction(() => modelData.triggered());
              }
            }
          }
        }
      }
    }
  }
}
