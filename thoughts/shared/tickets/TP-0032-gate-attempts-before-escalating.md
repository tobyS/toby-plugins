# TP-0032: Plan-Compliance Gate must attempt verification before escalating to the user

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-08
**Updated:** 2026-09-08

## Problem Statement

The Plan-Compliance Gate treats its own non-"met" verdicts as a hand-off to the
human instead of as a work list for itself. Two separate defects, both in step 4
of the `## Plan-Compliance Gate` section of `implement.md`:

1. **"cannot verify from diff" is a structural artifact, not a finding.** The
   `plan-compliance-checker` agent has no shell by design (`Read, Grep, Glob,
   LS`), so *every* command-shaped criterion — run the tests, run the formatter,
   build the binary — necessarily lands in that bucket regardless of whether it
   passes. The bullet says "investigate" but never says why these items appear
   there, or that the remedy is usually just to run the command and record the
   output.
2. **The MANUAL label is never re-tested.** It is inherited verbatim from the
   plan, which was written before any code existed by someone with no build.
   `implement.md` goes straight from "needs human verification" to "list them and
   ask the user" — there is no instruction to try discharging an item first.

Observed on tideways/apm, ticket GH-10848a (a Go CLI change): the gate returned 4
MANUAL + 3 "cannot verify" items and the agent escalated all 7 with zero attempts.
On pushback, 6 of the 7 turned out to be dischargeable in-session:

- The 3 "cannot verify" items were `go test`, `gofmt -l` and `go build` — the
  agent had already run all three and they were green.
- 2 of the 4 MANUAL items were already pinned by existing automated tests (an
  exact error string in `project_test.go`; zero-argument resolution tests for
  service/project/run).
- A 3rd became automatable — the agent wrote the missing test for the
  project-less `error list` form once asked.
- The CLI binary built trivially (`go build -o /tmp/tideways .` from
  `golang/cmd/cli`), but only after the user asked whether it could.

Genuinely human-only in the end: one item needing an API token plus a live
endpoint, one agent-behaviour spot-check, and one read-and-judge item.

This lands hardest in `/tce:work` and `/tce:quickfix`, which removed the
intermediate human review — the gate is their *only* exit check, and it currently
converts itself into a homework list.

## Desired Outcome

When the gate finishes, every criterion it did not mark "met" has been attempted
by the agent, and the user sees only items that genuinely require a human — each
with a copy-pasteable command, a pass/fail reading, and one line on why it could
not be done in-session. Concretely:

- Command-shaped criteria are run and reported with their real output, never
  escalated.
- Every MANUAL item is checked against existing automated coverage, against a
  build-and-run of the artifact, and against whether the behaviour is testable —
  before any of them is escalated.
- The escalation list is a residue, not a default.

## User Stories / Use Cases

- As a developer closing a ticket with `/tce:implement`, I want the agent to run
  the commands it is asking me about, so that I only spend attention on things a
  machine genuinely cannot check.
- As a developer running `/tce:quickfix` autonomously, I want the gate to
  discharge what it can before it stops, so that "fully autonomous" does not mean
  "autonomous until the last step".
- As a developer receiving a genuine escalation, I want the exact command with
  real paths and the pass criterion, so that I do not have to re-derive what the
  agent already knew.

## Acceptance Criteria

- [ ] `implement.md`'s "cannot verify from diff" bullet states that the checker
      has no shell by design and that command-shaped criteria land there by
      construction, and instructs the agent to run the command and record the
      real output as evidence — reclassifying to manual only when the criterion
      is genuinely runtime-only and unreachable.
- [ ] `implement.md`'s "needs human verification" bullet requires an attempt on
      **every** item before **any** item is escalated, naming the concrete
      avenues: existing automated coverage; build and run the artifact; add a
      test when the behaviour is testable and the change is ours; construct the
      conditions (temp dir, scratch git repo, env override, fixture config file,
      local stub server) the way the project's own tests do.
- [ ] Each discharged item is reported with its evidence (command + output, or
      the test that pins it), and its plan checkbox handling is unambiguous —
      including whether an agent-discharged MANUAL item may be ticked without
      user confirmation, or still waits (this currently conflicts with
      Implementation Log Rules rule 2).
