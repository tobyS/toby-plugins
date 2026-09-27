# TP-0038: tsf — script-side pick and a `claude -p` runner so waiting costs no model tokens

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-27
**Updated:** 2026-09-27

Learnings from the first successful tsf run (chat-sustainability GH-40, factory
session `8867f1a0`, 2026-09-26). The correctness findings of that run are
TP-0039; this ticket is the cost finding, which was the dominant surprise.

## Problem Statement

The continuous mode of tsf is `/loop /tsf:cycle` in one interactive session.
DESIGN.md §11.3 states the dispatcher's context "grows by one result block per
cycle"; the first real run measured ~18k tokens per cycle instead — every cycle
re-reads the config and the reference files in full, and under `/loop` all of
it accumulates in one conversation. Over 12 cycles the context grew from 26k to
240k tokens with no compaction; the dispatcher consumed 52.1M cache-read tokens
across 317 turns against ~9.8M for all ten subagents combined (84% of the run's
token traffic, on Opus), and the 240k-token context after a single
two-increment ticket would compact mid-ticket or exhaust a smaller window on a
real backlog.

Most of those cycles did no work: they read a scan record showing
`ci: pending`, or a parked ticket with no reply, and went back to sleep. The
decision in those cycles is mechanical on scan fields, yet it costs a full
replay of the accumulated conversation each time.

Two secondary observations belong to the same mechanism:

- Under `/loop` the dispatcher never printed the closing `## tsf cycle` report
  (0 of 12 cycles — the `/loop` skill's own "summarize for the user"
  instruction wins), so the report contract that names the suggested wait went
  unexercised.
- Step 3's actionability and skip rules exist only as prose in `cycle.md` and
  `cycle-dispatch.md`, so a runner cannot apply them without a second copy.

## Desired Outcome

Waiting costs no model tokens. A shell runner loops over `preflight → scan →
pick`; when nothing is actionable it sleeps the suggested wait and re-scans
without launching a model; when something is, it runs one fresh
`claude -p "/tsf:cycle"` session for exactly one cycle. The actionability and
skip rules of Step 3 live in one shipped script that both the runner and the
dispatcher consume, so there is one implementation of "what is actionable and
why not". The dispatcher's per-cycle context becomes the cycle's own reads
only, and the closing report is the runner's actual interface. DESIGN.md's
continuous-mode description and the §11.3 cost claim are corrected to what was
measured.

## User Stories / Use Cases

- As the factory operator, I want a ticket parked for my reply or waiting on CI
  to cost nothing while it waits, so that leaving the factory running overnight
  is affordable.
- As the factory operator, I want each cycle to start from a fresh context, so
  that a long backlog cannot degrade into mid-ticket compaction or a
  context-limit failure.
- As a plugin maintainer, I want the skip rules in one script, so that changing
  a rule (e.g. a new parked state) cannot silently diverge between the
  dispatcher and the runner.
- As an operator reading the runner's log, I want each cycle's closing report
  printed, so that I can see what was picked, what was skipped and why without
  opening a session.

## Acceptance Criteria

- [ ] A shipped script (`scan.sh --pick` or a new `pick.sh`) consumes the scan's
      records and prints a machine-readable result: the picked ticket (or none),
      every skipped ticket with a reason from the closed skip vocabulary of
      Step 3, and the suggested wait per the table in `cycle-report.md`. Its
      header block documents the record, like `scan.sh`'s.
- [ ] `/tsf:cycle` Step 3 calls that script and acts on its output; it no longer
      re-derives actionability from the scan records in prose, and its Skipped
      report line is filled from the script's output.
