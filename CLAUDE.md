# toby-plugins marketplace — repository instructions

This repository is the **`toby-plugins` marketplace**, a monorepo whose plugins live
under `plugins/`. There are two plugins: **`tce`** — the context-engineering workflow
you install into other projects — and **`tmt`** (Toby Markdown Tickets) — a
lightweight markdown ticket tracker that works standalone and is tce's native ticket
backend. (Marketplace = `toby-plugins`; plugins = `tce`, `tmt`; keep the names
distinct.) When you work here, you are developing the marketplace and its plugins —
and the repo **dogfoods both**: tickets are tmt tickets (prefix `TP`) in
`thoughts/shared/tickets/`, and the tce workflow applies (`.claude/tce/` +
`.claude/tmt/` are this project's own config).

The root `README.md` documents the **marketplace** (how to add it, the plugin
catalog, repo layout, release flow). For what each plugin is and how it's consumed,
see `plugins/tce/README.md` and `plugins/tmt/README.md`.

## Layout

```
.claude-plugin/marketplace.json # the marketplace (name: toby-plugins) — lists plugins by relative source
plugins/tce/                    # the tce plugin (CLAUDE_PLUGIN_ROOT points here once installed)
├── .claude-plugin/plugin.json  # plugin manifest (name: tce, version)
├── README.md                   # the tce plugin docs (consumer-facing)
├── commands/*.md               # the /tce:* slash commands
├── agents/*.md                 # research subagents
├── hooks/hooks.json            # SessionStart init nudge
├── scripts/*.sh                # lib.sh, ticket.sh (thoughts lookup by ID), check-init.sh
└── templates/tce/              # skeletons /tce:init copies into a consuming project
                                #   (profile.md, tickets.md, design-system.md) — source of truth for their structure
plugins/tmt/                    # the tmt plugin
├── .claude-plugin/plugin.json  # plugin manifest (name: tmt, version)
├── README.md                   # the tmt plugin docs (consumer-facing)
├── commands/*.md               # /tmt:init, /tmt:create, /tmt:list
├── hooks/hooks.json            # ticket-status PostToolUse hooks (git add reminder, status validation)
├── scripts/*.sh                # lib.sh, next-ticket.sh, open_tickets.sh + hook scripts
└── templates/tmt/              # config skeleton (TICKET_PREFIX=) /tmt:init copies into a project
```

To add another plugin: create `plugins/<name>/` (with its own `.claude-plugin/plugin.json`)
and add an entry to `.claude-plugin/marketplace.json` with `source: "./plugins/<name>"`.

## Core design rule: keep the plugins project-agnostic

Nothing project-specific belongs in a plugin (its `commands/`, `agents/`, `hooks/`,
`scripts/`). All per-project data lives in the consuming project: `.claude/tce/`
(created by `/tce:init` — `profile.md` + `tickets.md`, markdown only) and
`.claude/tmt/config` (created by `/tmt:init` — machine-readable, parsed by tmt's
shell scripts/hooks). When editing:

- **No stack literals in tce commands.** Don't hardcode `php artisan`, `bun run`,
  framework names, or paths like `[project-root]/backend`. Instead, instruct the
  command to read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and use what it finds.
- **No ticket-system literals in tce commands.** tce is ticket-system-agnostic: how to
  resolve/read/create tickets and the status policy come from the project's
  `.claude/tce/tickets.md`. tmt conventions may appear only as the *example* of a
  generic mechanism ("for tmt, …"). **`[PREFIX]-XXXX` is a placeholder** for a
  canonical ticket ID (e.g. `MYAPP-0042`, `GH-123`) — never a real prefix.
- **tmt owns the ticket envelope.** Prefix (`TICKET_PREFIX` in `.claude/tmt/config`),
  numbering, file location (`thoughts/shared/tickets/`), the `**Status:**` enum and
  its enforcement hooks all live in `plugins/tmt/`. tce declares payload expectations
  ("What tce needs from a ticket" in its `tickets.md` template); `/tmt:create` honors
  that section when the file exists. The plugins coordinate **only through project
  config files**, never by calling into each other (there is no cross-plugin
  `${CLAUDE_PLUGIN_ROOT}`).
- **Reference shipped scripts via `${CLAUDE_PLUGIN_ROOT}/scripts/...`** in command and
  hook text. This variable is substituted inline (per plugin) and survives updates.
- **Scripts must not assume their own location maps to the project.** Use the helpers
  in each plugin's `scripts/lib.sh`: `tce_project_root` / `tmt_project_root`
  (`CLAUDE_PROJECT_DIR` or `$PWD`) and `tmt_ticket_prefix` (reads `.claude/tmt/config`,
  with a legacy fallback to `.claude/tce/config` from tce ≤1.x). tmt hook scripts
  no-op silently when no prefix is configured; user-invoked scripts error and point to
  `/tmt:init`.

## Why per-project config, not plugin `userConfig` (for the ticket prefix)

Claude Code plugins support [`userConfig`](https://code.claude.com/docs/en/plugins-reference#user-configuration)
— values declared in `plugin.json` that Claude Code prompts for **when the plugin is
enabled**, stored in the user's `settings.json` under `pluginConfigs[<id>].options`,
and substitutable as `${user_config.KEY}` in hook/MCP/LSP/monitor configs and
(non-sensitive) in skill/agent content. It is tempting to move tmt's `TICKET_PREFIX`
there and drop the `.claude/tmt/config` file. **Don't** — the scope is wrong:

- `userConfig` is **per-user, per-plugin-install**, prompted once at enable time. It has
  **no per-project dimension**: one developer working across several tmt repos would get
  a single shared prefix (ID collisions), and the value is **not Git-tracked**, so
  teammates cloning the repo wouldn't inherit it and could desync ticket IDs. The ticket
  prefix is inherently per-project and team-shared — exactly what `.claude/tmt/config`
  (committed) provides and `userConfig` cannot.
- Substituting `${user_config.*}` to replace placeholders doesn't help either: the docs
  grant substitution in *skill and agent content*, **not in `commands/*.md`** (our
  commands), and it would inject the machine-global value anyway. Placeholders in
  commands are almost entirely illustrative; the operational prefix is resolved at
  runtime by tmt's scripts. Keep it that way.

**Where `userConfig` *is* the right tool:** install-time, user-scoped, non-project state.
We use exactly one entry — `show_setup_reminders` (boolean, default `true`) — to greet
the user at enable time (its `title`/`description` carry the "what tce is / run
`/tce:init` next" blurb) and to let them silence the setup nudge. Its value is passed to
the `SessionStart` hook as `${user_config.show_setup_reminders}`; `check-init.sh` stays
silent only when the arg is the literal `"false"` (empty / un-substituted on older
Claude Code = reminders on). See the next section.

## Prompting `/tce:init`: the `SessionStart` hook + enable-time greeting

The plugin must steer a fresh project toward `/tce:init` without it being run manually.
There is **no "plugin installed" hook event** in Claude Code (the hook-event list keeps
growing, but none fires on install/enable/update). So we use two complementary mechanisms:

- **`SessionStart` hook → `scripts/check-init.sh`** (matcher `startup|resume|clear`). It
  guards on `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` (the first file `/tce:init`
  writes): if missing, it emits `additionalContext` with one of **two nudge variants** —
  if the project carries the claude-template signature (`scripts/next-ticket.sh` +
  `.claude/commands/research_codebase.md`), a migration-tailored nudge; otherwise the
  generic introduce-tce nudge (offer + brief docs, run on confirm). If `profile.md`
  exists, it's a silent no-op. This is **project-state-aware** and also covers fresh
  clones — the closest equivalent to an install-time trigger, since the first session
  after install is uninitialized.
- **`userConfig` enable-time greeting** (`show_setup_reminders`, above) — fires once when
  the plugin is enabled, the actual post-install moment.

A hook **cannot execute a slash command** — it only injects context — so both mechanisms
*advise/offer*; `/tce:init` still runs interactively (and `init.md` asks before writing
files). If you change the intro/advice wording, update it in `check-init.sh` (both
heredocs), the `userConfig` `description`, and `plugins/tce/README.md` together so they
don't drift.

## Migrations & version markers (TP-0003)

Both init commands detect prior installs and migrate them, confirmed and listed —
never automatic, and never touching anything under `thoughts/shared/`:

- **Version markers** record the plugin version that last wrote the project config:
  `TMT_CONFIG_VERSION=` in `.claude/tmt/config` (sourced shell; unknown keys are inert
  to the scripts) and a `<!-- tce-config-version: X.Y.Z -->` HTML comment on line 1 of
  `.claude/tce/profile.md` (tce has no machine-readable file; never create
  `.claude/tce/config` — that name is the tce ≤1.x legacy path tmt still sources as a
  fallback). Inits stamp the marker from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`
  and compare it on re-run ("already up to date" / upgrade walk-through). **If a new
  plugin version changes what the project config must contain, extend the init's
  Idempotency upgrade list in the same commit.**
- **claude-template migration**: detection is presence-based (the template has no
  tags/releases and users were told to edit the copied files — content hashes are
  useless). Cleanup duties split by successor ownership: `/tmt:init` removes the 4
  ticket scripts, `create_ticket.md`, the template's two PostToolUse entries in
  `.claude/settings.json` (the one sanctioned settings.json edit, approval-gated) and
  offers to delete the legacy `.claude/tce/config`; `/tce:init` removes the 7
  un-namespaced commands, 6 agents, `scripts/ticket.sh`, proposes CLAUDE.md
  boilerplate-section edits (approved individually), and moves a customized
  `.claude/references/design-system.md` to `.claude/tce/design-system.md` (pristine
  skeletons are deleted). No artifact appears in both lists.

## Composite commands must track the single-step commands

Two commands are **composite**: they chain the single-step workflow commands and run
them with reduced user interaction.

- **`/tce:work`** — (ticket sufficiency check) → `/tce:research_codebase` → (open-questions
  checkpoint) → `/tce:create_plan` → `/tce:implement_plan` for an existing ticket.
- **`/tce:quickfix`** — ticket creation (via the project's `tickets.md` mechanism;
  mirrors tmt's `/tmt:create` template for tmt projects) → `/tce:research_codebase` →
  `/tce:create_plan` → `/tce:implement_plan` for a small, well-understood fix, fully
  autonomous. Refuses if `tickets.md` forbids autonomous ticket creation.

These commands re-describe (and, for planning/implementation, delegate to) the
single-step commands. They are therefore **derived artifacts** that can silently drift
out of sync.

**RULE: Whenever you change a single-step command (`research_codebase`, `create_plan`,
`implement_plan`, `commit`, `design_explore`), check `work.md` and `quickfix.md` and
update them in the same commit if the change affects anything they mirror** — e.g. the
research agent list, the research/plan templates, the sufficiency/open-questions/
design-exploration checks, the status-file mechanics, the ticket-status policy
handling, commit conventions, or the phase ordering. The same applies across plugins:
if tmt's ticket template (`/tmt:create`) changes, update quickfix's inlined tmt
template to match. The composite commands must produce output identical in quality
and structure to running the single-step commands manually; the only intended
difference is the reduced interaction. When in doubt, re-read both composite commands
after editing any single-step command.

## `/tce:refresh` re-analysis must track `/tce:init`'s analysis

`/tce:refresh` (reconcile `.claude/tce/profile.md` with the actual repo) re-implements the
same project analysis `/tce:init` Phase 1 performs — stack/tooling, the build/test/lint
commands, and the code map — described **in its own words** rather than shared at runtime
(commands don't read each other's markdown). The two descriptions can silently drift.

**RULE: When you change what `/tce:init` Phase 1 detects, or how it fills profile.md's
factual sections (Tech stack, Commands, Code map), update `/tce:refresh`'s Phase 1 in the
same commit — and vice versa.** `/tce:refresh` also maintains the `tce-config-version`
marker the same way init does (see "Migrations & version markers"). It does **not** change
what profile.md must contain, so it needs no Idempotency upgrade-list entry. Note the
drift *detection* that recommends `/tce:refresh` lives in `/tce:research_codebase` (and is
mirrored into the composites per the rule above); `/tce:refresh` itself is the *fix*.

## The AskUserQuestion guidelines block is duplicated — keep the copies identical

The `### AskUserQuestion dialog guidelines` block (dialog copy rules: intro text
above the dialog, recommended-first with reasoning in the description, tool limits,
plain text only) is deliberately duplicated **byte-identically** across the seven
commands with dialog sites: `plugins/tce/commands/{init,research_codebase,
create_plan,work,quickfix,refresh}.md` and `plugins/tmt/commands/init.md`. (Duplication
instead of a shared file because commands don't read plugin-internal markdown at
runtime, and cross-plugin references are forbidden — see the core design rule.)

**RULE: When you edit the block in one file, update all seven copies in the same
commit.** Verify by extracting each block (heading through its last bullet) and
diffing. Related: the verbatim dialog copy in `tce/init.md` (ticket-system + policy
dialogs) and `tmt/init.md` (prefix dialog) is part of the commands' contract —
wording changes go through normal commits/review and are never improvised at
runtime (TP-0001).

## Testing changes

- **Manifests:** `claude plugin validate .` (marketplace) and
  `claude plugin validate ./plugins/tce` / `./plugins/tmt` (each plugin).
- **Scripts:** create a throwaway project dir with `.claude/tmt/config`
  (`TICKET_PREFIX=FAKE`) and `thoughts/shared/tickets/`, then run e.g.
  `CLAUDE_PROJECT_DIR=/tmp/fakeproj plugins/tmt/scripts/next-ticket.sh`. The hook
  scripts take their JSON on stdin (`echo '{"tool_input":{...}}' | …`).
- **End to end:** `/plugin marketplace add .` then `/plugin install tmt@toby-plugins`
  and `/plugin install tce@toby-plugins` in a scratch project, run `/tmt:init` +
  `/tce:init`, and exercise the commands. (Reverts: uninstall + `marketplace remove`.)

## Releasing

Bump `version` in **both** the plugin's `.claude-plugin/plugin.json` and the matching
entry in `.claude-plugin/marketplace.json`, then `claude plugin tag ./plugins/<name>`
to create the `<name>--v<version>` git tag. Each plugin is versioned and tagged
independently. Consumers pick up the new version with
`/plugin marketplace update toby-plugins`.

**Versioning convention:** every plugin in this marketplace starts at `1.0.0` (tce
did; new plugins follow suit).

## Conventions

- PRs/commits: concise, conventional commits, what-not-how.
- Don't auto-push; the human decides when to push.
- Markdown-heavy repo — when editing a command, preserve its existing structure and
  altitude; most commands are long prompts and small surgical edits are safer than
  rewrites.
