# TP-0034b: tsf slice 2 — implementation, verification pipeline, and the dossier

**Status:** Done
**Estimated Complexity:** Large
**Created:** 2026-09-15
**Updated:** 2026-09-18

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

- [ ] Agents `tsf:implement` (normal, rework and fix modes, §6.6; working
      increment by increment with each increment's own verification run
      immediately after it is built and one commit per increment in the
      project's convention; plan deviations written as dated plan addenda
      that restate the affected increment's verification criteria, never
      journal-only; rework recording the requested changes as a plan
      addendum before implementing them (the review's comments passed in
      the spawn prompt by the dispatcher, §4 row 11, §11.1); fix mode
      fixing exactly what the failing reports evidence, the round counter
      derived from the report filenames; a
      plan mismatch too large for an addendum parks the ticket
      `tsf:needs-answer` with a batched question comment, and answer
      distillation (§6.3, §4 row 1; performed as in TP-0034a) gains the
      implement mapping: the dispatcher derives the target artifact
      (`plan.md`) from the journal's last transition and passes the reply
      in the spawn prompt; `tsf:plan` folds it into `plan.md` as a commit,
      re-summarizes, and the ticket goes back through the plan gate), `tsf:verify-fix` (§6.7; CI red diagnosed by local
      reproduction first, check logs only when reachable, the CI results
      passed in by the dispatcher, §11.1), `tsf:dossier`
      (§9.1; the dispatcher passes the PR diff, the PR's current title
      and body, and the other open factory PRs with their touched files
      in the spawn prompt, since the agent has no `gh`, §11.1) per the §6 common contract and with the §11.1
      worker tool set in frontmatter (no `gh`, never push; the `Agent`
      question decided in TP-0034a); the four-gate roster's first three,
      `tsf:plan-compliance`,
      `tsf:spec-coverage`, `tsf:security`, mechanically read-only
      (`tools: Read, Grep, Glob`), each with the three-part constraint
      envelope, context-starved by hard prompt constraint and receiving
      exactly its §11.2 inputs in the spawn prompt — plan-compliance:
      per-increment criteria + diff, returning one evidenced verdict per
      criterion (met / not met / cannot verify from diff / needs human
      verification), the last never silently passed but carried into the
      dossier's open items (§7, §9.1); spec-coverage: `spec.md` + diff,
      never research or plan; security: diff, may read the touched files'
      surroundings, never `thoughts/` docs — never a transcript; the
      security gate classifying findings blocking/advisory (§7); all
      descriptions begin "Internal to `/tsf:cycle` — not for
      direct use".
