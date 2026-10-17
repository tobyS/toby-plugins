---
description: Research the codebase (and web) for a ticket with an intent, or a ticketless intent, in a fresh agent, and write the research document. Step 2 of the tce workflow. Needs CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=600000.
argument-hint: "[ticket-id | intent path]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/work.sh":*)
---

# Research Codebase

Run the research step for a ticket that has an intent — or for a ticketless
intent — and stop. You are the **orchestrator** of one step: the `researcher`
agent does the research in a fresh context and writes and commits the research
document; you resolve the input, dispatch it, and report where the document is.
Nothing is asked.

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

**Usage:** `/tce:research [PREFIX]-XXXX | <intent path>` (a ticket needs an
intent — run `/tce:intent` first; a ticketless intent is a path into
`thoughts/shared/intents/`). A free-form research question is not an input:
use `/tce:discuss` to explore, or `/tce:intent` to agree what to build.

## The loop

Read `${CLAUDE_PLUGIN_ROOT}/references/work-loop.md` **now — in full** —
and run it as `<command>` = `/tce:research`, in this lane:

- **Start rows:** 10 (no research).
- **Steps:** 5 — research. Then print the research document's path, the
  config-drift line if Step 5 kept one, and "Next: `/tce:plan <argument>`",
  and stop.
- **Otherwise:** the loop's *otherwise* line, with the next command by row:
  rows 9 and 8 → "research exists at <research path>; next:
  `/tce:plan <argument>`"; rows 7 to 3 → `/tce:implement <argument>`;
  row 2 → "<ID> is done."; row 1 → `/tce:work <argument>` (delivery).
  A re-run never writes a second research document — removing the existing
  one is your call.
