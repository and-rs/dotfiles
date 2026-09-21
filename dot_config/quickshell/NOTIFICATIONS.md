## NotificationV2

- `NotificationStore.qml` owns archive state, the `ScriptModel` timeline, popup scheduling, and image-cache state. Live notification objects remain owned by Quickshell while their records are open.
- `NotificationData.qml` shapes records and may request cache work from the Store; it must not own cache state.
- `NotificationLifecycle.qml` owns dismiss, expire, action, and reply operations. `NotificationPopupQueue.qml` owns popup selection helpers.
- Keep timeline records type-stable with unique `id` values; replace the records array when updating `ScriptModel` projections.
- Keep popup enter/leave and popup-change animations on the shared content animation; the timeout bar must not animate swaps independently.

## Notification Bench

- Use `nu dot_config/quickshell/utils/test-notifs.nu --img` for image-only cases.
- Use `nu dot_config/quickshell/utils/test-notifs.nu --count 50 --delay 20` to stress sidebar scrolling.
- Use `nu dot_config/quickshell/utils/quickshell-notif-bench.nu --delay 50` for image-cache testing; clean spawned Quickshell process groups on exit.
