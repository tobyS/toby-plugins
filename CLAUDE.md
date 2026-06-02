# tce plugin — repository instructions

This repository **is the `tce` Claude Code plugin** (and its own marketplace). It is
not a project that uses the workflow — it's the source you install into other
projects. When you work here, you are developing the plugin.

For what the plugin is and how it's consumed, see `README.md`.

## Layout

```
.claude-plugin/plugin.json      # manifest (name: tce, version)
.claude-plugin/marketplace.json # self-marketplace (name: rent-the-toby)
commands/*.md                   # the /tce:* slash commands
agents/*.md                     # research subagents
hooks/hooks.json                # ticket-status PostToolUse hooks
scripts/*.sh                    # ticket scripts + shared lib.sh + hook scripts
templates/tce/                  # skeletons /tce:init copies into a consuming project
                                #   (config, profile.md, design-system.md) — source of truth for their structure
```

## Core design rule: keep the plugin project-agnostic

Nothing project-specific belongs in `commands/`, `agents/`, `hooks/`, or `scripts/`.
All per-project data lives in the consuming project's `.claude/tce/` (created by
`/tce:init`). When editing:

- **No stack literals in commands.** Don't hardcode `php artisan`, `bun run`, framework
  names, or paths like `[project-root]/backend`. Instead, instruct the command to read
  `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and use what it finds.
- **`[PREFIX]` is a placeholder**, not a real prefix. The real ticket prefix is in the
  consuming project's `.claude/tce/config` (`TICKET_PREFIX=...`). Commands resolve it by
  running the scripts; they never hardcode it.
- **Reference shipped scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/...`** in command and
  hook text. This variable is substituted inline and survives plugin updates.
- **Scripts must not assume their own location maps to the project.** Use the helpers in
  `scripts/lib.sh`: `tce_project_root` (`CLAUDE_PROJECT_DIR` or `$PWD`) and
  `tce_ticket_prefix` (reads `.claude/tce/config`). Hook scripts no-op silently when no
  prefix is configured; user-invoked scripts error and point to `/tce:init`.

## Testing changes

- **Manifests:** `claude plugin validate .`
- **Scripts:** create a throwaway project dir with `.claude/tce/config` and
  `thoughts/shared/tickets/`, then run e.g.
  `CLAUDE_PROJECT_DIR=/tmp/fakeproj scripts/next-ticket.sh`.
- **End to end:** `/plugin marketplace add .` then `/plugin install tce@rent-the-toby`
  in a scratch project, run `/tce:init`, and exercise the commands. (Reverts: uninstall
  + `marketplace remove`.)

## Releasing

Bump `version` in **both** `plugin.json` and the matching entry in `marketplace.json`,
then `claude plugin tag .` to create the `tce--v<version>` git tag. Consumers pick up
the new version with `/plugin marketplace update rent-the-toby`.

## Conventions

- PRs/commits: concise, conventional commits, what-not-how.
- Don't auto-push; the human decides when to push.
- Markdown-heavy repo — when editing a command, preserve its existing structure and
  altitude; most commands are long prompts and small surgical edits are safer than
  rewrites.
