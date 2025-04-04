{ ... }: {
  home.username = "and-rs";
  home.homeDirectory = "/home/and-rs";
  home.stateVersion = "24.11";

  programs.neovim.defaultEditor = true;
  programs.home-manager.enable = true;
}
