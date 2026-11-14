---
name: code-documentation
description: On writing code comments and documentation for functions and modules. Run this before adding or editing any comment. The default is no comment.
---

# On writing code documentation

Document the why, not the what: The code shows what it does. Documentation should only explain why it exists, why it works this way, and what could go wrong, only when it tells a reader something the code cannot or isn't obvious.

Produce clear, accurate, and consistent content that helps developers succeed on the codebase.

Document what **not** to do: Warn against common mistakes when a misuse would be easy and costly.

Document design choices: When you choose between reasonable alternatives, explain the reasoning in a sentence. e.g. "The package X uses functional options Y rather than a config struct because Z" or "We return a X rather than failing on the Y because Z"

The depth of documentation should match complexity. A simple getter needs at most one line. A distributed algorithm may need multiple.

Use mostly ASD-STE100 Simplified Technical English. Active-voice, simple tenses, single-meaning sentences, and consistent terms. Avoid redundant, dense, jargon-heavy, or ambiguous prose.

Never log change history or chat context in code — no "previously did X, now does Y", "per <task/PR>", "changed because…", or "AI:"/"agent:" notes.

When refactoring or moving code, preserve existing comments unless they are explicitly made obsolete by the change.

No em-dash. Avoid any two-part phrase joined by a dash, like `# do the thing — it's faster`. Use a connective instead ("because", "so that", "which means", "to avoid").

- ❌ `# batch here — avoids N+1`
- ✅ `# batch here to avoid an N+1 against posthog_organizationmembership`

## When you're tempted to comment

Try, in order: (1) a better name, (2) a smaller function, (3) a type. Reach for a comment only when none of those can carry the meaning.
