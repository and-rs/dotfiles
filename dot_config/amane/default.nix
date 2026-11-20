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

  preCheck = ''
    export LD_LIBRARY_PATH="${
      pkgs.lib.makeLibraryPath [ pkgs.wayland ]
    }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  postInstall = ''
    mv "$out/bin/amane_shell" "$out/bin/amane_shell_release"
    # On non-NixOS, prefer Mesa from the same package set while retaining host ICD discovery.
    wrapProgram "$out/bin/amane_shell_release" \
      --run 'if [ ! -e /etc/NIXOS ]; then
        export VK_ADD_DRIVER_FILES="${pkgs.mesa}/share/vulkan/icd.d''${VK_ADD_DRIVER_FILES:+:$VK_ADD_DRIVER_FILES}"
      fi' \
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
