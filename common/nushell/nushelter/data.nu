use clip.nu

# Run a DuckDB query on a database and inspect the result in csvlens.
# Example:
#   duck-inspect my.db "select * from users limit 100"
def duck-inspect [
   db: path  # Path to the duckdb database file
   query: string # SQL query string to execute
] {
   if (which duckdb | is-empty) { error make {msg: "'duckdb' is required"} }
   if (which csvlens | is-empty) { error make {msg: "'csvlens' is required"} }
   ^duckdb -csv $db $query | ^csvlens
}

# Run a SQL query from the clipboard on a DuckDB database.
# Example:
#   duck-inspect-clip my.db
def duck-inspect-clip [
   db: path # Path to the duckdb database file
] {
   let query = (clip-paste)
   if ($query | is-empty) {
      error make {msg: "Clipboard is empty."}
   }
   print $"(ansi cyan)Running query from clipboard:(ansi reset)"
   print $"(ansi gray)($query)(ansi reset)"
   duck-inspect $db $query
}

# Internal helper to pick file and headers interactively
def _nushelter-pick-qsv-args [] {
   let file = (
      ^fd -t f -e csv -e tsv -e ssv -e tab -H --follow --color=never --exclude .git
      | ^fzf --prompt="File > " --layout=reverse --height=40%
   )
   if ($file | is-empty) { return null }
   let selection = (
      ^qsv headers $file 
      | ^fzf --prompt="Headers > " --multi --layout=reverse --height=40%
   )
   if ($selection | is-empty) { return null }
   let headers = ($selection 
      | lines 
      | each { |line| $line | str replace --regex '^\s*\d+\s+' '' } 
      | str join ","
   )
   return { file: $file, headers: $headers }
}

# Interactive 'qsv select' wrapper.
# Usage: 
#   qsel | table
#   qsel | save output.csv
def qsv-select [] {
   let args = (_nushelter-pick-qsv-args)
   if ($args == null) {
      print "(ansi yellow)Selection cancelled.(ansi reset)"
      return
   }
   ^qsv select $args.headers $args.file
}
