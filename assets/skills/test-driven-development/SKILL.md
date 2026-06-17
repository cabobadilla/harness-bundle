---
name: test-driven-development
description: |
  Use before writing implementation code for any non-trivial business
  logic. Triggers: "implement <feature>", "add <function>", "build <X>"
  where X is non-trivial. Enforces test-first discipline. Skip for: pure
  config edits, doc changes, one-line refactors, throwaway spikes.
---

# Test-Driven Development

Write the test first. See it fail. Implement. See it pass. Refactor.

## When TDD applies (default: YES)
- New function/method with non-trivial logic
- Any bug fix (the regression test IS the test)
- Anything touching money, security, or data integrity

## When to skip
- Config/env changes, docs, cosmetic/formatting
- Exploratory spikes deleted in the same session

## The loop
1. **RED** — write a failing test. Name it after the behavior
   (`processes_payment_with_valid_card`). Run it, confirm it fails for the
   right reason. If it passes immediately, you wrote the wrong test.
2. **GREEN** — minimum code to pass. Hardcoded returns allowed. Don't
   generalize yet.
3. **REFACTOR** — remove duplication, improve naming, tests stay green.
4. **Repeat** — next behavior → next test. Commit when a cycle ends green.

## Test quality
- One behavior per test; name reads as a spec
- Arrange / Act / Assert; assert on outputs, not internals
- Deterministic — no flaky time/random/network

## Anti-patterns to refuse
- Writing all tests AFTER implementation ("retroactive TDD")
- Tests that never failed — they prove nothing
- Mocking what you're testing
- Over-specified tests that break on any change
