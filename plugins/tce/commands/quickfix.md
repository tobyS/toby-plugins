---
description: Run a small fix from your description to a verified change — an autonomously written ticketless intent, then research, plan, implementation, verification and the dossier in fresh agents, without plan approval. No ticket. Needs CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=600000.
argument-hint: "[small fix, described]"
disable-model-invocation: true
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/work.sh:*), Bash(git rev-parse:*), Bash(git log:*)
---

# Quickfix

Take a small, well-understood fix from its description to a verified change
with as little ceremony as the work allows. You write no ticket: the
description becomes a **ticketless intent**, written without dialogue, and the
same step agents as every other tce command run from it — researcher, planner
and challenger, implementer, verifier. You are their **orchestrator**; you ask
only when an agent genuinely needs a decision, and you stop as soon as the
work turns out not to be small. Nothing is branched, pushed or delivered.

## Project context

This command ships in the **tce** workflow plugin and is stack- and
ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` (reader, commit
  convention) and `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md`. If either is
  missing, tell the user to run `/tce:init` and stop.
- The agents receive `${CLAUDE_PLUGIN_ROOT}/references` as `references:`.

**Usage:** `/tce:quickfix <the fix, described>` — what is wrong, what should
happen instead, and where (a command, screen, error message or file). With no
argument, ask "What should I fix?" and stop.

## 1. Preflight

Read `${CLAUDE_PLUGIN_ROOT}/references/work-loop.md` **now — in full**, and
run its Step 0 with `<command>` = `/tce:quickfix` before anything is written.

## 2. Intent

Invoke the `tce:intent` skill through the Skill tool with `--autonomous`
followed by the description, verbatim. It writes and commits a ticketless
intent and returns one line:

- `intent: <path>` → continue with that path as `<argument>`.
- `insufficient: <line>` → stop: "Not enough to go on: <line>. Re-run
  `/tce:quickfix` with that added, or use `/tce:intent` for a dialogue."

## 3. The loop

Run `work-loop.md` from its Entry with `<command>` = `/tce:quickfix` and the
intent path as `<argument>`, in this lane:

- **Start rows:** all (a fresh intent always starts at row 10).
- **Steps:** 5 — research; 6 **without the approval dialog**: ask the
  planner's questions only when it returns some, run the challenger rounds,
  print the brief and the challenger notes, and ask "Decisions for you" only
  when it is not `None.` — then go straight on; 7 — implement; 8 — verify,
  with the bounded fix loop and the gate; 9 — dossier; 10 in its *no
  delivery* variant; 11 — closeout and summary; 12 — items for you to check.
- **Otherwise:** none.

**Not-small stop.** Stop — before asking anything further — when the
planner's questions include the design-exploration question, or when the
brief's `Phases:` count is above 2:

```
This is larger than a quickfix (<the design-exploration question | N phases>).
The intent and any plan stay committed. Create a ticket and run
/tce:intent <ID> to agree it, or continue with /tce:work <intent path>.
```

**Resuming.** Wherever the loop prints a re-run line (`<command> <argument>`
in a stop message, "Stop here" or "Not yet"), print
`/tce:work <intent path>` instead: a second `/tce:quickfix` would write a
second intent. For a ticketless intent `/tce:work` always delivers Direct, so
it resumes exactly where this run stopped.

## Rules

1. **Small means at most two phases and no new UX flow** — the not-small stop
   enforces it; never trim a plan to fit.
2. **Never skip verification.** The verifier, the bounded fix loop and the
   plan-compliance gate run exactly as in every other lane.
3. **Never branch, push or deliver** — ticketless work stays on the current
   branch; the human decides what happens next.
4. **Ask only on a genuine decision** — a planner question, a "Decisions for
   you" item, a `needs decision` or `blocked` stop, or the closing items for
   you to check. Never guess one away.
