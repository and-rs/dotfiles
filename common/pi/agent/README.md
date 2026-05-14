# Pi agent setup

## Extensions

- `web-docs`: `/exa` auth command, `exa_search`, `web_fetch`.
- `hashline-edit`: strict `hashline_read`, `hashline_edit`, and `file_create` tools.
- `hashline_read` can inspect files under cwd or `$HOME`; `hashline_edit` and `file_create` stay cwd-bound.
- `focus-border`: dim input border on terminal focus loss.
- `context-mask`: automatically masks old bulky tool results from LLM context and logs context operations.
- `pi-checkpoint`: local `[PI]` checkpoint commits after file-changing turns; blocks `git push`; adds `/undo` for latest checkpoint.
- `code-tools`: `code_overview` and `code_search` for compact JIT repo exploration.
- `lib`: shared extension helpers. Not loaded as an extension.

## Exa auth

- `/exa login`: save regular Exa search API key as `auth.exa`.
- `/exa status`: show regular Exa key source.
- `/exa logout`: remove regular Exa key.
- `/exa service-login`: save Exa service/admin key as `auth.exa_service`.
- `/exa service-status`: show service key source.
- `/exa usage`: show 30-day Exa spend using service/admin key.
- `/exa service-logout`: remove service key.

Env fallbacks:

- `EXA_API_KEY`
- `EXA_SERVICE_KEY`

Stored key values may also be an env var name or `!command` that prints a key.

## Bootstrap

Run after clone/update:

```nu
ai bootstrap web-docs
ai bootstrap hashline-edit
ai bootstrap focus-border
ai bootstrap context-mask
ai bootstrap pi-checkpoint
ai bootstrap code-tools
```

## Tmux focus

Required for pane-switch dimming:

```nu
tmux set-option -g focus-events on
```

Restart tmux if existing panes still do not emit focus events.


## Keybindings

- `alt+p`: toggle session path filter.
- `alt+o`: toggle model provider.

## Checkpoints

- `pi-checkpoint` creates local `[PI] checkpoint:` commits only when a turn changes files and the worktree was clean at turn start.
- `/undo` resets files by dropping latest `[PI]` commit when worktree is clean.
- `ai gs` refuses normal commit flow while `[PI]` commits are at `HEAD`; run `ai squash` to squash them into a final commit.
- Agent `git push` is blocked; push manually outside Pi.

## Local secrets

`auth.json` is local-only and ignored. Do not commit plaintext provider or Exa keys.
