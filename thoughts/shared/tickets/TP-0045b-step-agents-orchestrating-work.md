# TP-0045b: the step agents and the orchestrating `/tce:work` (stage 1)

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-10-11
**Updated:** 2026-10-11

Sub-ticket of TP-0045 (the epic). Second of four; follows TP-0045a (intent,
reader and delivery sections), precedes TP-0045c (stage 2) and feeds
TP-0045d (improvements collected from real runs).

## Problem Statement

The step logic of research, plan and implement lives in three long commands
with dialog sites that cannot execute inside an agent, and `/tce:work` runs
all three in one context window (independent review finding 2.3). Nothing
dispatches a step in a fresh context, nothing returns questions to a single
asker, and nothing presents a plan as a brief or a result as a dossier.

## Desired Outcome

New tce agents carry the step logic for autonomous execution — an
**extraction, not a redesign**: each agent does what its step does today, with
the same documents, templates and checks; the only differences are the
dispatch boundary, a short return shape, and that dialog sites become
returned questions. The agents: research (fanning out to the existing locator
and analyzer agents), plan (questions-first, then plan plus brief), plan
challenger (brief versus plan, plan criteria), implement (one phase per
dispatch, plan log on disk), verifier (shell and browser, runs tests), plus
the existing compliance checker.

`/tce:work <ticket>` is rewritten as the orchestrator: it refuses without an
intent, dispatches one agent per step, centralizes all interaction in
**planning** (the plan agent is the only one that returns questions and the
brief; research and implement are non-interactive and return `blocked` only
for a situation they can neither resolve nor defer), resumes the same agent
with the answers, renders the brief, runs bounded fix loops, and ends with
the dossier and the delivery step from the profile. The single-step commands
and `/tce:quickfix` are untouched, so this stage reverts cleanly.

## User Stories / Use Cases

- As the human, I want to run one command after the intent and be interrupted
  in one place — planning — so that a ticket moves from intent to verified
  change while I do something else.
- As the approving human, I want to approve the plan from a brief that states
  what was understood, the approach, the decisions for me and the decisions
  made for me, so that I decide in a minute without reading the plan.
- As the human reviewing the result, I want a dossier with counted facts and
  permalinks so that I know where to look and what was decided for me.
- As a tce consumer with an unfamiliar stack, I want briefs phrased per the
  reader section so that I can still decide.

## Acceptance Criteria

- [ ] **The working of the three phases is retained.** The research agent
      performs `research.md`'s fan-out, drift check and document template;
      the plan agent produces a plan per the plan template with the same
      sections and phase structure; the implement agent runs the phase loop,
      plan log, intermediate commits, final verification and compliance gate
      as `implement.md` specifies. A `/tce:work` run produces research and
      plan documents of the same structure as today's commands.
- [ ] Agents exist under `plugins/tce/agents/` for research, plan, plan
      challenger, implement and verifier, each with its return shape shown
      filled in inside its own prompt, bounded return length, artifacts
      referenced by path, and no `AskUserQuestion`; the verifier has Bash
      and inherits the session's browser tools.
- [ ] Only the plan agent returns questions and the brief. The research and
      implement agents return done / done with concerns / blocked; `blocked`
      is reserved for a situation the agent can neither resolve nor defer
      and is the only way either interrupts the human.
- [ ] `/tce:work <ticket>` refuses without an intent, naming `/tce:intent`;
      otherwise runs research → plan (questions-first return; the orchestrator
      asks one decision per block, recommended option first, with context
      sufficient to decide without the artifacts; resumes the planner; the
      planner writes the plan and returns the brief) → challenger → brief
      approval or push-back (push-back resumes the planner; the next return
      shows only what changed) → implement phase by phase → verifier →
      compliance gate → dossier → delivery per `## Delivery`.
- [ ] The brief and every question follow the agreed terminal layout: one
      takeaway line with counts, headings and short bullets, no tables with
      prose cells, phrased per `## Reader`. Decisions made on the human's
      behalf, with the rejected alternative, are persisted in the plan's
      `## Decisions` section.
