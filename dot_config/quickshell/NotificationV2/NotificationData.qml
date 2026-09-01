pragma Singleton
import Quickshell
import qs.Bar
import qs.Config

Singleton {
	id: root

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
			if (isDefaultAction(actions[index]))
				return index;
		}
		return -1;
	}
	function entryForClosedNotification(entry: var, notification: var, reason: string): var {
		const nextEntry = cloneObject(entry);
		nextEntry.closed = true;
		nextEntry.closeReason = reason;
		nextEntry.image = nextEntry.cachedImage;
		nextEntry.appIcon = nextEntry.cachedAppIcon;
		nextEntry.notification = null;
		if (notification) {
			nextEntry.expireTimeout = notification.expireTimeout;
			nextEntry.resident = notification.resident;
			nextEntry.transient = notification.transient;
			nextEntry.urgency = notification.urgency;
		}
		return nextEntry;
	}
	function entryForNotification(notification: var, previousEntry: var): var {
		const now = Date.now();
		const image = notification?.image ?? "";
		const appIcon = notification?.appIcon ?? "";
		const cachedImage = previousEntry && previousEntry.sourceImage === image ? previousEntry.cachedImage : NotificationStore.cacheImage(image, String(notification?.id ?? -1));
		const cachedAppIcon = previousEntry && previousEntry.sourceAppIcon === appIcon ? previousEntry.cachedAppIcon : NotificationStore.cacheImage(appIcon, String(notification?.id ?? -1) + "-icon");

		return {
			id: notification?.id ?? -1,
			appName: notification?.appName ?? "",
			summary: notification?.summary ?? "",
			body: notification?.body ?? "",
			image: cachedImage,
			appIcon: cachedAppIcon,
			sourceImage: image,
			sourceAppIcon: appIcon,
			cachedImage: cachedImage,
			cachedAppIcon: cachedAppIcon,
			urgency: notification?.urgency ?? 1,
			closed: false,
			closeReason: "",
			expireTimeout: notification?.expireTimeout ?? -1,
			resident: notification?.resident ?? false,
			transient: notification?.transient ?? false,
			timestamp: previousEntry?.timestamp ?? now,
			createdAtMs: previousEntry?.createdAtMs ?? now,
			notification: notification ?? null
		};
	}
	function isDefaultAction(action: var): bool {
		if (!action)
			return false;

		const identifier = String(action.identifier || "").toLowerCase();
		return identifier === "default" || identifier === "activate";
	}
	function popupDurationFromTimeout(expireTimeout: var): int {
		if (expireTimeout === undefined || expireTimeout === null)
			return Config.notifications.popupDuration;

		const timeout = Number(expireTimeout);
		if (!isFinite(timeout) || timeout < 0)
			return Config.notifications.popupDuration;

		return Math.max(0, Math.round(timeout));
	}
	function visibleActions(actions: var): var {
		const visible = [];
		if (!actions)
			return visible;

		for (let index = 0; index < actions.length; index++) {
			if (!isDefaultAction(actions[index]))
				visible.push({
					index: index,
					action: actions[index],
					text: actions[index]?.text ?? "Action"
				});
		}
		return visible;
	}
}
