# Amane shell

A 32-pixel bar on each monitor, with Niri workspaces, a tiled-window minimap,
the active window title, and a local-time clock.
No autostart configuration is installed.

## Run

Deploy from the dotfiles repository:

```sh
chezmoi apply ~/.config/amane
~/.config/amane/launch.sh
```

The launcher uses Nix for native dependencies and Cargo for the build.
Build artifacts live in `$XDG_CACHE_HOME/amane/target` (normally `~/.cache/amane/target`).
The Amane CLI is not needed: this is an ordinary Cargo application with a pinned
framework revision and a committed dependency lockfile.

## Theme

`~/.config/amane/theme.json` is generated from the dotfiles palette.
Changes reload without rebuilding or restarting the shell. Atomic saves work.
Invalid edits retain the previous theme and print an error to stderr.
A missing or invalid theme at startup stops the shell with an error.

Colors accept `#RRGGBB` or `#RRGGBBAA`. `font_size` is in pixels, from 8 to 24.
Changing the font family also reloads live.

For temporary experiments, edit the generated JSON directly; a later chezmoi
apply will overwrite it. For persistent changes, edit `theme.json.tmpl` or the
shared palette and apply again.

Set `AMANE_THEME` to use another JSON file, including when running from this
repository:

```sh
AMANE_THEME=/absolute/path/to/theme.json bash dot_config/amane/executable_launch.sh
```

## Niri

The integration uses the official `niri-ipc` types and workspace/window state
helpers, pinned to Niri 26.04. It supports only the events needed by this bar.
`NIRI_SOCKET` must point to the running compositor.

- Workspaces are filtered per output and ordered by their current index.
- Clicks focus a stable workspace ID, not its changing index.
- Each output has an active workspace; keyboard focus is global.
- The title follows that output's active workspace, even when another output
  has keyboard focus.
- The minimap is a schematic of tiled columns and rows, not a desktop thumbnail.
  A solid tile has keyboard focus; an outlined tile is the workspace's active
  window. Floating windows count toward occupancy and titles, but are not drawn
  in the tiled minimap.
- Commands run off the UI thread, check replies, and time out after two seconds.
- A lost event stream clears stale state and reconnects from fresh snapshots.

No polling, shell commands, C++ plugins, or independent UI copies of focus state.

## Develop

From this directory:

```sh
nix-shell
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
cargo fmt --check
cargo run --locked
```

Theme, Niri state/event, socket-command, title, and minimap geometry tests do not
need a compositor. Rendering and live reload need a running Wayland compositor
and Vulkan driver. Stop the shell with Ctrl+C.
