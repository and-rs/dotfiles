pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  property QtObject colors
  property QtObject radius
  property QtObject spacing
  property QtObject padding
  property QtObject sizes
  property QtObject durations
  property QtObject transparency
  property QtObject curves

  // lightmode
  // colors: QtObject {
  //   property string bg: "#e0e2ea"
  //   property string dim: "#cacbd3"
  //   property string muted: "#b3b5bb"
  //   property string bright: "#9d9ea4"
  //   property string accent: "#86888c"
  //   property string light: "#707175"
  //   property string light_green: "#00a244"
  //   property string light_red: "#A8000E"
  //   property string fg: "#07080d"
  //   property string success: "#005523"
  //   property string primary: "#004c73"
  //   property string secondary: "#470045"
  //   property string destructive: "#590008"
  // }

  // darkmode
  colors: QtObject {
    property string bg: "#14161b"
    property string dim: "#1b1e25"
    property string muted: "#353945"
    property string bright: "#4f5258"
    property string accent: "#646a7a"
    property string light: "#79839c"

    property string light_green: "#b3f6c0"
    property string light_red: "#ffc0b9"
    property string fg: "#e0e2ea"
    property string success: "#b3f6c0"
    property string primary: "#a6dbff"
    property string secondary: "#ffcaff"
    property string destructive: "#ffc0b9"
  }

  curves: QtObject {
    property var standard: Easing.OutQuint
    property var bounce: Easing.OutBack
    property var smooth: Easing.InOutQuad
    property var snap: Easing.OutQuad
    property var enter: Easing.InCubic
    property var sharp: Easing.OutQuint
    property var linear: Easing.Linear
    property var springy: Easing.InOutCubic
  }

  radius: QtObject {
    property real scale: 1
    property int small: 4 * scale
    property int normal: 8 * scale
    property int large: 16 * scale
    property int full: 1000 * scale
  }

  spacing: QtObject {
    property real scale: 1
    property int extraSmall: 4 * scale
    property int small: 8 * scale
    property int normal: 12 * scale
    property int large: 16 * scale
    property int extraLarge: 24 * scale
  }

  padding: QtObject {
    property real scale: 1
    property int extraSmall: 5 * scale
    property int small: 7 * scale
    property int normal: 10 * scale
    property int large: 12 * scale
    property int extraLarge: 15 * scale
  }

  sizes: QtObject {
    property real scale: 1
    property int extraSmall: 8 * scale
    property int small: 12 * scale
    property int normal: 16 * scale
    property int large: 20 * scale
    property int extraLarge: 24 * scale
  }

  durations: QtObject {
    property real scale: 1
    property int extraFast: 100 * scale
    property int fast: 200 * scale
    property int normal: 400 * scale
    property int slow: 600 * scale
    property int extraSlow: 1000 * scale
  }

  transparency: QtObject {
    property bool enabled: false
    property real base: 0.85
    property real layers: 0.4
  }
}