- [ ] A shipped runner script loops `preflight → scan → pick`; on `pick: none`
      it sleeps the suggested wait and repeats without launching Claude;
      otherwise it runs one `claude -p "/tsf:cycle"` (with
      `--dangerously-skip-permissions`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`
      and the bash timeout, since the factory is only ever run inside a
      sandbox) and prints that cycle's output. A preflight or scan failure stops
      the runner with the detail line instead of retrying blindly.
- [ ] Running the runner against a scratch repository with one `tsf:queued`
      issue drives the ticket through the same state sequence the GH-40 run
      took, and every idle poll during the plan-approval and CI waits shows no
      `claude` invocation in the runner's log.
- [ ] Every `/tsf:cycle` run under the runner ends with the `## tsf cycle —`
      report as its last output; the report is what the runner reads, so its
      shape stays a documented contract.
- [ ] README and `/tsf:init`'s clone checklist describe the runner as the
      continuous mode; `/loop /tsf:cycle` is documented as the fallback with its
      cost characteristic stated. DESIGN.md §8 promotes the `claude -p` runner
      from "Future" to the delivered mode and §11.3 states the measured
      per-cycle growth instead of "one result block".
- [ ] `claude plugin validate ./plugins/tsf` passes; the pick script is covered
      by the fake-`gh` test approach (scan records → pick output) for at least:
      idle, one actionable ticket, CI-pending skip, needs-answer-without-reply
      skip, and two landings.

## Out of Scope

- Parallel factories (several runners on one repository) — the next step after
  this ticket, recorded in `plugins/tsf/TODO.md`. The pick script must not
  pretend to solve it: a pick observed by a runner and acted on by a session
  started afterwards is a window in which another runner can pick the same
  ticket.
- Reducing the reference-file re-reads inside a single cycle (they are the
  compaction-safety mechanism and are cheap once the session is fresh).
- Event-driven wake-ups (webhooks) instead of polling.
- Any change to the agents, the state-machine rows, or the GitHub writes.
- The GH-40 corrections (invalid-return robustness, gate line citations, marker
  rewrite at landing, quoting the scan pattern, skipping local verify after
  green CI, permission-mode documentation) — TP-0039.

## Open Questions

None — the design was agreed in the run analysis on 2026-09-27.

## Questions for Research/Planning

- [ ] `scan.sh --pick` versus a separate `pick.sh`: which keeps the scan-record
      contract (CLAUDE.md "the scan record is a machine contract") cleanest,
      given the runner must call both anyway?
- [ ] Which Step 3 rules need data the scan record does not carry today (e.g.
      the landing pick keys on `review_at`; does anything key on the journal)?
      Any such rule either gets a scan field or stays in the dispatcher —
      enumerate before writing the script.
- [ ] How the runner reads the suggested wait: from the pick script's output
      (preferred, no model involved) or by parsing the cycle report — and
      whether the report keeps its Suggested wait line at all once the runner
      no longer needs it.
- [ ] Exact `claude -p` invocation for a plugin skill in a project directory:
      flags needed for plugins to load, output mode (plain text vs
      `stream-json`), how a non-zero exit or an unfinished cycle (usage limit)
      surfaces to the runner, and whether the subscription-allowance claim in
      DESIGN.md §8 still holds.
- [ ] Where the runner script ships and how `/tsf:init` points at it (plugin
      `scripts/` referenced by absolute plugin-root path, or copied into
      `.claude/tsf/scripts/` like the contract skeletons).

## References

- Run analysis of session `8867f1a0` (factory clone of chat-sustainability,
  2026-09-26): 12 cycles, context 26k → 240k tokens, dispatcher 52.1M
  cache-read tokens vs 9.8M for all subagents.
- `plugins/tsf/DESIGN.md` §8 (runner modes; "Future: `claude -p` while-loop"),
  §11.3 (dispatcher context claim), §16.
- `plugins/tsf/commands/cycle.md` Step 3; `plugins/tsf/references/cycle-report.md`
  "The suggested wait" table.
- `plugins/tsf/TODO.md` "Document and check the factory session's permission
  mode" and "Parallel factories".

## Implementation Plan

## Notes & Updates

### 2026-09-27

- Origin: the first successful tsf run. The token cost was the dominant
  surprise; correctness was fine and its findings went to TP-0039.
- Decision: the runner must not launch a model to learn that nothing is
  actionable — that is why the pick rules move into a script rather than the
  runner simply parsing the report.
- Decision: the factory runs only with `--dangerously-skip-permissions` inside
  a sandbox; the runner passes it unconditionally and the docs say so.
- Parallel factories are the next step after this ticket and are deliberately
  out of scope here; the pick-then-act window they introduce is recorded in
  `TODO.md` so the pick script's design keeps it in view.
