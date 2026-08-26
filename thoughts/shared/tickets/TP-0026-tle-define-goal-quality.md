# TP-0026: /tle:define — improve the quality of the goals it produces

**Status:** Done
**Estimated Complexity:** Medium
**Created:** 2026-08-23
**Updated:** 2026-08-26

## Problem Statement

The first real run of the tle plugin (TP-0025) validated the architecture: the
loop engine, the file-only handoffs, and `/goal` driving one iteration per turn
all worked. What did not hold up was the **goal file `/tle:define` produced**.

Three shortcomings were observed:

1. **Missing criteria** — the checklist did not cover everything that "done"
   actually required.
2. **Not sceptical enough** — the command accepted what it was given rather than
   pushing back to enforce goal-definition best practice.
3. **Incomplete for actually running the loop** — the goal file did not capture
   everything the loop's agents needed to get going.

This matters more than an ordinary prompt-quality issue because of tle's
architecture: **the goal file is the loop's only oracle**. It is immutable once
a loop starts, the verifier judges solely against it, and the spec+planner picks
its steps from its failing items. A gap in the goal is a gap the loop cannot
notice, cannot recover from, and will happily converge around — declaring
victory on an unfinished job. Everything downstream is only as good as this one
document, and it is authored in the one place a human is still in the loop.

## Desired Outcome

`/tle:define` reliably produces goal files that are **complete enough to run a
loop to a genuinely finished result**: the checklist covers what the user
actually means by done, each item is verifiable by the stated method, and the
ops facts contain everything the agents need without rediscovery or guessing.
The command should behave like a demanding editor — surfacing gaps, challenging
vague or unverifiable items, and refusing to write a goal file it can tell is
incomplete.

## User Stories / Use Cases

- As a loop user, I want `/tle:define` to catch what I forgot to put in the
  goal, so the loop does not converge on a checklist that misses the point.
- As a loop user, I want to be told when an item cannot really be verified the
  way I described, before the loop starts and the goal becomes immutable.
- As a loop user, I want the goal file to carry every ops fact the agents need,
  so the first iterations are not spent rediscovering how to boot or test the
  project.

## Acceptance Criteria

- [x] `/tle:define` gains an explicit completeness pass that actively hunts for
      missing checklist items rather than accepting the user's first
      decomposition.
- [x] The command challenges items whose stated verification method will not
      actually prove them, and does not let an unverifiable item into the file.
- [x] The ops facts collected are sufficient to start a loop without an agent
      having to rediscover or guess a project fact.
- [x] A goal file the command can tell is incomplete is not written; the gap is
      surfaced to the user instead.
- [x] The changes stay within the TP-0025 architecture: goal files remain
      immutable once a loop starts, item IDs stay stable, and no pass-state
      field is reintroduced.
