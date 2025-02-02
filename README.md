# dotfiles
![image](https://github.com/JuanBaut/dotfiles/assets/90160941/a776fc3f-8a46-448d-abe7-8f7c13b8bc72)

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
git clone
```

Use this repo with stow.
```sh
stow -t "$HOME" .
```

Setup macOS.
```sh
stow -t "$HOME" -S macos
```

## Considerations
- ```./macos```:
    - Symlinks for files that can also be used on nixos
    - Files that have specific changes for macos
    - Custom icons.
    I do this because I want to be able to have everything in one repo, and be linked by
    stow, make changes to one (for example) .zshrc and have the changes shared
    across nixos and macos.

- ```./tower/```
    - NixOS setup that I use on a desktop sometimes
    - Not usable yet

- ```./xorg```:
    - X11 files that I might use if I go back to i3 in a hidpi laptop.

- ```./.local/share/icons/macOS```:
    - It is a custom hyprland cursor.

- My dependencies are managed by nixos and nix-darwin.
