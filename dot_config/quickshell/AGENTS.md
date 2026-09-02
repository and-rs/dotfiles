# Quickshell Agent Notes

These rules apply to `dot_config/quickshell/`.

## Workflow

- Do not use `qmllint`; it produces low-value noise here.
- QML types come from Quickshell's live tooling VFS. Keep Quickshell running
  while editing types; do not commit generated VFS files or `.qmlls.ini`.
- Pure-QML modules use generated metadata. Native plugins may keep a `qmldir`
  and need matching `.qmltypes` metadata when `qmlls` cannot see their types.
- For visual diagnosis, enable `Config.debug.enabled`, reload Quickshell, and
  run `just debug-capture <target>`.

## QML

- Use PascalCase component filenames; do not add wrapper components.
- Under `ComponentBehavior: Bound`, declare Repeater inputs as required
  properties; in nested delegates, qualify outer values via the outer
  delegate's id.
- When consuming custom QML components, use their concrete type. Use `Item`
  or `var` only when intentionally untyped.
- Keep QML-imported `.js` helpers pure and cover them with Bun tests.
- Capture targets belong to their owning host; keep the capture service generic.
- Use `Config.curve`, `Config.durations`, and shared spacing, padding, color,
  and radius tokens for new UI. Use `Easing.Linear` only for progress values.
- Use `DirectScrollList` for new compact scroll panels; do not duplicate its
  wheel, bounds, edge-stop, or overflow-indicator behavior.

## Performance

- Prefer asynchronous, event-driven I/O after startup; do not add blocking UI
  work.
- Lazy-load inactive panels with `Loader`; `visible: false` leaves bindings,
  timers, and models active.
- Keep delegates small and pause pooled delegate timers/animations. Use
  `reuseItems` only when state lives in the model/service.
- Do not animate view-controlled geometry (`x`, `y`, width, height) as entries
  change; reserve space and animate card-local feedback instead.
- Load local images asynchronously with bounded `sourceSize`; avoid expensive
  delegate effects unless benchmarked.
- Batch state updates, keep hot bindings simple, and measure before optimizing.

## NotificationV2

- `NotificationStore.qml` owns archive state, the `ScriptModel` timeline, popup
  scheduling, and image-cache state. Live notification objects remain owned by
  Quickshell while their records are open.
- `NotificationData.qml` shapes records and may request cache work from the
  Store; it must not own cache state.
- `NotificationLifecycle.qml` owns dismiss, expire, action, and reply
  operations. `NotificationPopupQueue.qml` owns popup selection helpers.
- Keep timeline records type-stable with unique `id` values; replace the
  records array when updating `ScriptModel` projections.
- Keep popup enter/leave and popup-change animations on the shared content
  animation; the timeout bar must not animate swaps independently.

## Notification Bench

- Use `nu dot_config/quickshell/utils/test-notifs.nu --img` for image-only
  cases.
- Use `nu dot_config/quickshell/utils/test-notifs.nu --count 50 --delay 20` to
  stress sidebar scrolling.
- Use `nu dot_config/quickshell/utils/quickshell-notif-bench.nu --delay 50` for
  image-cache testing; clean spawned Quickshell process groups on exit.
