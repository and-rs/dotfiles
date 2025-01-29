{ ... }: {
  imports = [ ./tooling.nix ./packages.nix ];

  home.username = "dagger";
  home.homeDirectory = "/home/dagger";
  home.stateVersion = "24.11";

  #programs.zsh.enable = true;
  programs.neovim.defaultEditor = true;
  programs.home-manager.enable = true;
}
