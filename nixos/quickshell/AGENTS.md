# Quickshell Agent Notes

## Scope

These instructions apply to `nixos/quickshell/`.

## Workflow

- Do not use `qmllint`; it produces low-value noise for this setup.
- Prefer live bench scripts over fake debug paths.

## QML Style

- Use PascalCase component filenames.
- Do not add `.js` helper files.
- Do not add `qmldir` files.
- Do not add wrapper components.
- Keep global animation easing through `Config.curve`. Use existing
  `Config.durations`, `Config.spacing`, `Config.padding`, `Config.colors`, and
  `Config.radius`.

## NotificationV2 Rules

- `NotificationStore.qml` owns notification state and image cache ownership.
- `NotificationData.qml` stays pure data shaping helper.
- `NotificationLifecycle.qml` owns notification object
  retain/release/dismiss/expire/action/reply operations.
- `NotificationPopupQueue.qml` owns popup queue selection helpers.
- Do not move image cache ownership into lifecycle/data helpers.
- Keep action model roles type-stable; avoid nested QML object/list roles in
  `ListModel` entries.
- Keep popup enter/leave and popup-change animations using `Config.curve`.
- Timeout bar should follow popup content animation through shared parent, not
  own separate swap animation.

## Notification Test Bench

- Use `nu utils/test-notifs.nu --img` for image-only notification cases.
- Use `nu utils/quickshell-notif-bench.nu --delay 50` for Quickshell log-driven
  image cache testing.
- Bench must kill spawned Quickshell process group before exit.
- Relevant image cache log lines contain `[NotificationV2] image cache wrote`.
