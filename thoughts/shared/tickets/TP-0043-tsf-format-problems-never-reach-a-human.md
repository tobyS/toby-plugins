# TP-0043: tsf — a format problem in a factory artifact must never reach a human

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-28
**Updated:** 2026-09-28

From the chat-sustainability GH-41 run (2026-09-27/28). An approved plan reached
implementation, the agent built and committed five commits, and the ticket then
parked `tsf:needs-human` because `plan.sh check` rejected the addendum the agent
wrote — twice. The human's attempt to re-queue it bounced as well. The work sat
stranded behind a parked label until a human checked out the branch and edited a
markdown field by hand.

## Problem Statement

Three failures compound, and each is the factory's own fault rather than the
human's:

1. **The parser is brittle where a reader would not be.** `plan.sh` requires an
   increment's or addendum's verification to be a **bullet** (`- **Verification:**`)
   and stops reading it at the **first blank line**. The agent wrote
   `**Verification (restated in full):**` followed by a numbered list — a form no
   reader would misunderstand, and which the parser rejects outright.
2. **A plan that does not parse escalates to a human.** `plan.md` is the
   factory's own artifact, in the factory's own format, written by its own
   agent. A human has no business checking out a branch to repair it: they did
   not write it and the format is not theirs.
3. **The park comment was a diagnostic, not an instruction**, and the human's
   reasonable recovery attempt was refused rather than resolved.

## Evidence from the run

- `plan.sh check` on the branch at `353f939`: `result: invalid` —
  "the addendum dated 2026-09-27 for increment 1 restates no `**Verification:**`
  or `**Manual:**` field". Adding a single `- ` prefix turns it into
  `result: ok`. Verified on the real artifact.
- The agent's one retry, commit `353f939` ("restate increment 1 addendum
  verification field"), changed `**Verification (restated in full):**` to
  `**Verification:**` — a correct reading of the message — and still failed,
  because the message names the field but not its **shape**.
- The first park comment read: "parked for a human: agent returned no valid
  result twice (plan.sh check: the addendum dated 2026-09-27 for increment 1
  restates no `**Verification:**` or `**Manual:**` field)". It says nothing about
  what the human should do.
- At 05:12Z the human set `tsf:answered`. The dispatcher refused it as a state
  mismatch and re-parked. The comment-pickup workflow had set `tsf:answered`
  automatically twice earlier in the same ticket (17:41Z, 17:50Z), so the system
  itself had taught that label as "the human acted".

## Corrections

### P1 — liberal in shape, strict in substance

**Finding.** Two distinct defects in `plugins/tsf/scripts/plan.sh`:

- **Shape.** The field is recognized only as `- **Verification:**`
  (`plan.sh:181`, `:188`). A bare-paragraph `**Verification:**`, or a trailing
  qualifier such as `(restated in full)`, is not matched.
- **Truncation, and it is silent.** A field's text ends at the first blank line
  (`plan.sh:196`), so a list-shaped or multi-paragraph restatement loses its
  body — while `check` still reports `ok`. Reproduced on a synthetic plan: a
  list-shaped `**Verification:**` yields the criterion
  "Increment 1 (…): the suite asserts:" with every assertion dropped. The
  plan-compliance gate then judges a criterion with no content and reports it
  met. This affects increments exactly as it affects addenda.

**Fix.** Accept the field in any form a reader would (bullet or paragraph, with
or without a trailing parenthetical), and capture its text until the next field,
heading or section rather than the first blank line. Keep the substance check:
every increment must state a verification.

**`check` and `criteria` must agree.** Today a plan can pass `check` while
`criteria` emits an empty criterion. `check` must validate the text the
extraction will actually produce, not the presence of a marker.

**Done when.** The GH-41 addendum as the agent originally wrote it parses, its
ten assertions survive into the criteria file, and a plan whose increment
extracts to an empty criterion is `result: invalid`.

### P2 — the factory repairs its own artifacts

**Finding.** There are two invalid-return retry paths and only one of them names
the required shape:

- `references/templates/result-block.md:177` — TP-0039 C1 fixed this: the note
  now points at the template **and** the agent's own `## Return` section.
- `commands/cycle.md:252` — the plan-check path still forwards
  `note: <the detail line>` verbatim, and that line is `plan.sh`'s.

So the single re-dispatch tsf grants was spent on a guess the message made
unguessable.

**Fix.** Two steps:

- The plan-check retry note carries the **required shape** — the template's
  field skeleton — not just the complaint.
- If the retry still fails, park as a **question** (`tsf:needs-answer`), not as
  `tsf:needs-human`: the comment carries the offending text and the shape it
  must take, and the reply is folded by the parking step. A human fixes it by
  replying on the issue, never by checking out the branch.

**Generalize it.** "A machine contract's error must show the shape, not only
name the field" becomes a rule in CLAUDE.md covering both paths, so the next
contract added does not repeat this.

**Done when.** A deliberately malformed addendum is repaired by the factory
within its bounds, and the escalation that does happen is answerable from the
issue.

