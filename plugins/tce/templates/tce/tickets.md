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

[How to create a ticket — used by `/tce:ticket` (interactively) and
`/tce:quickfix` (autonomously). Include how the new ID is determined and the
ticket's initial status. If Claude must NOT create tickets in this system, write
"not allowed": `/tce:quickfix` then refuses (it asks the user to create the
ticket manually and use `/tce:work`), and `/tce:ticket` still runs the authoring
discussion but offers the result as copy/paste-able content instead of writing
it (the user may grant a one-time override to create it anyway).]

## Ticket title & body layout

[How a ticket's title and body are assembled into this backend, so `/tce:ticket`
can persist the content it authors. State where the title goes and where the
body (the markdown content) goes — e.g. for a file backend: a `# <ID>: <title>`
heading, then the status/meta lines, then the body; for an issue tracker: the
issue title field and the issue body field. The author-facing body *structure*
itself is owned by `/tce:ticket`, not defined here.]

## Status / completion

[How tce maps its lifecycle moments to this system, and whether tce performs the
transition itself or only reminds. The moments:

- **start** — implementation begins → in progress;
- **complete** — all phases done and verified → done/closed;
- **reject** — work is abandoned / won't-fix → rejected/closed.

Give the concrete action for each, e.g. "edit the `**Status:**` line in the
ticket file" or "run `gh issue close <n>`". If tce must NOT transition tickets in
this system, write "do not transition — remind the user instead".

Also name the **terminal statuses** — those meaning the ticket needs no further
work (e.g. Done and Rejected; the closed states of an issue tracker).
`/tce:list` hides tickets in a terminal status unless asked to include them.]

## Listing tickets

[How `/tce:list` enumerates this project's tickets, and what metadata it can show
for each. Give a concrete mechanism that yields, for every ticket, at least its
canonical ID, title and status — e.g. for a file backend, the glob over the
ticket directory plus which lines carry the title and status; for an issue
tracker, a CLI or MCP call (`gh issue list --state all --limit 200 --json
number,title,state,labels`). The command runs this verbatim, so be concrete.
Also state:

- **Complexity** — where a ticket's size/estimate lives, or "none".
- **Priority** — where a ticket's priority lives and which values it takes, or
  "none". With "none" the listing's Priority column never appears at all — no
  empty column and no invented values.

`/tce:list` is read-only: it never creates, writes or transitions a ticket.]

## What tce needs from a ticket

<!-- Backend-independent — applies to every ticket system. Keep as-is; this is
     also what /tce:ticket and human ticket authors should aim for. -->

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
