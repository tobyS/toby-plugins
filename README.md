# toby-plugins — a Claude Code marketplace

This repository is the **`toby-plugins` marketplace**. It currently ships one
**plugin, `tce`** — a context-engineering driven development workflow for Claude Code:
**ticket → research → plan → implement**, plus review, discussion, and
design-exploration commands and a set of research subagents.

The `tce` plugin installs from this marketplace and **updates centrally** — no more
copying files into each project and merging changes by hand. Everything
project-specific lives in a small `.claude/tce/` config that `/tce:init` creates; the
workflow itself stays in the plugin and is shared across all your projects.

> **Two names, kept distinct:** `toby-plugins` is the **marketplace** (the catalog you
> add); `tce` is the **plugin** (what you install, and the `/tce:` command namespace).
> You install the plugin from the marketplace as `tce@toby-plugins`.

## Why context engineering?

LLMs perform best when given the right context at the right time. The workflow
builds context progressively through documents stored in `thoughts/`:

1. **Tickets** capture business requirements (the WHAT and WHY)
2. **Research** documents existing codebase patterns and constraints
3. **Plans** synthesize requirements + research into actionable steps
4. **Implementation** executes with full context from the previous phases

Each phase produces artifacts that persist across sessions, so Claude always has the
context it needs without repeated explanation.

## Requirements

The workflow itself is plain Markdown and needs nothing special, but the shipped
scripts have small external dependencies:

| Tool | Needed for | Required? |
|------|-----------|-----------|
| `git` | everything (the workflow lives in your repo) | **Required** |
| `jq` | the ticket-status hooks parse hook JSON with it | **Required** for the hooks; without it the status reminders silently don't fire (work is not blocked) |
| `gh` (GitHub CLI) | turning `file:line` refs into GitHub permalinks in `/tce:research_codebase` | Optional — degrades to local references when absent |

The ticket-numbering scripts are pure filesystem (`find` over `thoughts/`), so they
need no network, auth, or GitHub access. `/tce:init` checks for these tools and warns
if `jq` is missing.

## Install

```bash
# 1. Add the marketplace (once per machine). The argument is the repo's GitHub location.
/plugin marketplace add tobyS/toby-plugins      # a git URL or local path also work

# 2. Install the tce plugin from the toby-plugins marketplace (<plugin>@<marketplace>)
/plugin install tce@toby-plugins
```

> `tobyS/toby-plugins` is the repo's GitHub location (owner + repo). The repo name
> matches the marketplace `name` in `.claude-plugin/marketplace.json` (`toby-plugins`)
> by design, so the same string appears in both `marketplace add …/toby-plugins` and
> `install tce@toby-plugins` (`<plugin>@<marketplace>`).

## Set up a project

In each project where you want the workflow:

```bash
/tce:init
```

`/tce:init` analyzes the project, proposes a profile (stack, test/lint/typecheck
commands, conventions) and a ticket prefix, discusses it with you, and — once you
confirm — writes:

```
.claude/tce/
├── config           # TICKET_PREFIX=<PREFIX>   (read by the ticket scripts)
├── profile.md       # stack, commands, conventions (read by the commands at runtime)
└── design-system.md # optional, for /tce:design_explore
thoughts/shared/{tickets,research,plans,reviews,mockups,discussions}/
```

Commit `.claude/tce/` — it's shared project config, not personal settings. The
commands read these files at runtime, so **you never edit the plugin** to adapt it
to a project.

## Update

```bash
/plugin marketplace update toby-plugins
```

Releases are gated by the `tce` plugin's `version` (in its `plugin.json`, mirrored in
the marketplace entry), so projects only move when you bump it.

## Commands

Plugin commands are namespaced under `/tce:`.

| Step | Command | Purpose |
|------|---------|---------|
| setup | `/tce:init` | Analyze the project and write `.claude/tce/` config |
| 1 | `/tce:create_ticket` | Capture business requirements (WHAT & WHY) |
| 2 | `/tce:research_codebase` | Research codebase, find patterns & libraries |
| 3 | `/tce:create_plan` | Resolve questions, create a detailed implementation plan |
| 3b | `/tce:design_explore` | *(Optional)* Explore and select a visual design for non-trivial UX |
| 4 | `/tce:implement_plan` | Execute implementation using all documents |
| ✓ | `/tce:code_review` | Review an implementation (ticket-based or custom scope) |
| — | `/tce:discuss` | Technical discussion / sparring partner |
| — | `/tce:commit` | Commit with pre-commit checks (tests/lint/typecheck from the profile) |

## Agents

Specialized research subagents bundled with the plugin:

| Agent | Purpose |
|-------|---------|
| `codebase-locator` | Find files and directories by topic |
| `codebase-analyzer` | Understand implementation details |
| `codebase-pattern-finder` | Find similar implementations to model after |
| `thoughts-locator` | Find documents in the `thoughts/` directory |
| `thoughts-analyzer` | Extract insights from thought documents |
| `web-search-researcher` | Research external documentation |

## How project parameterization works

The plugin is identical across projects; only `.claude/tce/` differs.

- **Ticket prefix** — stored as `TICKET_PREFIX=<PREFIX>` in `.claude/tce/config`. The
  ticket scripts (shipped in the plugin) read it and resolve the project root from
  `CLAUDE_PROJECT_DIR` (falling back to the working directory). In command docs,
  `[PREFIX]` is just a placeholder for that configured prefix.
- **Stack, commands, conventions** — live in `.claude/tce/profile.md`. Each command
  reads `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` at runtime, so e.g. `/tce:commit`
  runs *your* test/lint/typecheck commands without the command being edited.
- **Scripts** are invoked via `${CLAUDE_PLUGIN_ROOT}/scripts/...` (substituted inline),
  so they resolve regardless of where the plugin is cached.

## Repository layout (for contributors)

This is a **monorepo marketplace**: the marketplace lives at the repo root and lists
plugins that live under `plugins/`. Today there's one plugin (`tce`); adding another
is a new `plugins/<name>/` directory plus an entry in `marketplace.json`.

```
.claude-plugin/marketplace.json   # the marketplace (name: toby-plugins) — lists the plugins
plugins/
└── tce/                          # the tce plugin (CLAUDE_PLUGIN_ROOT points here once installed)
    ├── .claude-plugin/plugin.json  # plugin manifest (name: tce, version)
    ├── commands/                   # the /tce:* slash commands
    ├── agents/                     # research subagents
    ├── hooks/hooks.json            # ticket-status PostToolUse hooks
    ├── scripts/                    # ticket scripts (lib.sh + next-ticket/ticket/open_tickets + hook scripts)
    └── templates/tce/              # skeletons /tce:init copies into a project (config, profile.md, design-system.md)
```

All plugin-internal references use `${CLAUDE_PLUGIN_ROOT}/...` (the plugin dir), so they
are unaffected by where the plugin sits in the repo.

### Validate & release

```bash
claude plugin validate .                 # validate the marketplace (+ the plugins it lists)
claude plugin validate ./plugins/tce     # validate just the tce plugin
# bump "version" in plugins/tce/.claude-plugin/plugin.json AND the tce entry in
# .claude-plugin/marketplace.json, then:
claude plugin tag ./plugins/tce          # create the tce--v<version> release tag
```

## License

Provided as-is. Adapt freely to your needs.
