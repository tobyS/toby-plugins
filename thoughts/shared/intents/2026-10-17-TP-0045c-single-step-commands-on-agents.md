---
date: 2026-10-17
ticket: TP-0045c
ticket_ref: thoughts/shared/tickets/TP-0045c-single-step-commands-on-agents.md
source: thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md
size: Large
status: agreed
last_updated: 2026-10-17
---

# Intent: stage 2 — the single-step commands, quickfix and ticketless runs on the shared agents

## Ticket

TP-0045c (`thoughts/shared/tickets/TP-0045c-single-step-commands-on-agents.md`),
sub-ticket of the epic TP-0045. The ticket is the human's; this file is the
agreement on what it means here, refined with what the first real
`/tce:work` run (GH-37, see `source:`) taught, as the epic's b→c gate requires.

## Scope

**In:**
- `/tce:research`, `/tce:plan` and `/tce:implement` become one-step
  orchestrators over the TP-0045b agents (`researcher`, `planner`,
  `plan-challenger`, `implementer`, `verifier`); none re-describes a step's
  working inline.
- The dispatch / ask / resume loop is extracted from `work.md` into one
  reference file under `plugins/tce/references/`, read at point of use by
  `work.md`, `research.md`, `plan.md`, `implement.md` and `quickfix.md`.
- Every step command and `/tce:work` accept a ticket ID **or** a path to an
  intent in `thoughts/shared/intents/` — ticketless intents become a standard
  input (small work, developer-only implementations). Without a ticket the
  branch step and the done transition are skipped, and delivery is always
  Direct.
- `/tce:intent` gains an autonomous mode that writes a ticketless intent
  without dialogue.
- `/tce:quickfix` becomes the reduced-ceremony lane: autonomous ticketless
  intent, then the same agents with a shorter chain.
- `/tce:implement` runs through verify, the bounded fix loop, the
  compliance gate, the dossier and the closeout.
- All step commands require the foreground environment (`work.sh preflight`).
- `plugins/tce/commands/implement_eco.md` is deleted.
- CLAUDE.md: the composite-tracking rule is removed; the TP-0013, TP-0020,
  TP-0031 and TP-0045b spans are re-pointed at the agents and the reference
  file; TP-0017 is re-derived.
- README updates, a real run in a consuming project, tce version bump and tag.

**Out:**
- `/tce:review`, `/tce:discuss`, `/tce:design_explore`, `/tce:list`,
  `/tce:commit`, `/tce:init`, `/tce:refresh` keep their form (unless a shared
  reference file lets one shrink for free).
- Free-form research questions without a ticket or intent (never used; dropped).
- Model pins for the step agents (TP-0045d).
- The question form / communication style (TP-0047) and moving the
  design-exploration check into `/tce:intent` (GH-37 finding 1, TP-0045d) —
  both become later edits to the one shared reference file.
- Agent contract changes beyond what rewiring and ticketless input require.
- The test-meaningfulness gate (TP-0046).

## Observable outcome

`/tce:research <ID|intent>`, `/tce:plan <ID|intent>` and
`/tce:implement <ID|intent>` each run their step through the TP-0045b agents
and leave on disk exactly what a `/tce:work` run leaves; `/tce:implement`
ends with the dossier. `/tce:quickfix "<description>"` writes a ticketless
intent without dialogue, creates no ticket, and runs researcher, planner,
implementer and verifier to a dossier. `/tce:work <intent-path>` runs a
ticketless intent end to end. No command contains an inline step
description, `implement_eco.md` is gone, and CLAUDE.md has no
composite-tracking rule.

## Anchors

- `plugins/tce/commands/research.md`, `plan.md`, `implement.md`,
  `quickfix.md`, `work.md`, `intent.md`, `implement_eco.md`
- `plugins/tce/references/work-dispatch.md` (position table, payloads),
  `work-brief.md`, `agent-returns.md`, `intent-document-template.md`
- `plugins/tce/agents/researcher.md`, `planner.md`, `plan-challenger.md`,
  `implementer.md`, `verifier.md`
- `plugins/tce/scripts/work.sh` (`preflight`, `artifact`), `stage.sh`,
  `ticket.sh`, `branch.sh`, `baseline.sh`
- CLAUDE.md sections "Composite commands must track the single-step
  commands", the TP-0020 gate, TP-0031 branch, TP-0045b orchestrator, TP-0017
  invocation control and TP-0013 re-read rules
- `plugins/tce/README.md` sections `## Commands` and `## Running /tce:work`

## Acceptance criteria

- [ ] `/tce:research`, `/tce:plan` and `/tce:implement` each dispatch only
      their own step's agents with the payloads of the shared reference file,
      and contain no inline step working.
- [ ] All three (and `/tce:quickfix`) run `work.sh preflight` and refuse
      without `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` and
      `BASH_DEFAULT_TIMEOUT_MS` ≥ 600000, with the same message as
      `/tce:work`; the README states the requirement for every step command.
- [ ] `/tce:plan` asks the planner's questions, prints the brief, runs the
      challenger and takes approval or push-back exactly as `/tce:work` Step 6,
      from the same reference text.
