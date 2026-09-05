<!-- tce-config-version: FILLED-BY-INIT -->
# Project Profile

> Read by the tce workflow commands and research agents at runtime. `/tce:init`
> seeds this file and fills it in; keep it accurate. If the stack, layout, or
> commands change, update this file (or run `/tce:refresh` to reconcile it with
> the repo, or re-run `/tce:init`).

## Tech stack

[Languages, frameworks, package manager, datastore — concise.]

## Commands

Always run from the listed directory (use absolute paths from the repo root).

- **Test:** `<command>`  (in `<dir>`)   [repeat per suite if monorepo]
- **Typecheck:** `<command>`  (in `<dir>`)   [or "none"]
- **Lint/format:** `<command>`  (in `<dir>`)

## Dev environment

Optional. Lets `/tce:design_explore` reach the running app for automated
visual-baseline screenshot capture instead of asking every time. Left unset
until `/tce:design_explore` fills it in (with your approval) the first time
it needs a URL, or you fill it in by hand.

- **Dev server URL:** [not set]

## Code map (where things live)

The research agents (`codebase-locator` / `codebase-analyzer` / `codebase-pattern-finder`)
read this to know where to look. List where each kind of code lives (drop rows that
don't apply, add ones that do):

| Kind of code | Location(s) |
|--------------|-------------|
| Entry points (routes / handlers / CLI / pages) | `<dir>` |
| Application / business logic | `<dir>` |
| Domain models / schema / persistence | `<dir>` |
| Migrations | `<dir>` |
| Interface (UI components / API endpoints) | `<dir>` |
| Tests (unit / integration / e2e) | `<dir>` |
| Configuration | `<dir>` |

[If a monorepo: list the top-level apps/packages and their purpose.]

## Conventions

[Project-specific do/don't rules the workflow should honor: commit discipline,
directory rules, testing-per-phase, impact-analysis expectations, etc.]

## Commit convention

How tce formats commit messages. `/tce:init` agrees this with you and fills in the
chosen convention's spec; `/tce:commit` (and the docs-commits in research / plan /
ticket / quickfix) read and follow it. The ticket-ID portion is resolved per
`.claude/tce/tickets.md` and is omitted when a commit isn't about a ticket.

[Filled by `/tce:init` with one of:

- **Conventional Commits** — `<type>(<ticket-id>): <description>` with an optional
  body. Types: feat, fix, refactor, docs, test, chore, style, perf, ci, build.
  First line under 72 chars; explain what/why, not how.
- **Plain / freeform** — `<ticket-id>: <description>` with an optional body.
  Imperative subject; first line under 72 chars; explain what/why, not how.
- **Issue-reference** — `#<ticket-id>: <description>` with an optional body. Intended
  for numeric issue trackers; first line under 72 chars; explain what/why, not how.]

## Branch convention

Where tce puts a ticket's work. `/tce:init` agrees this with you and fills in the
chosen model; `/tce:research`, `/tce:plan`, `/tce:implement` and `/tce:review` (and
the composites `/tce:work` / `/tce:quickfix`) read it right after fetching the
ticket, and `/tce:commit` checks it before a ticket-scoped commit. Work without a
ticket — discussions, design explorations, config, chores — and ticket *creation*
are never moved: they stay on whatever branch the session is on.

[Filled by `/tce:init` with one of:

- **Current branch** — tce works on whatever branch the session is on and never
  creates or switches branches. (The default — identical to leaving this section
  out.)
- **Branch per ticket** — each ticket's research, plan and implementation live on
  their own branch, cut from a freshly fetched base:
  - **Branch name:** `<pattern>` — `<ticket-id>` stands for the canonical ID per
    `.claude/tce/tickets.md` (e.g. `<ticket-id>`, `feature/<ticket-id>`,
    `<ticket-id>-<slug>` with a short kebab-case slug of the ticket title).
  - **Base branch:** `<branch>` on remote `<remote>` (or "no remote").
  - **When the base cannot be brought up to date** (fetch fails, no remote): tce
    stops and asks you to update it or confirm the local tip is current. It never
    cuts the branch from any other tip and never substitutes another branch.
  - `/tce:research` creates the branch (or switches to it if it exists);
    `/tce:plan`, `/tce:implement` and `/tce:review` switch to it when the session
    is elsewhere and stop and ask if it is missing or the working tree has
    uncommitted changes; `/tce:commit` warns and asks before a ticket-scoped
    commit that would land on the base branch.]

## Preferred research sources

The `web-search-researcher` agent prioritizes these when doing web lookups for this
project's stack. List authoritative docs as `URL — description`:

- `https://...` — [language] reference
- `https://...` — [framework] official docs
- `https://...` — [notable library] docs

(General sources like MDN are always available; list the *stack-specific* ones here.)
