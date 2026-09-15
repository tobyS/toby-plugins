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

`/tsf:cycle` handles DESIGN.md §4 row 12: at most one landing **in
flight**, oldest approval first (every other `tsf:landing` ticket is not
actionable while one awaits CI, §5.2), each landing at least a decision
cycle followed by a write-free merge cycle; sync by the REST update-branch
endpoint, the merge-resolver agent only on conflict with classification;
the integration gate when the main branch moved; a CI-red combination
re-entering verification; the decide-and-record rule on the logic head;
the `mergeable_state` check and the REST squash merge with the PR title as
subject; the state-label removal after the merge; branch deletion
fallback; no repository write in the merge cycle or after the merge. tsf
1.0.0 is tagged and listed in the marketplace catalog.

## Dependencies

- TP-0034b implemented.
- The consumer-side spike from `plugins/tsf/DESIGN.md` §9.3, run in the
  first consumer project's sandbox (its issue #62 walk-through): the REST
  merge and update-branch endpoints are accepted for the factory identity by
  the proxy and by the ruleset with one required approving review, and the
  identity the server-made sync commit carries is known. Its outcome is
  recorded in this ticket's plan and selects the mechanism per operation —
  REST for the merge and for the update-branch sync, or, for whichever of
  the two the sandbox or ruleset refuses, the label-bridge fallback with an
  App token (§10).

## Acceptance Criteria

