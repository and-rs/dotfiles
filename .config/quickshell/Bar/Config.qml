pragma Singleton

import Quickshell
import QtQuick

Singleton {
  id: root

  property QtObject colors
  property QtObject rounding
  property QtObject spacing
  property QtObject padding
  property QtObject sizes
  property QtObject durations
  property QtObject transparency

  colors: QtObject {
    property string bg: "#14161b"
    property string dim: "#1b1e25"
    property string muted: "#3f4655"
    property string bright: "#515a6e"
    property string accent: "#79839c"

    property string fg: "#fff"
    property string primary: "#a6dbff"
    property string secondary: "#ffcaff"
    property string destructive: "#ffc0b9"
  }

  rounding: QtObject {
    property real scale: 1
    property int small: 4 * scale
    property int normal: 8 * scale
    property int large: 16 * scale
    property int full: 1000 * scale
  }

  spacing: QtObject {
    property real scale: 1
    property int extraSmall: 2 * scale
    property int small: 4 * scale
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
    property int small: 11 * scale
    property int smaller: 12 * scale
    property int normal: 13 * scale
    property int larger: 15 * scale
    property int large: 24 * scale
    property int extraLarge: 28 * scale
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