- [ ] `/tce:implement` runs every remaining phase, then verify with the
      bounded fix loop and the gate, the dossier, the closeout and the done
      transition (when there is a ticket); it never pushes and never opens a
      pull request, under either Delivery setting.
- [ ] A ticket run step by step (research → plan → implement) leaves
      `stage.sh` / `ticket.sh` results and documents indistinguishable in
      structure from a `/tce:work` run; an interrupted step resumes from disk.
- [ ] `/tce:work`'s behaviour is unchanged for tickets; its loop prose lives in
      the shared reference file, read at point of use.
- [ ] Every step command and `/tce:work` accept an intent path; with a
      ticketless intent they skip the branch step and the done transition,
      and `/tce:work` delivers Direct.
- [ ] Ticketless research, plan and dossier documents are named so that the
      intent's slug (or path) finds all of them again, and every command
      derives its position for a ticketless intent from disk.
- [ ] `/tce:research` with a free-form question (no ticket ID, no intent path)
      refuses with a pointer to `/tce:intent` or `/tce:discuss`.
- [ ] `/tce:intent` has an autonomous mode that writes and commits a
      ticketless intent without dialogue, and refuses when the sufficiency
      test fails.
- [ ] `/tce:quickfix` uses that mode, creates no ticket, runs the agents
      without plan approval (questions only on a genuine `needs decision`),
      with the same verifier, gate and dossier; it never branches and never
      delivers; when the researcher or planner signals the work is not small,
      it stops and recommends a ticket plus `/tce:intent`. It no longer
      refuses on `tickets.md`'s ticket-creation policy.
- [ ] The TP-0013 re-read, the TP-0031 branch steps and the TP-0020 gate are
      implemented once — in the agents and the shared reference file — not per
      command.
- [ ] CLAUDE.md's composite-tracking rule is removed; the gate, branch,
      re-read and orchestrator spans are re-pointed; TP-0017 is re-derived
      (`research`, `plan`, `implement`, `intent` stay unflagged delegation
      targets).
- [ ] `implement_eco.md` is deleted and no reference to it remains in the
      plugin, the README or CLAUDE.md.
- [ ] In a consuming project, a real ticket runs step by step through the
      rewired commands, one fix runs through `/tce:quickfix`; tce is
      version-bumped and tagged (`git tag --list 'tce--v*'` shows it).

## Decisions

- **The single-step commands require the foreground environment** — over an
  inline fallback when the variables are missing: a fallback is the second
  step description this ticket exists to remove.
- **`implement_eco` is deleted in this ticket** — over keeping it until the
  TP-0045d pins: it was never used, and after the rewire its turn-scoped pin
  would likely not reach the `inherit` agents anyway.
- **Extract today's loop as it is** — over waiting for TP-0047 and GH-37
  finding 1: those then edit one reference file instead of four commands.
- **Quickfix authors an intent only, no ticket** — over keeping ticket
  creation: ticketless intents are the standard for small work; `/tce:intent`
  gets an autonomous mode (the `/tce:ticket --autonomous` precedent).
- **`/tce:implement` standalone writes the dossier** — over stopping at the
  closeout: the step ends where `/tce:work`'s verification ends; only
  delivery stays with `/tce:work`.
- **All step commands and `/tce:work` accept ticketless intents** — over
  restricting ticketless runs to quickfix: developer-only implementations can
  be larger than a quickfix, and the naming and loop must exist for quickfix
  anyway.
- **Free-form research is dropped** — over widening the researcher to accept a
  bare question: never used; `/tce:discuss` covers exploration.

## Open questions

None.

## Questions for research

- [ ] The naming scheme for ticketless research, plan and dossier documents,
      and how `stage.sh` / `ticket.sh` (ID-based, delimited-segment match)
      discover them from an intent's slug without weakening the ID matching.
- [ ] Where the shared loop's reference file splits from `work-dispatch.md`
      and `work-brief.md`, and what each command keeps (its entry, its first
      and last step).
- [ ] How the agents' payloads represent "no ticket" (`ticket: none`?) and
      what in each agent's contract that touches.
- [ ] How the thirteen-copy AskUserQuestion guidelines block changes when the
      dialog sites move into one reference file (CLAUDE.md duplication rule),
      and where the branch stop-and-ask dialog copy lives after the rewire.
- [ ] What `/tce:intent`'s autonomous mode needs as input, and how it
      reports a failed sufficiency test back to quickfix.
- [ ] What remains of `plan.md`'s dialog surface (structure review, open
      questions, design-exploration check) once the planner asks through the
      orchestrator.
- [ ] Whether `/tce:review` needs any adjustment once implement ends with the
      verifier and dossier (kept out of scope unless it breaks).
- [ ] Which CLAUDE.md rules and README passages name `implement_eco`, the
      composite, or quickfix's ticket creation, and need rewriting.

## Notes

Size Large: four commands rewired plus `/tce:work` extended, a reference file
extracted, an autonomous intent mode, ticketless naming, several CLAUDE.md
spans re-pointed and a real run. Considered splitting; kept as one because the
shared loop, the ticketless naming and the rewired commands only make sense
together.

The ticket's "Cost tuning" README section, which `implement_eco.md` points to,
does not exist (`git log -S` finds no commit that ever added it); deleting the
command removes the dangling pointer.
