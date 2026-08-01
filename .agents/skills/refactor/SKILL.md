---
name: refactor
description: Structural refactoring and code simplification pass. Use this skill whenever the user wants to clean up, simplify, refactor, restructure, or improve code clarity, consistency, maintainability, or efficiency. Triggers on phrases like "refactor", "clean up", "simplify", "improve readability", "remove duplication", "make this cleaner", "optimize this code", or any request to restructure, consolidate, or polish recently modified or existing code and documentation. Also trigger when reviewing changed code for reuse, quality, and efficiency issues.
---

# Refactor and Simplify

Refactor and simplify code to improve clarity, consistency, and maintainability while preserving exact functionality. This skill combines structural cleanup, duplication removal, and quality review into a single workflow. Fix any issues found.

## Core Principles

### Preserve Functionality

Never change what the code does — only how it does it. All original features, outputs, and behaviors must remain intact. Test changes before and after cleanup.

### Apply Project Standards

Follow established coding standards from AGENTS.md and the surrounding codebase. Use consistent formatting, naming conventions, and patterns. Prefer explicit, readable code over compact or clever solutions.

### Enhance Clarity

Simplify structure by reducing unnecessary complexity and nesting. Eliminate redundant code and abstractions. Consolidate related logic. Choose clarity over brevity — explicit code is easier to reason about and maintain.

- Avoid nested ternary operators; prefer early returns, switch statements, or if/else chains
- Break overly compact chains into named intermediate steps
- Remove unnecessary comments that describe obvious code
- Declare variables at the smallest possible scope

### Remove Duplication

Find and consolidate duplicate code into reusable functions or shared utilities. Identify repeated patterns across files and extract common abstractions. Merge similar configuration or setup instructions.

### Maintain Balance

Avoid over-simplification that reduces clarity or combines too many concerns. Do not remove helpful abstractions that improve organization. Prioritize readability over line count.

## Workflow

### Scope

Focus only on the specified file(s) or directory. Do not make changes outside the target area unless duplication requires extracting a shared utility to an appropriate common location.

### Phase 1: Identify Changes

If reviewing recent work, run `git diff` (or `git diff HEAD` if there are staged changes) to see what changed. If there are no git changes, review the most recently modified files the user mentioned or that were edited earlier in the conversation.

### Phase 2: Launch Three Review Agents in Parallel

Analyze the code from three angles. Use the Task tool to launch all three agents concurrently in a single message. Pass each agent the relevant files so it has the complete context.

### Agent 1: Code Reuse Review

1. **Search for existing utilities and helpers** that could replace newly written code. Look for similar patterns elsewhere in the codebase — common locations are utility directories, shared modules, and files adjacent to the changed ones.
2. **Flag any new function that duplicates existing functionality.** Suggest the existing function to use instead.
3. **Flag any inline logic that could use an existing utility** — hand-rolled string manipulation, manual path handling, custom environment checks, ad-hoc type guards, and similar patterns are common candidates.

### Agent 2: Code Quality Review

Review the relevant file(s) for hacky patterns:

1. **Redundant state**: state that duplicates existing state, cached values that could be derived, observers/effects that could be direct calls
2. **Parameter sprawl**: adding new parameters to a function instead of generalizing or restructuring existing ones
3. **Copy-paste with slight variation**: near-duplicate code blocks that should be unified with a shared abstraction
4. **Leaky abstractions**: exposing internal details that should be encapsulated, or breaking existing abstraction boundaries
5. **Stringly-typed code**: using raw strings where constants, enums (string unions), or branded types already exist in the codebase
6. **Unnecessary JSX nesting**: wrapper Boxes/elements that add no layout value — check if inner component props (flexShrink, alignItems, etc.) already provide the needed behavior

### Agent 3: Efficiency Review

Review the relevant file(s) for efficiency:

1. **Unnecessary work**: redundant computations, complexity, repeated file reads, duplicate network/API calls, N+1 patterns
2. **Missed concurrency**: independent operations run sequentially when they could run in parallel
3. **Hot-path bloat**: new blocking work added to startup or per-request/per-render hot paths
4. **Recurring no-op updates**: state/store updates inside polling loops, intervals, or event handlers that fire unconditionally — add a change-detection guard so downstream consumers aren't notified when nothing changed. Also: if a wrapper function takes an updater/reducer callback, verify it honors same-reference returns (or whatever the "no change" signal is) — otherwise callers' early-return no-ops are silently defeated
5. **Unnecessary existence checks**: pre-checking file/resource existence before operating (TOCTOU anti-pattern) — operate directly and handle the error
6. **Memory**: unbounded data structures, missing cleanup, event listener leaks
7. **Overly broad operations**: reading entire files when only a portion is needed, loading all items when filtering for one

### Phase 3: Fix Issues

Aggregate findings and fix each issue directly. If a finding is a false positive or not worth addressing, note it and move on — do not argue with the finding, just skip it. Verify nothing breaks during removal or consolidation.

When done, briefly summarize what was fixed or confirm the code was already clean.

## Documentation Cleanup

- Update broken references and links
- Add comments only where they ensure consistency or explain non-obvious decisions

## Examples

### Before: Nested Ternaries

```typescript
const status = isLoading ? 'loading' : hasError ? 'error' : isComplete ? 'complete' : 'idle';
```

### After: Clear Conditionals

```typescript
function getStatus(isLoading: boolean, hasError: boolean, isComplete: boolean): string {
  if (isLoading) return 'loading';
  if (hasError) return 'error';
  if (isComplete) return 'complete';
  return 'idle';
}
```

### Before: Overly Compact

```typescript
const result = arr.filter(x => x > 0).map(x => x * 2).reduce((a, b) => a + b, 0);
```

### After: Clear Steps

```typescript
const positiveNumbers = arr.filter(x => x > 0);
const doubled = positiveNumbers.map(x => x * 2);
const sum = doubled.reduce((a, b) => a + b, 0);
```

### Before: Redundant Abstraction

```typescript
function isNotEmpty(arr: unknown[]): boolean {
  return arr.length > 0;
}

if (isNotEmpty(items)) {
  // ...
}
```

### After: Direct Check

```typescript
if (items.length > 0) {
  // ...
}
```
