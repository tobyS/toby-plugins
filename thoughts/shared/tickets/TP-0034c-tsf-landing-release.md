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
cycle, oldest approval first, each landing a decision cycle followed by a
write-free merge cycle; sync by the REST update-branch endpoint, the
merge-resolver agent only on conflict with classification; the integration
gate when the main branch moved; the decide-and-record rule; the REST
squash merge with the PR title as subject; branch deletion fallback;
nothing written in the merge cycle or after the merge. tsf 1.0.0 is tagged
and listed in the marketplace catalog.

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

- [ ] Agents `tsf:merge-resolver` (§9.3, §11.1) and `tsf:integration` (gate
      4, §7, §11.2; read-only, three-part envelope); descriptions begin
      "Internal to `/tsf:cycle` — not for direct use".
- [ ] `/tsf:cycle` row 12 (§9.3 steps 1–5): REST update-branch first, then
      `prepare` again so the clone holds the merged head; clone merge by the
      merge-resolver agent on conflict with mechanical/logic classification
      and journaled reasoning, unresolvable → `tsf:needs-human` with the
      concrete decision; integration gate only when main moved since
      approval, verdict safe/risk; verify-fix on red CI as usual;
      decide-and-record (up to date, mechanical or no resolution, gate safe
      or skipped, latest approval newer than the last logic-changing push →
      landing decision entry naming the head, committed and pushed with the
      integration report) or dossier addendum + `tsf:needs-review`; a later
      write-free cycle merges over REST (squash, PR title as subject) when
      the decided head is unchanged and CI on it is green, and restarts at
      the sync when the head moved; remote branch deleted when the
      repository setting is off; the next prepare prunes; no write in the
      merge cycle or after the merge (§3.2, §3.3, §9.4).
- [ ] Reference template: integration report (with the `head:` line);
      landing decision journal entry; dossier addendum shape for
      logic-changing resolutions.
- [ ] Repo docs: root `README.md` plugin catalog lists tsf; the consumer
      README covers the whole v1 flow, the `/loop` runner and the
      two-cycle landing; repo `CLAUDE.md` gains the tsf rule sections for
      the same-commit spans this slice creates (at least: the landing
      decision/merge split and the no-path-filter CI requirement), slices 1
      and 2 having recorded theirs.
- [ ] `claude plugin validate` passes for the marketplace and the plugin;
      version `1.0.0` in both manifests (from `0.2.0`, §12 release plan);
      `claude plugin tag ./plugins/tsf` creates `tsf--v1.0.0`.
- [ ] End-to-end smoke test (manual): on the scratch project, two approved
      PRs land, each across its decision and merge cycles, the second after
      a server-side sync; a deliberately conflicting third one is resolved
      and classified by the merge-resolver agent.

## Out of Scope

- The release/deploy step (DESIGN.md §15 item 2) and everything else in §14.
- The consumer project's own changes (handover document there).

## Questions for Research/Planning

- [ ] The exact REST calls for update-branch, merge, and branch deletion,
      and their failure shapes (conflict, ruleset refusal, proxy denial).
- [ ] How the dispatcher computes the main-branch delta since approval for
      the integration gate (approval timestamp → merge-base at that time).

## References

- `plugins/tsf/DESIGN.md` v1.3 — §3.3, §4 row 12, §7 gate 4, §9.2–9.4, §11,
  §16.30
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
  — note that its follow-up section describes `gh pr merge` /
  `gh pr update-branch` porcelain, which §10 forbids; the REST endpoints
  are this ticket's first planning question, and that section is
  superseded for everything but the behavioural facts (conflict reporting,
  head-SHA guard) it records.
- Epic: `TP-0034-implement-tsf-plugin-v1.md`; predecessor `TP-0034b`

## Implementation Plan

## Notes & Updates

### 2026-09-15

- Created as the last of three slices when TP-0034 became an epic. Carries
  the consumer-side spike as a dependency rather than as its own criterion.
- Aligned with DESIGN.md v1.3: the landing is a decision cycle plus a
  write-free merge cycle (§16.30), `tsf:integrate` renamed
  `tsf:merge-resolver`, `prepare` after a server-side sync, CLAUDE.md
  sections limited to this slice's spans, smoke test reworded, research
  reference caveated.
