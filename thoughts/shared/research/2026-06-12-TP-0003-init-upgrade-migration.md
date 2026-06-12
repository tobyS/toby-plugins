---
date: 2026-06-12
ticket: TP-0003
topic: "Init commands detect and migrate prior installs (template & older plugin versions)"
status: complete
git_commit: 3634e1623148e970e9c10e8f1f4e36bf4b75d47b
branch: main
---

# Research: TP-0003 — Init commands detect and migrate prior installs

**Date:** 2026-06-12
**Ticket:** `thoughts/shared/tickets/TP-0003-init-upgrade-migration.md`
**Git commit at research time:** `3634e16` (main)

## Research Question

`/tce:init` and `/tmt:init` must learn to detect (a) an older plugin install
(legacy `.claude/tce/config` from tce ≤1.x, or any config written by an older
plugin version) and (b) an install of the original
[claude-template](https://github.com/tobyS/claude-template), then offer and
perform a confirmed migration; `check-init.sh` must recognize the template and
tailor its SessionStart nudge; each init must stamp a version marker. Determine
the current init flows and their migration seams, the exact template footprint
to detect, where version markers can live, and what the Claude Code plugin
platform offers (and doesn't) for install/update detection.

## Summary

The codebase already contains every structural seam the feature needs. Both
init commands follow the same "analyze → propose via AskUserQuestion → confirm
→ write" shape with a hard no-writes-before-confirmation gate, and both end in
an Idempotency section that handles re-runs. tmt's init **already performs a
value-level legacy migration** (detect `.claude/tce/config` → surface
"Migrated from legacy…" provenance in the prefix dialog → post-write cleanup
advice), which is the in-repo precedent to extend; tce's init only *detects*
the legacy config and redirects to `/tmt:init`. Neither command, and no
script, knows about the claude-template.

The template's footprint is fully mapped: 8 un-namespaced commands in
`.claude/commands/`, 6 agents in `.claude/agents/` (names match tce's
one-to-one), 5 root `scripts/*.sh` each hardcoding `TICKET_PREFIX="…"` in an
identical config block (the value to harvest), 4 boilerplate workflow sections
in `CLAUDE.md`, a placeholder `design-system.md`, and — critically — a
`.claude/settings.json` whose two `PostToolUse` hook entries are the ancestors
of tmt's shipped hooks and would **double-fire** after plugin install. The
template has **no tags or releases** and its README tells users to edit the
copied files, so version detection is impossible and content-hash
fingerprinting unreliable: detection must be presence-based, and the
confirmed-deletion list is the safety net for user-modified copies.

For version markers: `.claude/tmt/config` is sourced shell, so an extra
`KEY=VALUE` line is fully backward-compatible today (unknown keys are inert in
`tmt_ticket_prefix()`). `.claude/tce/` has no machine-readable file — a marker
needs a new convention (HTML comment in `profile.md`, or a small dedicated
file; the name `.claude/tce/config` is *burdened* and must not be reused,
since tmt's legacy fallback still sources it). Plugins can read their own
version at runtime: `${CLAUDE_PLUGIN_ROOT}` is substituted in command text and
hook commands, and `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` exists
in the install cache (tce is at 2.0.0, tmt at 1.0.0). There is still no
install/enable/update hook event, confirming the init-command +
SessionStart-nudge approach.

Three genuine design decisions surfaced (see Open Questions): where tce's
version marker lives, whether migration may edit `.claude/settings.json`
(today both commands promise never to touch it, but the duplicate hooks make
advise-only painful), and how cleanup duties split between the two inits.

## Detailed Findings

### 1. Current init flows and their migration seams

**`/tce:init`** (`plugins/tce/commands/init.md`, 334 lines, 5 phases):

- No-writes-before-confirmation rule at lines 12–13, restated at 121; all
  writes happen in Phase 4 (line 240, "only after explicit confirmation").
- Phase 1 item 6 (lines 102–115) is the ticket-system detection probe set —
  including the legacy `TICKET_PREFIX=` in `.claude/tce/config` check (lines
  105–107). Phase 1 item 7 (lines 116–117) checks for existing
  `profile.md`/`tickets.md` and defers to the Idempotency section. A
  template-install probe is the same shape and slots in here.
- Phase 2 (lines 119–213) is the dialog point: detected option first,
  "(Recommended)" label, detection reasoning in the description (lines
  169–172) — the established pattern for a "migrate detected install?"
  question. Dialog copy is a verbatim contract (TP-0001).
- Phase 4 step 5 (lines 300–313) is the hand-off summary where migration
  results would be reported. No auto-commit (line 313).
- Idempotency (lines 315–326): re-run = "review and amend"; the "Legacy
  projects" paragraph (322–326) is advisory-only — redirect to `/tmt:init`,
  suggest deleting `.claude/tce/config` afterwards. tce never migrates it
  itself.
- Notes: **"never edits `.claude/settings.json`"** (lines 330–331) — directly
  in tension with the template's settings.json clash (finding 3b).
- The AskUserQuestion guidelines block sits at lines 15–33 (one of six synced
  byte-identical copies; sync rule in repo CLAUDE.md).

**`/tmt:init`** (`plugins/tmt/commands/init.md`, 156 lines, 4 phases):

- Phase 1 (lines 57–71) derives the prefix in priority order: existing ticket
  filenames → **legacy `.claude/tce/config`** ("this run migrates it", lines
  64–67) → fresh derivation. Idempotency check for existing `.claude/tmt/config`
  at line 71.
- Phase 2 prefix dialog (lines 73–100, TP-0001 verbatim contract) already has
  the provenance string **"Migrated from legacy .claude/tce/config."** (lines
  90–93).
- Phase 3 step 3 is an existing **"Legacy cleanup"** step (lines 122–125):
  advises that the legacy file is superseded, but "Do not edit tce's files
  yourself" (line 125). The detect → provenance-in-dialog → cleanup-step
  pattern is the template to extend.
- Guidelines block at lines 14–32. Same never-edit-settings.json note (lines
  152–153), no auto-commit (line 141).
- The cross-command ping-pong: tce Phase 3 hands off to `/tmt:init` and asks
  to re-run `/tce:init` after (tce init.md:226–238); tmt's hand-off suggests
  running/re-running `/tce:init` (tmt init.md:137–139). Coordination is only
  through project config files.

**Re-run/prior-state handling that must not regress:** tce Idempotency
(315–320: don't clobber, diff, ask), tmt Idempotency (143–148: show existing
prefix, warn that changing it breaks numbering), `thoughts/` scaffolding skips
existing dirs in both.

### 2. Scripts, hooks, config formats, and version-marker options

**`check-init.sh`** (`plugins/tce/scripts/check-init.sh`, 89 lines) is linear:
userConfig gate (`"$1" = "false"` → silent exit; lines 42–45) → init guard
(`profile.md` exists → silent exit; lines 50–54) → fixed heredoc nudge text
(58–73) → jq-free awk-escape + `hookSpecificOutput`/`additionalContext` JSON
emission (75–85). Template detection slots in around the guard: extra
existence checks against `$(tce_project_root)`, selecting a different
`CONTEXT` heredoc; the escape/emit tail is state-agnostic and reusable as-is.
Wired in `plugins/tce/hooks/hooks.json:9` with matcher `startup|resume|clear`,
passing `${user_config.show_setup_reminders}` as `$1`.

**`tmt_ticket_prefix()`** (`plugins/tmt/scripts/lib.sh:22-35`) sources
`.claude/tmt/config` then legacy `.claude/tce/config` (line 25), breaking on
the first non-empty `TICKET_PREFIX`. Because the config is **sourced**, any
additional `KEY=VALUE` line (e.g. a version key) is inert to existing
consumers — fully backward- and forward-compatible. The config template
(`plugins/tmt/templates/tmt/config`) is 7 lines: comment header ("simple
KEY=VALUE lines; it is sourced by the shell") + `TICKET_PREFIX=`.

**tce has no machine-readable config.** All three `.claude/tce/` files are
prose markdown without frontmatter; the only script access is an existence
check on `profile.md`. Options for a tce marker: (a) an HTML comment or
marker line in `profile.md` (precedent: `tickets.md` already uses an HTML
comment as a structural marker, template lines 49–50; greppable by
check-init.sh), or (b) a new dedicated file under `.claude/tce/`. **Do not
name it `.claude/tce/config`** — that exact path is the legacy tce ≤1.x
location that `tmt_ticket_prefix()` still sources; recreating it would
re-trigger the legacy fallback path.

**Scripts can read their own plugin's version.** Every script computes
`SCRIPT_DIR` from `BASH_SOURCE` (e.g. check-init.sh:27), and
`"$SCRIPT_DIR/../.claude-plugin/plugin.json"` resolves to the installed
manifest; `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` works in hook
command strings and command markdown too. Caveat: check-init.sh is
deliberately jq-free (line 75) — version extraction there needs a grep/sed
one-liner (tmt's hook scripts already require jq, so jq is fine on the tmt
side). Current versions: tce `2.0.0`, tmt `1.0.0` (each `plugin.json` +
duplicated in `marketplace.json`).

**tmt hook scripts' no-op discipline** (no prefix configured → silent exit 0
for hooks, hard error pointing at `/tmt:init` for user-invoked scripts) is the
behavior contract any new script logic must keep.

### 3. The claude-template footprint (detection + migration surface)

Full inventory confirmed by fetching the repo (default branch `main`):

**a) Files and their plugin successors:**

| Template artifact | Successor | Notes |
|---|---|---|
| `.claude/commands/{research_codebase,create_plan,implement_plan,commit,code_review,design_explore,discuss}.md` | tce commands (same names, now `/tce:*`) | un-namespaced duplicates shadow plugin commands |
| `.claude/commands/create_ticket.md` | `/tmt:create` | crosses the plugin boundary |
| `.claude/agents/*.md` (6 files) | `plugins/tce/agents/` | names match one-to-one |
| `scripts/ticket.sh` | tce's `scripts/ticket.sh` | |
| `scripts/{next-ticket,open_tickets,check-ticket-status,validate-ticket-status}.sh` | tmt's scripts/hooks | |
| `.claude/references/design-system.md` | `.claude/tce/design-system.md` (template) | placeholder skeleton; ancestor of tce's template |
| `CLAUDE.md` workflow sections | tce/tmt commands | see (c) |
| `.claude/settings.json` PostToolUse hooks | tmt's `hooks/hooks.json` | see (b) |
| `thoughts/shared/*` tree | unchanged | same layout both plugins use — **nothing to migrate, must be preserved** |
| `.gitignore` entries (`.claude-commit`, `.claude/settings.local.json`) | still correct | keep |

**b) `.claude/settings.json` clash.** The template ships:
`PostToolUse(Bash)` → `"$CLAUDE_PROJECT_DIR"/scripts/check-ticket-status.sh`
and `PostToolUse(Edit|Write)` → `…/validate-ticket-status.sh` — the
project-local ancestors of tmt's shipped hooks. After installing tmt these
fire **in addition to** the plugin hooks (double reminders/validation), and
they break outright once `scripts/` is deleted (hook command fails every Bash/
Edit/Write call). The file also contains `alwaysThinkingEnabled` and
macOS `Notification`/`Stop` osascript entries — user preferences a migration
must not touch. Both init commands currently promise never to edit
`.claude/settings.json` → decision needed (Open Question 2).

**c) `CLAUDE.md` boilerplate vs. user content.** Template headings classified:

