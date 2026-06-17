---
description: Lightweight QA — review code and output against the spec (no browser).
---

Invoke the `evaluator` subagent to review the work that was just built.

This is the LIGHT evaluator: it reads code and output, it does NOT launch a
browser. Use it as a quick second opinion before /ship. For full UI testing
with a real browser, upgrade to the Playwright evaluator (see backlog in
HARNESS.md).

The evaluator must:
- Read the diff and the relevant files (no app execution, no Playwright).
- Check against the spec in memory/specs/ and the conventions in CLAUDE.md.
- Run the existing test suite and report pass/fail.
- Grade: spec coverage, correctness, code quality, obvious gaps —
  each with a clear verdict.
- Write the report to `memory/evaluations/<slug>-<date>.md`.
- Be skeptical: find what's missing or wrong, don't rubber-stamp.

$ARGUMENTS
