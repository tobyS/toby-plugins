# tle Plugin — Loop-Engineering Workflow Implementation Plan

## Overview

Add **tle** (Toby Loop Engineering) as a third plugin in the `toby-plugins`
marketplace: an interactive goal-authoring command (`/tle:define`), a
single-iteration convergence-loop runner (`/tle:run`) driven by Claude Code's
built-in `/goal`, and three subagents (verifier, spec+planner, implementer) that
hand off exclusively through files under `thoughts/shared/loops/<goal-slug>/`.

## Current State Analysis

The repo is a monorepo marketplace with two plugins (`tce`, `tmt`). There is no
`tle` artifact and nothing loop-related anywhere in the tree — this is
greenfield. Adding a plugin is purely additive: everything a plugin consists of
(commands, agents, hooks, scripts, references, templates) is auto-discovered
from conventional directory names, and **no manifest lists them**. Only two
things must change outside `plugins/tle/`: the `plugins` array in
`.claude-plugin/marketplace.json:10-23`, and the documentation surfaces that
hardcode "two plugins".

Three findings from the research constrain the design:

1. **`/goal` evaluates once per turn, at Stop.** A runner that iterates N times
   inside one turn receives zero evaluations until that turn ends. `/goal`
   cannot supervise, bound, or interrupt an internal loop.
2. **An active goal is not observable** by any script, hook, env var,
   status-line field, CLI flag, or `stream-json` event.
3. **Plugin subagents may not declare `mcpServers`** (silently ignored), and a
   `tools:` allowlist has a documented history of stripping inherited MCP tools
   and of refusing to launch when no entry resolves.

All seven existing tce agents are read-only *by tool omission*. tle inverts
this: its verifier must execute commands and drive a browser, and its
implementer must edit and commit.

## Desired End State

`plugins/tle/` exists and validates; a user can take a prepared greenfield
web-app project from "goal discussed" to "goal verifiably reached" with three
inputs: `/tle:define`, one `/goal <condition>` paste, `/tle:run <goal-file>`.
Each `/tle:run` invocation performs exactly one iteration and ends its turn;
`/goal`'s evaluator then decides whether another turn starts.

Verify by: `claude plugin validate .` and `claude plugin validate ./plugins/tle`
pass; a scratch-project end-to-end run produces a `thoughts/shared/loops/<slug>/`
directory containing `goal.md`, numbered `NNN-verify.md` / `NNN-plan.md` files,
and a `loop-log.md` with one row per iteration.

### Key Discoveries

- `/goal` docs: "Each time Claude finishes a turn, Claude Code sends the
  condition and the conversation so far to your configured small fast model" —
  and the evaluator "does not call tools, so it can only judge what Claude has
  already surfaced in the conversation."
- "**If a subagent or a background shell command is still running when a turn
  ends, Claude Code skips the evaluation for that turn.**" → all agent dispatch
  must be foreground.
- Setting a goal "starts a turn immediately, **with the condition itself as the
  directive**", and each "not yet met" reason is fed back as guidance. The
  condition (up to 4,000 chars) is therefore the durable per-turn loop driver,
  not merely an exit test.
- Compaction: re-attached skills keep only the **first 5,000 tokens** each,
  within a **25,000-token shared budget**, oldest dropped first;
  "**Truncation keeps the start of the file**."
