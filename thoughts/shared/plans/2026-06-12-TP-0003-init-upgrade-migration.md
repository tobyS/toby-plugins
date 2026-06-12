# TP-0003: Init commands detect and migrate prior installs — Implementation Plan

**Date:** 2026-06-12
**Ticket:** `thoughts/shared/tickets/TP-0003-init-upgrade-migration.md`
**Research:** `thoughts/shared/research/2026-06-12-TP-0003-init-upgrade-migration.md`

## Overview

Teach `/tce:init` and `/tmt:init` to detect prior installs — the original
[claude-template](https://github.com/tobyS/claude-template) or an older plugin
version — and perform a confirmed migration; stamp a per-project version
marker so future inits can detect outdated config; make `check-init.sh`
recognize a template install and tailor its SessionStart nudge. Everything
under `thoughts/shared/` is never touched; clean projects see no new behavior.

**Decisions from the question checkpoint** (all recommended options):

1. tce's version marker is an HTML comment in `.claude/tce/profile.md`
   (`<!-- tce-config-version: X.Y.Z -->`); tmt's is a `TMT_CONFIG_VERSION=`
   key in `.claude/tmt/config`.
2. Migration MAY edit `.claude/settings.json` — propose-and-approve only, and
   only to remove the template's two PostToolUse hook entries; everything
   else in the file stays byte-identical.
3. Cleanup duties split by successor ownership: `/tmt:init` removes what tmt
   supersedes (4 ticket scripts, the settings hooks, `create_ticket.md`);
   `/tce:init` removes what tce supersedes (7 commands, 6 agents,
   `ticket.sh`, CLAUDE.md workflow sections, design-system relocation).

## Current State Analysis

(Full detail in the research doc.)

- Both inits are "analyze → propose via AskUserQuestion → confirm → write"
  with a no-writes-before-confirmation gate and an Idempotency section.
  Dialog copy is a verbatim contract (TP-0001); command references use
  prefixed names (TP-0002).
- `/tmt:init` already migrates the legacy `.claude/tce/config` prefix
  (detect at `init.md:64-67`, provenance string at `:90-93`, cleanup advice
  at `:122-125`). `/tce:init` only detects it (`init.md:105-107`) and
  redirects (`:322-326`). Neither knows the claude-template.
- The template footprint: 8 un-namespaced `.claude/commands/*.md`, 6
  `.claude/agents/*.md` (names match tce's), 5 root `scripts/*.sh` each
  hardcoding `TICKET_PREFIX="…"`, 4 workflow-boilerplate CLAUDE.md sections,
  placeholder `.claude/references/design-system.md`, and `.claude/settings.json`
  whose two PostToolUse hooks duplicate tmt's shipped hooks (double-fire now,
  hard-fail once `scripts/` is deleted). No tags/releases; users were told to
  edit copied files → detection must be presence-based.
- `check-init.sh` is linear: userConfig gate (`:42-45`) → `profile.md` guard
  (`:50-54`) → fixed heredoc → jq-free awk-escape/JSON emit (`:75-85`).
- `.claude/tmt/config` is sourced shell — unknown `KEY=VALUE` lines are inert
  to `tmt_ticket_prefix()` (`plugins/tmt/scripts/lib.sh:22-35`). `.claude/tce/`
  is prose-only. The filename `.claude/tce/config` is burdened (legacy
  fallback still sources it) and must not be reused.
- Commands can read their own plugin version from
  `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` (tce 2.0.0, tmt 1.0.0).

## Desired End State

- In a template repo, the SessionStart nudge says a template install was
  detected and points at `/tce:init` to migrate; running the inits harvests
  the prefix, writes the plugin config, and (after listed, confirmed
  deletions and approved CLAUDE.md/settings.json edits) removes every
  superseded template artifact.
- In a repo with legacy `.claude/tce/config`, `/tmt:init` migrates the prefix
  (existing behavior) and now also offers to delete the legacy file itself.
- Both inits stamp version markers; re-running with a matching version
  reports "already up to date"; an older marker triggers an upgrade review.
- `thoughts/shared/` untouched in all paths; clean projects: zero new
  prompts.

### Verification

- Automated: `claude plugin validate` ×3; `check-init.sh` smoke tests against
  fake project dirs (template footprint / clean / initialized); sourcing a
  config containing `TMT_CONFIG_VERSION` leaves all tmt scripts working.
- Manual: read-through of all new verbatim dialog copy; consistency of the
  tce↔tmt hand-off ping-pong; README/CLAUDE.md accuracy.

## What We Are NOT Doing

- No downgrades; no automatic/unconfirmed migration (hooks only advise).
- Not porting user customizations of template command/agent content — the
  confirmed deletion list is the safety net; users keep them via git history.
- Not touching `alwaysThinkingEnabled`, the osascript Notification/Stop
  hooks, `.gitignore`, `.claude/settings.local.json`, or anything under
  `thoughts/shared/` (including a stray `thoughts/shared/tickets/CLAUDE.md`).
- Not editing the AskUserQuestion guidelines block (six-copy sync rule not
  triggered) and not changing `work.md`/`quickfix.md` (they don't mirror
  `init.md`).
- No version bumps / release tagging in this ticket (human decides releases;
  the marker mechanism reads whatever version is installed).
- No `${CLAUDE_PLUGIN_DATA}` usage — per-user, wrong scope for per-project
  state.

## Implementation Approach

Four phases, each independently committable. Command-text changes are
surgical insertions into the existing phase structure (preserve altitude; new
dialog copy is written out verbatim per the TP-0001 contract, using prefixed
command names per TP-0002). Detection is presence-based fingerprinting; all
destructive steps live in the existing post-confirmation write phases.

**Template fingerprint** (shared definition, used by both inits and
check-init.sh — "template install" means at least one un-namespaced workflow
artifact is present; the *strong* signature for the nudge is
`scripts/next-ticket.sh` + `.claude/commands/research_codebase.md`):

- tce-superseded: `.claude/commands/{research_codebase,create_plan,implement_plan,commit,code_review,design_explore,discuss}.md`,
  `.claude/agents/{codebase-analyzer,codebase-locator,codebase-pattern-finder,thoughts-analyzer,thoughts-locator,web-search-researcher}.md`,
  `scripts/ticket.sh`, `.claude/references/design-system.md`, CLAUDE.md
  sections `## General` (ticket-numbering paragraph), `## Git Commit
  Discipline`, `## Implementation Phase Discipline`.
- tmt-superseded: `scripts/{next-ticket,open_tickets,check-ticket-status,validate-ticket-status}.sh`,
  `.claude/commands/create_ticket.md`, the two PostToolUse entries in
  `.claude/settings.json` whose commands reference
  `scripts/check-ticket-status.sh` / `scripts/validate-ticket-status.sh`.

## Phase 1: Version markers

### Changes Required

1. **`plugins/tmt/templates/tmt/config`** — add below `TICKET_PREFIX=`:
   a comment line (`# Plugin version that last wrote this file — used by
   /tmt:init to detect upgrades. Do not edit by hand.`) and
   `TMT_CONFIG_VERSION=`.
2. **`plugins/tce/templates/tce/profile.md`** — add as the first line:
   `<!-- tce-config-version: FILLED-BY-INIT -->` (HTML comment; invisible in
   rendered markdown, greppable).
3. **`plugins/tmt/commands/init.md`**:
   - Phase 3 step 1 (write config): after filling `TICKET_PREFIX=`, fill
     `TMT_CONFIG_VERSION=` with the version read from
     `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
   - Idempotency section: read `TMT_CONFIG_VERSION` from the existing config.
     Same as installed version → report "tmt config is already up to date
     (vX.Y.Z)" alongside the existing show-and-ask behavior. Older or missing
     → say the config was written by an older tmt (or predates version
     markers), apply any config changes the newer version requires (none
     besides adding the marker itself today), and update the marker — still
     ask before writing, per the global gate.
4. **`plugins/tce/commands/init.md`**:
   - Phase 4 step 2 (fill profile.md): fill the version comment with the
     version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.
   - Idempotency section: same compare/report/update logic against the
     `tce-config-version` comment; a `profile.md` without the comment is a
     pre-marker install — offer to stamp it during the review-and-amend pass.

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate .`, `claude plugin validate ./plugins/tce`,
      `claude plugin validate ./plugins/tmt` pass
- [x] `grep -n "TMT_CONFIG_VERSION" plugins/tmt/templates/tmt/config` and
      `grep -n "tce-config-version" plugins/tce/templates/tce/profile.md` hit
- [x] Fake project (`/tmp/fakeproj` with `.claude/tmt/config` containing
      `TICKET_PREFIX=FAKE` + `TMT_CONFIG_VERSION=0.9.0` and
      `thoughts/shared/tickets/`):
      `CLAUDE_PROJECT_DIR=/tmp/fakeproj plugins/tmt/scripts/next-ticket.sh`
      prints `FAKE-0001` (unknown key inert)

#### Manual Verification

- [x] Both Idempotency sections read naturally and keep the existing
      don't-clobber / prefix-change-warning behavior intact

## Phase 2: `/tmt:init` — template detection & migration

### Changes Required

All in **`plugins/tmt/commands/init.md`**:

1. **Phase 1 (Analyze)** — extend the prefix-derivation priority list with a
   new tier between existing tickets and legacy config:
   1. existing ticket filenames (unchanged, most reliable)
   2. *new:* `TICKET_PREFIX="…"` assignments in root `scripts/*.sh`
      (the template's config block; note values could differ across the five
      scripts — if they do, prefer the `next-ticket.sh` value and mention the
      discrepancy in the dialog description)
   3. legacy `.claude/tce/config` (unchanged)
   4. fresh derivation (unchanged)
   Also record which tmt-superseded template artifacts exist (fingerprint
   list above), for Phase 3 cleanup.
2. **Phase 2 (Propose)** — add a third canned provenance string for the
   prefix dialog: "Harvested from the template's scripts/*.sh." (verbatim
   copy, joins the existing two).
3. **Phase 3 (Write)** — extend step 3 ("Legacy cleanup") into a general
   **Superseded-install cleanup** step with verbatim dialog copy:
   - If template artifacts were detected: list exactly the files to delete
     (the tmt-superseded set that actually exists), then one dialog —
     question "Remove the superseded template files listed above?", header
     "Cleanup", options "Remove them (Recommended)" (description: tmt's
     shipped scripts and hooks replace them; git history preserves the
     files) / "Keep them" (description: they stay and may double-fire with
     tmt's hooks until removed manually). Delete on approval; remove
     `scripts/` only if empty afterwards.
   - If `.claude/settings.json` contains the two template PostToolUse
     entries: show the exact entries, then a dialog — question "Remove these
     two hook entries from .claude/settings.json?", header "Settings",
     options "Remove the two entries (Recommended)" (description: they
     duplicate tmt's shipped hooks and will fail once scripts/ is deleted)
     / "Leave settings.json untouched" (description: print the manual
     removal instructions instead). On approval edit surgically: only those
     two array entries; all other keys byte-identical.
   - Legacy `.claude/tce/config` case: upgrade the existing advice into an
     offer — same Cleanup dialog pattern, deleting the file on approval
     (supersedes "Do not edit tce's files yourself" for this one file; the
     value has been migrated into `.claude/tmt/config` at that point).
4. **Notes section** — qualify the "never edits `.claude/settings.json`"
   claim: "except the migration cleanup step, which removes the template's
   two hook entries after explicit approval".

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .` / `./plugins/tce` / `./plugins/tmt` pass
- [ ] `grep -n "Harvested from the template" plugins/tmt/commands/init.md`
      hits (provenance string present)

#### Manual Verification

- [ ] New dialog copy follows the guidelines block (intro before tool,
      recommended-first, plain text, headers ≤12 chars)
- [ ] Priority order reads unambiguously; existing tiers unchanged
- [ ] The no-writes-before-confirmation gate still holds for every new action

## Phase 3: `/tce:init` — template detection & migration

### Changes Required

All in **`plugins/tce/commands/init.md`**:

1. **Phase 1 (Analyze)** — add probe item: detect tce-superseded template
   artifacts (fingerprint list) regardless of whether `.claude/tce/` exists
   (covers partially-migrated projects). For CLAUDE.md, identify the
   boilerplate sections by heading (`## General` ticket-numbering paragraph,
   `## Git Commit Discipline`, `## Implementation Phase Discipline`) — treat
   them as candidates only; the user approves each edit.
   For `.claude/references/design-system.md`: classify pristine (contains the
   template's placeholder strings, e.g. "Replace this with your project's
   actual design system tokens.") vs customized.
2. **Phase 2 (Propose)** — when template artifacts were detected, the
   proposal block gains a "Template install detected" subsection listing:
   files to delete, CLAUDE.md sections proposed for removal, the
   design-system plan (pristine → delete, offer the optional tce template
   instead; customized → move to `.claude/tce/design-system.md`). The
   ticket-system dialog's detection reasoning mentions the template when it
   is the prefix source.
3. **Phase 4 (Write)** — add a **Template cleanup** step after the existing
   steps, with verbatim dialog copy:
   - One dialog — question "Remove the superseded template files listed
     above?", header "Cleanup", options "Remove them (Recommended)"
     (description: the tce plugin's commands and agents replace them; git
     history preserves the files) / "Keep them" (description: the
     un-namespaced commands keep appearing alongside the /tce:* versions).
     On approval delete the listed files; remove `.claude/commands/`,
     `.claude/agents/`, `.claude/references/`, `scripts/` only if empty.
   - CLAUDE.md: present each proposed section removal/replacement as a
     concrete diff-style proposal and apply only the ones the user approves
     (free-form approval, not a 4-option dialog — the set is variable).
   - design-system.md: pristine → delete with the cleanup batch; customized
     → move (`git mv` semantics) to `.claude/tce/design-system.md` and skip
     the template copy for it in step 4.
4. **Phase 4 step 5 (hand-off summary)** — report migration results
   (deleted/kept/moved, CLAUDE.md edits applied).
5. **Idempotency / "Legacy projects"** (lines 315–326) — extend: legacy
   paragraph keeps redirecting prefix migration to `/tmt:init`; add that
   template leftovers are detected and cleaned on re-run too (re-run =
   review, amend, and finish any incomplete migration).
6. **Notes section** — same settings.json qualification as tmt's? **No** —
   settings.json cleanup is tmt's duty (the hooks reference tmt-superseded
   scripts); tce's note stays absolute. Instead add: template migration never
   touches `thoughts/shared/`.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .` / `./plugins/tce` / `./plugins/tmt` pass
- [ ] `grep -n "Template install detected" plugins/tce/commands/init.md` hits

#### Manual Verification

- [ ] Cleanup-duty split is consistent: no file appears in both inits'
      deletion lists; union covers the full fingerprint
- [ ] The tce↔tmt hand-off ping-pong still reads coherently for the template
      case (tce detects → sends to /tmt:init → returns → tce finishes)
- [ ] All new dialog copy follows the guidelines block; prefixed command
      names throughout (TP-0002)

## Phase 4: `check-init.sh` nudge + documentation

### Changes Required

1. **`plugins/tce/scripts/check-init.sh`** — between the userConfig gate and
   the JSON emission:
   - Keep the `profile.md` guard (initialized → silent exit, unchanged).
   - If not initialized, probe the strong template signature
     (`[ -f "$ROOT/scripts/next-ticket.sh" ] && [ -f "$ROOT/.claude/commands/research_codebase.md" ]`).
   - Select between two heredocs: the existing generic nudge, or a new
     template-tailored one ("This project contains an install of the original
     claude-template… `/tce:init` can migrate it to the plugins: it harvests
     your ticket prefix, writes the plugin config, and removes the superseded
     files after confirmation. Offer to run `/tce:init`."). The awk-escape +
     emit tail stays shared and unchanged.
2. **`plugins/tce/README.md`** — document the tailored nudge and the
   template migration path (per the drift rule: nudge wording lives in
   check-init.sh + userConfig description + README together; the userConfig
   `description` in `plugin.json` needs no change — enable-time greeting is
   state-agnostic — but verify its wording still fits).
3. **`plugins/tmt/README.md`** — extend the migration section (`:64-66`) with
   the template story (prefix harvesting, script/hook cleanup, settings.json
   edit-on-approval).
4. **Repo `CLAUDE.md`** — update the "Prompting `/tce:init`" section
   (check-init.sh now has two nudge variants) and add a short "Migrations &
   version markers" note: marker locations/format, the fingerprint
   definition, the duty split, and the rule that new config-affecting
   changes must extend the inits' upgrade sections.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .` / `./plugins/tce` / `./plugins/tmt` pass
- [ ] Template fake project (`/tmp/tplproj` with `scripts/next-ticket.sh`,
      `.claude/commands/research_codebase.md`, no `.claude/tce/`):
      `CLAUDE_PROJECT_DIR=/tmp/tplproj plugins/tce/scripts/check-init.sh true`
      emits JSON whose additionalContext mentions the template
- [ ] Clean fake project: same call emits the generic nudge (unchanged text)
- [ ] Initialized fake project (with `.claude/tce/profile.md`): silent exit 0
- [ ] `plugins/tce/scripts/check-init.sh false`-style gate still silent:
      first arg `false` → no output in all three fixtures

#### Manual Verification

- [ ] Both heredoc texts use prefixed command names and read well
- [ ] README/CLAUDE.md sections accurate against the implemented behavior

## Testing Strategy

This repo has no test suite; per `profile.md` the checks are the three
`claude plugin validate` runs plus script smoke tests against throwaway
project dirs (`CLAUDE_PROJECT_DIR=/tmp/...`). Phases 2–3 are prompt-text
changes verified by validation + careful read-through; Phase 4's script
change gets the three-fixture smoke test above. End-to-end (install plugins
into a scratch clone of the actual claude-template and run both inits) is
recommended before release but is a manual, out-of-session step.

## References

- Ticket: `thoughts/shared/tickets/TP-0003-init-upgrade-migration.md`
- Research: `thoughts/shared/research/2026-06-12-TP-0003-init-upgrade-migration.md`
- Template inventory: https://github.com/tobyS/claude-template
- TP-0001 dialog-copy contract; TP-0002 prefixed-names contract
- Repo `CLAUDE.md`: core design rule, drift rule for nudge wording
