# gitignore.yazi

A Yazi fetcher plugin that automatically reads `.gitignore` files and applies their patterns to hide ignored files in the file manager.

## Features

- Automatically detects if you're in a git repository
- Reads `.gitignore` files from the git root
- Converts gitignore patterns to Yazi exclude patterns
- Supports negation patterns (patterns starting with `!`)
- User config exclude patterns can override plugin patterns using negation
- Efficient caching per repository
- No external git process spawning

## How it works

This plugin runs as a "fetcher" which means it executes when browsing directories. It:

1. Checks if the current directory is within a git repository
2. Locates the `.gitignore` file in the repository root
3. Parses the patterns from `.gitignore`
4. Sends patterns to the core via `ya.mgr_emit("exclude_add", patterns)`
5. The core applies patterns using compiled glob sets for efficient matching

## Pattern Conversion

The plugin converts gitignore patterns to glob patterns following gitignore semantics:

| `.gitignore` Pattern | Generated Patterns                | Matches                   |
| -------------------- | --------------------------------- | ------------------------- |
| `target`             | `target`, `**/target`             | `target/` anywhere        |
| `*.log`              | `*.log`, `**/*.log`               | Any `.log` file           |
| `/build`             | `build`                           | `build/` at git root only |
| `node_modules/`      | `node_modules`, `**/node_modules` | `node_modules/` anywhere  |
| `!important.log`     | `!important.log`                  | Whitelist (negation)      |
| `build/output`       | `build/output`                    | From git root (has `/`)   |

## Configuration

To use the gitignore plugin, clone it into your plugins folder (eg. `$HOME/.config/yazi/plugins`) and add it to your fetchers on `yazi.toml`:

```toml
[[plugin.prepend_fetchers]]
id   = "gitignore"
url = "*"
run  = "gitignore"
```

To further customize patterns or add custom excludes, use the `[files]` section in your `yazi.toml`:

```toml
[files]
excludes = [
  # Show 'target' directory even if .gitignore excludes it
  { urn = "!target", in = "/home/user/projects/myproject" },
  
  # Add additional patterns not in .gitignore
  { urn = ["*.backup", "*.tmp"], in = "*" },
  
  # Context-specific patterns
  { urn = "*.pyc", in = "search://**" },
]
```

Config patterns are applied **after** gitignore patterns, overriding them so negation patterns in your config can whitelist files.
