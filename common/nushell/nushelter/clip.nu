# Copy input to system clipboard.
# Supports wl-copy, xclip, and pbcopy.
def clip-copy [] {
    let input = $in
    if (which wl-copy | is-not-empty) {
        $input | wl-copy
    } else if (which xclip | is-not-empty) {
        $input | xclip -selection clipboard
    } else if (which pbcopy | is-not-empty) {
        $input | pbcopy
    } else {
        error make {msg: "No clipboard utility found (install wl-copy, xclip, or pbcopy)"}
    }
}

# Read content from system clipboard.
# Supports wl-paste, xclip, and pbpaste.
export def clip-paste [] {
    if (which wl-paste | is-not-empty) {
        wl-paste --no-newline
    } else if (which xclip | is-not-empty) {
        xclip -selection clipboard -o
    } else if (which pbpaste | is-not-empty) {
        pbpaste
    } else {
        error make {msg: "No clipboard utility found (install wl-paste, xclip, or pbpaste)"}
    }
}
