---
date: 2026-06-14
ticket: TP-0004
topic: "Detect and refresh a stale project profile (/tce:refresh)"
status: ready
research: thoughts/shared/research/2026-06-14-TP-0004-profile-drift-refresh.md
---

# Implementation Plan: Profile-drift detection and `/tce:refresh` (TP-0004)

## Overview

Add a new **`/tce:refresh`** command to the tce plugin that re-analyzes the consuming
project, compares the findings against `.claude/tce/profile.md`, and applies approved
changes **per section** (preserving hand-authored Conventions / Preferred research
sources), keeping the `tce-config-version` marker correct. Separately, fold a
**non-blocking, high-confidence drift advisory** into `/tce:research_codebase` and mirror
it into the composite `work.md` / `quickfix.md`, where it surfaces both in the written
research document and in a human-visible spot (work's Phase 2 intro, quickfix's Phase 6
summary).

This is entirely markdown-prompt + docs work — **no scripts, no new file formats, no new
infrastructure.** The constraints are the repo's sync contracts (composite commands, the
duplicated dialog block, the version-marker convention) and the project-agnostic design
rule.

## Decisions (from the TP-0004 question checkpoint)

1. **Standalone command + sync note** — `/tce:refresh` describes its re-analysis in its
   own words; a CLAUDE.md rule ties it to init's Phase 1 so they don't drift.
2. **Per-section approval** — show before/after per changed section, approve per section;
   factual sections refresh, manual sections stay untouched unless opted in.
3. **Doc + visible echo** — drift advisory always in the research document, plus echoed in
   work's Phase 2 checkpoint intro and quickfix's Phase 6 final summary.
4. **High-confidence only** — advise only on concrete mismatches (manifest/lockfile shows
   a stack the profile omits; a profile test/lint command no longer exists; a code-map
   directory is gone/moved). Soft wording, never blocking.

## Current state

- `plugins/tce/commands/init.md` owns the repo-analysis routine (Phase 1, `:71-136`), the
  profile write + version stamp (Phase 4, `:278-296`), and the idempotency / version-marker
  "show what differs, ask before writing, don't clobber" posture (`:400-416`).
- Version marker `<!-- tce-config-version: X.Y.Z -->` lives on line 1 of `profile.md`;
  version source is `plugins/tce/.claude-plugin/plugin.json` `version` (`2.0.0`). All
  marker handling is prose-driven — no shell helper.
- `research_codebase.md` reads the profile once as guidance (`:14`); it has no drift
  concept and a strict documentarian block (`:58-66`). `work.md` Phase 1 (`:77-90`) and
  `quickfix.md` Phase 3 (`:179-187`) mirror the research flow and are bound by lock-step
  clauses (`work.md:22`, `quickfix.md:22`).
- The "AskUserQuestion dialog guidelines" block is duplicated byte-identically in six
  files; CLAUDE.md mandates they stay identical.

## Desired end state

- `plugins/tce/commands/refresh.md` exists and works as decided.
- `research_codebase.md`, `work.md`, `quickfix.md` carry the drift advisory consistently.
- CLAUDE.md and `plugins/tce/README.md` document the new command, the sync note, and the
  expanded (seven-file) dialog-block contract.
- `claude plugin validate ./plugins/tce` and `claude plugin validate .` pass; the seven
  dialog-block copies are byte-identical; no project-specific literals in the new/changed
  commands.

---

## Phase 1: Create the `/tce:refresh` command

**File:** `plugins/tce/commands/refresh.md` (new)

Follow the command skeleton (`commit.md`/`discuss.md` conventions):

1. **Frontmatter** — `description:` only (no `argument-hint`; refresh takes no argument).
   Description e.g.: "Re-analyze the project and reconcile `.claude/tce/profile.md` with
   it — proposes per-section changes, writes only what you approve."
2. **Title + one-sentence task** — `# Refresh Project Config` (or similar), then a single
   sentence stating it reconciles the tce project docs with the current repo.
3. **`## Project context`** — ships in tce, stack-agnostic; read
   `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`; if it's missing, tell the user to run
   `/tce:init` (refresh updates an existing profile, it does not create one). State the
   scope explicitly: **this command currently reconciles `profile.md` only**; the name is
   generic so it can grow to cover other generated tce docs later (out of scope here).
