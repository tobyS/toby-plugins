<!-- tce-config-version: 3.1.0 -->
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

- **Test:** `claude plugin validate .` plus `claude plugin validate ./plugins/tce`
  and `claude plugin validate ./plugins/tmt`  (in repo root). For script changes,
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
| Slash commands (long markdown prompts) | `plugins/tce/commands/`, `plugins/tmt/commands/` |
| Research subagents | `plugins/tce/agents/` |
| Hook configs | `plugins/*/hooks/hooks.json` |
| Shell scripts (helpers + hook scripts) | `plugins/tce/scripts/`, `plugins/tmt/scripts/` |
| Templates copied into consuming projects | `plugins/tce/templates/tce/`, `plugins/tmt/templates/tmt/` |
| Consumer-facing docs | `README.md` (catalog), `plugins/*/README.md` |
| Repository instructions | `CLAUDE.md` |

Monorepo with two plugins: `tce` (context-engineering workflow) and `tmt`
(Toby Markdown Tickets). This repo dogfoods both.

## Conventions

- **Plugins stay project-agnostic**: no stack or ticket-system literals in
  command text; per-project data lives in consuming projects' `.claude/tce/` and
  `.claude/tmt/` config. `[PREFIX]-XXXX` is always a placeholder.
- **Ownership boundary**: tmt owns the ticket envelope (prefix, numbering,
  status enum + enforcement hooks); tce declares payload expectations in its
  `tickets.md` template. Plugins coordinate only through project config files,
  never by calling into each other.
- **Composite commands track single-step commands**: editing
  `research`/`plan`/`implement`/`commit`/`design_explore`
  requires checking `work.md` and `quickfix.md` in the same commit. Same across
  plugins: tmt's ticket template changes propagate to quickfix's inlined copy.
- Markdown-heavy repo: commands are long prompts — surgical edits over rewrites,
  preserve structure and altitude.
- Conventional commits, what-not-how; never push — the human decides.
- Releases: bump version in both the plugin's `plugin.json` and its
  marketplace.json entry, then `claude plugin tag ./plugins/<name>`. Plugins
  start at 1.0.0 and are versioned independently.

## Preferred research sources

The `web-search-researcher` agent prioritizes these when doing web lookups for this
project's stack. List authoritative docs as `URL — description`:

- `https://code.claude.com/docs/en/plugins-reference` — Claude Code plugins reference (manifests, userConfig, marketplaces)
- `https://code.claude.com/docs/en/hooks` — Claude Code hook events and JSON contract
- `https://code.claude.com/docs/en/slash-commands` — Claude Code command/skill authoring
