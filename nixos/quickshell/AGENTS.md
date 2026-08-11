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
- Every animation must use `Config.curve` and a `Config.durations` value.

## Performance

- Keep the UI thread non-blocking: do not use blocking `FileView` reads/writes
  after shell startup; prefer asynchronous, event-driven work.
- Lazy-load and unload inactive panels with `Loader`; `visible: false` still
  leaves bindings, timers, and models active.
- Keep list delegates small. Use `reuseItems` only when delegate state lives in
  the model/service, and pause timers/animations while delegates are pooled.
- Do not animate geometry controlled by a view (`x`, `y`, width, or height) as
  entries are inserted or removed. Reserve async content space up front and
  use card-local visual feedback instead.
- Load local images asynchronously and bound decode memory with `sourceSize`.
  Avoid mipmaps, clipping, layers, and effects in delegates unless benchmarked.
- Batch model/state updates and keep hot bindings simple. Avoid per-frame JS
  and large whole-model replacements during bursts.
- Prefer opaque, non-overlapping primitives. Use `visible: false` or unload
  content that is not meant to render.
- Measure before optimizing: use the notification bench, QML Profiler, and
  temporary `QSG_RENDER_TIMING=1` / `QSG_RENDERER_DEBUG=render` diagnostics.

## NotificationV2 Rules

- `NotificationStore.qml` owns archive state, the `ScriptModel` timeline, popup
  scheduling, and image cache ownership. Live notification objects stay owned by
  Quickshell while their records are open.
- `NotificationData.qml` stays pure data shaping helper.
- `NotificationLifecycle.qml` owns notification dismiss/expire/action/reply
  operations.
- `NotificationPopupQueue.qml` owns popup queue selection helpers.
- Do not move image cache ownership into lifecycle/data helpers.
- Keep action model roles type-stable; avoid nested QML object/list roles in
  `ListModel` entries.
- Use `ScriptModel` for timeline projections; records need stable unique `id`
  values and all model changes must replace the records array.
- Keep popup enter/leave and popup-change animations using `Config.curve`.
- Timeout bar should follow popup content animation through shared parent, not
  own separate swap animation.

## Notification Test Bench

- Use `nu utils/test-notifs.nu --img` for image-only notification cases.
- Use `nu utils/quickshell-notif-bench.nu --delay 50` for Quickshell log-driven
  image cache testing.
- Bench must kill spawned Quickshell process group before exit.
- Relevant image cache log lines contain `[NotificationV2] image cache wrote`.
