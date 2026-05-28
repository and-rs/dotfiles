---
name: nu-syntax
description: Nushell syntax reference and common patterns. Load when writing, editing, or debugging nushell scripts or config files, or when translating bash to nushell.
---

# Nushell Syntax Reference

Official docs: https://www.nushell.sh/book/ Command reference:
https://www.nushell.sh/commands/ Cookbook: https://www.nushell.sh/cookbook/

## Variables

```nu
let x = 5            # immutable
mut y = 5            # mutable
$y += 1

$env.HOME            # env vars, not $HOME
$env.PATH ++= ["/extra/bin"]
$env.FOO? | default "fallback"  # safe access with default
```

## String Interpolation

```nu
$"hello ($name)"         # parens, not braces
$"path: ($env.HOME)/bin"
```

## Pipelines

```nu
ls | where type == dir | get name
[1 2 3] | each {|x| $x * 2}
"hello" | str upcase
cmd | str trim
```

No `$()` substitution — use `(expr)` inline or `let result = (cmd)`.

Multiline expressions wrap in `()` — no bash `\` and no PowerShell backticks needed:

```nu
let result = (
  ls
  | where type == dir
  | get name
  | str upcase
)
```

Pipes also continue naturally after `|` at end of line without parens:

```nu
ls
| where type == dir
| get name
```

## No && / || / ; Equivalents

```nu
# sequential: newline or semicolon
cmd1
cmd2

# conditional chaining
if (cmd | complete).exit_code == 0 { next-cmd }

# or / and in conditions
if $a > 0 and $b < 10 { ... }
if $a == "" or $b == "" { ... }
```

## Conditionals

`if` is an expression — it returns a value.

```nu
let label = if $x > 0 { "pos" } else { "neg" }

if $x > 0 {
  print "positive"
} else if $x == 0 {
  print "zero"
} else {
  print "negative"
}
```

## Loops

```nu
for item in $list { print $item }
for i in 0..10 { print $i }

while $cond { ... }

# functional style (preferred)
$list | each {|x| $x * 2}
$list | filter {|x| $x > 0}
$list | reduce {|acc x| $acc + $x}
```

## Closures

```nu
{|x| $x * 2}
{|| some-expr }   # no args
```

## Data Types

```nu
let list = [1 2 3]
let rec = {name: "alice", age: 30}
let table = [[name age]; [alice 30] [bob 25]]

# access
$rec.name
$list.0
$table | get name
```

## Comparison & Matching

```nu
== != < > <= >=
=~ "regex"      # matches
!~ "regex"      # not matches
in [a b c]      # membership
not-in [a b c]
```

## Type Annotations & Defs

```nu
def greet [name: string, --loud (-l): bool] {
  if $loud { $"HELLO ($name | str upcase)" } else { $"hello ($name)" }
}

def --env set-cwd [path: string] {
  cd $path
}

export def my-cmd [] { ... }
```

## Modules

```nu
use my-module *          # imports all exports + runs export-env
use my-module [cmd1]     # selective import
source file.nu           # inline include, no isolation
```

## Error Handling

```nu
try {
  rm important-file.txt
} catch {|e|
  print $e.msg
}

let result = try { risky-cmd } catch { null }
```

## Common Checks

```nu
which nvim | is-empty              # command exists?
($path | path exists)              # file exists?
($list | is-empty)                 # empty?
($str | str contains "sub")        # substring?
```

## export-env

```nu
export-env {
  $env.FOO = "bar"
  $env.PATH ++= [$"($env.HOME)/.local/bin"]
}
```

## Running External Commands

```nu
git status             # external command works directly
^ls                    # force external only when bypassing Nushell command/alias
nu -c 'ls | get name'  # run nushell from within nushell/bash
```

## User-facing Command Formatting

- In fenced `nu` blocks, do not indent command lines unless syntax requires indentation.
- Multiple sequential commands are not multiline command syntax. Put one command per line:

```nu
touch keep.txt
git add keep.txt
rm keep.txt
zig build run -- files --cwd .
```

- Never use PowerShell-style backtick line continuation in Nushell.
- Use wrapped `(` `)` form when one external command is split across lines. Keep command plus fixed subcommands on first line, then flags or long arguments:

```nu
(
  az devops invoke
  --area build
  --resource artifacts
  --route-parameters project=b90e608b-ac63-4052-819e-ca677fed3f4c buildId=181039
) | get value
```

- If whole pipeline needs grouping, wrap whole pipeline instead of adding backticks:

```nu
(
  az devops invoke
  --area build
  --resource artifacts
  --route-parameters project=b90e608b-ac63-4052-819e-ca677fed3f4c buildId=181039
  | get value
)
```

- Use `do { ... }` only when block semantics are needed, not for ordinary sequential commands.
- Do not prefix external commands with `^` unless you must bypass Nushell command/alias resolution.

## Key Bash Gotchas

| Bash                   | Nushell                           |
| ---------------------- | --------------------------------- |
| `$VAR`                 | `$env.VAR`                        |
| `$(cmd)`               | `(cmd)`                           |
| `"${var}"`             | `$"($var)"`                       |
| `export FOO=bar`       | `$env.FOO = "bar"`                |
| `cmd1 && cmd2`         | `cmd1; cmd2` or `if ... { cmd2 }` |
| `[[ -f path ]]`        | `($path \| path exists)`          |
| `arr=(a b c)`          | `let arr = [a b c]`               |
| `${arr[@]}`            | `$arr`                            |
| `for x in "${arr[@]}"` | `for x in $arr { }`               |
| `cmd > file`           | `cmd \| save file`                |
| `cmd >> file`          | `cmd \| save --append file`       |
