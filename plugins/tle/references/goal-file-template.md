<!--
Runtime reference for the tle loop-engineering workflow. Read at the moment of
writing a goal file by /tle:define — always in full, even if already read
earlier in the session. Never copied into consuming projects.

Changes to this file are command-contract changes: the CLAUDE.md rules "tle's
engine model — one iteration per turn" and "The verdict vector is a machine
contract" apply. The `## /goal condition` string below is part of the loop
engine (it carries the restart directive), and the `item-NN` IDs are the stable
handles the verifier's verdict vector and /tle:run's stall check key on — so
changing either requires updating plugins/tle/commands/run.md,
plugins/tle/agents/loop-verifier.md and plugins/tle/README.md in the same
commit.

Contents:
1. The goal file skeleton (ops facts, budgets, checklist, /goal condition)
2. Authoring guidance (oracle hierarchy, browser scenarios, granularity,
   feasibility, Verify by must prove Done when, immutability)
-->

# Goal file skeleton

Write `thoughts/shared/loops/<goal-slug>/goal.md` with this structure. Fill in
every bracketed placeholder — never leave one in the written file.

````markdown
# Loop Goal: [Goal title]

**Slug:** [goal-slug]
**Created:** YYYY-MM-DD

## Ops facts

Facts the loop's agents need every iteration, so they never rediscover them.

- **Boot the app:** `[command]`
- **Run tests:** `[command]`
- **Base commit:** `[full sha]`
- **Test file locations:** `[paths or globs the verifier diff-reviews]`
- **Other:** [anything else agents must know — ports, seed data, env setup]

## Budgets

- **Max iterations:** [N]
- [Any further budget]

## Checklist

Item IDs are permanent and are the loop's stable handle on each item — never
renumber, reorder-by-renaming, or reuse an ID.

### item-01 — [short name]

**Done when:** [observable outcome, in user-visible terms]
**Verify by:** [command that exits 0 | user-level browser scenario]

### item-02 — [short name]

**Done when:** [...]
**Verify by:** [...]

## /goal condition

Paste this into Claude Code before starting the loop:

```
the tle verifier has reported every checklist item in [goal-slug] passing; if it
has not, run the next iteration with /tle:run thoughts/shared/loops/[goal-slug]/goal.md;
or stop after [N] iterations
```
````

# Authoring guidance

## The oracle hierarchy

Push each `Verify by` as far down this list as you honestly can:

1. **A command with a meaningful exit code** — a test, build, typecheck, or
   lint invocation that fails loudly when the item is not done. Always
   preferred: it is unambiguous, cheap, and cannot be talked into passing.
2. **A user-level browser scenario** — used only for what end-to-end
   interaction alone can prove (rendering, navigation, persistence across a
   reload, an interaction sequence).

If an item's outcome could be proven by a command but no such command exists
yet, prefer making the item's `Verify by` that command anyway and let the loop
write it — a test the loop must make pass is a better oracle than a scenario a
model must judge.

## Browser scenarios are user-level narratives

Write them as a user would describe them:

> open `/`, add an item, reload the page, the item is still listed

**Never** reference selectors, DOM ids, CSS classes, or component names. The UI
drifts across iterations; the goal file must not. A scenario pinned to a
selector turns a legitimate refactor into a false failure — and invites the loop
to preserve markup instead of behaviour.

## Granularity

One item, one outcome, one check. An item whose `Verify by` needs more than one
command or more than one scenario should be split into separate items. Small
items give the loop a fine-grained gradient to descend; coarse items stall it,
because nothing observable changes for many iterations.

## Feasibility

Every item must be something an autonomous agent with code, tests, and a browser
could actually make true. The recurring infeasibility classes are:

1. **Determinism demanded of a nondeterministic system** — byte-identical output
   from an LLM, a result that depends on timing.
2. **Outcomes that depend on the world outside the repo** — a third party
   shipping something, a human deciding something.
3. **Unbounded claims** — "no bugs", "handles any input".

An infeasible item is not merely dead weight: `/goal` has an `Impossible`
verdict that clears the goal and ends the run, so one impossible expectation
can kill the whole loop. Such an expectation is excluded from the loop and
verified by hand afterwards — never written into the checklist.

## `Verify by` must prove `Done when`

For every item, imagine its `Done when` is false and ask whether this
`Verify by`, run exactly as stated, would fail. If a passing `Verify by` is
compatible with an unmet `Done when`, it is a proxy and not a proof — fix the
check or split the item until each check actually proves its outcome.

## Immutability

Once a loop starts, the goal file never changes — not its items, not their IDs,
not the ops facts. A changed goal means a fresh `/tle:define` with a new slug
and a new `thoughts/shared/loops/<goal-slug>/` directory, and a new loop.

This is why the checklist carries **no pass-state field**: live pass state is
the verdict vector in the latest `NNN-verify.md`, re-established from scratch
every iteration by the verifier running every item.
