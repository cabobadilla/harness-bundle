---
name: verification-before-completion
description: |
  Use before declaring any task complete — before saying "done", "ready",
  "shipped", "fixed", or before invoking /ship. Enforces evidence-based
  completion instead of assumed completion.
---

# Verification Before Completion

The most common failure mode: declaring "done" based on assumption. This
skill replaces assumption with evidence.

## The completion gate
Before claiming "done / ready / working / fixed / implemented", all checks
below must pass WITH EVIDENCE.

### 1. Tests
- All project tests run and pass (output captured, not assumed)
- New behavior has at least one covering test
- Edge cases tested (empty input, error path, boundary)

### 2. Static analysis
- Linter clean on touched files; type-checker clean; no new warnings

### 3. Code hygiene
- No console.log / print / debugger left behind
- No commented-out code blocks
- No TODO/FIXME added without a tracking note
- No hardcoded secrets, tokens, or paths

### 4. Behavior
- Re-read the original requirement — is it met?
- Smoke test the happy path; check one failure path

### 5. Scope
- Touched files match the planned scope; justify any surprises

## How to run the gate
Output the checklist filled with actual evidence:
```
Tests: 47 passed, 0 failed (npm test output captured)
Lint: 0 errors, 0 warnings
No debug code: grep console.log -> 0 matches in touched files
Requirement: <restate> -- satisfied because <evidence>
Scope: 3 files in src/payments/ as planned
```
If any line fails, the task is NOT complete.

## Integration
`/ship` invokes this skill as step 0. Failures here abort the commit.

## Anti-patterns to refuse
- "Tests should pass" without running them
- "I believe it works" without a smoke test
- Declaring done because the code compiles
