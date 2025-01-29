{ pkgs, ... }: {
  home.packages = with pkgs; [
    bun
    deno
    yarn
    corepack_latest
    pnpm-shell-completion
    nodePackages_latest.nodejs

    emmet-ls
    prettierd
    typescript
    nodePackages_latest.eslint
    nodePackages_latest.prettier
    vscode-langservers-extracted
    tailwindcss-language-server
    nodePackages_latest.typescript-language-server
    nodePackages_latest.vscode-json-languageserver

    sumneko-lua-language-server
    luajitPackages.luarocks
    stylua
    lua

    python312Packages.pip
    python312Packages.virtualenv
    basedpyright
    python3Full
    virtualenv
    tesseract
    poetry
    black
    ruff
    pdm

    go
    gopls

    shellcheck
    beautysh

    nixfmt-classic
    nil
    gcc

    zig-shell-completions
    zig
    zls
  ];
}