- [ ] `/tsf:cycle` rows 5–11: the slice-1 scan helper gains the PR per
      ticket branch, the check runs and review state per PR head, and the
      `created_at` of the factory's last dossier or addendum comment on
      the PR (§5.1 step 1, §4 row 10, REST only, §10); after implement the dispatcher pushes and
      opens the PR from the pr-body template — **never a draft** — with
      title `<type>(GH-<n>): <spec title>` in the project's commit
      convention (the squash commit's subject, §9.3) and a body carrying
      the closing keyword, the spec link, the plan summary and the
      artifact links (§6.6, §10), and records the PR number in the issue's
      marker block at PR creation and in the next journal entry (the
      opening cycle's entry is committed before the PR exists, §3.2, §5.1,
      §6.6); PR creation, the gate comments and the dossier comment go
      through the REST helper's read-back and retry rule (§10); local
      verification through
      the project's `verify` script, CI read at pickup on the PR head, mode
      `local` | `ci` (§7); a ticket whose local verification is green (or
      whose mode is `ci`) and whose CI is pending is **not actionable** —
      local red goes to verify-fix first — the pick moves on and the
      closing report names the pending head for `/loop` pacing (§4 rows
      6–7, §5.2); verify-fix bounded
      per episode by the config's verify-fix attempt bound (§12) with
      `reports/verify-fix-<episode>-<attempt>.md`, every transition into
      `tsf:verify` (from implement, from rework) journaled with its
      episode number and the attempt counter derived from the files — a
      fix-mode return to `tsf:verify` stays within the current episode
      (the round counter advances, the episode number does not); only
      implement, rework (and, in TP-0034c, a CI-red landing) open a new
      one — exhausted → `tsf:needs-human` with a summary of what was tried
      (CI-red-with-local-green reported as an environment difference,
      §6.7); the three gates dispatched in parallel and in the
      foreground, each receiving the **PR diff** — the three-dot diff
      against the base branch with `thoughts/` excluded, computed by the
      dispatcher, no base commit recorded anywhere (§3.5, §11.2) — the
      dispatcher writing the three reports as
      `reports/<gate>-<episode>-<round>.md` whose first line
      `head: <sha>` names the **logic head** (§3.5; never the plain PR
      head) and posting one
      one-line PR comment per gate summarizing its verdict (§7, §3.4, §10
      — with the integration gate's comment joining in TP-0034c, the only
      factory PR comments besides the dossier and its addenda),
      re-running the gates when a report is missing or names another
      logic head, and routing any "not met" or blocking finding to
      implement in fix mode — entered by the dispatcher from the reports
      on disk, never by a label; the ticket stays `tsf:verify` (§6.6) —
      bounded by `gate_fix_bound`, exhausted →
      `tsf:needs-human` with the last reports linked, all three green →
      `tsf:dossier` ends the gate cycle (§4 row 8, §6.6, §7); the next
      cycle (row 9) runs `tsf:dossier`: dossier written to
      `reports/dossier.md` on the branch and posted to the PR as a
      factory-identity comment with the five sections of §9.1,
      PR title/body validated, `tsf:needs-review` set; row 10 read from
      GitHub, never from the journal (§3.3, §16.41): the reviewer's latest
      review counts; an approving review whose `commit_id` is at or after
      the logic head → `tsf:landing` (in this slice a `tsf:landing` ticket
      is **not actionable**: the pick skips it and the closing report
      names it as "landing not implemented in this slice" — it never ends
      the cycle while other tickets are actionable, §5.2), an approval
      behind the logic head is
      stale and the ticket stays parked; a changes-requested review whose
      `submitted_at` is newer than the `created_at` of the factory's last
      dossier or addendum comment → `tsf:rework`, an older one ignored (§4
      row 10, §9.1, §9.2); rework returns the ticket to `tsf:verify` as a
      new verification episode, with the gates re-run on the new logic
      head and a dossier addendum (§4 row 11, §6.7).
- [ ] Environment contract execution: `env_up` in every
      implementation-flavored cycle (idempotent), `env_reset` on ticket
      switch, `env_check` when registered, failure → `tsf:needs-human` (§8).
- [ ] Reference templates: report (first line `head: <sha>` naming the
      logic head), dossier (incl. the addendum shape and the closing line that
      free-text PR comments are not read, §9.1, §10), pr-body (title
      `<type>(GH-<n>): <spec title>`, body with closing keyword, spec
      link, plan summary, artifact links, §6.6); the plan-compliance gate
      receives the plan's per-increment criteria
      (addenda included) and the PR diff of §3.5 — never a recorded base
      commit (§7, §11.2, §16.44).
- [ ] Project-agnostic: no stack, path or project literals.
- [ ] Version bumped to `0.2.0` in both manifests (§12 release plan); the
      consumer `README.md` states the slice 2 scope (implementation
      through review, landing not yet); repo
      `CLAUDE.md` gains the tsf rule sections for the same-commit spans this
      slice creates (at least: the gate-report contract, the fix-mode
      routing, the environment-contract cadence, the logic-head and
      PR-diff definitions of §3.5 shared by the dispatcher and the gates).
- [~] **Deferred to the first real factory setup** (agreed 2026-09-18, the same
      decision as TP-0034a's): the smoke test runs when tsf is first used on a
      real project, which needs the same second GitHub account, ruleset and
      factory clone anyway and exercises them for real. TP-0034c's smoke test
      inherits that setup.
      Smoke test (manual): on the scratch project (factory identity = the
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
- [ ] How the dispatcher computes the logic head (§3.5) from the branch's
      git history in this slice — with no mechanical sync merges before
      TP-0034c, the rule reduces to "newest commit touching a path outside
      `thoughts/`" — and compares it with a review's `commit_id`.
- [ ] Concurrency: three foreground gates per cycle against the per-session
      subagent cap (20).
- [ ] How the pick learns "local green" for a not-yet-picked `tsf:verify`
      ticket (§4 rows 6–7 make actionability depend on the local
      verification result, but §5.1 runs `prepare`/`env_up`/`verify` only
      after the pick): run `verify` as part of the pick, or reuse a result
      recorded by a prior cycle.

## References

- `plugins/tsf/DESIGN.md` v1.4 — §3.5, §4 rows 5–11, §5.2, §6.6, §6.7, §7,
  §8, §9.1, §9.2, §11.1–11.4, §16.41, §16.43–16.45
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
- Epic: `TP-0034-implement-tsf-plugin-v1.md`; predecessor `TP-0034a`

## Implementation Plan

## Notes & Updates

### 2026-09-15

- Created as the second of three slices when TP-0034 became an epic.
- Aligned with DESIGN.md v1.4: gate reports name the logic head and the
  gates receive the three-dot PR diff with `thoughts/` excluded, no
  recorded base commit (§16.43, §16.44); row 10 reads the review's
  `commit_id` and the dossier comment's `created_at` from GitHub; no
  journal timestamp serves as row 10's reference point (§3.3, §16.41); the PR number goes into the marker block
  at creation and the next journal entry; a CI-pending ticket is not
  actionable (§16.45); rework opens a new verification episode.
- Aligned with DESIGN.md v1.3: fix mode and `gate_fix_bound`, numbered gate
  reports with a `head:` line, plan deviations as addenda, the
  changes-requested recency rule, `env_up` every implementation cycle,
  version `0.2.0`, CLAUDE.md sections per slice, second GitHub account in
  the smoke test.

### 2026-09-18

- Implemented in seven phases; see
  `thoughts/shared/plans/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`.
- The plan-compliance gate found two defects on its first run, both fixed
  before it passed: the dossier's inputs could not be produced (the read
  helper returned no pull-request body, and nothing sourced the touched files
  for the overlap warning), and the verify-fix attempt counter derived from
  report files nothing wrote, so `verify_fix_bound` was unreachable.
- Two deviations from DESIGN.md, agreed with the user and recorded in the plan:
  verification **attempts** the plan's manual items through a dedicated agent
  before escalating any of them, and the dossier opens with a rated executive
  summary above the five §9.1 sections.
- The end-to-end smoke test is deferred to the first real factory setup (see
  the acceptance criterion); the README was confirmed by the user.
