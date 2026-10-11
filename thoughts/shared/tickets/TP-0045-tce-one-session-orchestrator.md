# TP-0045: tce in one session — `/tce:work` orchestrating one agent per step (epic)

**Status:** Open
**Estimated Complexity:** Extra Large
**Created:** 2026-10-11
**Updated:** 2026-10-11

**Epic.** The work is carried by four sub-tickets; this ticket holds the
whole-chain outcome and is done when all four are:

1. `TP-0045a` — the human-facing layer: `/tce:intent` (the intent file in
   `thoughts/shared/intents/`, the agent-facing specification of a human
   ticket or of ticketless input — today's `/tce:ticket` dialogue moved off
   the ticket), the reader and delivery sections in `profile.md`; no tce
   command writes into an existing ticket's body.
2. `TP-0045b` — the step agents (research, plan, implement, plan challenger,
   verifier) and the new orchestrating `/tce:work` (stage 1). An extraction
   of the three phases' working, not a redesign; interaction centralized in
   planning. The single-step commands and `/tce:quickfix` stay untouched, so
   a failed experiment is reverted without touching them.
3. `TP-0045c` — stage 2: `/tce:research`, `/tce:plan`, `/tce:implement` and
   `/tce:quickfix` rewired onto the same agents as one-step (or
   reduced-ceremony) orchestrators; quickfix authors an intent only, no
   ticket; the inline step prose and the composite-tracking rule retired.
4. `TP-0045d` — improvements collected from real runs: a checklist of small
   non-defect observations (first item: progress heads-up lines from running
   agents), worked in batches alongside and after `TP-0045c`; Done when every
   item is ticked or moved to its own ticket.

**Gate between b and c:** `TP-0045c` starts only after `TP-0045b` has carried
at least one real ticket end to end in a consuming project. What that run
teaches goes into `TP-0045c`'s ticket before it is researched.

## Problem Statement

tce produces good results, but every step (`/tce:ticket` → `/tce:research` →
`/tce:plan` → `/tce:implement`) needs a fresh context and therefore a human to
start it. The one composite that avoids this, `/tce:work`, runs three phases in
one context window — the independent review flagged exactly that (finding
2.3). tsf removed the human at the price of a factory (dedicated clone, second
GitHub identity, label state machine, scan, journal-derived state, two-cycle
landing) that a single engineer whose backlog arrives in sequential epics
cannot justify maintaining.

There is no way to carry a ticket from agreed intent to a verified, implemented
change in one session, with the human pulled in only for genuine decisions and
addressed in terms they understand regardless of the project's stack.

## Desired Outcome

In a consuming project, the human runs `/tce:intent <ticket>` once, in
dialogue, and then `/tce:work <ticket>`. Research, plan and implementation run
in that one session, each step in a fresh-context agent, the main context
staying short. The human is asked only at genuine decisions — each question
self-contained, answerable without having read the artifacts, and phrased for
the reader described in the profile. The plan is approved from a terminal
brief (understanding, approach, decisions for the human, decisions made on
their behalf with the rejected alternative, counted facts), never from the
plan file. The result is a dossier of counted facts with permalinks. The
artifacts stay tce's existing files in their existing places.

When the epic is done, every tce workflow command is an orchestrator over the
shared step agents: the composites and the single-step commands differ only in
how many steps they run and how much ceremony they carry, and no command
re-describes a step inline any more.

Framing (agreed in the discussion): this is "tce in one session with less
interaction", **not** "tsf run locally" — tsf is a source of lessons, not the
architecture.

## User Stories / Use Cases

- As a single engineer across several projects, I want one command to carry a
  ticket through research, plan and implementation so that I start the chain
  once instead of once per step.
- As the approving human, I want decisions presented as self-contained
  questions and the plan as a terminal brief so that I decide well without
  reading a 1000-line plan.
- As someone fluent in one stack and new to another, I want briefs and
  questions that explain the unfamiliar parts and skip the familiar ones so
  that the same workflow serves both projects.
- As a tce consumer, I want the step logic in agents the single-step commands
  share so that the commands cannot drift apart and the composite-tracking
  duplication disappears.

## Acceptance Criteria (epic level)

The detailed criteria live in the sub-tickets. The epic is done when:

- [ ] TP-0045a, TP-0045b, TP-0045c and TP-0045d are Done.
- [ ] On at least one real ticket in a consuming project, `/tce:intent` then
      `/tce:work` ran research, plan and implementation to a verified result
      without the human opening a `thoughts/` file, and the research and plan
      documents landed where `stage.sh` and `ticket.sh` find them today.
- [ ] The cross-cutting rules hold in every command that runs a step: every
      step runs in a fresh-context agent dispatched in the foreground of the
      orchestrator's turn model; no agent asks the user — every question
      returns to the orchestrator as data and the orchestrator asks; artifacts
      travel by path and returns are bounded; the orchestrator re-derives its
      position from disk (`stage.sh`, the plan log), so a dead agent or a
      crash costs a phase, not a run; no script parses an agent-authored
      format — the only mechanical checks are "exists, non-empty, committed";
      counted facts, never confidence scores; evidence cites post-change
      source lines and links are permalinks at the commit; every agent prompt
      shows its return shape filled in; the verifier has a shell and the
      browser and runs tests itself; fix loops are bounded with the counter on
      disk; the status vocabulary is done / done with concerns / needs
      decision / blocked, and only the last two reach the human.
- [ ] No tce command or step writes into an existing ticket's body (status
      transitions per `tickets.md` excepted); `/tce:ticket` hands off to
      `/tce:intent`, which is unflagged and also takes ticketless input.
- [ ] The steps' working is retained through the move into agents: research,
      plan and implement produce documents of the same structure as today,
      and only planning interrupts the human (research and implement only
      when blocked).