### P3 — park comments are instructions, and label mistakes resolve gracefully

**Finding.** The park comment is written for whoever wrote the dispatcher. The
human is expected to know what `plan.sh` is, that a "result block" exists, and
which of fourteen labels re-queues a ticket.

**Fix.**

- Every park comment carries, in plain language: what happened, what it means
  for the ticket, what the human should do, and the exact label to set. The
  diagnostic string stays in the journal, where it belongs.
- **`tsf:answered` on a `tsf:needs-human` park resumes the ticket** — with the
  reply folded in when there is one, exactly as P2's question park expects. The
  dispatcher knows where the ticket stood; re-parking to teach vocabulary is
  hostile, and the pickup workflow teaches that very label. "Never guess a
  state" stops the dispatcher inventing *workflow* state; mapping one
  unambiguous human "I have acted" signal onto another is not guessing.

**Done when.** A park comment tells a human with no knowledge of tsf's internals
what to do next, and either `tsf:queued` or `tsf:answered` resumes a
`needs-human` ticket.

## Acceptance Criteria

- [ ] P1: `plan.sh` accepts bullet and paragraph field forms and a trailing
      parenthetical; field text is captured to the next field/heading/section;
      the GH-41 addendum as originally written parses with its ten assertions
      intact in the criteria file.
- [ ] P1: `check` fails a plan whose increment would extract to an empty or
      trivial criterion — `check` and `criteria` never disagree.
- [ ] P2: the plan-check retry note carries the field skeleton; a second failure
      parks `tsf:needs-answer` with the offending text, answerable on the issue.
- [ ] P2: CLAUDE.md carries the "an error must show the shape" rule naming both
      retry paths.
- [ ] P3: park comments state what happened, what it means, what to do and which
      label, with the diagnostic in the journal only.
- [ ] P3: `tsf:answered` on a `needs-human` park resumes rather than re-parks.
- [ ] `claude plugin validate ./plugins/tsf` passes; the CLAUDE.md same-commit
      spans for the plan contract, the result block and the park sequences are
      honoured.

## Out of Scope

- Plan quality and verification depth — TP-0040, TP-0041, TP-0042.
- Removing the plan check entirely. The dispatcher cannot read artifact content
  (`cycle.md` invariant 3), so something mechanical must gate the handoff; the
  fix is tolerance and honest diagnostics, not removal.
- The pre-commit hook that rejected the human's repair commit in the worktree
  (`prek`, missing `.pre-commit-config.yaml`) — that is `plugins/tsf/TODO.md`'s
  "Survive a project hook that rewrites or rejects a bookkeeping commit", now
  observed against a human rather than the factory.
- Changing how the comment-pickup workflow assigns `tsf:answered`.

## Open Questions

- P1: should the tolerated shapes be listed in `references/templates/plan.md`,
  or should the template keep showing exactly one canonical form while the
  parser quietly accepts more? (Showing one form keeps agents consistent;
  listing them invites drift.)
- P3: does `tsf:answered` on a `needs-human` park need a reply to be present, or
  should a bare relabel resume just like `tsf:queued`?

## Questions for Research/Planning

- [ ] P1: where exactly `check`'s substance test should live so it shares one
      code path with `criteria`'s extraction rather than re-deriving it.
- [ ] P2: whether the question park reuses `tsf:needs-answer` as-is or needs a
      distinct journal outcome, given row 1 folds replies into `spec.md` or
      `plan.md` by parking step.
- [ ] P3: the full inventory of park sites in `references/cycle-write-phase.md`
      that must gain the instruction structure.

## References

- Run: chat-sustainability GH-41, journal entries `2026-09-27T18:07Z` (plan
  check park) and `2026-09-28T05:12Z` (state mismatch park); issue comments
  18:48:16Z and 05:13:14Z; label events 17:41Z, 17:50Z, 05:12Z.
- Repair commit `f116634` on `gh-41` — the manual intervention this ticket
  exists to abolish.
- `plugins/tsf/scripts/plan.sh:181`, `:188` (bullet requirement), `:196`
  (blank-line flush), `:198-201` (continuation join).
- `plugins/tsf/commands/cycle.md:240-252` (the plan-check retry path),
  `plugins/tsf/references/templates/result-block.md:170-179` (its fixed twin).
- `plugins/tsf/references/cycle-dispatch.md` row 1 and row 3;
  `plugins/tsf/references/cycle-write-phase.md` park sequences;
  `plugins/tsf/README.md` Labels table.
- TP-0039 (the first-run corrections; C1 fixed one of the two retry paths).

## Implementation Plan

## Notes & Updates

### 2026-09-28

- Raised from the GH-41 run analysis. The three parts match the three points the
  user made: tolerant parsing, no human in the codebase for a transport-format
  problem, and park comments that instruct rather than diagnose.
- P2 and P3 converge on one mechanism: if a format park becomes a question park,
  `tsf:answered` means "the human acted" everywhere, with no exception to learn.
- The GH-41 run used tsf **1.1.1**; 1.2.0 would have failed identically, since
  TP-0039 never touched `plan.sh`.