- [ ] Progress is on disk: the implement agent keeps the plan's per-phase
      log; the orchestrator derives its position from `stage.sh` and the plan
      log, so a run resumed in a new session continues at the next phase
      without re-researching or re-planning.
- [ ] Fix loops are bounded with the counter in the plan log; exhaustion
      returns "needs decision" with the evidence. Only "needs decision" and
      "blocked" interrupt; concerns go to the dossier.
- [ ] Mechanical checks are limited to exists, non-empty, committed for each
      artifact; no script parses an agent return or agent-authored document.
- [ ] The dossier reports criteria met n/m, fix rounds used, tests added,
      decisions made for you, "start here" and "where to look" with permalinks
      at the commit; it is posted on the pull request when `## Delivery` says
      one is opened, otherwise printed.
- [ ] `/tce:init` offers the permission allowlist entries a smooth run needs,
      on explicit approval and surgically, as `/tsf:init` does.
- [ ] `research.md`, `plan.md`, `implement.md`, `quickfix.md`, `review.md`
      and `commit.md` are byte-identical to before this ticket. One real
      ticket in a consuming project runs end to end through the new
      `/tce:work`.
- [ ] CLAUDE.md: the composite-tracking and TP-0020 gate rules state that the
      new `work.md` is an orchestrator and no longer re-describes the steps;
      the new same-commit spans (return shapes, brief layout, fix-loop
      counter) are recorded; the tce README documents the flow and
      `BASH_DEFAULT_TIMEOUT_MS`; version bumped and tagged.

## Out of Scope

- Rewiring the single-step commands and quickfix (TP-0045c).
- Any change to a step's working beyond what extraction requires; an
  improvement to a step is a TP-0045d item or its own ticket.
- Progress heads-up lines from running agents (TP-0045d).
- The test-meaningfulness gate (TP-0046).
- `agent-present` or HTML rendering of the brief; stacked branches; any tsf
  change.
- `/tce:design_explore` inside the orchestrated flow; a UX ticket is told to
  run it before `/tce:work`.

## Open Questions

None. Resolved during ticket creation (2026-10-11):

- `/tce:work` opens the pull request itself when `## Delivery` says so, with
  `gh` granted in `work.md`'s `allowed-tools` only; the dossier's home is the
  pull request and the human merges.
- No research checkpoint: the human confirms only the plan. The planner's
  questions-first return surfaces whatever research found that needs a
  decision.

## Questions for Research/Planning

- [ ] Foreground versus background dispatch and how the orchestrator's turn
      handles agent results; `SendMessage` resume across compaction and what
      to do when the agent id is lost.
- [ ] Model pins per agent (TP-0029 precedent).
- [ ] How the implement agent's phase scope and the plan template's
      `### Implementation log` carry the fix-loop counter.
- [ ] How the compliance checker and verifier divide the gate; whether the
      verifier is the TP-0032 answer for the checker's shell-less escalation.
- [ ] Which tsf templates port (dossier, pr-body, question-comment) and what
      the tce copies shed.
- [ ] `work.md`'s size budget under compaction (first 5,000 tokens) and what
      moves to reference files.

## References

- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md` — the epic
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md` —
  platform facts, approach B, the brief, question ordering, verification,
  tsf learnings
- `plugins/tce/commands/work.md`, `research.md`, `plan.md`, `implement.md` —
  the working to extract; `references/*.md` — the document templates
- `plugins/tce/agents/plan-compliance-checker.md`; `scripts/stage.sh`,
  `baseline.sh`, `branch.sh`
- `plugins/tsf/references/templates/{dossier,pr-body,question-comment}.md`
- `thoughts/shared/tickets/TP-0032`, `TP-0038`, `TP-0039`, `TP-0044`

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-10-11

- Extraction, not redesign, by user decision: the three phases keep their
  working; only the boundary and the return shape change.
- Interaction is centralized in planning by user decision; research and
  implement interrupt only on `blocked`.
- Progress heads-up lines deferred to TP-0045d.
