---
name: testing
description: Testing standards and patterns. Use when the user writes tests, asks "should I write a test for this?"
---

## Why we test

Tests exist to give confidence. Confidence to ship changes quickly, confidence that refactoring will not break production, confidence that the system behaves as expected. A test suite with 90 percent coverage that misses critical edge cases is less valuable than one with 60 percent coverage that catches real bugs.

> We prioritize quality over quantity. A single well-designed test that validates complex business logic is worth more than a dozen tests that exercise trivial code paths. When writing tests, ask what could go wrong in production that this test would catch. They are an investment with a return: catch regressions, document behavior, enable refactors. Write the tests that pay back; skip the ones that don't.

## When to skip

- Throwaway scripts and prototypes you'll delete
- One-off internal tooling

## What to test

Test **what callers depend on**, not how it's done internally. If a refactor preserves behavior but rewrites every line, the tests should still pass. If they don't, they were testing the wrong thing. Invest testing effort where bugs would hurt most.

```ts
// BAD — tests the implementation
expect(spy).toHaveBeenCalledWith({ format: 'iso', tz: 'UTC' })

// GOOD — tests the behavior callers see
expect(formatDate(new Date('2026-05-07'))).toBe('2026-05-07')
```

**High value targets:** Business logic with complex conditionals, error handling paths, concurrent code with race potential, security sensitive operations, data transformations that could silently corrupt.

**Lower value targets:** Simple getters and setters, straightforward pass-through functions, code that delegates to well-tested libraries.

**Skip entirely:** Tests that verify the programming language works.

Ask what bug this test would catch that the compiler, a code review, or a more meaningful test would not.

### Testing observability

Do not verify every log line or metric increment. Test metrics that drive alerts or SLOs. Test that error conditions produce the logs operators need for debugging.

```ts
import { test, expect } from "bun:test";

test("rate limiter emits rejection metric", () => {
    const collector = new TestMetricCollector();
    const limiter = new RateLimiter({ limit: 1 }, collector);

    limiter.allow();
    limiter.allow();

    expect(collector.count("rate_limit_rejected_total")).toBe(1);
});
```

## Test organization

Unit Tests live alongside the code they test. A file `lib.ts` has its tests in `lib.test.ts` in the same directory.

For integration tests that require substantial setup or external dependencies, create an `integration/` subdirectory when it improves clarity, and for end-to-end testing `e2e/`.

## Running tests

During development, run tests for the package you are working on:

Before pushing, run the full test suite:

```bash
bun test
```

## War story

A startup's CI suite grew to 14 minutes and 800 tests, mostly mock-heavy unit tests of route handlers. They refactored from REST to tRPC, broke ~600 tests (all the mocks), and the team gave up on tests for a quarter. The replacement: 80 integration tests against a real Postgres (Testcontainers), 4 minutes total, caught more regressions than the previous 800 ever had.

## Quick checklist

- [ ] Tests exercise behavior, not implementation
- [ ] Backend logic uses integration tests (real DB) by default
- [ ] Mocks only as last resort; prefer real or fake
- [ ] Each test self-sufficient (no order dependence)
- [ ] Fast reset (transaction rollback) between integration tests
- [ ] E2E covers golden path; doesn't try to cover everything
- [ ] No sleep() band-aids; flakes are bugs to fix
- [ ] Time / random / network injected, not real
- [ ] Coverage isn't the goal; bug recurrence is
