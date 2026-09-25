---
name: testing
description: Testing standards and patterns.
---

<!-- Based on https://github.com/unkeyed/unkey/blob/main/docs/engineering/contributing/quality/testing/index.mdx -->

## Why we test

Tests exist to give confidence. Confidence to ship changes quickly, confidence that refactoring will not break production, confidence that the system behaves as expected. A test suite with 90 percent coverage that misses critical edge cases is less valuable than one with 60 percent coverage that catches real bugs. Tests must earn their place: every new test has to catch a realistic regression no existing test already catches (if you can't name it, don't add it), assert observable behavior through the public interface rather than implementation details, and stay cheap — deterministic, isolated, and at the lowest level that catches the bug.

Prioritize quality over quantity. A single well-designed test that validates complex business logic is worth more than a dozen tests that exercise trivial code paths. When writing tests, ask what could go wrong in production that this test would catch. They are an investment with a return: catch regressions, document behavior, enable refactors. Write the tests that pay back; skip the ones that don't.

## When to skip

- Throwaway scripts and prototypes you'll delete
- One-off internal tooling

## What to test

Test **what callers depend on**, not how it's done internally. If a refactor preserves behavior but rewrites every line, the tests should still pass. If they don't, they were testing the wrong thing. Invest testing effort where bugs would hurt most.

```ts
// BAD — tests the implementation
expect(spy).toHaveBeenCalledWith({ format: "iso", tz: "UTC" });

// GOOD — tests the behavior callers see
expect(formatDate(new Date("2026-05-07"))).toBe("2026-05-07");
```

**High value targets:** Business logic with complex conditionals, error handling paths, concurrent code with race potential, security sensitive operations, data transformations that could silently corrupt.

**Lower value targets:** Simple getters and setters, straightforward pass-through functions, code that delegates to well-tested libraries.

**Skip entirely:** Tests that verify the programming language works.

Ask what bug this test would catch that the compiler, a code review, or a more meaningful test would not.

Each contract has one primary test owner at the strongest boundary that can
observe it (usually E2E or integration over unit). A second layer needs its
own distinct risk — e.g. transport, lifecycle, or error-mapping failure the
owner cannot reach. Prefer extending a table-driven case or shared fixture
over adding a near-duplicate test; consolidate duplicated setup in the same
change.

Avoid writing unit tests after you code. If you must test a system in
isolation, first write down all the ways it could fail, then write the code.

Highly prefer E2E tests as the sole testing mechanism. Use them to verify
complex features work. At the end of the E2E test, produce a verifiable and
repeatable artifact.

Never mock the database in tests.

## Authoring gate — before adding a test

A missing answer means do not add it yet:

1. What observable behavior, invariant, or independent contract does it protect?
2. What credible regression makes it fail? If you can't name it, don't add it.
3. Why does existing coverage not already catch that failure? State the
   distinct risk or boundary vs. the current owner.
4. Does it need a production seam (export, flag, wrapper, injection hook) that
   no production caller needs? If yes, move the test to the real boundary
   instead of adding the seam.

Then check against [junk patterns](#junk-patterns). A match fails the gate
unless [retention bar](#retention-bar) names the contract it independently
guards. A test that would break under a behavior-preserving refactor is
asserting implementation, not behavior — rewrite it at the owning boundary
before landing it.

## Junk patterns — do not add, prune on sight

Shared checklist for authoring and audits:

- Assertion-free coverage probes (test passes with no assertions).
- Self-comparisons, identity copiers, tautologies.
- Copied fixtures, inventories, manifests, or export lists that re-assert source.
- Exact source, import, or string greps (unless they meet the retention bar below).
- Private-predicate or call-shape tests duplicated at a real boundary
  (e.g. `toHaveBeenCalledWith` where a behavior assertion would do).
- Duplicate invocations of the same contract at multiple layers without
  distinct risk.
- Provider-local replays of shared helpers (same helper re-tested per consumer).
- Tests whose only purpose is preserving test-only exports, globals, or wrappers.
- Dead production code whose only callers are tests.
- Expected values produced by the helper or renderer under test.
- Mocks that implement the asserted behavior, or one identical mock standing in
  for different APIs.
- Fixtures that supply the receipt, admission, or callback ordering the owner
  should produce; persistence asserted against a store the path never writes.
- Capability tests that restate declared flags instead of exercising the
  delivery or acknowledgement the flag promises.
- Negative controls that pass for an unrelated reason (denial from a different
  guard, rejection the production path never reaches).
- Names or fixtures that promise more than the input exercises.

## Retention bar — when to keep

Keep a test when it independently enforces a public API, SDK, protocol,
config, migration, storage, security, platform, default, or architecture
contract. Also keep:

- Call ordering when order is observable behavior.
- Regressions with a credible failure mode (see below).
- Source inspection when it is the cheapest independent guard: it fails when
  the user-facing contract changes (key, byte, path) and survives an
  identifier-only refactor.
- Slow or static tests — slowness alone is not a deletion reason.

In an audit, a test that must change for a behavior-preserving reorganization
is suspect, not automatically deletable. Before judging a candidate, read the
complete test and its production owner, entry point, callers, overlapping
tests, and history. A retained test that fails on baseline is a possible
product bug — reproduce it and repair the owner rather than deleting it.

## Regression tests

Bug regression tests must fail on the pre-fix code for the intended reason
and pass after the owner-boundary repair. A regression test that never
demonstrably failed proves the mock, not the fix. One regression at the owner
boundary covers the bug; do not replay the same scenario at every layer it
crosses.

## Test-only seams

Delete obsolete test-only exports, globals, wrappers, and dead production
paths instead of preserving aliases. Move retained regressions to their
canonical owners. Prefer net-negative production LOC. Do not add replacement
tests that restate the same implementation, and do not convert uncertain
candidates into cleanup to inflate deletion counts.

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

For integration tests that require substantial setup, expensive cross-service or external dependencies, put in an `integration/` subdirectory when it improves clarity, and for end-to-end testing `e2e/`.

## Running tests

During development, run tests for the package you are working on:

Before pushing, run the full test suite:

```bash
bun test
```

Tests that acquire resources must clean them up.

## Quick checklist

- [ ] Authoring gate answered (behavior, regression, owner, no test-only seam)
- [ ] No junk pattern match, or retention bar names the contract
- [ ] Regression fails pre-fix for intended reason, passes after
- [ ] One owner boundary per contract; no cross-layer replays
- [ ] Tests exercise behavior, not implementation
- [ ] Backend logic uses integration tests (real DB) by default
- [ ] Mocks only as last resort; prefer real or fake
- [ ] Each test self-sufficient (no order dependence)
- [ ] Fast reset (transaction rollback) between integration tests
- [ ] E2E covers golden path; doesn't try to cover everything
- [ ] No sleep() band-aids; flakes are bugs to fix
- [ ] Time / random / network injected, not real
- [ ] Coverage isn't the goal; bug recurrence is

<!-- Lessons merged from https://github.com/openclaw/openclaw/blob/main/.agents/skills/test-audit/SKILL.md: authoring gate, junk patterns, retention bar, owner-boundary, regression discipline, test-only seams. OpenClaw-specific workflow (CAMPAIGN.md, run-vitest, crabbox, autoreview, PR flow) intentionally omitted. -->
