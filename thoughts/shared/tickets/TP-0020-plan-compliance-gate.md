# TP-0020: Plan-compliance gate — fresh-context criteria check before closing a ticket

**Status:** Done
**Estimated Complexity:** Medium
**Created:** 2026-07-03
**Updated:** 2026-07-05

## Problem Statement

tce's completion check is self-graded. `/tce:implement` runs tests/typecheck/lint
and ticks off plan checkboxes — but both happen inside the same context that
produced the code, which "knows" it implemented each criterion and checks the box
accordingly. The failure mode is well documented in comparable workflows: agents
marking verification tasks done without the verified thing actually existing
("false security"). Nothing in tce today verifies the implementation *against the
plan and ticket criteria* from an unbiased position — `/tce:review` exists but is
optional, broad, and post-hoc.

Anthropic's published best practice for exactly this is an adversarial check in a
fresh subagent context: a reviewer that sees only the diff and the criteria, not
the reasoning that produced the change, and therefore cannot rationalize gaps
away.

## Desired Outcome

Before a ticket transitions to done, `/tce:implement` (and via it `/tce:work` and
`/tce:quickfix`) runs a **plan-compliance gate**: a dedicated, fresh-context
subagent — a new agent definition shipped with the plugin — that receives only
(a) the ticket's acceptance criteria and the plan's success criteria, and (b) the
implementation diff, and returns a per-criterion verdict: met / not met / cannot
be verified from the diff, each with evidence references. Unmet criteria block
the done transition and are reported for the normal implement flow to address.

The agent is **hard-gated against scope creep**, in the same style as the
existing documentarian blocks: criteria coverage only — no code-quality opinions,
no style commentary, no suggestions, no findings beyond the criteria list. A
checker prompted to find problems always finds some; this one is only allowed to
answer "is each criterion satisfied by this diff?".

## User Stories / Use Cases

- As a tce user, I want an unbiased confirmation that every acceptance criterion
  is actually met before the ticket is marked done, so that "done" means done.
- As a tce user running `/tce:work` or `/tce:quickfix` autonomously, I want this
  gate especially — those flows removed my intermediate reviews, so the exit
  check is the safety net.
- As a tce user, I do not want the gate to turn every small fix into a code-style
  debate — it must stay silent on everything except the criteria.

## Acceptance Criteria

- [ ] A new agent definition exists in `plugins/tce/agents/` (e.g.
      `plan-compliance-checker`) with read-only tools, whose contract is:
      input = criteria + diff scope; output = one verdict per criterion
      (met / not met / cannot verify from diff) with evidence references.
- [ ] The agent's prompt hard-forbids anything beyond criteria verdicts (no
      quality/style/security/refactoring commentary, no suggestions, no
      additional findings), in the same explicit style as the existing
      documentarian blocks.
- [ ] `implement.md` runs the gate after final verification and before the
      ticket-status transition to done; any "not met" verdict blocks the
      transition, is reported to the user, and feeds back into the normal
      implement flow.
- [ ] Criteria that require human judgment (the plan's Manual Verification
      items) are reported as "needs human verification", not guessed at, and do
      not silently pass.
- [ ] `work.md` and `quickfix.md` inherit/mirror the gate per the CLAUDE.md
      composite rule (same commit).
- [ ] The gate adds no interaction when all criteria pass — a passing run is a
      one-line note in the completion summary.

## Out of Scope

- Changes to `/tce:review` (remains the broad, human-triggered review).
- Auto-fixing gaps inside the gate agent — it reports; implement fixes.
- Gating research or plan documents (this is an implementation-exit check only).

## Open Questions

None — the tight criteria-only gating and the dedicated-agent approach were
explicitly confirmed at ticket creation.

## Questions for Research/Planning

- [ ] How the agent obtains the diff: passed into the delegation prompt by
      implement, or derived itself from the ticket's commits (it would need the
      commit range / `git log --grep` mechanics and a Bash grant — weigh
      against keeping it read-only-tools-only).
- [ ] How the criteria are passed: verbatim in the delegation prompt vs the
      agent reading ticket + plan files itself (fresh-context purity argues for
      passing only the criteria + diff, not the full documents).
- [ ] Exact placement in `implement.md` relative to "Final Verification Before
      Closing a Ticket" and the status-transition step, and what the blocked
      path looks like (report → fix → re-run gate).
- [ ] Whether the agent needs the project profile at all (probably not — a
      design goal is that it knows as little as possible beyond criteria+diff).

## References

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 3, item 1 (with sources: Anthropic
  best-practices adversarial-review pattern; Marmelab "false security"
  critique).
- `plugins/tce/commands/implement.md` — "Final Verification Before Closing a
  Ticket" and "Ticket Status Transitions" (the integration site).
- `plugins/tce/agents/codebase-analyzer.md` — the documentarian-block style the
  gating should mirror.
- `CLAUDE.md` — composite-tracking rule.

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5) discussion. Key decisions:
- A **dedicated new agent definition** (not an inline subagent prompt) so the
  gating lives in one reviewed, versioned place.
- The gate is criteria-coverage-only by hard prompt constraint — the user
  specifically called out preventing the checker from "going in the wrong
  direction" as the design priority.
- Especially valuable for the autonomous flows (work/quickfix), which removed
  intermediate human review.
