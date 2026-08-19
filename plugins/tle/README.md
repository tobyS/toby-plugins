# tle — Toby Loop Engineering

An autonomous convergence loop for greenfield projects. You define what "done"
means as a checklist a machine can check, pin it with Claude Code's built-in
`/goal`, and then the loop runs: a fresh-context **verifier** proves each item
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
  ready-to-paste `/goal` condition.
- **A one-iteration runner** (`/tle:run`) — verify → surface the verdict → stall
  check → spec the next step → implement and commit → log. Then it ends the
  turn, which is what lets `/goal` decide whether another one starts.
- **Three agents with hard boundaries** — the verifier is denied the plan, the
  log, previous reports, and every claim the implementer made, so it grades the
  system rather than the intent; the planner may only specify one small step;
  the implementer may only land that step and may never touch a test to make it
  pass.
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
