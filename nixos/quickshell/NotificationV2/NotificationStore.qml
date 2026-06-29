pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.Bar

Singleton {
  id: root

  readonly property int count: entries.count
  readonly property ListModel entries: ListModel {
  }
  readonly property bool hasNotifications: count > 0
  readonly property string imageCacheDir: imageCachePrefix
  readonly property string imageCachePrefix: Quickshell.cachePath("notification-v2-")
  property var liveNotifications: ({})
  property var notificationLocks: ({})
  property var popupEntry: null
  property real popupExpiresAtMs: 0
  property int popupId: -1
  property var popupQueueIds: []
  property real popupStartedAtMs: 0
  property var removingIds: ({})

  function activateNextPopup(): void {
    if (popupId !== -1)
      return;

    const nextPopup = NotificationPopupQueue.takeNext(popupQueueIds, entries);
    popupQueueIds = nextPopup.queue;
    if (nextPopup.index === -1) {
      setPopupEntry(null);
      return;
    }
    const current = entries.get(nextPopup.index);
    const expiresAtMs = Date.now() + current.popupDurationMs;
    const nextEntry = NotificationData.withPopupUntil(current, expiresAtMs);
    setEntry(nextPopup.index, nextEntry);
    setPopupEntry(nextEntry);
    return;
  }
  function addNotification(notification: var): var {
    if (!notification)
      return null;

    notification.tracked = true;
    if (liveNotifications[notification.id] !== notification)
      notification.closed.connect(reason => markClosed(notification.id, reason));

    delete removingIds[notification.id];
    retainNotification(notification.id, notification);

    const current = getById(notification.id);
    const nextEntry = current ? NotificationData.mergeNotification(current, notification) : NotificationData.fromNotification(notification);
    const cachedEntry = cacheEntryImages(nextEntry);
    const savedEntry = upsertEntry(cachedEntry);

    enqueuePopupId(notification.id);
    activateNextPopup();
    return savedEntry;
  }
  function cacheEntryImages(entry: var): var {
    const previous = getById(entry.id);
    console.log("[NotificationV2] image intake", "id=" + entry.id, "appIcon=" + String(entry.appIcon || ""), "image=" + String(entry.image || ""));
    const cachedAppIcon = previous && previous.sourceAppIcon === entry.appIcon ? previous.cachedAppIcon : cacheImage(entry.appIcon, String(entry.id) + "-icon");
    const cachedImage = previous && previous.sourceImage === entry.image ? previous.cachedImage : cacheImage(entry.image, String(entry.id));
    const nextEntry = cloneObject(entry);
    nextEntry.sourceAppIcon = entry.appIcon;
    nextEntry.sourceImage = entry.image;
    nextEntry.appIcon = cachedAppIcon;
    nextEntry.image = cachedImage;
    nextEntry.cachedAppIcon = cachedAppIcon;
    nextEntry.cachedImage = cachedImage;
    return nextEntry;
  }
  function cacheImage(image: var, cacheKey: string): string {
    const sourcePath = localImagePath(image);
    if (!sourcePath) {
      console.log("[NotificationV2] image cache passthrough", "key=" + cacheKey, "value=" + String(image || ""));
      return image ? String(image) : "";
    }
    const reader = Qt.createQmlObject('import Quickshell.Io; FileView { blockAllReads: true; printErrors: false; path: "" }', root);
    const writer = Qt.createQmlObject('import Quickshell.Io; FileView { blockWrites: true; printErrors: false; path: "" }', root);

    try {
      reader.path = sourcePath;
      const data = reader.data();
      if (!data || data.byteLength === 0) {
        console.log("[NotificationV2] image cache read-empty", "key=" + cacheKey, "source=" + sourcePath);
        return "";
      }

      const targetPath = imageCachePrefix + cacheKey + "-" + Date.now() + "." + imageExtension(sourcePath);
      writer.path = targetPath;
      writer.setData(data);
      console.log("[NotificationV2] image cache wrote", "key=" + cacheKey, "bytes=" + data.byteLength, "target=" + targetPath);
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
    cleanupCachedFile(entry?.cachedImage ?? "");
    cleanupCachedFile(entry?.cachedAppIcon ?? "");
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
    const currentEntries = [];
    for (let index = 0; index < entries.count; index++)
      currentEntries.push({
        id: entries.get(index).id,
        closed: entries.get(index).closed
      });

    entries.clear();
    popupQueueIds = [];
    setPopupEntry(null);

    for (let index = 0; index < currentEntries.length; index++) {
      const entry = currentEntries[index];
      const notification = liveNotifications[entry.id];
      removingIds[entry.id] = true;
      if (notification && !entry.closed)
        NotificationLifecycle.dismiss(notification);
      else
        delete removingIds[entry.id];
      releaseNotification(entry.id);
    }

    cleanupImageCacheDirectory();
  }
  function clearPopup(id: int): void {
    const index = indexOfId(id);
    if (index !== -1) {
      const nextEntry = NotificationData.withPopupUntil(entries.get(index), 0);
      setEntry(index, nextEntry);
    }

    if (popupId === id) {
      const nextPopup = NotificationPopupQueue.takeNext(popupQueueIds, entries);
      popupQueueIds = nextPopup.queue;
      if (nextPopup.index === -1) {
        setPopupEntry(null);
        return;
      }

      const current = entries.get(nextPopup.index);
      const expiresAtMs = Date.now() + current.popupDurationMs;
      const nextEntry = NotificationData.withPopupUntil(current, expiresAtMs);
      setEntry(nextPopup.index, nextEntry);
      setPopupEntry(nextEntry);
    }
  }
  function cloneObject(value: var): var {
    const clone = {};
    if (!value)
      return clone;
    for (const key in value)
      clone[key] = value[key];
    return clone;
  }
  function enqueuePopupId(id: int): void {
    popupQueueIds = NotificationPopupQueue.enqueue(popupQueueIds, id);
  }
  function expirePopup(id: int): void {
    clearPopup(id);
    const notification = liveNotifications[id];
    if (notification)
      NotificationLifecycle.expire(notification);
  }
  function getById(id: int): var {
    const index = indexOfId(id);
    return index === -1 ? null : entries.get(index);
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
    for (let index = 0; index < entries.count; index++) {
      if (entries.get(index).id === id)
        return index;
    }
    return -1;
  }
  function invokeAction(id: int, actionIndex: int): void {
    const notification = liveNotifications[id];
    if (popupId === id)
      clearPopup(id);
    NotificationLifecycle.invoke(notification, actionIndex);
  }
  function invokeDefaultAction(id: int): void {
    const entry = getById(id);
    if (!entry || entry.defaultActionIndex === -1)
      return;
    invokeAction(id, entry.defaultActionIndex);
  }
  function invokeVisibleAction(id: int, visibleActionIndex: int): void {
    const entry = getById(id);
    const visibleActions = JSON.parse(String(entry?.visibleActionsJson || "[]"));
    if (!entry || visibleActionIndex < 0 || visibleActionIndex >= visibleActions.length)
      return;
    invokeAction(id, visibleActions[visibleActionIndex].index);
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
      return;
    }

    const index = indexOfId(id);
    if (index === -1)
      return;

    const wasActive = popupId === id;
    removeQueuedPopupId(id);
    const nextEntry = NotificationData.withClosedState(entries.get(index), String(reason));
    setEntry(index, nextEntry);
    releaseNotification(id);

    if (wasActive) {
      setPopupEntry(null);
      activateNextPopup();
    }
  }
  function queueIndexOfId(id: int): int {
    return NotificationPopupQueue.indexOf(popupQueueIds, id);
  }
  function releaseNotification(id: int): void {
    const released = NotificationLifecycle.release(notificationLocks, liveNotifications, id);
    notificationLocks = released.locks;
    liveNotifications = released.live;
  }
  function removeEntryOnly(id: int): void {
    const index = indexOfId(id);
    if (index === -1)
      return;

    const entry = entries.get(index);
    entries.remove(index, 1);
    cleanupEntryAssets(entry);
  }
  function removeNotification(id: int): void {
    const entry = getById(id);
    if (!entry)
      return;

    const wasActive = popupId === id;
    const notification = liveNotifications[id];
    removingIds[id] = true;
    removeQueuedPopupId(id);
    removeEntryOnly(id);

    if (notification && !entry.closed)
      NotificationLifecycle.dismiss(notification);
    else
      delete removingIds[id];

    releaseNotification(id);
    if (wasActive) {
      setPopupEntry(null);
      activateNextPopup();
    }
  }
  function removeQueuedPopupId(id: int): void {
    popupQueueIds = NotificationPopupQueue.remove(popupQueueIds, id);
  }
  function retainNotification(id: int, notification: var): void {
    const retained = NotificationLifecycle.retain(root, notificationLocks, liveNotifications, id, notification);
    notificationLocks = retained.locks;
    liveNotifications = retained.live;
  }
  function sendInlineReply(id: int, text: string): void {
    const notification = liveNotifications[id];
    if (popupId === id)
      clearPopup(id);
    NotificationLifecycle.sendInlineReply(notification, text);
  }
  function setEntry(index: int, entry: var): void {
    entries.set(index, entry);
    if (popupId === entry.id)
      popupEntry = entry;
  }
  function setPopupEntry(entry: var): void {
    popupEntry = entry;
    popupId = entry ? entry.id : -1;
    popupStartedAtMs = entry ? Date.now() : 0;
    popupExpiresAtMs = entry ? popupStartedAtMs + entry.popupDurationMs : 0;
  }
  function trimToLimit(): void {
    while (entries.count > Config.notifications.historyLimit) {
      const entry = entries.get(entries.count - 1);
      removeQueuedPopupId(entry.id);
      entries.remove(entries.count - 1, 1);
      cleanupEntryAssets(entry);
      releaseNotification(entry.id);
      if (popupId === entry.id)
        setPopupEntry(null);
    }
  }
  function updateNotification(notification: var): var {
    return addNotification(notification);
  }
  function upsertEntry(entry: var): var {
    const index = indexOfId(entry.id);
    if (index === -1)
      entries.insert(0, entry);
    else {
      cleanupReplacedAssets(entries.get(index), entry);
      setEntry(index, entry);
    }

    trimToLimit();
    return entry;
  }

  Component.onCompleted: cleanupImageCacheDirectory()
}
