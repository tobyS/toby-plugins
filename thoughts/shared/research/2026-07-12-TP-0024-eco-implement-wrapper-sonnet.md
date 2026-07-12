---
date: 2026-07-12T09:59:42Z
git_commit: b5623e8942af28736fcb139475e48d9cf117ec34
branch: main
repository: toby-plugins
topic: "Opt-in eco wrapper command to run /tce:implement on Sonnet (TP-0024)"
tags: [research, codebase, tce, frontmatter, model-selection, skill-delegation, cost-tuning]
status: complete
last_updated: 2026-07-12
---

# Research: Opt-in eco wrapper command to run /tce:implement on Sonnet (TP-0024)

**Date**: 2026-07-12T09:59:42Z
**Git Commit**: b5623e8942af28736fcb139475e48d9cf117ec34
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0024 asks for a new opt-in wrapper command in `plugins/tce/commands/` that carries
`model: sonnet` and `disable-model-invocation: true` in its frontmatter, and whose body
does nothing but delegate to the `tce:implement` skill, passing arguments through — so a
user can run implementation on a Sonnet-class model without manually switching models
before and after. What exists today around command/agent frontmatter, `model:` selection,
Skill-tool delegation, and the invocation-control classification (TP-0017) that the new
wrapper must fit into, and what is documented vs. undocumented about the specific
mechanism the wrapper depends on?

## Summary

- No command in this plugin (or `plugins/tmt/`) currently sets a `model:` frontmatter
  field — `model:` is used only on the seven agent files under `plugins/tce/agents/`,
  where it is either `haiku` (the two locator agents) or `inherit` (all others). The
  wrapper would be the first command-level use of `model:` in the repo.
- No pure "wrapper" command exists anywhere in the repo today — every existing command,
  including the two composites (`work.md`, `quickfix.md`), carries substantial prose
  (project-context reads, workflow-step tables, its own process). The wrapper described
  by the ticket has no precedent to copy verbatim; it is a new, minimal pattern.
- The combination `disable-model-invocation: true` alongside a command that itself
  Skill-invokes an unflagged delegation-target command already exists and is proven to
  work: `quickfix.md` is flagged and has zero inbound delegation edges, yet its body
  explicitly Skill-invokes `tce:ticket`, `tce:plan`, and `tce:implement` — all three
  unflagged delegation targets. TP-0017's Phase 6 end-to-end test exercised exactly this
  shape and found no delegation regression. This is the same shape the new wrapper would
  have (flagged, no inbound edges, one outbound edge to `tce:implement`), which is strong
  precedent that the `disable-model-invocation` half of the wrapper's design is safe.
- TP-0017 never researched, tested, or discussed a command-level `model:` field — its
  scope was strictly the invocation-control flag and agent-level `model:` resolution.
  There is therefore no internal precedent for command-level `model:` behavior.
- Official Claude Code docs **do** document that a skill/command's `model:` frontmatter
  override "applies for the rest of the current turn and is not saved to settings; the
  session model resumes on your next prompt" — this directly confirms the ticket's first
  empirical-verification item (switches model, reverts on next prompt) as documented
  behavior, not merely assumed.
- The ticket's second, load-bearing empirical-verification item — whether that override
  **persists into a Skill-tool-invoked nested command** within the same turn (i.e.,
  whether `tce:implement`, which has no `model:` field of its own, actually executes on
  Sonnet when invoked from inside the wrapper) — is **undocumented in any official
  source**. Web research found no changelog entry, doc passage, or resolved GitHub issue
  that confirms or denies this specific nested-delegation interaction. A related (but
  distinct) GitHub issue shows precedent for a *different* skill-frontmatter field
  (`context: fork` / `agent:`) not reliably propagating through Skill-tool-mediated
  invocation at one point. The ticket's own acceptance criteria already anticipate this
  gap by requiring the behavior be "empirically confirmed in a scratch project, not
  assumed from docs."
- `$ARGUMENTS` as a literal frontmatter/body placeholder token is used in exactly one
  place in the repo today (`review.md`); every other command instead describes "the
  user's input"/"parameters" in prose. The wrapper's "pass arguments through with no
  workflow content of its own" requirement points toward the `$ARGUMENTS` literal-token
  approach, since prose paraphrasing isn't drift-free by construction.
- The exact, repeated phrasing convention for Skill-tool delegation in this repo is:
  `**Invoke the `tce:X` skill** (via the Skill tool) with <args description> as args`,
  usually preceded by a `**CRITICAL: You MUST run the full `/tce:X` process.**` guard
  line (both from `quickfix.md`).