- *Workflow boilerplate, superseded by the plugins:* `## General` (ticket
  numbering script instructions, TODO-file conventions), `## Git Commit
  Discipline` (references `./scripts/ticket.sh`; never-amend/never-push rules
  now in tce), `## Implementation Phase Discipline` (now
  `/tce:implement_plan`), parts of `## Communication` (commit style, now in
  tce conventions).
- *Project-specific, keep (or fold into `.claude/tce/profile.md` during init
  analysis):* `# [Your Project Name]`, `## Architecture Overview` (+
  subsections), `## Development Environment` (+ subsections), `## CRITICAL:
  Reusing and Extending Existing Code`, `## Component-Specific Documentation`.

**d) Prefix harvesting.** All five scripts carry the identical block
`TICKET_PREFIX="PROJ"  # Change this to your project's prefix…` — the value
(possibly differing across scripts if the user was sloppy) is what `/tmt:init`
should harvest and propose, alongside its existing tier-1 source (existing
ticket filenames, which is the more reliable signal and already first
priority).

**e) No template versioning, user-edited files.** The repo has zero tags/
releases; README Quick Start explicitly instructs editing the copied files
(replace `[PREFIX]-XXXX` with the real prefix in command files, customize
`commit.md`/`discuss.md`/CLAUDE.md/settings). Consequences: (i) a template
"version" cannot be detected; (ii) content hashes won't match a pristine
template — **fingerprinting must be presence-based** (e.g.
`scripts/next-ticket.sh` + `.claude/commands/research_codebase.md` +
`thoughts/shared/tickets/` is a strong template signature; the
`TICKET_PREFIX="…"` assignment pattern in root scripts confirms); (iii) the
exact-list-then-confirm deletion UX from the ticket is the safety net for
user-modified copies — there is no reliable way to auto-distinguish pristine
from edited files, except for `design-system.md`, whose placeholder strings
("Replace this with your project's actual design system tokens.", "Document
your font stack here.", …) do reliably mark an untouched skeleton.
- Minor: template's `validate-ticket-status.sh` references a
  `thoughts/shared/tickets/CLAUDE.md` not present in the template tree; real
  installs may or may not have one — leave it alone (it's under the
  untouchable `thoughts/shared/`).

### 4. Claude Code platform facts

- `${CLAUDE_PLUGIN_ROOT}` is substituted in skill/command content, agent
  content, hook commands, and MCP/LSP configs, and exported to hook
  processes. Marketplace plugins are copied to `~/.claude/plugins/cache`
  including `.claude-plugin/plugin.json`, so reading the own version at
  runtime is legitimate. The install directory name also encodes the version.
- **No plugin install/enable/update hook event exists.** The hook event list
  has grown considerably (now includes `Setup`, `InstructionsLoaded`,
  `ConfigChange`, `FileChanged`, `PostCompact`, etc.), but none is an install
  trigger — the repo CLAUDE.md's conclusion stands (its event list is merely
  outdated). `userConfig` remains the only enable-time mechanism.
