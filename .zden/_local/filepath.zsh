function filepath() {
    local depth=1

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


    if ! command -v fd >/dev/null 2>&1; then
        echo "Error: 'fd' is required." >&2
        return 1
    fi
    if ! command -v fzf >/dev/null 2>&1; then
        echo "Error: 'fzf' is required." >&2
        return 1
    fi

    local clipboard_cmd=""
    if command -v pbcopy >/dev/null 2>&1; then
        clipboard_cmd="pbcopy"
    elif command -v wl-copy >/dev/null 2>&1; then
        clipboard_cmd="wl-copy"
    else
        echo "Error: No clipboard utility found. Install 'pbcopy' (macOS), 'wl-copy' (Wayland)" >&2
        return 1
    fi


    local selected_files
    selected_files="$(fd --exact-depth="$depth" | fzf \
        --multi \
        --padding=1,0,0,1 \
        --prompt="Select file(s) > " \
        --layout=reverse)"

    if [[ -z "$selected_files" ]]; then
        echo "No file selected."
        return 0
    fi

    local -a files_array
    files_array=("${(@f)selected_files}")

    local -a quoted_paths
    local current_dir
    current_dir="$(pwd)"

    for file in "${files_array[@]}"; do
        quoted_paths+=("${(q)current_dir}/${(q)file}")
    done

    local clipboard_content
    clipboard_content="${(j:\n:)quoted_paths}"

    printf '%s' "$clipboard_content" | "$clipboard_cmd"
    echo "Copied ${#files_array[@]} file path(s) to clipboard."
}
