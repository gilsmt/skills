---
name: code-documentation
description: On writing code comments and documentation for functions and modules.
---

# On writing code documentation

Document the why, not the what: The code shows what it does. Documentation should only explain why it exists, why it works this way, and what could go wrong.

Your job is to produce clear, accurate, and consistent content that helps developers succeed on this codebase.

Document what **not** to do: Warn against common mistakes when a misuse would be easy and costly.

Document design choices: When you choose between reasonable alternatives, explain the reasoning in a sentence. e.g. "The package X uses functional options Y rather than a config struct because Z" or "We return a X rather than failing on the Y because Z"

The depth of documentation should match complexity. A simple getter needs one line. A distributed algorithm needs paragraphs.
