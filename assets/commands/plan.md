---
description: Expand a short prompt into a full product spec (planner agent).
---

Invoke the `planner` subagent with the following objective:

$ARGUMENTS

The planner must:
- Be ambitious about scope, stay high-level (no granular tech details).
- WRITE the spec to `memory/specs/<slug>.md` using the Write tool — persist
  it to disk, do NOT just return it inline.
- UPDATE `docs/architecture.md` to reflect the planned architecture.
- UPDATE `CLAUDE.md` if the spec changes the stack, mission, or structure.
- NOT implement any application code.

After planning, confirm to the user: where the spec was saved and which docs
were updated. Do not start building until the user approves the spec.