- `${CLAUDE_PLUGIN_DATA}` (`~/.claude/plugins/data/<id>/`, survives updates,
  deleted on last-scope uninstall) is the documented home for plugin state,
  with a documented SessionStart pattern: diff a bundled file against a copy
  in the data dir to detect first-run/update. **But it is per-user, not
  per-project** — per-project migration state belongs in the project config,
  consistent with this repo's core design rule (the same reasoning that
  rejected `userConfig` for `TICKET_PREFIX`).
- Plugin update flow: explicit `version` in `plugin.json` pins until bumped;
  consumers update via `/plugin marketplace update`; a mid-session update
  keeps hooks on the old path until `/reload-plugins`.

### 5. Contracts and conventions that bind this change

- **TP-0001:** all AskUserQuestion dialog copy in init commands is verbatim,
  reviewed prose — new migration dialogs must be written out in the command
  text, not improvised. The guidelines block is byte-identical across six
  files; editing it requires syncing all six in one commit.
- **TP-0002:** all command references use installed prefixed names
  (`/tce:*`, `/tmt:*`) — applies to all new nudge/dialog/cleanup text.
- **Core design rule:** plugins stay project-agnostic; coordinate only via
  project config files; never call into each other; tmt owns the ticket
  envelope. "Never edit the other plugin's files" (tmt init.md:125).
