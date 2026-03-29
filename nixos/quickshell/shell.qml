//@ pragma Env QS_NO_RELOAD_POPUP=1
import Quickshell
import QtQuick
import qs.Bar
import qs.Notification
import qs.Osd

Scope {
  property int height: 32

  Osd {}
  Bar {
    mainHeight: height
  }
  Notification {
    mainHeight: height
  }
}
