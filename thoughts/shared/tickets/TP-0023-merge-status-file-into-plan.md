# TP-0023: Merge implementation status tracking into the plan (drop .status.md)

**Status:** Done
**Estimated Complexity:** Small
**Created:** 2026-07-03
**Updated:** 2026-07-10

## Problem Statement

`/tce:implement` tracks progress in two places: checkboxes in the plan file and
a parallel `.status.md` file (same basename as the plan). The review flagged the
double bookkeeping as a drift risk; dogfooding experience since the status files
were introduced showed no observable improvement from the separate file — the
progress state already lives in the plan's checkboxes, and both documents are
read together at resume time anyway. Two sources of progress truth invite
exactly the divergence the convention was meant to prevent, and the
basename-pairing convention is one more thing every command (implement, work,
quickfix) and the README must describe.

## Desired Outcome

The plan file becomes the single record of implementation progress.
`/tce:implement` appends a compact, clearly demarcated per-phase
**implementation log** to the plan (phase status, commit hash, deviations or
issues and their resolutions, verification results) instead of maintaining a
separate `.status.md`. Resume logic — detecting a fully implemented plan,
continuing from the first incomplete phase — works from the plan alone. Log
entries stay terse (a few lines per phase), because the plan is re-read fully by
implement and on resume and must not bloat as context.

## User Stories / Use Cases

- As a tce user resuming an interrupted implementation, I want one document
  that tells me spec and progress together, so that resume needs no
  file-pairing convention.
- As a tce user, I want progress state that cannot drift from the plan's
  checkboxes, because they are the same document.
- As a teammate reading a finished ticket's trail, I want the plan to show what
  was planned and what actually happened (deviations, commits) in one place.

## Acceptance Criteria

- [ ] `implement.md` defines the in-plan log format: a clearly demarcated,
      per-phase block (e.g. `### Implementation log` under each phase) holding
      status, commit hash, issues → resolutions, and verification results —
      with explicit terseness guidance (a few lines, not prose journaling).
- [ ] `implement.md` no longer creates or writes `.status.md`; all Status File
      Tracking / Resuming Work sections are rewritten against the in-plan log.
- [ ] Resume behavior is preserved: detect "all phases complete" (stop and
      report), summarize done vs remaining, continue from the first incomplete
      phase — from the plan alone.
- [ ] Backward compatibility is decided in planning and implemented: an
      existing `.status.md` next to a plan is still read for resume (in-flight
      tickets), or old tickets explicitly finish old-style — either way the
      behavior is documented, and no new `.status.md` is ever created.
- [ ] `work.md` and `quickfix.md` mirrors are updated in the same commit
      (composite rule) — both currently describe status-file mechanics.
- [ ] The README's "See it work" tree and any other status-file mentions are
      updated.
- [ ] Blocker recording is preserved: hitting a blocker still writes what
      happened (now into the plan's log) so the next session knows.

## Out of Scope

- Changing the plan template's phase structure or success-criteria split.
- The plan-compliance gate (TP-0020) — it reads criteria, not the log.
- Retroactively migrating existing `.status.md` files into old plans.

## Open Questions

None — dropping the separate file in favor of in-plan logs was confirmed at
ticket creation.

## Questions for Research/Planning

- [ ] Log placement: per-phase blocks (keeps log next to its phase) vs one
      appended log section (keeps the spec part pristine) — recommend
      per-phase, confirm against resume readability.
- [ ] How "plan fully implemented" is detected without the status file (all
      phase logs present and complete vs all checkboxes ticked — define one
      signal).
- [ ] Exact backward-compatibility path for in-flight tickets with an existing
      `.status.md`.
- [ ] Whether `/tce:review` or any other command reads status files today
      (expected: no, but verify before deleting the convention).

## References

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 4, item 4 (the double-bookkeeping
  flag this supersedes).
- `plugins/tce/commands/implement.md` — "Status File Tracking", "Resuming
  Work", "Verification Approach", "Committing Each Phase".
- `plugins/tce/commands/work.md` Phase 4, `plugins/tce/commands/quickfix.md`
  Phase 5 — composite mirrors of the status-file mechanics.
- `plugins/tce/README.md` — the `.status.md` entry in the "See it work" tree.

## Implementation Plan

- Research: `thoughts/shared/research/2026-07-10-TP-0023-merge-status-file-into-plan.md`
- Plan (incl. implementation log + closeout): `thoughts/shared/plans/2026-07-10-TP-0023-merge-status-file-into-plan.md`

## Notes & Updates

### 2026-07-10
Implemented via /tce:work. Checkpoint decisions: per-phase log blocks; completion
requires both signals (all phase logs ✅ Complete AND all checkboxes ticked,
Manual only on explicit user confirmation — the done transition now waits for
it); legacy `.status.md` read-only on resume; gate verdict + ticket transition
persisted in an `## Implementation Closeout` block. Dogfooding this very ticket
surfaced that the manual-confirmation ask must restate the items in full
(`e11eb7c`).

### 2026-07-03
Created from the independent plugin review (Fable 5) discussion. The review
originally proposed merely documenting the intent split (plan = spec state,
status = session journal); the user reported the status files brought no
noticeable improvement since their introduction and chose the stronger
resolution: one document, with the journal folded into the plan as terse
per-phase logs. This ticket supersedes the "bookkeeping intent note" idea.
