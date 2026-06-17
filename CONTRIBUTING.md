# Contributing to toby-plugins

Thanks for your interest in improving these plugins! This repository is the
**`toby-plugins` marketplace** — a monorepo containing two Claude Code plugins under
`plugins/`:

- **`tce`** — the context-engineering development workflow.
- **`tmt`** — Toby Markdown Tickets, a Git-tracked markdown ticket tracker.

This guide covers how to work on the plugins themselves. If you just want to *use*
them, see the [marketplace README](README.md) and each plugin's README
([`tce`](plugins/tce/README.md), [`tmt`](plugins/tmt/README.md)).

## Two names, kept distinct

`toby-plugins` is the **marketplace** (the catalog you add); a plugin (e.g. `tce`) is
**what you install** from it, using `<plugin>@toby-plugins`. The repo name matches the
marketplace `name` in `.claude-plugin/marketplace.json` (`toby-plugins`) by design, so
the same string appears in both `marketplace add …/toby-plugins` and
`install <plugin>@toby-plugins`.

## Repository layout

This is a **monorepo marketplace**: the marketplace lives at the repo root and lists
plugins that live under `plugins/`. Adding another plugin is a new `plugins/<name>/`
directory (with its own `.claude-plugin/plugin.json`) plus an entry in
`marketplace.json` with `source: "./plugins/<name>"`.

```
.claude-plugin/marketplace.json   # the marketplace (name: toby-plugins) — lists the plugins
plugins/
├── tce/                          # the tce plugin (CLAUDE_PLUGIN_ROOT points here once installed)
│   ├── .claude-plugin/plugin.json  # plugin manifest (name: tce, version)
│   ├── README.md                   # the tce plugin docs
│   ├── commands/                   # the /tce:* slash commands
│   ├── agents/                     # research subagents
│   ├── hooks/hooks.json            # SessionStart init nudge
│   ├── scripts/                    # lib.sh, ticket.sh (thoughts lookup), check-init.sh
│   └── templates/tce/              # skeletons /tce:init copies into a project
└── tmt/                          # the tmt plugin (Toby Markdown Tickets)
    ├── .claude-plugin/plugin.json  # plugin manifest (name: tmt, version)
    ├── README.md                   # the tmt plugin docs
    ├── commands/                   # /tmt:init, /tmt:create, /tmt:update, /tmt:list
    ├── hooks/hooks.json            # ticket-status PostToolUse hooks
    ├── scripts/                    # lib.sh, next-ticket.sh, open_tickets.sh + hook scripts
    └── templates/tmt/              # config skeleton /tmt:init copies into a project
```

All plugin-internal references use `${CLAUDE_PLUGIN_ROOT}/...` (the plugin dir), so they
are unaffected by where the plugin sits in the repo.

## Working on the plugins

A few conventions to follow:

- **Work directly on `main`.** This repository uses no branching or PR strategy —
  commit straight to `main`; don't create feature branches.
- **Conventional commits**, concise, describing *what* changed, not *how*.
- **Never auto-push** — pushing is the maintainer's call.

The plugins are deliberately **project-agnostic**: nothing project-specific belongs in a
plugin's `commands/`, `agents/`, `hooks/`, or `scripts/`. The full set of design rules —
the project-agnostic rule, the ownership boundary between `tce` and `tmt`, the rule that
composite commands must track the single-step commands, migrations, and more — lives in
[`CLAUDE.md`](CLAUDE.md), which is the authoritative reference our tooling and reviewers
follow. (It's written as instructions for the AI agent working in this repo, but it's the
best map of the design constraints for human contributors too.)

## Validating changes

There is no application runtime or build step — the "code" is markdown command prompts,
bash scripts, and JSON manifests. To validate:

```bash
claude plugin validate .                 # validate the marketplace (+ the plugins it lists)
claude plugin validate ./plugins/tce     # validate a single plugin
claude plugin validate ./plugins/tmt     # (same for the other plugin)
```

For **script changes**, smoke-test against a throwaway project with a
`.claude/tmt/config` (`TICKET_PREFIX=FAKE`) and `thoughts/shared/tickets/`, then run e.g.

```bash
CLAUDE_PROJECT_DIR=/tmp/fakeproj plugins/tmt/scripts/next-ticket.sh
```

Hook scripts take their JSON on stdin (`echo '{"tool_input":{...}}' | …`). For an
**end-to-end** check, `/plugin marketplace add .`, then install and exercise the plugins
in a scratch project. See "Testing changes" in [`CLAUDE.md`](CLAUDE.md) for the full
details.

## Update gating

Updates are gated per plugin by its `version` (in the plugin's `plugin.json`, mirrored in
the marketplace entry), so consuming projects only move when a plugin is bumped.

## Releasing

Each plugin is versioned and tagged independently (every plugin starts at `1.0.0`):

```bash
# bump "version" in plugins/<name>/.claude-plugin/plugin.json AND the matching entry in
# .claude-plugin/marketplace.json, then:
claude plugin tag ./plugins/<name>       # create the <name>--v<version> release tag
```

Consumers pick up the new version with `/plugin marketplace update toby-plugins`.
