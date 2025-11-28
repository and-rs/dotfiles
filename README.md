# dotfiles

## These are my goats (and their links for my configs)

- [NixOS & Nix Darwin](https://github.com/and-rs/nixos)
- [neovim](https://github.com/and-rs/nvim)
- ghostty
- tmux
- yazi
- niri
- zsh

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
stow -t "$HOME" -S macos zden
```
