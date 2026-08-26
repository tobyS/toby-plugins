# TP-0028: Harden tle's prompts and template from the first two real loop runs

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-08-26
**Updated:** 2026-08-26

## Problem Statement

The first two real tle loops (`v1-ingest-source-views`, 19 iterations to 17/17,
and `v1-merged-transaction-list`, 19 iterations to 20/20, both in
`/Users/toby/code/private/to-fi/thoughts/shared/loops/`) validated the engine —
vector-based stall detection, fresh-context verification, the file-only handoff
and a two-day pause all worked — but surfaced five gaps where the prompts or the
template are silent and the loop had to improvise or burned an iteration. All
five are straightforward markdown fixes to existing tle files; no engine or
mechanism change.

1. **Planner over-constraint made a plan unsatisfiable** (loop 1, iteration
   002). The plan's own Notes said "Do not touch any existing test file", but
   two base-commit tests hard-coded the empty schema the step's migration
   necessarily invalidated. The implementer correctly refused to improvise and
   a full iteration was spent re-planning. `loop-spec-planner.md` forbids
   weakening tests but never states the converse: updating an existing test's
   expectations to track the behaviour the step legitimately changes is allowed
   — and should be named in the plan (the 003 re-plan did exactly that, and the
   verifier's own standard already accepts it as "legitimately extended").

2. **The runner has no instruction to count the verdict from the vector.**
   Loop 1, iteration 016: the verifier's Gap prose and return line said 13/17
   while the vector correctly held 14 passes. The runner caught it ad hoc
   ("verifier summary miscounted as 13" in the log), but `run.md` Step 6 says
   to restate "the verifier's one-line result" — and that surfaced sentence is
   what the `/goal` evaluator reads. The X/Y must be derived by counting the
   parsed verdict-vector, never trusted from the agent's return line or prose.

3. **Stall-rung episodes are not defined.** Loop 1 hit rung 1 at iteration 003
   and again at 009; the runner correctly improvised "STALL rung 1 (new
   episode)", but `run.md` Step 8 only says to determine the rung from the log
   notes — a naive reading of two rung-1 notes gives rung 2 and a spurious
   rung-3 stop one stall later. The rule to codify: rungs count consecutive
   stalled iterations since the last vector change; any movement resets the
   episode.

4. **The "nothing plannable" endgame is uncovered.** Loop 1, iterations
   018–019: the only remaining item was `cannot-verify` on user-owned
   infrastructure (dev stack down). There are verify reports but no plan files
   for those iterations — the runner improvised a verify-only wait. `run.md`
   has no branch for "no `fail` remains, only non-loop-fixable
   `cannot-verify`": nothing should be dispatched, the user must be told
   exactly what is unreachable, and the turn must still end in the normal way
   (the still-unmet `/goal` condition then drives verify-only turns — which is
   also why point 5 matters).

5. **The template never says that `Verify by` runs on every iteration and must
   therefore be cheap and idempotent.** Loop 1's item-12 check
   (`pnpm check:import` against a fresh throwaway DB) genuinely re-ran both
   paid `claude -p` extractions on every verify pass from iteration 017 on.
   Loop 2's goal fixed this by hand ("the wipe-and-import happens once … the
   check asserts the *state* the rebuild left behind", plus a one-paid-
   extraction budget) — but that insight lives only in that goal file, not in
   `goal-file-template.md`'s authoring guidance or the goal-critic's checks.
   Related and worth one line in the same guidance: when one item's check
   establishes state a later item's check reads, order the items accordingly
   and say so in the ops facts (the verifier runs in goal-file order — loop 2
   needed exactly this for rebuild → match → browser).

## Desired Outcome

The five behaviours the loops had to improvise (or pay for) are stated in the
tle markdown they belong to, so the next loop gets them by instruction instead
of by luck: the planner may name legitimate expectation updates, the runner
counts from the vector, stall rungs reset on movement, the
nothing-plannable endgame has a defined branch, and goal authoring warns
against expensive re-verification and undocumented check ordering.

## User Stories / Use Cases

- As a loop user, I don't want an iteration burned because the planner
  blanket-forbade touching tests its own step invalidates.
- As a loop user, I want the surfaced X/Y verdict — the thing `/goal` judges —
  to be computed from the machine contract, not hand-counted prose.
- As a loop user, I want a long loop to survive two separate stalls without a
  spurious rung-3 stop, and to tell me plainly when everything left is blocked
  on infrastructure only I can fix.
