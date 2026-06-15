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

## Preferred research sources

The `web-search-researcher` agent prioritizes these when doing web lookups for this
project's stack. List authoritative docs as `URL — description`:

- `https://...` — [language] reference
- `https://...` — [framework] official docs
- `https://...` — [notable library] docs

(General sources like MDN are always available; list the *stack-specific* ones here.)
