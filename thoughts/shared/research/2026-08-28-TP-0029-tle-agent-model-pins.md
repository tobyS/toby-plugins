---
date: 2026-08-28T11:01:27+02:00
git_commit: 5cb89db0c23b0d758e0a9388ef10408e4b35b249
branch: main
repository: toby-plugins
topic: "TP-0029: Pin explicit models on tle's loop agents to cut token burn"
tags: [research, codebase, tle, agents, frontmatter, model-pins, cost]
status: complete
last_updated: 2026-08-28
---

# Research: TP-0029 — Pin explicit models on tle's loop agents to cut token burn

**Date**: 2026-08-28 11:01:27 CEST
**Git Commit**: 5cb89db0c23b0d758e0a9388ef10408e4b35b249
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0029 asks to pin explicit models on tle's three loop agents (`loop-implementer`
and `loop-verifier` on `sonnet`, `loop-spec-planner` on `opus`), leave
`loop-goal-critic` on `inherit` and both tle commands without a `model:` field,
and record the resulting policy in `plugins/tle/README.md` and the repo
`CLAUDE.md`. The ticket's six "Questions for Research/Planning" ask: how to
*observe* which model a subagent actually ran on; whether an invalid `model:`
value fails loudly or silently; whether `[1m]` context-window suffixes are legal
in agent frontmatter; where the README note belongs; which `CLAUDE.md` section
should carry the policy; and what the cheapest credible scratch-project setup for
the empirical check is.

## Summary

The edit itself is four frontmatter lines and is unambiguous — the mechanism is
documented, already used in this repo, and empirically confirmed working during
this very research session. What research changes is the *shape of the
verification*, and it changes it in two directions at once.

**The good news — the empirical criterion is cheap and precise, not a
narrative judgement.** TP-0017's parity spot-check had to infer haiku's effect
from output quality because no direct observation was known. There is one now:
Claude Code writes a per-subagent transcript whose every assistant line carries
`message.model`, and the parent session transcript records a `resolvedModel`
string per dispatch. Both were verified on this machine during this session —
`tce:thoughts-locator` (`model: haiku`) resolved to
`claude-haiku-4-5-20251001` while the `inherit` agents in the same session
resolved to `claude-opus-5`. That is a direct, greppable proof that a
plugin-shipped agent's frontmatter pin takes effect, which is exactly what
acceptance criterion 5 asks for. Caveat: the transcript schema is *explicitly
declared internal and unstable* by the docs, so this is an observation
technique, not a contract.

