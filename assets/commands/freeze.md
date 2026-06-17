---
description: Restrict edits to a specific directory until /unfreeze.
---

Set an edit scope for the rest of this session.

Usage: `/freeze <relative-path>`

Behavior:
1. Write the path argument ($ARGUMENTS) to `.claude/.freeze`.
2. The `freeze-guard.sh` hook will block any Edit/Write outside that path.
3. Acknowledge the new scope.
4. If $ARGUMENTS is empty, read `.claude/.freeze` and report current scope.

Use when refactoring one module to prevent accidental edits elsewhere.
