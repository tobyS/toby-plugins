# TP-0046: tce — verification must judge whether the ticket's tests are meaningful

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-10-11
**Updated:** 2026-10-11

Follow-up to the TP-0045 epic. Scheduled after TP-0045b has run real tickets,
so the gate joins a verification flow that exists.

## Problem Statement

Once the plan is approved from a brief and nobody reads it (TP-0045), the only
thing standing between an implementation and "done" is verification. tce's
verification checks that the plan's criteria were met from the diff and that
the tests pass. Nothing asks whether the tests would fail if the behaviour
broke. A test that asserts a mock against itself, a tautology, or an assertion
on the value just constructed leaves the chain green, and a requirement the
implementation satisfies but no test pins is never noticed.

tsf has the same gap open as TP-0042. With tce moving to agent-run steps, the
same risk arrives here: over many tickets a suite accumulates tests that are
green by construction, and nothing in the chain notices.

## Desired Outcome

Verification returns an evidenced verdict on the ticket's tests: each test
added or changed in the ticket's scope asserts the behaviour it claims, and
the intent's requirements are pinned by tests, with every unpinned requirement
named. A weak or missing test set routes like any other failing verdict — back
into the bounded fix loop, then to the human as "needs decision". Requirements
that genuinely cannot be tested automatically land in the dossier's human
checklist instead of passing silently.

## User Stories / Use Cases

- As the approving human, I want a green chain to mean the tests would fail if
  the behaviour broke, so that not reading the plan stays a safe bet.
- As the approving human, I want to see at the end which requirements no test
  pins, so that I know exactly where the gap is.
- As a tce consumer, I want a tautological test rejected at verification
  instead of committed.

## Acceptance Criteria

- [ ] Every verification run produces an evidenced verdict on test
      meaningfulness and on test coverage of the intent's requirements.
- [ ] Per requirement, the output is one of: pinned by test (with
      `file:line`), pinned weakly (with why), not pinned, or not automatically
      testable.
- [ ] A vacuous, tautological or self-asserting test is a finding with
      evidence and what would make it real.
- [ ] Blocking findings route into the fix loop exactly like a "not met"
      criterion, under the existing bound, with "needs decision" on
      exhaustion.
- [ ] "Not automatically testable" travels to the dossier's human checklist
      and is never silently passed.
- [ ] The judgment runs in a fresh context that never sees the
      implementation's reasoning or transcript, and is criteria-only by prompt
      constraint like the compliance checker.
- [ ] Counted into the dossier: requirements pinned n/m, weak tests found,
      tests added.

## Out of Scope

- Changes to tsf (TP-0042 covers the factory side independently).
- Mutation testing or any tool-based test-quality metric; the judgment is an
  agent reading tests against requirements.
- Judging the pre-existing test suite; only tests added or changed in the
  ticket's scope.
- Deciding the fix-loop bound; TP-0045b defines it, this ticket reuses it.

## Open Questions

None.

## Questions for Research/Planning

- [ ] Whether this is a separate agent or a mode of the TP-0045b verifier, and
      what it receives (the intent's requirements, the diff, the test files;
      never the plan prose).
- [ ] How a "not pinned" requirement is distinguished from one the intent
      marks as manual.
- [ ] How the verdict feeds the dossier counts and the fix loop's counter on
      disk.
- [ ] Whether the compliance checker's criteria-only envelope is reused
      verbatim.

## References

- `thoughts/shared/tickets/TP-0042-tsf-meaningful-tests-at-verification.md` —
  the tsf sibling; same problem, factory routing
- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md` — the epic
  this follows; TP-0045b defines the verifier and the fix loop
- `plugins/tce/agents/plan-compliance-checker.md` — the criteria-only envelope
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md` —
  "Verification and agent-to-agent checks"

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-10-11

- Created as the follow-up split out of TP-0045 by user decision: stage 1 of
  the orchestrator stays small enough to learn from and to revert, and the
  gate is designed against a verification flow that has run real tickets.
- Mirrors TP-0042's criteria with tce's routing (fix loop → "needs decision",
  dossier checklist) in place of tsf's (fix mode → `tsf:needs-human`).
