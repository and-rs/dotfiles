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

```bash
mkdir -p ~/.config/chezmoi

# change this
printf 'sourceDir = "%s/actual/dir/dotfiles"\n' "$HOME" > ~/.config/chezmoi/chezmoi.toml
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

Themes are swappable palettes selected by the `theme` value in `.chezmoidata.toml`.
Change it to any palette name, then apply the configuration:

```toml
theme = "tokyo-night"
```

```bash
just apply
```

Each palette defines its colors, including `bg`. The `surface1` through
`surface5` colors are generated automatically by adjusting the HSL lightness of
`bg` in nonlinear steps: 3%, 9%, 17%, 26%, and 36%. `surface1` is closest to
`bg`, while `surface5` is farthest away. Dark backgrounds become lighter and
light backgrounds become darker. Non-neutral palettes gently pull hue and
saturation toward their `blue` color so the surfaces retain their theme tint
instead of becoming neutral gray. They do not need to be defined in
`.chezmoidata.toml`.

## Notes

- The repo is intentionally opinionated; it is optimized for a specific workflow, not for generic portability.
- Several configs assume availability of external tools, review my [nix setup](https://github.com/and-rs/nixed)
- Also check my [nvim setup](https://github.com/and-rs/nvim)
