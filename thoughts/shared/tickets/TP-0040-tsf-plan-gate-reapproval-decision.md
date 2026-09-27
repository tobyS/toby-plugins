# TP-0040: tsf — decide at the plan gate whether a revised plan needs re-approval

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-27
**Updated:** 2026-09-27

## Problem Statement

At the plan gate the human's reply is classified binarily: an approving reply
moves the ticket to `tsf:implement`; *anything else* is feedback — the plan is
revised, re-summarized and parks at `tsf:needs-plan-approval` again (DESIGN.md
§6.3; `agents/plan.md`'s "Which values go together"; `cycle-dispatch.md` row 1).

A reply that approves the plan's intent and asks for one small adjustment
("fine, but call it X", "yes, also handle the empty case") therefore costs a
second human round-trip and at least one idle wait — the factory asks twice for
a decision the human already made, against §1's promise that after the plan
approval and the review approval nothing else is asked of them.

The safety net that makes relaxing this safe already exists: the human still
reviews the pull request before anything lands (§9.2), so an adjustment made
inside already-approved intent is not unreviewed — it is reviewed later, in the
review the human was going to do anyway.

## Desired Outcome

The plan step classifies a non-pure-approval reply into one of two cases:

- **The plan's decisions, trade-offs and increment set stand; this is detail
  inside them** → fold the adjustment into `plan.md` and continue to
  `tsf:implement` in the same cycle.
- **This changes a decision, the scope or a trade-off** → revise, re-summarize
  and park for approval, exactly as today.

The rule is stated in the plugin rather than improvised per run, the decision
and its grounds are visible to the human in the outcome comment and in the
journal, unclear cases fail closed (re-park), and the human can always demand
re-approval.

## User Stories / Use Cases

- As the factory's human, I want a plan I approved with a one-line tweak to go
  straight into implementation, so that I am not asked again for a decision I
  already made.
- As the factory's human, I want the proceed-without-re-approval decision named
  in the issue comment and the journal, so that I can see what was folded in and
  object before the pull request arrives.
- As the factory's human, I want a reply that changes a decision or the scope to
  still come back for approval, so that the plan gate keeps its purpose.

## Acceptance Criteria

- [ ] The proceed-vs-re-approve rule is stated as explicit, closed criteria (not
      "use judgment") in the plan agent's contract and in DESIGN.md.
- [ ] A reply that approves and requests only adjustments leaving the plan's
      decisions, trade-offs and increment set intact yields
      `next-label: tsf:implement` in a single cycle, with the adjustment written
      into `plan.md`.
- [ ] A reply that changes a decision, adds or removes scope, or rejects a
      trade-off yields `tsf:needs-plan-approval`, as today.
- [ ] A reply whose classification is genuinely unclear re-parks for approval
      and says why (fails closed).
- [ ] When the step proceeds without re-approval, the issue comment names what
      was folded in and states that it proceeded without re-approval; the journal
      entry records the same decision.
- [ ] The human has a documented way to demand re-approval regardless.
- [ ] Every contract touched moves in the same commit: the plan agent's return
      values, `result-block.md`'s outcome table, `cycle-dispatch.md` row 1, and
      `journal-entry.md`.

## Out of Scope

- The final pull-request review gate — unchanged and still mandatory.
- Any similar relaxation at the review gate (`tsf:rework`) or at
  `tsf:needs-answer`.
- Making the rule project-configurable (a config constant or threshold).
- Batching or re-ordering several replies.

## Open Questions

None.

## Questions for Research/Planning

- [ ] Does the classification belong in the plan agent's own prompt, or in a
      separate read-only judgment? A self-classifying agent judges its own
      eagerness to proceed.
- [ ] Does row 1's `implement`-question exception (an implementation question is
      a plan-gate question, §6.3) get the same treatment, or must it always
      re-park?
- [ ] On the proceed path, does the human get a "what changed" line, or only the
      outcome comment?
- [ ] Does `result-block.md` need a new row or value, and `journal-entry.md` a
      new field, for "continued after folding feedback"?
- [ ] Interaction with TP-0041: does a plan that survived a challenge widen the
      legitimate "proceed" class?

## References

- DESIGN.md §6.3 (the reply is the approval channel), §6.5 (the plan summary),
  §9.2 (the review approval)
- `plugins/tsf/agents/plan.md`; `plugins/tsf/references/cycle-dispatch.md` row 1
- TP-0041 — the plan challenge phase

## Implementation Plan

## Notes & Updates

### 2026-09-27

Created from the user's feedback after the first factory runs. Scoped
deliberately narrow: only the plan gate, only the classification of a reply that
already approves. The review gate is untouched, which is what makes the
relaxation safe — every folded-in adjustment still reaches the human at the
pull-request review.
