---
description: Review unstaged changes for unnecessary code
---

Use @code-deslopify to review unnecessary code. (Target: $ARGUMENTS) If no target was supplied, inspect only unstaged changes (`git diff`), excluding staged changes. If there are no unstaged changes, report that and stop; do not broaden scope. Default to review only: report what you would remove or simplify, with locations, concrete reasons, and any material tradeoff. Do not edit unless explicitly asked to make changes. Optimize for the smallest maintained code surface, not the smallest patch. Preserve required behavior, real boundary protections, and valuable tests.
