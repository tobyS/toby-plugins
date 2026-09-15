# TP-0034a: tsf slice 1 — foundation, init, spec, and the cycle up to plan approval

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-09-15
**Updated:** 2026-09-15

Sub-ticket of TP-0034 (the epic). First of three slices; the others are
TP-0034b (implementation, verification, dossier) and TP-0034c (landing).

## Problem Statement

The tsf design (`plugins/tsf/DESIGN.md`, v1.4) is agreed but nothing of it
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
      contract commands (§8; one per contract command, `env_check`
      included),
      `templates/github/` with the
      comment-pickup workflow (`issue_comment`; issue payload only, not a
      PR; `tsf:needs-answer` or `tsf:needs-plan-approval` present;
      commenter is a configured responder → label swapped to
      `tsf:answered`; anyone else changes nothing; built-in token, §3.4),
      `scripts/lib.sh`. `claude plugin validate .`
      and `claude plugin validate ./plugins/tsf` pass.
- [ ] `scripts/` holds the REST scan helper (open issues carrying a
      `tsf:*` state label only — closed issues are never read, §5.1, §9.4)
      and the one REST write helper (§11.3): comment, label set (full-set
      PATCH, re-read immediately before the write, non-`tsf:*` labels
      and the `tsf:priority` modifier passed through unchanged, the
      previous `tsf:*` state label replaced so exactly one state label
      remains, §3.4), issue marker block, each write read
      back, one retry on a transport error, a second failure parking the
      ticket `tsf:needs-human` with the failed operation journaled (§10);
      the helper and the push resolve the factory credential from the
      configured source explicitly, per call, never from the session's
      ambient `gh` login (§12) — the source has two forms: the default,
      `GH_TOKEN` in the clone's environment (init documents where it comes
      from), and a proxy injecting the credential by repository URL (§8),
      in which case the helper passes nothing; no `gh` porcelain anywhere.
- [ ] `/tsf:init` (flagged `disable-model-invocation: true`): analyzes the
      project (seeding from `.claude/tce/profile.md` when present, §2), writes
      `.claude/tsf/config.md` (line-1 `tsf-config-version` marker, profile,
      GitHub coordinates, branch pattern, factory identity login and
      credential source, responders, contract script paths, verification
      mode, constants incl. `gate_fix_bound`; **no clone path**, the
      runner session is opened in the clone, §5.3), runs the contract
      check — every mandatory script and every registered optional one
      must exist and be executable — and refuses to finish with a
      mandatory script missing, explaining per missing command what its
      script must do for this project, offering the skeleton (written only
      on confirmation) and stating what is still needed and how to re-run
      (§12), creates the `tsf:*` labels with family
      colours over REST, verifies the **factory credential** resolved from
      the configured source — not the session's own `gh` login, which is
      the human's — authenticates as the configured factory login and that
      this login is not a responder, offers the allowlist (covering the
      registered contract scripts), offers the pickup workflow with the
      responders baked in, prints the ruleset checklist incl. the
      no-path-filter CI requirement, and documents the dedicated-clone
      concerns (sandbox filesystem grant, per-checkout ports, §8) (§12).
      Idempotent on re-run, comparing the version marker.
- [ ] `/tsf:spec` (flagged): guided spec authoring to the sufficiency
      minimum, creates the issue (title + short human summary), then
      creates the ticket branch from the base branch's head and commits
      `spec.md` on it under `thoughts/factory/GH-<n>/` (§3.2; the
      canonical ID `GH-<n>` normalized from `#n`, bare numbers and issue
      URLs, §3.1) **over REST** (refs and contents endpoints — no
      checkout is touched, nothing is pushed from a working copy), appends
      the `<!-- tsf:links -->` marker block with the spec and branch links
      to the issue body (§3.2; §6.1 lists the block with the issue
      creation — it is appended once the branch exists, since its name
      derives from the issue number), and offers `tsf:queued`; runs under
      the human's ambient login deliberately (§6.1, §12).
- [ ] `/tsf:cycle` (**unflagged**, §12), run in the factory clone as the
      session's project directory (§5.3): the contract check at the start
      of every cycle (a missing mandatory command ends the cycle with a
      report, §12), scan over REST, pick per §5.2 (non-actionable tickets
      are skipped, the cycle ends idle only when none is actionable),
      dispatch-table rows 1 to 4 and 13 of §4 (distill, triage, research,
      plan, skip parked), the prepare phase through the project's `prepare`
      script (creating a missing ticket branch from the base branch; run
      for the base branch on an idle cycle, §5.1, §8), foreground agent
      dispatch, the §11.3 write phase (journal entry committed and pushed,
      the `<!-- tsf:links -->` marker block appended or updated on the
      issue with spec, branch and journal links without touching the
      original body (§3.2, §10), one comment, next label), the
      auto-continue rule, the derived state
      as the journal's last `Next step` line validated against the
      artifacts — a stale factory-side label is corrected, a disagreeing
      human-side label gets a journal entry describing the mismatch and
      parks the ticket `tsf:needs-human`, never a guess (§3.3, §3.4) —
      resuming a `tsf:needs-human` ticket via `tsf:queued` at the
      journal's `Next step` (§3.4, §4 row 3), and a closing report that
      states the suggested wait for the self-paced `/loop` (§5.3). Every
      REST call and push runs as the factory identity from the configured
      credential source (§12). A ticket whose row belongs to a later slice
      (`tsf:implement` onwards) is **not actionable** in this slice: the
      pick skips it and the closing report names it as "not implemented
      in this slice" — it never ends the cycle while other tickets are
      actionable (§5.2).
