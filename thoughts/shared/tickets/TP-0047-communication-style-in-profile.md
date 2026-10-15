# TP-0047: let the project profile describe how tce asks questions

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-10-15
**Updated:** 2026-10-15

## Problem Statement

tce prescribes *how* questions are asked. The thirteen copies of the
AskUserQuestion dialog guidelines say to use the dialog whenever 2–4 concrete
options exist, and the orchestrating `/tce:work` (TP-0045b) requires its plan
approval and its closing check to go through AskUserQuestion. In the first
real `/tce:work` run (GH-37 in chat-sustainability, 2026-10-14) both were asked
in prose instead — and the human preferred that: when a question needs more
context, a prose question carries it better than a dialog whose question text
must be bare and whose option descriptions are one or two sentences.

How a person wants to be asked is a property of the person, like the
`## Reader` section already captures their fluency. Today nothing records it,
so every command hardcodes one style.

## Desired Outcome

- The project profile gains a way to describe the communication style — at
  least when to ask in a dialog and when in prose, and how much context a
  question carries — agreed at `/tce:init` and preserved by `/tce:refresh`, as
  the Reader section is (possibly as part of it).
- Commands and agents that ask questions read it and leave the choice of
  form to the agent within it, instead of mandating AskUserQuestion. This
  includes loosening `/tce:work`'s "ask through AskUserQuestion" invariant.
- A missing section keeps today's behaviour.

## Acceptance Criteria

- [ ] The profile template, `/tce:init` (dialog, fill, Idempotency bullet),
      `/tce:refresh` and the tce README describe the new setting.
- [ ] The commands with dialog sites and `/tce:work`'s orchestrator read it;
      none mandates a question form the setting rules out.
- [ ] `/tce:work` no longer requires AskUserQuestion for plan approval and the
      closing check, and states what happens when the answer arrives in a
      later turn (the position is re-derived from disk; the turn-scoped
      `allowed-tools` grant is renewed by re-invoking `/tce:work`).
- [ ] CLAUDE.md records how the new setting relates to the duplicated
      AskUserQuestion guidelines block.

## Out of Scope

- Rewriting the AskUserQuestion guidelines block itself beyond what the
  setting needs.
- tsf's issue-comment questions (a different medium).

## Open Questions

- One section ("Communication style") or an extension of `## Reader`?
- Does the setting live in tce only, or should tmt/tle/tsf commands with
  dialog sites read it too (they cannot read tce config — cross-plugin rule)?

## References

- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` —
  the GH-37 run review (finding 3.1)
- `plugins/tce/commands/work.md` (invariant 5, Steps 6 and 12)
- `plugins/tce/templates/tce/profile.md` (`## Reader`)
- CLAUDE.md, "The AskUserQuestion guidelines block is duplicated"

## Notes & Updates

### 2026-10-15

- Created from the human's feedback on the GH-37 run: "I actually like prose
  questions more, when questions need more context. We should leave it more
  open to agents, how questions are asked."
