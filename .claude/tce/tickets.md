# Ticket System

> Read by the tce workflow commands at runtime to work with this project's
> ticket system. `/tce:init` seeds this file and fills in the backend sections;
> keep it accurate. If the ticket system or how you access it changes, update
> this file (or re-run `/tce:init`).

## System

tmt (Toby Markdown Tickets) — tickets are markdown files in this repo, managed
by the tmt plugin (prefix configured in `.claude/tmt/config`).

## Canonical ticket ID

`TP-NNNN` (4-digit, zero-padded, e.g. `TP-0001`); sub-tickets of an epic add a
letter suffix: `TP-0001a`. Use this form in `thoughts/` filenames and commit
scopes. Normalize other references to it: a bare number (`42` → `TP-0042`), a
lowercase form (`tp-0042` → `TP-0042`), or an unpadded one (`TP-42` → `TP-0042`).

## Reading a ticket

Read the matching file: `thoughts/shared/tickets/TP-NNNN-*.md` (glob for the
canonical ID; exactly one file matches a main ticket, sub-tickets include the
letter suffix in the filename).

## Parent / epic tickets

A letter suffix marks a sub-ticket: `TP-0100a`'s parent is `TP-0100`. Strip the
suffix and read that ticket file (plus its research/plan, found via the
discovery script). Main tickets (no suffix) have no parent.

## Creating a ticket

Allowed (used autonomously by `/tce:quickfix`). Determine the next free number
by scanning `thoughts/shared/tickets/` for the highest `TP-NNNN` (ignore letter
suffixes), then write `thoughts/shared/tickets/TP-NNNN-brief-description.md`
following the structure of existing tickets / the tmt template. Valid statuses:
Open, In Progress, Done, Rejected — a tmt hook validates them on write. Commit
the new ticket file (docs-only commit).

## Status / completion

tce transitions statuses itself: edit the `**Status:**` line in the ticket file
(`In Progress` when implementation starts, `Done` when all phases complete and
verified, `Rejected` for won't-fix). Commit the status change together with the
related work (the tmt `git add` hook reminds about due transitions).

## What tce needs from a ticket

<!-- Backend-independent — applies to every ticket system. Keep as-is; this is
     also what /tmt:create and human ticket authors should aim for. -->

tce works from any ticket that provides, at minimum:

- **Clear scope** — what should change or be built, and roughly where the
  boundary is (what is explicitly not part of it, if anything).
- **Observable outcome** — you can tell from the ticket what "done" would look
  like, even informally.
- **An anchor** — at least one concrete pointer into the system (a feature,
  screen, command, error message, or code area) so research has somewhere to
  start.

Not required: business justification, formal acceptance criteria, technical
detail, or any particular section structure.

If a ticket additionally contains these, the tce commands exploit them
directly:

- **Open Questions** — resolved with the user before planning.
- **Questions for Research/Planning** — guide the research phase.
- **Acceptance Criteria** — used as the review checklist by `/tce:review`.

Tickets missing the minimum trigger an upfront clarification round in
`/tce:research` (and `/tce:work`) before any research starts.