- `CLAUDE.md`'s TP-0017 section (lines 238-260) is the exact passage the ticket's fifth
  acceptance criterion requires updating — it lists delegation targets and user-only
  commands by name and states the re-derivation rule for new delegation edges.
- `plugins/tce/README.md` has no existing "cost" or "model" section; its top-level
  sections run: Contents, See it work, Why context engineering?, Requirements, Install,
  Set up a project, Update, Commands, Agents, How project parameterization works,
  Contributing.

## Detailed Findings

### Command frontmatter conventions (`plugins/tce/commands/`)

12 command files exist. Fields observed across all of them: `description` (every
command), `argument-hint` (present on `implement`, `work`, `quickfix`, `review`,
`design_explore`, `discuss`; absent on `refresh`, `init`, `commit`, `ticket`), `allowed-tools`
(present on `implement`, `research`, `plan`, `work`, `review`), and
`disable-model-invocation: true` (present on exactly the seven "user-only" commands
classified in `CLAUDE.md`'s TP-0017 section). No command file in the repo has ever set a
`model:` field.

Delegation-target commands (never flagged, per TP-0017 — `ticket`, `research`, `plan`,
`implement`, `commit`):

- `plugins/tce/commands/implement.md:1-5` — frontmatter is `description`,
  `argument-hint`, `allowed-tools` only. No `model`, no `disable-model-invocation`.
- `plugins/tce/commands/commit.md:1-3` — frontmatter is `description` only.

User-only commands (flagged, per TP-0017 — `init`, `refresh`, `work`, `quickfix`,
`review`, `discuss`, `design_explore`):

- `plugins/tce/commands/work.md:1-6`:
  ```
  ---
  description: End-to-end workflow for an existing ticket (research → clarify → plan → implement), autonomous except for a single open-questions checkpoint.
  argument-hint: "[ticket-id]"
  disable-model-invocation: true
  allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)
  ---
  ```
- `plugins/tce/commands/quickfix.md:1-5`:
  ```
  ---
  description: Rapidly fix a small, well-understood issue by chaining the full workflow (ticket → research → plan → implement) autonomously, with minimal interruption.
  argument-hint: "[bug or correction to fix]"
  disable-model-invocation: true
  ---
  ```

### Agent frontmatter conventions (`plugins/tce/agents/`) — the only existing `model:` precedent

All seven agent files carry a `model:` field; none carries `disable-model-invocation`
(agents are not Skill-invocable, so the flag is inapplicable — `CLAUDE.md` notes this
explicitly for `plan-compliance-checker`).

- `plugins/tce/agents/codebase-locator.md:1-6` and
  `plugins/tce/agents/thoughts-locator.md:1-6` — `model: haiku` (fast locator-style
  agents).
- `plugins/tce/agents/codebase-analyzer.md:1-6`,
  `plugins/tce/agents/codebase-pattern-finder.md:1-6`,
  `plugins/tce/agents/thoughts-analyzer.md:1-6`,
  `plugins/tce/agents/web-search-researcher.md:1-7`,
  `plugins/tce/agents/plan-compliance-checker.md:1-6` — `model: inherit` (deeper-analysis
  agents).

This confirms `model:` selection is an established pattern in this repo, but only ever
at the **agent** level (resolved via the documented Agent-tool/subagent model-resolution
order — `CLAUDE_CODE_SUBAGENT_MODEL` env var → per-invocation `model` param → agent's own
frontmatter → main-conversation model), never at the **command** level. TP-0017's research
document (`thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md:271-291`)
is where this agent-level resolution order was researched and adopted; it mentions
command-level `model:` only once, as a line item in an enumerated list of supported skill
frontmatter fields, with no further elaboration, testing, or adoption
(`...393-399`).

### No pure-wrapper command precedent exists

Every command in `plugins/tce/commands/` (12 files) and `plugins/tmt/commands/` (4 files)
carries substantial body content — a `## Project context` section, a workflow-position
table, and its own process description. The two closest analogues, `work.md` and
`quickfix.md`, are ~200-260 line composites that *inline-describe* each delegated phase
around the Skill-tool invocation lines; they are not thin pass-through wrappers. The
shape TP-0024 asks for — frontmatter plus a single delegation instruction and nothing
else — has no existing file to model structurally, though the delegation *wording*
convention (below) is well established.

### Skill-tool delegation wording convention

The general convention sentence appears in both composites, verbatim (only the trailing
example differs):

- `plugins/tce/commands/quickfix.md:21`: "When these instructions tell you to invoke
  another workflow command **via the Skill tool**, use its namespaced name (e.g.,
  `tce:plan`). In prose, sibling commands are referenced by their installed, prefixed
  name (e.g., `/tce:plan`)."
- `plugins/tce/commands/work.md:22`: identical sentence, trailing example `/tce:research`.

The concrete per-invocation phrasing, used three times in `quickfix.md` (once per
delegated phase), each preceded by a `**CRITICAL: You MUST run the full `/tce:X`
process.**` guard line:

- `plugins/tce/commands/quickfix.md:109`: "**Invoke the `tce:ticket` skill** (via the
  Skill tool) with `--autonomous` and the fix understanding from Phase 1 as the
  argument…"
