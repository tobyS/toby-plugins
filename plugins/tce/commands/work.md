---
description: Orchestrate a ticket with an intent, or a ticketless intent, from research to a verified, delivered change — one fresh agent per step, questions only during planning. Needs CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=600000.
argument-hint: "[ticket-id | intent path]"
disable-model-invocation: true
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/work.sh":*), Bash(git rev-parse:*), Bash(git log:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr view:*)
---

# Work on Ticket

Take a ticket that has an intent — or a ticketless intent — from research to a
verified, delivered change. You are the **orchestrator**: each step runs in a
fresh agent, the documents they write are the run's state, and the human is
asked only during planning — and, at the end, to confirm what the run could not
check itself.

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

**Usage:** `/tce:work [PREFIX]-XXXX | <intent path>` (a ticket needs an intent
— run `/tce:intent` first; a ticketless intent is a path into
`thoughts/shared/intents/`).

## The loop

Read `${CLAUDE_PLUGIN_ROOT}/references/work-loop.md` **now — in full** —
and run it as `<command>` = `/tce:work`, in this lane:

- **Start rows:** all.
- **Steps:** 5–12 — research, planning with approval, implement, verify,
  dossier, delivery, closeout, items for you to check.
- **Otherwise:** none.