- [x] Any change to the goal-file structure keeps the CLAUDE.md sync rules
      satisfied ("tle's engine model", "The verdict vector is a machine
      contract").

## Out of Scope

- Changes to `/tle:run`, the three loop agents, or the engine model — TP-0025's
  first run confirmed those work.
- Mid-run goal revision. Goal files stay immutable once a loop starts; this
  ticket improves the goal *before* the loop begins.
- The three tle failure modes left unverified by TP-0025 (absent
  chrome-devtools-mcp, weakened tests, stall escalation) — separate concerns.

## Open Questions

- [ ] What exactly was missing from the first run's goal file? The concrete gaps
      are the most valuable input here and are only recoverable from the user's
      run.
- [ ] Should the completeness pass be a checklist the command works through, a
      dedicated sceptical review step, or a subagent that critiques the draft
      goal from a fresh context?

## Questions for Research/Planning

- [ ] Where do comparable "interrogate the user until the spec is sound"
      patterns already exist in this repo (e.g. `/tce:ticket`'s guided
      authoring, `/tce:research`'s ticket-sufficiency check), and what is
      reusable?
- [ ] Does the fix belong in `define.md`'s discussion steps, in
      `goal-file-template.md`'s authoring guidance, or both — and how does that
      interact with the point-of-use reference read?
- [ ] Is a fresh-context critic agent (mirroring `plan-compliance-checker`'s
      isolation) the right shape for judging a draft goal's completeness?
- [ ] What is the minimum ops-fact set that makes a loop startable, and can it
      be derived rather than asked for?

## References

- `thoughts/shared/tickets/TP-0025-tle-loop-engineering-plugin.md` — the plugin
  this improves; its closing note records the first run's findings
- `plugins/tle/commands/define.md` — the command to improve (its 9 discussion
  steps, and the "Important Rules" that already forbid subjective items)
- `plugins/tle/references/goal-file-template.md` — the skeleton and its
  authoring guidance (oracle hierarchy, granularity, immutability)
- `plugins/tle/agents/loop-verifier.md` — the consumer whose verdicts are only
  as meaningful as the goal's items
- `CLAUDE.md` — "tle's engine model", "The verdict vector is a machine contract"

## Implementation Plan

`thoughts/shared/plans/2026-08-23-TP-0026-tle-define-goal-quality.md` — three
phases: (1) in-command scepticism in `define.md` (goal-level challenge,
omission sweep + goal-anchored completeness check, per-item feasibility/
verification-validity/wording pass, three hard gates, refuse-to-write rule) +
matching template authoring guidance; (2) a fresh-context `loop-goal-critic`
agent reviewing the assembled draft before writing, findings adjudicated with
the user; (3) README/CLAUDE.md sync + manifest validation. Ops facts stay
conversationally confirmed (user decision); the goal-file machine contract is
untouched.

## Notes & Updates

### 2026-08-23

Created from the first real tle run. The user's assessment: installation, goal
creation and convergence all worked and the overall architecture held; the goal
`/tle:define` produced was the weak point — it "missed some criteria", "was not
skeptical enough to create a sensible goal to ensure best practices are met",
and "did not include everything that was needed to actually get the goal
running". Deliberately split from TP-0025 rather than reopening it.

### 2026-08-23 — finding from the first run of the hardened `/tle:define`

User ran the improved command against a real project (goal slug
`v1-ingest-source-views`). Two observations:

**The scepticism works.** The goal discussion "went way more detailed (good!)"
and "created a nice goal". This is real-run evidence for the Phase 1 + 2
machinery — the gates, the omission sweep and the per-item challenge produce a
materially better goal than the accepting-scribe version did.

**The hand-off recommends a step that is not needed.** Step 10 tells the user to
do two things — paste the `/goal` condition, *then* run `/tle:run <goal-file>`.
In the real run the second step was unnecessary: pasting the condition alone
started the loop, because the condition string names `/tle:run` and the
evaluator's "not met" verdict opens a turn that invokes it. The user's verbatim
hand-off output:

```
Paste this to /goal

the tle verifier has reported every checklist item in v1-ingest-source-views passing; if it
has not, run the next iteration with /tle:run thoughts/shared/loops/v1-ingest-source-views/goal.md;
or stop after 50 iterations

Then run:

/tle:run thoughts/shared/loops/v1-ingest-source-views/goal.md
```

This is a **defect in the hand-off wording, not in the engine** — the automatic
start is the condition string's restart directive working exactly as designed
(CLAUDE.md, "tle's engine model"). Two places present the manual run as a
required step and would need to agree on the correction:

- `plugins/tle/commands/define.md:203-205` — "The exact next two steps".
- `plugins/tle/README.md:84-93` — "Three inputs get you from …", whose example
  block lists `/tle:run` as a third input.

Both should say that pasting the condition starts the loop by itself, keeping
the explicit `/tle:run` invocation only as a fallback for when it does not.
Out of TP-0026's scope (goal *quality*, not the hand-off) — recorded here
because it surfaced while verifying this ticket; needs its own ticket.

### 2026-08-26 — closed

Implemented in three phases and closed with all six acceptance criteria met and
all six of the plan's manual criteria user-confirmed.

What shipped: `define.md` now challenges the goal itself (achievable /
well-defined / loop-sized), sweeps five omission categories, asks whether
passing every item would genuinely achieve the goal, and tests each item for
feasibility, whether its `Verify by` can prove its `Done when`, and vague
wording — each closed by a hard "do not proceed until" gate. A new
`loop-goal-critic` agent reviews the assembled draft from a fresh context
before it is written, its findings adjudicated with the user; blocking findings
gate the write, and a knowably incomplete goal is not written at all. The
goal-file machine contract (skeleton, `item-NN` scheme, condition string,
immutability, no pass-state field) was left untouched.

Validated on a real run (goal slug `v1-ingest-source-views`): the discussion
went "way more detailed" and produced a good goal; resolving critic findings
together with the user works.

Commits: `77f9a1f`, `811e35f`, `87fa897`, `cf1f7e0`, `b7c9b62`, `02ea451`.
Follow-up: TP-0027 (hand-off overstates the manual `/tle:run`). Still
human-gated: the tle version bump / release.
