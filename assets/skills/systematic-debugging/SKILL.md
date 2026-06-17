---
name: systematic-debugging
description: |
  Use this skill whenever a bug, unexpected behavior, failing test, or
  "it doesn't work" situation appears. Triggers: stack traces, test
  failures, "not working", "broken", "weird behavior", "regression".
  Enforces a disciplined debugging loop instead of guess-and-patch.
---

# Systematic Debugging

A bug is a hypothesis test. Skip steps and you debug-by-coincidence.

## Loop

1. **Reproduce** — get a deterministic repro before changing anything.
   Smallest input that triggers the bug. If you can't reproduce, STOP and
   gather more info — do not patch.
2. **Isolate** — narrow the surface. `git bisect` if recent; binary-search
   the code path. Find the smallest unit that exhibits the bug.
3. **Diagnose** — form a falsifiable hypothesis BEFORE changing code:
   "I believe X causes Y because Z." Verify the prediction with an experiment.
4. **Fix** — change ONE thing. Minimum change at the root cause, not a
   workaround. If the fix touches >1 module, you probably misdiagnosed.
5. **Verify** — original repro now passes; adjacent tests still pass; add a
   regression test for this specific bug.
6. **Document** — one paragraph in memory/decisions.md if the bug taught
   something non-obvious about the system.

## Anti-patterns to refuse
- Random changes hoping one works
- "Let me just add a try/except" without understanding the error
- Fixing the symptom instead of the cause
- Patching without a regression test
- Declaring "fixed" without re-running the original repro

Even under time pressure: at minimum reproduce → diagnose → fix → verify.
