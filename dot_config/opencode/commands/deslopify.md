---
description: Aggressively remove unnecessary code from the current change
---

Use @code-deslopify to clean up the current change, not merely review it. Target: $ARGUMENTS. If no target was supplied, inspect and clean up the current diff only. Optimize for the smallest maintained code surface, not the smallest patch: delete or simplify anything without a concrete requirement, caller contract, real failure mode, or meaningful safety benefit. Preserve required behavior and valuable tests, run focused verification, and report what was removed plus any material tradeoff.