**The bad news — `claude plugin validate` is not a guard, and a wrong value
fails silently.** I copied `plugins/tle/` to a scratch dir, set
`model: bogus-model-xyz` on `loop-implementer` and `model: sonnet[1m]` on
`loop-spec-planner`, and ran `claude plugin validate .`: it printed
"Validating plugin manifest: …/.claude-plugin/plugin.json" and
"✔ Validation passed". It never reads the agent files' model values at all. The
documented behaviour for a value blocked by an org allowlist is a silent
fallback to the inherited model; for a *typo'd* value nothing is documented, and
a closed upstream bug report (anthropics/claude-code#32415) describes exactly the
same silent fallback. So AC 4 (`claude plugin validate ./plugins/tle` passes) is
necessary but proves nothing about the pins — the whole burden of proof sits on
AC 5, and AC 5 is the one criterion that cannot be discharged inside this repo,
because tle is deliberately not dogfooded here.

Three further findings shape the plan:

1. **`sonnet[1m]` is undocumented in *agent* frontmatter.** The `[1m]` suffix is
   documented as a first-class alias for `/model`, full model names and the
   `ANTHROPIC_DEFAULT_*_MODEL` env vars, but the sub-agents frontmatter table
   enumerates only `sonnet`/`opus`/`haiku`/`fable`/full ID/`inherit` with no
   `[1m]` example. Combined with the silent-failure mode above, shipping a `[1m]`
   pin means shipping something that may silently do nothing.
2. **A consumer-side escape hatch exists after all, and it is global.** The
   `CLAUDE_CODE_SUBAGENT_MODEL` env var "overrides the per-invocation `model`
   parameter and the subagent definition's `model` frontmatter". This partly
   contradicts the ticket's premise that "no per-skill override mechanism exists
   for plugin consumers" — for *agents* one does — but it is all-or-nothing
   across every subagent in the session, so it does not make the pins
   configurable per agent.
3. **TP-0024's precedent is thinner than the ticket assumes.** The `implement_eco`
   wrapper shipped, but its CLAUDE.md and README phases never ran — including the
   drafted `## Cost tuning` section, which exists verbatim in TP-0024's plan and
   is referenced from `implement_eco.md:11-12` as if it were live. TP-0024 stalled
   on precisely the kind of human-gated manual verification TP-0029's AC 5 and 6
   require. That is the risk this ticket has to design around, not repeat.

## Detailed Findings

### Current state of tle's agent and command frontmatter

All four tle agents are identical in shape, `model: inherit` on line 4 in each:

- `plugins/tle/agents/loop-verifier.md:4`
- `plugins/tle/agents/loop-spec-planner.md:4`
- `plugins/tle/agents/loop-implementer.md:4`
- `plugins/tle/agents/loop-goal-critic.md:4`

The tle agent frontmatter convention is `name` → `description` → `model` →
`disallowedTools`, opening `---` on line 1, closing `---` on line 6, unquoted
plain scalars, comma-space separated alphabetized denylist. (tce's agents use a
different order — `name` → `description` → `tools` → [`color`] → `model` — so
`model` is the *last* key there and the *third* key in tle.) Each edit is a
single-line replacement in place; no reordering is needed.

Neither tle command carries `model:`:

- `plugins/tle/commands/define.md` — frontmatter lines 1–5: `description`,
  `argument-hint`, `disable-model-invocation: true`.
- `plugins/tle/commands/run.md` — frontmatter lines 1–4: `description`,
  `argument-hint`. No `disable-model-invocation` (load-bearing, per
  `CLAUDE.md:286-291`).

So AC 3 ("neither `run.md` nor `define.md` gains a `model:` field") is satisfied
by the current state and only needs preserving, not changing.

### The in-repo precedent for `model:` pins

`grep -rn "^model:" plugins/` returns twelve lines. The complete picture:

| File | Line | Value |
|---|---|---|
| `plugins/tce/agents/codebase-locator.md` | 5 | `haiku` |
| `plugins/tce/agents/thoughts-locator.md` | 5 | `haiku` |
| `plugins/tce/agents/codebase-analyzer.md` | 5 | `inherit` |
| `plugins/tce/agents/codebase-pattern-finder.md` | 5 | `inherit` |
| `plugins/tce/agents/thoughts-analyzer.md` | 5 | `inherit` |
| `plugins/tce/agents/plan-compliance-checker.md` | 5 | `inherit` |
| `plugins/tce/agents/web-search-researcher.md` | 6 | `inherit` |
| `plugins/tce/commands/implement_eco.md` | 4 | `sonnet` |
| `plugins/tle/agents/*.md` (×4) | 4 | `inherit` |

Two concrete-tier pins exist today, both alias form, both on tce's pure
locator agents. `implement_eco.md:4` is the repo's only command-level `model:`.

### TP-0017 — what makes an agent safe to downgrade

TP-0017's eligibility criterion, from
`thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md:293-297`:

> Candidates: `codebase-locator.md` and `thoughts-locator.md` — both are pure
> find-and-categorize (tools: Grep/Glob/LS(+LSP), no Read, no analysis duties;
> their Output Format is a categorized file listing). The analyzers,
> pattern-finder, and web-search-researcher synthesize/read content and are not
> in scope of the review's recommendation.

Its *verification* criterion,
`thoughts/shared/research/2026-07-04-…:299-305`, is a parity spot-check:

> **Parity spot-check (cheap)**: pick 2–3 known research questions against this
> repo …, run each locator prompt once with `model: inherit` and once with
> `model: haiku` … and diff the returned file sets against the known-correct
> locations. Locator output is a file list — parity is objectively checkable,
> unlike analyzer prose.

with the pass bar at
`thoughts/shared/plans/2026-07-04-…:155`: "**Parity = no known-correct file
missing on haiku.**" The result, `plans/2026-07-04-…:171-175`, was 100% recall.

Two things follow for TP-0029. First, TP-0017's *eligibility* test (mechanical,
no synthesis) does **not** cover tle's implementer or verifier — both read,
reason and write. TP-0029's ticket argues a different and explicitly stated
basis (constrained inputs plus downstream re-checking), which is a new criterion
rather than an application of the old one, and the ticket says so. Second,
TP-0017's *verification* method — output parity — is not available here: a
verify report is prose plus evidence, not a checkable file set. The verdict
vector is the only machine-comparable output, and it is a function of the system
state, not of the verifier's model.

