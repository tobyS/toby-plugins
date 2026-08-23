# TP-0027: `/tle:define`'s hand-off presents an unnecessary manual `/tle:run`

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-08-23
**Updated:** 2026-08-23

## Problem Statement

`/tle:define` closes by telling the user to do two things: paste the `/goal`
condition, *then* run `/tle:run <goal-file>`. The second step is not needed.
Pasting the condition alone starts the loop — the condition string names
`/tle:run`, the evaluator returns "not met", and the turn that opens invokes the
runner. That is the restart directive working exactly as designed (CLAUDE.md,
"tle's engine model — one iteration per turn"); the engine is correct and only
the instructions describe it wrongly.

Observed in the first real run of the hardened `/tle:define` (TP-0026, goal slug
`v1-ingest-source-views`): the command recommended running `/tle:run` manually,
but the loop had already started on its own.

The cost is small but real: a user who follows the instruction literally may
kick off a second, redundant iteration, and the wording misrepresents the
mechanism the whole plugin turns on — the condition string, not the human, is
what drives the loop.

## Desired Outcome

The hand-off says that pasting the `/goal` condition starts the loop by itself,
and keeps the explicit `/tle:run <goal-file>` invocation only as a fallback for
when it does not. The two places that describe this flow agree with each other
and with the engine's actual behaviour.

## User Stories / Use Cases

- As a loop user, I want the hand-off to tell me what actually happens after I
  paste the condition, so I don't start a redundant iteration by following the
  instructions.

## Acceptance Criteria

- [ ] `plugins/tle/commands/define.md`'s Step 10 ("Hand off", currently
      `:203-205`) no longer presents `/tle:run` as a required second step; it
      states that the paste starts the loop and gives `/tle:run` as a fallback.
- [ ] `plugins/tle/README.md`'s "The loop" section (currently `:84-93`, "Three
      inputs get you from …") is reconciled with the same behaviour — its
      example block currently lists `/tle:run` as a third required input.
- [ ] The two descriptions agree with each other and with CLAUDE.md's "tle's
      engine model" section.
- [ ] Step 10's closing rule ("Do not start the loop, do not run `/tle:run`, and
      do not offer to") is preserved — the command still must not start the loop
      itself.
- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tle` pass.

## Out of Scope

- Any change to `/tle:run`, the loop agents, the condition-string template, or
  the engine model — the mechanism is correct; only its description is wrong.
- The goal-quality machinery from TP-0026.
- Version bump / release of the tle plugin (human-gated).

## Open Questions

- [ ] Is the automatic start guaranteed, or can it depend on session state (e.g.
      whether the paste's turn ends with no background work)? The fallback
      wording should be accurate about *when* the manual run is actually needed,
      which is why this is worth one round of confirmation rather than a blind
      rewording.

## Questions for Research/Planning

- [ ] Does the CLAUDE.md rule "When you change the iteration steps in `run.md`,
      update the condition-string template and the README flow in the same
      commit" reach this change? `run.md` is untouched, but the README flow is
      one of the two files being corrected — confirm which sync rules fire.
- [ ] Are there other places (README "What you get", the plugin description)
      that restate the two-step hand-off and would drift?

## References

- `thoughts/shared/tickets/TP-0026-tle-define-goal-quality.md` — the finding is
  recorded in its Notes & Updates (2026-08-23), with the verbatim hand-off output
- `plugins/tle/commands/define.md:197-207` — Step 10, the hand-off
- `plugins/tle/README.md:84-104` — "The loop", the three-input example and the
  paragraph explaining why the `/goal` paste is manual
- `CLAUDE.md` — "tle's engine model — one iteration per turn", which documents
  the restart directive that makes the manual run redundant

## Notes & Updates

### 2026-08-23

Split out of TP-0026 rather than folded into it: TP-0026 is about goal
*quality*, and it only renumbered Step 10 without touching its wording. The
defect predates it.
