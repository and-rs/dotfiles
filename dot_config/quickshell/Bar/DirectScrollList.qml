import QtQuick
import qs.Bar

ListView {
  id: root

  readonly property bool scrollable: maximumContentY() > minimumContentY() + 1
  property real wheelScrollMultiplier: 10.0

  function clampContentY(value: real): real {
    return Math.max(minimumContentY(), Math.min(maximumContentY(), value));
  }
  function maximumContentY(): real {
    return Math.max(minimumContentY(), originY + contentHeight - height + bottomMargin);
  }
  function minimumContentY(): real {
    return originY - topMargin;
  }

  boundsBehavior: Flickable.StopAtBounds
  boundsMovement: Flickable.StopAtBounds
  interactive: false

  Rectangle {
    anchors.right: root.right
    anchors.rightMargin: Config.padding.micro / 2
    color: Config.colors.surface5
    height: Math.min(root.height, Math.max(Config.padding.large * 2, root.height * root.height / (root.maximumContentY() - root.minimumContentY() + root.height)))
    opacity: 0.8
    parent: root
    radius: width / 2
    visible: root.scrollable
    width: Config.padding.micro
    y: (root.contentY - root.minimumContentY()) / (root.maximumContentY() - root.minimumContentY()) * (root.height - height)
    z: 2
  }
  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    blocking: true
    enabled: root.scrollable
    target: null

    onWheel: event => {
      const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y * root.wheelScrollMultiplier : (event.angleDelta.y / 120) * 24 * root.wheelScrollMultiplier;
      root.contentY = root.clampContentY(root.contentY - delta);
    }
  }
}
