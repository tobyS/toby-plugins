# Ticket System

> Read by the tce workflow commands at runtime to work with this project's
> ticket system. `/tce:init` seeds this file and fills in the backend sections;
> keep it accurate. If the ticket system or how you access it changes, update
> this file (or re-run `/tce:init`).

## System

[Name the ticket system: tmt (Toby Markdown Tickets) / GitHub Issues / Jira /
Linear / <custom>.]

## Canonical ticket ID

[The canonical ID form used in `thoughts/` filenames and commit scopes. It must
be filesystem-safe and greppable (letters, digits, hyphens — e.g. `MYAPP-0042`,
`GH-123`, `ABC-123`). State how to normalize other ways users reference a
ticket (a bare number, `#123`, a URL) into this form.]

## Reading a ticket

[How to fetch a ticket's full content given its canonical ID — a file path /
glob, a CLI command, an MCP tool. The commands run this verbatim, so be
concrete.]

## Parent / epic tickets

[How to tell whether a ticket has a parent/epic and how to fetch that parent
for context. Write "none" if the system or project doesn't use parent/child
tickets.]

## Creating a ticket

[How to create a ticket — used by `/tce:quickfix` (autonomously). Include how
the new ID is determined. If Claude must NOT create tickets in this system,
write "not allowed" — `/tce:quickfix` will then refuse and ask the user to
create the ticket manually and use `/tce:work` instead.]

## Status / completion

[Whether and how tce updates ticket status: when work starts (→ in progress)
and when an implementation completes (→ done/closed), e.g. "edit the
`**Status:**` line in the ticket file" or "run `gh issue close <n>`". If tce
must NOT transition tickets in this system, write "do not transition — remind
the user instead".]

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
- **Acceptance Criteria** — used as the review checklist by `/tce:code_review`.

Tickets missing the minimum trigger an upfront clarification round in
`/tce:research_codebase` (and `/tce:work`) before any research starts.