- [ ] Agents `tsf:merge-resolver` (§9.3 step 1, §11.1; inputs: the
      approved PR whose server-side sync conflicted, the main branch's
      delta and the merge state in the clone; the worker tool set incl.
      local `git merge`/commit, no `gh`, never push; returns the
      resolution's classification, its journal entry and one comment) and
      `tsf:integration` (gate 4, §7, §11.2; mechanically read-only,
      `tools: Read, Grep, Glob`, three-part envelope, context-starved by
      hard prompt constraint: it receives exactly its §11.2 inputs in the
      spawn prompt — the PR diff of §3.5, the main delta since the
      approval or since the last integration report's recorded main head,
      `spec.md` — may read the post-merge source files in the clone, which
      holds the merged head via `prepare` after a clean server-side sync
      or via the merge-resolver's local merge commit on the conflict path
      (no `prepare` after the resolver), and must never see research,
      plan, journal or any transcript); both dispatched in the foreground
      like every other agent (§5.1 step 5, §7); descriptions begin
      "Internal to `/tsf:cycle` — not for direct use".
- [ ] `/tsf:cycle` row 12 (§9.3 steps 1–5), landing tickets now actionable
      and picked before all other work (§5.2 rule 1), with at most one
      landing in flight (oldest approval first, §9.3) and the other
      `tsf:landing` tickets skipped by the pick as not actionable, and — while CI on the decided head is pending — the
      in-flight landing ticket itself not actionable either: the pick
      moves on to non-landing work, the closing report names the pending
      head for `/loop` pacing, and the cycle ends idle only when nothing
      at all is actionable (§5.1 step 7, §5.2, §16.45): REST
      update-branch first (merge, never rebase,
      never force-push, §9.3 step 1), then `prepare` again so the clone
      holds the merged head; clone merge (`git merge`) by the merge-resolver
      agent on conflict with mechanical/logic classification and journaled
      reasoning (a mechanical resolution does not advance the logic head, a
      logic one does, §3.5), unresolvable → `tsf:needs-human` with the
      concrete decision; integration gate only when main moved since the
      approval or, on a restarted landing, since the main head the last
      `integration-<n>.md` recorded — inputs the PR diff of §3.5, the main
      delta and the spec, verdict safe/risk, reports numbered per landing
      attempt and each summarized by the dispatcher in a one-line PR
      comment like the other three gates (§7 gate 4, §10); CI red on the
      decided head → the ticket leaves landing for `tsf:verify` as a new
      verification episode, the transition journaled with its episode
      number exactly as the implement and rework entries are (§6.7; the
      third episode source, added in this slice) — verify-fix, gates on
      the new logic head, dossier addendum, `tsf:needs-review`,
      re-approval through row 10, then the landing restarts at the sync
      (§9.3 step 3, §16.40); decide-and-record (up to date, mechanical or no
      resolution, gate safe or skipped, latest approving review's
      `commit_id` at or after the logic head → landing decision entry
      naming the head, committed and pushed with the integration report —
      the decision cycle otherwise runs the standard §5.1 write phase:
      journal entry committed and pushed, one summary comment on the
      issue (the merge-resolver's comment when it ran, §9.3 step 1, §10),
      the label unchanged) or dossier addendum stating what was decided
      and why + `tsf:needs-review`; a later write-free cycle, entered
      once the check on the decided head has finished: it first confirms
      the decided head is still the PR head — moved (a human pushed) →
      the decision is void, restart at the sync silently; unchanged and
      CI red on it → step 3's exit to `tsf:verify`; unchanged and green →
      it reads the PR's `mergeable_state`: `behind` voids the decision
      and restarts at the sync silently, never the §10 retry-then-park
      rule; `clean` → merge over REST (squash, PR title as subject) (the
      cycle that performs the merge writes nothing to the repository and
      posts no comment, §3.3, §9.3 step 5); merge, sync and branch-delete calls go through
      the REST helper's read-back and retry rule (§10), while a sync
      conflict and a
      `behind` state are routine outcomes, never retry-then-park; after
      the merge its only remaining writes are GitHub writes: the label
      PATCH removing the `tsf:*` state label without a replacement (the
      slice-1 helper gains this mode, §3.4, §9.3 step 5) and,
      where the repository setting is off, the remote branch deletion over
      REST (§9.4); the next prepare prunes; no repository write in the
      merge cycle or after the merge (§3.2, §3.3, §9.4, §16.30, §16.46,
      §16.48).
- [ ] Reference template: integration report (the `head:` line naming the
      logic head it judged as every report does, §7, plus a separate line
      recording the main head it judged, which a restarted landing
      compares against, §9.3 step 2); landing decision journal entry
      ("merge when CI on head `<sha>` is green", §3.3, §9.3 step 4);
      the slice-2 dossier addendum template extended for a step-4 refusal
      (a logic-changing resolution among its causes).
- [ ] Repo docs: root `README.md` plugin catalog lists tsf; the consumer
      README covers the whole v1 flow, the `/loop` runner, the two-cycle
      landing and the ruleset settings the landing relies on, including
      that "dismiss stale reviews on push" and "require approval of the
      last push" stay off (§9.2); repo `CLAUDE.md` gains the tsf rule
      sections for
      the same-commit spans this slice creates (at least: the landing
      decision/merge split, the one-landing-in-flight rule, and the
      no-path-filter CI requirement), slices 1 and 2 having recorded
      theirs.
- [ ] `claude plugin validate` passes for the marketplace and the plugin;
      version `1.0.0` in both manifests (from `0.2.0`, §12 release plan);
      `claude plugin tag ./plugins/tsf` creates `tsf--v1.0.0`.
- [ ] End-to-end smoke test (manual): on the scratch project, two approved
      PRs land, each across its decision and merge cycles, the second not
      actionable while the first awaits CI and landing after a server-side
      sync; a deliberately conflicting third one is resolved and classified
      by the merge-resolver agent; each landed issue is closed with no
      `tsf:*` state label and is never picked again.

## Out of Scope

- The release/deploy step (DESIGN.md §15 item 2) and everything else in §14.
- The consumer project's own changes (handover document there).

## Questions for Research/Planning

- [ ] The exact REST calls for update-branch, merge, and branch deletion,
      and their failure shapes (conflict, ruleset refusal, proxy denial);
      and the handling of the `mergeable_state` values the design does not
      name — `dirty` (main moved with a conflict: restart at the sync,
      where the merge-resolver handles it), `blocked`, `unstable`,
      `unknown` — so none falls into retry-then-park.
- [ ] How the dispatcher computes the main-branch delta since approval for
      the integration gate (from the approving review's `commit_id` and its
      merge-base with main, or from the main head recorded in the last
      integration report on a restarted landing, §9.3 step 2), and how it
      detects that main moved at all.
- [ ] How the dispatcher identifies mechanical sync merges when computing
      the logic head (§3.5): server-made update-branch merge commits and
      merge-resolver resolutions classified mechanical.
- [ ] Whether a decision cycle in which the merge-resolver ran writes one
      combined journal entry (§3.3: one entry per cycle) covering both
      the resolution (§9.3 step 1) and the landing decision (step 4), or
      two.
- [ ] What a post-merge write failure does: a label PATCH or branch
      deletion that fails twice would, under §10, park the ticket
      `tsf:needs-human` — a state label on a closed issue the open-only
      scan never reads again (§5.1, §9.4); how the failure is surfaced
      instead.
- [ ] Which SHA the landing decision entry names (the logic head, since
      the entry's own commit cannot be known before it is written) and how
      the merge cycle identifies the decided PR head — e.g. the commit
      that introduced the decision entry — so "head unchanged" and "CI
      green on it" are checked against the commit the required check
      actually ran on (§3.3, §9.3 steps 4–5).

## References

- `plugins/tsf/DESIGN.md` v1.4 — §3.3, §3.5, §4 row 12, §5.2, §7 gate 4,
  §9.2–9.4, §11, §16.30, §16.40, §16.45, §16.46, §16.48
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
- Aligned with DESIGN.md v1.4: one landing in flight (§16.45), a CI-red
  combination re-enters verification instead of "verify-fix as usual"
  (§16.40), the decision compares the approval's `commit_id` with the
  logic head (§16.41, §16.43), the merge cycle checks `mergeable_state`
  first and integration reports are numbered per landing attempt
  (§16.46), the merge strips the state label (§16.48).
- Aligned with DESIGN.md v1.3: the landing is a decision cycle plus a
  write-free merge cycle (§16.30), `tsf:integrate` renamed
  `tsf:merge-resolver`, `prepare` after a server-side sync, CLAUDE.md
  sections limited to this slice's spans, smoke test reworded, research
  reference caveated.
