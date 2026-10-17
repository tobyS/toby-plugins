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
chosen model; `/tce:intent` cuts a ticket's branch, `/tce:research`, `/tce:plan`,
`/tce:implement`, `/tce:work` and `/tce:review` read it right after fetching the
ticket, and `/tce:commit` checks it before a ticket-scoped commit. Work without a
ticket — ticketless intents and `/tce:quickfix`, discussions, design
explorations, config, chores — and ticket *creation* are never moved: they stay
on whatever branch the session is on.

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

## Delivery

How a ticket's finished work reaches your main line. `/tce:init` agrees this with
you; the orchestrating `/tce:work` reads it at the end of a run: under
**Direct** it prints the dossier, under **Pull request** it pushes the ticket
branch and opens the pull request with the dossier as its body. tce never
merges.

[Filled by `/tce:init` with one of:

- **Direct** — no pull request: the work stays on the branch the branch
  convention put it on, and you take it from there. (The default — identical to
  leaving this section out.)
- **Pull request** — requires **Branch per ticket** above and uses its base
  branch and remote:
  - tce pushes the ticket branch and opens a pull request against the base branch;
  - **you** review and merge it — tce never merges;
  - the next ticket starts only after the previous ticket's pull request is
    merged.]

## Reader

Who reads tce's questions, drafts and summaries. Commands that address you —
`/tce:intent`, and `/tce:work`'s questions, brief and dossier — write for this
reader: terms within their fluency are used without explanation; the first time
a tool, library, pattern or abbreviation outside it appears, it is named and
explained in half a sentence. This governs vocabulary and depth, not length.

[Filled by `/tce:init` with one of:

- **Not described** — tce assumes a reader fluent in this project's stack. (The
  default — identical to leaving this section out.)
- **Described:** <two or three lines on the reader's fluency, e.g. "Fluent in PHP
  and Laravel; new to the TypeScript ecosystem — name a library or pattern the
  first time it appears and say in half a sentence what it does.">]

## Preferred research sources

The `web-search-researcher` agent prioritizes these when doing web lookups for this
project's stack. List authoritative docs as `URL — description`:

- `https://...` — [language] reference
- `https://...` — [framework] official docs
- `https://...` — [notable library] docs

(General sources like MDN are always available; list the *stack-specific* ones here.)
