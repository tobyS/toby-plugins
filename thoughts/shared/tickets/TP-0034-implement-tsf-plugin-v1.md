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
(`plugins/tsf/DESIGN.md` v1.3, background review in
`thoughts/shared/research/2026-07-07-tce-software-factory-review.md`), but no
implementation exists — `plugins/tsf/` contains only the design document.
Until the plugin is built, the factory workflow it describes (autonomous
backlog work over GitHub issues with async human gates) cannot be used or
iterated on with real runs.

## Desired Outcome

A complete, installable v1 of the tsf plugin in this marketplace,
implementing the design document in full. When done:
`/plugin install tsf@toby-plugins` works in a consuming project; `/tsf:init`
sets the project up; `/tsf:spec` authors a spec triple interactively;
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
      dispatcher owns every GitHub write (§11.3); the gates are mechanically
      read-only; PRs are never drafts; no GraphQL-only operation; `cycle`
      unflagged, `init` and `spec` flagged (§12); nothing written after the
      merge, and nothing written in the merge cycle (§3.2, §9.3).
- [ ] Repo docs updated: root `README.md` catalog (TP-0034c); repo
      `CLAUDE.md` tsf rule sections, each slice recording the same-commit
      spans it creates in its own commit.

## Out of Scope

- Everything DESIGN.md §14 lists as v1 non-goals: parallel
  execution/worktrees/multiple factory instances, configurable priority or
  gate family, auto-pickup without human release, telemetry, a GitHub Action
  or webhook that starts a cycle (the pickup workflow only relabels), GitHub
  merge queue and auto-merge, a release/deploy step, draft PRs, ticket-backend
  abstraction, incident feedback loop, running tce and tsf side by side.
- The `claude -p` while-loop runner (§5.3 "Future").
- Any changes to the tce or tmt plugins; any dependency between tsf and tce
  (§2).
- The first consumer project's own changes (its handover document lists
  them).
- Design changes: material deviations from DESIGN.md require discussion, not
  unilateral redesign.

## Open Questions

None at design level — v1 was agreed on 2026-08-11 (DESIGN.md §13), v1.1,
v1.2 and v1.3 on 2026-09-15 (DESIGN.md §16). The platform-driven planning
decisions (§16.14: inline vs nested work in the steps, a machine-readable
part of `config.md`, where the allowlist is written) are carried by the
sub-tickets' planning questions; the `/loop` runner and the invocation flag
are decided (§16.24), and the gates' `tools:` list is fixed in §11.2.

## References

- `plugins/tsf/DESIGN.md` — the binding design (v1.3, 2026-09-15; §16 holds
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