TP-0017 also recorded the resolution precedence,
`research/2026-07-04-…:273-282`: `CLAUDE_CODE_SUBAGENT_MODEL` → per-invocation
`model` param → frontmatter → main-conversation model; and that an org
`availableModels` block "falls back to the inherited or default model rather than
failing the request".

### TP-0024 — the alias rule, the command rule, and the stall

**Alias, not pinned ID** — the reasoning is one sentence, from
`thoughts/shared/tickets/TP-0024-eco-implement-wrapper-sonnet.md:78-80`:

> - Making the wrapper's model configurable (haiku, full model IDs, per-project
>   config) — the `sonnet` alias tracks the latest Sonnet release; that is
>   enough for now.

The same argument appears in TP-0017 for `haiku`
(`research/2026-07-04-…:287-291`): "The alias (not a pinned ID) tracks future
Haiku releases automatically."

**Why a user-invoked command must not carry `model:`** —
`tickets/TP-0024-…:26-28`:

> Hardcoding `model: sonnet` into `implement.md` was considered and rejected:
> there is no per-skill override mechanism for plugin consumers, so it would
> silently remove model choice — against tce's everything-agnostic design.

**What actually shipped, and what did not.** Only
`plugins/tce/commands/implement_eco.md` (commit `1bed1c2`). TP-0024's Phase 2
(two `CLAUDE.md` edits) and Phase 3 (a `plugins/tce/README.md` `## Cost tuning`
section, a Helpers-table row, a TOC entry) were never executed —
`grep` for `implement_eco` and `Cost tuning` outside the TP-0024 thoughts docs
finds nothing in `CLAUDE.md` or `plugins/tce/README.md`. The wrapper body
therefore points at a section that does not exist
(`plugins/tce/commands/implement_eco.md:11-12`). The ticket is still
`**Status:** In Progress` with all five acceptance criteria unchecked.

The stated reason for the stall, `plans/2026-07-12-…:144-150`: "**Decision gate —
do not start Phase 2 until a human has performed and confirmed all three Manual
Verification items above.**" All three remain unperformed. This is the single
most relevant historical fact for TP-0029: an identically-shaped ticket, with an
identically-shaped human-gated empirical criterion, has been parked for six weeks
with its documentation phases unwritten.

### Observing which model a subagent ran on — the answer to research question 1

Three surfaces, in descending order of usefulness.

**(a) `resolvedModel` in the parent session transcript.** Each subagent dispatch
result carries the fully resolved model string, keyed by `agentId`, and it
*preserves the `[1m]` suffix*:

```
"toolUseResult":{"isAsync":true,"status":"async_launched",
  "agentId":"afdf128d66ee53158","description":"Locate TP-0017/0024/0025 thoughts docs",
  "resolvedModel":"claude-haiku-4-5-20251001"
```
```
"toolUseResult":{…,"agentId":"a63759fc5e8122e53",
  "description":"Research subagent model frontmatter semantics",
  "resolvedModel":"claude-opus-5[1m]"
```

This is the best signal for verifying a pin: it is the resolution *outcome*, not
an inference. Observed on `[1m]`-suffixed async dispatches; whether foreground
dispatches also carry the field was not confirmed.

