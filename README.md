# Dotfiles

<img width="2559" height="1599" alt="image" src="https://github.com/user-attachments/assets/515adecf-da7b-4a31-8d04-e94efae7008c" />
<img width="2560" height="1600" alt="image" src="https://github.com/user-attachments/assets/25f5b4ad-aa8c-4a95-9b67-d965fc502849" />
<img width="2560" height="1600" alt="image" src="https://github.com/user-attachments/assets/bb92d0dd-922b-48fa-8cc1-88ff1ad8f3a6" />

My super baller dotfiles for Linux and macOS, with a strong bias toward a tiled, keyboard-driven workflow, custom shell tooling, and consistent theming across terminals, editors, and desktop components.

## What this repo configures

- Shell: Nushell
- Terminal emulators: Ghostty, Kitty, Alacritty
- Window managers / compositors:
  - Linux: Niri, Quickshell, Hypridle, Hyprlock, Rofi
  - macOS: Aerospace
- File management: Yazi
- CLI tooling: direnv, zoxide, pi, opencode, fastfetch, topiary
- Themes and palettes: Neovim, Ghostty, Kitty, Alacritty, fastfetch, rofi, bat

## Structure

Chezmoi source tree (home-shaped):

- `.chezmoiignore` - skip non-dotfile paths and OS-specific targets
- `.chezmoitemplates/` - Linux vs Darwin kitty / ghostty / alacritty bodies
- `dot_config/` - `~/.config`
- `dot_pi/` - `~/.pi`
- `dot_local/` - `~/.local`
- `utils/` - scripts and tooling, not deployed
- `wallpapers/` - not deployed

## Install

```sh
mkdir -p ~/.config/chezmoi
printf 'sourceDir = "%s/Vault/personal/dotfiles"\n' "$HOME" > ~/.config/chezmoi/chezmoi.toml
chezmoi apply
```

`just apply`, `just diff`, and `just status` wrap chezmoi.

## Highlights

### Linux desktop

- Niri window manager configuration with workspace rules, keybindings, and layer rules
- Quickshell bar, notifications, OSD, tray, battery, and recording widgets
- Idle / lock handling through Hypridle and Hyprlock
- Rofi launcher and power menu integration

### Shell workflow

- Nushell configuration with custom prompt, keybinds, history tooling, git helpers, and file utilities
- Pi and shell LLM helpers
- Zoxide, direnv, and completion setup

### Terminal workflow

- Shared terminal themes and font configs
- Consistent palettes across Ghostty, Kitty, Alacritty, Neovim, and Fastfetch

## Switching themes

These are all the places that need to change for a full theme swap:

- `.chezmoitemplates/ghostty-linux` + `ghostty-darwin` — `config-file = themes/<name>`
- `.chezmoitemplates/kitty-linux` + `kitty-darwin` — `include ./themes/<name>.conf`
- `.chezmoitemplates/alacritty-linux` + `alacritty-darwin` — `import = ["themes/<name>.toml"]`
- `dot_config/alacritty/themes/` — create theme file if it doesn't exist
- `dot_config/nushell/config.nu` — `BAT_THEME`
- `dot_config/quickshell/Bar/Config.qml` — `_dark` and `_light` palette blocks
- `dot_config/rofi/monochrome.rasi` — `color0` through `color4` + `text`
- `dot_config/niri/config.kdl` — backdrop, border active/inactive, focus ring, shadow colors

## Notes

- The repo is intentionally opinionated; it is optimized for a specific workflow, not for generic portability.
- Several configs assume availability of external tools, review my [nix setup](https://github.com/and-rs/nixed)
- Also check my [nvim setup](https://github.com/and-rs/nvim)
