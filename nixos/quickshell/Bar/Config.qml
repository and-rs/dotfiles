pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  property bool darkMode: true

  readonly property QtObject _dark: QtObject {
    property string base: "#181a27"
    property string surface1: "#212330"
    property string surface2: "#2f334d"
    property string surface3: "#3b4261"
    property string surface4: "#545c7e"
    property string surface5: "#727aac"
    property string fg: "#c8d3f5"
    property string primary: "#82aaff"
    property string secondary: "#c099ff"
    property string success: "#c3e88d"
    property string destructive: "#ff757f"
  }

  readonly property QtObject _light: QtObject {
    property string base: "#dddde3"
    property string surface1: "#d0d5e3"
    property string surface2: "#b7c1e3"
    property string surface3: "#979fba"
    property string surface4: "#777c92"
    property string surface5: "#5c6172"
    property string fg: "#3760bf"
    property string primary: "#2e7de9"
    property string secondary: "#9854f1"
    property string success: "#587539"
    property string destructive: "#c41c46"
  }

  readonly property QtObject colors: QtObject {
    property string base: root.darkMode ? root._dark.base : root._light.base
    property string surface1: root.darkMode ? root._dark.surface1 : root._light.surface1
    property string surface2: root.darkMode ? root._dark.surface2 : root._light.surface2
    property string surface3: root.darkMode ? root._dark.surface3 : root._light.surface3
    property string surface4: root.darkMode ? root._dark.surface4 : root._light.surface4
    property string surface5: root.darkMode ? root._dark.surface5 : root._light.surface5
    property string fg: root.darkMode ? root._dark.fg : root._light.fg
    property string primary: root.darkMode ? root._dark.primary : root._light.primary
    property string secondary: root.darkMode ? root._dark.secondary : root._light.secondary
    property string success: root.darkMode ? root._dark.success : root._light.success
    property string destructive: root.darkMode ? root._dark.destructive : root._light.destructive
  }

  readonly property QtObject popup: QtObject {
    property int width: 240
    property int gap: 6
    property int borderWidth: 2
  }

  readonly property QtObject curves: QtObject {
    property var standard: Easing.OutQuint
    property var bounce: Easing.OutBack
    property var smooth: Easing.InOutQuad
    property var snap: Easing.OutQuad
    property var enter: Easing.InCubic
    property var sharp: Easing.OutQuint
    property var linear: Easing.Linear
    property var springy: Easing.InOutCubic
  }

  readonly property QtObject radius: QtObject {
    property real scale: 1
    property int small: 4 * scale
    property int normal: 8 * scale
    property int large: 16 * scale
    property int full: 1000 * scale
  }

  readonly property QtObject spacing: QtObject {
    property real scale: 1
    property int extraSmall: 6 * scale
    property int small: 10 * scale
    property int normal: 12 * scale
    property int large: 16 * scale
    property int extraLarge: 24 * scale
  }

  readonly property QtObject padding: QtObject {
    property real scale: 1
    property int extraSmall: 5 * scale
    property int small: 7 * scale
    property int normal: 10 * scale
    property int large: 12 * scale
    property int extraLarge: 15 * scale
  }

  readonly property QtObject sizes: QtObject {
    property real scale: 1
    property int extraSmall: 8 * scale
    property int small: 12 * scale
    property int normal: 16 * scale
    property int large: 20 * scale
    property int extraLarge: 24 * scale
  }

  readonly property QtObject durations: QtObject {
    property real scale: 1
    property int extraFast: 100 * scale
    property int fast: 200 * scale
    property int normal: 400 * scale
    property int slow: 600 * scale
    property int extraSlow: 1000 * scale
  }

  readonly property QtObject transparency: QtObject {
    property bool enabled: false
    property real base: 0.85
    property real layers: 0.4
  }
}