- [ ] Agents `tsf:triage`, `tsf:research`, `tsf:plan` per §6.2, §6.4, §6.5
      and the §6 common contract (re-read chain from disk, commit on the
      branch, return a result block, never push/comment/label), with the
      §11.1 worker tool set in frontmatter (file tools + Bash for local
      `git` and the project's commands, no `gh`; the dispatcher passes the
      issue body to `tsf:triage` in the spawn prompt, §11.1; whether
      `Agent` is omitted is the §11 planning decision); descriptions begin
      "Internal to `/tsf:cycle` — not for direct use".
- [ ] Reference templates: spec, research, plan (self-verifying increments,
      §6.5), journal entry (with the `Next step` line the dispatcher
      derives state from, §3.3), question comment (§10 shape), which the
      plan summary reuses with `plan.md`/`research.md` file links on the
      ticket branch and never the increment list (§6.5); every command and
      agent reads a template from the plugin's `references/templates/` at
      the point of use, never earlier (§6).
- [ ] Answer distillation (§6.3): the dispatcher derives the target
      artifact from the parking step recorded in the journal
      (triage/research → `spec.md`, plan gate → `plan.md`), reads the
      responder's reply over REST and passes it to the resumed step's
      agent in the spawn prompt; the agent folds it into that artifact as
      a commit (the dispatcher does no content work and the agent never
      reads GitHub, §5.1, §11.1, §11.3), and the dispatcher posts the
      one-line confirmation; at the plan gate the reply is the approval
      channel: an approving reply moves the ticket to `tsf:implement`,
      anything else is feedback that `tsf:plan` folds into `plan.md`
      (§11.1), revises, re-summarizes, and the ticket is parked
      `tsf:needs-plan-approval` again (§4 row 1, §6.3); polling fallback (issue comments only, one REST
      call per parked ticket) when the pickup workflow is absent, applying
      the same responder rule (§3.4).
- [ ] Project-agnostic: no stack, path or project literals; everything from
      `.claude/tsf/config.md` at runtime.
- [ ] Repo `CLAUDE.md` gains the tsf rule sections for the same-commit spans
      this slice creates (at least: the dispatcher-owns-writes seam, the
      `cycle` unflagged rule, the contract-script rule).
- [ ] Smoke test (manual, per repo "Testing changes"): install in a scratch
      project with a real GitHub repo **and a second GitHub account as the
      factory identity** (the human's account is the responder; the second
      account's token is what the configured credential source resolves
      to, e.g. `GH_TOKEN` exported in the factory clone's environment,
      §12), `/tsf:init` and `/tsf:spec`
      from the human's working copy, then `/loop /tsf:cycle` in a
      dedicated factory clone (§5.3, §8) until a ticket sits at
      `tsf:needs-plan-approval`; reply with feedback on the issue and see
      the plan revised and re-summarized; reply approvingly; the next
      cycle reaches `tsf:implement`.

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
- [ ] Whether worker agents stay inline — `Agent` omitted from their
      `tools:` — or may nest helpers (DESIGN.md §11, §16.14).
- [ ] Which agent performs the fold for a research-parked ticket: §6.3
      sends research's answers into `spec.md` while `research.md` already
      exists, and §4 row 1 continues "with the step the artifacts imply" —
      whether `tsf:research` re-runs or `tsf:plan` folds (its §11.1 inputs
      list only plan-gate feedback) is not stated.
- [ ] Whether `/tsf:spec` and `/tsf:init`, which run under the human's
      ambient login (§6.1, §12), go through the one REST write helper
      with an identity switch or bypass it (§10, §11.3 place the
      read-back/PATCH/retry logic once, in `scripts/`; the design does not
      say which).

## References

- `plugins/tsf/DESIGN.md` v1.4 — §2, §3, §4 rows 1–4 and 13, §5, §6.1–6.5,
  §8, §10, §11.1, §11.3, §12, §16.42, §16.47, §16.48
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
- Epic: `TP-0034-implement-tsf-plugin-v1.md`

## Implementation Plan

## Notes & Updates

### 2026-09-15

- Created as the first of three slices when TP-0034 became an epic (context
  size per implementation phase; each slice is usable on its own).
- Aligned with DESIGN.md v1.4: the derived state is the journal's `Next
  step` (resume path, §16.42); the runner session is opened in the clone,
  no clone path, the factory credential is resolved per call and init
  checks that credential, `/tsf:spec` creates branch and spec over REST
  (§16.47); the scan reads open issues only (§16.48). Also carried from
  §12 in the same pass: the contract check at the start of every cycle.
- Aligned with DESIGN.md v1.3: version `0.1.0`, version marker, factory
  identity credential source and auth check, `prepare` creating the ticket
  branch, distillation by parking step, `tsf:needs-human` resume, CLAUDE.md
  sections per slice, second GitHub account in the smoke test.
