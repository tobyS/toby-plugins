# TP-0045f: ticketless runs follow the branch convention and delivery

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-10-27
**Updated:** 2026-10-27

Sub-ticket of TP-0045 (the epic). A design change to what TP-0045c built,
not a defect.

## Problem Statement

TP-0045c decided that ticketless work never branches and is always delivered
Direct: `/tce:quickfix`, and every step command or `/tce:work` given an
intent path, stay on the current branch and never push or open a pull
request. In a project whose profile says **Branch per ticket** and **Pull
request**, that means a quickfix lands its intent, research, plan, code and
dossier on the base branch and bypasses the project's own review flow. The
first real `/tce:quickfix` run (2026-10-27) showed exactly that: it did not
obey the branching and pull-request rules the other commands follow.

## Desired Outcome

Ticketless runs follow the profile's `## Branch convention` and `## Delivery`
the same way ticket runs do. Under Branch per ticket they work on their own
branch; under Pull request delivery `/tce:quickfix` (like `/tce:work`) ends
with an open pull request. Projects on Current branch and Direct delivery see
no change.

## Acceptance Criteria

- [ ] Under Branch per ticket, a ticketless run works on its own branch and
      no commit of the run lands on the base branch.
- [ ] Under Pull request delivery, `/tce:quickfix` and a ticketless
      `/tce:work` push the branch and open a pull request.
- [ ] Under Current branch / Direct (or with the sections absent), behaviour
      is unchanged from tce 1.5.0.
- [ ] CLAUDE.md and the tce README describe the new ticketless behaviour.
- [ ] tce version bumped and tagged.

## Out of Scope

- The four defects of TP-0045e.
- Changes to the profile's Branch convention or Delivery options themselves.

## Open Questions

None at this time.

## References

- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md` — the epic
- `thoughts/shared/tickets/TP-0045c-single-step-commands-on-agents.md` — where
  "ticketless never branches, always Direct" was decided
- `plugins/tce/references/work-loop.md` (Steps 2 and 10),
  `plugins/tce/commands/quickfix.md`, `plugins/tce/commands/intent.md`
  (Autonomous mode)

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-10-27

- Reported on a real `/tce:quickfix` run; first drafted into TP-0045e's
  intent, then split out as its own sub-ticket because it is a design change.
