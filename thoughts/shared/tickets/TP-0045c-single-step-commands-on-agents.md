# TP-0045c: stage 2 — the single-step commands and quickfix on the shared agents

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-10-11
**Updated:** 2026-10-11

Sub-ticket of TP-0045 (the epic). Third of four; starts only after TP-0045b
has carried at least one real ticket end to end, and is refined with what
that run taught before it is researched.

## Problem Statement

After TP-0045b, tce describes every step twice: once in the autonomous agents
and once in the interactive `research.md`, `plan.md`, `implement.md` and
`quickfix.md`. The composite-tracking rule exists only because of this
duplication, and the two descriptions will drift the first time one is edited
alone.

## Desired Outcome

`/tce:research`, `/tce:plan` and `/tce:implement` become one-step
orchestrators over the same agents, each running the dispatch, ask, resume
loop around one step with the same brief and question presentation as
`/tce:work`. `/tce:quickfix` becomes the reduced-ceremony lane: it authors an
**intent only** — no ticket — autonomously from the description, then runs the
same agents with a shorter chain (no brief approval, fewer questions, the same
verifier and gate). `implement_eco` is retired or reduced to a pin, since cost
now lives in the agents' pins. No command re-describes a step inline, and the
composite-tracking rule leaves CLAUDE.md.

## User Stories / Use Cases

- As a tce user who likes the single steps, I want `/tce:research`,
  `/tce:plan` and `/tce:implement` to keep working one step at a time so that
  I can still stop between steps, with the same quality as the full run.
- As a tce maintainer, I want one description of each step so that a change
  to a step is one edit, not three.
- As the human with a small fix, I want `/tce:quickfix` to run the same agents
  from an intent, with less ceremony and no ticket, so that small things stay
  cheap without a second code path.

## Acceptance Criteria

- [ ] `/tce:research`, `/tce:plan`, `/tce:implement` dispatch the TP-0045b
      agents for their step, ask and resume as `/tce:work` does, and write the
      same documents to the same places; a chain run step by step produces
      artifacts indistinguishable in structure from a `/tce:work` run.
- [ ] `/tce:plan` standalone presents the brief and takes approval or
      push-back exactly as `/tce:work`; `/tce:implement` standalone runs the
      verifier, the bounded fix loop and the compliance gate exactly as
      `/tce:work`.
- [ ] `/tce:quickfix` creates a minimal intent autonomously (via
      `/tce:intent`), creates no ticket, runs the same agents with the reduced
      chain from that intent, and still refuses when `tickets.md` forbids
      autonomous creation of workflow artifacts.
- [ ] The TP-0013 re-read rule, the TP-0031 branch steps and the TP-0020 gate
      hold in every rewired command, implemented once in the agents and
      reference files rather than per command.
- [ ] `work.md`, `research.md`, `plan.md`, `implement.md`, `quickfix.md`
      contain no inline step description; the shared loop lives in a
      reference file read at point of use. CLAUDE.md's composite-tracking
      rule is removed and its gate, branch and re-read spans are re-pointed
      at the agents and reference files; the TP-0017 classification is
      re-derived (research, plan, implement stay unflagged delegation
      targets).
- [ ] `implement_eco.md` is removed or reduced to a documented pin, with the
      README's "Cost tuning" section updated.
- [ ] A real ticket runs step by step through the rewired single-step
      commands and one fix through `/tce:quickfix` in a consuming project;
      tce version bumped and tagged.

## Out of Scope

- `/tce:review`, `/tce:discuss`, `/tce:design_explore`, `/tce:list`,
  `/tce:commit`, `/tce:init`, `/tce:refresh`: not step commands; they keep
  their form unless a shared reference file lets them shrink for free.
- Changes to the agents' contracts beyond what rewiring requires; a contract
  change is a TP-0045d item or its own ticket.
- The test-meaningfulness gate (TP-0046).

## Open Questions

None at this time; refined after TP-0045b's real run, per the epic's gate.

## Questions for Research/Planning

- [ ] How much of `plan.md`'s dialog surface survives as orchestrator
      questions versus disappears.
- [ ] What the quickfix minimal intent contains and how a ticketless intent
      names the research and plan documents and the branch.
- [ ] Whether `implement_eco`'s Sonnet pattern maps onto the implement agent's
      pin.
- [ ] How `/tce:review` relates to the verifier and gate afterwards.
- [ ] How the twelve-copy AskUserQuestion guidelines block changes when dialog
      sites move into one reference file.

## References

- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md` — the epic
- `thoughts/shared/tickets/TP-0045b-step-agents-orchestrating-work.md` — the
  agents this rewires onto
- `plugins/tce/commands/research.md`, `plan.md`, `implement.md`,
  `implement_eco.md`, `quickfix.md`
- Repo `CLAUDE.md` — composite-tracking, TP-0013, TP-0017, TP-0020, TP-0031
  rules

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-10-11

- Quickfix authors an intent only, no ticket, by user decision.
- Gated on a real TP-0045b run; this ticket is refined before research.