- `allowed-tools` / `model` grants are **turn-scoped** ("the grant clears when
  you send your next message"). One iteration per turn means the skill is
  re-invoked each turn, so the grant is re-established each iteration — the
  turn-scoping problem that would have bitten an internally-looping runner does
  not arise.
- Tool resolution matrix: neither `tools` nor `disallowedTools` set → inherits
  every subagent-available tool **including MCP tools**; `disallowedTools` only
  → every parent tool except those listed; both → `disallowedTools` wins.
- Plugin agents cannot set `permissionMode`; "Claude Code checks the subagent's
  own tool calls against your permission rules as it runs." A plugin cannot
  pre-approve its implementer's Bash/Edit/commit calls.
- Subagents can never use `AskUserQuestion` (universally filtered) — all user
  interaction must live in `/tle:define`.
- Plugin agents are **lowest precedence** of five scopes; a same-named project
  or user agent shadows them → use distinctive names.
- `plugins/tce/agents/plan-compliance-checker.md:14-26` (read boundary),
  `:37-47` (verdict vocabulary + tie-break), `:57-71` ("Emit only this"),
  `:28-35`/`:81-90`/`:92-99` (the three-part envelope) — the isolation pattern
  the verifier mirrors.
- `plugins/tce/commands/quickfix.md:146`,`:170` — the `MANDATORY OUTPUT`
  assertion pattern, directly reusable for a loop whose every iteration must
  produce artifacts.
- `plugins/tce/commands/design_explore.md:158`,`:296` — the only existing
  directory-of-artifacts precedent; `thoughts/shared/loops/<goal-slug>/` follows
  the same shape minus the date prefix.
- `plugins/tce/agents/codebase-analyzer.md:10-12` — the `## Project context`
  profile-read paragraph with explicit missing-file fallback, which every tle
  agent mirrors.

## Resolved Design Decisions

These were open in the research and are settled here; the reasoning is recorded
because it is not recoverable from the code.

### 1. Engine model — one iteration per turn, `/goal` drives

`/tle:run` performs **one** iteration and ends its turn. `/goal`'s evaluator
sees the surfaced verdict, returns "not yet met", and Claude starts another
turn. This buys per-iteration supervision by an independent fresh model, makes
the built-in stall guard live, and makes the budget clause in the condition
enforceable — all forfeited by an internal loop.

The mechanism that makes it work: **the condition string `/tle:define` generates
carries the restart directive**, not just the completion test:

```
the tle verifier has reported every checklist item in <goal-slug> passing; if it
has not, run the next iteration with /tle:run thoughts/shared/loops/<goal-slug>/goal.md;
or stop after <N> iterations
```

This self-heals: if compaction drops the runner's skill body, the condition
still names the command and the goal file, so the next turn re-invokes it.

Consequences, both load-bearing:

- **`/tle:run` reads all its state from disk on every invocation** (iteration
  number, previous verify report, loop log). Across turn boundaries there is no
  reliable memory.
- **The runner keeps its own stall check.** `/goal`'s built-in guard fires only
  on *no tool use* for several consecutive turns; a loop that keeps busily
  working while producing identical verdicts sails past it.

This contradicts the ticket's AC wording ("then loops: baseline check →
dispatch verifier → …"); Phase 6 reconciles it.

### 2. `commands/` not `skills/`

The docs recommend `skills/<name>/SKILL.md` for new plugins, but this repo uses
`commands/*.md` in both existing plugins and documents that layout in
`CLAUDE.md`, `CONTRIBUTING.md`, and `README.md`. Both produce `/tle:<name>`.
Diverging for one plugin buys nothing and adds a governance surface (plus
`/reload-plugins` reports `0 skills` for a `skills/`-based plugin).

### 3. Stall check compares the verdict vector, not the file

A whole-file comparison of consecutive verify reports would essentially never
fire — reports carry prose, evidence lines, and timestamps that differ even when
nothing was achieved. That is the "asserted rather than checked invariant"
failure mode the independent review already flagged in tce
(`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:82-90`).

Instead each `NNN-verify.md` carries a stable machine-comparable block that the
runner extracts and compares against the previous iteration's. This imposes two
contracts worth having anyway: goal.md checklist items need **stable IDs**, and
the verifier must emit the block verbatim.

### 4. One reference file; every other skeleton inline at its point of use

| Artifact | Skeleton lives in | Why |
|---|---|---|
| `goal.md` | `plugins/tle/references/goal-file-template.md` | Large stable fill-in skeleton inside a long interactive command — TP-0016's class exactly |
| `NNN-verify.md` | Inline in `loop-verifier.md` | Agents get fresh context per dispatch: inline costs nothing, zero compaction risk. Matches precedent — `${CLAUDE_PLUGIN_ROOT}` appears in no agent file |
| `NNN-plan.md` | Inline in `loop-spec-planner.md` | Same |
| `loop-log.md` row + stall rule | Inline in `run.md`, near the top | The runner is short (one pass), comfortably under the 5,000-token truncation point |

Payoff: the runner never re-reads a reference file mid-iteration, so the loop
turn stays tiny.

### 5. Agent tool declaration — `disallowedTools` only, never `tools`

Omitting `tools` is the only configuration that inherits chrome-devtools-mcp by
documented contract *and* cannot hit the zero-tools launch refusal when the
server is absent.

### 6. Live pass state lives in the verify report, not in goal.md

The ticket's AC asks for goal.md to carry "per-item pass state", but the ticket
also makes goal files **immutable once a loop starts**. Those collide: a
pass-state field that is never updated is dead machinery. goal.md therefore
declares items, stable IDs, and verification methods; the **verdict vector in
the latest `NNN-verify.md` is the single source of live pass state**. The
oscillation guard the design wanted from pass state ("done items stay done and
are re-verified, not re-decided") is served instead by the verifier re-running
*every* item each iteration and emitting a complete vector. Phase 6 reconciles
the AC.

## What We're NOT Doing

- A Stop-hook-based loop engine (the ralph-wiggum pattern) — remains the
  documented fallback if same-session accumulation bites; separate ticket.
- `/loop` compatibility work beyond leaving `/tle:run` unflagged.
- An initializer agent or project scaffolding — groundwork is manual.
- Mid-run goal revision. `/tle:define` never edits an existing goal file.
- Non-web-app verification profiles beyond commands + browser scenarios.
- Any tce/tmt integration beyond the optional `profile.md` read. No
  `${CLAUDE_PLUGIN_ROOT}` reference from tle into tce or tmt.
- Shipping or configuring chrome-devtools-mcp — documented dependency only.
- Any `.claude/tle/` per-project config. tle takes its facts from the goal file,
  optionally enriched by tce's profile.
- Bumping tce's or tmt's versions. tle ships at 1.0.0; tagging is a separate,
  human-initiated release step.

## Implementation Approach

Build bottom-up so each phase is independently validatable: manifest first
(Phase 1), then the artifact-producing side (`/tle:define` + its template,
Phase 2), then the workers that consume and produce loop artifacts (Phase 3),
then the runner that orchestrates them (Phase 4), then docs and the repo's
governance rules (Phase 5), then reconcile the ticket contract (Phase 6).

Phases 2–4 are markdown prompts with no runtime, so their automated
verification is limited to `claude plugin validate` plus structural greps; real
confidence comes from the Phase 5 manual end-to-end run in a scratch project.

**Note for `/tce:implement`'s plan-compliance gate:** Phase 6 deliberately
rewrites two of TP-0025's acceptance criteria (the engine model and goal.md's
pass state). The **reconciled** criteria are the ones the gate should be run
against; the pre-reconciliation wording is known to contradict this plan.

---

## Phase 1: Plugin Skeleton + Marketplace Wiring

### Overview

Create the plugin manifest and register it in the marketplace, so
`claude plugin validate` covers everything added in later phases.

### Changes Required

#### 1. Plugin manifest

**File**: `plugins/tle/.claude-plugin/plugin.json` (new)
**Changes**: Follow `plugins/tmt/.claude-plugin/plugin.json:1-15` — the simpler
of the two existing manifests. No `userConfig` (tle has no install-time,
user-scoped state), no `mcpServers`, no `homepage`/`repository`/`license`.

```json
{
  "name": "tle",
  "version": "1.0.0",
  "description": "Toby Loop Engineering — an autonomous convergence loop for greenfield projects. Define a machine-checkable goal (/tle:define), pin it with the built-in /goal, then iterate (/tle:run): a fresh-context verifier proves each checklist item, a spec+plan agent derives one small step, an implementer commits the green increment. All handoffs go through files under thoughts/shared/loops/.",
  "author": {
    "name": "Tobias Schlitt",
    "email": "tobias@schlitt.info"
  },
  "keywords": [
    "loop",
    "autonomous",
    "verification",
    "goal",
    "workflow"
  ]
}
```

#### 2. Marketplace entry

**File**: `.claude-plugin/marketplace.json`
**Changes**: Append a third object to the `plugins` array (currently
`:10-23`), using exactly the four fields already in use — `name`, `source`,
`description`, `version`.

```json
    {
      "name": "tle",
      "source": "./plugins/tle",
      "description": "Toby Loop Engineering: an autonomous convergence loop — define a machine-checkable goal, then iterate verify → spec → implement until every checklist item verifiably passes. Greenfield-first; file-only handoffs under thoughts/shared/loops/.",
      "version": "1.0.0"
    }
```

Also update the marketplace `metadata.description` at `:4`, which currently
says "starting with the tce context-engineering workflow".

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate .` passes
- [x] `claude plugin validate ./plugins/tle` passes
- [x] `claude plugin validate ./plugins/tce` and `./plugins/tmt` still pass
- [x] `jq -e '.plugins | length == 3' .claude-plugin/marketplace.json` succeeds
- [x] `jq -e '.version == "1.0.0"' plugins/tle/.claude-plugin/plugin.json` succeeds, and matches the marketplace entry's `version`

#### Manual Verification

- [ ] If `claude plugin validate ./plugins/tle` rejects a manifest-only plugin
      (no `commands/` yet), fold this phase's validation into Phase 2 rather
      than inventing a placeholder command — note it in the implementation log

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `85d4413` (HEAD before any implementation commit)
- **Commit**: `2ef4201` feat(TP-0025): add the tle plugin manifest and marketplace entry
- **Did**: New `plugins/tle/.claude-plugin/plugin.json` (1.0.0, tmt-shaped: no
  userConfig/mcpServers); third entry + refreshed `metadata.description` in
  `.claude-plugin/marketplace.json`; ticket → In Progress.
- **Issues**: none — `claude plugin validate ./plugins/tle` accepts a
  manifest-only plugin, so the conditional fold into Phase 2 is not needed.
- **Verification**: ✅ validate (marketplace + all 3 plugins), ✅ jq assertions
  (3 plugins, version 1.0.0 in both manifests)

---

## Phase 2: `/tle:define` + the Goal-File Reference Template

### Overview

The interactive goal-authoring command and the stable skeleton it fills in.
This phase defines the two contracts every later phase depends on: **stable
checklist item IDs** and **the `/goal` condition string**.

### Changes Required

#### 1. The goal-file reference template

**File**: `plugins/tle/references/goal-file-template.md` (new)
**Changes**: Open with the HTML-comment header every reference file carries
(see `plugins/tce/references/research-document-template.md:1-22`): when it is
read, by whom, that it is never copied into consuming projects, which
governance rule applies to edits, and a numbered Contents list. Then the
skeleton:

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

Include, as unfenced guidance below the skeleton:

- **The oracle hierarchy** — push each `Verify by` as far down as honestly
  possible: a command with a meaningful exit code (test, build, typecheck) is
  always preferred; a browser scenario is used only for what end-to-end
  interaction alone can prove.
- **Browser scenarios are written as user-level narratives** ("open `/`, add an
  item, reload the page, the item is still listed") — **never selectors, DOM
  ids, or CSS classes**. The UI drifts across iterations; the goal file must
  not.
- **Granularity** — an item whose `Verify by` needs more than one command or
  more than one scenario should be split.
- **Immutability** — once a loop starts, the goal file never changes. A changed
  goal means a fresh `/tle:define` with a new slug.

#### 2. The `/tle:define` command

**File**: `plugins/tle/commands/define.md` (new)
**Changes**: Follow the command skeleton in order — frontmatter → Title Case
heading → "You are tasked with…" role paragraph → `## Project context` →
`### AskUserQuestion dialog guidelines` → `---` → `## Workflow Context` table →
body.

Frontmatter:

```yaml
---
description: Define a machine-checkable loop goal through guided discussion, and write it to thoughts/shared/loops/<goal-slug>/goal.md with a ready-to-paste /goal condition.
argument-hint: "[goal description]"
disable-model-invocation: true
---
```

The flag is correct per TP-0017's inbound-edge rule: nothing delegates into
`/tle:define` (the ticket explicitly forbids `/tle:run` editing goal files).

`## Project context` must:
- name the plugin and assert project-agnosticism;
- instruct reading `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` **if it
  exists**, as optional enrichment for the ops facts (test/build commands), with
  an explicit fallback of asking the user — tle must work with tce absent;
- define `<goal-slug>` as a placeholder, never a literal.

`### AskUserQuestion dialog guidelines` — copy **byte-identically** from
`plugins/tce/commands/research.md`. This is the tenth copy; Phase 5 updates the
`CLAUDE.md` rule that currently says "nine".

Body requirements:

- **Argument handling**: a skip-the-greeting branch when a goal description is
  passed, plus a no-argument fallback that prints a fenced message and waits.
  Its absence is a real defect
  (`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:50-57`).
- **Immutability guard, before any writing**: if
  `thoughts/shared/loops/<goal-slug>/` already exists, **stop** and ask for a
  different slug. Never edit or overwrite an existing goal file.
- **Discussion phases**: converge on the goal → decompose into granular
  checklist items → push each item's verification down the oracle hierarchy →
  collect ops facts → agree budgets → assign stable sequential IDs.
- **Point-of-use template read**, immediately before writing the file, carrying
  the recurring clause: read `${CLAUDE_PLUGIN_ROOT}/references/goal-file-template.md`
  now — in full, even if you read it earlier in this session.
- **Final output**: the goal file path plus the `/goal` condition string
  rendered in a fenced block for copy-paste, and the exact next two steps
  (paste the condition, then run `/tle:run <goal-file>`).

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate ./plugins/tle` passes
- [x] `plugins/tle/commands/define.md` carries `disable-model-invocation: true`
- [x] The `### AskUserQuestion dialog guidelines` block in `define.md` is
      byte-identical to the one in `plugins/tce/commands/research.md` (extract
      heading-through-last-bullet from both and `diff`; must be empty)
- [x] `define.md` contains the literal string
      `${CLAUDE_PLUGIN_ROOT}/references/goal-file-template.md`
- [x] No stack literals: grepping `define.md` and the reference file for
      `npm |bun |php artisan|pytest|vitest|jest` returns nothing outside
      clearly-marked placeholder examples

#### Manual Verification

- [ ] Running `/tle:define` in a scratch project produces a `goal.md` with
      stable `item-NN` IDs, ops facts, a max-iterations budget, and a condition
      string naming both the slug and the goal file path
- [ ] Re-running `/tle:define` against an existing slug refuses and asks for a
      new one rather than editing
- [ ] Every `Verify by` is either a command or a selector-free user-level
      scenario

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `e773f7c` feat(TP-0025): add /tle:define and the goal-file template
- **Did**: New `plugins/tle/references/goal-file-template.md` (skeleton + oracle
  hierarchy / scenario / granularity / immutability guidance) and
  `plugins/tle/commands/define.md` (9 steps: converge → survey → decompose →
  oracle → ops facts → budgets → IDs → write → hand off).
- **Issues**: none.
- **Verification**: ✅ validate ./plugins/tle, ✅ AskUserQuestion block
  byte-identical across all ten files, ✅ flag + point-of-use template read
  present, ✅ no stack literals

---

## Phase 3: The Three Agents

### Overview

The workers. All three read their inputs from disk and return exactly one line
to the caller — that return budget is what keeps the loop's main context tiny.

### Changes Required

Shared conventions for all three files (`plugins/tle/agents/`):

- **Frontmatter**: `name`, `description`, `model`, `disallowedTools`. **Never
  `tools`** (decision 5). Never `mcpServers`, `hooks`, or `permissionMode` —
  silently ignored for plugin agents.
- **Distinctive names** (`loop-verifier`, `loop-spec-planner`,
  `loop-implementer`) — plugin agents are lowest precedence and are shadowed by
  same-named project or user agents.
- **`## Project context`** paragraph mirroring
  `plugins/tce/agents/codebase-analyzer.md:10-12`: read
  `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` if present, as optional
  enrichment only, with an explicit fallback to the goal file's ops facts.
- **The three-part envelope** re-pointed per agent: `## CRITICAL: YOUR ONLY JOB
  IS …` with all-caps `DO NOT` bullets closing on a single `ONLY` bullet →
  `## What NOT to Do` with sentence-case `Don't` bullets → `## REMEMBER: You are
  an X, not a Y` plus a metaphor paragraph.
- **Explicit output budget**: return exactly one line to the caller; everything
  else goes in the file the agent writes.

#### 1. The verifier

**File**: `plugins/tle/agents/loop-verifier.md` (new)
**Changes**:

```yaml
---
name: loop-verifier
description: Fresh-context verifier for a tle convergence loop. Executes each goal checklist item's stated verification method, diff-reviews test files, and writes per-item verdicts to NNN-verify.md. Returns one line.
model: inherit
disallowedTools: AskUserQuestion, Edit, NotebookEdit, Task
---
```

`Write` is deliberately **not** disallowed — the verifier must write its own
report, and routing the report through the caller would put its contents in the
loop's context, breaking the file-only-handoff rule. The constraint is stated
informationally instead: **the only file you may create or modify is the
`NNN-verify.md` you were given.** MCP is left inherited so
chrome-devtools-mcp reaches the agent when the project has it.

Prompt requirements:

- **`## What you receive`**: the goal file path, the output path for
  `NNN-verify.md`, the base commit, and the iteration number. Nothing else.
- **Read boundary** (the tle analogue of
  `plan-compliance-checker.md:14-26`, stated in three registers): you MAY read
  the goal file and any project source needed to run a verification method. You
  may **NOT** read `NNN-plan.md`, `loop-log.md`, previous verify reports, or any
  implementer output. *Judging the state of the system without the reasoning
  that produced it is the entire point of this check.*
- **Every item, every iteration.** Never skip an item because it passed
  previously — this is what replaces a mutable pass-state field and is the
  oscillation guard.
- **Test-integrity review**: run `git diff <base-commit> -- <test paths from ops
  facts>`. Tests weakened, skipped, or deleted to make an item pass are a
  `fail` for that item with the reason named, never a `pass`.
- **Optional-dependency handling**: if an item's method is a browser scenario
  and no `mcp__chrome-devtools__*` tool is available, emit `cannot-verify` with
  "browser verification unavailable". **Never** substitute a weaker check and
  never guess the outcome.
- **Verdicts**, three: `pass` (with evidence — command + exit code, or the
  scenario steps observed), `fail` (with the observed gap), `cannot-verify`
  (with why). **Tie-break: when in doubt between `pass` and `fail`, use
  `fail`.** This inverts `plan-compliance-checker.md:79` deliberately — for a
  one-shot gate the conservative error is "cannot verify", but for a loop the
  conservative error is to keep working rather than declare premature victory.
- **Inline output format**, prefixed "Emit only this", for `NNN-verify.md`. The
  verdict vector is the machine-readable contract the runner's stall check
  parses and must be emitted verbatim, first, one item per line, in goal-file
  order:

  ````markdown
  # Verify report — iteration NNN

  <!-- verdict-vector -->
  item-01: pass
  item-02: fail
  item-03: cannot-verify
  <!-- /verdict-vector -->

  ## Evidence

  ### item-01 — pass
  [command run, exit code, or scenario steps observed]

  ### item-02 — fail
  [what was observed instead]

  ## Gap

  [One short paragraph: what stands between the current state and the goal.]
  ````

- **Return line**: `iteration NNN: X/Y passing — <one-line gap> — <path to NNN-verify.md>`

#### 2. The spec+plan agent

**File**: `plugins/tle/agents/loop-spec-planner.md` (new)
**Changes**:

```yaml
---
name: loop-spec-planner
description: Reads a tle goal file and the latest verify report, then writes ONE small actionable implementation step to NNN-plan.md, including how the step will be verified. Returns one line.
model: inherit
disallowedTools: AskUserQuestion, Edit, NotebookEdit, Task, mcp__*
---
```

Prompt requirements:

- **`## What you receive`**: the goal file path, the latest verify report path,
  the output path for `NNN-plan.md`. Read both inputs **fully, from disk**.
- **One small step per iteration** — the single most-repeated principle in the
  prior art. Pick one failing item (or the smallest increment toward one). If
  the step cannot be implemented in one go, **cut it smaller**; that is the
  corrective, not an extra planning layer.
- **Never propose weakening, skipping, or deleting a test**, and never propose
  editing the goal file.
- **Inline `NNN-plan.md` format**: the target item ID, what to change and where
  (specific paths), and how the step will be verified once done.
- **Return line**: `<path to NNN-plan.md> — <one-line step summary>`

#### 3. The implementer

**File**: `plugins/tle/agents/loop-implementer.md` (new)
**Changes**:

```yaml
---
name: loop-implementer
description: Reads a tle step plan from disk, implements it, verifies it is green, and commits the increment. Returns one line.
model: inherit
disallowedTools: AskUserQuestion, Task
---
```

Prompt requirements:

- **`## What you receive`**: the plan file path and the goal file path. Read
  both fully from disk — the fresh context gets the full plan without the loop
  ever holding it.
- **Implement only what the plan specifies.** Do not opportunistically fix
  unrelated items; the loop will get to them.
- **Hard rule, stated as emphatically as in the verifier**: **tests may not be
  edited, weakened, skipped, or deleted to make them pass.** If a test is
  genuinely wrong, say so in the return line and leave it — do not "fix" it.
- **Commit the green increment**: run the test command from the goal file's ops
  facts; commit only when green. Git is the rollback for the
  woke-up-to-a-broken-codebase failure mode. Format the message per the
  project's `.claude/tce/profile.md` "Commit convention" section if that file
  exists, otherwise Conventional Commits.
- **Return line**: `<commit sha> — <what changed>`, or
  `no commit — <blocker>` when it could not land a green increment.

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate ./plugins/tle` passes
- [x] All three agent files exist under `plugins/tle/agents/` and each declares
      `name`, `description`, `model`, `disallowedTools`
- [x] No agent file contains a `tools:` key, an `mcpServers:` key, or the string
      `${CLAUDE_PLUGIN_ROOT}`
- [x] Each agent file contains all three envelope headings (`## CRITICAL:`,
      `## What NOT to Do`, `## REMEMBER:`)
