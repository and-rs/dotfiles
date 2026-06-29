import qs.Sidebar

SidebarHost {
  id: root

  title: "Notifications"

  NotificationSidebarActions {
    onClearAllRequested: NotificationStore.clear()
    onCloseRequested: notificationId => NotificationStore.removeNotification(notificationId)
  }
}
