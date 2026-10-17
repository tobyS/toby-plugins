---
description: Implement an approved plan for a ticket or a ticketless intent — one fresh agent per phase, then verification with the bounded fix loop and the plan-compliance gate, the dossier and the closeout. Never delivers. Step 4 of the tce workflow. Needs CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=600000.
argument-hint: "[ticket-id | intent path]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/work.sh":*), Bash(git rev-parse:*), Bash(git log:*)
---

# Implement Plan

Implement the approved plan of a ticket — or of a ticketless intent — and
verify it, ending with the dossier and the closeout. You are the
**orchestrator**: the `implementer` agent builds one phase per dispatch, the
`verifier` agent runs the suites and the plan-compliance gate and writes the
dossier, and the plan's logs are the run's state, so an interrupted run
resumes at the next phase. You are asked only at the end, to confirm what
could not be checked without you. This command never pushes and never opens a
pull request — `/tce:work` delivers.

## Project context

This command ships in the **tce** workflow plugin and is stack- and
ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` (branch convention,
  delivery, reader) and `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` (how to
  resolve and read a ticket, parent tickets, the status policy). If either is
  missing, tell the user to run `/tce:init` and stop.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md`
  (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- The agents receive `${CLAUDE_PLUGIN_ROOT}/references` as `references:`.

**Usage:** `/tce:implement [PREFIX]-XXXX | <intent path>` (the plan must exist
— run `/tce:plan` first; a ticketless intent is a path into
`thoughts/shared/intents/`). Asking for implementation of a written plan is
its approval.

## The loop

Read `${CLAUDE_PLUGIN_ROOT}/references/work-loop.md` **now — in full** —
and run it as `<command>` = `/tce:implement`, in this lane:

- **Start rows:** 8 (plan written, not started — treated as approved: go
  straight to Step 7, no brief and no approval dialog), 7, 6, 5, 4 (dossier
  exists: closeout without delivery) and 3 (Step 12).
- **Steps:** 7 — implement; 8 — verify, with the bounded fix loop and the
  gate; 9 — dossier; 10 in its *no delivery* variant; 11 — closeout and
  summary; 12 — items for you to check.
- **Otherwise:** rows 9 and 10 → "No plan for <ID> — run
  `/tce:plan <argument>` first."; row 2 → "<ID> is done."; row 1 →
  "Implemented; run `/tce:work <argument>` to deliver."
