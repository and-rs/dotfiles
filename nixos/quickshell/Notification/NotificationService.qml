pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
  id: root

  property var activeNotifications: []

  signal showNotification(notification: var)
  signal hideNotification(id: var)
  signal clearAll

  NotificationServer {
    actionIconsSupported: true
    actionsSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    bodyMarkupSupported: true
    bodySupported: true
    imageSupported: true
    keepOnReload: false
    persistenceSupported: true

    onNotification: notification => {
      activeNotifications = [...activeNotifications, notification];
      root.showNotification(notification);
    }
  }

  function dismiss(notificationId) {
    var notification = activeNotifications.find(n => n.id === notificationId);
    if (notification?.dismiss) {
      notification.dismiss();
    }
    root.hideNotification(notificationId);
    activeNotifications = activeNotifications.filter(n => n.id !== notificationId);
  }

  function dismissAll() {
    activeNotifications.forEach(n => {
      try {
        n.dismiss?.();
      } catch (e) {
        console.warn("Failed to dismiss notification:", n.id, e);
      }
    });
    activeNotifications = [];
    root.clearAll();
  }
}
