# TP-0045h: decide design exploration in the intent, not in the planner

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-10-30
**Updated:** 2026-10-30

Sub-ticket of TP-0045 (the epic), moved out of TP-0045d. Not part of the epic's
done check, which names a to d.

## Problem Statement

The planner decides whether a ticket needs design exploration, as the first
question of its round. In the first real `/tce:work` run (GH-37) that was
question 1 of 8: the human chose to stop, the run ended without asking the other
7, and that planner run (112k tokens) was wasted.

The same run showed two defects in `/tce:design_explore`: it named the mockup
folder without the ticket ID, so `ticket.sh` cannot find it, and it left
`DECISION.md` uncommitted.

## Desired Outcome

`/tce:intent` holds the design-exploration check and records its outcome: the
`DECISION.md` path, or "plan directly". The planner follows that record and asks
only for older intents that have none. `/tce:design_explore` names its mockup
folder with the ticket ID and commits `DECISION.md`.

## Out of Scope

- What a design exploration itself produces, beyond the folder name and the
  commit.
- The form of the planner's questions (TP-0047).

## References

- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` —
  finding 1, with the human's decision
- `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md` —
  "Items H to L"
- `plugins/tce/agents/planner.md:99-109` — the design exploration check
- `plugins/tce/references/work-loop.md:179-181` — Step 3's note on design
  exploration
- `plugins/tce/references/work-loop.md:222-224` — Step 6's stop for it