- [x] Each agent file contains the literal
      `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`
- [x] `loop-verifier.md` contains the literal `<!-- verdict-vector -->`

#### Manual Verification

- [ ] Dispatched by hand in a scratch project, the verifier runs every checklist
      item and emits a complete verdict vector in goal-file order
- [ ] With chrome-devtools-mcp absent, a browser-scenario item yields
      `cannot-verify` rather than a fabricated `pass`
- [ ] With a test file deliberately weakened after the base commit, the verifier
      marks the corresponding item `fail` and names the weakening
- [ ] The implementer's return line is one line and carries a real commit sha

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `7ec5f00` feat(TP-0025): add the three tle loop agents
- **Did**: New `plugins/tle/agents/{loop-verifier,loop-spec-planner,loop-implementer}.md`
  — `disallowedTools`-only frontmatter (MCP inherited for the verifier, blocked
  for the planner), the three-part envelope re-pointed per agent, one-line
  return budgets, and the verifier's `<!-- verdict-vector -->` machine contract.
- **Issues**: none.
- **Verification**: ✅ validate ./plugins/tle, ✅ frontmatter keys (no `tools:`,
  no `mcpServers:`), ✅ no `${CLAUDE_PLUGIN_ROOT}` in any agent, ✅ 3 envelope
  headings each, ✅ profile-read literal each, ✅ verdict-vector marker

