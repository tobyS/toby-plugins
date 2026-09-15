# TP-0034a: tsf slice 1 — foundation, init, spec, and the cycle up to plan approval

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-09-15
**Updated:** 2026-09-15

Sub-ticket of TP-0034 (the epic). First of three slices; the others are
TP-0034b (implementation, verification, dossier) and TP-0034c (landing).

## Problem Statement

The tsf design (`plugins/tsf/DESIGN.md`, v1.3) is agreed but nothing of it
exists. The first slice is everything a factory needs before it touches code:
the plugin scaffold, project setup, spec authoring, and the dispatcher cycle
for the steps that end at the plan gate. After this slice a consumer can
release a ticket and get research and a plan summary to approve — the
factory's human interface is real and can be judged on real tickets.

## Desired Outcome

`/plugin install tsf@toby-plugins` works; `/tsf:init` sets a project up
(config, contract check, labels, pickup workflow); `/tsf:spec` creates the
ticket triple; `/tsf:cycle` advances a ticket through triage, research and
plan, parks it with batched questions or the plan summary, picks the human's
reply up, and ends at `tsf:implement`. `/loop /tsf:cycle` drives it. The
dispatcher owns every GitHub write (§11.3) from the start, so later slices
add agents and dispatch-table rows without touching the write path.

## Acceptance Criteria

- [ ] Scaffold per DESIGN.md §12: `.claude-plugin/plugin.json` (name `tsf`,
      version `0.1.0` per the §12 release plan), the marketplace entry at
      the same version, a consumer-facing `README.md`
      (slice 1 scope stated), `commands/{init,spec,cycle}.md`,
      `templates/tsf/config.md`, `templates/tsf/scripts/` skeletons for the
      four mandatory contract commands (§8), `templates/github/` with the
      comment-pickup workflow, `scripts/lib.sh`. `claude plugin validate .`
      and `claude plugin validate ./plugins/tsf` pass.
- [ ] `scripts/` holds the REST scan helper and the one REST write helper
      (§11.3): comment, label set (full-set PATCH, re-read immediately
      before the write, non-`tsf:*` labels passed through), issue marker
      block, each write read back with one retry (§10); no `gh` porcelain
      anywhere.
- [ ] `/tsf:init` (flagged `disable-model-invocation: true`): analyzes the
      project (seeding from `.claude/tce/profile.md` when present, §2), writes
      `.claude/tsf/config.md` (line-1 `tsf-config-version` marker, profile,
      GitHub coordinates, branch pattern, factory identity login and
      credential source, responders, contract script paths, verification
      mode, constants incl. `gate_fix_bound`), runs the contract check and
      refuses to finish with a mandatory script missing while offering the
      skeletons, creates the `tsf:*` labels with family colours over REST,
      verifies `gh` auth as the factory identity (login equals the
      configured one and is not a responder), offers the allowlist, offers
      the pickup workflow with the responders baked in, prints the ruleset
      checklist incl. the no-path-filter CI requirement (§12). Idempotent on
      re-run, comparing the version marker.
- [ ] `/tsf:spec` (flagged): guided spec authoring to the sufficiency
      minimum, creates issue, branch, `spec.md`, pushes, offers `tsf:queued`
      (§6.1).
- [ ] `/tsf:cycle` (**unflagged**, §12): scan over REST, pick per §5.2,
      dispatch-table rows 1 to 4 and 13 of §4 (distill, triage, research,
      plan, skip parked), the prepare phase through the project's `prepare`
      script (creating a missing ticket branch from the base branch; run
      for the base branch on an idle cycle, §5.1, §8), foreground agent
      dispatch, the §11.3 write phase (journal entry committed and pushed,
      one comment, next label), the auto-continue rule,
      label/artifact-disagreement parking, resuming a `tsf:needs-human`
      ticket via `tsf:queued` (§3.4), and a closing report that states the
      suggested wait for the self-paced `/loop` (§5.3). Every REST call and
      push runs as the factory identity (§12). Rows for later slices end
      the cycle with "not implemented in this slice".
- [ ] Agents `tsf:triage`, `tsf:research`, `tsf:plan` per §6.2, §6.4, §6.5
      and the §6 common contract (re-read chain from disk, commit on the
      branch, return a result block, never push/comment/label); descriptions
      begin "Internal to `/tsf:cycle` — not for direct use".
- [ ] Reference templates: spec, research, plan (self-verifying increments,
      §6.5), journal entry, question comment (§10 shape), plan summary with
      file links to the branch.
- [ ] Answer distillation (§6.3) by the fixed mapping from the parking step
      recorded in the journal (triage/research → `spec.md`, plan gate →
      `plan.md`); polling fallback when the pickup workflow is absent
      (§3.4).
- [ ] Project-agnostic: no stack, path or project literals; everything from
      `.claude/tsf/config.md` at runtime.
- [ ] Repo `CLAUDE.md` gains the tsf rule sections for the same-commit spans
      this slice creates (at least: the dispatcher-owns-writes seam, the
      `cycle` unflagged rule, the contract-script rule).
- [ ] Smoke test (manual, per repo "Testing changes"): install in a scratch
      project with a real GitHub repo **and a second GitHub account as the
      factory identity** (the human's account is the responder), `/tsf:init`,
      `/tsf:spec`, then `/loop /tsf:cycle` until a ticket sits at
      `tsf:needs-plan-approval`; reply on the issue; the next cycle reaches
      `tsf:implement`.

## Out of Scope

- Implementation, verification, gates, dossier, review handling (TP-0034b).
- Landing, integration gate, merge, root README catalog, the `tsf--v1.0.0`
  tag (TP-0034c).
- Anything DESIGN.md §14 lists as a v1 non-goal.

## Questions for Research/Planning

- [ ] The exact result-block format agents return and how the dispatcher
      parses it (the research notes subagent output may carry a harness
      marker and escaped `<`).
- [ ] Whether `config.md` needs a machine-readable companion for the
      constants `scripts/` read (research open question 5).
- [ ] Where the allowlist is written given workspace-trust rules (research
      open question 6).
- [ ] How the closing report conveys the wait suggestion to the self-paced
      `/loop`.

## References

- `plugins/tsf/DESIGN.md` v1.3 — §2, §3, §4 rows 1–4, §5, §6.1–6.5, §8, §10,
  §11.1, §11.3, §12
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
- Epic: `TP-0034-implement-tsf-plugin-v1.md`

## Implementation Plan

## Notes & Updates

### 2026-09-15

- Created as the first of three slices when TP-0034 became an epic (context
  size per implementation phase; each slice is usable on its own).
- Aligned with DESIGN.md v1.3: version `0.1.0`, version marker, factory
  identity credential source and auth check, `prepare` creating the ticket
  branch, distillation by parking step, `tsf:needs-human` resume, CLAUDE.md
  sections per slice, second GitHub account in the smoke test.
