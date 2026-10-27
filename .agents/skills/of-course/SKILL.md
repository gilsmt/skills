---
name: of-course
description: Finds high-value obvious-in-hindsight fixes by hunting inconsistency and missed reuse. Use when reviewing a codebase for small surgical quality-of-life improvements, aligning divergent sibling paths, or when the user asks for "of course" improvements.
disable-model-invocation: true
---

# Of Course

Find the single smallest change that, once seen, feels obvious — a quality-of-life fix that aligns code with how it clearly already intends to behave.

This is not a feature skill. This is not a refactor skill. If the fix needs a new abstraction, it is the wrong fix — keep looking.

## When to Use

- User asks for "of course" improvements, quick wins, or obvious cleanups.
- Reviewing unfamiliar code for inconsistency before changing it.
- A helper, constant, or pattern exists but is unevenly applied.

## Do Not Use For

- New features, behavior changes, or API redesigns.
- Large refactors or structural reorganization.
- Introducing a new utility, abstraction, or dependency. Reuse what exists.

## Workflow

### 1. Map intent

Read before hunting. Establish what the code claims to do:

- Read the documented examples, README, and comments in the area.
- Read both the suspect function and its siblings/callers — never snippets alone.
- Note the "smart path" if one exists: the helper, constant, or branch that already handles the concept correctly.

### 2. Hunt inconsistency and missed reuse

Search in this order. Prefer grep/glob and parallel subagents over reading at random.

1. **Divergent sibling paths.** Find two places that should behave identically but don't. Tell: function A handles a concept the smart way, and function B — often one A calls into — handles it the naive way (dedicated parser vs. raw conversion, validated vs. unvalidated branch).
2. **Existing machinery unused where it should be.** Inventory helpers, utilities, constants, and patterns already in the repo. Find the spot that reimplements one badly or skips it. The best fix applies something already there and adds no new abstraction.
3. **Behavior that contradicts user intent.** Find cases where reasonable, even documented, usage silently does the wrong thing (e.g. string `"false"` treated as truthy). The gap between what a user obviously meant and what the code does is where these fixes live.

Rank candidates by: obviousness once seen > smallness of diff > confidence in safety. Keep only the single best.

### 3. Prove the best candidate

Ground every claim in code actually read. Cite `file:line` for:

- The correct path (X does it this way).
- The divergent path (Y should match but does it that way).
- The existing helper/constant to reuse, with its definition site.

Then write a minimal reproduction showing wrong behavior vs. correct expected behavior side by side. Do not proceed without one.

### 4. Fix surgically

- Smallest diff that removes the inconsistency. Prefer 1–5 lines.
- Reuse the existing helper/constant/pattern. No new abstraction, no new dependency.
- Must be explainable in one sentence that makes the reader think "oh, obviously."

### 5. Validate safety and lock it down

- Confirm existing/correct inputs behave exactly as before — only the mishandled case changes.
- Write the regression test before the fix, watch it fail, apply the fix, watch it pass.
- Run the repo's gate: lint, type-check, affected tests.
