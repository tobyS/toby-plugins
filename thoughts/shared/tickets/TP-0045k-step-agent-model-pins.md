# TP-0045k: model pins for the step agents

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-10-30
**Updated:** 2026-10-30

Sub-ticket of TP-0045 (the epic), moved out of TP-0045d. Not part of the epic's
done check, which names a to d.

## Problem Statement

All five step agents are `model: inherit`, so a run costs whatever model the
session happens to be on. The decision to leave them open waited for cost data
from a real run, and GH-37 gave it: 88.3M tokens, of which implementers 32.0M
(36%), the verifier with the gate 23.1M (26%), the orchestrator 13.8M (16%) and
research with its sub-agents 9.1M (10%). Everything except the locators ran on
Opus. Pins for the implementer, verifier and research sub-agents are the largest
cost lever.

That is one ticket's data, and a wrong pin fails silently.

## Desired Outcome

A pin policy for the step agents and research sub-agents, following TP-0029:
aliases only, no `model:` on any step command, each pin deliberate. Every pin is
proven on a real dispatch, because `claude plugin validate` does not read agent
`model:` values and an unrecognized one falls back to the inherited model.
`CLAUDE.md`'s "All five agents" bullet states the result.

## Out of Scope

- A `model:` on any step command (TP-0024).
- tle's and tsf's pins.

## References

- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` — the
  "Cost" section
- `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md` —
  "Items H to L"
- `CLAUDE.md` — the "All five agents are `model: inherit`" bullet, and "tle's
  model pins are policy" for the runbook that proves a pin
- `thoughts/shared/tickets/TP-0029-tle-agent-model-pins.md` — the pin precedent