---

## Phase 4: `/tle:run`

### Overview

The runner. Performs exactly one iteration, surfaces the verdict, ends the turn.

### Changes Required

#### 1. The runner command

**File**: `plugins/tle/commands/run.md` (new)
**Changes**:

```yaml
---
description: Run one iteration of a tle convergence loop — verify, derive the next small step, implement and commit it — then end the turn so the /goal evaluator decides whether to continue.
argument-hint: "<goal-file>"
---
```

**No `disable-model-invocation`** — the flag is never written as `false`, it is
omitted. `/tle:run` must stay Skill-invocable so the `/goal`-driven next turn
can re-invoke it, and so it remains `/loop`-schedulable.

**Body ordering is load-bearing.** Compaction truncation keeps the start of the
file, so the loop invariants go at the very top, immediately after the role
paragraph and before `## Project context`:

1. **This command performs exactly ONE iteration. Never start a second
   iteration in the same turn.** Ending the turn is what lets `/goal`'s
   evaluator run.
2. **Never carry document contents, diffs, or test output in this context.**
   Only file paths and one-line statuses.
3. **Dispatch every agent in the foreground.** If a subagent is still running
   when the turn ends, Claude Code skips that turn's goal evaluation.
4. **Read all loop state from disk on every invocation.** Previous turns are not
   reliable memory.

