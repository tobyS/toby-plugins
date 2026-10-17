<!-- tce-config-version: 1.3.0 -->
# Project Profile

> Read by the tce workflow commands and research agents at runtime. `/tce:init`
> seeds this file and fills it in; keep it accurate. If the stack, layout, or
> commands change, update this file (or re-run `/tce:init`).

## Tech stack

Claude Code plugin marketplace monorepo. No application runtime or package
manager — the "code" is markdown command prompts, bash scripts, and JSON
manifests (plugin/marketplace manifests, hook configs).

## Commands

Always run from the listed directory (use absolute paths from the repo root).

- **Test:** `claude plugin validate .` plus `claude plugin validate ./plugins/tce`,
  `./plugins/tmt`, `./plugins/tle` and `./plugins/tsf`  (in repo root). For script changes,
  smoke-test against a throwaway project, e.g.
  `CLAUDE_PROJECT_DIR=/tmp/fakeproj plugins/tmt/scripts/next-ticket.sh` (hook
  scripts take their JSON on stdin). See "Testing changes" in `CLAUDE.md`.
- **Typecheck:** none
- **Lint/format:** none (`shellcheck` fits the bash scripts but is not installed;
  optional)

## Code map (where things live)

The research agents (`codebase-locator` / `codebase-analyzer` / `codebase-pattern-finder`)
read this to know where to look.

| Kind of code | Location(s) |
|--------------|-------------|
| Marketplace manifest | `.claude-plugin/marketplace.json` |
| Plugin manifests | `plugins/*/.claude-plugin/plugin.json` |
| Slash commands (long markdown prompts) | `plugins/tce/commands/`, `plugins/tmt/commands/`, `plugins/tle/commands/`, `plugins/tsf/commands/` |
| Subagents (research, verification, step agents) | `plugins/tce/agents/`, `plugins/tle/agents/`, `plugins/tsf/agents/` |
| Hook configs | `plugins/*/hooks/hooks.json` |
| Shell scripts (helpers, hook scripts, GitHub REST) | `plugins/tce/scripts/`, `plugins/tmt/scripts/`, `plugins/tsf/scripts/` |
| Runtime reference files (command templates) | `plugins/tce/references/`, `plugins/tle/references/`, `plugins/tsf/references/` |
| Templates copied into consuming projects | `plugins/tce/templates/tce/`, `plugins/tmt/templates/tmt/`, `plugins/tsf/templates/` |
| Design documents | `plugins/tsf/DESIGN.md` |
| Consumer-facing docs | `README.md` (catalog), `plugins/*/README.md` |
| Repository instructions | `CLAUDE.md` |

Monorepo with four plugins: `tce` (context-engineering workflow), `tmt`
(Toby Markdown Tickets), `tle` (Toby Loop Engineering — an autonomous
convergence loop) and `tsf` (Toby Software Factory — an agentic factory over a
GitHub-issue backlog, released in slices). This repo dogfoods tce and tmt; tle
targets greenfield app projects and tsf GitHub-issue projects with a factory
clone, so neither is used here.

## Conventions

- **Plugins stay project-agnostic**: no stack or ticket-system literals in
  command text; per-project data lives in consuming projects' `.claude/tce/` and
  `.claude/tmt/` config. `[PREFIX]-XXXX` is always a placeholder.
- **Ownership boundary**: tmt owns the ticket envelope (prefix, numbering,
  status enum + enforcement hooks); tce declares payload expectations in its
  `tickets.md` template. Plugins coordinate only through project config files,
  never by calling into each other.
- **Step working lives once, in the agents and `work-loop.md`**: the step
  commands (`work`, `research`, `plan`, `implement`, `quickfix`) carry only
  their lane; a step change is an agent edit, a loop change a `work-loop.md`
  edit (CLAUDE.md "tce: the step commands are orchestrators").
- Markdown-heavy repo: commands are long prompts — surgical edits over rewrites,
  preserve structure and altitude.
- Conventional commits, what-not-how; never push — the human decides.
- Releases: bump version in both the plugin's `plugin.json` and its
  marketplace.json entry, then `claude plugin tag ./plugins/<name>`. Plugins
  start at 1.0.0 and are versioned independently.

## Commit convention

How tce formats commit messages. `/tce:commit` (and the docs-commits in research /
plan / ticket / quickfix) read and follow it. The ticket-ID portion is the canonical
`TP-NNNN` form (per `.claude/tce/tickets.md`) and is omitted when a commit isn't about
a ticket.

- **Conventional Commits** — `<type>(<ticket-id>): <description>` with an optional
  body. Types: feat, fix, refactor, docs, test, chore, style, perf, ci, build.
  First line under 72 chars; explain what/why, not how. E.g. `feat(TP-0008): …`.

## Branch convention

Where tce puts a ticket's work. `/tce:init` agrees this with you and fills in the
chosen model; `/tce:intent` cuts a ticket's branch, `/tce:research`, `/tce:plan`,
`/tce:implement`, `/tce:work` and `/tce:review` read it right after fetching the
ticket, and `/tce:commit` checks it before a ticket-scoped commit. Work without a
ticket (ticketless intents, `/tce:quickfix`) and ticket *creation* are never
moved: they stay on whatever branch the session is on.

- **Current branch** — tce works on whatever branch the session is on and never
  creates or switches branches. (This repo always works on `main`; see
  `CLAUDE.md` Conventions.)

## Delivery

How a ticket's finished work reaches your main line. `/tce:init` agrees this with
you; the orchestrating `/tce:work` reads it to know whether its job ends with a
pull request (until a tce release acts on it, it is a recorded agreement only).
tce never merges.

- **Direct** — no pull request: the work stays on the branch the branch
  convention put it on, and you take it from there. (The default — identical to
  leaving this section out.)

## Reader

Who reads tce's questions, drafts and summaries. Commands that address you —
`/tce:intent` today — write for this reader: terms within their fluency are used
without explanation; the first time a tool, library, pattern or abbreviation
outside it appears, it is named and explained in half a sentence. This governs
vocabulary and depth, not length.

- **Described:** Fluent in bash, git, and Claude Code skills and agents. Not
  so fluent in Claude Code hooks and mods — name a hook event, hook field or
  mod mechanism the first time it appears and say in half a sentence what it
  does.

## Preferred research sources

The `web-search-researcher` agent prioritizes these when doing web lookups for this
project's stack. List authoritative docs as `URL — description`:

- `https://code.claude.com/docs/en/plugins-reference` — Claude Code plugins reference (manifests, userConfig, marketplaces)
- `https://code.claude.com/docs/en/hooks` — Claude Code hook events and JSON contract
- `https://code.claude.com/docs/en/slash-commands` — Claude Code command/skill authoring
