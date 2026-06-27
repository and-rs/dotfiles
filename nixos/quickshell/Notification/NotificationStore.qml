pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Bar

Singleton {
    id: root

    readonly property ListModel items: ListModel {}
    property var removingIds: ({})
    property var liveNotifications: ({})
    property var notificationLocks: ({})
    property var popupQueueIds: []

    readonly property int count: items.count
    readonly property bool hasNotifications: count > 0
    property var popupEntry: null
    property int popupId: -1
    property real popupStartedAtMs: 0
    property real popupExpiresAtMs: 0
    function localImagePath(image) {
        if (!image)
            return "";
        const value = String(image);
        if (value.startsWith("file://"))
            return decodeURIComponent(value.slice(7));
        if (value.startsWith("/"))
            return value;
        return "";
    }

    function imageExtension(path) {
        const cleanPath = path.split("?")[0].split("#")[0];
        const match = cleanPath.match(/\.([A-Za-z0-9]{1,8})$/);
        return match ? match[1].toLowerCase() : "image";
    }

    function cacheImage(image, id) {
        const sourcePath = localImagePath(image);
        if (!sourcePath)
            return image || "";

        const reader = Qt.createQmlObject('import Quickshell.Io; FileView { blockAllReads: true; printErrors: false; path: "" }', root);
        const writer = Qt.createQmlObject('import Quickshell.Io; FileView { blockWrites: true; printErrors: false; path: "" }', root);
        try {
            reader.path = sourcePath;
            const data = reader.data();
            if (!data || data.byteLength === 0)
                return image;

            const targetPath = Quickshell.cachePath("notification-" + id + "-" + Date.now() + "." + imageExtension(sourcePath));
            writer.path = targetPath;
            writer.setData(data);
            return "file://" + targetPath;
        } catch (error) {
            return image || "";
        } finally {
            reader.destroy();
            writer.destroy();
        }
    }

    function popupDurationFromTimeout(expireTimeout) {
        if (expireTimeout <= 0)
            return Config.notifications.popupDuration;
        const timeout = Number(expireTimeout);
        const timeoutMs = timeout > 60 ? timeout : timeout * 1000;
        return Math.max(3000, Math.round(timeoutMs));
    }

    function buildEntry(notification) {
        const now = Date.now();
        const popupDurationMs = popupDurationFromTimeout(notification.expireTimeout);
        return {
            id: notification.id,
            appName: notification.appName,
            appIcon: cacheImage(notification.appIcon, notification.id + "-icon"),
            summary: notification.summary,
            body: notification.body,
            image: cacheImage(notification.image, notification.id),
            urgency: notification.urgency,
            createdAtMs: now,
            popupDurationMs: popupDurationMs,
            popupUntilMs: 0,
            resident: notification.resident,
            transient: notification.transient,
            closed: false,
            closeReason: ""
        };
    }

    function indexOfId(id) {
        for (let index = 0; index < items.count; index++) {
            if (items.get(index).id === id)
                return index;
        }
        return -1;
    }

    function getById(id) {
        const index = indexOfId(id);
        return index === -1 ? null : items.get(index);
    }

    function queueIndexOfId(id) {
        return popupQueueIds.indexOf(id);
    }

    function enqueuePopupId(id) {
        if (queueIndexOfId(id) === -1)
            popupQueueIds = popupQueueIds.concat([id]);
    }

    function removeQueuedPopupId(id) {
        const index = queueIndexOfId(id);
        if (index === -1)
            return;
        const nextQueue = popupQueueIds.slice();
        nextQueue.splice(index, 1);
        popupQueueIds = nextQueue;
    }

    function setPopupEntry(entry, startedAtMs, expiresAtMs) {
        startedAtMs = startedAtMs ?? 0;
        expiresAtMs = expiresAtMs ?? 0;
        popupEntry = entry;
        popupId = entry ? entry.id : -1;
        popupStartedAtMs = entry ? startedAtMs : 0;
        popupExpiresAtMs = entry ? expiresAtMs : 0;
    }

    function activateNextPopup() {
        if (popupId !== -1)
            return;

        while (popupQueueIds.length > 0) {
            const nextId = popupQueueIds[0];
            popupQueueIds = popupQueueIds.slice(1);
            const index = indexOfId(nextId);
            if (index === -1)
                continue;

            const current = items.get(index);
            if (current.closed)
                continue;

            const startedAtMs = Date.now();
            const expiresAtMs = startedAtMs + current.popupDurationMs;
            const nextEntry = {
                id: current.id,
                appName: current.appName,
                appIcon: current.appIcon,
                summary: current.summary,
                body: current.body,
                image: current.image,
                urgency: current.urgency,
                createdAtMs: current.createdAtMs,
                popupDurationMs: current.popupDurationMs,
                popupUntilMs: expiresAtMs,
                resident: current.resident,
                transient: current.transient,
                closed: current.closed,
                closeReason: current.closeReason
            };
            items.set(index, nextEntry);
            setPopupEntry(nextEntry, startedAtMs, expiresAtMs);
            return;
        }

        setPopupEntry(null);
    }

    function setEntry(index, entry) {
        items.set(index, entry);
        if (popupId === entry.id)
            popupEntry = entry;
    }

    function removeById(id) {
        const index = indexOfId(id);
        if (index === -1)
            return;
        items.remove(index, 1);
        if (popupId === id)
            setPopupEntry(null);
    }

    function retainNotification(id, notification) {
        releaseNotification(id);
        if (!notification)
            return;
        liveNotifications[id] = notification;
        const lock = Qt.createQmlObject('import Quickshell; RetainableLock { locked: true }', root);
        lock.object = notification;
        notificationLocks[id] = lock;
    }

    function releaseNotification(id) {
        const lock = notificationLocks[id];
        if (lock) {
            lock.locked = false;
            lock.destroy();
            delete notificationLocks[id];
        }
        delete liveNotifications[id];
    }

    function trimToLimit() {
        while (items.count > Config.notifications.historyLimit) {
            const entry = items.get(items.count - 1);
            removingIds[entry.id] = true;
            removeQueuedPopupId(entry.id);
            items.remove(items.count - 1, 1);
            if (popupId === entry.id)
                setPopupEntry(null);
            const notification = liveNotifications[entry.id];
            if (notification)
                notification.dismiss();
            else
                delete removingIds[entry.id];
            releaseNotification(entry.id);
        }
    }

    function add(notification) {
        if (!notification)
            return;

        notification.tracked = true;
        notification.closed.connect(reason => root.markClosed(notification.id, reason));
        delete removingIds[notification.id];
        retainNotification(notification.id, notification);

        const existingIndex = indexOfId(notification.id);
        const nextEntry = buildEntry(notification);

        if (existingIndex !== -1) {
            setEntry(existingIndex, nextEntry);
            if (popupId === notification.id)
                setPopupEntry(nextEntry, popupStartedAtMs, popupExpiresAtMs);
            else
                enqueuePopupId(notification.id);
            activateNextPopup();
            return;
        }

        items.insert(0, nextEntry);
        enqueuePopupId(notification.id);
        trimToLimit();
        activateNextPopup();
    }

    function markClosed(id, reason) {
        if (removingIds[id]) {
            delete removingIds[id];
            return;
        }

        const index = indexOfId(id);
        if (index === -1)
            return;

        const wasActive = popupId === id;
        removeQueuedPopupId(id);
        const current = items.get(index);
        const nextEntry = {
            id: current.id,
            appName: current.appName,
            appIcon: current.appIcon,
            summary: current.summary,
            body: current.body,
            image: current.image,
            urgency: current.urgency,
            createdAtMs: current.createdAtMs,
            popupDurationMs: current.popupDurationMs,
            popupUntilMs: 0,
            resident: current.resident,
            transient: current.transient,
            closed: true,
            closeReason: String(reason)
        };
        setEntry(index, nextEntry);
        if (wasActive) {
            setPopupEntry(null);
            activateNextPopup();
        }
    }

    function clearPopup(id) {
        const index = indexOfId(id);
        if (index === -1)
            return;

        const wasActive = popupId === id;
        const current = items.get(index);
        const nextEntry = {
            id: current.id,
            appName: current.appName,
            appIcon: current.appIcon,
            summary: current.summary,
            body: current.body,
            image: current.image,
            urgency: current.urgency,
            createdAtMs: current.createdAtMs,
            popupDurationMs: current.popupDurationMs,
            popupUntilMs: 0,
            resident: current.resident,
            transient: current.transient,
            closed: current.closed,
            closeReason: current.closeReason
        };
        setEntry(index, nextEntry);
        if (wasActive) {
            setPopupEntry(null);
            activateNextPopup();
        }
    }

    function hideActivePopup() {
        if (popupId === -1)
            return;
        clearPopup(popupId);
    }

    function expirePopup(id) {
        clearPopup(id);
        const notification = liveNotifications[id];
        if (notification)
            notification.expire();
    }

    function dismiss(id) {
        const entry = getById(id);
        if (!entry)
            return;

        const wasActive = popupId === id;
        const notification = liveNotifications[id];
        removingIds[id] = true;
        removeQueuedPopupId(id);
        removeById(id);

        if (notification && !entry.closed)
            notification.dismiss();
        else
            delete removingIds[id];
        releaseNotification(id);
        if (wasActive)
            activateNextPopup();
    }

    function clearAll() {
        const currentEntries = [];
        for (let index = 0; index < items.count; index++)
            currentEntries.push({ id: items.get(index).id, closed: items.get(index).closed });
        items.clear();
        popupQueueIds = [];
        setPopupEntry(null);
        for (let index = 0; index < currentEntries.length; index++) {
            const entry = currentEntries[index];
            const notification = liveNotifications[entry.id];
            removingIds[entry.id] = true;
            if (notification && !entry.closed)
                notification.dismiss();
            else
                delete removingIds[entry.id];
            releaseNotification(entry.id);
        }
    }

}
