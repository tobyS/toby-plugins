# TP-0025: Implement the tsf plugin v1 per DESIGN.md

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-08-11
**Updated:** 2026-08-11

## Problem Statement

The tsf (Toby Software Factory) design is agreed and committed
(`plugins/tsf/DESIGN.md`, background review in
`thoughts/shared/research/2026-07-07-tce-software-factory-review.md`), but no
implementation exists — `plugins/tsf/` contains only the design document. Until
the plugin is built, the factory workflow it describes (autonomous backlog work
over GitHub issues with async human gates) cannot be used or iterated on with
real runs.

## Desired Outcome

A complete, installable v1 of the tsf plugin in this marketplace, implementing
the design document in full. When done: `/plugin install tsf@toby-plugins`
works in a consuming project; `/tsf:init` sets the project up; `/tsf:spec`
authors a spec triple interactively; `/tsf:cycle` advances the
highest-priority actionable ticket exactly one step; `/tsf:run` repeats cycles
self-paced. `DESIGN.md` is the binding specification — deviations discovered
during implementation are surfaced, not silently made.

## User Stories / Use Cases

- As a single-engineer project owner, I want to release issues to the factory
  by labeling them `tsf:ready` so that tickets advance to reviewed PRs without
  me babysitting generation.
- As the reviewing human, I want plan summaries, batched questions, and a final
  dossier on GitHub so that each of my interactions is short and maximally
  informed.
- As a marketplace consumer, I want tsf installable and initializable like
  tce/tmt so that setup follows the familiar plugin conventions.

## Acceptance Criteria

- [ ] `plugins/tsf/` matches the layout in DESIGN.md §12:
      `.claude-plugin/plugin.json` (name `tsf`, version `1.0.0`), `README.md`
      (consumer-facing), `commands/` (`init`, `spec`, `cycle`, `run`),
      `agents/` (7 workers + 3 gates per §11), `references/templates/` (spec,
      research, plan, journal-entry, report, dossier skeletons), `scripts/`,
      `templates/tsf/` (config.md skeleton); `.claude-plugin/marketplace.json`
      lists tsf.
- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf`
      pass.
- [ ] All four commands carry `disable-model-invocation: true` (§12).
- [ ] The three gate agents are mechanically read-only: frontmatter tools
      limited to `Read, Grep, Glob, LS`; each carries the three-part
      constraint envelope; the dispatcher performs their git/GitHub I/O
      (§11.2).
- [ ] Worker agents implement the §6 common contract: re-read input artifacts
      from disk in chain order, commit, push, exactly one summary comment,
      exactly one journal entry, label adjustment per §4; every agent
      description begins "Internal to `/tsf:cycle` — not for direct use"
      (§11.3).
- [ ] `/tsf:cycle` implements the dispatch table (§4) and cycle phases (§5.1)
      including the hard-reset prepare phase (§8),
      label/artifact-disagreement parking, and the auto-continue rule.
- [ ] `/tsf:init` writes `.claude/tsf/config.md` (profile, environment
      contract, factory constants), creates the `tsf:*` labels, verifies `gh`
      auth, and offers the permission allowlist (§12).
- [ ] The plugin is project-agnostic: no stack, path, or project literals in
      commands/agents/scripts; everything project-specific is read from
      `.claude/tsf/config.md` at runtime (repo core rule + §12).
- [ ] Verification pipeline, dossier, and integration behave per §7 and §9:
      gate order plan-compliance → spec-coverage → CI-green → security, one
      gate per cycle, "needs human verification" verdicts land in the dossier,
      squash-merge with escalation on risky rebases.
- [ ] End-to-end smoke test (manual, per repo "Testing changes"): install in a
      scratch project with a real GitHub repo, run `/tsf:init` and
      `/tsf:spec`, and drive at least one ticket through triage/research
      cycles with `/tsf:cycle`.
- [ ] Repo docs updated: root `README.md` plugin catalog lists tsf; repo
      `CLAUDE.md` gains whatever tsf-specific sync/design rules the
      implementation establishes (analogous to the existing tce/tmt rule
      sections).

## Out of Scope

- Everything DESIGN.md §14 lists as v1 non-goals: parallel
  execution/worktrees/multiple factory instances, configurable priority or
  gate family, auto-pickup without human release, telemetry, GitHub
  Action/webhook triggers, ticket-backend abstraction, incident feedback loop.
- The `claude -p` while-loop runner (§5.3 "Future") — v1 ships `cycle`, `run`,
  `/loop`-compatibility only.
- Any changes to the tce or tmt plugins; any dependency between tsf and tce
  (§2).
- Design changes: material deviations from DESIGN.md require discussion, not
  unilateral redesign.

## Open Questions

None — the design was discussed and agreed on 2026-08-11 (DESIGN.md §13
records the decision log).

## Questions for Research/Planning

- [ ] How exactly `/tsf:cycle` spawns the named `tsf:*` plugin agents via the
      Agent tool, and what each spawn prompt must carry (dispatcher-computed
      inputs, especially for gates).
- [ ] The single-`gh`-query scan design (§5.1): which `gh` invocation(s) yield
      labels + PR + CI state cheaply, and what `scripts/` helpers should wrap.
- [ ] How `/tsf:run` self-paces within one session (mechanism and pause
      policy).
- [ ] What of tce's existing command/agent prose is worth mining as *drafting
      reference* (register, constraint envelopes) while keeping tsf standalone
      (§2).
- [ ] Which parts of the §6 step specs live in agent system prompts vs.
      point-of-use reference templates.

## References

- `plugins/tsf/DESIGN.md` — the binding design (v1, agreed 2026-08-11)
- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` —
  background review
- Repo `CLAUDE.md` — marketplace conventions (plugin layout, project-agnostic
  rule, versioning, release flow)

## Implementation Plan

## Notes & Updates

### 2026-08-11

- Ticket created from the agreed DESIGN.md; single ticket for the full
  greenfield implementation per explicit user decision.
- Complexity Large: an entire new plugin (4 commands, 10 agents, templates,
  scripts), but fully specified by the design document.
- All design-level questions are settled (DESIGN.md §13); remaining questions
  are implementation-mechanical and deferred to research/planning.
