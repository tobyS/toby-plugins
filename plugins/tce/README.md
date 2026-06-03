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
| `jq`              | the ticket-status hooks parse hook JSON with it                             | **Required** for the hooks; without it the status reminders silently don't fire (work is not blocked) |
| `gh` (GitHub CLI) | turning `file:line` refs into GitHub permalinks in `/tce:research_codebase` | Optional — degrades to local references when absent                                                   |

The ticket-numbering scripts are pure filesystem (`find` over `thoughts/`), so
they need no network, auth, or GitHub access. `/tce:init` checks for these tools
and warns if `jq` is missing.

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
nudge too. Once the project is initialized the hook goes quiet; you can also turn
the reminders off via the `show_setup_reminders` setting.

`/tce:init` analyzes the project, proposes a profile (stack, test/lint/typecheck
commands, conventions) and a ticket prefix, discusses it with you, and — once
you confirm — writes:

```
.claude/tce/
├── config           # TICKET_PREFIX=<PREFIX>   (read by the ticket scripts)
├── profile.md       # stack, commands, conventions (read by the commands at runtime)
└── design-system.md # optional, for /tce:design_explore
thoughts/shared/{tickets,research,plans,reviews,mockups,discussions}/
```

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
| 1     | `/tce:create_ticket`     | Capture business requirements (WHAT & WHY)                                        |
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

- **Ticket prefix** — stored as `TICKET_PREFIX=<PREFIX>` in
  `.claude/tce/config`. The ticket scripts (shipped in the plugin) read it and
  resolve the project root from `CLAUDE_PROJECT_DIR` (falling back to the
  working directory). In command docs, `[PREFIX]` is just a placeholder for that
  configured prefix.
- **Stack, commands, conventions** — live in `.claude/tce/profile.md`. Each
  command reads `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` at runtime, so
  e.g. `/tce:commit` runs _your_ test/lint/typecheck commands without the
  command being edited.
- **Scripts** are invoked via `${CLAUDE_PLUGIN_ROOT}/scripts/...` (substituted
  inline), so they resolve regardless of where the plugin is cached.