- **Composite-command sync rule:** `work.md`/`quickfix.md` mirror the
  single-step commands — but neither mirrors `init.md`, so init changes don't
  trigger that rule. (Verify at implementation time if any shared block —
  e.g. the guidelines block — is touched.)
- Both inits: no writes before confirmation, no auto-commit, config files are
  meant to be committed.
- README/docs drift rule: nudge wording changes go to `check-init.sh`, the
  `userConfig` description, and `plugins/tce/README.md` together; tmt's
  README documents the legacy migration story (`plugins/tmt/README.md:64-66`)
  and will need the template story added.

## Code References

- `plugins/tce/commands/init.md:102-117` — Phase 1 detection probes (legacy config, existing setup)
- `plugins/tce/commands/init.md:226-238` — Phase 3 tmt hand-off ping-pong
- `plugins/tce/commands/init.md:315-326` — Idempotency + advisory-only legacy paragraph
- `plugins/tce/commands/init.md:330-331` — "never edits `.claude/settings.json`"
- `plugins/tmt/commands/init.md:57-71` — prefix derivation priority order (legacy adoption at 64–67)
- `plugins/tmt/commands/init.md:90-93` — "Migrated from legacy…" dialog provenance
- `plugins/tmt/commands/init.md:122-125` — existing Legacy cleanup step
- `plugins/tce/scripts/check-init.sh:42-54` — userConfig gate + profile.md guard (extension point)
- `plugins/tce/scripts/check-init.sh:75-85` — reusable jq-free JSON emission tail
- `plugins/tmt/scripts/lib.sh:22-35` — `tmt_ticket_prefix()` with legacy fallback (line 25)
- `plugins/tmt/templates/tmt/config` — sourced KEY=VALUE format (version-key-ready)
- `plugins/tce/.claude-plugin/plugin.json:3` — tce version 2.0.0; `plugins/tmt/.claude-plugin/plugin.json:3` — tmt 1.0.0

