---
name: code-deslopify
description: Critically simplify existing code by removing unnecessary implementation and maintenance surface, especially redundant wrappers, checks, layers, and speculative abstractions.
---

# Code Deslopify

Use this skill to find and remove code the project does not need. Default to the smallest maintained code surface that satisfies the request and real project contracts. Fewer lines, branches, files, dependencies, and concepts are legitimate goals because each adds maintenance and failure surface. Do not keep code merely because it works, is conventional, looks defensive, or might be useful someday. Be blunt about what can be skipped or deleted, with a concrete reason; do not pad with praise or style complaints.

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
- **Unnecessary structure or scope** — dead or stale code, speculative abstractions, layers that obscure control flow, misplaced responsibilities, unrequested features, and unrelated additions without a concrete benefit.
- **Noise** — comments, documentation, or boilerplate that is redundant, misleading, or merely restates what the code does.

For every extra construct, ask what breaks if it is removed. Check callers, invariants, and real trust boundaries before deciding. Keep it only when it serves a concrete requirement, caller contract, demonstrated failure mode, or material safety/correctness need. "Best practice," hypothetical reuse, and future-proofing are not enough. Prefer direct code; an abstraction must reduce total maintenance surface, not just move lines elsewhere. Small deliberate duplication can be cheaper than another helper. Preserve meaningful tests and safeguards, but remove ceremony that verifies no meaningful behavior.

## Cleanup workflow

1. Inspect the target, repository conventions, relevant callers, invariants, tests, and working-tree changes. Preserve unrelated user edits.
2. Find the minimum implementation that satisfies the request and real contracts. First ask what can be skipped entirely, then what existing code can be reused, simplified, or deleted.
3. Remove code without a concrete job, including unnecessary wrappers, rethrows, guards, layers, configurability, and test ceremony. Optimize the final maintained surface, not merely the patch size; simplify touched code when that makes the result smaller and clearer.
4. Preserve required behavior, real boundary protections, and meaningful verification. If behavior or an invariant is unclear, investigate; do not guess. Never weaken a valuable test or safeguard just to reduce lines.
5. Run proportionate verification for the touched behavior, then inspect the final diff for correctness and scope creep.

## Review-only output

When asked to review without editing, report only actionable removals or simplifications, with location, evidence, and the maintenance/correctness impact. Mark uncertainty clearly; do not report a stylistic preference as a defect.

## Completion

Briefly report the cleanup made and the verification run. Mention unresolved risks or uncertain behavior instead of silently making a speculative change.
