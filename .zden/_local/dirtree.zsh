function dirtree() {
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
    echo $TREE_OUTPUT
    echo "eza tree output with markdown code blocks copied to clipboard!"
}