**(b) `message.model` per assistant line in the subagent transcript**, at
`~/.claude/projects/<project>/<sessionId>/subagents/agent-<agentId>.jsonl` (a
documented path — sub-agents page, and the `.claude` directory page lists
`projects/<project>/<session>/subagents/` as "Subagent conversation
transcripts"). I ran this against this session's own dispatches:

```
$ jq -r 'select(.type=="assistant") | (.message.model // "no-model-field")' \
    <thoughts-locator dispatch>.jsonl | sort | uniq -c
  54 claude-haiku-4-5-20251001
$ jq -r … <codebase-analyzer dispatch>.jsonl | sort | uniq -c
  26 claude-opus-5
```

The `thoughts-locator` agent carries `model: haiku`
(`plugins/tce/agents/thoughts-locator.md:5`); the two `codebase-analyzer`
dispatches carry `model: inherit`
(`plugins/tce/agents/codebase-analyzer.md:5`) and the session model is Opus 5.
**This is a live, in-repo demonstration that a plugin-shipped agent's `model:`
frontmatter pin resolves as written and that `inherit` follows the session.**
Note it records the plain model ID *without* the `[1m]` suffix, so it cannot
distinguish context-window variants.

**(c) OpenTelemetry.** `claude_code.cost.usage` / `claude_code.token.usage` carry
a `model` attribute, and spans carry `agent_id` / `parent_agent_id` /
`query_source` (`"main"`/`"subagent"`) plus `agent.name` — the latter replaced
with `"custom"` unless `OTEL_LOG_TOOL_DETAILS=1`. Correlating model to a specific
subagent this way is inference from the attribute lists, not a documented recipe.
Overkill for this ticket.

**Not usable:** `/agents` no longer opens a wizard (v2.1.198 prints a reminder
instead); `SubagentStart`/`SubagentStop` hooks receive `agent_id` and
`agent_type` but no model ("Only `SessionStart` hooks can receive a `model`
field"); `modelUsage` in `--output-format json` is a per-run aggregate with no
subagent breakdown; the status line and `/status` report the main session only.

**Standing caveat**, from the sessions doc: "The entry format is internal to
Claude Code and changes between versions, so scripts that parse these files
directly can break on any release." The technique belongs in a plan's
verification steps, never in shipped plugin code.

### Invalid `model:` values — the answer to research question 2

**`claude plugin validate` does not check the value. Verified empirically.**
Procedure and result:

```
$ cp -R plugins/tle <scratch>/tle-validate-test
$ claude plugin validate .            # baseline, all four agents `inherit`
  Validating plugin manifest: …/tle-validate-test/.claude-plugin/plugin.json
  ✔ Validation passed
$ sed -i '' 's/^model: inherit$/model: sonnet/'          agents/loop-verifier.md
$ sed -i '' 's/^model: inherit$/model: bogus-model-xyz/' agents/loop-implementer.md
$ sed -i '' 's/^model: inherit$/model: sonnet[1m]/'      agents/loop-spec-planner.md
$ claude plugin validate .
  Validating plugin manifest: …/tle-validate-test/.claude-plugin/plugin.json
  ✔ Validation passed
```

The command validates the plugin *manifest*; a nonsense model value on an agent
is invisible to it. Per the plugins reference it does catch agent frontmatter
that *fails to parse*, and reports unrecognized field *names* as warnings (with
a did-you-mean suggestion, promotable to errors with `--strict`) — so it would
catch `modle: sonnet` but not `model: sonnnet`.

**What the docs say about bad values.** Only the org-allowlist case is
documented, and it is a silent substitution:

> Claude Code checks the environment variable, per-invocation parameter, and
> frontmatter values against your organization's `availableModels` allowlist.
> For a blocked value, it substitutes another model … Claude Code runs the
> subagent on the inherited model instead. In interactive sessions, Claude Code
> shows a warning naming the requested model and the model the subagent runs on.

(Interactive sessions do warn *for the allowlist case*.) An unrecognized string is
not covered: the "`Model "<name>" is not a recognized model id.`" check documented
in model-config is explicitly scoped away from `--model`, `ANTHROPIC_MODEL` and
the `model` setting, and frontmatter is named in neither direction.

**Non-doc evidence**, flagged as such: anthropics/claude-code issue #32415,
"[BUG] Unsupported (?) model in agent config silently fails instead of erroring"
(9 Mar 2026, closed) reports that frontmatter agents with a bad model "spawn but
silently run on the main agent's model" with no warning, while `--agents` JSON
agents with a bad model are silently dropped.

What *does* make an agent file fail to load (and appear in `claude --debug`):
missing `name`, a `name` starting with `-` or containing `:`, a `name` without
`description`, and unparseable YAML. A bad `model:` is not on that list.

**Consequence for the plan:** the only reliable guard is observing
`resolvedModel` / `message.model` on a real dispatch. A validation-only
acceptance criterion would be an asserted invariant rather than a checked one —
the same failure mode `CLAUDE.md:355-359` calls out for the verdict vector.

### `[1m]` suffixes in agent frontmatter — the answer to research question 3

**Documented for `/model`, full model names and env vars; not documented for
agent frontmatter.** The model-config alias table lists `sonnet[1m]` and
`opus[1m]` as first-class aliases, and the extended-context section shows
`/model opus[1m]`, `/model sonnet[1m]`, `/model claude-opus-4-8[1m]` and
`ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-8[1m]'`. The sub-agents frontmatter
table and its "Choose a model" section enumerate only `sonnet`, `opus`, `haiku`,
`fable`, a full model ID, and `inherit` — no `[1m]` anywhere on the page. The CLI
reference's `--model` row does not mention `[1m]` either, so the frontmatter
doc's "accepts the same values as the `--model` flag" bridge does not carry it.

One data point in favour: `resolvedModel` for a subagent dispatch in this session
reads `claude-opus-5[1m]`, so the suffix *does* survive the subagent resolution
path. That shows the resolver handles the string; it does not show the
frontmatter parser accepts it as an input.

Weighed against the silent-failure mode above, a `[1m]` pin would be a shipped
plugin field that may quietly do nothing on a consumer's machine, with no
validation and no warning. It is also outside AC 2's "model **aliases** … so the
pins track the current release of each tier" — `sonnet[1m]` pins a context
window, not a tier.

### The consumer escape hatch that does exist

From the sub-agents resolution order: `CLAUDE_CODE_SUBAGENT_MODEL`, when set to a
model alias or model ID, "overrides the per-invocation `model` parameter and the
subagent definition's `model` frontmatter" — i.e. it defeats every pin in the
plugin. Setting it to `inherit` "is the same as leaving it unset" (as of
v2.1.196).

This is a genuine, documented, consumer-side override for exactly the thing
TP-0029 pins, and the ticket's Out of Scope entry ("no per-skill override
mechanism exists for plugin consumers") is accurate for *commands* but not for
*agents*. It is global rather than per-agent — a user who sets it to `sonnet` to
cheapen the implementer also downgrades the spec-planner and the goal critic — so
it does not satisfy the ticket's "configurable per project or per user" scope
exclusion, but it is the honest answer to a consumer who asks "what if I disagree
with these pins?", and it is a plausible README addition.

### Where the README note could go — the answer to research question 4

`plugins/tle/README.md` is 208 lines, one `#` and twelve `##` sections, **no
`###` headings at all**. A grep for `model|cost|token|budget|price|opus|sonnet|haiku`
returns four hits, all about the *iteration* budget or the generic phrase "an
independent model" (`:8`, `:25`, `:103`, `:107`). **There is no section about
model choice, cost, pricing, or token spend anywhere in the file.**

The section list, with the candidates in bold:

| Line | Section |
|---|---|
| 20 | `## What you get` — four bullets, each a bolded label + em dash; the agents bullet is `:36-42` |
| 46 | **`## Requirements`** — a 3-column tool table + a prose caveat paragraph |
| 60 | `## Install` |
| 68 | `## Set up a project` |
| 75 | `## Commands` |
| 82 | **`## The loop`** — the three-input example + why `/goal` drives it |
| 111 | `## Where the thinking sits — an honest framing` |
| 131 | `## Greenfield-first` |
| 143 | **`## Recommended permissions`** |
| 174 | `## What the loop writes` |
| 197 | `## Update` |
| 203 | `## Contributing` |

Three observations bear on placement:

1. **`## Requirements` is a table of *external tools*** (`git`, `/goal`,
   `chrome-devtools-mcp`, `tce`) with a "Required?" verdict column. A model-pin
   policy is not a tool the user must install; it would not fit the column
   semantics.
2. **`## Recommended permissions` is the exact precedent** for what TP-0029's
   README note is: an operational reality of running a long unattended loop that
   the user must understand and may want to act on, stated in prose, with a
   concrete config snippet. Its opening —"Plugin agents cannot set their own
   permission mode … and the plugin cannot grant this for you" (`:145-148`) — is
   the register to match.
3. The closest existing text to a cost claim is `:10-13` ("the orchestrating
   context only ever holds paths and one-line statuses … lets the loop run long
   without drowning in its own history"), framed as context hygiene. A model
   section would be its natural sibling — the *other* half of why a long loop
   stays affordable.

The README's conventions to match: second person ("you"), sentence-case headings
with no ticket IDs, `##` only, tables reserved for enumerable reference data
(exactly two exist), one bolded load-bearing claim per paragraph, ~78-column hard
wrap, deliberately candid sections that state limits rather than features.

### Where the CLAUDE.md policy could go — the answer to research question 5

`CLAUDE.md` is 494 lines, eighteen `##` sections, **no `###` headings**. The tle
territory:

| Lines | Passage |
|---|---|
| 3–12 | intro, plugin roster naming tle |
| 14–18 | "**tle is deliberately not dogfooded here.**" |
| 46–53 | the `plugins/tle/` block in the Layout tree |
| 264–303 | `## Invocation control: disable-model-invocation … (TP-0017)` — tle half at 281–296 |
| 305–340 | `## tle's engine model — one iteration per turn (TP-0025)` |
| 342–359 | `## The verdict vector is a machine contract (TP-0025)` |
| 469–472 | the tle end-to-end bullet in `## Testing changes` |

The house style of a governance section is consistent and easy to match: a
framing paragraph naming the artifact and why it can silently break; then the
mechanism as bullets with bolded lead-ins; then a `**RULE: When you …**`
paragraph as the section's last content, with the bold span running past the
colon and closing mid-sentence so trailing rationale is unbolded; one bare
parenthesised ticket ID at the end of the heading; sentence-case declarative
headings; ~88-column wrap. Seven of the eighteen sections carry a `**RULE:` line
(`:213`, `:257`, `:336`, `:355`, `:372`, `:395`, `:417`, `:447`).

Two placements are viable:

- **Extend the TP-0017 invocation-control section** (264–303). It is already the
  "frontmatter classification" section and already splits tce/tle, and TP-0029's
  policy is structurally the same shape (a two-set classification: agents pinned,
  commands open). Against it: that section is titled and framed entirely around
  `disable-model-invocation`, its closing rule is about the delegation graph, and
  bolting a second, unrelated frontmatter field into it would blur a section that
  is currently precise. The tle half there also already carries the load-bearing
  `/tle:run` argument, which the model policy must cross-reference rather than
  crowd.
- **A new `##` section adjacent to the two tle ones** (i.e. after 340 or after
  359). Matches the one-invariant-per-section pattern, gets its own `**RULE:`
  line, and lands next to `## tle's engine model` which it cross-references (a
  future `model:` on `/tle:run` is *both* a cascade risk and a turn-scoping
  question). Against it: a nineteenth section in an already long file.

Note the precedent for one ticket heading two sections: TP-0025 heads both 305
and 342.

Whichever is chosen, the policy must record three things the ticket names: (a)
agents pinned / commands open, (b) the pins are deliberate and must not be
"tidied" back to `inherit`, and (c) a `model:` added to `/tle:run` would cascade
into any agent still on `inherit`. Research adds a fourth candidate: (d)
`claude plugin validate` does not check model values, so a typo is invisible
until a real dispatch is observed.

### The scratch-project setup — the answer to research question 6

The ticket asks for "the cheapest credible scratch-project setup … (it must boot,
run tests, and reach a green commit twice)". Constraints from
`plugins/tle/README.md:70-73` — "There is nothing to initialize … What it does
need is a project that can already boot and run its tests: do the groundwork
first (dev environment, a boot command, a test command, an empty passing test
suite), then define the goal" — and from `CLAUDE.md:469-472`, which prescribes
the procedure: `/plugin install tle@toby-plugins` in a scratch greenfield app
project (not this repo), then `/tle:define` → paste the `/goal` condition →
`/tle:run <goal-file>` for a few iterations.

The measurable part of AC 5 does **not** require the loop to be long. One
`/tle:run` iteration dispatches all three loop agents; one `/tle:define` dispatches
`loop-goal-critic`. So the minimum shape is: a project with a boot command, a test
runner, one passing test, a git repo with a base commit, a goal file with two or
three genuinely small checklist items, and two `/tle:run` turns. AC 6's "at least
two consecutive iterations each produce a verify report, a plan, and a green
commit" sets the floor at two iterations, not at goal completion.

Also relevant: `plugins/tle/README.md:143-172` — without the permission grants in
`.claude/settings.local.json`, the implementer prompts on every Bash/Edit/commit
and the run is not autonomous. The scratch project needs that file before the
run, or the "empirical" check measures prompting rather than the loop.

The verification itself, once the run exists, is a grep — the observation
techniques above, keyed by `agentId`, against the session transcript. Nothing
about it requires judgement, which is what makes AC 5 discharge-able in one
sitting *if* the scratch project exists.

### Nothing else in the repo references tle's agent models

`grep` across `plugins/tle/` for model-related words finds no prose in
`run.md`, `define.md`, `references/goal-file-template.md` or the agents' bodies
that describes which model an agent runs on. So the four frontmatter edits have
no in-plugin prose to keep in sync — the sync burden is entirely the README and
`CLAUDE.md`, exactly as the ticket's ACs state. In particular, none of the three
`CLAUDE.md` tle sync rules (TP-0025 engine model → `run.md` + template + README;
TP-0025 verdict vector → template + verifier + runner; TP-0017 invocation
control) is triggered by a frontmatter `model:` change.

`plugins/tle/.claude-plugin/plugin.json` is at `version: 1.0.0`, matching its
`.claude-plugin/marketplace.json` entry, and `git tag --list` shows only
`tce--v1.0.0`, `tce--v1.0.1`, `tmt--v1.0.0` — **tle has never been released**.
TP-0029 therefore needs no version bump and no release step unless the user wants
tle's first tag as part of this work.

## Code References

- `plugins/tle/agents/loop-verifier.md:4` — `model: inherit`, to become `sonnet`
- `plugins/tle/agents/loop-spec-planner.md:4` — `model: inherit`, to become `opus`
- `plugins/tle/agents/loop-implementer.md:4` — `model: inherit`, to become `sonnet`
- `plugins/tle/agents/loop-goal-critic.md:4` — `model: inherit`, stays
- `plugins/tle/commands/run.md:1-4` — frontmatter, must not gain `model:`
- `plugins/tle/commands/define.md:1-5` — frontmatter, must not gain `model:`
- `plugins/tce/agents/thoughts-locator.md:5` / `codebase-locator.md:5` — the
  `model: haiku` precedent (TP-0017)
- `plugins/tce/commands/implement_eco.md:4` — the repo's only command-level
  `model: sonnet` (TP-0024)
- `plugins/tce/commands/implement_eco.md:11-12` — points at a `## Cost tuning`
  README section that was never written
- `plugins/tle/README.md:46-58` — `## Requirements` table (a *tool* table)
- `plugins/tle/README.md:143-172` — `## Recommended permissions`, the register
  and shape a cost/model section should match
- `plugins/tle/README.md:36-42` — the four-agents bullet in `## What you get`
- `plugins/tle/README.md:10-13` — the context-hygiene paragraph, the closest
  existing sibling to a cost claim
- `CLAUDE.md:264-303` — `## Invocation control … (TP-0017)`, tle half at 281–296
- `CLAUDE.md:305-340` — `## tle's engine model — one iteration per turn (TP-0025)`
- `CLAUDE.md:342-359` — `## The verdict vector is a machine contract (TP-0025)`
- `CLAUDE.md:469-472` — the tle end-to-end testing procedure
- `plugins/tle/.claude-plugin/plugin.json` — `version: 1.0.0`, never tagged

## Architecture Documentation

**tle agent frontmatter shape** (all four files, lines 1–6):

```
---
name: <agent-name>
description: <one to three sentences; the three loop agents end "Returns one line.">
model: inherit
disallowedTools: <alphabetized, comma-space separated denylist>
---
```

`model` is the third key, between `description` and `disallowedTools`. tce's
agents put `model` last instead. Values are unquoted plain scalars throughout
both plugins.

**Model resolution precedence for a subagent** (documented, sub-agents page):

1. `CLAUDE_CODE_SUBAGENT_MODEL` env var
2. per-invocation `model` parameter
3. the subagent definition's `model` frontmatter  ← what TP-0029 sets
4. the main conversation's model  ← what `inherit` means

Legal frontmatter values: `sonnet`, `opus`, `haiku`, `fable`, a full model ID,
`inherit` (default when omitted). `default`, `best` and `opusplan` are
session-level aliases in the model-config table and are *not* enumerated for
agent frontmatter. The plugins reference confirms plugin-shipped agents support
`model` (alongside `name`, `description`, `effort`, `maxTurns`, `tools`,
`disallowedTools`, `skills`, `memory`, `background`, `isolation`).

**Command/skill `model:` semantics** (documented, skills page): "The override
applies for the rest of the current turn and is not saved to settings; the
session model resumes on your next prompt." Whether an `inherit` subagent
dispatched during that turn sees the override is **not documented** — the
sub-agents page says `inherit` uses "the main conversation's model" and never
says whether that reads the active or the configured model. This is precisely the
uncertainty behind the ticket's Out of Scope exclusion of an eco `/tle:run`, and
it is also the mechanism behind the ticket's "immune to a future `model:` on
`/tle:run`" argument: explicit pins make the question moot for the three pinned
agents.

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0017-adopt-frontmatter-machinery.md:125-128` — the
  locator pins and the parity spot-check result; "Analyzer/pattern/web agents
  stay `inherit`."
- `thoughts/shared/tickets/TP-0017-…:52-54` — the meta-requirement that "the
  decision (either way) is recorded", which TP-0029's CLAUDE.md AC mirrors.
- `thoughts/shared/tickets/TP-0017-…:132-141` — an adjacent silent-failure hazard
  (a missing `allowed-tools` grant makes a command invocation "silently abort —
  0 turns, no error"). Different mechanism, same lesson: this platform's
  frontmatter failures are quiet.
- `thoughts/shared/tickets/TP-0024-eco-implement-wrapper-sonnet.md:26-28, 73-74,
  78-80` — the command-vs-agent rule and the alias rule.
- `thoughts/shared/plans/2026-07-12-TP-0024-…:255-283` — the drafted
  `## Cost tuning` section for tce's README, never written. TP-0029 scopes it
  out, but it is the wording TP-0029's README section would otherwise duplicate,
  and it is where a future shared framing would come from.
- `thoughts/shared/plans/2026-07-12-TP-0024-…:132-137` — the manual verification
  item that stalled TP-0024, phrased as "ask what model is currently active
  partway through the turn, or check Claude Code's own model indicator/status
  line". TP-0029 can do materially better than this.
- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md` —
  cites `implement_eco.md` as existing precedent for a model-pinned artifact.

## Related Research

- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` —
  agent-level `model:` resolution, the haiku eligibility criteria, the parity
  spot-check design.
- `thoughts/shared/research/2026-07-12-TP-0024-eco-implement-wrapper-sonnet.md` —
  command-level `model:` semantics, turn scoping, and the undocumented
  propagation question.
- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md` —
  tle's architecture, the verdict vector, the one-iteration-per-turn engine.

## Open Questions

1. **How AC 5 and AC 6 get discharged.** They require a scratch greenfield
   project outside this repo and an interactive multi-turn loop run — work that
   cannot happen inside this session. TP-0024 stalled at exactly this gate and
   left its documentation phases unwritten as a result. The plan must decide
   whether the docs ship alongside the pins (with the empirical criteria carried
   as an explicit Manual Verification gate the user performs), or whether
   everything waits on the run.
2. **Where the README section goes** — a new `##` section (and if so, in which
   slot), a note attached to `## Requirements`, or folded into `## The loop`.
3. **Where the CLAUDE.md policy goes** — a new tle section adjacent to the two
   TP-0025 ones, or an extension of the TP-0017 invocation-control section.
4. **Whether to document `CLAUDE_CODE_SUBAGENT_MODEL`** in the README as the
   consumer's (global, all-or-nothing) escape hatch from the pins. It partly
   contradicts the ticket's stated premise and is a small scope addition.
5. **Settled by research, recorded here rather than asked:** `sonnet[1m]` /
   `opus[1m]` should **not** be used. Undocumented in agent frontmatter, not
   caught by `claude plugin validate`, and silently ignored when rejected — a
   shipped field that may do nothing. AC 2's "aliases … track the current release
   of each tier" also argues against a context-window pin.
6. **Not investigated:** whether `effort:` (documented on subagent frontmatter
   with the same override semantics as `model:`) is a better or complementary
   lever for the verifier. Out of the ticket's scope; noted for a future ticket.
