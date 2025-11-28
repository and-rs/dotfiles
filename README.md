# dotfiles

<img width="2560" height="1600" alt="image" src="https://github.com/user-attachments/assets/16f82de3-7f0b-4063-b3aa-23a450b8b110" />

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
