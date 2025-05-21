# dotfiles

![Screenshot from 2025-05-20 19-13-41](https://github.com/user-attachments/assets/1c75107a-f37b-40f9-912b-4950e7329c74)

## For reference other important repos:
- [neovim](https://github.com/and-rs/nvim)
- [nix-darwin](https://github.com/and-rs/nix-darwin)
- [nixos](https://github.com/and-rs/nixos)

## I use too many things to list them here, but...
- Nvim is just better.
- Unix has always been better.
- Nothing is better than Zsh, Tmux and ~~Alacritty~~ Ghostty together.
- MacOS has been very nice lately, NixOS when I want full control. I just switch what I use for fun as long as I can use nix for package management.

Clone the repo
```sh
git clone https://github.com/and-rs/dotfiles.git
```

Using this repo with stow, linking the base `.config` and ignoring the rest
```sh
stow -t "$HOME" .
```

Linking the MacOS package.
```sh
stow -t "$HOME" -S macos
```

## Considerations
- `./utils/` and `./xorg/`:
    - These are NOT packages to stow, there is no point in linking them and stow will ignore them

- ```./macos```:
    - Symlinks for files that can also be used on nixos (eg. `.zshrc`)
    - Files that have specific changes for macos
    - Custom icons.
    I do this because I want to be able to have everything in one repo, and be linked by
    stow, make changes to one (for example) `.zshrc` and have the changes shared
    across nixos and macos.

- ```./xorg```:
    - X11 files that I might use if I go back to i3 in a hidpi laptop.

- My dependencies are managed by nixos and nix-darwin.