- [ ] The escalate-only-if list is stated: credentials or live services the agent
      cannot obtain, third-party systems, subjective or visual judgment, and
      decisions that are the user's to make.
- [ ] Every escalated item carries a copy-pasteable command with real paths
      (explicitly not placeholders), what output means pass vs. fail, and one
      line on why it could not be done in-session.
- [ ] `work.md`'s inline gate re-description carries the same substance, per the
      composite-tracking rule.
- [ ] `quickfix.md`'s gate-outcome section reflects the new shape
      (attempted-and-discharged vs. escalated) rather than implying every MANUAL
      item reaches the user.
- [ ] `claude plugin validate .` and the three per-plugin validates pass.
- [ ] `CLAUDE.md`'s TP-0020 section (the "gate spans four files" rule) is updated
      if the same-commit span changes.

## Out of Scope

- **Giving `plan-compliance-checker` a shell.** Its read-only, context-isolated
  design is the point of TP-0020; the fix belongs in the *consuming* command, not
  the agent.
- Changing the agent's four-verdict vocabulary (`met` / `not met` / `cannot
  verify from diff` / `needs human verification`) or its output table format.
- `implement_eco.md` — verified as an 18-line `model: sonnet` wrapper that
  invokes the `tce:implement` skill; it inherits the fix with no edit.
- tle's `loop-verifier` and any tle verification flow.
- Broadening the gate into a code/quality review.

## Open Questions

None blocking.

## Questions for Research/Planning

- [ ] **Should `/tce:plan` stop labelling command-shaped checks "Manual
      Verification"?** The Automated/Manual taxonomy lives in
      `references/plan-document-template.md`, not in `plan.md` (which only points
      at it). Cutting the mislabelling at the source is attractive, but it
      changes a template that in-flight plans were written against, and
      `implement.md` step 1 marks MANUAL items from that same split. Leaning: fix
      `implement.md` first (it must be robust to a mislabelled plan anyway, since
      plans predate the code) and treat the template change as a smaller
      follow-up — to be decided in planning.
- [ ] Does `review.md` need anything? It carries no MANUAL or compliance
      references; research should confirm whether it re-derives criteria checks
      anywhere, or whether it is genuinely out of scope.
- [ ] Where does the shared "try before you escalate" wording belong — inlined in
      `implement.md` + `work.md` (duplication, matching the AskUserQuestion-block
      precedent), or a `references/` file read at point of use (matching the
      TP-0013 reference-file precedent)?
- [ ] Does the discharge instruction risk conflicting with Implementation Log
      Rules rule 2 ("Manual Verification checkboxes are ticked only on explicit
      human confirmation")?

## References

- `plugins/tce/commands/implement.md` — the `## Plan-Compliance Gate` section;
  step 4 holds both defective bullets
- `plugins/tce/agents/plan-compliance-checker.md` — shell-less by design
  (`Read, Grep, Glob, LS`)
- `plugins/tce/commands/work.md` — Phase 4d, the inline gate re-description
- `plugins/tce/commands/quickfix.md` — Final Summary, the gate-outcome section
- `plugins/tce/references/plan-document-template.md` — the Automated/Manual
  verification split
- `CLAUDE.md` — "The plan-compliance gate must stay wired across implement and
  the composites (TP-0020)"
- The user's global `CLAUDE.md`, "Verifying work before handing checks to the
  user" — states this same principle at the user level; this ticket makes tce
  enforce it.

## Implementation Plan

## Notes & Updates

### 2026-09-08

- Created from a concrete failure on tideways/apm (GH-10848a), where 6 of 7
  escalated gate items proved dischargeable in-session.
- Complexity Medium: prompt-text change with a known root cause and a bounded
  blast radius (`implement.md` is the source, `work.md` mirrors it inline,
  `quickfix.md` surfaces the outcome), plus one design decision (the plan
  template's Manual label) deferred to planning.
- `implement_eco.md` scoped out after verifying it is a pure delegating wrapper
  with no gate content; `review.md` left as a research question rather than an
  assumption.
