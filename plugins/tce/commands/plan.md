---
description: Plan a ticket with an intent, or a ticketless intent, from its research in a fresh agent — questions first, then a challenged plan and a brief for your approval. Step 3 of the tce workflow. Needs CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=600000.
argument-hint: "[ticket-id | intent path]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/work.sh:*)
---

# Implementation Plan

Run the planning step for a ticket that has an intent and research — or for a
ticketless intent with research — and stop at your approval. You are the
**orchestrator** of one step: the `planner` agent asks its questions through
you, writes and commits the plan and returns a brief; the `plan-challenger`
agent checks it; you ask, print the brief and take approval or push-back,
exactly as `/tce:work` does.

## Project context

This command ships in the **tce** workflow plugin and is stack- and
ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` (branch convention,
  reader) and `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` (how to resolve
  and read a ticket, parent tickets). If either is missing, tell the user to
  run `/tce:init` and stop.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md`
  (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- The agents receive `${CLAUDE_PLUGIN_ROOT}/references` as `references:`.

**Usage:** `/tce:plan [PREFIX]-XXXX | <intent path>` (a ticket needs an intent
and research — run `/tce:intent` and `/tce:research` first; a ticketless
intent is a path into `thoughts/shared/intents/`).

## The loop

Read `${CLAUDE_PLUGIN_ROOT}/references/work-loop.md` **now — in full** —
and run it as `<command>` = `/tce:plan`, in this lane:

- **Start rows:** 9 (plan questions) and 8 (brief, then approval).
- **Steps:** 6 — the planner's questions, the challenger, the brief and the
  "Approve the plan?" dialog, exactly as `/tce:work`. On **Approve**, print
  the plan's path and "Next: `/tce:implement <argument>`", and stop.
- **Otherwise:** row 10 → "No research for <ID> — run
  `/tce:research <argument>` first."; rows 7 to 3 → the loop's *otherwise*
  line with `/tce:implement <argument>`; row 2 → "<ID> is done."; row 1 →
  the *otherwise* line with `/tce:work <argument>` (delivery).
