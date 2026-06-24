pragma Singleton

import Quickshell
import QtQuick
import qs.Bar

Singleton {
    id: root

    readonly property ListModel items: ListModel {}
    property int nowMs: Date.now()
    property var removingIds: ({})
    property var liveNotifications: ({})
    property var notificationLocks: ({})
    property var popupQueueIds: []

    readonly property int count: items.count
    readonly property bool hasNotifications: count > 0
    property var popupEntry: null
    property int popupId: -1
    property int popupStartedAtMs: 0
    property int popupExpiresAtMs: 0
    property int lastNowMs: nowMs
    property int popupTimeoutId: -1

    Timer {
        id: popupTimeoutTimer
        repeat: false
        onTriggered: root.timeoutActivePopup()
    }

    function buildEntry(notification) {
        const now = Date.now();
        const popupDurationMs = notification.expireTimeout > 0
            ? Math.max(3000, Math.round(notification.expireTimeout * 1000))
            : Config.notifications.popupDuration;
        return {
            id: notification.id,
            appName: notification.appName,
            appIcon: notification.appIcon,
            summary: notification.summary,
            body: notification.body,
            image: notification.image,
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
        popupTimeoutId = entry ? entry.id : -1;

        popupTimeoutTimer.stop();
        if (entry)
            popupTimeoutTimer.interval = Math.max(1, popupExpiresAtMs - nowMs);
        if (entry)
            popupTimeoutTimer.start();
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

    function timeoutActivePopup() {
        if (popupId === -1 || popupTimeoutId !== popupId)
            return;
        if (popupExpiresAtMs > 0 && nowMs < popupExpiresAtMs)
            return;
        hideActivePopup();
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

        if (notification)
            notification.dismiss();
        else
            delete removingIds[id];
        releaseNotification(id);
        if (wasActive)
            activateNextPopup();
    }

    function clearAll() {
        const currentIds = [];
        for (let index = 0; index < items.count; index++)
            currentIds.push(items.get(index).id);
        items.clear();
        popupQueueIds = [];
        setPopupEntry(null);
        for (let index = 0; index < currentIds.length; index++) {
            const id = currentIds[index];
            const notification = liveNotifications[id];
            removingIds[id] = true;
            if (notification)
                notification.dismiss();
            else
                delete removingIds[id];
            releaseNotification(id);
        }
    }


    function reconcilePopupState() {
        if (popupId !== -1 && popupExpiresAtMs > 0 && nowMs >= popupExpiresAtMs)
            hideActivePopup();
        activateNextPopup();
    }
    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.lastNowMs = root.nowMs;
            root.nowMs = Date.now();
            root.reconcilePopupState();
        }
    }
}
