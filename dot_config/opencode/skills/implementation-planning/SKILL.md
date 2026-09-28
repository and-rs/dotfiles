---
name: implementation-planning
description: Create clear, code-grounded implementation plans for non-trivial software changes. Use before implementation when a task spans multiple surfaces, has meaningful risk, or contains unresolved design choices.
---

# Implementation Planning

Use this skill in Plan mode for multi-step, ambiguous, or consequential code changes. Small, obvious fixes do not need a formal plan.

## Planning process

1. Restate the requested outcome and constraints. Separate required behavior from optional improvements.
2. Inspect the current implementation and follow the behavior to its actual owner. Reuse existing patterns and dependencies; avoid speculative architecture.
3. Identify affected modules, callers, data or state transitions, and compatibility requirements. Do not infer behavior from names alone.
4. Resolve only questions that materially change the implementation. Ask one focused question when necessary; otherwise state a reasonable assumption.
5. Order the smallest safe changes by dependency. Include behavior for success, failure, and relevant state restoration.
6. Name focused tests and one runnable repository check that prove the change. Include user-visible manual verification only when automated checks cannot cover it.
7. Stop exploring when implementation surfaces, order, and proof are clear. Present the plan; do not implement or prepare copyable patches in Plan mode.

## Plan format

- **Goal:** desired behavior and consequence.
- **Scope:** important constraints and explicit non-goals.
- **Changes:** ordered steps, naming concrete modules or runtime surfaces and their behavior.
- **Verification:** focused tests and one runnable check.
- **Risks or assumptions:** only material items that can change implementation or safety.

Keep each step actionable. Do not make file-by-file inventories, add workflow ceremony to trivial work, or claim a check passed before running it.
