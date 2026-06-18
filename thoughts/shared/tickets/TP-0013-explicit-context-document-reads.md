# TP-0013: Commands must explicitly re-read their input context documents

**Status:** In Progress
**Estimated Complexity:** Small
**Created:** 2026-06-18
**Updated:** 2026-06-18

## Problem Statement

The tce workflow is a chain — `/tce:ticket` → `/tce:research` → `/tce:plan` →
`/tce:implement` (plus `/tce:review`, and the composites `/tce:work` and
`/tce:quickfix` that run several steps back-to-back). Each step produces a **context
document** (the ticket file, the research doc, the plan doc) that the next step is
meant to consume.

In practice, when a consuming command runs **in the same conversation** where an
earlier step already ran — most acutely inside the composites and back-to-back
single-step runs — the command leans on what is already in the conversation history
instead of **explicitly re-reading the context document(s) it depends on**. That is
not intended: it weakens the model's attention on the content that matters to the
current step, since the relevant document is buried in surrounding history rather than
freshly read.

The intent is that every consuming command **always** fully reads its input context
documents when invoked — even if it "remembers" them or just produced them — so that
the step's attention is freshly anchored on the inputs that matter, without losing the
surrounding conversational history.

## Desired Outcome

When this is complete, the following is true:

- Every consuming tce command explicitly reads its full input context document(s) on
  **every** invocation — unconditionally, even when the document already appears
  earlier in the conversation or was produced by a prior step of a composite run.
- The reads happen **in chain order** (the order of the workflow), e.g.
  `/tce:implement` reads ticket → research → plan; `/tce:review` reads ticket → plan →
  implementation; `/tce:plan` reads ticket → research.
- The behavior is captured as a **durable design rule** in the repo's `CLAUDE.md`, so
  future command edits preserve it, alongside the per-command instructions.

## User Stories / Use Cases

- As a tce user running `/tce:work` or `/tce:quickfix`, I want each downstream step to
  freshly read its inputs so that the step's output is grounded in the actual ticket /
  research / plan content, not a fading memory of it from earlier in the chat.
- As a tce user resuming mid-chain in an existing conversation, I want the next command
  to re-read its inputs so its quality matches running it in a fresh session.
- As a maintainer of the tce plugin, I want a documented rule so that when I edit or add
  commands I keep the explicit-re-read behavior intact.

## Acceptance Criteria

- [ ] Each consuming command (`research`, `plan`, `implement`, `review`, `work`,
      `quickfix`) contains explicit, **unconditional** instruction to read its input
      context document(s) in full at the start of the relevant phase — wording does not
      allow "skip if already read / already in context".
- [ ] The instructions specify reading inputs **in chain order** for commands with more
      than one input (e.g. implement: ticket → research → plan; review: ticket → plan →
      implementation; plan: ticket → research).
- [ ] The composite commands (`work`, `quickfix`) re-read inputs at each downstream step
      they drive, even though prior steps ran in the same context (consistent with the
      "composite commands must track the single-step commands" rule in CLAUDE.md).
- [ ] A durable rule is added to the repo `CLAUDE.md` stating that consuming commands
      must explicitly re-read their input context documents in chain order on every
      invocation.
- [ ] No change to what each command writes, the chain structure, or the documents'
      content/format.

## Out of Scope

- Restructuring the workflow chain or changing which document each step consumes.
- Changing what each command **writes** or the layout of the ticket/research/plan docs.
- Any read deduplication or "optimization" to avoid re-reading — the explicit re-read is
  the desired behavior, not a cost to minimize.
- Behavior of non-consuming commands that have no upstream context document input.

## Open Questions

None — the desired behavior and scope were confirmed during ticket creation.

## Questions for Research/Planning

- [ ] For each consuming command, what are its exact input context documents and the
      correct chain order to read them in?
- [ ] Where in each command's markdown is the current read instruction (if any), and is
      it conditional / implicit today? Identify the precise edit sites.
- [ ] Does the discovery/lookup of the prior documents (e.g. via the thoughts lookup by
      ID) already exist in each command, so only the "always read in full" framing needs
      tightening, or is a read step missing anywhere?
- [ ] Where should the durable rule live in `CLAUDE.md`, and should it cross-reference
      the existing "composite commands must track the single-step commands" and
      "`/tce:refresh` re-analysis must track `/tce:init`" rules?

## References

- `CLAUDE.md` — "Composite commands must track the single-step commands" rule (the
  composites are a primary place this behavior matters).
- `plugins/tce/commands/{research,plan,implement,review,work,quickfix}.md` — the
  consuming commands to edit.
- `plugins/tce/scripts/ticket.sh` — thoughts lookup by ID (how commands locate prior
  context documents).

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-06-18
Key decisions made during ticket creation:
- Root concern confirmed as same-context / composite runs, but the fix must apply to
  **all** consuming commands on **every** invocation, not only composites.
- Inputs must be read **in chain order** (workflow order) — added as an explicit
  requirement at the user's request.
- Confirmed a durable `CLAUDE.md` rule should accompany the per-command edits.
- Scoped as Small: markdown command wording plus one documented rule; no code changes.
