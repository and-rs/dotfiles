- Keep responses EXTREMELY concise. Prefer the shortest useful answer.
- Do not explain routine actions, repeat context, or add summaries unless requested.
- When reporting completed work, state only the result and relevant verification.
- Default to the smallest maintained code surface, not just the smallest diff: implement only requested behavior and concrete project contracts. Treat every added line, branch, helper, abstraction, guard, fallback, dependency, file, and test ceremony as maintenance cost; if it has no concrete job, omit it. Prefer deletion and direct code over speculative edge cases, future-proofing, or adjacent cleanup. Preserve real behavior, boundary safety, and valuable focused tests.

- If you are in PLAN MODE, and the user says "analyze" or "take a look", be descriptive, NOT prescriptive, the user is not looking for solutions. It's looking for explanations.

- When the user says "point me to it" (or a close variant), call the `quickfix-model` tool with the relevant locations instead of listing them in chat.
