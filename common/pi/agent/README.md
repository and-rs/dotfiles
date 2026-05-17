# Pi agent setup

## Extensions

- `web-docs`: `/exa` auth command, `exa-search`, `web-fetch`.
- `hashline-edit`: strict `hashline-read`, `hashline-edit`, and `file-create` tools.
- `hashline-read` can inspect files under cwd or `$HOME`; small files return whole body, huge files return simple segment labels like `A` and `B`.
- `focus-border`: dim input border on terminal focus loss.
- `context-mask`: aggressively masks old bulky tool results; expect stale file context to disappear and re-read for fresh anchors.
- `pi-checkpoint`: local `[PI]` checkpoint commits in small batches after file-changing turns; blocks agent `git push`.
- `code-tools`: `code-overview` and `code-search` for compact JIT repo exploration.
- `tool-policy`: disables built-in `read`, `edit`, `write`, `grep`, `find`, and `ls`; keeps replacement tools active.
- `forge`: optional phased workflow with color-coded footer chip, `/forge`, `/phase`, read-only `tactic`/`temper`, and interactive human-first `temper` coaching.
- `lib`: shared extension helpers. Not loaded as an extension.

## Architecture rules

- One project root only: `common/pi/agent/extensions/`.
- Backend-style layout:
  - `src/app/` for assembly.
  - `src/ui/` for footer/widget chrome ownership.
  - `src/features/<feature>/` for domain modules.
- `package.json` loads one extension only: `src/app/index.ts`.
- `app/` composes features and UI. Features do not self-assemble globally.
- Only `ui/` owns footer/widget/status mutations.
- Features expose `index.ts` as public facade.
- Small composition-only helpers belong in `index.ts`.
- Separate file only when concern has real behavior depth, reuse, or boundary value.
- Avoid ad-hoc per-extension packages, locks, bootstrap steps.
- Prefer repeating module grammar over clever one-offs.
- Stop splitting when file becomes fake wrapper with no semantic value.

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
ai bootstrap
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