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
    property string bg: "#1a1c26"
    property string dim: "#282a3a"
    property string muted: "#3c4158"
    property string bright: "#686e97"

    property string fg: "#FAFAFA"
    property string accent: "#A9B1D6"
    property string primary: "#7AA2F7"
    property string secondary: "#BB9AF7"
    property string destructive: "#F7768E"
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
    property int small: 4 * scale
    property int smaller: 8 * scale
    property int normal: 12 * scale
    property int larger: 16 * scale
    property int large: 20 * scale
  }

  padding: QtObject {
    property real scale: 1
    property int small: 5 * scale
    property int smaller: 7 * scale
    property int normal: 10 * scale
    property int larger: 12 * scale
    property int large: 15 * scale
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
