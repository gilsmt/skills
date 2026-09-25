# Do not over-abstract

<!-- Based on https://ondrejvelisek.github.io/the-cost-of-abstraction-for-humans-and-ai-agents -->

Every abstraction is a boundary the reader must jump across. For an agent,
a jump into another file is a round trip and a first read of new tokens; that, not the amount of code,
is the bill. Measured: up to 5x on a one-value change, about 30% over a normal mix of work.
Abstractions inside one file are nearly free for agents but still cost humans. Abstractions across files cost both.

**Default: inline.** Add a function, constant, hook, component, class, file or layer only if at least one holds:

- It hides non-trivial logic the caller should not have to read.
- It is used in three or more places with identical intent. Two is not enough.
- A likely change would otherwise land in three or more files that always change together.
- It names a well-known concept (`PI`, `HTTP_UNAUTHORIZED`), not a plain value.

Otherwise inline it. When unsure, inline it. Duplication is cheaper than the wrong abstraction.
Abstraction is fine; put boundaries only where they pay for themselves.

**Collocate.** One file per feature or component, not per function and not per layer.
No barrel `index.ts`, no per-feature `types/` `constants/` `hooks/` `utils/` split.
If you need to split complex code, split it vertically: by feature and component, not by layer.

**Types, not indirection, for values.** `const user: User = { name, email, age }`, not `createUser(name, email, age)`.
`variant="outline"` inline, not `const VARIANT = "outline"` reused twice.
Never abstract a value expression. Tighten the type instead: literal unions, discriminated unions, enums.

**A new feature is a new file, not a new table entry.** Add it as its own file next to similar ones.
Do not create a data table, config list, generic factory or base class that generates features from entries
just to hold the first or second one. If such a table (or a shared token) already exists, add your entry there;
do not bypass it with a one-off.

**Components.** Write static JSX out; do not `array.map` over a static list to render it.
Read context in the deepest component scoped to it, never in a parent that then prop-drills.
Exception: a generic reusable component, which should not be hooked into a specific context.
No HOC where a hook does. No primitive stacks (`Box` → `Stack` → `BaseButton` → `Button`),
no slot-based compound component for one or two fixed layouts, no wrapper that only forwards fixed props,
unless they already exist.

**Styling.** If the project uses utility CSS (Tailwind or similar): utility classes on the element.
No per-component class holding one or two declarations. No `variant` → class map → `.btn-x` → `--token` chain.
A shared token only for values many components share and change together.

**Naming.** No layer that only renames (`STATUS_TO_TYPE[status]`). Reuse the names of the library, API or
backend you consume, even when they are slightly off. One vocabulary, not two.
When you do abstract, name the file after the concern it owns. Good file names are the one abstraction
that measurably helps agents find things.

**When editing existing code.** Change the existing layer; never add a new one on top because the old one is unfamiliar.
Never refactor toward abstraction unasked. Never extract helpers, constants or components from code you were
not asked to touch. On meeting a wrong abstraction, prefer inlining it back into its callers over extending it.
Removing a feature: delete every type, handler, token or layer left with no other user.
Nothing "for future flexibility". Wait for the third concrete case.

**Before you add a boundary, ask:**

1. What does it hide? "Nothing, it forwards" → do not add it.
2. How many callers today? Fewer than three → inline.
3. Does the reader now open more files to answer a trivial question? → reconsider.
4. Is this the deepest place scoped to the value, or am I about to prop-drill?

Source: [The Cost of Abstraction for Humans and AI Agents](https://ondrejvelisek.github.io/the-cost-of-abstraction-for-humans-and-ai-agents).
