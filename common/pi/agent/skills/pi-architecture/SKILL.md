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
- `src/features/hashline-edit/` now owns staged edit flow: `{path, goal}` first, then `{path, segment}` if needed, then `{path, edits}`.

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