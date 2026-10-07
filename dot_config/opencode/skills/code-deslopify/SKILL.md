---
name: code-deslopify
description: Review or clean up existing code that adds avoidable correctness risk or maintenance cost, especially redundant wrappers, checks, and error handling.
---

# Code Deslopify

Use this skill to review or clean up existing code. “Slop” is code that adds avoidable correctness risk or maintenance cost, even if it runs and looks plausible. Judge the code and its fit with the project, not whether AI wrote it. Verbosity, unfamiliar style, or a code smell alone is not proof; findings need concrete evidence and impact.

## Scope

- Follow the user's target. If they refer to the current change without naming files, inspect the current diff and stay within it.
- Do not expand a file- or diff-scoped request into nearby modules or a repository-wide cleanup.
- If there is no clear target, ask what code they want reviewed or cleaned.
- If the user asks for review only, do not edit. Otherwise, make the requested, behavior-preserving cleanup.
- This is not a feature implementation, format-only pass, UI-design critique, or broad redesign. Use implementation guidance such as `ponytail` while writing new code; this skill is for cleaning up existing code.

## Look for evidence of

- **Redundant indirection and repeated work** — make this a first-class review target:
  - wrappers or forwarding layers that only rename a function, pass through the same arguments, and return the same result
  - `catch` blocks that only rethrow the same error without recovery, cleanup, useful context, or meaningful translation
  - repeated validation, guards, or defensive checks that establish the same invariant without a new trust boundary, state change, or failure mode
  - duplicate helpers or parallel implementations where an existing project utility already does the job
- **Avoidable correctness risk** — behavior that misses the request or project contract; swallowed or misrepresented errors; unverified APIs or integrations; unsafe shortcuts; or tests that mirror the implementation, mock away the behavior under test, or were weakened just to pass.
- **Unnecessary structure or scope** — dead or stale code, speculative abstractions, layers that obscure control flow, misplaced responsibilities, and unrelated additions without a concrete benefit.
- **Noise** — comments, documentation, or boilerplate that is redundant, misleading, or merely restates what the code does.

For each suspected wrapper, catch, or check, ask what it contributes: adaptation, a stable boundary, policy, instrumentation, recovery, cleanup, or protection at a real trust boundary can justify it. Do not remove a check until its invariant and callers are understood. Keep deliberate duplication, useful abstractions, domain-specific names, and comments that preserve non-obvious rationale. A long function or extra line is a lead to inspect, not a finding by itself.

## Cleanup workflow

1. Inspect the target, repository conventions, relevant callers, invariants, tests, and working-tree changes. Preserve unrelated user edits.
2. Identify concrete evidence and its cost. Prioritize redundant wrappers, rethrows, checks, and repeated implementations; do not optimize for fewer lines alone.
3. Protect intended behavior. Check the narrowest relevant existing tests or verification before editing when practical. If behavior or an invariant is unclear, do not make a speculative cleanup; explain the uncertainty.
4. Make the smallest focused change. Prefer removing genuinely redundant work; do not add dependencies, abstractions, or unrelated cleanup. Never weaken tests or safeguards just to make cleanup pass.
5. Run proportionate verification for the touched behavior, then inspect the final diff for behavior changes and scope creep.

## Review-only output

When asked to review without editing, report actionable findings with location, evidence, and impact. Separate correctness or security risks from avoidable maintenance cost. Mark uncertainty clearly; do not report a stylistic preference as a defect.

## Completion

Briefly report the cleanup made and the verification run. Mention unresolved risks or uncertain behavior instead of silently making a speculative change.
