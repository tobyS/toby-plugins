# TP-0023: Merge Implementation Status Tracking into the Plan Implementation Plan

## Overview

Drop the parallel `.status.md` status file: the plan document becomes the single
record of implementation progress. `/tce:implement` appends a terse, clearly
demarcated `### Implementation log` block under each phase (status, base/phase
commit hashes, what was done, issues → resolutions, verification results) plus a
compact `## Implementation Closeout` section at the end (gate verdict, manual
verification state, ticket transition). Resume, completion detection, and blocker
recording work from the plan alone; a legacy `.status.md` next to a plan is still
read (read-only) so in-flight implementations in consuming projects survive the
upgrade.

## Current State Analysis

- `plugins/tce/commands/implement.md` owns the convention: `## Status File
  Tracking` (lines 91–150: naming, full format incl. `**Base commit**`, rules
  1–6), `## Getting Started` (152–167: detect/resume/create), `## Verification
  Approach` (224–226: update plan checkboxes AND status file), `## Committing
  Each Phase` (240: commit hash into the status file), `## Plan-Compliance Gate`
  (279–284: diff from the status file's `**Base commit**`, with a
  `git log --grep` fallback), `## Resuming Work` (336–359: "the status file is
  the authoritative record").
- Mirrors: `work.md:226-228,239-240,256` (inline re-description, composite rule),
  `quickfix.md:186` (one delegated-procedure sentence), `plugins/tce/README.md:65`
  (`.status.md` entry in the "See it work" tree), `CLAUDE.md` ("the status file
  records a `**Base commit**` so the diff is precise" in the TP-0020 gate
  section, plus "the status-file mechanics" in the composite-tracking rule's
  example list).
- Nothing else reads status files: `review.md`, `plan.md`, `research.md`, both
  reference templates, the `plan-compliance-checker` agent, scripts, and hooks
  are all clean (research finding 3).
- Today's completion signal is "all phases ✅ Complete in the status file"; plan
  checkboxes are write-only and never consulted at resume time. Dogfooded status
  files additionally record the gate verdict and the ticket transition (e.g.
  `thoughts/shared/plans/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.status.md`).
- All 20 existing `.status.md` files belong to Done tickets; no in-flight
  implementation in this repo depends on one.

## Desired End State

A plan document carries its own progress: each phase ends (after
`### Success Criteria:`) with a terse `### Implementation log` block, and a
finished plan ends with `## Implementation Closeout`. `/tce:implement` (and the
composites) create, read, and resume from these blocks; no `.status.md` is ever
created again; a legacy one is read for resume only. Verify by reading the five
edited files and running the greps/validators below.

### Key Discoveries:

- The gate's diff step must re-point at the new `**Base commit**` home; its
  existing `git log --grep` fallback (implement.md:282-284) is the precedent for
  tolerating missing base commits (research finding 1).
- The plan template's per-phase structure ends with the success-criteria H3
  followed by `---`, so a per-phase H3 log block fits without disturbing the
  checkbox sections (research finding 4).
- `CLAUDE.md`'s TP-0020 rule itself demands its gate sentence be updated in the
  same commit as implement.md's diff mechanics (research finding 3).
- Dogfooded status files record gate verdict + ticket transition beyond the
  template — the closeout block re-homes these (research finding 5).

### Checkpoint decisions (from the /tce:work question round):

1. **Placement**: per-phase `### Implementation log` blocks.
2. **Completion signal**: BOTH signals must agree — every phase's log status is
   ✅ Complete AND every success-criteria checkbox (Automated **and** Manual) is
   ticked. Manual boxes are ticked only on explicit human confirmation, so the
   Done transition now waits for that confirmation ("Manual blocks too").
3. **Backward compatibility**: read a legacy same-basename `.status.md` on
   resume when the plan has no log blocks; log into the plan from then on; never
   create or write a `.status.md`.
4. **Gate verdict + ticket transition**: persisted compactly in the closeout
   block.

## What We're NOT Doing

- Not migrating the 20 existing `.status.md` files into their plans (ticket Out
  of Scope).
- Not changing the plan template's phase structure or the Automated/Manual
  success-criteria split.
- Not touching the `plan-compliance-checker` agent — it receives criteria + diff
  as text and never reads files under `thoughts/` (TP-0020 isolation).
- Not changing `plan.md`'s authoring flow — plans are still written without log
  blocks; only the template's downstream-consumer notes change.
- No version bump/release in this ticket (release flow is separate).

## Implementation Approach

One phase, one commit: the composite-tracking rule (implement → work/quickfix),
the TP-0020 gate rule (its CLAUDE.md sentence), and the template's own header all
require same-commit updates, so every file moves together. Edits are surgical —
section replacements in implement.md, line-level rewording in the mirrors —
preserving each command's structure and altitude.

**Dogfooding note:** this implementation itself uses the new convention — its
progress is logged into this plan's own Implementation log block, and no
`.status.md` is created for this plan.

## Phase 1: Swap the status-file convention for in-plan implementation logs

### Overview

Rewrite implement.md's tracking/resume/gate/closing mechanics against the in-plan
log, mirror the changes into work.md and quickfix.md, acknowledge the log in the
plan template's contract notes, and update README + CLAUDE.md mentions.

### Changes Required:

#### 1. `plugins/tce/commands/implement.md` — the authoritative spec

**File**: `plugins/tce/commands/implement.md`
**Changes**:

a) Frontmatter `description` (line 2): "…with verification and status tracking"
→ "…with verification and in-plan progress tracking".

