# Project priorities

1. iridium / edge / site
- Core business value.
- Highest external leverage.
- Direct effect on product, users, and long-term upside.

2. exoskeleton
- Meta-leverage project.
- Targets core failure mode in current AI-assisted workflow: model output outruns human understanding.
- Goal not speed. Goal cognitive assimilation.
- Replaces acceptance-heavy codegen flow with reconstruction-heavy flow.
- Worth prioritizing because it can improve quality of work across iridium, edge, site, zetesis, and future projects.
- Constraint: must reduce cognitive load inside existing flow, not create bureaucracy, dashboards, or separate maintenance burden.

3. zetesis
- High daily-use value.
- Already active and clearly useful.
- Strong personal leverage through editor/tooling quality.
- Below exoskeleton because exoskeleton could improve whole development loop, not only one tool.

4. grit-v2 / zql
- Both strong personal-value projects.
- grit-v2: personal infrastructure, strong life-QOL, blocked by sync/integration model.
- zql: strong technical niche, real gap, good future optionality.
- Important, but lower than zetesis and exoskeleton because value is narrower.

5. browser extensions
- Good ideas, but polish-heavy and time-hungry.
- Fuzzy finish line.
- Lower leverage than projects above.

## Priority logic

Use this order:
- business value first
- then leverage multipliers
- then high-frequency personal tooling
- then bounded personal infrastructure / niche builds
- then polish projects

## exoskeleton thesis

Current failure mode:
- AI generates functional code fast.
- Human understanding lags behind.
- Review becomes shallow.
- Codebase quality drifts.
- Learning collapses.

Core proposition:
- intervene at codegen flow level
- add friction at acceptance point
- invert tab completion: model proposes, human writes to accept
- move chunk by chunk through modifications
- allow model revision or manual takeover at each step
- optimize for understanding, not passive acceptance

## exoskeleton MVP direction

First target:
- intervention between Neovim Lua side and TypeScript codegen side

Open question:
- direct integration vs middleman process
- do not decide by architecture taste
- decide by smallest path to proving core loop

MVP success condition:
- human understands changed code better
- human stays in flow
- throughput drops less than comprehension improves
