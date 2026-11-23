---
name: automate-me
description: 'Use for "automate me", "create/update/refresh my -mode skill", "turn/capture my preferences or working style into a skill", or wanting agents to follow how the user works. Drafts or revises a personal -mode skill using stated preferences and optional evidence from recent workspace transcripts.'
disable-model-invocation: true
---

<!-- Based on https://github.com/cursor/plugins/blob/main/pstack/skills/automate-me/SKILL.md -->

# Automate me

A guided flow for turning the user's working conventions into a skill agents will follow. The output is one `-mode` skill tailored to them (e.g. `jay-mode`, `priya-mode`).

Use the active harness's skill-authoring guidance when available.

## Flow

### 0. Check for an existing skill

Look for an existing `*-mode/SKILL.md` matching the user's handle in the active harness's project and personal skill directories. Check nested categories too. If you find one and the user's intent is unclear, ask whether to update it or start fresh:

- Update the existing skill (default for repeat runs)
- Start fresh (rare, ask why before doing it)

Update mode changes the rest of the flow:

- Step 1 mines only history since the skill was last edited (`git log -1 --format=%cI <path>`).
- Step 2 asks what's changed or missing, not what to capture from zero.
- Step 4 edits the existing file in place. Preserve sections the user hasn't contradicted. Revise ones with new evidence. Add new sections only for genuinely new rules.

### 1. Mine their history

Use transcript history only when the active harness provides a workspace-scoped source. If it is unavailable, gather preferences directly from the user.

Survey recent conversations for recurring patterns. If delegation is available and authorized, split the review into independent date ranges. Give each reviewer only the workspace-scoped source and its assigned range. Choose reasoning effort for the work if the harness supports it. Otherwise review the available history directly. Record evidence for recurring patterns such as:

- Response preferences (length, tone, format, "dumb it down" corrections)
- Delegation habits (subagents, models, specialized workflows, parallelism)
- Verification posture (what "done" means, unit tests vs live repro, reviewers)
- Code and prose discipline (style, principles cited, lint/format tools)
- Process conventions (worktrees, commits, PRs, review/merge tooling)
- Meta preferences (fixing skills mid-task, proposing new ones)

Look for recurrence across independent conversations. Use the interview to confirm uncertain preferences.

### 2. Ask the user directly

Ask one or two focused questions at a time about gaps or conflicting evidence. Use structured choices when available and give the user room to add a preference in their own words.

### 3. Cluster findings

Group the combined signals into sections. Common ones (use only what applies):

- **Response style**: length, tone, format.
- **Autonomy**: how much to do without asking, MCP tool use.
- **Understand first**: which skills to reach for when scoping or investigating a change.
- **Subagents**: default, parallelism, model-to-task, specialized workflows.
- **Prose / code discipline**: principles, lint tools, style guides.
- **Review and verify**: repro posture, verification skills, live-testing tools.
- **Process**: git worktrees, commits, PRs, review/merge tooling.
- **Skills**: skill-authoring habits, fix-the-skill-first, proposing new skills.

### 4. Draft the skill

- Preserve the path of an existing mode skill. For a new project skill, follow the project's existing skill layout or use `.agents/skills/<handle>-mode/SKILL.md` in a repository that uses the shared layout. For a personal skill, use the active harness's personal skill directory.
- Handle: the user's first name or chosen identifier.
- Frontmatter `description`: trigger on their name + `/<handle>-mode` + "work in their style", not on generic keywords like "write code" or "review PR".
- Frontmatter formatting: follow the active harness's skill format. Keep `description` as one YAML scalar. Quote it or use `description: >-` with indented continuation lines when punctuation or wrapping requires it.
- Default to explicit invocation where the harness supports it. Opt out only if the user explicitly wants their mode to apply on every turn.

### 5. Iterate on prose

Keep each rule concise, concrete and actionable.

Show the draft to the user and take feedback. Expect multiple iterations. Cut ruthlessly. A mode skill is not a manual.

### 6. Land it

Apply the agreed edits in the chosen skill directory. Follow the repository's workflow when the user asks to commit or open a PR.

## Guardrails

- **Don't overfit to one conversation.** A preference stated once and contradicted another time is noise. Require multiple instances before codifying it.
- **Don't be clever.** Restating other skills' contents, inventing metaphors, or writing "poetic" prose for an agent reader is cost without benefit. Keep it operational.
- **Reference, don't inline.** Other skills the user relies on should appear as path references, not pasted excerpts. Same for any principle docs they maintain elsewhere.
- **Keep sections minimal.** Only add a section if the user has a specific, non-default rule there. "Communicate clearly" is not a section. "Short paragraphs. Tables when comparing options. Bullets only when items are genuinely parallel." is.
- **Name conventions generic.** Use "the user" or "the human" in imperatives, not the author's first name.
- **Don't force symmetry.** If a user has no process rules worth writing down, skip the Process section entirely.

## Evaluation

Ask whether the draft reflects the user's preferences and whether it misses anything important. Revisit the description if the skill triggers at the wrong times in practice.

## When not to use

- User wants a task-specific skill (not working conventions): use the active harness’s skill-authoring guidance.
- User wants to capture one narrow workflow (e.g. "how I write commit messages"). That's a regular skill, not a mode skill.
