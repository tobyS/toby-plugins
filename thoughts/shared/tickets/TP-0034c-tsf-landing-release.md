# TP-0034c: tsf slice 3 — landing loop, integration gate, and the 1.0.0 release

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-15
**Updated:** 2026-09-15

Sub-ticket of TP-0034 (the epic). Last of three slices; depends on TP-0034b
and on the consumer-side spike (see Dependencies).

## Problem Statement

After slice 2 an approved PR waits at `tsf:landing` and the human would have
to merge by hand — the one thing the design promises they never do. This
slice lands approved work unattended and completes the plugin: the landing
loop, the integration gate, the merge, the repo documentation, and the
release tag.

## Desired Outcome

`/tsf:cycle` handles DESIGN.md §4 row 12: at most one landing ticket per
cycle, oldest approval first; sync by the REST update-branch endpoint, the
integrate agent only on conflict with classification; the integration gate
when the main branch moved; the decide rule; the REST squash merge with the
PR title as subject; branch deletion fallback; nothing written after the
merge. tsf 1.0.0 is tagged and listed in the marketplace catalog.

## Dependencies

- TP-0034b implemented.
- The consumer-side spike from `plugins/tsf/DESIGN.md` §9.3, run in the
  first consumer project's sandbox (its issue #62 walk-through): the REST
  merge and update-branch endpoints are accepted for the factory identity by
  the proxy and by the ruleset with one required approving review, and the
  identity the server-made sync commit carries is known. Its outcome is
  recorded in this ticket's plan and selects the merge mechanism (REST, or
  the label-bridge fallback with an App token).

## Acceptance Criteria

- [ ] Agents `tsf:integrate` (§9.3, §11.1) and `tsf:integration` (gate 4,
      §7, §11.2; read-only, three-part envelope); descriptions begin
      "Internal to `/tsf:cycle` — not for direct use".
- [ ] `/tsf:cycle` row 12 (§9.3 steps 1–5): REST update-branch first, clone
      merge by the integrate agent on conflict with mechanical/logic
      classification and journaled reasoning, unresolvable → `tsf:needs-human`
      with the concrete decision; integration gate only when main moved since
      approval, verdict safe/risk; verify-fix on red CI as usual; decide rule
      (CI green, up to date, mechanical or no resolution, gate safe or
      skipped, latest approval newer than the last logic-changing push) or
      dossier addendum + `tsf:needs-review`; REST squash merge with the PR
      title as subject; remote branch deleted when the repository setting is
      off; the next prepare prunes; no write after the merge (§3.2, §9.4).
- [ ] Reference template: integration report; dossier addendum shape for
      logic-changing resolutions.
- [ ] Repo docs: root `README.md` plugin catalog lists tsf; the consumer
      README covers the whole v1 flow and the `/loop` runner; repo
      `CLAUDE.md` gains the tsf rule sections the implementation established
      (at least: the dispatcher-owns-writes seam, the `cycle` unflagged
      rule, the contract-script rule, whatever same-commit spans the three
      slices created).
- [ ] `claude plugin validate` passes for the marketplace and the plugin;
      version `1.0.0` in both manifests; `claude plugin tag ./plugins/tsf`
      creates `tsf--v1.0.0`.
- [ ] End-to-end smoke test (manual): on the scratch project, two approved
      PRs land in consecutive cycles, the second after a server-side sync;
      a deliberately conflicting third one is resolved and classified by the
      integrate agent.

## Out of Scope

- The release/deploy step (DESIGN.md §15 item 2) and everything else in §14.
- The consumer project's own changes (handover document there).

## Questions for Research/Planning

- [ ] The exact REST calls for update-branch, merge, and branch deletion,
      and their failure shapes (conflict, ruleset refusal, proxy denial).
- [ ] How the dispatcher computes the main-branch delta since approval for
      the integration gate (approval timestamp → merge-base at that time).

## References

- `plugins/tsf/DESIGN.md` v1.2 — §4 row 12, §7 gate 4, §9.2–9.4, §11
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
  (follow-up section: merge and update-branch affordances, exit codes)
- Epic: `TP-0034-implement-tsf-plugin-v1.md`; predecessor `TP-0034b`

## Implementation Plan

## Notes & Updates

### 2026-09-15

- Created as the last of three slices when TP-0034 became an epic. Carries
  the consumer-side spike as a dependency rather than as its own criterion.
