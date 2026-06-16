---
date: 2026-06-16
ticket: TP-0009
branch: main
commit: caddbfe
topic: "/tce:implement makes no intermediate commits"
status: ready
---

# Implementation Plan: /tce:implement intermediate commits (TP-0009)

## Overview

`/tce:implement` never instructs the agent to commit — it only reserves a passive
`### Commit` slot in the status file and a "record the hash *if* a commit was
made" rule. Make it commit in logical groups (per verified phase, finer when a
phase has independent units), delegating to `/tce:commit` (which already runs the
project's tests/typecheck/lint for code commits and formats the message per the
configured convention), and tighten the status-file language to expect a commit.
Then bring the two composites (`work.md`, `quickfix.md`) into exact lock-step.

## Current State

- `plugins/tce/commands/implement.md`: no `/tce:commit` reference; commits only
  appear as a status-file slot (116-118) and conditional record rules (131, 140);
  Verification Approach (208-219) and Final Verification (221-239) omit committing.
- `plugins/tce/commands/work.md:234`: already instructs per-phase commit via
  `/tce:commit`; reinforced at `:260`.
- `plugins/tce/commands/quickfix.md:185`: asserts implement "committing after each
  phase" — currently an unbacked claim.

## Desired End State

`implement.md` contains an explicit, imperative per-phase commit step that
delegates to `/tce:commit` (code commit → full pre-commit checklist), expresses
"logical groups" granularity, and folds in the ticket-status commit. The
status-file slot stops hedging. `work.md` and `quickfix.md` read as mirrors of
implement's behavior, not its source. No project-specific literals introduced.

### Verification (automated)

From `profile.md`:
- `claude plugin validate .`
- `claude plugin validate ./plugins/tce`
- `claude plugin validate ./plugins/tmt`

### Verification (manual)

- `implement.md` has a clear "commit after each verified phase via `/tce:commit`"
  instruction near the Verification Approach section.
- The status-file "if a commit was made" hedge is gone.
- `grep -n "tce:commit" plugins/tce/commands/implement.md` returns the new line(s).
- Re-reading `work.md` Phase 4 and `quickfix.md` Phase 5 against implement shows
  consistent wording (the composites describe, implement instructs).

## What We're NOT Doing

- Commit-frequency preference at init (TP-0010).
- Changing `/tce:commit` itself or the commit-convention mechanism (TP-0008).
- Changing the docs-only heuristic in `/tce:commit` (the repo-specific `.md`
  wrinkle noted in research is out of scope).

---

## Phase 1: Add the per-phase commit instruction to `implement.md`

Two edits in `plugins/tce/commands/implement.md`.

### 1a. Add a commit step to "Verification Approach"

The section (lines 208-219) ends with "Don't let verification interrupt your
flow - batch it at natural stopping points." Add a commit instruction so that a
verified phase is committed. Insert, after the existing bullet list and before/
around the "batch it" line, a step in the established work.md:234 idiom, expanded
into a short recipe:

- Commit each verified phase as its own logical commit (split finer when a phase
  contains independent units of work) using the `/tce:commit` workflow. Because
  these are code commits, `/tce:commit` runs the full pre-commit checklist
  (tests/typecheck/lint from `profile.md`) before committing — so a phase is only
  committed once its checks pass.
- Stage the files changed in the phase (plus the ticket file if its status
  changed — see "Ticket Status Transitions"); `/tce:commit` formats the message
  per the project's commit convention (e.g. `feat([PREFIX]-XXXX): <what the phase
  did>`).
- Record the resulting commit hash in the status file's `### Commit` slot.

Keep wording project-agnostic (no stack literals; `[PREFIX]-XXXX` placeholder).
Preserve the "batch it at natural stopping points" guidance — committing *is* the
natural stopping point.

### 1b. Tighten the status-file commit language

- Line 140 ("The commit hash **if a commit was made**"): change to expect a
  commit — e.g. "The commit hash for the phase's commit (see Verification
  Approach)."
- Optionally adjust the `### Commit` slot comment (116-118) so it reads as a
  required record, not an optional one. Keep the `abc1234` example.

### Success Criteria — Phase 1

#### Automated
- [ ] `claude plugin validate ./plugins/tce` passes

#### Manual
- [ ] `grep -n "tce:commit" plugins/tce/commands/implement.md` shows the new step
- [ ] No "if a commit was made" hedge remains
- [ ] No stack-specific literals added; `[PREFIX]-XXXX` used for IDs

---

## Phase 2: Reconcile the composites (`work.md`, `quickfix.md`)

Per the CLAUDE.md "Composite commands must track the single-step commands" rule,
verify and align — in the same commit as Phase 1 ideally, or the immediately
following one.

### 2a. `work.md`

- `:234` already says "Commit after each verified phase (using `/tce:commit` with
  full pre-commit checklist for code commits)". Confirm it still reads as a
  faithful mirror of implement's new step; adjust only if wording now conflicts
  (e.g. add the "logical groups / finer split" nuance if it improves consistency,
  but avoid gratuitous churn).
- `:258-260` Important Rule about commit points — confirm consistent.

### 2b. `quickfix.md`

- `:185` asserts the implement process runs "…committing after each phase". Now
  backed by implement; confirm wording is accurate and needs no change (or tighten
  to match implement's phrasing).

### Success Criteria — Phase 2

#### Automated
- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `claude plugin validate .` passes

#### Manual
- [ ] Reading implement.md, work.md, quickfix.md together, the per-phase commit
      behavior is described consistently (implement instructs; composites mirror)
- [ ] No new divergence introduced

---

## Testing Strategy

Markdown-only change to command prompts; "tests" are manifest validation. Run all
three `claude plugin validate` invocations. Manual review is the primary
verification: re-read the three command files for consistency and project-
agnosticism (no stack literals, placeholder IDs, preserved structure/altitude per
the repo's surgical-edit convention).

## References

- Research: `thoughts/shared/research/2026-06-16-TP-0009-implement-intermediate-commits.md`
- Ticket: `thoughts/shared/tickets/TP-0009-implement-intermediate-commits.md`
- `plugins/tce/commands/commit.md` (the workflow being delegated to)
- CLAUDE.md — composite-tracking rule; surgical-edit convention