## Open Questions

Design decisions research could not resolve (multiple valid approaches):

1. **Where does tce's version marker live?** `.claude/tce/` is prose-only.
   Options: (a) HTML comment in `profile.md` (e.g. `<!-- tce-config-version:
   2.0.0 -->`; no new file, greppable, precedent in tickets.md) — leans
   recommended; (b) a new dedicated machine-readable file (must not be named
   `config`). tmt's side is settled by format: a `KEY=VALUE` line in
   `.claude/tmt/config`.
2. **May migration edit `.claude/settings.json`?** The template's PostToolUse
   hooks double-fire with tmt's and break when `scripts/` is deleted, so
   leaving them is actively harmful — but both commands currently promise
   never to touch settings.json. Options: (a) relax the invariant for
   migration only, propose-and-approve like CLAUDE.md; (b) keep the
   invariant, advise-only with exact manual instructions.
3. **How do cleanup duties split between the two inits?** Options: (a) each
   init removes the artifacts its own plugin supersedes (tmt: 4 ticket
   scripts + settings hooks; tce: commands, agents, `ticket.sh`, CLAUDE.md
   sections, design-system move) — respects ownership, two confirmations;
   (b) `/tce:init` as the guaranteed entry point (the nudge targets it)
   performs one full sweep — single confirmation, but tce deletes
   tmt-superseded files (which are template files, not tmt's, so the
   never-edit-other-plugin rule arguably doesn't apply).

Resolved by research (no user input needed): fingerprinting must be
presence-based (no template versions; user-edited files expected);
`design-system.md` pristine-vs-customized is detectable via placeholder
strings; version markers are read at init re-run time (per the ticket's
acceptance criteria), with check-init.sh optionally growing the same check
later; `${CLAUDE_PLUGIN_DATA}` is per-user and therefore not the home for
per-project migration state.
