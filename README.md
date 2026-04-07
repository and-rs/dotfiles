# Dotfiles

<img width="2559" height="1599" alt="image" src="https://github.com/user-attachments/assets/515adecf-da7b-4a31-8d04-e94efae7008c" />
<img width="2559" height="1598" alt="image" src="https://github.com/user-attachments/assets/35cd4461-017e-4b89-9d54-2883f19818f5" />

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
- CLI tooling: direnv, zoxide, aichat, fastfetch, topiary
- Themes and palettes: Neovim, Ghostty, Kitty, Alacritty, fastfetch, rofi, bat

## Structure

- `install.conf.yaml` - Dotbot link map and OS-specific targets
- `common/` - shared config used across platforms
- `nixos/` - Linux-specific configs
- `macos/` - macOS-specific configs
- `scripts/` - helper scripts and command wrappers
- `utils/` - random things

## Install

```sh
dotbot -c install.conf.yaml
```

IIt handles macos and linux specific configs.

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
- Aichat and LLM helpers
- Zoxide, direnv, and completion setup

### Terminal workflow

- Shared terminal themes and font configs
- Consistent palettes across Ghostty, Kitty, Alacritty, Neovim, and Fastfetch

## Notes

- The repo is intentionally opinionated; it is optimized for a specific
  workflow, not for generic portability.
- Several configs assume availability of external tools, review my
  [nix setup](https://github.com/and-rs/nixed)
- Also check my [nvim setup](https://github.com/and-rs/nvim)
