//@ pragma Env QS_NO_RELOAD_POPUP=1
import Quickshell
import QtQuick
import qs.Bar
import qs.NotificationV2
import qs.Osd
import qs.Lock

Scope {
  property int height: 32

  Osd {
  }
  Bar {
    mainHeight: height
  }
  NotificationPopupHost {
    mainHeight: height
  }
  Lock {
  }
}
