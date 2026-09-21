# HARD RULES

These override every later section. Follow them in all new and edited QML.

## Readability

- No ternaries. Use if/return blocks.
- No oneliners. Split bindings, conditions, and returns across lines.
- Do not alias `SC.Config.*` into a shorter property just to rename it. Read the token at the use site. Store a local only when you transform it or branch on it.

## Group related values and pass them down

This is the highest-priority layout rule.

- Keep a family of values together on the owner (colors with colors, sizes with sizes). Do not scatter the same family across siblings, children, and inline bindings.
- Derive once in that group. Pass results into children as properties.
- Children must not re-read `SC.Config.colors` (or re-derive the same color) for values the parent already owns.
- Duplicate token reads in a parent/child tree are a bug: group on the parent and pass down.

# Quickshell Agent Notes

These rules apply to `dot_config/quickshell/`.

## Workflow

- Do not use `qmllint`; it produces low-value noise here.
- QML types come from Quickshell's live tooling VFS. Keep Quickshell running while editing types; do not commit generated VFS files or `.qmlls.ini`.
- If the user reports type-resolution diagnostics, remind them once to create `~/.config/quickshell/.qmlls.ini` while Quickshell is running.
- Pure-QML modules use generated metadata. Native plugins may keep a `qmldir` and need matching `.qmltypes` metadata when `qmlls` cannot see their types.

## QML

- Use PascalCase component filenames; do not add wrapper components.
- Under `ComponentBehavior: Bound`, declare Repeater inputs as required properties; in nested delegates, qualify outer values via the outer delegate's id.
- When consuming custom QML components, use their concrete type. Use `Item` or `var` only when intentionally untyped.
- Keep QML-imported `.js` helpers pure and cover them with Bun tests.
- Import `qs.Config as SC` and access shared tokens through `SC.Config`. Use `SC.Config.curve`, durations, spacing, padding, colors, and radii; use `Easing.Linear` only for progress values.
- Use `DirectScrollList` for new compact scroll panels; do not duplicate its wheel, bounds, edge-stop, or overflow-indicator behavior.
- Use `LoaderIcon` beside in-progress feedback text; do not create other spinners.
- Reserve `LoaderIcon` size in layout height so showing or hiding it does not shift siblings.

## Performance

- Lazy-load inactive panels with `Loader`; `visible: false` leaves bindings, timers, and models active.
- Keep delegates small and pause pooled delegate timers/animations. Use `reuseItems` only when state lives in the model/service.
- Do not animate view-controlled geometry (`x`, `y`, width, height) as entries change; reserve space and animate card-local feedback instead.
- Load local images asynchronously with bounded `sourceSize`; avoid expensive delegate effects unless benchmarked.

## Popups

- Keep popup content inside its window.
- Use `grabFocus` for outside clicks.
- Sync popup close state with its button.
- Animate one height value.
- Avoid clipping animated content.

## Verification

- Do not run unrelated tests for UI-only changes.