- As a goal author, I want `/tle:define` to stop me before I write a check that
  re-runs a paid extraction on every iteration.

## Acceptance Criteria

- [ ] `plugins/tle/agents/loop-spec-planner.md`: the Test integrity section (or
      an adjacent paragraph) states that adjusting an existing test's
      expectations to track behaviour the step legitimately changes is not
      weakening, and that the plan must name the affected test(s) and the new
      expected values; the existing weakening prohibition is untouched.
- [ ] `plugins/tle/commands/run.md` Step 6: the surfaced X/Y is explicitly
      derived by counting the parsed `<!-- verdict-vector -->` block, never
      taken from the verifier's return line or report prose.
- [ ] `plugins/tle/commands/run.md` Step 8: defines a stall episode — rungs
      count consecutive stalled iterations since the last vector change, and
      any vector movement resets to rung 0; the log-row note remains how the
      rung is persisted.
- [ ] `plugins/tle/commands/run.md`: a defined branch for "no `fail` in the
      vector and every remaining non-pass is a `cannot-verify` the loop cannot
      fix" — dispatch no planner or implementer, report what is unreachable
      and whose it is, append the log row, and end the turn normally.
- [ ] `plugins/tle/references/goal-file-template.md` authoring guidance: states
      that every `Verify by` runs on every iteration, so a check must be cheap
      and idempotent — an expensive or paid one-time action gets a
      state-asserting check, never a re-performing one; and that ordered,
      stateful checks are handled by item order plus an ops fact naming the
      dependency.
- [ ] `plugins/tle/agents/loop-goal-critic.md` (define-time critic) checks
      goal drafts for the two authoring hazards above, in whatever form its
      existing check list uses.
- [ ] The CLAUDE.md sync rules are honoured: any `run.md` iteration-step change
      is reflected in `goal-file-template.md` and `plugins/tle/README.md` in
      the same commit where the described mechanism changes.
- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tle`
      pass.

## Out of Scope

- Any change to the engine model (one iteration per turn), the verdict-vector
  format, its markers, or the item-ID scheme.
- The slicing-vs-stall tension (a planned intermediate slice reads as a stall
  and costs a rung-1 escalation) — observed but self-correcting and cheap;
  accepted behaviour for now.
- Green-but-uncommittable handling in `loop-implementer.md` (the 1Password
  signing outages) — likely an artifact of the miswired cage, not the plugin;
  the improvised stage-plus-`.claude-commit` pattern worked. Revisit only if it
  recurs in a correct cage.
- Sanctioning the improvised `NNNb` out-of-band log rows.
- Adding a `## Test integrity` section to `loop-verifier.md`'s output format
  spec (the mandate to run the diff already exists; cosmetic).
- Version bump / release of the tle plugin (human-gated).

## Open Questions

- [ ] For the endgame branch: should the runner suggest the user clear the
      `/goal` (to stop verify-only spinning) or rely on the budget clause and
      `/goal`'s own stall guard? The two real loops never actually spun, so
      this is untested either way.

## Questions for Research/Planning

- [ ] Does the endgame branch count as an iteration against the max-iterations
      budget (a verify report is still written and numbered)? Loop 1's 018/019
      were numbered normally — probably keep that.
- [ ] Where exactly in `run.md`'s step sequence does the endgame branch belong —
      inside Step 8's rung logic or as its own step between 7 and 8?

## References

- `/Users/toby/code/private/to-fi/thoughts/shared/loops/v1-ingest-source-views/`
  — loop 1: `loop-log.md` (stall episodes 003/009, miscount note at 016,
  endgame 018–019), `002-plan.md` (the unsatisfiable Notes constraint),
  `016-verify.md` (vector 14 pass vs "Thirteen of seventeen" prose)
- `/Users/toby/code/private/to-fi/thoughts/shared/loops/v1-merged-transaction-list/`
  — loop 2: `goal.md` (the hand-written once-not-per-iteration and
  verification-order ops facts this ticket promotes into the template),
  `loop-log.md` (count-invariant vector change at 011, stall at 017)
- `plugins/tle/commands/run.md` — Steps 6, 8, and the missing endgame branch
- `plugins/tle/agents/loop-spec-planner.md` — Test integrity section
- `plugins/tle/references/goal-file-template.md` — authoring guidance
- CLAUDE.md — "tle's engine model", "The verdict vector is a machine contract"
  (the sync rules the fixes must respect)
- `thoughts/shared/tickets/TP-0026-tle-define-goal-quality.md` — the prior
  define-time hardening this extends
