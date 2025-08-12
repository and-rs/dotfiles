#!/usr/bin/env zsh

DOTS="$HOME/vault/personal/dotfiles"

alias ..="z .."
alias nv="nvim"
alias c="clear -x"
alias reload="exec zsh"
alias sw="stow -t $HOME"

alias l="eza -lha --no-time --no-permissions --no-user -I .DS_Store"
alias ld="eza -lha --no-filesize --no-permissions --no-user -I .DS_Store"
alias ls="eza -liha"
alias lt="eza -lihaT --git-ignore"

alias update-nixos="sudo nixos-rebuild switch --flake $HOME/vault/personal/nixos#default"
alias update-darwin="sudo darwin-rebuild switch --flake $HOME/vault/personal/nix-darwin"

alias ff="fastfetch --logo-color-1 cyan --file $DOTS/utils/ascii/spider2.txt"
alias ffn="fastfetch --logo-color-1 red --file $DOTS/utils/ascii/spider2.txt --config neofetch"

code () { VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;}

f () {
    directories=(fd --type d)
    directories+=(--hidden
        --exclude .git
        --exclude node_module
        --exclude .cache
        --exclude .npm
        --exclude .mozilla
        --exclude .meteor
        --exclude .nv
    )

    selected_dir=$("${directories[@]}" | fzf --prompt="choose directory > " --reverse --info="right" --padding=1,0,0,1)

    if [ -n "$selected_dir" ]; then
        cd "$selected_dir" || exit
    else
        echo "No directory selected."
    fi

}

dirtree() {
    if ! command -v eza &> /dev/null; then
        echo "Error: 'eza' command not found. Please install eza to use this script."
        exit 1
    fi
    CLIPBOARD_CMD=""
    if command -v pbcopy &> /dev/null; then
        CLIPBOARD_CMD="pbcopy"
    elif command -v wl-copy &> /dev/null; then
        CLIPBOARD_CMD="wl-copy"
    else
        echo "Error: No clipboard utility found. Please install 'pbcopy' (macOS) or 'wl-copy' (Linux)."
        exit 1
    fi
    TREE_OUTPUT=$(eza -Ta --git-ignore)
    FORMATTED_OUTPUT="\`\`\`\n${TREE_OUTPUT}\n\`\`\`"
    echo -e "${FORMATTED_OUTPUT}" | ${CLIPBOARD_CMD}
    echo "eza tree output with markdown code blocks copied to clipboard!"
}

zd() {
    local current_dir
    current_dir=$(pwd)
    cd "$HOME/vault" || return 1
    local dir
    dir=$(fd -t d --exact-depth 2 | fzf --prompt="projects > " --reverse --info="right" --padding=1,0,0,1)
    if [[ -n $dir ]]; then
        cd "$dir"
    else
        cd "$current_dir"
    fi
}

ze() {
    local file
    file=$(fd --exclude .git --hidden | fzf --prompt="edit > " --reverse --info="right" --padding=1,0,0,1)
    [[ -n $file ]] && $EDITOR "$file"
}

filepath() {
    # Default depth
    local depth=1

    # Parse args: -d N or --depth N
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--depth)
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    depth="$2"
                    shift 2
                else
                    echo "Usage: filepath [-d N|--depth N]" >&2
                    return 2
                fi
                ;;
            -h|--help)
                echo "Usage: filepath [-d N|--depth N]"
                echo "Select one or more files at exact depth N (default: 1) and copy their paths."
                return 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Usage: filepath [-d N|--depth N]" >&2
                return 2
                ;;
        esac
    done

    # Ensure fd and fzf exist
    if ! command -v fd >/dev/null 2>&1; then
        echo "Error: 'fd' is required." >&2
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Error: 'fzf' is required." >&2
        return 1
    fi

    # Select files (multi-select enabled)
    local selected_files
    selected_files="$(fd --exact-depth="$depth" | fzf \
        --multi \
        --padding=1,0,0,1 \
        --prompt="Select file(s) > " \
        --layout=reverse)"

    # Handle cancel
    if [[ -z "$selected_files" ]]; then
        echo "No file selected."
        return 0
    fi

    # Prepend current working directory to each selected file
    local filepaths
    filepaths="$(printf '%s\n' "$selected_files" | sed "s|^|$(pwd)/|")"

    # Clipboard command
    local clipboard_cmd=""
    if command -v pbcopy >/dev/null 2>&1; then
        clipboard_cmd="pbcopy"
    elif command -v wl-copy >/dev/null 2>&1; then
        clipboard_cmd="wl-copy"
    elif command -v xclip >/dev/null 2>&1; then
        clipboard_cmd="xclip -selection clipboard"
    else
        echo "Error: No clipboard utility found. Install 'pbcopy' (macOS), 'wl-copy' (Wayland), or 'xclip' (X11)." >&2
        return 1
    fi

    # Copy to clipboard
    printf '%s\n' "$filepaths" | eval "$clipboard_cmd"
    echo "Copied $(echo "$filepaths" | wc -l) file path(s) to clipboard."
}