Steps:

1. **Argument handling** — skip-the-greeting branch for a passed goal-file path,
   plus a no-argument fallback that prints a fenced message and waits.
2. **Re-read the goal file fully from disk**, unconditionally, even if it
   appears earlier in the conversation (TP-0013). Extract the ops facts,
   budgets, item IDs, and the max-iterations budget.
3. **Goal-condition check.** State plainly in the command that an active `/goal`
   is **not programmatically detectable** — no hook field, env var, status-line
   field, or CLI flag reports it. The check is prompt-level: if no goal
   directive is visible in the session context, print the condition string from
   the goal file's `## /goal condition` section and stop, telling the user to
   paste it and re-run. Do not attempt to parse `transcript_path`.
4. **Determine the iteration number**: glob
   `thoughts/shared/loops/<slug>/*-verify.md`, take the highest, add 1;
   zero-padded to three digits, starting at `001`.
5. **Baseline check**: run the boot/build command from the ops facts. Record the
   result for the log; a red baseline is a gap like any other and does not skip
   the iteration.
6. **Dispatch the loop-verifier agent** (foreground), passing the goal file
   path, the output path `thoughts/shared/loops/<slug>/NNN-verify.md`, the base
   commit, and the iteration number.
   **MANDATORY OUTPUT**: `NNN-verify.md` exists on disk. If it does not, stop
   and report — do not proceed to planning on a missing report.
