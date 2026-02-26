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

def qsv-select [] {
  let input = $in
  let has_stdin = ($input != null and ($input | into string | str trim | is-not-empty))

  let file = if $has_stdin {
    null
  } else {
    let picked = (
      ^fd -t f -e csv -e tsv -e ssv -e tab -H --follow --color=never --exclude .git
      | ^fzf --prompt="File > " --layout=reverse --height=40%
    )
    if ($picked | is-empty) {
      print $"(ansi yellow)Selection cancelled.(ansi reset)"
      return
    }
    print $"(ansi re)(ansi --escape { fg: white bg: blue }) CSV selected: (ansi rst) ($picked)\n"
    $picked
  }

  let selection = if $has_stdin {
    $input | ^qsv headers | ^fzf --prompt="Headers > " --multi --layout=reverse --height=40%
  } else {
    ^qsv headers $file | ^fzf --prompt="Headers > " --multi --layout=reverse --height=40%
  }

  if ($selection | is-empty) {
    print $"(ansi yellow)Selection cancelled.(ansi reset)"
    return
  }

  let headers = ($selection
    | lines
    | each { |line| $line | str replace --regex '^\s*\d+\s+' '' }
    | str join ","
  )

  if $has_stdin {
    $input | ^qsv select $headers
  } else {
    ^qsv select $headers $file
  }
}
