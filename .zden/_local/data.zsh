
clsql() {
    local db="${1:-practice.db}"
    query="$(wl-paste 2>/dev/null || xclip -out 2>/dev/null || pbpaste 2>/dev/null)"
    if [[ -z "$query" ]]; then
        echo "No query found in clipboard"
        return 1
    fi
    duckdb -csv "$db" "$query" | csvlens;
}