4. **`### AskUserQuestion dialog guidelines`** — paste the byte-identical block (copy from
   `research_codebase.md:18-36`). This becomes the **seventh** copy.
5. **Body — the reconcile flow:**
   - **Re-analyze** the repo in refresh's own words (mirroring init Phase 1's targets:
     stack & tooling from manifests/lockfiles; test/typecheck/lint commands; code-map
     layout). Describe doing it directly with Glob/Grep/Read/Bash, spawning research
     subagents only if the project is large/unclear — matching init's altitude. Add the
     CLAUDE.md sync pointer in a comment-style note (see Phase 4).
   - **Compare** the analysis against the existing `profile.md`, section by section:
     factual sections = **Tech stack, Commands, Code map** (primary refresh targets);
     hand-authored sections = **Conventions, Preferred research sources** (preserved).
   - **Propose per section**: for each section with a concrete, high-confidence difference,
     show a before/after (fenced block — no diff helper exists) and ask the user to approve
     that section's change. Use the dialog guidelines. Conventions / Preferred research
     sources are left untouched unless the user explicitly opts in to changing them.
   - **Version marker:** read the installed version from
     `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`; compare to the line-1
     `tce-config-version` comment. Same → leave as-is; older/missing → update the marker to
     the installed version as part of the write (mirror init `:407-416`).
   - **Write** only the approved section changes (Edit in place — never `cp` the skeleton,
     which would clobber manual content). **On decline of everything, change nothing** and
     say so.
   - If analysis finds **no** high-confidence differences, report "profile is already in
     sync (vX.Y.Z)" and exit without writing.
6. **`## Important`** — never clobber; preserve manual sections; ask before writing; never
   touch anything under `thoughts/`; no stack/ticket-system literals (read project state).

### Success criteria

#### Automated
- [ ] `claude plugin validate ./plugins/tce` passes.
- [ ] `claude plugin validate .` passes.
- [ ] The dialog block in `refresh.md` is byte-identical to the other six (diff check, see
      Phase 5).

#### Manual
- [ ] `refresh.md` frontmatter matches convention (description, no argument-hint).
- [ ] No project-specific literals (stack names, paths beyond the standard
      `${CLAUDE_PROJECT_DIR}`/`${CLAUDE_PLUGIN_ROOT}` vars, commands) appear in the file.
- [ ] The command preserves Conventions / Preferred research sources unless the user opts
      in; gates every write on approval; keeps the version marker correct.

---

## Phase 2: Add high-confidence drift detection to `/tce:research_codebase`

**File:** `plugins/tce/commands/research_codebase.md`

1. **Detection step** — insert after Step 4 (synthesis, `:201-211`) and before the write
   (Step 5/6): a new step that compares the just-gathered codebase reality against
   `profile.md` and identifies **high-confidence** drift only (manifest/lockfile shows a
   stack the profile omits; a profile test/lint command no longer exists; a code-map
   directory is gone/moved). Explicitly **read-only** — never edits the profile.
2. **Documentarian carve-out** — amend the block near `:58-66` (or add a one-line
   exception) so the `/tce:refresh` recommendation is the single sanctioned recommendation,
   coexisting with the "only describe what exists" rule.
3. **Surface in the document** — add a short, optional section to the Step 6 template
   (`:235-309`), placed near `## Open Questions` (`:307`), e.g. `## Profile Drift` — emitted
   only when drift was found, with the recommendation to run `/tce:refresh`.
