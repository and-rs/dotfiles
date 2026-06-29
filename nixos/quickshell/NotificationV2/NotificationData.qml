pragma Singleton
import Quickshell
import qs.Bar

Singleton {
  id: root

  function actionIdentifier(action: var): string {
    if (!action)
      return "";
    return String(action.identifier || "").toLowerCase();
  }
  function cloneObject(value: var): var {
    const clone = {};
    if (!value)
      return clone;
    for (const key in value)
      clone[key] = value[key];
    return clone;
  }
  function defaultActionIndex(actions: var): int {
    if (!actions)
      return -1;

    for (let index = 0; index < actions.length; index++) {
      if (actions[index].isDefault)
        return actions[index].index;
    }
    return -1;
  }
  function fromNotification(notification: var): var {
    const actions = normalizeActions(notification?.actions);
    const popupDurationMs = popupDurationFromTimeout(notification?.expireTimeout);
    const now = Date.now();

    return {
      id: notification?.id ?? -1,
      appName: notification?.appName ?? "",
      summary: notification?.summary ?? "",
      body: notification?.body ?? "",
      image: notification?.image ?? "",
      appIcon: notification?.appIcon ?? "",
      sourceImage: notification?.image ?? "",
      sourceAppIcon: notification?.appIcon ?? "",
      cachedImage: "",
      cachedAppIcon: "",
      urgency: notification?.urgency ?? 1,
      actionsJson: JSON.stringify(actions),
      visibleActionsJson: JSON.stringify(visibleActions(actions)),
      defaultActionIndex: defaultActionIndex(actions),
      hasDefaultAction: defaultActionIndex(actions) !== -1,
      hasActions: visibleActions(actions).length > 0,
      hasInlineReply: notification?.hasInlineReply ?? false,
      inlineReplyPlaceholder: notification?.inlineReplyPlaceholder || "Reply",
      closed: false,
      closeReason: "",
      popupDurationMs: popupDurationMs,
      popupUntilMs: 0,
      expireTimeout: notification?.expireTimeout ?? -1,
      resident: notification?.resident ?? false,
      transient: notification?.transient ?? false,
      timestamp: now,
      createdAtMs: now
    };
  }
  function isDefaultAction(action: var): bool {
    const identifier = actionIdentifier(action);
    return identifier === "default" || identifier === "activate";
  }
  function mergeNotification(entry: var, notification: var): var {
    const nextEntry = fromNotification(notification);
    nextEntry.timestamp = entry?.timestamp ?? nextEntry.timestamp;
    nextEntry.createdAtMs = entry?.createdAtMs ?? nextEntry.createdAtMs;
    return nextEntry;
  }
  function normalizeAction(action: var, index: int): var {
    return {
      index: index,
      id: action?.identifier ?? "",
      identifier: action?.identifier ?? "",
      text: action?.text ?? "Action",
      isDefault: isDefaultAction(action)
    };
  }
  function normalizeActions(actions: var): var {
    const normalized = [];
    if (!actions)
      return normalized;

    for (let index = 0; index < actions.length; index++)
      normalized.push(normalizeAction(actions[index], index));
    return normalized;
  }
  function popupDurationFromTimeout(expireTimeout: var): int {
    if (expireTimeout === undefined || expireTimeout === null)
      return Config.notifications.popupDuration;
    const timeout = Number(expireTimeout);
    if (timeout <= 0)
      return Config.notifications.popupDuration;
    const timeoutMs = timeout > 60 ? timeout : timeout * 1000;
    return Math.max(3000, Math.round(timeoutMs));
  }
  function visibleActions(actions: var): var {
    const visible = [];
    if (!actions)
      return visible;

    for (let index = 0; index < actions.length; index++) {
      if (!actions[index].isDefault)
        visible.push(actions[index]);
    }
    return visible;
  }
  function withClosedState(entry: var, reason: string): var {
    const nextEntry = cloneObject(entry);
    nextEntry.closed = true;
    nextEntry.closeReason = reason;
    nextEntry.popupUntilMs = 0;
    return nextEntry;
  }
  function withPopupUntil(entry: var, popupUntilMs: real): var {
    const nextEntry = cloneObject(entry);
    nextEntry.popupUntilMs = popupUntilMs;
    return nextEntry;
  }
}
