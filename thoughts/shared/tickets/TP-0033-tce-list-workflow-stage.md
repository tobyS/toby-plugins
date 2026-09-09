# TP-0033: Add /tce:list — ticket listing with tce workflow stage

**Status:** In Progress
**Estimated Complexity:** Medium
**Created:** 2026-09-09
**Updated:** 2026-09-09

## Problem Statement

tce has no way to show where tickets stand **in its own workflow**. The chain
produces artifacts per ticket — a research document, a plan document, an
implementation log inside the plan — but nothing surfaces them together, so the
question "which tickets are researched but not planned?" or "which plan is
half-implemented?" can only be answered by eyeballing directory listings under
`thoughts/` and opening plan files one by one.

`/tmt:list` exists but does not fill this gap and is not meant to: it belongs to
the tmt plugin (so it is tmt-specific, not adapter-driven), shows only Open and
In Progress, prints a flat block per ticket rather than a skimmable table, has no
notion of *how far* implementation has got, no priority, and no epic nesting.

## Desired Outcome

`/tce:list` prints a table — one row per ticket — from which the user can skim
the state of the backlog without opening a file. Each row carries the ticket ID,
title, the backend's own status, the tce stage (research / plan / implementation
progress), complexity, and priority where the backend has one. Sub-tickets appear
nested directly under their parent epic, and the epic's implementation cell rolls
up its children.

With no argument it lists every ticket not in a terminal status. With a free-form
prompt argument it filters, sorts, groups, or extends the listing as asked
(topic filter, include closed tickets, group by priority, …) and says in one line
how it interpreted the prompt.

Target output (a real markdown table — see "Output format" below):

| Ticket | Title | Priority | Status | Research | Plan | Implementation | Complexity |
|---|---|---|---|---|---|---|---|
| MYAPP-0100 | Billing overhaul | High | In Progress | – | – | 2/4 sub-tickets | Extra Large |
| └─ MYAPP-0100a | Extract invoice model | High | Done | ✓ | ✓ | ✓ | Medium |
| └─ MYAPP-0100b | Proration engine | Medium | In Progress | ✓ | ✓ | 2/6 phases | Large |
| └─ MYAPP-0100c | Dunning emails | Low | Open | ✓ | – | – | Small |
| MYAPP-0104 | Fix CSV export encoding | High | Open | ✓ | – | – | Small |

(For a backend without priorities — tmt, for instance — the Priority column is
absent entirely.)

## User Stories / Use Cases

- As a developer resuming work, I want one table of unfinished tickets with their
  tce stage, so that I can pick up the one closest to done without opening files.
- As a developer planning a session, I want to filter by topic
  (`/tce:list only tle tickets`), so that I see just the area I am working in.
- As someone reviewing an epic, I want its sub-tickets nested underneath it with a
  roll-up, so that I can see the epic's real progress at a glance.
- As a user of a ticket system that has priorities, I want a priority column, so
  that I can triage from the same table instead of switching to the backend's UI.

## Acceptance Criteria

### Listing

- [ ] `/tce:list` with no argument lists every ticket **not** in a terminal status
      (terminal statuses come from the project's status policy in
      `.claude/tce/tickets.md`, never hardcoded), newest first.
- [ ] Each row shows: canonical ticket ID, title, backend status, research
      indicator, plan indicator, implementation indicator, complexity.