b) Replace `## Status File Tracking` (lines 91–150) with a new
`## Implementation Log Tracking` section carrying this substance:

- Opening statement: **the plan document is the single record of implementation
  progress** — each phase gets a terse `### Implementation log` block appended
  as the phase's last subsection (after `### Success Criteria:`, before the
  `---` separator). No separate status file exists.
- `### Implementation Log Format` — fenced template:

  ```markdown
  ### Implementation log

  - **Status**: ✅ Complete | ⚠️ Partial | ❌ Blocked
  - **Base commit**: `<hash>` (first phase's log only — HEAD before any
    implementation commit; the Plan-Compliance Gate diffs from it)
  - **Commit**: `abc1234` <commit subject per the project's commit convention>
  - **Did**: [1–2 lines — files changed, tests added]
  - **Issues**: [none | issue description → resolution applied]
  - **Verification**: [compact ✅/❌ list on one line, e.g. "✅ tests, ✅ lint"]
  ```

  (Timestamps from the old format are deliberately dropped for terseness; git
  history carries timing.)
- **Terseness guidance** (explicit, per the ticket): a few lines per phase —
  target ≤ 8 lines per block, never prose journaling; the plan is re-read fully
  by implement, the composites, and every resume, and must not bloat as context.
- `### Implementation Closeout Format` — appended at the very end of the plan
  when closing the ticket:

  ```markdown
  ## Implementation Closeout

  - **Plan-compliance gate**: [PASS — N met, K verified manually in-session | summary per gate run]
  - **Manual verification**: [confirmed by user YYYY-MM-DD | pending: <items>]
  - **Ticket**: [PREFIX]-XXXX → Done
  ```

- `### Implementation Log Rules` (successor of Status File Rules 1–6):
  1. Read the plan's log state before starting any implementation work (the
     log blocks are part of the plan just read — no extra file).
  2. **Fully implemented** = every phase's log has `**Status**: ✅ Complete`
     AND every success-criteria checkbox (Automated **and** Manual) is ticked;
     the two signals must agree. If so: stop, tell the user, list what was done.
  3. Log blocks exist with incomplete phases → print a done-vs-remaining
     summary, continue from the first incomplete phase.
  4. **Legacy status files**: plan has no log blocks but a same-basename
     `.status.md` exists → read it to recover progress (including a recorded
     `**Base commit**`), then log into the plan from this point on. Never
     create a new `.status.md`, never write to an existing one.
  5. No log state anywhere → fresh implementation: when starting the first
     phase, append its log block and record `git rev-parse HEAD` as the
     `**Base commit**` (tip before any implementation commit — the gate diffs
     from it).
  6. Update the phase's log block after every phase (status, commit hash, did,
     issues → resolutions, verification results).
  7. Write the log when encountering blockers — set `❌ Blocked` and record the
     issue even if unresolved, so the next session knows what happened.
  8. Manual verification checkboxes are ticked **only on explicit human
     confirmation** — never tick them yourself (see Final Verification / gate).

