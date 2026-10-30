# TP-0045d: improvements collected from real orchestrator runs

**Status:** In Progress
**Estimated Complexity:** Medium
**Created:** 2026-10-11
**Updated:** 2026-10-11

Sub-ticket of TP-0045 (the epic). Fourth of four; a collector, open from the
first real TP-0045b run and worked alongside and after TP-0045c.

## Problem Statement

The first real runs of the orchestrator will surface small things that are
not defects and do not belong in TP-0045a, b or c: a missing glimpse of
progress, a brief that explains too much or too little, a question phrased
for the wrong reader. Without a home they either bloat the sub-ticket being
worked or get lost between sessions.

## Desired Outcome

One sub-ticket collects them as a checklist, each item one or two lines with
the run it came from. Items are implemented in batches once TP-0045c has
landed (or earlier when one is cheap and does not touch a step's working), or
spun out into a ticket of their own when one grows. The epic's done check
counts this ticket as Done when every item is ticked or moved.

## User Stories / Use Cases

- As the human running real tickets, I want a place to drop an observation
  in one line so that the run is not interrupted and the observation is not
  lost.
- As the maintainer, I want the improvements batched after stage 2 so that
  they are built against the final command shape, not against stage 1 prose
  that stage 2 deletes.

## Collected items

- [ ] **Progress heads-up lines.** Agents return short progress lines while
      running so the human sees what is happening between dispatch and
      return. Platform question: whether a subagent can surface anything
      before it finishes (a notification, a file the orchestrator tails, or
      nothing). Source: ticket creation, 2026-10-11.

## Acceptance Criteria

- [ ] Every collected item is either ticked with the commit that implemented
      it or moved to a named ticket.
- [ ] No item changes an agent's contract or a step's working; such a change
      is moved to its own ticket on sight.
- [ ] Each batch of implemented items bumps and tags tce.

## Out of Scope

- Anything that changes an agent's contract or a step's working.
- Defects: a run that breaks is a bug ticket, not an improvement.

## Open Questions

None.

## Questions for Research/Planning

Per item, at implementation time.

## References

- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md` — the epic
- `thoughts/shared/tickets/TP-0045b-step-agents-orchestrating-work.md` — the
  runs this collects from

## Implementation Plan

Per batch; none up front.

## Notes & Updates

### 2026-10-11

- Created by user decision during sub-ticket authoring, with the progress
  heads-up idea as its first item.
