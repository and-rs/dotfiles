def nvgrep [pattern: string] {
  nvim -c $"call setqflist\((
    rg --json --vimgrep $pattern | from json --objects | where type == 'match' | get data | each {|l|
      return {
        filename: $l.path.text
        lnum: $l.line_number
        text: $l.lines.text
        col: ($l.submatches.0.start + 1)
      }
    } | to json -r
  )\)" -c 'copen | cc 1 | filetype detect'
}