- [ ] The profile's reader and delivery sections follow the branch-convention
      pattern (TP-0031): template, `init` dialogs and fill, `refresh` preserves
      them as hand-authored, README; a project without the sections behaves
      byte-identically to today.
- [ ] The single-step commands and `/tce:quickfix` are unchanged through
      TP-0045b and migrated in TP-0045c; after TP-0045c, `/tce:quickfix` runs
      the same agents with ceremony scaled to the ticket's size, and the
      CLAUDE.md composite-tracking rule is removed or rewritten to the new
      mechanism.
- [ ] Repo docs updated per sub-ticket: tce `README.md`, root `README.md`
      catalog, CLAUDE.md rule sections for every new same-commit span, the
      TP-0017 invocation classification re-derived for `intent`, the new
      `work` and the rewired commands; tce version bumped and tagged with each
      sub-ticket.

## Out of Scope

- A test-meaningfulness gate (tsf's open gap TP-0042) — filed as its own
  follow-up ticket, TP-0046, to be scheduled after the first real runs.
- Rendering the brief through `agent-present` or an HTML artifact; markdown in
  the terminal only, within the table-collapse constraint.
- Stacking branches on unmerged pull requests.
- Everything tsf-specific the discussion lists as not carried: labels, scan,
  journal-derived state, the two-cycle landing, the second GitHub identity,
  REST-only writes, the clone / `prepare` contract, implement batching.
- Changes to tmt, tle or tsf. Porting a tsf template means copying it into
  tce's `references/` and shedding its factory assumptions — never a
  cross-plugin read.

## Open Questions

None at epic level. Resolved during ticket creation (2026-10-11):

- The test-meaningfulness gate is a separate follow-up ticket (TP-0046), not
  part of TP-0045b, so stage 1 stays small enough to learn from and to revert.
- The new orchestrator takes over the `/tce:work` name in stage 1 and replaces
  the inline composite directly; reversibility is `git revert` plus the
  untouched single-step commands, not a parallel command.

## Questions for Research/Planning

- [ ] Dispatch mode and turn handling: how the orchestrator acts on agent
      results (background notifications vs. foreground), and how `SendMessage`
      resume of a finished agent behaves across compaction.
- [ ] Which permission allowlist entries a smooth run needs
      (`Read(~/.claude/plugins/**)`, the profile's test commands) and how
      `/tce:init` offers them (TP-0034a precedent).
- [ ] Where the intent file lives and how `ticket.sh` / `stage.sh` discover
      it; how the ticket-sufficiency test moves from `research.md` onto the
      intent (TP-0022 span).
- [ ] The exact brief and question layout under the terminal's table-collapse
      constraint; what of the brief persists into the plan (`## Decisions`).
- [ ] Which tsf reference templates (dossier, pr-body, question-comment, the
      result shape) port into tce references and what they shed.
- [ ] How the verifier gets shell and browser (TP-0032), what the fix-loop
      bound is and where its counter lives in the plan log.
- [ ] Model pins for the step agents (TP-0029 precedent) and which agents
      pin at all.
- [ ] What `/tce:init` and `/tce:refresh` must gain for the reader and
      delivery sections, and the Idempotency upgrade entries (TP-0003).
- [ ] For TP-0045c: how a one-step orchestrator and the quickfix lane reuse the
      dispatch / ask / resume loop without re-describing it per command.

## References

- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md` —
  the design discussion (platform facts verified on Claude Code 2.1.290,
  approaches, the human-facing layer, tsf learnings, follow-up order; its
  References list the platform docs, HumanLayer, superpowers, agent-present
  and the tsf tickets)
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`
  finding 2.3 (`/tce:work` runs three phases in one window)
- `plugins/tce/commands/work.md`, `quickfix.md` — the inline composites being
  replaced; `research.md` (six-agent fan-out), `plan.md` (dialog sites),
  `implement.md` (plan log, compliance gate)
- `plugins/tce/scripts/stage.sh`, `branch.sh`, `baseline.sh`, `ticket.sh`
- `plugins/tsf/DESIGN.md` §11; `plugins/tsf/references/templates/`
- Repo `CLAUDE.md` — composite-tracking, TP-0013 re-read, TP-0017
  classification, TP-0020 gate span, TP-0031 branch-convention span

## Implementation Plan

Per sub-ticket; none at epic level.

## Notes & Updates

### 2026-10-11

- Ticket created from the completed design discussion of 2026-10-09.
- Built inside tce as the successor of `/tce:work`, not as a fifth plugin:
  cross-plugin references are forbidden, so a new plugin would duplicate the
  templates and scripts and break the "same files as tce" promise over time.
- Vocabulary: "intent" (not "spec") is the artifact authored with the human;
  the "brief" is the planner's return rendered in the terminal, not a file.
- Sub-ticket shape by user decision: the `## Delivery` profile section is
  folded into TP-0045a (same template / init / refresh / README span as the
  reader section). Stage 2 is kept inside the epic so that the epic ends
  with all of tce — quickfix included — on the new model; it is gated on a
  real run of stage 1. A fourth sub-ticket, TP-0045d, collects
  improvements from real runs.
- Test-meaningfulness gate split out as TP-0046; `/tce:work` is replaced in
  place in stage 1.
- Sub-tickets authored 2026-10-11: TP-0045a sized Medium (the dialogue
  already exists in `/tce:ticket`); `/tce:intent` unflagged (intents come
  from interactive and discussion sessions too); TP-0045b is an extraction
  that retains the phases' working, with interaction centralized in
  planning; quickfix authors an intent only, no ticket; progress heads-up
  lines go to TP-0045d.