- `plugins/tce/commands/quickfix.md:161`: "**Invoke the `tce:plan` skill** (via the
  Skill tool) with the ticket number from Phase 2 as args (e.g., `[PREFIX]-XXXX`)"
- `plugins/tce/commands/quickfix.md:185`: "**Invoke the `tce:implement` skill** (via the
  Skill tool) with the ticket number as args (e.g., `[PREFIX]-XXXX`)"

By contrast, `/tce:commit` (also a delegation target) is always reached through plain
prose ("use the `/tce:commit` command/workflow") rather than the explicit "Invoke the
skill" phrasing — e.g. `plugins/tce/commands/plan.md:441`,
`plugins/tce/commands/research.md:294`, `plugins/tce/commands/implement.md:215`. `CLAUDE.md`
itself notes this distinction: "prose-invokes `/tce:commit` (\"use the `/tce:commit`
command\" resolves to a Skill-tool call at runtime)".

### `$ARGUMENTS` pass-through precedent

Only one command in the repo uses the literal `$ARGUMENTS` token:

- `plugins/tce/commands/review.md:63`: "When this command is invoked, you receive user
  input in `$ARGUMENTS`."
- `plugins/tce/commands/review.md:69`: "Parse `$ARGUMENTS` to determine:" (followed by a
  detection-logic block).

Every other command instead describes an `## Initial Response`/setup step in prose
("Check if parameters were provided", "the user's input") without the literal token —
e.g. `plugins/tce/commands/plan.md:139-164`, `plugins/tce/commands/ticket.md:70-72`. Since
the wrapper's entire purpose is verbatim argument pass-through with "no workflow content
of its own," the literal `$ARGUMENTS` token (rather than a prose paraphrase that could
silently diverge from what the caller actually passed) is the pattern already present in
the codebase for this exact need.

### No existing frontmatter combines `model:` and `disable-model-invocation:`

Confirmed by direct search: `disable-model-invocation: true` appears only in command
frontmatter, `model:` appears only in agent frontmatter, and the two keys never co-occur
in any file in the repo today. There is no evidence of a documented or observed conflict
between them — they govern different concerns (which model executes the turn vs.
whether the model can spontaneously invoke the skill) — but the wrapper would be the
first file in the repo to combine them.

### TP-0017's invocation-control classification and its bearing on the wrapper

