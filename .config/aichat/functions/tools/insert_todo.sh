#!/usr/bin/env bash
set -e

## @describe Insert a TODO comment at a specific line in a file
## @option --path! The path of the file to modify
## @option --text! The TODO text (must be single line and contain TODO)
## @option --line! <INT> The line number where to insert the TODO
## @env LLM_OUTPUT=/dev/stdout The output path

main() {
    if [[ -z "$argc_text" ]]; then
        echo "error: --text is required" >&2
        exit 1
    fi

    if [[ "$argc_text" == *$'\n'* ]]; then
        echo "error: TODO text must be a single line" >&2
        exit 1
    fi

    if [[ "$argc_text" != *"TODO"* ]]; then
        echo "error: TODO text must contain 'TODO'" >&2
        exit 1
    fi

    if [[ ! -f "$argc_path" ]]; then
        echo "error: File not found: $argc_path" >&2
        exit 1
    fi

    local total_lines
    total_lines=$(wc -l < "$argc_path")
    if [[ "$argc_line" -lt 1 ]] || [[ "$argc_line" -gt $((total_lines + 1)) ]]; then
        echo "error: Invalid line number $argc_line for file with $total_lines lines" >&2
        exit 1
    fi

    local patch_content
    patch_content=$(build_patch "$argc_path" "$argc_text" "$argc_line")

    "$(dirname "$0")/fs_patch.sh" --path "$argc_path" --contents "$patch_content"
}

build_patch() {
    local file="$1"
    local text="$2"
    local line_num="$3"
    local total_lines=$(wc -l < "$file")
    local line_content=""
    local insert_line=$((line_num - 1))

    if [[ $line_num -gt $total_lines ]]; then
        line_num=$total_lines
        insert_line=$total_lines
    fi

    if [[ $line_num -gt 0 ]]; then
        line_content=$(sed -n "${line_num}p" "$file")
    fi

    local comment_line
    if [[ "$text" == TODO* ]]; then
        comment_line="# $text"
    else
        comment_line="# TODO: $text"
    fi

    cat <<EOF
--- a/$file
+++ b/$file
@@ -$insert_line,0 +$insert_line,1 @@
+$comment_line
EOF
}

eval "$(argc --argc-eval "$0" "$@")"
