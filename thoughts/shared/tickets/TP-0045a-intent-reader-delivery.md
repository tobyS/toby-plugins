# TP-0045a: the human-facing layer — `/tce:intent`, reader and delivery profile sections

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-10-11
**Updated:** 2026-10-11

Sub-ticket of TP-0045 (the epic). First of four; the others are TP-0045b
(step agents and the orchestrating `/tce:work`), TP-0045c (stage 2: the
single-step commands and quickfix on the agents) and TP-0045d (improvements
collected from real runs).

## Problem Statement

tce has no artifact that records the agreement between the human and the
agents on what a ticket means in this codebase. The ticket belongs to the
ticket system and may be someone else's; clarifications today either go into
the research document, where no human reads them, or get folded back into the
ticket body, which pollutes a shared ticket system. The dialogue that produces
such an agreement already exists — it is `/tce:ticket`'s guided discussion —
but it is tied to creating a ticket, so it cannot be run for a ticket that
already exists, for a discussion result, or for a fix that needs no ticket.

The profile also says nothing about who reads tce's output, so briefs and
questions cannot know what to explain and what to skip, and nothing records
whether a pull request is expected and who merges.

## Desired Outcome

A new file type, the **intent**: the agent-facing specification of a human
ticket (or of ticketless input), authored with the human. `/tce:intent
<ticket | free input>` runs today's ticket-authoring dialogue moved off the
ticket and writes one intent file into `thoughts/shared/intents/`, holding the
understood scope, the observable outcome, the anchors into the system, the
decisions resolved with the human (with the rejected alternative) and the
open questions. The ticket is read, never modified. The command is
unflagged: interactive sessions, `/tce:discuss` and later `/tce:quickfix`
hand off to it.

The profile gains a `## Reader` section (two or three lines on the reader's
fluency, read by every human-facing output) and a `## Delivery` section
(whether a pull request is opened, who merges, merge-before-next-ticket rule),
both agreed at `/tce:init`, preserved by `/tce:refresh` as hand-authored, and
absent by default so un-upgraded projects behave byte-identically.

## User Stories / Use Cases

- As the human, I want to agree what to build once, in dialogue, so that every
  later step works from that agreement and nothing asks me again what the
  ticket means.
- As someone whose tickets live in a shared tracker, I want tce to leave the
  ticket body alone so that my clarifications do not appear in colleagues'
  tickets.
- As someone coming out of a `/tce:discuss` session, I want to turn its
  conclusion into an intent directly so that the agreement is not retyped.
- As a reader fluent in one stack and new to another, I want to tell tce my
  fluency once so that its questions and briefs explain only the unfamiliar.
- As the person who merges, I want the delivery rule recorded so that
  `/tce:work` knows when its job ends.

## Acceptance Criteria

- [ ] `/tce:intent` exists and is **unflagged** (a delegation target per
      TP-0017). Given a ticket reference it reads the ticket via `tickets.md`;
      given free input it works from that. It opens with the three-part
      sufficiency test (scope, outcome, anchor) with the human, then runs the
      scale-adaptive dialogue `/tce:ticket` runs today, and writes
      `thoughts/shared/intents/YYYY-MM-DD-[PREFIX]-XXXX-description.md` (a
      slug in place of the ID for ticketless intents) from a reference
      template, committed with a docs-only commit.
- [ ] The intent file carries: understood scope, observable outcome, anchors,
      decisions resolved with the human (with the rejected alternative), open
      questions, and a pointer to the ticket when there is one. Re-running
      `/tce:intent` for a ticket that has an intent updates that file after
      confirmation; it never creates a second one.
- [ ] No tce command or step writes into an existing ticket's body;
      status-line transitions per `tickets.md` remain the only ticket writes.
      `/tce:ticket` keeps authoring new tickets and hands off to
      `/tce:intent` instead of `/tce:research`.
- [ ] `ticket.sh` and `stage.sh` discover the intent as they discover
      research and plan documents; `/tce:list` shows whether an intent exists.
- [ ] `profile.md` template, `init.md` (gather item, dialog copy, fill,
      Idempotency bullet), `refresh.md` (hand-authored list) and the tce
      README gain `## Reader` and `## Delivery` following the
      branch-convention pattern (TP-0031); a profile without either section
      changes no behaviour.
- [ ] The three-part sufficiency test (TP-0022 span) is reconciled: the intent
      is the canonical place it is applied; `research.md` and `work.md` are
      updated minimally in the same commit (TP-0045b and c replace them).
- [ ] CLAUDE.md records the same-commit span for the intent (template,
      command, scripts, `list.md`) and extends the profile-section spans; tce
      version bumped and tagged.

## Out of Scope

- Any change to how research, plan or implement run (TP-0045b/c). The existing
  single-step commands get at most a one-line "if an intent exists, read it
  after the ticket".
- A profile migration that writes the new sections without asking.
- Pull request creation itself (TP-0045b consumes `## Delivery`).
- A `/tce:discuss` → `/tce:intent` automation beyond a hand-off hint.

## Open Questions

None.

## Questions for Research/Planning

- [ ] The intent template's sections and frontmatter, and how much of
      `ticket.md`'s dialogue text moves versus is referenced.
- [ ] How `ticket.sh`'s substring match and `stage.sh`'s delimited match pick
      the intent up, and how a ticketless intent is addressed by later
      commands (`/tce:work <intent path>`?).
- [ ] Which commands or habits fold content into tickets today and where that
      content now lands.
- [ ] The exact wording of the `## Reader` prompt so the model applies it to
      vocabulary and depth, not length.
- [ ] Whether `## Delivery` needs the remote and base branch or repeats
      `## Branch convention`'s.

## References

- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md` — the epic
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md` —
  "The human-facing layer", items 1 and "The reader section", and "Delivery"
- `plugins/tce/commands/ticket.md` — the dialogue being moved; `discuss.md`
- `plugins/tce/templates/tce/profile.md`, `commands/init.md`, `refresh.md` —
  the branch-convention pattern to follow
- `plugins/tce/scripts/ticket.sh`, `stage.sh`; `commands/list.md`

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-10-11

- Sized Medium, not Large, by user decision: the dialogue exists in
  `/tce:ticket`; the work is moving it off the ticket onto a new file type
  plus two profile sections in an established pattern.
- `/tce:intent` is unflagged by user decision: intents are regularly created
  from interactive and discussion sessions, and quickfix invokes it.
- Intents may exist without a ticket (quickfix, TP-0045c).
