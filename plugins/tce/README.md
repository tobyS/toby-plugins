# tce — Toby Context Engineering

A context-engineering development workflow for Claude Code: a chain of context
artifacts built step-by-step — **ticket → research → plan → implement** — that gives
Claude the right context at each stage of a task. Also included: commands for review,
technical discussion, and design exploration, plus a set of research subagents the
commands rely on.

In a hurry? `/tce:work` runs the whole chain for an existing ticket with minimal
interaction, and `/tce:quickfix` fixes small annoyances fully autonomously — both keep
the benefits of context engineering without you watching every step.

tce is **ticket-system-agnostic**: tickets are the entry point, but where they live is
up to the project — the [tmt](../tmt/README.md) plugin (markdown tickets in your repo,
tce's native backend), GitHub Issues, Jira, Linear, or anything you can describe.
`/tce:init` configures the integration in `.claude/tce/tickets.md`. The plugin installs
once and **updates centrally** — no more copying files into each project and merging
changes by hand. Everything project-specific lives in a small `.claude/tce/` config that
`/tce:init` creates; commands are namespaced under `/tce:`.

> **Built by Toby.** These plugins come out of my daily practice helping
> engineering teams turn experimental AI use into structured, sustainable
> workflows. Need a sparring partner for the hard technical and AI-adoption calls?
> Find me at [rent-the-toby.com](https://rent-the-toby.com).

## Contents

- [Why context engineering?](#why-context-engineering)
- [Requirements](#requirements)
- [Install](#install)
- [Set up a project](#set-up-a-project)
- [Update](#update)
- [Commands](#commands)
- [Agents](#agents)
- [How project parameterization works](#how-project-parameterization-works)
- [Contributing](#contributing)

## Why context engineering?

LLMs perform best when given the right context at the right time. The workflow builds
context progressively through documents stored in `thoughts/`:

1. **Tickets** capture business requirements (the WHAT, WHY and acceptance criteria)
2. **Research** documents existing codebase patterns, constraints and finds the right
   API/library/tool documentation for proper implementation
3. **Plans** synthesize requirements + research into actionable steps
4. **Implementation** executes with full context from the previous phases

Each phase produces artifacts that persist across sessions, so Claude always has the
context it needs without repeated explanation. The context stays in Git so that Claude
can refer to it later and find decisions and implementation details.

The plugin supersedes the previous
[Claude Code template](https://github.com/tobyS/claude-template) — installed once and
updated centrally instead of copied per project. Also read more
[on my blog](https://schlitt.info/blog/0793_context_engineering_claude_code.html)
about why I created this process.

## Requirements

The workflow itself is plain Markdown and needs nothing special, but the shipped
scripts have small external dependencies:

| Tool              | Needed for                                                                  | Required?                                                                                             |
| ----------------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `git`             | everything (the workflow lives in your repo)                                | **Required**                                                                                          |
| a ticket system   | tickets are the entry point of the workflow                                 | **Required** — tmt (markdown tickets in the repo), GitHub Issues, Jira, Linear, or custom             |
| `gh` (GitHub CLI) | GitHub permalinks in `/tce:research`; reading/creating tickets when GitHub Issues is the backend | Optional — required only for the GitHub Issues ticket backend            |

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
commands, conventions, and the **commit convention** tce should use — Conventional
Commits, plain, or issue-reference, pre-selected from your git history) and detects
the likely **ticket system** (tmt, GitHub Issues, Jira, Linear, or custom), discusses
everything with you — including whether tce may transition ticket statuses and create
tickets autonomously — and, once you confirm, writes:

```
.claude/tce/
├── profile.md       # stack, commands, conventions, commit convention (read by the commands at runtime)
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

Plugin commands are namespaced under `/tce:`. The core workflow is the
ticket → research → plan → implement chain; the rest support and accelerate it.

**Core workflow** — the four-step context chain, run in order:

| Command           | Purpose                                                                       |
| ----------------- | ----------------------------------------------------------------------------- |
| `/tce:ticket`     | Author a ticket (WHAT & WHY) and create it in your ticket system (any backend) |
| `/tce:research`   | Research the codebase, find patterns & libraries                              |
| `/tce:plan`       | Resolve questions, create a detailed implementation plan                      |
| `/tce:implement`  | Execute the implementation using all documents                                |

**Shortcuts** — run the chain with reduced interaction:

| Command          | Purpose                                                                            |
| ---------------- | --------------------------------------------------------------------------------- |
| `/tce:work`      | Run steps research→implement for an existing ticket autonomously (one open-questions checkpoint) |
| `/tce:quickfix`  | Run the full chain for a small fix, fully autonomous (no ticket discussion)        |

**Helpers** — supporting commands you reach for as needed:

| Command               | Purpose                                                             |
| --------------------- | ------------------------------------------------------------------ |
| `/tce:discuss`        | Technical discussion / sparring partner                            |
| `/tce:review`         | Review an implementation (ticket-based or custom scope)            |
| `/tce:commit`         | Commit with pre-commit checks and the profile's commit convention  |
| `/tce:design_explore` | _(Optional)_ Explore and select a visual design for non-trivial UX |

**Maintenance** — project setup & keeping config in sync:

| Command         | Purpose                                                                                 |
| --------------- | --------------------------------------------------------------------------------------- |
| `/tce:init`     | Analyze the project and write `.claude/tce/` config                                     |
| `/tce:refresh`  | Reconcile `.claude/tce/profile.md` with the repo when it drifts (per-section, approved) |

`/tce:research` also watches for profile drift while it works: if the
codebase has outgrown `profile.md` (a new stack, a build/test command that no longer
exists, a moved directory), it adds a non-blocking note suggesting you run
`/tce:refresh`. `/tce:refresh` re-analyzes the repo, proposes per-section changes, and
writes only what you approve — leaving your hand-written Conventions and research
sources untouched.

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
- **Stack, commands, conventions, commit convention** — live in
  `.claude/tce/profile.md`. Each command reads
  `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` at runtime, so e.g. `/tce:commit`
  runs _your_ test/lint/typecheck commands and writes messages in _your_ commit
  convention without the command being edited.
- **Scripts** are invoked via `${CLAUDE_PLUGIN_ROOT}/scripts/...` (substituted
  inline), so they resolve regardless of where the plugin is cached.

## Contributing

Want to work on the plugin itself? See the repository's
[CONTRIBUTING.md](../../CONTRIBUTING.md) for the layout, how to validate changes, and
the release flow.
