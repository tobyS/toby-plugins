# TP-0034b: tsf slice 2 — implementation, verification pipeline, and the dossier

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-09-15
**Updated:** 2026-09-15

Sub-ticket of TP-0034 (the epic). Second of three slices; depends on
TP-0034a. Followed by TP-0034c (landing).

## Problem Statement

After slice 1 a ticket stops at `tsf:implement`. This slice makes the
factory produce code: implementation from the approved plan, the PR, local
and CI verification with bounded fixing, the three context-starved gates,
the dossier, and the reading of the human's review. After it, a ticket goes
from an approved plan to a PR the human can approve or send back; only the
landing is missing.

## Desired Outcome

`/tsf:cycle` handles dispatch-table rows 5 to 11 of DESIGN.md §4: implement
(and rework mode), verify-fix per episode, the three post-implement gates in
one foreground cycle, the dossier, and the review-state transitions to
`tsf:landing` / `tsf:rework`. The environment contract (`env_up`,
`env_reset`, `env_check`, `verify`) is exercised for real.

## Acceptance Criteria

- [ ] Agents `tsf:implement` (normal, rework and fix modes, §6.6; plan
      deviations written as plan addenda, never journal-only),
      `tsf:verify-fix` (§6.7), `tsf:dossier` (§9.1) per the §6 common
      contract; the four-gate roster's first three, `tsf:plan-compliance`,
      `tsf:spec-coverage`, `tsf:security`, mechanically read-only
      (`tools: Read, Grep, Glob`), each with the three-part constraint
      envelope, the security gate classifying findings blocking/advisory
      (§7); all descriptions begin "Internal to `/tsf:cycle` — not for
      direct use".
- [ ] `/tsf:cycle` rows 5–11: after implement the dispatcher pushes and
      opens the PR from the pr-body template — **never a draft** — and
      journals the PR number (§6.6, §9.1); local verification through the
      project's `verify` script, CI read at pickup on the PR head, mode
      `local` | `ci` (§7); verify-fix bounded per episode with
      `reports/verify-fix-<episode>-<attempt>.md`, the episode number taken
      from the journal (§6.7); the three gates dispatched in parallel and in
      the foreground, the dispatcher writing the three reports as
      `reports/<gate>-<episode>-<round>.md` with a `head:` line, re-running
      the gates when a report is missing or names another head, and
      routing any "not met" or blocking finding to implement in fix mode
      bounded by `gate_fix_bound` (§4 row 8, §6.6, §7); dossier posted to
      the PR with the five sections of §9.1, PR title/body validated,
      `tsf:needs-review` set and the comment timestamp journaled; an
      approving review newer than the last logic-changing push →
      `tsf:landing` (row 12 ends the cycle with "not implemented in this
      slice"), a changes-requested review newer than the last dossier post
      or addendum → `tsf:rework`, an older one ignored (§4 row 10, §9.2).
- [ ] Environment contract execution: `env_up` in every
      implementation-flavored cycle (idempotent), `env_reset` on ticket
      switch, `env_check` when registered, failure → `tsf:needs-human` (§8).
- [ ] Reference templates: report (with the `head:` line), dossier, pr-body;
      the plan-compliance gate receives the plan's per-increment criteria
      (addenda included) and the diff computed from the base commit
      recorded at implement start (§7, §11.2).
- [ ] Project-agnostic: no stack, path or project literals.
- [ ] Version bumped to `0.2.0` in both manifests (§12 release plan); repo
      `CLAUDE.md` gains the tsf rule sections for the same-commit spans this
      slice creates (at least: the gate-report contract, the fix-mode
      routing, the environment-contract cadence).
- [ ] Smoke test (manual): on the scratch project (factory identity = the
      second GitHub account, so the human can review), drive a ticket from
      `tsf:implement` to `tsf:needs-review` with `/loop /tsf:cycle`, approve
      the PR, and see `tsf:landing` set on the next cycle; request changes
      on another ticket and see the rework round return to
      `tsf:needs-review` with a dossier addendum, and the following cycle
      **not** send it back to rework.

## Out of Scope

- Landing loop, integration gate, merge (TP-0034c).
- Anything DESIGN.md §14 lists as a v1 non-goal.

## Questions for Research/Planning

- [ ] Prompt size when a full diff is passed inline to three gates at once
      (no documented Agent-prompt limit; needs a check with a large diff).
- [ ] How the dispatcher derives "last logic-changing push" for §4 row 10
      from the journal in this slice (before the merge-resolver agent
      exists, every push is logic-changing).
- [ ] Concurrency: three foreground gates per cycle against the per-session
      subagent cap (20).

## References

- `plugins/tsf/DESIGN.md` v1.3 — §4 rows 5–11, §6.6, §6.7, §7, §8, §9.1,
  §9.2, §11.1–11.4
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
- Epic: `TP-0034-implement-tsf-plugin-v1.md`; predecessor `TP-0034a`

## Implementation Plan

## Notes & Updates

### 2026-09-15

- Created as the second of three slices when TP-0034 became an epic.
- Aligned with DESIGN.md v1.3: fix mode and `gate_fix_bound`, numbered gate
  reports with a `head:` line, plan deviations as addenda, the
  changes-requested recency rule, `env_up` every implementation cycle,
  version `0.2.0`, CLAUDE.md sections per slice, second GitHub account in
  the smoke test.
