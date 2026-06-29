pragma Singleton
import Quickshell

Singleton {
  id: root

  function dismiss(notification: var): void {
    if (notification)
      notification.dismiss();
  }
  function expire(notification: var): void {
    if (notification)
      notification.expire();
  }
  function invoke(notification: var, actionIndex: int): void {
    if (!notification || !notification.actions || actionIndex < 0 || actionIndex >= notification.actions.length)
      return;
    notification.actions[actionIndex].invoke();
  }
  function release(locks: var, live: var, id: int): var {
    const lock = locks[id];
    if (lock) {
      lock.locked = false;
      lock.destroy();
      delete locks[id];
    }
    delete live[id];
    return {
      locks: locks,
      live: live
    };
  }
  function retain(owner: var, locks: var, live: var, id: int, notification: var): var {
    release(locks, live, id);
    if (!notification)
      return {
        locks: locks,
        live: live
      };

    live[id] = notification;
    const lock = Qt.createQmlObject('import Quickshell; RetainableLock { locked: true }', owner);
    lock.object = notification;
    locks[id] = lock;
    return {
      locks: locks,
      live: live
    };
  }
  function sendInlineReply(notification: var, text: string): void {
    const reply = String(text || "").trim();
    if (!reply || !notification || !notification.hasInlineReply)
      return;
    notification.sendInlineReply(reply);
  }
}
