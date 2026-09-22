---
name: ponytail
description: >
  Apply minimal, YAGNI-first implementation discipline when building, fixing,
  refactoring, reviewing, or designing software. Use when a coding task risks
  over-engineering, speculative abstractions, unnecessary dependencies,
  boilerplate, extra files, or a larger diff than needed.
---

# Ponytail

Lazy means efficient, not careless. The best code is code never written.

Use this skill for implementation decisions, not as a replacement for understanding the problem. Read the code touched by the change, trace the real flow, then choose the smallest safe solution.

## Ladder

Stop at first rung that holds:

1. **Does this need to exist?** Skip speculative work. Do not implement unrequested features.
2. **Already in this codebase?** Reuse existing helpers, types, patterns, and callers. Search before creating duplicates.
3. **Stdlib does it?** Use the standard library instead of custom code.
4. **Native platform feature covers it?** Prefer browser, OS, database, shell, or language features over dependencies and wrappers.
5. **Existing dependency solves it?** Reuse installed dependencies. Do not add a dependency for a small amount of code.
6. **Can fewer lines and files solve it safely?** Choose the smaller working diff.
7. **Only then:** write the minimum code that fits existing conventions.

## Rules

- No abstraction with one implementation unless it removes real complexity now.
- No configuration for values nobody needs to change.
- No scaffolding, flexibility, or cleanup for a future that was not requested.
- Prefer deletion over addition and boring code over clever code.
- Keep every changed line traceable to the request or to correctness of the change.
- Fix bugs at the shared root cause when callers converge; do not patch one symptom while sibling callers remain broken.
- Keep deliberate simplifications visible when they have a known ceiling: `ponytail: global lock; use per-account locks if throughput requires it`.

## Safety boundary

Never simplify away:

- input validation at trust boundaries
- security controls
- accessibility basics
- error handling that prevents data loss or corrupt state
- behavior explicitly requested by the user
- correctness checks needed for non-trivial logic

Minimal does not mean careless. A smaller wrong fix is still wrong.

## Verification

For non-trivial logic, leave or run one proportionate check that would fail if the change breaks: an existing test, focused test, assertion, typecheck, or runnable smoke check. Do not add test ceremony for a trivial one-liner when existing checks already cover it.

Before finishing, verify the success path, relevant failure path, and affected caller contract. Do not claim completion from code inspection alone when a runnable check exists.

## Output

For normal implementation work, show the result first and explain only meaningful omissions or tradeoffs. Keep the report short:

`Done. Skipped [unneeded thing]; add it when [concrete condition].`

Give fuller detail when the user asks for a review, walkthrough, plan, or rationale.

## Boundaries

Ponytail governs what gets built, not permission to mutate files. Follow the active harness mode and repository instructions. In read-only modes, inspect and recommend; do not implement.