c) `## Getting Started` (lines 152–167): replace the "Check for a status file"
step with: check the plan's `### Implementation log` blocks (already read with
the plan); if none, check for a legacy `.status.md` next to the plan (read-only,
rule 4); branch to all-complete / partial / fresh exactly as today.

d) `## Verification Approach` (lines 224–226): merge the two bookkeeping bullets
into the single document — "Check off completed Automated checkboxes in the plan
file using Edit (Manual ones only on user confirmation)" + "Update the phase's
`### Implementation log` block with the results".

e) `## Committing Each Phase` (line 240): "Record the resulting commit hash in
the phase's `### Implementation log` block in the plan." (Same mechanics as
today: the hash line lands with the next commit.)

f) `## Plan-Compliance Gate` step 2 (lines 279–284): re-point the base-commit
source and extend the fallback chain:

> **Assemble the diff.** Use the `**Base commit**` recorded in the first
> phase's `### Implementation log` block in the plan. Compute the
> implementation diff with `git diff <base> -- . ':(exclude)thoughts/'` plus a
> `git diff <base> --stat` summary. If the plan's log records no base commit,
> check a legacy `.status.md` next to the plan for one; failing that, fall back
> to `git log --grep="[PREFIX]-XXXX" --format=%H | tail -1` and diff from that
> commit's parent.

g) Gate outcome + `## Ticket Status Transitions` (lines 290–324): after the gate
passes, MANUAL items are presented to the user with a request to verify and
confirm (plain prose ask — implement.md has no AskUserQuestion block). On
confirmation: tick the Manual checkboxes, append `## Implementation Closeout`,
transition the ticket to done per policy. If the user defers: leave Manual boxes
unticked and the ticket un-transitioned (per policy it stays in progress), write
the closeout with `Manual verification: pending: <items>`, and remind the user
the done transition is due after confirmation. Plans with no Manual criteria
skip the ask. The done bullet's condition becomes: all phases ✅ Complete, gate
passed, and Manual criteria confirmed (or none exist).

h) `## Resuming Work` (lines 336–359): rewrite against the plan alone — "The
plan document is the authoritative (and only) record of implementation
progress"; read the log blocks (and the legacy `.status.md` if rule 4 applies);
keep the existing ✅/⚠️/⬚ summary format and the Partial/Blocked/trust-complete
steps verbatim in substance.

#### 2. `plugins/tce/commands/work.md` — composite mirror (same commit)

**File**: `plugins/tce/commands/work.md`
**Changes**: Phase 4a steps 3–5 (lines 226–228) → check the plan for
`### Implementation log` blocks; if none, check for a legacy `.status.md`
(read-only); resume from log state or append the first phase's log block
(recording the Base commit) when starting fresh. Phase 4b bullets (lines
239–240) → "Update the phase's `### Implementation log` block in the plan after
every phase" / "Check off completed success-criteria checkboxes (Manual ones
only on user confirmation)". Phase 4d (line 256) → the gate diff comes "from
the `**Base commit**` in the plan's first-phase implementation log"; the done
transition additionally waits for user confirmation of Manual criteria.

#### 3. `plugins/tce/commands/quickfix.md` — delegated mention (same commit)

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: Line 186 → "…reading the ticket/research/plan, logging progress
into the plan itself (per-phase implementation log), implementing phase by
phase, running verification, and committing after each phase." Final Summary
gate line (218) and its explanation (233–239): reflect that Manual items now
gate the done transition — when manual items are pending, the summary states the
ticket remains in progress pending the user's confirmation.

#### 4. `plugins/tce/references/plan-document-template.md` — contract note

