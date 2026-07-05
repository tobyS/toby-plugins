# TP-0018: Permit root-cause analysis in research for defect tickets

**Status:** In Progress
**Estimated Complexity:** Small
**Created:** 2026-07-03
**Updated:** 2026-07-05

## Problem Statement

The independent plugin review (`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`, Section 2,
finding 6) identified a collision in `/tce:research`'s core rules. The
"documentarian, not critic" block — "DO NOT perform root cause analysis unless
the user explicitly asks" — is the right guard against premature solutioning
for feature tickets. But for a **bug ticket** (and every `/tce:quickfix`),
locating the cause *is* the research deliverable: research that describes
everything around the defect without saying where the faulty behavior comes
from forces the model to either violate the rule or produce a document that
planning can't plan from.

## Desired Outcome

The documentarian rules carve an explicit, bounded exception: when the ticket
describes a defect, tracing and documenting the **mechanism of the faulty
behavior** (where actual behavior diverges from intended behavior, with
file:line evidence) is in scope as documentation. The boundary stays firm:
still no fix proposals, no critique of code quality, no refactoring
suggestions — choosing the fix remains the planning phase's job. Feature-ticket
research behavior is unchanged.

## User Stories / Use Cases

- As a tce user researching a bug ticket, I want the research document to
  pinpoint where and why the behavior goes wrong so that planning can choose a
  fix instead of re-doing the diagnosis.
- As a tce user running `/tce:quickfix`, I want the autonomous research phase
  to be allowed to find the cause of the bug it is supposed to fix.
- As a tce user researching a feature ticket, I want research to stay purely
  descriptive, exactly as today.

## Acceptance Criteria

- [ ] `research.md`'s documentarian rules contain an explicit defect-ticket
      exception with a clear boundary: tracing the mechanism of the faulty
      behavior (with file:line evidence) is documentation; proposing or
      choosing fixes, and critiquing unrelated code, remain out of scope.
- [ ] `work.md` and `quickfix.md` mirror the exception (CLAUDE.md composite
      rule, same commit).
- [ ] Research determines whether the agents' documentarian blocks
      (`codebase-analyzer`, `codebase-locator`, `codebase-pattern-finder`)
      need the same carve-out — and the outcome is applied consistently, so a
      command asking an agent to trace a defect isn't refused by the agent's
      own rules.
- [ ] Behavior for non-defect tickets is unchanged (the exception is keyed on
      the ticket describing a defect, not on research mood).

## Out of Scope

- Any relaxation of the no-recommendations rule for feature tickets.
- Changes to `/tce:review` (which is allowed to critique by design).
- Command length/restructuring (TP-0016).

## Open Questions

None — the boundary (trace mechanism: yes; propose fix: no) was set at ticket
creation.

## Questions for Research/Planning

- [ ] Where exactly the exception lands in `research.md` (the CRITICAL block,
      the sufficiency check, or both) and how the composites mirror it.
- [ ] How research classifies a ticket as a defect (explicit signal from the
      ticket content vs judgment call) — keep it simple and stated.
- [ ] Whether the research document template needs a dedicated section (e.g.
      "Defect Mechanism") or the existing Detailed Findings structure carries
      it.

## References

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 2, finding 6.
- `plugins/tce/commands/research.md` — the "CRITICAL: YOUR ONLY JOB…" block.
- `plugins/tce/agents/codebase-analyzer.md` and siblings — the agents'
  documentarian blocks.
- `CLAUDE.md` — composite-tracking rule.

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5). The exception is
deliberately narrow: it legitimizes diagnosis for defects without reopening
the door to solutioning or critique in research.
