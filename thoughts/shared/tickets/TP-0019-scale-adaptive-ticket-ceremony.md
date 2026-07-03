# TP-0019: Scale-adaptive ceremony in /tce:ticket

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-07-03
**Updated:** 2026-07-03

## Problem Statement

The independent plugin review (`plugins/tce/fable_review.md`, Section 2,
finding 7) found `/tce:ticket`'s interaction ceremony is fixed-size: seven
discussion phases with three hard "do not proceed until the user confirms"
gates, regardless of ticket size. That is right for a Large feature and
exhausting for "rename this setting and add a tooltip." The workflow currently
offers `/tce:quickfix` at the bottom and full ceremony at the top, with
nothing between — and forcing full ceremony on small-but-not-quickfix tickets
is the most common reason users route around a structured workflow (the
review's competitive survey found every surviving competitor grew a
scale-adaptive path: Kiro Quick Plan, BMAD Quick Flow; Spec Kit's lack of one
is its top criticism).

## Desired Outcome

`/tce:ticket` sizes its process to the ticket. For Small/Medium tickets the
discussion phases collapse into at most two batched interaction rounds (one
consolidated understanding-plus-draft round, one final confirmation) — while
Large/XL tickets keep the current full phase gates. The resulting ticket body
is identical in structure and quality on both tracks; only the interaction
density differs. The user can always force the full ceremony.

## User Stories / Use Cases

- As a tce user filing a small, well-understood ticket, I want one or two
  focused confirmation rounds instead of seven gated phases so that creating
  the ticket takes minutes, not a meeting.
- As a tce user shaping a Large feature, I want the full guided discussion
  (unchanged) so that scope, criteria, and boundaries get properly negotiated.
- As a tce user, I want the command to escalate to full ceremony if the
  "small" ticket turns out to be bigger than it looked.

## Acceptance Criteria

- [ ] `ticket.md` establishes an early size assessment (the command proposes a
      complexity estimate with one-line reasoning; the user can override) and
      two interaction tracks keyed on it.
- [ ] Small/Medium track: at most two interaction rounds before creation —
      excluding genuinely unresolved business questions, which always warrant
      asking (per the AskUserQuestion dialog guidelines).
- [ ] Large/XL track: the current seven-phase ceremony, unchanged.
- [ ] Both tracks produce the same ticket body structure ("The ticket body"
      template) at the same quality bar — the compressed track fills the same
      sections, it just batches the questions.
- [ ] Escalation rule: if the discussion reveals larger scope or unresolved
      complexity, the command says so and switches to the full ceremony.
- [ ] The user can explicitly request the full ceremony regardless of size.
- [ ] Autonomous mode (`--autonomous`, used by `/tce:quickfix`) is unaffected;
      the byte-identical AskUserQuestion guidelines block is untouched (or, if
      it must change, all nine copies change in the same commit per the
      CLAUDE.md rule).

## Out of Scope

- Changing the ticket body template or "What tce needs from a ticket".
- Scale-adapting other commands (research/plan depth) — separate concern.
- `/tce:quickfix` behavior.

## Open Questions

None at ticket level — the two-track shape was agreed at creation; the exact
assessment mechanics are a planning question.

## Questions for Research/Planning

- [ ] How the size assessment is presented (fold it into the first response
      alongside the restated understanding, so it costs no extra round).
- [ ] How to phrase the compressed track so the model doesn't skip the
      substance (acceptance criteria still testable, out-of-scope still
      explicit) while batching the confirmation.
- [ ] Whether the review's own competitive references (Kiro Quick Plan, BMAD
      Quick Flow) suggest wording patterns worth borrowing.
- [ ] Whether `work.md`/`quickfix.md` mirror anything from ticket.md's
      discussion process that this change touches (expected: no — quickfix
      delegates to autonomous mode — but verify per the composite rule).

## References

- `plugins/tce/fable_review.md` — Section 2, finding 7 and Section 3
  (competitive evidence); uncommitted at ticket-creation time.
- `plugins/tce/commands/ticket.md` — the Discussion Process phases and gates.
- `CLAUDE.md` — AskUserQuestion duplication rule, composite-tracking rule.

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5). Motivating example: this
very ticket batch — five well-understood maintenance tickets created in one
confirmation round, which the current command text technically doesn't
provide for.