- [ ] The implementation indicator distinguishes three states: not started,
      partial (`n/m phases`, read from the plan document's implementation log),
      and complete.
- [ ] A **Priority** column appears if — and only if — the project's `tickets.md`
      declares where priority lives. Otherwise the column is omitted entirely: no
      empty column, no placeholder values, no invented priorities.
- [ ] Sub-tickets are rendered directly beneath their parent, visibly nested, and
      stay grouped with the parent even when the parent is in a terminal status.
- [ ] An epic's implementation cell rolls up its sub-tickets
      (`n/m sub-tickets`); its research and plan cells reflect only documents the
      epic itself has.
- [ ] A prompt argument adjusts the listing — at minimum topic filter, include
      terminal statuses, group by, sort by — and the command states in one line
      how it interpreted the prompt before the table.
- [ ] A count line accompanies the table (e.g. shown vs. total).

### Output format

- [ ] The table is emitted as a **real markdown table**, not inside a code fence,
      so the renderer performs the column padding.
- [ ] Column headings are full words (`Research`, `Implementation`, `Complexity`),
      not abbreviations.
- [ ] **No emoji-presentation or ambiguous-width characters appear in any cell.**
      Cell glyphs are single-width text-presentation characters (`✓` U+2713, `–`
      U+2013, `└─` U+2514 U+2500). `✅` and similar emoji occupy two terminal
      columns and break alignment — this is the concrete defect being avoided.
- [ ] Nesting uses a visible leading marker, not leading whitespace (markdown
      renderers trim leading spaces inside table cells).
- [ ] A legend explains the indicators.

### Agnosticism & integration

- [ ] The command obtains ticket enumeration, the status policy, the priority
      location, and the parent/epic rule from `.claude/tce/tickets.md`. No ticket
      prefix, no `thoughts/shared/tickets/`, and no other tmt specific appears in
      the command text (`[PREFIX]-XXXX` placeholders only).
- [ ] A **"Listing tickets"** section exists in
      `plugins/tce/templates/tce/tickets.md`, is filled by `/tce:init`, and is
      reconciled by `/tce:refresh` (per the refresh-tracks-init rule in
      `CLAUDE.md`).
- [ ] Missing `.claude/tce/tickets.md` → the command tells the user to run
      `/tce:init` and stops.
- [ ] The command is classified for `disable-model-invocation` per the TP-0017
      rule and the classification lists in `CLAUDE.md` are updated.
- [ ] `plugins/tce/README.md` documents the command; the tce version is bumped in
      both `plugins/tce/.claude-plugin/plugin.json` and
      `.claude-plugin/marketplace.json`.
- [ ] `claude plugin validate .` and the three per-plugin validates pass.

## Out of Scope

- **Changing, thinning or retiring `/tmt:list`.** tmt must keep listing tickets
  standalone, without tce installed; a pointer into tce would couple the plugins,
  which the ownership boundary forbids. Some overlap is the accepted price.
- **Adding a priority field to tmt.** tmt tickets have no priority and that is
  fine — the Priority column simply never appears for tmt projects. No follow-up
  ticket is intended.
- Writing to, or mutating, any ticket — `/tce:list` is read-only.
- Output formats other than the table (JSON, CSV, a TUI).
- Caching, indexing, or incremental state for large backlogs.
- Changing what `/tce:research`, `/tce:plan` or `/tce:implement` write; the
  command reads their existing artifacts as they are.

## Open Questions

None blocking.

## Questions for Research/Planning

- [ ] **Shipped script or pure prompt?** Enumerating and parsing every ticket
      file, then globbing `thoughts/` for research and plan documents, is real
      work for a prompt. Options: a `plugins/tce/scripts/` helper following the
      `baseline.sh` / `branch.sh` pattern (fast, but the adapter must still
      describe the generic mechanism for non-file backends), or direct
      Glob/Grep/Read from the command. Deliberately left to research.
- [ ] How does a plan document encode phase completion, and is it reliable enough
      to derive `n/m phases`? (`### Implementation log`, phase checkboxes — needs
      confirming against real plans, including the ones predating TP-0023's
      status-file merge.)
- [ ] Is `plugins/tce/scripts/ticket.sh` usable here, or does per-ticket
      invocation across a whole backlog need a bulk mode?
- [ ] What should the "Listing tickets" adapter section look like so it works for
      both file backends and issue trackers (e.g. a command that returns
      ID/title/status/priority), and does it need a companion "Priority" field
      declaration or can priority ride inside it?
- [ ] How is an epic's roll-up computed when the parent carries its own plan with
      phases *and* has sub-tickets?
- [ ] Does the free-form prompt argument need a documented vocabulary, or is
      natural-language interpretation plus the one-line echo enough?

## References

- `plugins/tmt/commands/list.md` and `plugins/tmt/scripts/open_tickets.sh` — the
  existing tmt lister; the closest prior art and the thing this does *not* replace
- `plugins/tce/templates/tce/tickets.md` — the adapter template gaining a
  "Listing tickets" section; today it covers reading, creating, parent/epic and
  status only
- `plugins/tce/scripts/ticket.sh` — existing per-ticket `thoughts/` document
  discovery
- `plugins/tce/commands/init.md`, `plugins/tce/commands/refresh.md` — must learn
  the new adapter section together
- `CLAUDE.md` — "Core design rule: keep the plugins project-agnostic",
  "`/tce:refresh` re-analysis must track `/tce:init`'s analysis", and the TP-0017
  invocation-control classification

## Implementation Plan

## Notes & Updates

### 2026-09-09

- Table shape agreed interactively over three rounds of example output. Locked:
  full-word headings, `✓` / `–`, `└─`-nested sub-tickets, Priority only when the
  backend has it, epic roll-up in the Implementation cell.
- The first example tables misrendered in the terminal because `✅` is an
  emoji-presentation character occupying two columns while the padding counted it
  as one. Fix chosen: emit a real markdown table and let the renderer pad, with
  single-width glyphs only. Both halves of that fix are acceptance criteria.
- Priority: decided that tmt simply has none and needs none; the column is
  backend-conditional rather than a reason to extend tmt.
- `/tmt:list` deliberately untouched — tmt has to work without tce.
- Script-vs-prompt enumeration left to research rather than pre-empted in the
  ticket.
- Complexity Medium: one new command, but it introduces a new adapter section
  that drags in the template, `/tce:init` and `/tce:refresh`, plus README and a
  version bump.
