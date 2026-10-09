---
name: standup
description: 'Build a standup report from git history — what landed, what is still in flight, and what to do next. Use when the user says "standup", "what did I do (yesterday|friday|last week)", "catch me up", "what did <person> work on", "what changed while I was away", "anything from my stash", or asks for a daily or weekly sync update. Covers multi-repo workspaces, uncommitted work, stashes, unpushed branches, GitHub PRs and review requests.'
---

# Standup

Answer two questions with evidence from git, never from memory:

1. **What happened** — what landed, grouped into themes a human would recognize.
2. **Where I left off** — what is uncommitted, stashed, unpushed, or awaiting review.

The second question is where most standup tools stop working. `git standup` (https://github.com/nilbuild/git-standup) reports commits in a window and nothing else, so it cannot answer "what was I in the middle of". Uncommitted work, stashes, and unpushed branches are the state you actually have to reconstruct on Monday morning.

## Rules

- **Read-only by default.** Never run a command that changes the working tree, the index, or a ref. Forbidden without an explicit request in the current turn: `git reset`, `git checkout --`, `git restore`, `git clean`, `git stash` (including `pop`/`drop`/`clear`/`apply`), `git commit`, `git push`, `git add`, `git rebase`, `git merge`, `git cherry-pick`, `git revert`, `git update-ref`. These destroy or hide work: a stashed change leaves the normal status and diff flow and gets forgotten.
- **`git fetch` is allowed** — it only downloads. It does not touch the working tree, the index, or local branches. Run it when the user wants other people's work, since local clones are often days stale. It does move remote-tracking refs, so if the user has asked for a strictly no-ref-changes session, skip it and say so.
- **Confirmation does not carry over.** Approval for a git mutation in an earlier conversation is not approval now. Ask each time, every run.
- **Never suggest a destructive recovery.** A dirty tree invites "want me to `git restore` that?" Do not offer. Report what is uncommitted and let the user decide.
- **Never invent activity.** Every line traces to command output. If there were no commits, say there were no commits.
- **Ask before writing files.** Default is to print only.

## Step 1 — Scope

Establish, in this order. Do not guess past a question the user already answered.

- **Whose work.** Default: the current user (`git config user.name`). "Nosy" means someone else: `--author "Name"`. "Everyone" is `--author all`.
- **Which repos.** Default: if the current directory is a repo, just that one. Otherwise, every repo at or one level below the current directory. Honor a `.git-standup-whitelist` file if present.
- **Which window.** Default: the last working day. See below.

`--author` takes a regex matched against the author name, unanchored. `--author "Jane"` matches "Jane Doe", which is convenient but also means one person's commits can be attributed to another: `--author "Test"` returns commits by both "Test User" and "Test Runner". When a name could belong to more than one person, run `--author all` once and attribute by eye.

To exclude people rather than include them, set `git config --global grep.patternType perl` and use a negative lookahead: `--author '^(?!(renovate\[bot\]|dependabot))'`. "Everyone except bots" is otherwise tedious.

## Step 2 — Resolve the window

Weekends are the failure case. "Last working day" on a Sunday is not "yesterday" — it is Friday, and asking git for `--since=yesterday` returns nothing and looks like a day with no work.

Logic, matching `git-standup` with the weekend gap closed:

| Today | Window starts |
| --- | --- |
| Working day, not the first of the week | midnight yesterday |
| First working day of the week (Mon) | midnight of the previous week's last working day (Fri) |
| Non-working day (Sat/Sun) | midnight of the most recent working day |

Non-Mon-Fri weeks need `--week SUN-THU` or similar. Ask if the user works a non-standard week rather than assuming.

## Step 3 — Collect

```bash
scripts/collect.sh --author "<name|all>" [--scope auto|current|dir] [--root DIR] \
                   [--max-depth N] [--week MON-FRI] [--days N] [--since DATE] \
                   [--until DATE] [--branch B] [--no-state]
```

Run it from the skill directory, or with an absolute path. Output is tab-separated, uncolored, one block per repo: `--- meta`, `--- commits`, `--- author_used`, `--- commits_count`, `--- uncommitted`, `--- uncommitted_diffstat`, `--- stashes`, `--- unpushed`, `--- branches_recent`, `--- whitespace_only_commits`.

`--max-depth` is passed straight to `find`, so it counts directory levels: the default `2` finds repos in the current directory and one below. Unlike upstream's `-m`, which adds one internally. If a workspace run reports zero repos, that is the flag to raise, not a bug.

Read `--- window` from the header before interpreting anything; it states the resolved bounds. The script already excludes merge commits and drops whitespace-only commits from the theme grouping — they are still listed under `--- commits` so nothing is hidden.

Verify the author resolved as intended via `--- author_used`. If it reads `<unset: pass --author>`, `git config user.name` is unset and no author filter can apply.

## Step 4 — Pull remote context

Only when asked, or when the user wants other people's work. All read-only.

```bash
git fetch --all --quiet                     # per repo, makes other people's work visible
gh pr list --author @me --state open        # PRs awaiting review or CI
gh pr list --search "review-requested:@me"  # someone is waiting on the user
gh issue list --assignee @me --state open    # candidates for "today"
gh run list --branch "$(git branch --show-current)" --limit 5   # is CI red
```

Check `gh auth status` first and degrade gracefully when it is unavailable — say so rather than silently reporting less.

A red CI run or an open review request is a **blocker**, not a task. Blocking on someone else is the most useful thing a standup can surface, and it is invisible to a commit log.

## Step 5 — Group into themes

Report themes, not a commit list. Fourteen commit subjects is not a summary; three sentences naming what changed is.

- Cluster by **what changed**, not by when. "Retried webhook delivery and made it idempotent" beats three separate retry-related lines.
- Drop whitespace-only commits (flagged by the script) and dependency bumps unless they changed behaviour.
- Keep `fix:` commits that fixed a user-visible symptom, and say what the symptom was. "Parser no longer crashes on empty input" is worth a line; "various fixes" is not.
- Merge commits are already excluded. Do not re-add them.
- Per repo, aim for one to four bullets. If a repo has nothing, say "no commits" and move on.

Distinguish **committed** from **uncommitted** throughout. Uncommitted work is a claim about what someone intends to do; committed work is a fact.

## Step 6 — Write the report

Print two parts, in this order.

**1. Where things stand** — the recall layer, only if there is anything to say.

Lead with in-flight work, not commits. A dirty tree or a stash from three days ago is the answer to "what was I doing"; the commit log is not.

Call out, when present:

- Uncommitted changes, with the file count and a rough sense of size from the diffstat.
- Stashes, by age. A stash older than a few days is usually either important or dead, and nobody can tell which from memory. Surface it with its age and subject (`stash list --date=relative` reads better than the raw ISO date) and leave the decision to the user. Never propose popping, applying, or dropping one.
- Unpushed commits and WIP branches.
- Anything requiring another person: open review requests, red CI.

**2. Standup update** — the paste artifact. Plain text, no markdown headers beyond these labels, no bold, sized for a Slack message.

```
Yesterday
- <theme> (<repo>)
- <theme> (<repo>)

Today
- <intent, from in-flight work where possible; otherwise from open issues>

Blockers
- <what, and on whom> 
```

Omit `Blockers` entirely when there are none. Do not write "No blockers" — an empty section is cleaner than a negative claim.

Derive `Today` from evidence: an open PR awaiting review, a branch with unpushed commits, an assigned issue. When nothing constrains it, say what the unfinished work implies rather than inventing a task.

## Scope notes

- **Multi-repo**: run the script once from the parent directory; it handles recursion, and each repo gets its own block. Repo names in the report make the aggregation legible.
- **Linked worktrees**: a worktree's `.git` is a file, not a directory, so `git standup` skips it. The script includes them, which means the same commits can appear twice — once for the branch, once for the worktree checking it out. Deduplicate by SHA when counting, and prefer the primary checkout when both appear in the same report.
- **Shared `--author` identity**: if the user commits to some repos under a work email and others under a personal one, a single name filter misses commits. Compare `cfg_email` across repos in the output; if they differ, collect per repo or pass `--author all` and filter locally.
- **Single-repo detail**: for a deeper read on one repo, `git log -p -1 <sha>` and `git show <sha>` for the commits that matter.
- **No commits at all**: report the window, state that nothing landed, and show the in-flight state instead. That is a real and common answer.