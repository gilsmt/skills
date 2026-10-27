---
name: generalize-upstream-fix
description: Generalize an upstream bug fix to your codebase. Use when given an upstream PR or commit and asked whether the same bug class exists locally; finds analogues, verifies each, and fixes only what is proven.
disable-model-invocation: true
---

# Generalize Upstream Fix

## Overview

Extract the bug class from an upstream change, not its specifics. Audit the local codebase for the same shape. Fix only verified instances.

## Workflow

1. Read upstream

- Fetch the patch (`.patch` URL), not the discussion page.
- State the bug class in one sentence per fix (e.g. "function value mistaken for state updater", "document-scoped lookup misses shadow trees").

2. Map to local shapes

- Translate each class into code patterns to grep for (types that admit functions, swallowed test assertions, owner-document ID lookups, optional-context fallbacks, expensive calls inside comparators).
- Enumerate every match. Absence of matches is a finding, not a failure.

3. Verify each candidate

- Read each call site and its callers, not snippets.
- Question every assumption (check the helper's real implementation, confirm zero importers before deleting, confirm clean tree before editing).
- A no-change verdict beats a speculative fix (YAGNI).

4. Fix minimally and validate

- Smallest diff that removes the defect. Touch only the verified paths.
- Run the repo's gate: lint, type-check, tests.
- Report concisely with `file:line` refs: what was checked, what changed, what was deliberately left alone.
