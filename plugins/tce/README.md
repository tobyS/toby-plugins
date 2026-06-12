# tce — context-engineering workflow for Claude Code by rent-the-toby.com

`tce` is a context-engineering driven development workflow for Claude Code that
is developed and used by Toby (rent-the-toby.com). It uses a chain of context
artifacts created step-by-step to support the actual implementation: **ticket →
research → plan → implement**. Also included are commands for various review
tasks, technical discussions, and design-exploration plus a set of research
subagents used by the commands. If you don't want to observe/verify the process,
the `/tce:work` command is your shortcut to keep the benefits of context
engineering with minimal user interaction. `/tce:quickfix` lets you quickly fix
small annoyances by running the whole process autonomously, with almost no
interaction.

tce is **ticket-system-agnostic**: tickets are the entry point of the workflow,
but where they live is up to the project — the [tmt](../tmt/README.md) plugin
(markdown tickets in your repo, tce's native backend), GitHub Issues, Jira,
Linear, or anything you can describe. `/tce:init` configures the integration in
`.claude/tce/tickets.md`.

The plugin supersedes the previous
[Claude Code template](https://github.com/tobyS/claude-template). It installs
once and **updates centrally** — no more copying files into each project and
merging changes by hand. Everything project-specific lives in a small
`.claude/tce/` config that `/tce:init` creates; the workflow itself stays in the
plugin and is shared across all your projects. Commands are namespaced under
`/tce:`.

## Why context engineering?

LLMs perform best when given the right context at the right time. The workflow
builds context progressively through documents stored in `thoughts/`:

1. **Tickets** capture business requirements (the WHAT, WHY and acceptance
   criteria)
2. **Research** documents existing codebase patterns, constraints and finds the
   right API/library/tool documentation for proper implementation
3. **Plans** synthesize requirements + research into actionable steps
4. **Implementation** executes with full context from the previous phases

Each phase produces artifacts that persist across sessions, so Claude always has
the context it needs without repeated explanation. The context stays in Git so
that Claude can refer to it later and find decisions and implementation details.

Also read more
[on my blog](https://schlitt.info/blog/0793_context_engineering_claude_code.html)
about why I created this process.

## Requirements

The workflow itself is plain Markdown and needs nothing special, but the shipped
scripts have small external dependencies:

| Tool              | Needed for                                                                  | Required?                                                                                             |
| ----------------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `git`             | everything (the workflow lives in your repo)                                | **Required**                                                                                          |
| a ticket system   | tickets are the entry point of the workflow                                 | **Required** — tmt (markdown tickets in the repo), GitHub Issues, Jira, Linear, or custom             |
| `gh` (GitHub CLI) | GitHub permalinks in `/tce:research_codebase`; reading/creating tickets when GitHub Issues is the backend | Optional — required only for the GitHub Issues ticket backend            |

`/tce:init` checks for these tools and helps you pick — and verify access to —
the ticket system. Hosted backends (Jira, Linear, custom) need whatever access
tooling you document for them in `.claude/tce/tickets.md`.

## Install

```bash
# Add the marketplace (once per machine), then install the plugin:
/plugin marketplace add tobyS/toby-plugins
/plugin install tce@toby-plugins
```

## Set up a project

In each project where you want the workflow:

```bash
/tce:init
```

You usually don't have to remember this. When you enable the plugin, Claude Code
shows a short "what tce is / run `/tce:init` next" greeting (the plugin's
`show_setup_reminders` user setting). And in any project that isn't set up yet, a
`SessionStart` hook detects the missing `.claude/tce/` config and prompts Claude
to introduce tce and offer to run `/tce:init` for you — so fresh clones get the
nudge too. If the project carries an install of the original
[claude-template](https://github.com/tobyS/claude-template) (the plugins'
predecessor), the nudge says so and offers the migration instead. Once the
project is initialized the hook goes quiet; you can also turn the reminders off
via the `show_setup_reminders` setting.

`/tce:init` analyzes the project, proposes a profile (stack, test/lint/typecheck
commands, conventions) and detects the likely **ticket system** (tmt, GitHub
Issues, Jira, Linear, or custom), discusses everything with you — including
whether tce may transition ticket statuses and create tickets autonomously —
and, once you confirm, writes:

```
.claude/tce/
├── profile.md       # stack, commands, conventions (read by the commands at runtime)
├── tickets.md       # which ticket system the project uses and how tce works with it
└── design-system.md # optional, for /tce:design_explore
thoughts/shared/{research,plans,reviews,mockups,discussions}/
```

(`thoughts/shared/tickets/` belongs to the tmt plugin and is scaffolded by
`/tmt:init` when tmt is your ticket system.)

**Migrating from the original claude-template?** `/tce:init` detects the
template's files (un-namespaced `.claude/commands/*.md` and `.claude/agents/*.md`,
root `scripts/ticket.sh`, CLAUDE.md workflow boilerplate, the design-system
skeleton), proposes the migration, and removes the superseded files only after
your confirmation — a customized design-system file is moved to
`.claude/tce/design-system.md` instead. `/tmt:init` handles the ticket side
(prefix harvesting, the template's ticket scripts and settings.json hook
entries). Everything under `thoughts/shared/` carries over untouched.

Commit `.claude/tce/` — it's shared project config, not personal settings. The
commands read these files at runtime, so **you never edit the plugin** to adapt
it to a project.

## Update

```bash
/plugin marketplace update toby-plugins
```

You move to a new version of the plugin whenever you refresh the marketplace.

## Commands

Plugin commands are namespaced under `/tce:`.

| Step  | Command                  | Purpose                                                                           |
| ----- | ------------------------ | --------------------------------------------------------------------------------- |
| setup | `/tce:init`              | Analyze the project and write `.claude/tce/` config                               |
| 1     | ticket creation          | Capture business requirements (WHAT & WHY) in your ticket system (e.g. `/tmt:create`) |
| 2     | `/tce:research_codebase` | Research codebase, find patterns & libraries                                      |
| 3     | `/tce:create_plan`       | Resolve questions, create a detailed implementation plan                          |
| 3b    | `/tce:design_explore`    | _(Optional)_ Explore and select a visual design for non-trivial UX                |
| 4     | `/tce:implement_plan`    | Execute implementation using all documents                                        |
| ✓     | `/tce:code_review`       | Review an implementation (ticket-based or custom scope)                           |
| —     | `/tce:discuss`           | Technical discussion / sparring partner                                           |
| —     | `/tce:commit`            | Commit with pre-commit checks (tests/lint/typecheck from the profile)             |
| ⚡    | `/tce:work`              | Run steps 2→4 for an existing ticket autonomously (one open-questions checkpoint) |
| ⚡    | `/tce:quickfix`          | Run steps 1→4 for a small fix, fully autonomous (no ticket discussion)            |

## Agents

Specialized research subagents bundled with the plugin:

| Agent                     | Purpose                                     |
| ------------------------- | ------------------------------------------- |
| `codebase-locator`        | Find files and directories by topic         |
| `codebase-analyzer`       | Understand implementation details           |
| `codebase-pattern-finder` | Find similar implementations to model after |
| `thoughts-locator`        | Find documents in the `thoughts/` directory |
| `thoughts-analyzer`       | Extract insights from thought documents     |
| `web-search-researcher`   | Research external documentation             |

## How project parameterization works

The plugin is identical across projects; only `.claude/tce/` differs.

- **Ticket system** — described in `.claude/tce/tickets.md`: the canonical
  ticket ID format (used in thoughts/ filenames and commit scopes), how to read
  and create tickets, how to find parent/epic tickets, and whether tce may
  transition statuses. The commands read it at runtime, so the same workflow
  runs against tmt, GitHub Issues, Jira, Linear, or anything you describe. In
  command docs, `[PREFIX]-XXXX` is just a placeholder for a canonical ID.
- **Stack, commands, conventions** — live in `.claude/tce/profile.md`. Each
  command reads `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` at runtime, so
  e.g. `/tce:commit` runs _your_ test/lint/typecheck commands without the
  command being edited.
- **Scripts** are invoked via `${CLAUDE_PLUGIN_ROOT}/scripts/...` (substituted
  inline), so they resolve regardless of where the plugin is cached.