7. **Surface the verdict into the transcript** as plain assistant text mirroring
   the condition's wording (e.g. "The tle verifier reported 4/7 checklist items
   in `<slug>` passing."). The `/goal` evaluator does not call tools and judges
   only what has been surfaced in the conversation, so this restatement is what
   it reads.
8. **Convergence check**: if every item is `pass`, announce convergence in plain
   text mirroring the condition, append the final `loop-log.md` row, and
   **stop**. Do not plan or implement.
9. **Stall check**: read the `<!-- verdict-vector -->` block from the new report
   and from `(NNN-1)-verify.md`. If they are identical, no item changed state —
   escalate one rung and record the rung in `loop-log.md`:
   1. re-dispatch the spec+planner with an explicit instruction that the
      previous step moved no item, and that it must choose a different item or
      a smaller increment;
   2. instruct a different strategy for the same item;
   3. stop the loop and report to the user.
   Determine the current rung by reading previous rung notes from
   `loop-log.md` — not from conversation memory.
10. **Dispatch the loop-spec-planner agent** (foreground) with the goal file
    path, the new verify report path, and the output path `NNN-plan.md`.
    **MANDATORY OUTPUT**: `NNN-plan.md` exists on disk.
11. **Dispatch the loop-implementer agent** (foreground) with the plan file path
    and the goal file path.
12. **Append one row to `loop-log.md`** (format inline in this command; write
    the table header when creating the file):

    ```markdown
    | NNN | YYYY-MM-DDTHH:MM:SSZ | X/Y pass | <commit sha or "none"> | <one-line gap or escalation note> |
    ```

    One row per iteration, terse — never prose journaling.
13. **Budget check**: if the iteration number has reached the goal file's
    max-iterations budget, say so plainly in the transcript and stop.
14. **End the turn.** Do not begin another iteration.

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate ./plugins/tle` passes
- [x] `plugins/tle/commands/run.md` does **not** contain the string
      `disable-model-invocation`
- [x] `run.md` contains the literal `<!-- verdict-vector -->` (the stall check
      parses it) and the literal `loop-log.md`
- [x] The four loop invariants appear before the `## Project context` heading
      (`## CRITICAL: THE FOUR LOOP INVARIANTS` at line 10, `## Project context`
      at line 19)
- [x] `run.md` body is comfortably under the 5,000-token re-injection cap
      (197 lines / ~1.9k words ≈ 2.8k tokens)

#### Manual Verification

- [ ] Invoked with no active goal, `/tle:run` prints the condition string and
      stops instead of iterating
- [ ] One invocation produces exactly one `NNN-verify.md`, one `NNN-plan.md`,
      one commit, and one `loop-log.md` row — and then ends the turn
- [ ] With a goal condition set, the turn end triggers a `/goal` evaluation and
      a "not yet met" verdict starts the next turn, which re-invokes `/tle:run`
- [ ] Two consecutive iterations with an identical verdict vector trigger the
      first escalation rung, and the rung is recorded in `loop-log.md`
- [ ] The runner's context after an iteration contains no report bodies, diffs,
      or test output — only paths and one-line statuses

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `91272d1` feat(TP-0025): add the /tle:run loop iteration runner
- **Did**: New `plugins/tle/commands/run.md` — unflagged, four loop invariants
  at the top, then 13 steps (goal re-read → prompt-level goal check →
  iteration number → baseline → verifier → surface verdict → convergence →
  stall/escalation from `loop-log.md` → planner → implementer → log row →
  budget → end turn), with `MANDATORY OUTPUT` assertions on both report files.
- **Issues**: none.
- **Verification**: ✅ validate ./plugins/tle, ✅ no `disable-model-invocation`,
  ✅ `verdict-vector` + `loop-log.md` markers present, ✅ invariants precede
  `## Project context`, ✅ 197 lines / ~2.8k tokens (under the 5k cap)

---

## Phase 5: Documentation + Repo Governance

### Overview

Consumer docs for tle, plus every surface in the repo that currently assumes
two plugins or nine AskUserQuestion copies.

### Changes Required

#### 1. The tle README

**File**: `plugins/tle/README.md` (new)
**Changes**: Follow tmt's shape (`plugins/tmt/README.md`, 136 lines — the closer
model than tce's 283-line long-form): title `# tle — Toby Loop Engineering` →
intro → the "Built by Toby" blockquote **copied byte-identically** from
`README.md:10-13` → `## What you get` → `## Requirements` → `## Install` →
`## Set up a project` → `## Commands` (flat `Command | Purpose` table, cf.
`plugins/tmt/README.md:80-87`) → tle-specific sections → `## Update` →
`## Contributing` linking `../../CONTRIBUTING.md`.

