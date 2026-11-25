# BLUF

**BLUF** stands for *bottom line up front*: put the conclusion or the request first, then only the support the reader needs. Military and government writers use it so a busy reader can act after one line.

Decisions, not essays. Your agent answers in its first line. When it needs you, it hands you the question, its recommendation, and the exact reply that approves it.

![BLUF demo: the same question to the same agent, without BLUF and with it](../../assets/bluf-demo.gif)

*Same agent (Pi), same question, nothing else loaded. The only difference is the BLUF rules.*

## What changes

- **The answer comes first.** The first line starts with `BLUF:` and says the answer, outcome, or verdict.
- **Asks become decisions.** Anything the agent needs from you goes under `Needs you:` as a numbered question with its recommendation and a `Reply:` you can send back as-is.
- **Sized to the stakes.** Routine choices get one line. Spending, sending, deleting, or anything you can't undo gets the full brief: options, cost, risk, what's kept or lost, deadline, evidence.
- **Checked versus guessed.** It says what it verified and marks what it's inferring.
- **Bad news first.** A failure or a mistake goes in the first line.

## Install

From the [skeleton-crew README](../../README.md#install). For Claude Code and Codex, the installer also adds a short block to your global instructions, because those agents don't apply a skill on every reply by themselves. Pi applies it from the skill alone.

## Does it work?

Measured with `evals/run.sh`; see [RESULTS.md](../../evals/RESULTS.md). With BLUF on, every answer from Claude Code, Codex and Pi opened with `BLUF:` (21 of 21; none with it off). Decision replies: Claude Code 3/3, Codex 2/3, Pi 3/3. Tested by hand on Mac, Linux and Windows 11, including the Claude Desktop Code tab.

## Turn it off

Run the uninstaller from the [skeleton-crew README](../../README.md#turn-it-off). It removes only the block it added.
