{ pkgs ? import <nixpkgs> { } }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    cargo
    rustc
    rustfmt
    clippy
    rust-analyzer
    pkg-config
  ];

  buildInputs = with pkgs; [
    fontconfig
    freetype
    expat
    wayland
    libxkbcommon
    libpulseaudio
    linux-pam
  ];

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.vulkan-loader
    pkgs.wayland
  ];
  LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.linux-pam ];

  shellHook = ''
    export CARGO_TARGET_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/amane/target"
  '';
}
