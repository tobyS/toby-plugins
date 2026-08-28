# tle — Toby Loop Engineering

An experiment in **goal engineering / loop engineering** for greenfield
projects. You define what "done" means as a checklist a machine can check, pin
it with Claude Code's built-in `/goal`, and then the loop runs: a fresh-context **verifier** proves each item
against the system as it actually is, a **spec+plan** agent derives the single
next small step, an **implementer** lands it and commits it green. One iteration
per turn, until every item passes or a budget stops it.

Every handoff goes through files under `thoughts/shared/loops/<goal-slug>/`, so
the orchestrating context only ever holds paths and one-line statuses — never a
report body, a diff, or test output. That is what lets the loop run long without
drowning in its own history, and it leaves a complete audit trail behind.

> **Built by Toby.** These plugins come out of my daily practice helping
> engineering teams turn experimental AI use into structured, sustainable
> workflows. Need a sparring partner for the hard technical and AI-adoption calls?
> Find me at [rent-the-toby.com](https://rent-the-toby.com).

## What you get

- **Guided goal definition** (`/tle:define`) — a discussion that turns "build me
  a todo app" into a checklist where every item has an observable outcome and a
  concrete way to prove it, plus the ops facts (boot command, test command, base
  commit) the loop's agents need every iteration, a max-iterations budget, and a
  ready-to-paste `/goal` condition. It argues with you on the way: the goal must
  be achievable, well-defined and loop-sized, the checklist is swept for what it
  omits, and every item is challenged on whether an agent could reach it and
  whether its check really proves it — each behind a gate the discussion cannot
  pass until it is settled. A fresh-context critic then reviews the assembled
  draft before it is written, and a goal that is knowably incomplete is not
  written at all.
- **A one-iteration runner** (`/tle:run`) — verify → surface the verdict → stall
  check → spec the next step → implement and commit → log. Then it ends the
  turn, which is what lets `/goal` decide whether another one starts.
- **Four agents with hard boundaries** — the verifier is denied the plan, the
  log, previous reports, and every claim the implementer made, so it grades the
  system rather than the intent; the planner may only specify one small step;
  the implementer may only land that step and may never touch a test to make it
  pass. The fourth, the goal critic (`loop-goal-critic`), runs at definition
  time rather than in the loop: it is denied the discussion that produced the draft goal, so gaps in the
  goal surface while a human can still fix them.
- **An audit trail** — `goal.md`, one `NNN-verify.md` and `NNN-plan.md` per
  iteration, and a one-row-per-iteration `loop-log.md`, all in the repo.

## Requirements

| Tool | Needed for | Required? |
| ---- | ---------- | --------- |
| `git` | everything (the implementer commits each green increment; the verifier diffs test files against the base commit) | **Required** |
| `/goal` | driving the loop from turn to turn — a Claude Code built-in, unavailable when hooks are disabled | **Required** |
| [`chrome-devtools-mcp`](https://github.com/ChromeDevTools/chrome-devtools-mcp) | browser verification of user-level scenarios | **Recommended** — configure it in your project; without it, browser items report `cannot-verify` rather than a guessed pass |
| [`tce`](../tce/README.md) | optional enrichment: every tle agent reads `.claude/tce/profile.md` if present | No |

`chrome-devtools-mcp` is a **documented dependency, not a shipped one** — tle
does not install or configure it, and does not name it in any agent's tool list.
The agents inherit whatever MCP tools your project has; when the browser tools
are absent, browser-scenario items degrade to `cannot-verify`.

## Install

```bash
# Add the marketplace (once per machine), then install the plugin:
/plugin marketplace add tobyS/toby-plugins
/plugin install tle@toby-plugins
```

## Set up a project

There is nothing to initialize — tle writes no per-project config. What it does
need is a project that can already boot and run its tests: do the groundwork
first (dev environment, a boot command, a test command, an empty passing test
suite), then define the goal. The loop makes increments; it does not bootstrap.

## Commands

| Command       | Purpose                                                       |
| ------------- | ------------------------------------------------------------- |
| `/tle:define` | Agree a machine-checkable goal; write `goal.md` and the `/goal` condition |
| `/tle:run`    | Run one loop iteration against a goal file                    |

## The loop

Three inputs get you from "goal discussed" to "goal verifiably reached":

```bash
/tle:define a todo app whose items survive a page reload
# → thoughts/shared/loops/todo-app-mvp/goal.md, and a condition string

/goal the tle verifier has reported every checklist item in todo-app-mvp passing; if it has not, run the next iteration with /tle:run thoughts/shared/loops/todo-app-mvp/goal.md; or stop after 20 iterations

/tle:run thoughts/shared/loops/todo-app-mvp/goal.md
```

The `/goal` paste is manual because `/goal` is a Claude Code built-in that
cannot be invoked on your behalf. It is also the engine, not a safety net:
`/goal` evaluates **at the end of each turn**, so `/tle:run` performs exactly
one iteration and stops. The evaluator reads the verdict the runner surfaced,
returns "not yet met", and Claude starts another turn — which re-invokes
`/tle:run`, because the condition names the command and the goal file.

That design buys three things an internal loop cannot have: every iteration is
supervised by an independent model, Claude Code's own stall guard stays live,
and the "or stop after N iterations" clause is actually enforceable.

The loop ends when the verifier reports every item passing, when the
max-iterations budget is reached, or when the runner's stall escalation gives up
(two consecutive iterations with an identical verdict vector escalate: retry
with a different item or a smaller slice, then a different strategy, then stop).

## Which model runs what

A loop runs unattended, so nobody is there to switch models mid-run. **The
agents that do the repeated work therefore carry their own model pins instead
of inheriting yours**, and the split follows where the tokens actually go:

| Agent | Model | Why |
| ----- | ----- | --- |
| `loop-implementer` | `sonnet` | The largest consumer — it reads source, edits, runs tests and retries. Its plan file is written to be sufficient on its own, the step is one small slice, a green test run gates the commit, and the verifier re-checks the result independently |
| `loop-verifier` | `sonnet` | The highest repeat count: every checklist item, every iteration. Judgment is designed out — each item carries an explicit `Verify by`, a `pass` needs evidence, a method that cannot run reports `cannot-verify`, and when in doubt it fails |
| `loop-spec-planner` | `opus` | The smallest footprint and the loop's only genuine decision: which failing item to attack next, how small a slice to cut, and what to try differently when the loop stalls |

Everything you invoke yourself stays on **your** model. `/tle:define` writes the
one artifact the loop can never revise, and the goal critic reviews it — both
run on whatever you picked, in a session you are watching, where being wrong is
most expensive. `/tle:run` is unpinned for the same reason, and it costs little
either way: its own context is paths and one-line statuses, never a report body.

The verifier on `sonnet` is the deliberate risk here. It is the one component
nothing downstream re-checks, and a false `pass` ends a loop on an unfinished
goal. Two things in a run are the signal to raise it: a `pass` whose evidence is
not a command with an exit code or the steps of an observed scenario, and a test
that was weakened since the base commit without the verifier's integrity diff
catching it.

To override the split, set `CLAUDE_CODE_SUBAGENT_MODEL` — it outranks every
agent's own setting. It is all-or-nothing across the session, though: it moves
the planner and the goal critic along with the verifier and the implementer, so
it buys you a uniformly more expensive or a uniformly cheaper loop, not a
different division of labour.

## Where the thinking sits — an honest framing

tle experiments with goal engineering, and honesty about the current state of
that experiment matters: **the loop does not get full goal freedom.**
`/tle:define` is where the research happens, where the design decisions are
made, and where the goal is decomposed into checklist items — all
interactively, with a human in the gate. By the time the loop starts, the goal
file reads less like an open objective and more like a ticket whose acceptance
criteria have been promoted to executable oracles: the planner mostly schedules
the next item, and the implementer lands it.

What the loop genuinely adds is not search but measurement: a fresh-context
verifier re-proves every item, every iteration, against the system as it
actually is — review replaced by measurement, with no trust in the
implementer's own account of what it did. That trade-off is deliberate: design
freedom is spent at define time, where being wrong is cheap, and it buys
implementation you neither babysit nor take on faith. Outcome-level goals that
leave real design freedom to the loop are the open end of the experiment, not
the current claim.

## Greenfield-first

This technique suits **new** codebases: a small web app, a prototype, a tool you
are building from a blank page. There the checklist can genuinely cover the goal
and each iteration's blast radius is small.

It is not a general "make Claude finish anything" mechanism, and it is
deliberately not the shape of tce's ticket → research → plan → implement chain,
which exists precisely because established codebases need human gates. On a
large existing codebase a convergence loop will happily satisfy its checklist
while damaging things the checklist never mentioned. Use tce there.

## Recommended permissions

Plugin agents cannot set their own permission mode, so the implementer's Bash,
Edit, Write, and commit calls are checked against **your** permission rules and
will prompt unless you allow them. A loop that stops for a prompt on every
commit is not autonomous — and the plugin cannot grant this for you.

Adapt this into the project's `.claude/settings.local.json` before starting a
long run, substituting your project's own commands:

```json
{
  "permissions": {
    "allow": [
      "Edit",
      "Write",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git diff:*)",
      "Bash(git rev-parse:*)",
      "Bash(<your test command>:*)",
      "Bash(<your boot/build command>:*)"
    ]
  }
}
```

Grant only what the loop needs, and keep it in the project's local settings
rather than your user settings — this is a deliberately wide grant, scoped to a
project you are willing to let a loop rewrite.

## What the loop writes

```
thoughts/shared/loops/<goal-slug>/
├── goal.md          # the checklist, ops facts, budgets, /goal condition
├── 001-verify.md    # per-item verdicts + evidence, one per iteration
├── 001-plan.md      # the one step that iteration specified
├── 002-verify.md
├── 002-plan.md
└── loop-log.md      # one terse row per iteration
```

Commit the directory: it is the audit trail for everything the loop did, and
`loop-log.md` plus the commit history is how you reconstruct a run you were not
watching.

**Goal files are immutable once a loop starts.** `/tle:define` never edits an
existing one — a changed goal means a fresh `/tle:define` with a new slug, a new
directory, and a new loop. That is also why the checklist carries no pass-state
field: live pass state is the verdict vector in the latest `NNN-verify.md`,
re-established from scratch every iteration by the verifier re-running every
item.

## Update

```bash
/plugin marketplace update toby-plugins
```

## Contributing

Want to work on the plugin itself? See the repository's
[CONTRIBUTING.md](../../CONTRIBUTING.md) for the layout, how to validate changes, and
the release flow.
