# dotfiles

<img width="2559" height="1599" alt="image" src="https://github.com/user-attachments/assets/9dca69e7-be3b-4362-83cd-b376148edea4" />

## These are my goats (and their links for my configs)

- [NixOS & Nix Darwin](https://github.com/and-rs/nixos)
- [neovim](https://github.com/and-rs/nvim)
- ghostty
- tmux
- yazi
- niri
- zsh (perhaps not anymore, I am trying out fish and nushell)

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