**File**: `plugins/tce/references/plan-document-template.md`
**Changes**: Extend the header comment's downstream-consumers note (lines
10–12): /tce:implement appends a terse `### Implementation log` block to each
phase and an `## Implementation Closeout` section at the end during
implementation (formats owned by implement.md); plans are **authored without
them**. Add a matching one-paragraph note in the body (after "Structuring
patterns" or the template block) so plan authors reading only the body see it.

#### 5. `CLAUDE.md` — lock-step rule wording

**File**: `CLAUDE.md`
**Changes**: In the TP-0020 gate section, "the status file records a `**Base
commit**` so the diff is precise" → "the plan's first-phase implementation log
records a `**Base commit**` so the diff is precise". In the composite-tracking
rule's example list, "the status-file mechanics" → "the in-plan
implementation-log mechanics". Grep for any further "status file" occurrences
and reword them consistently.

#### 6. `plugins/tce/README.md` — artifact tree

**File**: `plugins/tce/README.md`
**Changes**: Remove the `…document-tagging.status.md` line from the "See it
work" tree (line 65); check surrounding prose for status-file narrative and
reword to the in-plan log if present.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes (repo root)
- [x] `claude plugin validate ./plugins/tce` passes
- [x] `claude plugin validate ./plugins/tmt` passes
- [x] `grep -rn "\.status\.md" plugins/` matches only the legacy-compat passages in `implement.md` and `work.md` (zero hits in `quickfix.md`, `README.md`, `references/`, `agents/`)
- [x] `grep -n "Status File" plugins/tce/commands/implement.md` returns nothing (old headings and rules gone)
- [x] `grep -in "status file" plugins/tce/README.md` returns nothing
- [x] `grep -in "status file" CLAUDE.md` returns nothing (both rule passages reworded)

#### Manual Verification:

- [ ] implement.md read-through: fresh start, resume-partial, resume-complete, legacy-`.status.md`, and blocked scenarios are each coherent working from the plan alone
- [ ] work.md Phase 4 mirrors implement.md's new mechanics point-for-point (composite rule)
- [ ] The done transition now waits for user confirmation of Manual criteria, and quickfix's Final Summary wording matches that behavior
- [ ] The plan template note cannot be misread as "plan authors write log blocks"

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `a694b109c9c7d3b569ff791e43382dbe84dd68d8` (HEAD before any implementation commit)
- **Commit**: pending
- **Did**: implement.md tracking/resume/gate/closing rewritten against in-plan logs; mirrored work.md 4a/4b/4d + quickfix.md (procedure sentence, gate summary); template header + "do not author" note; CLAUDE.md composite-list + gate sentence; README step 4 + tree.
- **Issues**: none
- **Verification**: ✅ validate ×3 (marketplace, tce, tmt), ✅ all 4 grep sweeps clean

---

## Testing Strategy

### Unit Tests:

- Not applicable — markdown command prompts; the "tests" are the plugin
  manifest validators and grep sweeps above.

### Integration Tests:

- None automated; the convention is exercised by the next dogfooded ticket
  (including this one — see the dogfooding note).

### Manual Testing Steps:

1. Read implement.md end-to-end and walk each resume scenario (fresh / partial /
   complete / legacy / blocked) against an imagined plan with log blocks.
2. Diff work.md's Phase 4 against implement.md's new sections for mirror
   fidelity.
3. Read quickfix.md's Final Summary against the new manual-confirmation gating.
4. Confirm the template note reads as "added during implementation", not as
   authoring instructions.

## Performance Considerations

Context size is the constraint (the plan is re-read fully by implement, the
composites, and every resume): the log format drops the old timestamps, caps
blocks at a few lines, and forbids prose journaling, so a merged plan stays
close to today's plan size plus ~6 lines per phase.

## Migration Notes

- In-flight implementations in consuming projects (plan without log blocks +
  existing `.status.md`) resume via the legacy read-only path and continue in
  the plan; no action needed from users.
- The 20 historical `.status.md` files in this repo stay untouched (out of
  scope).
- No config or init/upgrade-list change: the convention lives entirely in
  command text, not project config.

## References

- Original ticket: `thoughts/shared/tickets/TP-0023-merge-status-file-into-plan.md`
- Related research: `thoughts/shared/research/2026-07-10-TP-0023-merge-status-file-into-plan.md`
- Gate mechanics being re-pointed: `thoughts/shared/plans/2026-07-05-TP-0020-plan-compliance-gate.md`
- Freshest status-file example (what the closeout re-homes): `thoughts/shared/plans/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.status.md`