`CLAUDE.md:238-260` ("Invocation control: `disable-model-invocation` must respect the
delegation graph (TP-0017)") states the rule the ticket's fifth acceptance criterion
requires updating: delegation targets (`ticket`, `research`, `plan`, `implement`,
`commit`) must never carry the flag; user-only commands with no inbound delegation edge
(`init`, `refresh`, `work`, `quickfix`, `review`, `discuss`, `design_explore`) carry it
deliberately. The rule instructs: "When adding a command or a new delegation edge... re-
derive this classification."

TP-0017's own research (`thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md:167-177`)
establishes that the eligibility test for the flag is **inbound-edge-only** — whether
anything delegates *into* the command — not whether the command itself delegates out.
The new wrapper has zero inbound delegation edges (nothing in the repo would reference
it) and exactly one outbound edge (to `tce:implement`). This is structurally identical to
`quickfix.md`, which is flagged and outbound-delegates to three unflagged targets
(`tce:ticket`, `tce:plan`, `tce:implement`) — and TP-0017's Phase 6 end-to-end test
(`thoughts/shared/plans/2026-07-04-TP-0017-adopt-frontmatter-machinery.md:441-449`,
status lines 169-181) exercised `/tce:quickfix` fully, confirming "no delegation
regression" from that combination. This is direct, already-verified precedent that a
flagged, outbound-only-delegating command works — the wrapper's `disable-model-invocation`
half of the design fits an already-proven pattern, not a new risk.

TP-0017's research also flags one open caveat that does not apply here: "no doc passage
addresses the exact scenario 'command A's prompt instructs invoking hidden command B'"
(research lines 203-208) — but that caveat concerns a flagged command being the
**target** of delegation (B hidden), not the **source** (A hidden, B visible), which is
the wrapper's actual shape and is exactly what `quickfix.md` already demonstrates
working.

### Documented `model:` frontmatter semantics (official Claude Code docs)

The Skills frontmatter reference (custom commands and skills are now the same mechanism
— "Custom commands have been merged into skills... Files in `.claude/commands/` still
work and support the same frontmatter") documents the `model` field:

> `model` — No — Model to use when this skill is active. The override applies for the
> rest of the current turn and is not saved to settings; the session model resumes on
> your next prompt. Accepts the same values as `/model`, or `inherit` to keep the active
> model. A value excluded by your organization's `availableModels` allowlist is not used
> and the session keeps its current model.

(Source: https://code.claude.com/docs/en/skills, "Frontmatter reference")

This directly confirms the ticket's "Questions for Research/Planning" item "a user-
invoked command with `model: sonnet` frontmatter switches the turn's model and reverts on
the next prompt" as documented behavior. Corroborating wording from the model-config
docs' fallback-chain section: "The switch lasts for the current turn only, so your next
message tries the primary model first again" (https://code.claude.com/docs/en/model-config).
Claude Code's own definition of "turn" (Interactive Mode docs) is the full interaction
cycle for one user message, including however many internal tool calls occur before the
final reply — not a single model generation step.

### Undocumented: whether the override propagates into a Skill-tool-nested delegation

This is the ticket's single highest-risk open item and remains **unresolved by
documentation**. No official doc passage, changelog entry, or resolved GitHub issue
states whether a wrapper's `model: sonnet` override is inherited by `tce:implement` when
the wrapper Skill-invokes it mid-turn. The literal "current turn" scoping of the
`model:` field is suggestive (a Skill-tool call happens within the same turn as the
command that issued it), but this is an inference across two separate doc passages, not
an explicit statement.

Two data points from GitHub issue search bear on this, neither conclusive:

- Issue #23462 ("Feature: Model selection in skill frontmatter") — the original feature
  request — is open with no maintainer comments and no linked implementation discussion.
- Issue #17283 ("Skill tool should honor `context: fork` and `agent:` frontmatter
  fields") documents a **different** skill-frontmatter field (`context`/`agent`, which
  governs subagent forking) at one point being ignored when a skill was invoked via the
  Skill tool rather than by the user directly — i.e., a precedent exists in this exact
  system for a frontmatter field *not* reliably propagating through Skill-tool-mediated
  invocation. Current docs describe `context: fork` as working, suggesting this was
  fixed, but no changelog entry pinpoints when/how, and this issue concerns a different
  field than `model:`.

No source addresses precedence if the delegated skill had its own `model:` field (moot
here, since `tce:implement` has none), nor whether an org `availableModels` allowlist
interacts differently across a delegation boundary.

**This is precisely the gap the ticket's acceptance criteria already anticipate** by
requiring the behavior be "empirically confirmed in a scratch project, not assumed from
docs," and the ticket's "Questions for Research/Planning" section states the explicit
fallback if it does not hold (hardcode `model:` on `implement.md`, or a per-phase
implementer agent) and instructs returning the ticket for re-scoping if so. Research and
web search cannot resolve this further — it requires a live, out-of-session empirical
test (starting from a non-Sonnet session model, invoking the wrapper, and observing
whether `tce:implement`'s execution actually runs on Sonnet) that only a real Claude Code
session with the finished wrapper file can perform.

### `opusplan` and cost-guidance context (background for the README section)

Official docs confirm the "big model plans, Sonnet implements" pattern exists as a
built-in alias, cited by the ticket's Problem Statement:

> `opusplan` — Special mode that uses `opus` during plan mode, then switches to `sonnet`
> for execution... This pairs Opus's reasoning for planning with Sonnet's efficiency for
> execution.

(https://code.claude.com/docs/en/model-config, "`opusplan` model setting")

And the cost-guidance doc's exact phrasing echoed in the ticket:

> Sonnet handles most coding tasks well and costs less than Opus. Reserve Opus for
> complex architectural decisions or multi-step reasoning. Use `/model` to switch models
> mid-session, or set a default in `/config`.

(https://code.claude.com/docs/en/costs, "Choose the right model")

Neither doc cross-references a wrapper-command pattern or per-command `model:` override
as an alternative to `opusplan` — the ticket's approach (a dedicated opt-in command) is
not an officially documented pattern, it is a novel application of the general `model:`
frontmatter mechanism to this specific tce workflow shape.

## Code References

- `plugins/tce/commands/implement.md:1-5` - delegation-target frontmatter (no `model`,
  no `disable-model-invocation`)
- `plugins/tce/commands/work.md:1-6` - user-only composite frontmatter, with
  `disable-model-invocation: true`
- `plugins/tce/commands/quickfix.md:1-5,21,108-109,159-161,183-185` - user-only composite
  frontmatter and its three explicit Skill-tool delegation instructions with guard lines
- `plugins/tce/commands/commit.md:1-3` - minimal delegation-target frontmatter,
  prose-invoked elsewhere
- `plugins/tce/commands/review.md:63,69` - the repo's only literal `$ARGUMENTS` usage
- `plugins/tce/agents/codebase-locator.md:1-6` - `model: haiku` agent precedent
- `plugins/tce/agents/codebase-analyzer.md:1-6` - `model: inherit` agent precedent
- `CLAUDE.md:238-260` - TP-0017 invocation-control classification section (delegation
  targets vs. user-only commands, re-derivation rule)
- `plugins/tce/README.md` - top-level section list (Contents, See it work, Why context
  engineering?, Requirements, Install, Set up a project, Update, Commands, Agents, How
  project parameterization works, Contributing) — no existing cost/model section
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md:52-62,167-177,203-208,271-291,393-399`
  - disable-model-invocation mechanism, inbound-edge eligibility test, the "hidden
    command as delegation target" caveat (does not apply to the wrapper's shape), agent
    `model:` resolution order, command-level `model:` mentioned once and never adopted
- `thoughts/shared/plans/2026-07-04-TP-0017-adopt-frontmatter-machinery.md:441-449` and
  its `.status.md:169-181` - Phase 6 end-to-end verification of `/tce:quickfix`'s
  flagged/outbound-delegating shape, "no delegation regression"

## Architecture Documentation

- **Frontmatter fields are cleanly partitioned by artifact type today**: commands use
  `description`, `argument-hint`, `disable-model-invocation`, `allowed-tools`; agents use
  `name`, `description`, `tools`, `model` (and `color` on one). The wrapper would be the
  first command to cross that partition by adding `model:` to a command file — consistent
  with the frontmatter reference's documented field list (which shows `model` as a valid
  field for both skills and commands, since they're the same mechanism), but a first for
  this specific repo's commands.
- **Two distinct delegation-phrasing registers exist**: an explicit "Invoke the `tce:X`
  skill (via the Skill tool)" imperative (used for `ticket`/`plan`/`implement` inside
  `quickfix.md`) vs. plain prose ("use the `/tce:commit` command") for `commit`. Both
  resolve to a Skill-tool call at runtime per `CLAUDE.md`'s own note; the explicit-
  imperative register is what a minimal wrapper would naturally use, since it has no
  surrounding workflow prose to soften the instruction into.
- **The invocation-control classification (TP-0017) is a live, re-derived contract**,
  not a static list — `CLAUDE.md` explicitly requires re-deriving it whenever a new
  command or delegation edge is added, which is exactly TP-0024's fifth acceptance
  criterion.

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0017-adopt-frontmatter-machinery.md` - established the
  disable-model-invocation classification and the agent-level `model:` precedent
  (locators on haiku) that TP-0024 explicitly cites as its precedent in the References
  section.
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` - the
  fullest existing treatment of command/skill frontmatter semantics in this repo;
  establishes the inbound-edge-only eligibility test for `disable-model-invocation` and
  is the source of the agent `model:` resolution order.
- `thoughts/shared/plans/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` and its
  `.status.md` - record the empirical end-to-end verification methodology TP-0017 used
  (treating undocumented Claude Code behavior as unverified until tested in a real
  session), which is the same methodology TP-0024's acceptance criteria call for.

## Related Research

- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` (see
  above — directly established the classification machinery TP-0024 extends)

## Open Questions

- **Whether the wrapper's `model: sonnet` override actually persists into the
  Skill-invoked `tce:implement` execution.** Undocumented in any official source (see
  "Undocumented" finding above); the ticket's own acceptance criteria require this be
  empirically confirmed in a scratch project before the wrapper can be considered
  complete, with an explicit fallback path (hardcode on `implement.md`, or a per-phase
  implementer agent) if it does not hold. This cannot be resolved by further documentary
  research — it requires live testing with the finished wrapper file, starting from a
  non-Sonnet session model.
- **The wrapper's name** — explicitly deferred by the ticket itself to the question
  checkpoint (not a research question); "eco" is a placeholder, with `implement_eco`,
  `implement_sonnet`, `eco_implement`, or a model-name-free alternative as candidates.
