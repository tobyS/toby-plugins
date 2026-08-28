# TP-0029: Pin explicit models on tle's loop agents Implementation Plan

## Overview

Give tle's three loop-worker agents explicit model pins — `loop-implementer` and
`loop-verifier` on `sonnet`, `loop-spec-planner` on `opus` — so an unattended
`/tle:run` loop's cost is a property of the plugin rather than of whichever model
the user's session happened to be on. Leave `loop-goal-critic` on `inherit` and
both tle commands without a `model:` field, so every artifact where the user's own
model choice matters stays open. Then record the resulting division of labour for
consumers (`plugins/tle/README.md`) and the policy for maintainers (`CLAUDE.md`).

## Current State Analysis

All four tle agents declare `model: inherit` on line 4
(`plugins/tle/agents/{loop-verifier,loop-spec-planner,loop-implementer,loop-goal-critic}.md:4`),
so every verifier, planner and implementer dispatch runs on the session model —
Opus for most users — across a budget of up to twenty iterations with nobody
watching. Neither tle command carries a `model:` field today
(`run.md:1-4`, `define.md:1-5`), which is already the desired end state for them.

The repo has both halves of the precedent this ticket applies. TP-0017 pinned
`model: haiku` on tce's two locator agents
(`plugins/tce/agents/codebase-locator.md:5`, `thoughts-locator.md:5`) using the
alias form; TP-0024 rejected hardcoding `model:` into `/tce:implement` because
"there is no per-skill override mechanism for plugin consumers, so it would
silently remove model choice"
(`thoughts/shared/tickets/TP-0024-eco-implement-wrapper-sonnet.md:26-28`) and
shipped `plugins/tce/commands/implement_eco.md:4` as an opt-in wrapper instead.
Neither precedent has been written down as a general policy anywhere.

`plugins/tle/README.md` (208 lines, twelve `##` sections, no `###` headings) has
**no** content about models, cost, tokens or pricing — its four hits for those
words are all about the *iteration* budget. `CLAUDE.md` has two tle governance
sections (`:305-340` engine model, `:342-359` verdict vector) and a tle half
inside the TP-0017 invocation-control section (`:281-296`), but nothing about
agent models.

Two constraints discovered in research shape the verification rather than the
edit. First, `claude plugin validate` does not read agent `model:` values at all —
verified by copying `plugins/tle/` to a scratch dir, setting
`model: bogus-model-xyz` and `model: sonnet[1m]`, and watching it print
"✔ Validation passed". Second, a bad value fails *silently*: the documented
behaviour for an allowlist-blocked value is a fallback to the inherited model, and
upstream issue #32415 reports the same silent fallback for an unrecognized one. So
the acceptance criterion that actually proves anything is the empirical one, and it
can only be discharged in a scratch greenfield project outside this repo.

## Desired End State

`plugins/tle/agents/loop-implementer.md:4` and `loop-verifier.md:4` read
`model: sonnet`; `loop-spec-planner.md:4` reads `model: opus`;
`loop-goal-critic.md:4` still reads `model: inherit`; neither
`plugins/tle/commands/run.md` nor `define.md` has a `model:` line. All four plugin
manifests still validate. `plugins/tle/README.md` carries a new
`## Which model runs what` section between `## The loop` and `## Where the thinking
sits — an honest framing`, telling a consumer what runs on what, why the commands
stay open, what the verifier-on-sonnet risk looks like in a real run, and how to
override the split. `CLAUDE.md` carries a new
`## tle's model pins are policy — agents pinned, commands open (TP-0029)` section
after the verdict-vector section, with a `**RULE:` line forbidding a revert to
`inherit`, a model ID in place of an alias, or a `model:` on either command.

Verified by: the greps in each phase's Automated Verification, plus one scratch
loop run whose subagent transcripts show `sonnet` for the verifier and
implementer, `opus` for the planner, and the session model for the goal critic —
while `thoughts/shared/loops/<slug>/` and `git log` show two consecutive
iterations that each produced a verify report, a plan and a green commit.

### Key Discoveries:

