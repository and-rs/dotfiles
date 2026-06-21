---
name: pi-architecture
description: Pi extension architecture and repo-specific setup rules. Load when modifying common/pi/agent/extensions/, common/pi/agent/skills/, or other Pi agent setup files.
---

# Pi Architecture

Use this skill before changing `common/pi/agent/extensions/` or related Pi setup.
Update this skill when Pi architecture changes.

## Scope

- Main project root: `common/pi/agent/extensions/`
- One extension entrypoint only: `src/app/index.ts`
- `package.json` should load only that entrypoint

- `common/pi/agent/skills/user-story-factory` — standardized user-story template and authoring rules (SKILL.md only, no executable).

## Layout

- `src/app/` — assembly and event wiring
- `src/ui/` — footer, widgets, status, other chrome ownership
- `src/features/<feature>/` — domain modules

## Ownership Rules

- `app/` composes features and UI
- Features do not self-assemble globally
- Only `ui/` mutates footer, widgets, or statuses
- Features expose `index.ts` as public facade

## File Splitting Rules

- Small composition-only helpers belong in `index.ts`
- Split file only when concern has real behavior depth, reuse, or boundary value
- Prefer repeated module grammar over clever one-offs
- Stop splitting when file becomes fake wrapper with no semantic value

## Anti-patterns

- No ad-hoc per-extension packages
- No extra lockfiles inside Pi extension tree
- No custom bootstrap flows for one feature unless architecture truly demands it
- No duplicate UI ownership spread across feature and ui layers

## Practical Editing Notes

- If changing UI chrome, start in `src/ui/`
- If changing composition or event hooks, start in `src/app/`
- If changing domain behavior, start in `src/features/<feature>/`
- If architecture changes, update imports and this skill together

## Current Chrome Shape

- `src/ui/chrome.ts` owns footer renderer and footer statuses
- `src/app/ui.ts` wires session/model/thinking events into `src/ui/chrome.ts`

## When Cleaning Up

- Prefer direct imports from real owner file
- Remove inert compatibility shims when safe
- Keep ownership obvious from import graph

## Tool Registration Gotcha

- `src/app/features.ts` assembles feature registration.
- If feature is removed, remove its app registration and dead files together.
- Visual file inspection lives in `src/features/read-image/` and is registered through `src/app/features.ts` like other feature-owned tools.
- `read-image` sends actual image bytes to image-capable models; do not add OCR or shell/base64 workaround flows unless tool path truly fails.

## hashline-edit Staged Edit Flow

`src/features/hashline-edit/` owns all staged-edit logic. Public edit tool is `hashline-edit` only; real `read` remains available for read-only inspection.

Flow:
1. First call: `{"path":"...","goal":"..."}` — reads file, stages fresh context, queues `steer` message with `deliverAs: "steer"` so model applies in the same agentic run.
2. Large file: steer prompts `{"path":"...","segment":"LABEL"}` — narrows to a smaller range, queues another steer.
3. Apply: `{"path":"...","edits":[...]}` — writes file, clears pending state explicitly.

Key implementation facts:
- `steer` fires before the LLM's next decision within the same agentic run. Stage and apply happen in one turn. No cross-turn state dependency.
- `agent_end` does NOT clear pending. Pending is cleared only on: explicit apply success, non-recoverable apply failure, `session_start`, `session_shutdown`.
- `tool_call` guard blocks wrong call shapes while pending (wrong path, wrong mode).
- Tool policy does not block `read`; only `edit`, `write`, `grep`, `find`, and `ls` are removed from active tools.
- Steer messages use `customType: "hashline-edit-steer"` with `display: false`.
- `context-mask` filters ALL `display: false` custom messages from LLM context so steer payloads do not accumulate.
- `MAX_STEER_COUNT = 8` prevents infinite segment-bisection loops.
- `MAX_APPLY_FAILURES = 1` allows one recoverable retry (match_missing / match_ambiguous) before giving up.
- `hashline-edit` is edit-only. Do not use it for read-only file inspection; use `read`, `code-search`, or `code-files` for read-only context.

Dead code removed:
- `hashline/constants.ts` deleted (only had unused `MISMATCH_CONTEXT`).
- `paths.ts` no longer exports `ensureReadablePath` (was only used by deleted hashline-read).
- `types.ts` no longer exports `HOME_DIR` (was only used by ensureReadablePath).
- `index.ts` no longer has a `session_start` active-tool manipulation block (redundant with tool-policy).