The `## Requirements` table is where the documented-not-shipped dependency goes
(tce's equivalent row is `plugins/tce/README.md:122`):

| Tool | Needed for | Required? |
|---|---|---|
| `chrome-devtools-mcp` | Browser verification of user-level scenarios | Recommended — without it, browser items report `cannot-verify` |
| `tce` | Optional enrichment: agents read `.claude/tce/profile.md` if present | No |

tle-specific sections:

- **`## The loop`** — the three-input user flow: `/tle:define` → paste
  `/goal <condition>` → `/tle:run <goal-file>`. Explain that `/goal` is a
  built-in and not model-invocable, which is why the paste is manual, and that
  each `/tle:run` is one iteration with `/goal` deciding whether another turn
  starts.
- **`## Greenfield-first`** — say plainly that the technique suits new
  codebases; do not promise general convergence.
- **`## Recommended permissions`** — plugin agents cannot set `permissionMode`,
  so the implementer's Bash/Edit/Write/commit calls are checked against the
  *user's* permission rules and **will prompt** unless allowlisted. An
  autonomous loop that prompts on every commit is not autonomous. Give a
  concrete `.claude/settings.local.json` `permissions.allow` snippet the user
  can adapt, and state that the plugin cannot grant this itself.
- **`## What the loop writes`** — the `thoughts/shared/loops/<goal-slug>/`
  layout (`goal.md`, `NNN-verify.md`, `NNN-plan.md`, `loop-log.md`) as the audit
  trail, and that goal files are immutable once a loop starts.

#### 2. Marketplace README

**File**: `README.md`
**Changes**: Add a third row to the plugin catalog table (`:17-20`). Update the
subtitle (`:3-4`) and the "Add the marketplace once, then install either
plugin… Both are built for…" paragraph (`:6-8`) — "either"/"both" no longer fit
three.

#### 3. CONTRIBUTING

**File**: `CONTRIBUTING.md`
**Changes**: "a monorepo containing two Claude Code plugins" → three (`:3-8`),
plus a third bullet; the README links at `:12`; a `tle/` branch in the layout
tree (`:29-48`); a third `claude plugin validate ./plugins/tle` line (`:76-78`).

#### 4. CLAUDE.md

**File**: `CLAUDE.md`
**Changes**:

- Intro (`:3-8`): "There are two plugins" → three, with a one-line
  characterization of tle and its dogfooding status (tle is **not** dogfooded by
  this repo — it targets greenfield app projects, not a markdown plugin
  monorepo; say so, so nobody wires it into this repo's workflow).
- Layout tree (`:17-42`): add the `plugins/tle/` branch.
- **AskUserQuestion rule** (`:321-322` area): "nine" → "ten", and add
  `plugins/tle/commands/define.md` to the enumerated file list. Same commit as
  Phase 2, per that rule's own wording.
- **TP-0017 invocation-control section**: add tle's classification —
  `define` is user-only and carries the flag; `run` is unflagged, and record
  **why** (it must be Skill-invocable so the `/goal`-driven next turn can
  re-invoke it, and it stays `/loop`-schedulable). Note that tle's three agents,
  being subagents, carry no classification.
- **New section: "tle's engine model — one iteration per turn"**. This is tle's
  load-bearing governance rule, the analogue of TP-0020's gate-spans-four-files
  rule. It must state: `/goal` evaluates only at turn end, so `/tle:run`
  performs exactly one iteration and ends its turn; all agent dispatch is
  foreground because a running subagent at turn end skips that turn's
  evaluation; the condition string generated by `/tle:define` carries the
  restart directive and is therefore part of the engine, not decoration; and
  **when you change the iteration steps in `run.md`, the condition-string
  template in `goal-file-template.md` and the flow described in
  `plugins/tle/README.md` must be updated in the same commit.**
- **New section: "The verdict vector is a machine contract"** (or a paragraph in
  the above): `loop-verifier.md` emits it, `run.md` parses it for the stall
  check, and `goal-file-template.md` supplies the stable item IDs it keys on —
  changing any one requires the other two in the same commit.
- Testing section (`:370-378`): add `claude plugin validate ./plugins/tle` and
  the tle end-to-end install line.

#### 5. This project's own tce profile

**File**: `.claude/tce/profile.md`
**Changes**: The code map's closing note (`:45-46`) says "Monorepo with two
plugins" — update to three. Add `plugins/tle/references/` coverage if the
existing rows do not already generalize (they do: the rows are per-kind, not
per-plugin, so only the closing note changes).

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt`,
      `./plugins/tle` all pass
- [x] `grep -rn "two plugins" README.md CLAUDE.md CONTRIBUTING.md .claude/tce/profile.md`
      returns nothing
- [x] `grep -c "nine" CLAUDE.md` shows the AskUserQuestion rule no longer says
      nine; the rule enumerates ten files including
      `plugins/tle/commands/define.md`
- [x] The `### AskUserQuestion dialog guidelines` block is byte-identical across
      all ten files (extract from each and `diff` pairwise against
      `plugins/tce/commands/research.md`)
- [x] The "Built by Toby" blockquote in `plugins/tle/README.md` is
      byte-identical to the one in `README.md`

#### Manual Verification

- [ ] **End-to-end**: in a scratch greenfield project, `/plugin marketplace add .`,
      `/plugin install tle@toby-plugins`, run `/tle:define`, paste the generated
      `/goal` condition, run `/tle:run <goal-file>`, and confirm the loop
      advances across at least three iterations with `/goal` driving the turns
- [ ] The recommended-permissions snippet in the README actually suppresses the
      implementer's prompts when applied
- [ ] tle works with tce **not** installed (no `.claude/tce/profile.md`): agents
      fall back to the goal file's ops facts without erroring
- [ ] Reading only `plugins/tle/README.md`, a new user can get from zero to a
      running loop

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-5>` docs(TP-0025): document tle across the marketplace
- **Did**: New `plugins/tle/README.md` (tmt-shaped, with Requirements,
  The loop, Greenfield-first, Recommended permissions, What the loop writes);
  third catalog row + reworded intro in `README.md`; three-plugin intro, layout
  tree and validate list in `CONTRIBUTING.md`; `CLAUDE.md` intro (incl. "tle is
  not dogfooded here"), layout tree, AskUserQuestion rule nine→ten, TP-0017
  classification for `define`/`run`, two new governance sections ("tle's engine
  model", "The verdict vector is a machine contract"), testing section;
  `.claude/tce/profile.md` test command + code-map note.
- **Issues**: none.
- **Verification**: ✅ validate (marketplace + all 3 plugins), ✅ no "two
  plugins" / no "nine" left, ✅ AskUserQuestion block byte-identical across all
  ten files, ✅ "Built by Toby" blockquote byte-identical

---

## Phase 6: Ticket Contract Reconciliation

### Overview

Two of TP-0025's acceptance criteria were written before the research surfaced
`/goal`'s turn-boundary evaluation and before the pass-state/immutability
collision was noticed. Bring the ticket in line with what was built.

### Changes Required

**File**: `thoughts/shared/tickets/TP-0025-tle-loop-engineering-plugin.md`
**Changes**:

1. **The `/tle:run` criterion** — replace "then loops: baseline check → …; the
   loop ends when the verifier reports all items passing or an escalation stops
   it" with the one-iteration-per-turn contract: `/tle:run` performs a single
   iteration (baseline check → dispatch verifier → surface the verdict → stall
   check → dispatch spec+plan → dispatch implementer → append to `loop-log.md`)
   and then ends its turn; `/goal`'s evaluator decides whether another turn
   starts; the loop ends when the verifier reports all items passing, the
   iteration budget is reached, or an escalation stops it.
2. **The `/tle:define` criterion** — replace "a granular checklist with per-item
   pass state and per-item verification method" with "a granular checklist with
   **stable per-item IDs** and per-item verification method", and note that live
   pass state is the verdict vector in the latest `NNN-verify.md`, since goal
   files are immutable once a loop starts.
3. **`## Notes & Updates`** — add a dated entry recording both AC changes and
   the reason for each (the `/goal` turn-boundary finding; the pass-state
   versus immutability collision).
4. **`**Updated:**`** meta line — set to the implementation date.

The `## Implementation Plan` section already links this plan — it was filled in
when the plan was written, not here.

Do **not** touch `**Status:**` here — `/tce:implement` owns the lifecycle
transitions.

### Success Criteria

#### Automated Verification

- [ ] The ticket no longer contains the phrase "then loops"
- [ ] The ticket no longer contains the phrase "per-item pass state"
- [ ] The `**Status:**` line still passes the tmt status-validation hook

#### Manual Verification

- [ ] Every remaining acceptance criterion in TP-0025 is satisfied by what was
      actually built, and the two rewritten ones describe the delivered
      behaviour rather than the superseded design

---

## Testing Strategy

There is no application runtime, test runner, typechecker, or linter in this
repo (`.claude/tce/profile.md`), so "tests" means manifest validation plus
structural checks, and real confidence comes from the end-to-end scratch run.

### Automated checks

```bash
claude plugin validate .
claude plugin validate ./plugins/tce
claude plugin validate ./plugins/tmt
claude plugin validate ./plugins/tle
```

Plus the grep/jq structural assertions listed per phase — chiefly: the
AskUserQuestion block byte-identical across ten files, no `tools:` key in any
tle agent, no `disable-model-invocation` in `run.md`, and the `verdict-vector`
marker present in both the verifier and the runner.

### Manual testing steps

1. `/plugin marketplace add .` and `/plugin install tle@toby-plugins` in a
   scratch greenfield web-app project with a boot command and a test command
   already working.
2. Run `/tle:define`; confirm the goal file has stable IDs, ops facts, a
   budget, and a condition string.
3. Paste the generated `/goal` condition.
4. Run `/tle:run <goal-file>`; confirm exactly one iteration's artifacts appear
   and the turn ends.
5. Confirm `/goal` evaluates at that turn end and a "not yet met" verdict starts
   the next turn, which re-invokes `/tle:run`.
6. Let it run at least three iterations; inspect `loop-log.md`.
7. Deliberately weaken a test after the base commit; confirm the next verifier
   run marks the item `fail` and names the weakening.
8. Uninstall chrome-devtools-mcp (or run where it is absent); confirm browser
   items report `cannot-verify` rather than a fabricated `pass`.
9. Force a stall (revert the implementer's change each iteration); confirm the
   escalation rungs fire in order and are recorded.
10. Revert: `/plugin uninstall` + `marketplace remove`.

## Risks and Open Behaviours

Recorded because they are unverifiable from documentation and should be watched
during the manual run:

- **Whether the `/goal` evaluator sees tool results or only assistant text** is
  undocumented. The plan assumes only assistant text, which is why step 7 of the
  runner restates the verdict explicitly. If it turns out tool results are
  visible, the restatement is merely redundant — the assumption is safe in one
  direction only, which is the direction chosen.
- **Whether a plugin command may dispatch its own plugin agent by scoped
  `subagent_type`** (`tle:loop-verifier`) is unverified in this repo; tce's
  commands name agents in prose rather than by scoped type. Phase 4's manual
  verification is the first real test. If scoped dispatch fails, fall back to
  the bare-bold-name phrasing tce uses (`research.md:174-224`).
- **MCP-in-subagent has a poor reliability history** precisely in the
  project-scoped configuration chrome-devtools-mcp typically uses (issues
  #30280 open, #13898 closed). The `cannot-verify` degradation path is what
  keeps this from producing false passes.
- **`${CLAUDE_PLUGIN_ROOT}` substitution in command frontmatter** works but is
  undocumented. tle uses it only in body prose, not in frontmatter, so this
  plan does not depend on it.
- **Same-session context accumulation** is the accepted trade-off from the
  design discussion. One iteration per turn improves this over the internal
  loop, but does not eliminate it; the Stop-hook engine remains the documented
  fallback.

## References

- Original ticket: `thoughts/shared/tickets/TP-0025-tle-loop-engineering-plugin.md`
- Research: `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md`
- Design discussion (authoritative for the plugin's shape):
  `thoughts/shared/discussions/2026-08-19-tle-loop-engineering-plugin.md`
- Isolation pattern: `plugins/tce/agents/plan-compliance-checker.md:14-26`, `:37-47`, `:57-71`
- Profile-read paragraph: `plugins/tce/agents/codebase-analyzer.md:10-12`
- `MANDATORY OUTPUT` pattern: `plugins/tce/commands/quickfix.md:146`, `:170`
- Point-of-use reference read: `plugins/tce/commands/research.md:266`
- Argument check + fallback: `plugins/tce/commands/research.md:135-154`
- Directory-of-artifacts precedent: `plugins/tce/commands/design_explore.md:158`, `:296`
- Append-per-iteration log precedent: `plugins/tce/commands/implement.md:97-119`
- Reference-file header convention: `plugins/tce/references/research-document-template.md:1-22`
- README shape model: `plugins/tmt/README.md:80-87`
- Manifest model: `plugins/tmt/.claude-plugin/plugin.json:1-15`
- Marketplace array: `.claude-plugin/marketplace.json:10-23`
- Pitfalls this plan guards against:
  `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:50-57`, `:82-90`
- https://code.claude.com/docs/en/goal — condition semantics, turn-boundary evaluation, stall guard
- https://code.claude.com/docs/en/sub-agents — plugin-agent fields, tool resolution matrix, isolation
- https://code.claude.com/docs/en/context-window — compaction and skill re-injection caps
