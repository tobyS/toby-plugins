# TP-0034: Implement the tsf plugin v1 per DESIGN.md (epic)

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-08-11
**Updated:** 2026-09-15

**Epic.** The work is carried by three sub-tickets, implemented in order;
this ticket holds the whole-plugin outcome and is done when all three are:

1. `TP-0034a` — foundation, init, spec, and the cycle up to plan approval.
2. `TP-0034b` — implementation, verification pipeline, and the dossier.
3. `TP-0034c` — landing loop, integration gate, and the 1.0.0 release.

**Precondition:** the `tsf-design` branch is merged to `main` before slice 1
starts. The repo rule is to work on `main`; the design work happened on a
branch only because it predates its ticket number. Implementation commits
land on `main`.

## Problem Statement

The tsf (Toby Software Factory) design is agreed and committed
(`plugins/tsf/DESIGN.md` v1.4, background review in
`thoughts/shared/research/2026-07-07-tce-software-factory-review.md`), but no
implementation exists — `plugins/tsf/` contains only the design document.
Until the plugin is built, the factory workflow it describes (autonomous
backlog work over GitHub issues with async human gates) cannot be used or
iterated on with real runs.

## Desired Outcome

A complete, installable v1 of the tsf plugin in this marketplace,
implementing the design document in full. When done:
`/plugin install tsf@toby-plugins` works in a consuming project; `/tsf:init`
sets the project up; `/tsf:spec` authors a spec and establishes the ticket triple interactively
(§3.1, §6.1);
`/tsf:cycle` advances the highest-priority actionable ticket exactly one
step; `/loop /tsf:cycle` runs the factory. `DESIGN.md` is the binding
specification — deviations discovered during implementation are surfaced,
not silently made.

## User Stories / Use Cases

- As a single-engineer project owner, I want to release issues to the factory
  by labeling them `tsf:queued` so that tickets advance to reviewed PRs without
  me babysitting generation, and after my one approving review the factory
  lands the work without me.
- As the reviewing human, I want plan summaries, batched questions, and a final
  dossier on GitHub so that each of my interactions is short and maximally
  informed.
- As a marketplace consumer, I want tsf installable and initializable like
  tce/tmt so that setup follows the familiar plugin conventions.

## Acceptance Criteria (epic level)

The detailed criteria live in the sub-tickets. The epic is done when:

- [ ] TP-0034a, TP-0034b and TP-0034c are Done.
- [ ] `plugins/tsf/` matches the layout in DESIGN.md §12 (three commands,
      7 workers + 4 gates, reference templates, `scripts/`, `templates/tsf/`
      with the contract-script skeletons, `templates/github/` with the
      comment-pickup workflow); `.claude-plugin/marketplace.json` lists tsf;
      `claude plugin validate` passes for both; the version followed the
      release plan of §12 (0.1.0 → 0.2.0 → 1.0.0) and `tsf--v1.0.0` is
      tagged.
- [ ] The plugin is project-agnostic (no stack, path or project literals;
      everything from `.claude/tsf/config.md` at runtime) and reads and
      writes only `tsf:*` labels (§3.4).
- [ ] The design's cross-cutting rules hold across all three slices: the
      dispatcher owns every GitHub write (§11.3); `/tsf:cycle` runs every
      REST call and push as the factory identity resolved from the
      configured credential source, while `/tsf:spec` and `/tsf:init` use
      the human's ambient login deliberately (§6.1, §10, §12); the gates
      are mechanically read-only;
      every agent is dispatched with a fresh context and in the
      foreground — no agent or background shell is still running when a
      cycle ends (§5.1 step 5, §7, §16.25); the issue is the only
      conversation channel — questions, plan summaries and replies are
      issue comments, the polling fallback reads issue comments only, and
      the factory never reads free-text PR comments (§3.4, §10); PRs are
      never drafts; every GitHub operation is REST (`gh api`), never
      GraphQL-backed porcelain, and no GraphQL-only operation is needed
      (§10); exactly one `tsf:*` state label per factory ticket at a time
      until it lands — the merge cycle leaves the closed issue with none
      (§3.4); the journal is append-only (§3.3); the scan reads open
      issues only (§5.1, §9.4); document skeletons ship as reference
      templates that every command or agent reads from
      `${CLAUDE_PLUGIN_ROOT}/references/templates/` at the point of use,
      never earlier (§6; `cycle.md` runs under `/loop` in a compacted
      session, §5.3); the logic head and the three-dot PR diff
      with `thoughts/` excluded are the shared definitions for report
      staleness, approval validity and every gate's diff — no base commit
      is recorded anywhere (§3.5); the runner session is opened in the
      factory clone, which is the project directory (§5.3, §8); `cycle`
      unflagged, `init` and `spec` flagged (§12); nothing written to the
      repository after the merge, and no repository write in the merge
      cycle — its only post-merge writes are GitHub writes: the state-label
      removal and, where the repository setting is off, the remote branch
      deletion (§3.2, §9.3 step 5, §9.4).
