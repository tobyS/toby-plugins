# toby-plugins marketplace — repository instructions

This repository is the **`toby-plugins` marketplace**, a monorepo whose plugins live
under `plugins/`. Today there's one plugin, **`tce`** — the context-engineering
workflow you install into other projects. (Marketplace = `toby-plugins`; plugin =
`tce`; keep the two names distinct.) This is not a project that uses the workflow;
when you work here, you are developing the marketplace and its plugin(s).

For what the plugin is and how it's consumed, see `README.md`.

## Layout

```
.claude-plugin/marketplace.json # the marketplace (name: toby-plugins) — lists plugins by relative source
plugins/tce/                    # the tce plugin (CLAUDE_PLUGIN_ROOT points here once installed)
├── .claude-plugin/plugin.json  # plugin manifest (name: tce, version)
├── commands/*.md               # the /tce:* slash commands
├── agents/*.md                 # research subagents
├── hooks/hooks.json            # ticket-status PostToolUse hooks
├── scripts/*.sh                # ticket scripts + shared lib.sh + hook scripts
└── templates/tce/              # skeletons /tce:init copies into a consuming project
                                #   (config, profile.md, design-system.md) — source of truth for their structure
```

To add another plugin: create `plugins/<name>/` (with its own `.claude-plugin/plugin.json`)
and add an entry to `.claude-plugin/marketplace.json` with `source: "./plugins/<name>"`.

## Core design rule: keep the plugin project-agnostic

Nothing project-specific belongs in the plugin (`plugins/tce/` — its `commands/`,
`agents/`, `hooks/`, `scripts/`). All per-project data lives in the consuming
project's `.claude/tce/` (created by `/tce:init`). When editing:

- **No stack literals in commands.** Don't hardcode `php artisan`, `bun run`, framework
  names, or paths like `[project-root]/backend`. Instead, instruct the command to read
  `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and use what it finds.
- **`[PREFIX]` is a placeholder**, not a real prefix. The real ticket prefix is in the
  consuming project's `.claude/tce/config` (`TICKET_PREFIX=...`). Commands resolve it by
  running the scripts; they never hardcode it.
- **Reference shipped scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/...`** in command and
  hook text. This variable is substituted inline and survives plugin updates.
- **Scripts must not assume their own location maps to the project.** Use the helpers in
  `plugins/tce/scripts/lib.sh`: `tce_project_root` (`CLAUDE_PROJECT_DIR` or `$PWD`) and
  `tce_ticket_prefix` (reads `.claude/tce/config`). Hook scripts no-op silently when no
  prefix is configured; user-invoked scripts error and point to `/tce:init`.

## Composite commands must track the single-step commands

Two commands are **composite**: they chain the single-step workflow commands and run
them with reduced user interaction.

- **`/tce:work`** — `/research_codebase` → (open-questions checkpoint) → `/create_plan`
  → `/implement_plan` for an existing ticket.
- **`/tce:quickfix`** — `/create_ticket` → `/research_codebase` → `/create_plan` →
  `/implement_plan` for a small, well-understood fix, fully autonomous.

These commands re-describe (and, for planning/implementation, delegate to) the
single-step commands. They are therefore **derived artifacts** that can silently drift
out of sync.

**RULE: Whenever you change a single-step command (`create_ticket`, `research_codebase`,
`create_plan`, `implement_plan`, `commit`, `design_explore`), check `work.md` and
`quickfix.md` and update them in the same commit if the change affects anything they
mirror** — e.g. the research agent list, the ticket/research/plan templates, the
open-questions or design-exploration checks, the status-file mechanics, commit
conventions, or the phase ordering. The composite commands must produce output
identical in quality and structure to running the single-step commands manually; the
only intended difference is the reduced interaction. When in doubt, re-read both
composite commands after editing any single-step command.

## Testing changes

- **Manifests:** `claude plugin validate .` (marketplace) and
  `claude plugin validate ./plugins/tce` (the plugin).
- **Scripts:** create a throwaway project dir with `.claude/tce/config` and
  `thoughts/shared/tickets/`, then run e.g.
  `CLAUDE_PROJECT_DIR=/tmp/fakeproj plugins/tce/scripts/next-ticket.sh`.
- **End to end:** `/plugin marketplace add .` then `/plugin install tce@toby-plugins`
  in a scratch project, run `/tce:init`, and exercise the commands. (Reverts: uninstall
  + `marketplace remove`.)

## Releasing

Bump `version` in **both** `plugins/tce/.claude-plugin/plugin.json` and the matching
`tce` entry in `.claude-plugin/marketplace.json`, then `claude plugin tag ./plugins/tce`
to create the `tce--v<version>` git tag. Consumers pick up the new version with
`/plugin marketplace update toby-plugins`.

## Conventions

- PRs/commits: concise, conventional commits, what-not-how.
- Don't auto-push; the human decides when to push.
- Markdown-heavy repo — when editing a command, preserve its existing structure and
  altitude; most commands are long prompts and small surgical edits are safer than
  rewrites.
