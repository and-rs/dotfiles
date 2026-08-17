alias nv = neovide --neovim-bin $"(echo $env.EDITOR)" --chdir .

def nrg [pattern: string] {
  let rgcmd = rg --json --vimgrep $pattern | from json --objects | where type == 'match' | get data | each {|l|
      return {
        filename: $l.path.text
        lnum: $l.line_number
        text: ($l.lines.text | str replace --all "\n" "")
        col: ($l.submatches.0.start + 1)
      }
    } | to json -r

  let qflist = "lua vim.cmd([[call setqflist(" + $rgcmd + ")]])"
  let cfirst = "lua vim.schedule(function() vim.cmd.copen() vim.cmd.cfirst() end)"

  nvim -c $qflist -c $cfirst
}
