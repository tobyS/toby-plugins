# TP-0035: Evaluate how to remove tce's post-merge closeout step

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-12
**Updated:** 2026-09-12

## Problem Statement

`/tce:implement` ends a ticket by appending an `## Implementation Closeout`
section to the plan (gate result, manual-verification state, **merge
reference**, ticket → Done) and, where the ticket policy allows, flipping the
ticket status. In a project that develops branch-per-ticket (TP-0031) and
squash-merges with branch deletion, the merge reference is only known *after*
the human merged, and the branch that carried the plan is gone by then. The
closeout therefore becomes a commit on the main branch that happens after the
review decision — a **post-merge human touchpoint**:

- the human merges, then has to report back to the agent that the merge landed;
- the agent writes the closeout on main and the human pushes it (in projects
  where agents may not push main, the human is the only one who can — see
  chat-sustainability issue #63, "Record the merge reference without a human
  push to main");
- the agent's local stale-branch cleanup is a further step in the same
  hand-over chain.

For interactive tce use this is an avoidable extra round-trip after the
decision that mattered. (The tsf factory, TP-0034, had the same problem and
solved it independently in its own design — DESIGN.md §3.2, §9.3, §16.19: the
last journal entry precedes the merge, the merge cycle writes nothing. tsf
neither depends on nor adopts this ticket's result; the two are independent.)

## Desired Outcome

After the human's merge, **nothing remains to be done** by either the agent or
the human for the ticket to be complete and its record durable: no closeout
commit on main, no "report back that the merge landed", no follow-up push.
Every piece of information the closeout carries today either lands *before*
the merge (on the branch, inside the squash) or lives somewhere that needs no
commit (the ticket system), or is dropped because it is derivable.

The evaluation compares the candidate mechanisms against these criteria,
records the decision, and adapts tce accordingly.

## User Stories / Use Cases

- As a developer merging a tce PR, I want the merge to be the last action for
  that ticket, so that I do not return to the session to close it out.
- As a developer in a project where agents cannot push main, I want tce to
  never need a commit on main after the merge, so that the workflow works
  without a human push step.

## Acceptance Criteria

- [ ] A research document evaluates at least these options against the
      "nothing after the merge" outcome and against the retrievability of the
      per-phase commit hashes (which the merge reference exists to protect):
      1. writing the closeout on the branch **before** the merge, with the
         pull/merge request number as the merge reference (known once the PR
         exists);
      2. dropping the merge reference entirely and relying on the ticket ID in
         the squash commit's subject plus `baseline.sh` (TP-0030) for hash
         resolution;
      3. moving the closeout out of the plan into the ticket system (issue
         comment, tmt ticket note) where no commit is needed;
      4. any mechanism on the merge itself (e.g. `Closes #n`, a CI job on
         merge) for the status flip.
- [ ] The decision is recorded in the plan with reasoning, including what
      happens to the tmt status flip (`**Status:** Done` is a file edit) and to
      the GitHub adapter's status flip.
- [ ] tce is changed so that a branch-per-ticket, squash-merge project needs no
      commit and no agent interaction after the merge: `implement.md` (closeout
      and ticket-status sections), the plan template's closeout section, the
      `tickets.md` template's "Status / completion" guidance, and the
      composites `work.md`/`quickfix.md` per the composite-tracking rule.
- [ ] `/tce:list`'s stage detection (`stage.sh`, TP-0033) still reports
      finished tickets correctly under the new closeout shape.
- [ ] Projects that commit directly to main (this repo) keep working unchanged.
- [ ] The consumer-facing tce README and the chat-sustainability-style
      hand-over chain description are updated to match.

## Out of Scope

- tsf — its design already carries its own, independent mechanism
  (DESIGN.md §16.19); nothing here feeds into TP-0034.
- Making agents able to push main, or any change to a project's branch
  protection.
- The local stale-branch deletion beyond documenting that it is optional
  hygiene (`git fetch --prune` on the next start covers the remote side).

## Open Questions

- Is "Done" on the branch before the merge acceptable semantically, given the
  human may still request changes? Candidate reading: the closeout records that
  the implementation is complete and verified; the merge is the integration
  decision, not part of the ticket's completion state.

## Questions for Research/Planning

- [ ] What exactly consumes the merge reference today (drift check fallback,
      `baseline.sh`, `stage.sh`, `/tce:list`, humans reading the plan), and
      which of those consumers break without it?
- [ ] For the GitHub adapter: does `Closes #n` in the PR body cover every
      status transition tce performs at completion, or does anything remain
      (e.g. dropping an `in progress` label) that has to move before the merge?
- [ ] For tmt: whether `**Status:** Done` on the branch before the merge
      collides with the tmt status hooks or with `/tmt:list`.
- [ ] Whether the pre-merge closeout should be written at the complete
      transition (when the PR is un-drafted) or at the last implementation
      commit.

## References

- `plugins/tce/commands/implement.md` — "Implementation Closeout" and "Ticket
  Status Transitions"
- `plugins/tce/references/plan-document-template.md` — closeout section
- `plugins/tce/templates/tce/tickets.md` — "Status / completion"
- `plugins/tce/scripts/baseline.sh` (TP-0030), `plugins/tce/scripts/stage.sh`
  (TP-0033), `plugins/tce/scripts/branch.sh` (TP-0031)
- chat-sustainability: `.claude/tce/tickets.md` "Handing over at completion",
  issue #63
- TP-0034 (tsf plugin) — solved the same problem independently
  (`plugins/tsf/DESIGN.md` §16.19); reference only, no dependency either way

## Implementation Plan

## Notes & Updates

### 2026-09-12

- Ticket created from the tsf/chat-sustainability fit discussion. Numbered
  TP-0035 because TP-0034 is taken by the tsf ticket on the `tsf-design`
  branch, which is not on `main` yet.

### 2026-09-15

- Removed the tsf dependency: DESIGN.md §16.19 made tsf's mechanism
  independent of this ticket, so the "blocker for tsf" framing, the tsf user
  story and the "TP-0034 adopts the result" reference were stale.
