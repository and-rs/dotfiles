{
  pkgs ? import <nixpkgs> { },
}:

pkgs.rustPlatform.buildRustPackage {
  pname = "amane_shell";
  version = "0.1.0";

  src = pkgs.lib.fileset.toSource {
    root = ./.;
    fileset = pkgs.lib.fileset.unions [
      ./Cargo.toml
      ./Cargo.lock
      ./src
    ];
  };

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes."amane-0.1.2" = "sha256-fU20wtIC9wlOP9mvcCboSdB67zVq2ZSe9FjD7mwyHMc=";
  };

  nativeBuildInputs = with pkgs; [
    pkg-config
    makeWrapper
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

  LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.linux-pam ];

  postInstall = ''
    mv "$out/bin/amane_shell" "$out/bin/amane_shell_release"
    wrapProgram "$out/bin/amane_shell_release" \
      --prefix LD_LIBRARY_PATH : "${
        pkgs.lib.makeLibraryPath [
          pkgs.vulkan-loader
          pkgs.wayland
        ]
      }" \
      --prefix PATH : "${
        pkgs.lib.makeBinPath [
          pkgs.wireplumber
          pkgs.brightnessctl
        ]
      }"
  '';

  meta = {
    mainProgram = "amane_shell_release";
    platforms = pkgs.lib.platforms.linux;
  };
}
