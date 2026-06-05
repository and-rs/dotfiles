---
name: user-story-factory
description: Standardized user-story template and authoring rules for JB's projects. Use when drafting feature stories, acceptance criteria, and short step-by-step runbooks. This is a documentation-only skill (no executable code).
---

Purpose:
- ONLY provide one story at a time, and follow the example formatting correctly.
- Provide single canonical format for user stories used across projects.
- Enforce JB editorial rules: no "As a", no "I want", no filler, concise phrasing.
- Produce Markdown text that can be pasted into Jira, Confluence, or PR descriptions.
- Ensure Context, Objective, Action Items, optional Dependencies/Risks/POC, and concrete Acceptance Criteria.
- Make use of simple language that is understandable by semi-technical users like POs. Avoid buzzwords.
   - FOR EXAMPLE: Use common verbs like Sync, Match, or Fix instead of Reconcile, Idempotent, or Deterministic.

Template (exact output shape):
1. Context:
   - Known facts, history, and rationale. WHY THIS STORY EXISTS OR WHY IS IT NEEDED (important). What is already true and relevant. Do not list unknowns here.

2. Objective:
   - Clear outcome and scope. One-sentence target state that proves success.

3. Action Items:
   - Atomic ordered tasks. Each entry short imperative fragment.

4. Dependencies: (optional)
   - External teams, infra, or data required before completion.

5. Risks: (optional)
   - Clear blockers or impacts if dependencies fail. No vague language.

Point of Contact: (optional)
- Single named person or team and communication channel.

Acceptance criteria:
- Do not include the title "Acceptance criteria:". Just the table.
- Must name actor (pipeline, proc, script, team) and be testable.
- Must be concrete, not refer to unknowns or vague behavior.
- Avoid ambiguous verbs like "fail loud"; instead state exact observable behavior and where to look.
- Make it easy to understand for dummies. (REALLY IMPORTANT)
- Wrap names from actual code in {{}}, like this: {{BDP_<TENANT>ALERT_RECIPIENT_<NUMBER>}}. But avoid wrapping things like {{pipeline}}, basically don't wrap things that are just words.


Authoring rules (must follow):
- Do not use: "As a", "I want", "so that", or any persona-based phrasing.
- Use present tense, imperative fragments allowed.
- Context must be known facts only (history, current state, why needed).
- Objective must state the target state and scope succinctly.
- Action Items must be atomic, ordered tasks. No implementation prose.
- Acceptance criteria must name the actor and be verifiable (give exact queries, object names, or expected outputs).
- Do not include implementation details beyond necessary scope.

Example:

```markdown
1. Context:
- Pilot tenant `8n-sfsttest` has pipeline-managed recipient users and a notification integration.
- Managed schema `AUDIT_DB.USAGE_ALERTS` exists with current state table and alert objects created by pipeline.
- Manual direct procedure call previously sent an email; one stale `PENDING` state row was cleaned during testing.
- Purpose: shorten validation feedback loop and prove end-to-end behavior without full pipeline rerun.

2. Objective:
- Validate that managed alert setup can be inspected, triggered, and verified end-to-end using reusable scripts, without creating/deleting objects.

3. Action Items:
- Run inspect script to list alert objects, notification integration, recipient users, state table rows, and latest alert history for the target alert.
- Run trigger script to call the alert procedure directly (force-send path) for the current billing cycle and threshold.
- Re-run inspect script and verify new state row exists with `ALERT_STATUS = 'SENT'` or `FAILED` and contains `ERROR_MESSAGE` if failed.
- Verify email delivery to expected recipient or check integration logs if delivery failed.
- Repeat trigger and inspect to prove idempotency and reusability.

4. Dependencies:
- Snowflake access with ACCOUNTADMIN privileges for inspection and trigger operations.
- Validated `platform-app-configs` artifact for the tenant.

5. Risks:
- Alert procedure left in older broken form could surface SQL compilation errors during run.
- ACCOUNT_USAGE latency may cause transient CONDITION_FALSE results; tests must use direct proc call for deterministic validation.

6. Point of Contact:
- BDP platform dev: juanandres.bautista@amadeus.com
```

Example of the acceptance criteria format:
(/) = done
(x) = not done
(-) = incomplete
```
||Criteria||Status||
|Pipeline-managed recipient users exist for configured emails.|(/)|
|Notification integration exists and allows configured recipients.|(/)|
|No human/manual Snowflake users are reused for routing.|(/)|
|Client-owned distro membership is not managed by pipeline.|(/)|
|Setup uses validated platform-app-configs artifact only.|(/)|
|Setup works for both account and warehouse alert paths.|(x)|
|Validation fails loud if recipient or integration setup is broken.|(x)|
```
