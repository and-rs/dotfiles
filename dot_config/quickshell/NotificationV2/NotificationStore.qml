pragma Singleton
import Quickshell
import QtQuick
import qs.Bar
import qs.NotificationV2

Singleton {
	id: root

	property var connectedNotifications: ({})
	readonly property int count: records.length
	readonly property var entries: entriesModel
	readonly property bool hasNotifications: count > 0
	readonly property string imageCacheDir: imageCachePrefix
	readonly property string imageCachePrefix: Quickshell.cachePath("notification-v2-")
	readonly property int popupDurationMs: popupNotification ? NotificationData.popupDurationFromTimeout(popupNotification.expireTimeout) : 0
	readonly property var popupEntry: popupId === -1 ? null : getById(popupId)
	property int popupId: -1
	readonly property var popupNotification: popupEntry ? popupEntry.notification : null
	property var popupQueueIds: []
	readonly property bool popupVisible: popupEntry !== null
	property var records: []
	property var removingIds: ({})

	signal entriesPrepending

	function activateNextPopup(): void {
		if (popupId !== -1)
			return;

		const nextPopup = NotificationPopupQueue.takeNext(popupQueueIds, records);
		popupQueueIds = nextPopup.queue;
		popupId = nextPopup.id;
	}
	function addNotification(notification: var): var {
		if (!notification)
			return null;

		notification.tracked = true;
		connectNotification(notification);
		const current = getById(notification.id);

		const nextEntry = NotificationData.entryForNotification(notification, current);
		upsertEntry(nextEntry);

		enqueuePopupId(notification.id);
		activateNextPopup();
		return nextEntry;
	}
	function cacheImage(image: var, cacheKey: string): string {
		const sourcePath = localImagePath(image);
		if (!sourcePath)
			return image ? String(image) : "";

		const reader = Qt.createQmlObject('import Quickshell.Io; FileView { blockAllReads: true; printErrors: false; path: "" }', root);
		const writer = Qt.createQmlObject('import Quickshell.Io; FileView { blockWrites: true; printErrors: false; path: "" }', root);

		try {
			reader.path = sourcePath;
			const data = reader.data();
			if (!data || data.byteLength === 0)
				return "";

			const targetPath = imageCachePrefix + cacheKey + "-" + Date.now() + "." + imageExtension(sourcePath);
			writer.path = targetPath;
			writer.setData(data);
			//console.log("[NotificationV2] image cache wrote", "key=" + cacheKey, "bytes=" + data.byteLength, "target=" + targetPath);
			return "file://" + targetPath;
		} catch (_) {
			return "";
		} finally {
			reader.destroy();
			writer.destroy();
		}
	}
	function cleanupCachedFile(path: string): void {
		if (!path)
			return;

		const localPath = localImagePath(path);
		if (!localPath || !localPath.startsWith(imageCachePrefix))
			return;

		Quickshell.execDetached({
			command: ["rm", "-f", localPath]
		});
	}
	function cleanupEntryAssets(entry: var): void {
		if (!entry || !entry.closed)
			return;

		cleanupCachedFile(entry.cachedImage);
		cleanupCachedFile(entry.cachedAppIcon);
	}
	function cleanupImageCacheDirectory(): void {
		Quickshell.execDetached({
			command: ["sh", "-c", "rm -f \"$1\"*", "sh", imageCachePrefix]
		});
	}
	function cleanupReplacedAssets(previousEntry: var, nextEntry: var): void {
		if (previousEntry?.cachedImage && previousEntry.cachedImage !== nextEntry.cachedImage)
			cleanupCachedFile(previousEntry.cachedImage);
		if (previousEntry?.cachedAppIcon && previousEntry.cachedAppIcon !== nextEntry.cachedAppIcon)
			cleanupCachedFile(previousEntry.cachedAppIcon);
	}
	function clear(): void {
		const currentEntries = records;
		records = [];
		popupQueueIds = [];
		popupId = -1;

		for (let index = 0; index < currentEntries.length; index++) {
			const entry = currentEntries[index];
			const notification = entry.notification;
			removingIds[entry.id] = true;
			if (notification)
				NotificationLifecycle.dismiss(notification);
			else
				delete removingIds[entry.id];
			delete connectedNotifications[entry.id];
		}

		cleanupImageCacheDirectory();
	}
	function clearPopup(id: int): void {
		if (popupId !== id)
			return;

		const nextPopup = NotificationPopupQueue.takeNext(popupQueueIds, records);
		popupQueueIds = nextPopup.queue;
		popupId = nextPopup.id;
	}
	function cloneObject(value: var): var {
		const clone = {};
		if (!value)
			return clone;
		for (const key in value)
			clone[key] = value[key];
		return clone;
	}
	function connectNotification(notification: var): void {
		if (connectedNotifications[notification.id] === notification)
			return;

		connectedNotifications[notification.id] = notification;
		notification.closed.connect(reason => markClosed(notification.id, reason));
		notification.appIconChanged.connect(() => refreshNotification(notification));
		notification.appNameChanged.connect(() => refreshNotification(notification));
		notification.bodyChanged.connect(() => refreshNotification(notification));
		notification.imageChanged.connect(() => refreshNotification(notification));
		notification.summaryChanged.connect(() => refreshNotification(notification));
		notification.urgencyChanged.connect(() => refreshNotification(notification));
		notification.actionsChanged.connect(() => refreshNotification(notification));
		notification.hasInlineReplyChanged.connect(() => refreshNotification(notification));
		notification.inlineReplyPlaceholderChanged.connect(() => refreshNotification(notification));
	}
	function enqueuePopupId(id: int): void {
		popupQueueIds = NotificationPopupQueue.enqueue(popupQueueIds, id);
	}
	function expirePopup(id: int): void {
		clearPopup(id);
		const notification = getById(id)?.notification;
		if (notification)
			NotificationLifecycle.expire(notification);
	}
	function getById(id: int): var {
		const index = indexOfId(id);
		return index === -1 ? null : records[index];
	}
	function hideActivePopup(): void {
		if (popupId !== -1)
			clearPopup(popupId);
	}
	function imageExtension(path: string): string {
		const cleanPath = path.split("?")[0].split("#")[0];
		const match = cleanPath.match(/\.([A-Za-z0-9]{1,8})$/);
		return match ? match[1].toLowerCase() : "image";
	}
	function indexOfId(id: int): int {
		for (let index = 0; index < records.length; index++) {
			if (records[index].id === id)
				return index;
		}
		return -1;
	}
	function invokeAction(id: int, actionIndex: int): void {
		const notification = getById(id)?.notification;
		if (popupId === id)
			clearPopup(id);
		NotificationLifecycle.invoke(notification, actionIndex);
	}
	function invokeDefaultAction(id: int): void {
		const notification = getById(id)?.notification;
		if (!notification)
			return;

		const actionIndex = NotificationData.defaultActionIndex(notification.actions);
		if (actionIndex !== -1)
			invokeAction(id, actionIndex);
	}
	function localImagePath(image: var): string {
		if (!image)
			return "";

		const value = String(image);
		if (value.startsWith("image://icon//"))
			return decodeURIComponent(value.slice(13));
		if (value.startsWith("file://"))
			return decodeURIComponent(value.slice(7));
		if (value.startsWith("/"))
			return value;
		return "";
	}
	function markClosed(id: int, reason: var): void {
		if (removingIds[id]) {
			delete removingIds[id];
			delete connectedNotifications[id];
			return;
		}

		const index = indexOfId(id);
		if (index === -1)
			return;

		const nextEntries = records.slice();
		const entry = cloneObject(records[index]);
		const notification = entry.notification;
		const nextEntry = NotificationData.entryForClosedNotification(entry, notification, String(reason));
		nextEntries[index] = nextEntry;
		records = nextEntries;
		const wasActive = popupId === id;
		if (wasActive)
			popupId = -1;
		removeQueuedPopupId(id);
		delete connectedNotifications[id];
		cleanupReplacedAssets(entry, nextEntry);
		if (wasActive)
			activateNextPopup();
	}
	function refreshNotification(notification: var): void {
		if (!notification || !notification.tracked)
			return;

		const current = getById(notification.id);
		if (!current || current.closed)
			return;

		upsertEntry(NotificationData.entryForNotification(notification, current));
	}
	function removeEntryOnly(id: int): void {
		const index = indexOfId(id);
		if (index === -1)
			return;

		const entry = records[index];
		const nextEntries = records.slice();
		nextEntries.splice(index, 1);
		records = nextEntries;
		cleanupEntryAssets(entry);
		if (popupId === id)
			popupId = -1;
	}
	function removeNotification(id: int): void {
		const entry = getById(id);
		if (!entry)
			return;

		const notification = entry.notification;
		const wasActive = popupId === id;
		removingIds[id] = true;
		removeQueuedPopupId(id);
		removeEntryOnly(id);

		if (notification)
			NotificationLifecycle.dismiss(notification);
		else
			delete removingIds[id];
		delete connectedNotifications[id];

		if (wasActive)
			activateNextPopup();
	}
	function removeQueuedPopupId(id: int): void {
		popupQueueIds = NotificationPopupQueue.remove(popupQueueIds, id);
	}
	function sendInlineReply(id: int, text: string): void {
		const notification = getById(id)?.notification;
		if (popupId === id)
			clearPopup(id);
		NotificationLifecycle.sendInlineReply(notification, text);
	}

	function trimToLimit(nextEntries: var): var {
		while (nextEntries.length > Config.notifications.historyLimit) {
			const entry = nextEntries[nextEntries.length - 1];
			removeQueuedPopupId(entry.id);
			nextEntries.pop();
			cleanupEntryAssets(entry);
			if (entry.notification) {
				removingIds[entry.id] = true;
				NotificationLifecycle.dismiss(entry.notification);
			}
			delete connectedNotifications[entry.id];
			if (popupId === entry.id)
				popupId = -1;
		}
		return nextEntries;
	}
	function updateNotification(notification: var): var {
		return addNotification(notification);
	}
	function upsertEntry(nextEntry: var): var {
		const index = indexOfId(nextEntry.id);
		const nextEntries = records.slice();
		if (index === -1) {
			entriesPrepending();
			nextEntries.unshift(nextEntry);
		} else {
			const previousEntry = records[index];
			cleanupReplacedAssets(previousEntry, nextEntry);
			nextEntries[index] = nextEntry;
		}

		records = trimToLimit(nextEntries);
		return nextEntry;
	}

	Component.onCompleted: cleanupImageCacheDirectory()

	ScriptModel {
		id: entriesModel

		objectProp: "id"
		values: root.records
	}
}
