# Dotfiles

<img width="2559" height="1599" alt="image" src="https://github.com/user-attachments/assets/515adecf-da7b-4a31-8d04-e94efae7008c" />
<img width="2560" height="1600" alt="image" src="https://github.com/user-attachments/assets/25f5b4ad-aa8c-4a95-9b67-d965fc502849" />
<img width="2560" height="1600" alt="image" src="https://github.com/user-attachments/assets/bb92d0dd-922b-48fa-8cc1-88ff1ad8f3a6" />


My super baller dotfiles for Linux and macOS, with a strong bias toward a tiled,
keyboard-driven workflow, custom shell tooling, and consistent theming across
terminals, editors, and desktop components.

## What this repo configures

- Shell: Nushell
- Terminal emulators: Ghostty, Kitty, Alacritty
- Window managers / compositors:
  - Linux: Niri, Quickshell, Hypridle, Hyprlock, Rofi
  - macOS: Aerospace
- File management: Yazi
- CLI tooling: direnv, zoxide, pi, fastfetch, topiary
- Themes and palettes: Neovim, Ghostty, Kitty, Alacritty, fastfetch, rofi, bat

## Structure

- `install.conf.yaml` - Dotbot link map and OS-specific targets
- `common/` - shared config used across platforms
- `nixos/` - Linux-specific configs
- `macos/` - macOS-specific configs
- `utils/` - scripts and tooling for work Ubuntu / Nix environments

## Install

```sh
dotbot -c install.conf.yaml
```

It handles macOS and Linux specific configs.

## Highlights

### Linux desktop

- Niri window manager configuration with workspace rules, keybindings, and layer
  rules
- Quickshell bar, notifications, OSD, tray, battery, and recording widgets
- Idle / lock handling through Hypridle and Hyprlock
- Rofi launcher and power menu integration

### Shell workflow

- Nushell configuration with custom prompt, keybinds, history tooling, git
  helpers, and file utilities
- Pi and shell LLM helpers
- Zoxide, direnv, and completion setup

### Terminal workflow

- Shared terminal themes and font configs
- Consistent palettes across Ghostty, Kitty, Alacritty, Neovim, and Fastfetch

## Switching themes

These are all the places that need to change for a full theme swap:

- `nixos/ghostty/config.ghostty` + `macos/ghostty/config.ghostty` — `config-file = themes/<name>`
- `nixos/kitty/kitty.conf` + `macos/kitty/kitty.conf` — `include ./themes/<name>.conf`
- `nixos/alacritty/alacritty.toml` + `macos/alacritty/alacritty.toml` — `import = ["themes/<name>.toml"]`
- `common/alacritty/themes/` — create theme file if it doesn't exist
- `common/nushell/config.nu` — `BAT_THEME`
- `nixos/quickshell/Bar/Config.qml` — `_dark` and `_light` palette blocks
- `nixos/rofi/monochrome.rasi` — `color0` through `color4` + `text`
- `nixos/niri/config.kdl` — backdrop, border active/inactive, focus ring, shadow colors

## Notes

- The repo is intentionally opinionated; it is optimized for a specific
  workflow, not for generic portability.
- Several configs assume availability of external tools, review my
  [nix setup](https://github.com/and-rs/nixed)
- Also check my [nvim setup](https://github.com/and-rs/nvim)
