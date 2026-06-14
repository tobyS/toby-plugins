# TP-0004: Detect and refresh a stale project profile (`/tce:refresh`)

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-06-13
**Updated:** 2026-06-13

## Problem Statement

The tce workflow reads `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` at runtime —
tech stack, build/test/lint commands, the code map, conventions, and preferred
research sources. `/tce:init` seeds and fills this file, after which it is meant to
be kept accurate by hand.

In practice the profile drifts from reality: a project adds or swaps a framework,
changes its package manager, moves directories, or adds a test suite, and the
profile silently goes stale. The commands and research agents then operate on wrong
information, degrading every downstream step. There is currently no mechanism to
detect this drift or to bring the profile back in line short of the user remembering
to edit it (or re-running the full `/tce:init`).

## Desired Outcome

When this ticket is complete:

- There is a dedicated command that re-analyzes the repository and **proposes a
  reviewable diff** to `profile.md`, writing only after the user approves, and
  preserving hand-authored content rather than clobbering it.
- `/tce:research_codebase` — which already researches the codebase — notices when the
  profile contradicts what it observes and **advises** the user to run that command,
  without itself modifying the profile and without blocking the research.
- The command is named generically so it can grow to cover other generated tce docs
  later (not just `profile.md`).

## User Stories / Use Cases

- As a developer whose project's stack/layout has changed, I want tce to tell me my
  profile looks stale so that the workflow stops working off wrong information.
- As a developer, I want to run a single command that re-reads my repo and shows me
  exactly what it would change in the profile so that I can approve an accurate
  update without losing my hand-written conventions.
- As a developer running `/tce:research_codebase` (or `/tce:work` / `/tce:quickfix`),
  I want drift surfaced as part of work I'm already doing so that keeping the profile
  current costs me almost nothing.

## Acceptance Criteria

- [ ] A new command **`/tce:refresh`** exists. The name is deliberately generic (not
      `update_profile`, not `update`) so it can later cover other generated tce docs;
      this ticket scopes it to `profile.md` only.
- [ ] `/tce:refresh` re-analyzes the repository, compares the findings against the
      current `profile.md`, and presents the proposed changes as a **reviewable diff**.
- [ ] `/tce:refresh` writes `profile.md` **only after the user approves**; on decline
      it changes nothing.
- [ ] Hand-authored sections (at minimum **Conventions** and **Preferred research
      sources**) are preserved — the command asks before changing them rather than
      overwriting. Factual sections (tech stack, commands, code map) are the primary
      refresh target.
- [ ] After writing, the `<!-- tce-config-version: X.Y.Z -->` marker on line 1 of
      `profile.md` remains correct/consistent with the existing version-marker scheme.
- [ ] `/tce:research_codebase` compares observed repository reality against
      `profile.md` during its normal run and, when it detects drift (e.g. stack,
      commands, or code-map mismatch), surfaces a **clear, advisory note**
      recommending the user run `/tce:refresh`.
- [ ] The drift note is **non-blocking**: research completes and produces its normal
      output regardless.
- [ ] `/tce:research_codebase` never edits `profile.md` itself.
- [ ] Because `work.md` and `quickfix.md` chain `research_codebase`, the drift-check
      behavior is reflected in those composite commands too, per the
      composite-command sync rule in the repo's CLAUDE.md.
- [ ] No project-specific literals (stack names, paths, commands) are hardcoded in the
      new/changed commands — they read project state as the existing commands do
      (project-agnostic design rule).

## Out of Scope

- **Fully automatic, unprompted rewriting** of `profile.md` (the update is always
  proposed and approved).
- **Session-start drift detection** (e.g. extending `check-init.sh`). Detection is
  intentionally tied to `research_codebase`, which already reads the codebase.
- **Drift detection for files other than `profile.md`** (e.g. `tickets.md`,
  `design-system.md`, `.claude/tmt/config`). `/tce:refresh` is named to allow this
  later, but covering other docs is a separate ticket.
- Detecting drift inside other tce commands (`create_plan`, `implement_plan`,
  `commit`, etc.).
- A hook that auto-runs the command (hooks cannot execute slash commands anyway).

## Open Questions

_None — business/product scope is settled (see Notes & Updates)._

## Questions for Research/Planning

- [ ] **New command vs. extension of `/tce:init`.** `/tce:init` is already idempotent
      and has an upgrade/version-marker path. Should `/tce:refresh` be a standalone
      command, or share/reuse init's repo-analysis logic (and how, given the two must
      not drift)? Decide where the shared analysis lives.
- [ ] **Drift-detection signals.** What cheap, reliable signals should
      `research_codebase` (and `/tce:refresh`) use to judge staleness — manifest/lock
      files (`package.json`, `composer.json`, lockfiles), directory structure, test
      config — versus the facts recorded in `profile.md`? How to keep false positives
      low so the nudge stays trustworthy.
- [ ] **Diff presentation & approval UX.** How to show the proposed changes and gate
      writing (inline diff + confirmation, AskUserQuestion, per-section approval?),
      consistent with existing tce dialog guidelines.
- [ ] **Preserving manual sections.** Mechanics of refreshing factual sections while
      leaving Conventions / Preferred research sources intact unless approved.
- [ ] **Avoiding command drift.** If init's analysis logic is reused, how to structure
      it so `/tce:init` and `/tce:refresh` stay in sync (and whether the composite
      commands need any further updates beyond the chained research note).

## References

- `plugins/tce/templates/tce/profile.md` — profile structure (source of truth).
- `plugins/tce/commands/init.md` — existing seed/idempotency/version-marker logic.
- `plugins/tce/scripts/check-init.sh` — existing project-state-aware nudge precedent.
- `plugins/tce/commands/research_codebase.md`, `work.md`, `quickfix.md` — drift-check
  integration points (composite-command sync rule in `CLAUDE.md`).
- TP-0003 — version markers and config-versioning groundwork.

## Implementation Plan

[Leave empty - will be filled when plan is created]

## Notes & Updates

### 2026-06-13

Key decisions from the creation discussion:

- **Trigger:** nudge + user-run command (no silent auto-rewrite).
- **Detection moment:** inside `/tce:research_codebase` specifically, because it
  already performs codebase research; it scans for profile drift and recommends the
  refresh command when it finds any. Explicitly *not* session-start.
- **Update behavior:** re-analyze and propose a diff; write only on approval; preserve
  hand-customized sections.
- **Naming:** `/tce:refresh` (chosen over `update_profile` / `update` — the latter
  reads like updating the plugin itself). Generic on purpose so it can cover more
  generated docs in future; this ticket keeps it scoped to `profile.md`.
- Complexity Medium: two coordinated touch points (new command + research-phase
  detection) plus the composite-command sync obligations, but no new infrastructure.