4. **Surface in the presentation** — in Step 8 (`:319-328`), echo a one-line advisory next
   to the "Next command" line when drift was found ("Note: profile.md looks stale — consider
   `/tce:refresh`").
5. Wording must be **non-blocking**: research always completes and writes its document
   regardless.

### Success criteria

#### Automated
- [ ] `claude plugin validate ./plugins/tce` passes.

#### Manual
- [ ] Detection step sits after synthesis, before write; is read-only; flags only
      high-confidence drift.
- [ ] Advisory appears in both the document template (conditional section) and the Step 8
      presentation; nothing blocks research completion.
- [ ] The documentarian block still reads coherently with the carve-out.

---

## Phase 3: Mirror the drift behavior into the composite commands

**Files:** `plugins/tce/commands/work.md`, `plugins/tce/commands/quickfix.md`

Per the lock-step contracts (`work.md:22`, `quickfix.md:22`) — same commit as Phase 2.

1. **work.md Phase 1** (`:77-90`): add the detection step to the inline research-step list,
   between "Synthesize findings" and "Write the research document" (`:84-86`). Because
   Phase 1 suppresses presentation (`:96`), route the advisory into the **research document**
   and **echo it in the Phase 2 question-checkpoint intro** (`:100-169`) so the user sees it
   at the one interactive point.
2. **quickfix.md Phase 3** (`:179-187`): add the detection step between Spawn (`:185`) and
   Write (`:187`). Because quickfix is fully autonomous (`:185`), route the advisory into
   the **research document** and **echo it in the Phase 6 final-summary template**
   (`:243-267`).
3. Keep both mirrors high-confidence and non-blocking, matching Phase 2's wording.

### Success criteria

#### Automated
- [ ] `claude plugin validate ./plugins/tce` passes.

#### Manual
- [ ] work.md and quickfix.md each name the detection step explicitly (not left to the
      "follow all quality guidelines" catch-all).
- [ ] work's advisory echoes in the Phase 2 intro; quickfix's in the Phase 6 summary; both
      also write it to the research document.
- [ ] No interactive prompt is introduced into the autonomous phases.

---

## Phase 4: Documentation and sync contracts

**Files:** `CLAUDE.md`, `plugins/tce/README.md`, `plugins/tce/templates/tce/profile.md`

1. **CLAUDE.md:**
   - Add `refresh.md` to the layout list under `plugins/tce/commands/`.
   - **Dialog-block contract:** update "The AskUserQuestion guidelines block is
     duplicated…" to say **seven** files and add `refresh` to the enumerated list.
   - **Sync note (decision 1):** add a short rule that `/tce:refresh`'s re-analysis
     description must track `/tce:init`'s Phase 1 analysis targets — change both together.
   - Confirm the composite-command rule already covers the research→work/quickfix drift
     mirror (it does); add a clause only if wording needs it.
   - **Version marker:** note that `/tce:refresh` also stamps/maintains the
     `tce-config-version` marker (alongside init). No Idempotency upgrade-list change is
     needed because refresh does not change what `profile.md` must contain.
2. **plugins/tce/README.md:** document `/tce:refresh` in the command list/usage, and
   mention that `/tce:research_codebase` now advises when the profile looks stale.
3. **templates/tce/profile.md:** the header guidance currently says "update this file (or
   re-run `/tce:init`)" — extend to "(or run `/tce:refresh`)".

### Success criteria

#### Automated
- [ ] `claude plugin validate .` passes.

#### Manual
- [ ] CLAUDE.md reflects the new command, the seven-file dialog contract, and the init↔refresh
      sync note.
- [ ] README documents `/tce:refresh` and the research advisory.
- [ ] profile.md template header mentions `/tce:refresh`.

---

## Phase 5: Validation

1. Run the profile's test commands:
   - `claude plugin validate .`
   - `claude plugin validate ./plugins/tce`
   - `claude plugin validate ./plugins/tmt`
2. **Dialog-block parity:** extract the `### AskUserQuestion dialog guidelines` block
   (heading through its last bullet) from all **seven** files and confirm they are
   byte-identical.
3. **Project-agnostic check:** grep the new/changed command files for stack literals
   (`php artisan`, `bun`, framework names) and hardcoded project paths — there must be none.
4. **Self-dogfood smoke (optional):** mentally/manually walk `/tce:refresh` against this
   repo's own `profile.md` to confirm the flow reads sensibly (no execution needed — these
   are prompts).

### Success criteria

#### Automated
- [ ] All three `claude plugin validate` invocations pass.

#### Manual
- [ ] Seven dialog blocks byte-identical.
- [ ] No project-specific literals introduced.

---

## Testing strategy

The project has no runtime/test framework — "tests" are manifest validation
(`claude plugin validate`) plus structural review of the markdown contracts. Each phase
validates the affected plugin manifest; Phase 5 does the cross-file parity and
project-agnostic checks. Typecheck/lint: none (per profile).

## Notes

- **No plugin version bump in this plan** — versioning/tagging is a separate human-decided
  release step (CLAUDE.md "Releasing"); adding a command does not change required profile
  content, so no version-marker upgrade-list entry is required.
- **Out of scope (per ticket):** session-start drift detection, drift detection for files
  other than `profile.md`, a hook that auto-runs the command, fully-automatic rewrites.
