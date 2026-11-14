---
name: code_modularize
description: Plan evidence-based code division, modularization, reorganization, and unification that improves changeability.
---

# Code Modularize

Use this skill to plan structural changes that make code easier to understand, change, test, or own. Optimize for meaningful boundaries and lower maintenance cost, not smaller files, more folders, pattern adoption, or code movement by itself. A reorganization is worthwhile only when its expected benefit is concrete.

## Scope

- Follow the user's target. Without an explicit target, inspect only unstaged changes (`git diff`), excluding staged changes and untracked files. Treat an unspecified "current change" the same way.
- Do not expand a file- or diff-scoped request into nearby modules or a repository-wide redesign.
- If there are no unstaged changes and no explicit target, report that and stop; do not broaden scope.
- Default to planning, not editing. Recommend a structure and migration plan; change files only when explicitly asked.
- This is for structural design and reorganization, not feature implementation, a file-size cleanup, or a general code-quality review. Use `code_deslopify` to focus on removing unnecessary code.

## Find leverage before choosing boundaries

First understand the actual code paths, callers, state, tests, and working-tree changes in scope. Then establish the problem with evidence, such as:

- A common change repeatedly requires edits across unrelated locations.
- Responsibilities or concepts that change for different reasons are tangled together.
- Callers depend on implementation details, shared mutable state, or unstable internals.
- Similar behavior is independently maintained despite sharing the same domain meaning and evolution.
- A module's dependencies, setup, or tests make a focused change unusually risky or expensive.

Name the expected benefit in user terms: for example, containing a class of changes, making a behavior testable in isolation, reducing coordination, or establishing one authoritative implementation. State what observable change would show the boundary is useful, such as a representative change no longer requiring edits across unrelated modules. Do not use file count or abstract coupling scores as the success measure. If no concrete recurring cost or risk is visible, say so and do not invent a reorganization.

## Choose boundaries from evidence

- Prefer grouping behavior that serves the same cohesive responsibility and tends to change together. Separate concerns that change independently or hide decisions likely to change.
- Treat information hiding as the goal: expose the smallest useful contract and keep representation, policy, and state-management details inside the owning module.
- Trace the dependency graph. Minimize cross-boundary knowledge and avoid cycles; make dependencies explicit and point them toward stable contracts. Do not add interfaces, layers, dependency injection, or wrappers unless they buy a demonstrated seam or reduce coupling.
- Use domain concepts and observed change patterns when they reveal real boundaries. Do not force domain-driven design, layers, or team boundaries onto code without evidence.
- Unify duplicated code only when the implementations express the same concept and are likely to change together. Similar-looking code with different rules or reasons to change may be safer kept separate.
- Choose the least costly boundary that delivers the benefit. A function, file, package, or in-process module is usually preferable to a process, service, or deployment boundary. Do not propose microservices merely to improve code organization.
- Do not treat line count, file size, directory count, or theoretical future reuse as proof of modularity.

## Plan the change

1. Map the relevant behavior and dependencies, including callers, data ownership, side effects, and tests. Distinguish observed facts from assumptions.
2. Describe the current friction and expected benefit. If either is unclear or too small, recommend no reorganization.
3. Propose the target responsibilities, ownership, public contracts, and dependency direction. Explain what remains together and why.
4. Give a small, ordered migration path. Prefer behavior-preserving moves before behavior changes; use automated move/rename tools where reliable. Keep intermediate states buildable and avoid broad-bang rewrites.
5. Identify compatibility risks, state or data migrations, and the focused tests/checks that demonstrate behavior and boundary contracts. Do not add tests that only mirror the new structure.
6. Stop at a reviewable plan unless implementation was explicitly requested. If asked to implement, preserve unrelated user changes, make incremental edits, run proportionate verification, and inspect the final diff.

## Plan output

Keep the response proportional to scope. For a proposed reorganization include:

- **Problem and payoff:** observed friction and the specific improvement expected.
- **Proposed boundaries:** responsibilities, contracts, and dependency direction.
- **Migration:** ordered, incremental steps.
- **Verification and risks:** focused checks plus material assumptions or compatibility concerns.

For a small request, compress these into a concise recommendation. Do not present a generic architecture lecture or claim benefits that are not supported by the inspected code.

## Basis

These practices follow Parnas's information-hiding criterion, Fowler's guidance to place code that changes together in the same or nearby modules and to refactor in small tested steps, and DORA's emphasis on independent change and testing as outcomes of loose coupling. Domain analysis can inform boundaries, but no method mechanically determines the right decomposition.

- Parnas, [On the Criteria to be Used in Decomposing Systems into Modules](https://dl.acm.org/doi/10.1145/361598.361623)
- Fowler, [Refactoring Module Dependencies](https://martinfowler.com/articles/refactoring-dependencies.html) and [This class is too large](https://martinfowler.com/articles/class-too-large.html)
- DORA, [Loosely coupled teams](https://dora.dev/capabilities/loosely-coupled-teams/)
- Microsoft, [Use Domain Analysis to Model Microservices](https://learn.microsoft.com/en-us/azure/architecture/microservices/model/domain-analysis)

## Completion

For a planning/review request, finish with the actionable plan or the reason no reorganization is justified. For implementation, briefly summarize changes and verification, including unresolved risks.