- tle's agent frontmatter order is `name` → `description` → `model` →
  `disallowedTools`, `model` on line 4 in all four files — a single-line
  replacement each, no reordering (research "Current state of tle's agent and
  command frontmatter").
- **`claude plugin validate` ignores agent `model:` values** — empirically
  confirmed with a deliberately bogus value (research "Invalid `model:` values").
  AC 4 is necessary but proves nothing about the pins.
- **A pin is directly observable.** Each subagent writes
  `~/.claude/projects/<project>/<sessionId>/subagents/agent-<agentId>.jsonl` whose
  every assistant line carries `message.model`, and the parent session transcript
  records `resolvedModel` per dispatch. Verified live during research: this
  session's `haiku`-pinned locator resolved to `claude-haiku-4-5-20251001` while
  its `inherit` siblings resolved to `claude-opus-5`. The schema is documented as
  internal and unstable, so this belongs in a runbook, never in plugin code.
- **`sonnet[1m]` is undocumented in agent frontmatter** — the `[1m]` suffix is
  documented for `/model`, full model names and `ANTHROPIC_DEFAULT_*_MODEL`, but
  the sub-agents frontmatter table enumerates only `sonnet`/`opus`/`haiku`/
  `fable`/full ID/`inherit`. Combined with silent failure, a `[1m]` pin could ship
  as a field that does nothing. Not used.
- **`CLAUDE_CODE_SUBAGENT_MODEL` outranks frontmatter** and is the one real
  consumer escape hatch — global across every subagent, so it is honest to
  document but not a substitute for per-agent configurability.
- **TP-0024 is the cautionary precedent**: it shipped `implement_eco.md` but
  parked its CLAUDE.md and README phases behind an unperformed manual gate, and
  they are still unwritten six weeks later — `implement_eco.md:11-12` points at a
  `## Cost tuning` section that does not exist. This plan writes the documentation
  in the same pass as the pins for exactly that reason.
- No prose anywhere in `plugins/tle/` describes which model an agent runs on, so
  none of the three `CLAUDE.md` tle sync rules (TP-0025 engine model, TP-0025
  verdict vector, TP-0017 invocation control) is triggered by these edits.

## What We're NOT Doing

- Pinning or eco-wrapping `/tle:run` — the `/goal` condition string names it by
  hand, so an eco variant means changing `references/goal-file-template.md` and
  the README flow under the TP-0025 three-file sync rule. Separate ticket.
- Pinning `/tle:define` or `loop-goal-critic`.
- Using `haiku` anywhere in tle, or any `[1m]` context-window suffix.
- Making the pins configurable per project or per user (beyond documenting the
  `CLAUDE_CODE_SUBAGENT_MODEL` escape hatch that already exists).
- TP-0024's still-pending tce README `## Cost tuning` section, its CLAUDE.md
  edits, or anything else that would close TP-0024.
- Revisiting tce's own agent model assignments.
- Bumping `plugins/tle/.claude-plugin/plugin.json` or tagging a tle release — tle
  is at `1.0.0` and has never been tagged (`git tag --list` shows only
  `tce--v1.0.0`, `tce--v1.0.1`, `tmt--v1.0.0`).
- Adding any validation guard, script or hook for model values. Nothing in the
  platform supports it, and the runbook is the guard.

## Implementation Approach

Three small phases, one per file group, each independently verifiable and
committed on its own: the pins, the consumer documentation, the maintainer
policy. The pins go first because both documents describe them.

The empirical criteria (ticket AC 5 and AC 6) are carried as **Manual
Verification on Phase 1** with a full runbook in the Testing Strategy below.
They cannot run in this session — they need a scratch greenfield project outside
this repo, a plugin install, and an interactive multi-turn loop. Following the
answered checkpoint question, the documentation ships alongside the pins rather
than waiting behind that gate; the gate stays explicit and unticked until the run
happens. Nothing in either document asserts the run has been performed.

The runbook is designed so one setup proves both directions of AC 5: run
`/tle:define` and iteration 1 from an **Opus** session (goal critic should follow
the session to Opus; verifier and implementer should override it to Sonnet), then
`/model sonnet` and run iteration 2 (the planner should override *that* to Opus).
That is what "regardless of the session model" requires, and the two iterations
double as AC 6's evidence.

---

## Phase 1: Pin the three loop agents

### Overview

Replace `model: inherit` with the pinned alias on the three agents that do the
loop's repeated work, and confirm the two artifacts that must stay open are
untouched.

### Changes Required:

#### 1. The implementer

**File**: `plugins/tle/agents/loop-implementer.md`
**Changes**: line 4, `model: inherit` → `model: sonnet`

```yaml
---
name: loop-implementer
description: Reads a tle step plan from disk, implements it, verifies it is green, and commits the increment. Returns one line.
model: sonnet
disallowedTools: AskUserQuestion, Task
---
```

#### 2. The verifier

**File**: `plugins/tle/agents/loop-verifier.md`
**Changes**: line 4, `model: inherit` → `model: sonnet`

```yaml
model: sonnet
```

#### 3. The spec planner

**File**: `plugins/tle/agents/loop-spec-planner.md`
**Changes**: line 4, `model: inherit` → `model: opus`

```yaml
model: opus
```

#### 4. The two artifacts that must not change

**Files**: `plugins/tle/agents/loop-goal-critic.md`,
`plugins/tle/commands/run.md`, `plugins/tle/commands/define.md`
**Changes**: none. `loop-goal-critic.md:4` stays `model: inherit`; neither
command gains a `model:` field. Listed here because AC 1 and AC 3 assert their
state, and because a later "consistency tidy-up" is exactly the mistake the
CLAUDE.md rule in Phase 3 exists to prevent.

Use the alias form throughout — never a full model ID and never a `[1m]` suffix
(AC 2).

### Success Criteria:

#### Automated Verification:

- [ ] `grep -n "^model:" plugins/tle/agents/*.md` prints exactly four lines:
      `loop-goal-critic.md:4:model: inherit`,
      `loop-implementer.md:4:model: sonnet`,
      `loop-spec-planner.md:4:model: opus`,
      `loop-verifier.md:4:model: sonnet`
- [ ] `grep -c "^model:" plugins/tle/commands/run.md plugins/tle/commands/define.md`
      reports `0` for both files
- [ ] `grep -rn "\[1m\]" plugins/tle/agents/` returns nothing (no context-window
      suffix shipped)
- [ ] `claude plugin validate ./plugins/tle` passes (also confirms the edited
      frontmatter still parses as YAML)
- [ ] `claude plugin validate .`, `claude plugin validate ./plugins/tce` and
      `claude plugin validate ./plugins/tmt` still pass
- [ ] `git diff` for this phase touches only the three agent files and changes
      only their line 4

#### Manual Verification:

- [ ] In a scratch greenfield project (not this repo), across one `/tle:run`
      iteration, the subagent transcripts show `loop-verifier` and
      `loop-implementer` on a `claude-sonnet-*` model and `loop-spec-planner` on
      a `claude-opus-*` model, each differing from the session model in at least
      one of the two iterations — i.e. the pins override the session rather than
      coinciding with it (ticket AC 5, first half; runbook steps 1–8 below)
- [ ] In the same scratch project, `loop-goal-critic` runs on the session model
      during `/tle:define` (ticket AC 5, second half; runbook step 9)
- [ ] The same scratch loop still advances: at least two consecutive iterations
      each produce an `NNN-verify.md`, an `NNN-plan.md` and a green implementer
      commit, with no stall escalation attributable to the pins (ticket AC 6;
      runbook step 10)

---

## Phase 2: Document the division of labour in the tle README

### Overview

Add a new `## Which model runs what` section to `plugins/tle/README.md`, inserted
between `## The loop` (ends at the current line 109) and `## Where the thinking
sits — an honest framing` (currently line 111). It tells a consumer what runs on
what and why, names the verifier-on-sonnet risk in terms they can spot in a real
run, and gives them the one override that exists.

Placement rationale: the README has no cost or model content at all today; the
closest sibling is the context-hygiene paragraph at `:10-13` ("the orchestrating
context only ever holds paths and one-line statuses"), and the section reads as
the other half of why a long loop stays affordable. `## Requirements` (`:46-58`)
is a table of *external tools* with a "Required?" verdict column and does not fit.
The register to match is `## Recommended permissions` (`:143-172`): an operational
reality of running a long unattended loop, in prose, that the user may want to act
on.

### Changes Required:

#### 1. The new section

**File**: `plugins/tle/README.md`
**Changes**: insert after the `## The loop` section's final paragraph, before
`## Where the thinking sits — an honest framing`

```markdown
## Which model runs what

A loop runs unattended, so nobody is there to switch models mid-run. **The
agents that do the repeated work therefore carry their own model pins instead of
inheriting yours**, and the split follows where the tokens actually go:

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
```

Match the file's conventions: sentence-case `##` heading with no ticket ID, no
`###` headings, second person, one bolded load-bearing claim per paragraph, ~78
column hard wrap for prose (table rows are exempt — see `:48-53`).

### Success Criteria:

#### Automated Verification:

- [ ] `grep -n "^## " plugins/tle/README.md` shows `## Which model runs what`
      immediately before `## Where the thinking sits — an honest framing`
- [ ] `grep -n "CLAUDE_CODE_SUBAGENT_MODEL" plugins/tle/README.md` returns a hit
- [ ] `grep -c "^### " plugins/tle/README.md` returns `0` (the file's no-`###`
      convention is preserved)
- [ ] The section names all three pinned agents and both unpinned commands:
      `grep -c "loop-implementer\|loop-verifier\|loop-spec-planner" plugins/tle/README.md`
      is at least 3, and `/tle:define` and `/tle:run` both appear in the new section
- [ ] `claude plugin validate ./plugins/tle` still passes
- [ ] Prose lines in the new section (excluding table rows) are within the file's
      existing wrap width

#### Manual Verification:

- [ ] Reading the section cold, a consumer can act on it: they know what runs on
      what, why the commands stay open, what a verifier miss looks like, and how
      to override the split (ticket AC 7)

---

## Phase 3: Record the policy in CLAUDE.md

### Overview

Add a new `##` governance section after `## The verdict vector is a machine
contract (TP-0025)` (currently ends line 359) and before `## Consuming commands
must re-read their input context documents (TP-0013)` (currently line 361),
following the file's established shape: a framing paragraph naming the artifact
and why it can silently break, the mechanism as bulleted lead-ins, and a
`**RULE:` paragraph as the section's last content.

Placement rationale: a new section matches the one-invariant-per-section pattern
and lands adjacent to the two existing tle sections it cross-references. Folding
it into `## Invocation control … (TP-0017)` was the alternative, but that section
is framed entirely around `disable-model-invocation` and its closing rule is about
the delegation graph; a second, unrelated frontmatter field would blur it. TP-0025
already heads two sections, so a second TP-tagged heading is consistent.

### Changes Required:

#### 1. The new governance section

**File**: `CLAUDE.md`
**Changes**: insert between the verdict-vector section and the TP-0013 re-read
section

```markdown
## tle's model pins are policy — agents pinned, commands open (TP-0029)

tle's loop runs unattended, so its cost has to be a property of the plugin rather
than of whichever model the user happened to be on when they started it. The three
agents that do the loop's repeated work therefore carry **explicit** pins, and
everything the user invokes stays open:

- **`loop-implementer` and `loop-verifier` — `model: sonnet`; `loop-spec-planner`
  — `model: opus`.** Largest consumer, highest repeat count, and the loop's only
  genuine decision, respectively. Always the **alias**, never a full model ID and
  never a `[1m]` suffix, so each pin tracks the current release of its tier
  (TP-0024's precedent, and TP-0017's `haiku` locators before it).
- **`loop-goal-critic` stays `model: inherit`.** One dispatch per loop, in an
  interactive session whose model the user chose, guarding the one immutable
  artifact in the workflow — the saving is nil and a miss is expensive.
- **Neither `/tle:run` nor `/tle:define` carries `model:`.** TP-0024's rule for
  user-invoked commands: there is no per-skill override for plugin consumers, so a
  command-level pin silently removes the consumer's model choice.

Three platform facts make this a rule rather than a preference:

- **`inherit` resolves against the *active* model at dispatch time.** A `model:`
  later added to `/tle:run` would cascade into every agent still saying `inherit`;
  the explicit pins are what make the three loop agents immune to it. (Whether a
  command's turn-scoped pin even reaches a subagent dispatched inside that turn is
  undocumented — that uncertainty is also why an eco runner stays deferred.)
- **A wrong value fails silently.** `claude plugin validate` does not read agent
  `model:` values at all — `model: bogus-model-xyz` passes — and an unrecognized or
  allowlist-blocked value falls back to the inherited model instead of erroring.
  Nothing catches a typo before a real dispatch.
- **`CLAUDE_CODE_SUBAGENT_MODEL` outranks frontmatter.** A consumer who sets it
  defeats all three pins at once. It is documented in `plugins/tle/README.md` as
  the escape hatch, which is also why the pins are not additionally made
  configurable.

**RULE: Treat the three pins as deliberate — never "tidy" them back to `inherit`,
never swap an alias for a model ID, and never add a `model:` field to `/tle:run`
or `/tle:define`. When you change a pin, prove the new value on a real dispatch
before committing** — the subagent transcript at
`~/.claude/projects/<project>/<session>/subagents/agent-<agentId>.jsonl` records
`message.model` on every assistant line, and the parent session transcript records
a `resolvedModel` per dispatch. Validation will not tell you, and that transcript
format is internal to Claude Code and can change between releases, so it belongs
in a verification runbook and never in shipped plugin code.
```

Match the file's conventions: sentence-case declarative heading with a bare
parenthesised ticket ID at the end, no `###` headings, bulleted lead-ins in bold
followed by an em dash, the `**RULE:` bold span running past the colon and closing
mid-sentence so trailing rationale is unbolded, ~88 column wrap.

### Success Criteria:

#### Automated Verification:

- [ ] `grep -n "^## " CLAUDE.md` shows the new section between
      `## The verdict vector is a machine contract (TP-0025)` and
      `## Consuming commands must re-read their input context documents (TP-0013)`
- [ ] `grep -c "^\*\*RULE:" CLAUDE.md` increases by exactly 1 (from 8 to 9)
- [ ] `grep -c "^### " CLAUDE.md` returns `0` (the file's no-`###` convention is
      preserved)
- [ ] The section states all three required points: `grep -n "inherit\|/tle:run\|alias" CLAUDE.md`
      confirms the don't-tidy-back, the cascade warning, and the alias rule are
      all present in the new section
- [ ] No other `CLAUDE.md` section was edited: `git diff CLAUDE.md` shows one
      contiguous insertion and no deletions

#### Manual Verification:

- [ ] The section records the policy a maintainer needs: agents pinned / commands
      open, the pins are deliberate and must not be reverted, and a `model:` on
      `/tle:run` would cascade into any agent still on `inherit` (ticket AC 8)

---

## Testing Strategy

### Automated checks (this repo)

The project has no test runner or typechecker
(`.claude/tce/profile.md` "Commands"). The automated surface is manifest
validation plus the greps listed per phase:

```bash
claude plugin validate .
claude plugin validate ./plugins/tce
claude plugin validate ./plugins/tmt
claude plugin validate ./plugins/tle
grep -n "^model:" plugins/tle/agents/*.md
grep -c "^model:" plugins/tle/commands/run.md plugins/tle/commands/define.md
```

Note that validation is **not** a guard on the pins — it passed on a deliberately
bogus model value during research. It only proves the frontmatter still parses.

### Manual verification runbook (the empirical gate — ticket AC 5 and AC 6)

This cannot run in this repo: tle is deliberately not dogfooded here, and the
loop needs a project that boots and runs tests. Perform it once, in one sitting.

**Setup**

1. Create or pick a scratch greenfield project outside `toby-plugins` — the
   cheapest credible shape is a git repo with a boot command, a test runner, one
   passing test, and an initial commit to serve as the base commit
   (`plugins/tle/README.md:70-73`).
2. Add the permission grants from `plugins/tle/README.md:143-172` to that
   project's `.claude/settings.local.json`, substituting its own test and boot
   commands. Without them the implementer prompts on every Bash/Edit/commit and
   the run measures prompting rather than the loop.
3. Install the plugin from this working tree:
   `/plugin marketplace add /Users/toby/code/work/toby-plugins` (or
   `/plugin marketplace update toby-plugins` if already added), then
   `/plugin install tle@toby-plugins`. Restart the session so the edited agent
   frontmatter is loaded.

**Run**

4. Start a session and set a known session model: `/model opus`.
5. `/tle:define <a small two-or-three-item goal for that project>`.
6. Paste the generated `/goal` condition.
7. `/tle:run thoughts/shared/loops/<slug>/goal.md` — iteration 1, on the Opus
   session.
8. `/model sonnet`, then let the loop run iteration 2 (or invoke `/tle:run`
   again). Iteration 1 proves the `sonnet` pins override an Opus session;
   iteration 2 proves the `opus` pin overrides a Sonnet session. If switching
   models mid-loop disturbs the `/goal` condition, do two separate two-iteration
   runs instead, one from each session model.

**Verify the models (AC 5)**

9. Locate the session directory and read the per-subagent transcripts:

   ```bash
   S=~/.claude/projects/<project-slug>/<session-id>
   for f in "$S"/subagents/agent-*.jsonl; do
     printf '%s\n' "$f"
     jq -r 'select(.type=="assistant") | .message.model' "$f" | sort -u
   done
   ```

   Identify which file is which agent from the dispatch descriptions (or grep the
   parent transcript for `resolvedModel` alongside each `agentId`, which also
   preserves any `[1m]` suffix). Expect:

   | Agent | Expected | Proves |
   | ----- | -------- | ------ |
   | `loop-verifier` | a `claude-sonnet-*` id in the Opus-session iteration | pin overrides session |
   | `loop-implementer` | a `claude-sonnet-*` id in the Opus-session iteration | pin overrides session |
   | `loop-spec-planner` | a `claude-opus-*` id in the Sonnet-session iteration | pin overrides session |
   | `loop-goal-critic` | the model of the `/tle:define` session | `inherit` still follows the user |

   A pin that silently failed shows up here as the session model instead of the
   pinned one — the only way to detect it, since nothing warns.

**Verify the loop still advances (AC 6)**

10. In the scratch project:

    ```bash
    ls thoughts/shared/loops/<slug>/
    git log --oneline
    ```

    Expect `001-verify.md`, `001-plan.md`, `002-verify.md`, `002-plan.md` and
    `loop-log.md`, at least two implementer commits, and a `loop-log.md` whose
    two rows show progress rather than a stall escalation. A stall escalation
    triggered by an identical verdict vector across the two iterations is the
    failure signal to report back.

**If the gate fails**

A pin that does not take effect, or a loop that stalls where it previously
advanced, means returning to this plan rather than patching around it: the
likeliest causes are a stale plugin install (restart required), an org
`availableModels` allowlist silently substituting the model, or
`CLAUDE_CODE_SUBAGENT_MODEL` set in the environment and outranking the
frontmatter. Check the last one first — `echo $CLAUDE_CODE_SUBAGENT_MODEL`.

## Performance Considerations

The whole point. Expected effect on a 20-iteration loop: the implementer (largest
per-iteration spend) and the verifier (highest repeat count) move off Opus, while
the planner — the smallest footprint — stays on it. There is no measurement
requirement in the ticket, and none is added here; the acceptance criteria ask
that the pins take effect and the loop still converges, not that a particular
saving is demonstrated.

The countervailing risk is quality, concentrated in the verifier, and it is
handled by documentation rather than mechanism: the README section names the two
signals that mean raising it to `opus`, per the ticket's Notes.

## Migration Notes

None. The pins take effect for consumers on the next
`/plugin marketplace update toby-plugins`; there is no per-project config, no
state to migrate, and no version marker involved (tle writes no project config).
Consumers who prefer the old behaviour can set `CLAUDE_CODE_SUBAGENT_MODEL`.

## References

- Original ticket: `thoughts/shared/tickets/TP-0029-tle-agent-model-pins.md`
- Related research: `thoughts/shared/research/2026-08-28-TP-0029-tle-agent-model-pins.md`
- Agent-pin precedent: `plugins/tce/agents/thoughts-locator.md:5`,
  `plugins/tce/agents/codebase-locator.md:5` (TP-0017)
- Command-pin precedent and its rejection rationale:
  `plugins/tce/commands/implement_eco.md:4`,
  `thoughts/shared/tickets/TP-0024-eco-implement-wrapper-sonnet.md:26-28`
- README register to match: `plugins/tle/README.md:143-172`
- CLAUDE.md section shape to match: `CLAUDE.md:305-340`, `CLAUDE.md:342-359`
