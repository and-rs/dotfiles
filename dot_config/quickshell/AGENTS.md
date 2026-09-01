# Quickshell Agent Notes

## Scope

These instructions apply to `dot_config/quickshell/`.

## Workflow

- Do not use `qmllint`; it produces low-value noise for this setup.
- Prefer live bench scripts over fake debug paths.
- QML language-server types come from the live Quickshell tooling VFS. The
  generated `~/.config/quickshell/.qmlls.ini` points `qmlls` at that VFS via
  `General.buildDir` and at the config through `General.importPaths`.
- Keep Quickshell running while working on QML types so it can regenerate the
  VFS `qmldir` metadata. Do not commit the generated `.qmlls.ini`, VFS files,
  or hand-written `qmldir` files; restart or reload the language server after
  Quickshell regenerates its tooling metadata.
- When a component receives an instance of a custom QML component and accesses
  that component's custom properties or functions, type the property with the
  concrete QML type, not `Item` or `var`. Import the defining module with an
  alias and qualify the type, for example:
  `import qs.Bar.Status as Status` followed by
  `required property Status.StatusMenus controller`. This gives `qmlls` the
  component's generated property and function information. Use `Item` only
  when the consumer needs base `Item` members, and use `var` only when the
  value is intentionally untyped or can have unrelated runtime types.
- Native QML plugins need tool metadata in addition to runtime registration.
  If a plugin uses `qmlRegisterType()` and `qmlls` reports its type or import as
  missing, add a `<ModuleName>.qmltypes` file beside the plugin `qmldir` and
  reference it with `typeinfo <ModuleName>.qmltypes`. Generate it with
  `qmlplugindump` when necessary, or use `qmltyperegistrar` with
  `QML_ELEMENT` declarations when the plugin is migrated to that approach. A
  native plugin module is the exception to the no-`qmldir` rule: retain its
  `qmldir` with both the `plugin` and `typeinfo` entries. Pure QML directories
  should still rely on Quickshell's generated VFS metadata instead of adding a
  `qmldir` manually.

## QML Style

- Use PascalCase component filenames.
- QML-imported `.js` helpers must be pure and side-effect-free. Keep them free
  of QML object references and cover their behavior with Bun tests.
- Do not add `qmldir` files.
- Do not add wrapper components.
- For visual UI diagnosis, set `Config.debug.enabled` to `true`, reload
  Quickshell, then run `just debug-capture <target>`. It writes target-subtree,
  compositor, and runtime-log snapshots under `/tmp/quickshell-debug/`.
- Capture targets are registered by their owning host in `Debug.Capture`.
  Keep the generic capture service target-agnostic and add only target-specific
  open/close actions and items at the host.
- The capture utility retains the 10 newest directories. Override that limit
  with `QS_DEBUG_CAPTURE_RETAIN`; pass an explicit output directory to keep a
  capture outside the managed temporary directory.
- Keep global animation easing through `Config.curve`. Use existing
  `Config.durations`, `Config.spacing`, `Config.padding`, `Config.colors`, and
  `Config.radius`.
- Every animation must use `Config.curve` and a `Config.durations` value.
- Use `DirectScrollList` for compact scrollable panels. It owns amplified
  mouse/touchpad wheel input, origin-and-margin-aware bounds, hard edge stops,
  and a persistent custom overflow indicator. Do not recreate this behavior locally or
  use a full-area `MouseArea` solely to intercept wheel input.

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

- Use `nu dot_config/quickshell/utils/test-notifs.nu --img` for image-only notification cases.
- Use `nu dot_config/quickshell/utils/test-notifs.nu --count 50 --delay 20` to stress sidebar scrolling.
- Use `nu dot_config/quickshell/utils/quickshell-notif-bench.nu --delay 50` for Quickshell log-driven
  image cache testing.
- Bench must kill spawned Quickshell process group before exit.
- Relevant image cache log lines contain `[NotificationV2] image cache wrote`.
