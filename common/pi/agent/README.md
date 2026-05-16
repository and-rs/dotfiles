# Pi agent setup

## Extensions

- `web-docs`: `/exa` auth command, `exa-search`, `web-fetch`.
- `hashline-edit`: strict `hashline-read`, `hashline-edit`, and `file-create` tools.
- `hashline-read` can inspect files under cwd or `$HOME`; `hashline-edit` and `file-create` stay cwd-bound.
- `focus-border`: dim input border on terminal focus loss.
- `context-mask`: masks old bulky tool results while preserving recent active `hashline-read`/edit working set and logs context operations.
- `pi-checkpoint`: local `[PI]` checkpoint commits in small batches after file-changing turns; blocks agent `git push`.
- `code-tools`: `code-overview` and `code-search` for compact JIT repo exploration.
- `tool-policy`: disables built-in `read`, `edit`, `write`, `grep`, `find`, and `ls`; keeps replacement tools active.
- `forge`: optional phased workflow with color-coded footer chip, `/forge`, `/phase`, read-only `tactic`/`temper`, and interactive human-first `temper` coaching.
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
ai bootstrap tool-policy
ai bootstrap forge
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

- `pi-checkpoint` creates local `[PI] checkpoint:` commits only when a file-changing batch starts from a clean worktree.
- Batches flush after a short quiet pause, when file count/turn count grows, or on session shutdown.
- `ai gs` refuses normal commit flow while `[PI]` commits are at `HEAD`; run `ai squash` to squash them into a final commit.
- Agent `git push` is blocked; push manually outside Pi.

## Local secrets

`auth.json` is local-only and ignored. Do not commit plaintext provider or Exa keys.