- [ ] Repo docs updated: root `README.md` catalog (TP-0034c); repo
      `CLAUDE.md` tsf rule sections, each slice recording the same-commit
      spans it creates in its own commit.

## Out of Scope

- Everything DESIGN.md §14 lists as v1 non-goals: parallel
  execution/worktrees/multiple factory instances, configurable priority or
  gate family, auto-pickup without human release, telemetry, GitHub merge
  queue and auto-merge, a release/deploy step, draft PRs, ticket-backend
  abstraction, incident feedback loop, running tce and tsf side by side;
  and, from §15 item 3, a GitHub Action or webhook that starts a cycle (the
  shipped pickup workflow only relabels).
- The `claude -p` while-loop runner (§5.3 "Future").
- Any changes to the tce or tmt plugins; any dependency between tsf and tce
  (§2).
- The first consumer project's own changes (its handover document lists
  them).
- Design changes: material deviations from DESIGN.md require discussion, not
  unilateral redesign.

## Open Questions

None at design level — v1 was agreed on 2026-08-11 (DESIGN.md §13), v1.1,
v1.2, v1.3 and v1.4 on 2026-09-15 (DESIGN.md §16). The platform-driven planning
decisions (§16.14 and the §12 planning note: inline vs nested work in the
steps (§11), a machine-readable part of `config.md`, where the allowlist is
written) are carried by TP-0034a's planning questions; the `/loop` runner and the invocation flag
are decided (§16.24), and the gates' `tools:` list is fixed in §11.2.

## References

- `plugins/tsf/DESIGN.md` — the binding design (v1.4, 2026-09-15; §16 holds
  the revision reasoning)
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
  — platform facts and house style for the implementation (shared by all
  three sub-tickets; re-verify `gh`-porcelain findings against the REST-only
  rule)
- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` —
  background review
- Repo `CLAUDE.md` — marketplace conventions (plugin layout, project-agnostic
  rule, versioning, release flow)

## Implementation Plan

Per sub-ticket; none at epic level.

## Notes & Updates

### 2026-09-15

- DESIGN.md revised to v1.4 after a second consistency review of the state
  machine (§16.40 to §16.48): a landing whose combination fails CI
  re-enters verification, row 10 reads its reference points from GitHub
  rather than the journal, the journal's `Next step` is the derived state,
  the logic head and the three-dot PR diff are defined once (§3.5, no
  recorded base commit), "actionable" is defined with one landing in
  flight, the merge cycle checks `mergeable_state` first and strips the
  state label after the merge, the runner session is opened in the clone,
  and `/tsf:spec` writes over REST. The sub-tickets were aligned to it.
- DESIGN.md revised to v1.3 after a consistency review of the design and
  the tickets (§16.30 to §16.39): the landing splits into a decision cycle
  and a write-free merge cycle, changes-requested reviews get a recency
  rule, plan deviations become plan addenda, fix mode is specified with
  numbered gate reports, distillation is a fixed mapping, the factory
  identity's credential source is configuration, and the release plan runs
  0.1.0 → 0.2.0 → 1.0.0 across the slices. The sub-tickets were aligned:
  versions per slice, CLAUDE.md rule sections per slice, a second GitHub
  account in the smoke tests, `tsf:integrate` renamed `tsf:merge-resolver`.
- DESIGN.md revised to v1.1 after the fit review against chat-sustainability
  and the landing-design discussion (reasoning in DESIGN.md §16), then to
  v1.2 after the simplification pass (§16.22 to §16.29): no draft PRs, the
  dispatcher owns every write, `/loop` is the runner and `/tsf:run` is gone,
  the gates share one cycle, no release step, server-side sync first, one
  `tsf:answered` label. Design decisions from the review: §16.15 to §16.21.
- Converted into an epic with three sub-tickets (TP-0034a/b/c) by explicit
  user decision: the plan for the whole plugin would be re-read in full at
  every implementation phase, and each slice is usable on its own. The
  original acceptance criteria moved into the sub-tickets; this ticket keeps
  the epic-level ones.

### 2026-09-11

- Renumbered from TP-0025 to TP-0034: the branch was created before `main`
  assigned TP-0025 to the tle plugin, and the `tsf-design` branch was rebased
  onto current `main` on this date. The research document was renamed to
  match. Commit messages from before the rebase still say TP-0025.

### 2026-08-11

- Ticket created from the agreed DESIGN.md; single ticket for the full
  greenfield implementation per explicit user decision (superseded on
  2026-09-15 by the epic split).
- All design-level questions are settled (DESIGN.md §13); remaining questions
  are implementation-mechanical and deferred to research/planning.
