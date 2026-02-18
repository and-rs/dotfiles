pragma Singleton
import Quickshell

Singleton {
  readonly property int hours: clock.hours
  readonly property int minutes: clock.minutes
  readonly property int seconds: clock.seconds

  function format(fmt: string): string {
    return Qt.formatDateTime(clock.date, fmt);
  }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }
}
