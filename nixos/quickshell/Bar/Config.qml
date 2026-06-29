pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  readonly property QtObject _dark: QtObject {
    property string base: "#181a27"
    property string destructive: "#ff757f"
    property string fg: "#c8d3f5"
    property string primary: "#82aaff"
    property string secondary: "#c099ff"
    property string success: "#c3e88d"
    property string surface1: "#212330"
    property string surface2: "#2f334d"
    property string surface3: "#3b4261"
    property string surface4: "#545c7e"
    property string surface5: "#727aac"
  }
  readonly property QtObject _light: QtObject {
    property string base: "#dddde3"
    property string destructive: "#c41c46"
    property string fg: "#3760bf"
    property string primary: "#2e7de9"
    property string secondary: "#9854f1"
    property string success: "#587539"
    property string surface1: "#d0d5e3"
    property string surface2: "#b7c1e3"
    property string surface3: "#979fba"
    property string surface4: "#777c92"
    property string surface5: "#5c6172"
  }
  readonly property QtObject colors: QtObject {
    property string base: root.darkMode ? root._dark.base : root._light.base
    property string destructive: root.darkMode ? root._dark.destructive : root._light.destructive
    property string fg: root.darkMode ? root._dark.fg : root._light.fg
    property string primary: root.darkMode ? root._dark.primary : root._light.primary
    property string secondary: root.darkMode ? root._dark.secondary : root._light.secondary
    property string success: root.darkMode ? root._dark.success : root._light.success
    property string surface1: root.darkMode ? root._dark.surface1 : root._light.surface1
    property string surface2: root.darkMode ? root._dark.surface2 : root._light.surface2
    property string surface3: root.darkMode ? root._dark.surface3 : root._light.surface3
    property string surface4: root.darkMode ? root._dark.surface4 : root._light.surface4
    property string surface5: root.darkMode ? root._dark.surface5 : root._light.surface5
  }
  readonly property var curve: Easing.OutQuint
  property bool darkMode: false
  readonly property QtObject durations: QtObject {
    property int extraFast: 100 * scale
    property int extraSlow: 1000 * scale
    property int fast: 200 * scale
    property int instant: 75 * scale
    property int normal: 400 * scale
    property real scale: 1
    property int slow: 600 * scale
  }
  readonly property QtObject notifications: QtObject {
    property int historyLimit: 100
    property int popupDuration: 5000
    property int popupWidth: 360
  }
  readonly property QtObject padding: QtObject {
    property int extraLarge: 15 * scale
    property int extraSmall: 5 * scale
    property int large: 12 * scale
    property int micro: 4 * scale
    property int normal: 10 * scale
    property real scale: 1
    property int small: 7 * scale
  }
  readonly property QtObject popup: QtObject {
    property int borderWidth: 2
    property bool debug: false
    property int gap: 6
    property int width: 240
  }
  readonly property QtObject radius: QtObject {
    property int full: 1000 * scale
    property int large: 16 * scale
    property int normal: 8 * scale
    property real scale: 1
    property int small: 4 * scale
  }
  readonly property QtObject sidebar: QtObject {
    property int borderWidth: 2
    property int gap: 8
    property int maxHeight: 560
    property int rightMargin: 12
    property int width: 420
  }
  readonly property QtObject sizes: QtObject {
    property int extraLarge: 24 * scale
    property int extraSmall: 8 * scale
    property int large: 20 * scale
    property int normal: 16 * scale
    property real scale: 1
    property int small: 12 * scale
  }
  readonly property QtObject spacing: QtObject {
    property int extraLarge: 24 * scale
    property int extraSmall: 4 * scale
    property int large: 16 * scale
    property int normal: 12 * scale
    property real scale: 1
    property int small: 10 * scale
  }
  readonly property QtObject transparency: QtObject {
    property real base: 0.85
    property bool enabled: false
    property real layers: 0.4
  }
}
