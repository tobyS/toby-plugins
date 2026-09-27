# TP-0042: tsf — verification must judge whether the ticket's tests are meaningful

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-09-27
**Updated:** 2026-09-27

## Problem Statement

The verification pipeline checks that the plan's criteria were met and that the
spec was covered, both from the diff — but nothing judges the *tests* the
implementation added. Plan compliance reads the criteria + the diff, spec
coverage reads `spec.md` + the diff, security reads the diff and its
surroundings; none of them asks "would these tests fail if the behaviour broke?"

So both of these leave the pipeline green:

- a test that exists, passes, and asserts nothing meaningful — a mock asserting
  itself, a tautology, an assertion on the value just constructed;
- a ticket requirement that the implementation satisfies and no test pins.

For an unattended factory this is the main long-term risk: over many tickets the
suite accumulates tests that are green by construction, and nothing in the cycle
notices.

## Desired Outcome

Verification returns an evidenced verdict on the ticket's tests: that each test
added or changed in the ticket's scope asserts the behaviour it claims, and that
the ticket's requirements are exhaustively pinned by tests, naming any
requirement no test covers. A weak or missing test set routes like any other
failing verdict — back to implementation in fix mode, bounded, then
`tsf:needs-human`. Requirements that genuinely cannot be tested automatically
land in the dossier's human checklist rather than passing silently.

## User Stories / Use Cases

- As the factory's human, I want a green pipeline to mean the tests would actually
  fail if the behaviour broke, so that I can trust unattended landings across
  many tickets.
- As the factory's human, I want to be told at review time which of the ticket's
  requirements no test pins, so that I know exactly where the gap is.
- As the factory's operator, I want a tautological test rejected at verification
  instead of landed.

## Acceptance Criteria

- [ ] Every verification episode produces an evidenced verdict on test
      meaningfulness and on test coverage of the ticket's requirements.
- [ ] Per requirement, the output is one of: pinned by test (with the test's
      `file:line`), pinned weakly (with why), not pinned, or not automatically
      testable.
- [ ] A vacuous, tautological or self-asserting test is a finding, with evidence
      and what would make it real.
- [ ] Blocking findings route into fix mode exactly like a "not met" verdict,
      under the existing fix bound, with `tsf:needs-human` on exhaustion.
- [ ] "Not automatically testable" travels to the dossier's human checklist and is
      never silently passed.
- [ ] The judgment runs in a fresh context that never sees the implementation's
      reasoning or transcript.
- [ ] Evidence cites post-change source line numbers, never patch-file offsets
      (the TP-0039 C2 rule).
- [ ] Whatever shape it takes, these move in the same commit: the report
      contract, DESIGN.md §7/§11.2 including the gate count, `cycle-dispatch.md`,
      `cycle.md`, `report.md`, `plugins/tsf/README.md`, and `CLAUDE.md`'s rule
      that names "the **four** gate agents".

## Out of Scope

- Coverage tooling or percentage thresholds — this is a judgment, not a metric.
- Requiring tests where the project's own conventions do not; the project's stack
  and test conventions govern.
- Judging the project's pre-existing tests outside the ticket's diff.
- Making the gate family configurable (still future work per §7).
- Plan-time criteria quality — TP-0041 criterion (b) covers whether criteria are
  agent-verifiable.

## Open Questions

None.

## Questions for Research/Planning

- [ ] A fifth gate, or an extension of spec coverage (which already receives the
      spec + the diff) or of plan compliance? What does each cost in contract
      churn, tokens, and the parallel-dispatch budget?
- [ ] Does judging tests need more than the diff — the test files at head, the
      code under test, the project's test conventions from the profile? Does that
      widen a starved payload past §11.2?
- [ ] How is "in scope of the ticket" delimited — the test files in the pull
      request diff?
- [ ] How does this verdict avoid double-reporting the same requirement alongside
      plan compliance's per-criterion verdicts?
- [ ] Does the `<gate>-<episode>-<round>.md` numbering extend as-is?

## References

- DESIGN.md §7 (the verification pipeline and its four gates), §11.2 (per-agent
  inputs), §6.7 (the verification-fix episode and its bounds)
- `plugins/tsf/agents/spec-coverage.md`, `plugins/tsf/agents/plan-compliance.md`
- TP-0039 (C2 — post-change line numbers, never patch offsets)
- TP-0041 — the plan challenge phase, which catches unverifiable criteria before
  they reach implementation

## Implementation Plan

## Notes & Updates

### 2026-09-27

Created from the user's feedback. The shape — fifth gate versus an extension of
an existing one — is deliberately left to research and planning, because it is
the decision that determines whether this is Medium or Large: a fifth gate
touches the gate count, the parallel dispatch, the report naming and the
CLAUDE.md governance rule, while an extension of spec coverage touches one agent.
Estimated Large on the assumption research finds the extension path too narrow
for a payload that must include the test files.
