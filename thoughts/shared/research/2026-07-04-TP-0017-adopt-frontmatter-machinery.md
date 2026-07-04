---
date: 2026-07-04T09:01:24Z
git_commit: ddd104b5cf980069465460bcde85d3a72cde16e4
branch: main
repository: toby-plugins
topic: "TP-0017: Adopt command/agent frontmatter machinery (invocation control, tool pre-approval, agent models)"
tags: [research, codebase, frontmatter, skills, permissions, agents, tce, quickfix, work]
status: complete
last_updated: 2026-07-04
---

# Research: TP-0017 — Adopt command/agent frontmatter machinery

**Date**: 2026-07-04T09:01:24Z
**Git Commit**: ddd104b5cf980069465460bcde85d3a72cde16e4
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0017 asks tce to adopt the newer command/agent frontmatter levers
(`disable-model-invocation`, `allowed-tools`, agent `model`, and possibly
`` !`cmd` `` dynamic context injection) where they help, under one hard
constraint: the composites (`/tce:work`, `/tce:quickfix`) delegate to sibling
commands via the Skill tool, so invocation control must respect the delegation
graph. The ticket poses four research questions:

1. Map the delegation graph precisely — which commands are invoked via the
   Skill tool by `work.md` and `quickfix.md` (including `/tce:commit`)?
2. Does `disable-model-invocation` also suppress Skill-tool invocation, or only
   spontaneous model triggering?
3. What is the exact `allowed-tools` syntax for pre-approving a
   `${CLAUDE_PLUGIN_ROOT}`-relative script, and does substitution happen before
   permission matching?
4. Which model should the locators target, and how to spot-check quality parity
   cheaply?

## Summary

1. **Delegation graph**: Only `quickfix.md` invokes siblings explicitly "via
   the Skill tool" — three sites: `tce:ticket` (autonomous mode), `tce:plan`,
   `tce:implement`. `work.md` declares the Skill-tool phrasing convention but
   never uses it: it *inlines* the research/plan/implement phases while
   repeatedly deferring to the single-step commands' full specs ("Follow all
   research steps from `/tce:research`", "exactly as `/tce:implement`
   specifies"), and it references `/tce:commit` in prose four times ("use the
   `/tce:commit` command"). The single-step commands (`research`, `plan`,
   `implement`) also instruct "use the `/tce:commit` command" in prose. At
   runtime a prose instruction to "use the `/tce:commit` command" can only be
   executed by invoking the skill through the Skill tool — so prose references
   are operationally Skill-tool dependencies too.
2. **`disable-model-invocation` blocks Skill-tool invocation, full stop.** Per
   current docs it removes the skill's description from Claude's context
   entirely and makes it non-invocable by the model ("Only you can invoke the
   skill" / "Claude can invoke: No" / "block programmatic invocation"). No
   documented carve-out exists for prompt-instructed delegation. The constraint
   in the ticket therefore **binds**: commands the composites delegate to or
   defer to — `ticket`, `research`, `plan`, `implement`, `commit` — must NOT
   get `disable-model-invocation: true`. Notably, the originating review's
   suggested set ("`init`, `implement`, `quickfix`, `commit`") violates this:
   `implement` is Skill-invoked by quickfix and `commit` is prose-delegated
   from five commands.
3. **`allowed-tools` grants permission (no prompt) while the skill is active**
   and uses the same rule grammar as settings (`Bash(cmd:*)` ≡ `Bash(cmd *)`).
   It is documented to work in command files (commands are skills). But
   **`${CLAUDE_PLUGIN_ROOT}` substitution inside frontmatter is undocumented**
   — only `${CLAUDE_PROJECT_DIR}` is explicitly granted frontmatter
   substitution (v2.1.196+). The documented plugin-native alternative is the
   plugin `bin/` directory (executables added to Bash's PATH, invokable as
   bare commands → a stable literal rule like `Bash(ticket.sh *)`). Empirical
   verification is required either way (the docs gap, plus community-reported
   enforcement bugs).
4. **Locators → `haiku`.** Plugin agents officially support `model` with
   aliases (`haiku`/`sonnet`/`opus`/`fable`), full IDs, or `inherit` (the
   default). `haiku` currently resolves to Haiku 4.5, and the docs explicitly
   recommend Haiku-class models for exploration/search-type subagents. All six
   tce agents currently pin `model: inherit`; the two pure find-and-categorize
   agents (`codebase-locator`, `thoughts-locator`) are the candidates.
   Parity spot-check: run an identical locator prompt against this repo on
   both models and compare coverage of a known file set.
5. **`` !`cmd` `` injection works in plugin commands** (the
   `disableSkillShellExecution` setting explicitly names plugin sources), but
   it is preprocessing: it runs once, before Claude sees the prompt. The
   ticket.sh preamble needs the *canonical* ticket ID, which the commands
   normalize in-model first (bare `42` → `TP-0042`, via the project's
   `tickets.md` adapter) — injection cannot perform that normalization, and
   `/tce:research` also accepts non-ticket free-form questions where running
   ticket.sh makes no sense. Grounds for explicit rejection exist (the ticket's
   acceptance criterion allows "rejected with a note").

## Detailed Findings

### 1. Current frontmatter inventory (what exists today)

Every command file carries only `description` (plus `argument-hint` where the
command takes arguments) — no file uses `disable-model-invocation`,
`allowed-tools`, `model`, or any other lever:

- tce: `ticket.md`, `research.md`, `plan.md`, `implement.md`, `review.md`,
  `work.md`, `quickfix.md`, `discuss.md`, `design_explore.md` (all
  `description` + `argument-hint`); `commit.md`, `init.md`, `refresh.md`
  (`description` only). All at lines 1–4 of each file under
  `plugins/tce/commands/`.
- tmt: `create.md`, `update.md` (`description` + `argument-hint`); `init.md`,
  `list.md` (`description` only), under `plugins/tmt/commands/`.

All six agents in `plugins/tce/agents/` set `model: inherit` explicitly
(frontmatter lines 2–5 in each; `web-search-researcher.md` additionally has
`color: yellow` at line 5) and a `tools` allowlist:

| Agent | tools | model |
|---|---|---|
| `codebase-locator` | LSP, Grep, Glob, LS | inherit |
| `codebase-analyzer` | LSP, Read, Grep, Glob, LS | inherit |
| `codebase-pattern-finder` | LSP, Grep, Glob, Read, LS | inherit |
| `thoughts-locator` | Grep, Glob, LS | inherit |
| `thoughts-analyzer` | Read, Grep, Glob, LS | inherit |
| `web-search-researcher` | WebSearch, WebFetch, TodoWrite, Read, Grep, Glob, LS | inherit |

### 2. The delegation graph (ticket question 1)

**Explicit Skill-tool invocations exist only in `quickfix.md`** — exactly
three:

- `plugins/tce/commands/quickfix.md:108` → `tce:ticket`: "**Invoke the
  `tce:ticket` skill** (via the Skill tool) with `--autonomous` …"
- `plugins/tce/commands/quickfix.md:160` → `tce:plan`: "**Invoke the
  `tce:plan` skill** (via the Skill tool) with the ticket number …"
- `plugins/tce/commands/quickfix.md:184` → `tce:implement`: "**Invoke the
  `tce:implement` skill** (via the Skill tool) …"

**`work.md` uses no explicit Skill-tool invocation** despite carrying the same
phrasing-convention bullet at `work.md:20` (byte-similar to `quickfix.md:20`).
It inlines the phases but defers to the single-step specs:

- `work.md:65` — "Execute the full research workflow as defined in
  `/tce:research`" (plus "Follow all research steps from `/tce:research`" and
  "Follow ALL quality guidelines from `/tce:research`")
- `work.md:189` — "Follow the plan creation process from `/tce:plan` Step 3
  … and Step 4"
- `work.md:218` — "Execute the implementation plan exactly as
  `/tce:implement` specifies"

For the model to *follow* those specs at runtime it must be able to load them,
which happens through the Skill tool — so these deferrals are soft Skill-tool
dependencies on `research`, `plan`, and `implement` even without "Invoke the
… skill" phrasing.

**`/tce:commit` is prose-delegated everywhere, never "via the Skill tool":**

- `work.md:95`, `work.md:204`, `work.md:236`, `work.md:262` — "use the
  `/tce:commit` command / workflow"
- `quickfix.md:117`, `:147`, `:171`, `:241` — "using the `/tce:commit`
  workflow"
- `research.md:281`, `research.md:291` — "use the `/tce:commit` command"
- `plan.md:440` — "use the `/tce:commit` command"
- `implement.md:229` — "For each commit, use the `/tce:commit` workflow"
- Advisory-only (suggest to user, not invoke): `init.md:439`, `refresh.md:155`

**`ticket.md` invokes no sibling** (it is quickfix's callee; in autonomous
mode `ticket.md:288` defers the commit to the caller). **No tmt command
invokes any sibling via the Skill tool**; `/tce:ticket` writes ticket files
through the project's `tickets.md` adapter directly, not via `/tmt:create`,
and tce transitions statuses by editing the `**Status:**` line, not via
`/tmt:update` — so no cross-plugin or tmt-internal delegation exists.

**Resulting classification (facts, not decision):**

- **Must stay model-invocable** (delegated to, explicitly or in prose):
  `tce:ticket`, `tce:research`, `tce:plan`, `tce:implement`, `tce:commit`.
- **No inbound delegation — eligible for `disable-model-invocation: true`**:
  `tce:init`, `tce:refresh`, `tce:work`, `tce:quickfix`, `tce:review`,
  `tce:discuss`, `tce:design_explore`. (`design_explore` is referenced by
  `plan.md`/`work.md` only as something *the user* runs — "you run
  `/tce:design_explore`" — user invocation is unaffected by the flag.) All
  four tmt commands also have no inbound delegation, but the ticket's
  acceptance criteria scope classification to *tce* commands.

### 3. `disable-model-invocation` semantics (ticket question 2)

Per the current skills doc (https://code.claude.com/docs/en/skills — the page
now served for `/en/slash-commands`; "Custom commands have been merged into
skills", and plugin `commands/*.md` files "support the same frontmatter"):

> "Set to `true` to prevent Claude from automatically loading this skill. …
> Also prevents the skill from being preloaded into subagents."

> "**`disable-model-invocation: true`**: Only you can invoke the skill. Use
> this for workflows with side effects or that you want to control timing,
> like `/commit`, `/deploy`, or `/send-slack-message`."

Invocation table: user can invoke — Yes; **Claude can invoke — No**;
"Description not in context, full skill loads when you invoke". And: "The
`user-invocable` field only controls menu visibility, not Skill tool access.
Use `disable-model-invocation: true` to **block programmatic invocation**."

So the answer to the ticket's question is: **it suppresses Skill-tool
invocation entirely, not just spontaneous triggering** — with a double effect
(description removed from the model-facing listing + invocation blocked).
Anthropic's own plugin-dev reference states it as "Not available to
SlashCommand tool" (the Skill tool's former name).

**Caveat**: no doc passage addresses the exact scenario "command A's prompt
instructs invoking hidden command B", nor the failure mode of such an attempt
(graceful error vs. untargetable). The conclusion is inferred from categorical
wording. The ticket's scratch-project verification of `/tce:work` and
`/tce:quickfix` end-to-end (acceptance criterion 1) is the right empirical
backstop.

Side benefit relevant to the review's rationale: descriptions of disabled
commands leave the always-on skill listing (the listing has a character budget
— 1% of context window), so disabling the seven eligible commands shrinks
every session's baseline context in consuming projects.

### 4. `allowed-tools` for ticket.sh (ticket question 3)

**Semantics** (skills doc): "The `allowed-tools` field grants permission for
the listed tools while the skill is active, so Claude can use them without
prompting you for approval. It does not restrict which tools are available."
Accepts a space-/comma-separated string or YAML list; same rule grammar as
settings permissions, e.g. `allowed-tools: Bash(git add *) Bash(git commit *)`;
`Bash(ls:*)` ≡ `Bash(ls *)` (documented equivalence).

**The substitution question — partially open.** Documented:
`${CLAUDE_PROJECT_DIR}` "applies to both the skill body and the
[`allowed-tools`] frontmatter" (v2.1.196+), i.e. substitution does happen
before permission matching *for that variable*. **Not documented**:
`${CLAUDE_PLUGIN_ROOT}` in frontmatter. The plugins reference says plugin
variables are "substituted inline anywhere they appear in skill content, agent
content, hook commands, …" — whether "skill content" covers frontmatter is
unstated. (The TP-0016 research independently recorded the same gap.)

**Documented plugin-native alternative — `bin/`:** the plugins-reference file
locations table: "**Executables** — `bin/` — Executables added to the Bash
tool's `PATH`. Files here are invokable as bare commands in any Bash tool call
while the plugin is enabled." Moving/renaming the discovery script to
`plugins/tce/bin/` would make a stable literal rule possible (e.g.
`allowed-tools: Bash(tce-tickets *)`), with two knock-on considerations: a
PATH-safe (collision-unlikely) name is prudent, and all call sites plus
`allowed-tools` must change together. Note the `scripts/ticket.sh` filename
that appears in `init.md:127,180,398` is the *legacy claude-template project
file* to delete during migration — a frozen historical name unrelated to the
plugin's own script, so renaming the plugin script does not touch the
migration lists.

**Call sites needing the grant** (6 run-instructions across 5 commands):

- `plugins/tce/commands/research.md:84` and `:94` (main + parent-epic lookup)
- `plugins/tce/commands/plan.md:68`
- `plugins/tce/commands/implement.md:48` (plus the `:61` restatement)
- `plugins/tce/commands/review.md:116`
- `plugins/tce/commands/work.md:72`

`quickfix.md` never calls ticket.sh itself; it inherits the plan/implement
call sites by Skill-delegating to `tce:plan`/`tce:implement` (whose
`allowed-tools` would be active while those skills run).

**Reliability caveat**: open claude-code issues report `allowed-tools`
enforcement gaps for Bash rules in skills (#14956, #18837) — a scratch-project
test (acceptance criterion 2) is required regardless of which path is chosen.

**Other Bash the commands run** (candidates for the same grant mechanism,
for completeness): read-only git metadata (`git rev-parse HEAD`, `git branch
--show-current`, `git config --get remote.origin.url`, `git log`), `date`,
`grep -rl`/`ls` over `thoughts/shared/mockups/`, and tmt's three scripts
(`next-ticket.sh` at `tmt/create.md:50`, `valid-statuses.sh` at
`tmt/update.md:57`, `open_tickets.sh` at `tmt/list.md:10`). Git/date reads are
commonly auto-allowed by Claude Code defaults; the ticket's acceptance
criteria name only ticket.sh.

### 5. Agent `model` choices (ticket question 4)

From the sub-agents doc frontmatter table: `model` accepts "`sonnet`, `opus`,
`haiku`, `fable`, a full model ID …, or `inherit`. Defaults to `inherit`".
Plugin agents explicitly support `model` (plugins reference: "Plugin agents
support `name`, `description`, `model`, `effort`, `maxTurns`, `tools`,
`disallowedTools`, `skills`, `memory`, `background`, and `isolation`").
Resolution precedence: `CLAUDE_CODE_SUBAGENT_MODEL` env var → per-invocation
`model` param → frontmatter → main-conversation model; and if an org
`availableModels` policy blocks the frontmatter model, it "falls back to the
inherited or default model rather than failing the request" — so `model:
haiku` degrades gracefully, never errors.

The docs' own cost guidance matches the review's suggestion: subagents help
"**Control costs** by routing tasks to faster, cheaper models like Haiku", and
the built-in Explore override example uses `model: haiku` "to keep exploration
on a lower-cost model". `haiku` currently resolves to Claude Haiku 4.5
(`claude-haiku-4-5`, the newest Haiku per the platform models overview; the
Claude Code model-config page names versions only for `opus`/`sonnet` —
minor doc gap). The alias (not a pinned ID) tracks future Haiku releases
automatically.

Candidates: `codebase-locator.md` and `thoughts-locator.md` — both are pure
find-and-categorize (tools: Grep/Glob/LS(+LSP), no Read, no analysis duties;
their Output Format is a categorized file listing). The analyzers,
pattern-finder, and web-search-researcher synthesize/read content and are not
in scope of the review's recommendation.

**Parity spot-check (cheap)**: pick 2–3 known research questions against this
repo (e.g. "where do ticket-status hooks live", "find everything referencing
ticket.sh"), run each locator prompt once with `model: inherit` and once with
`model: haiku` (per-invocation `model` parameter on the Agent tool makes this
possible without editing files twice), and diff the returned file sets against
the known-correct locations. Locator output is a file list — parity is
objectively checkable, unlike analyzer prose.

Also documented and relevant: `color` is *not* in the plugin-supported field
list (only `hooks`/`mcpServers`/`permissionMode` are explicitly called
"ignored", but the supported list is presented as exhaustive) — so
`web-search-researcher.md`'s `color: yellow` is likely inert. A subagent also
can never use `AskUserQuestion` — unrelated to this ticket but worth knowing
when editing agent prompts.

### 6. Dynamic context injection (`` !`cmd` ``)

Documented on the skills page ("Inject dynamic context"): `` !`<command>` ``
"runs shell commands before the skill content is sent to Claude. The command
output replaces the placeholder … This is preprocessing, not something Claude
executes." Constraints: substitution runs once; inline form only recognized at
line start or after whitespace; multi-line via ```` ```! ```` blocks; `shell`
frontmatter field selects bash/powershell. It works for plugin commands — the
opt-out setting `disableSkillShellExecution` explicitly covers "user, project,
plugin, or additional-directory sources". `${CLAUDE_PLUGIN_ROOT}` inside the
injected command text is covered by "substituted inline anywhere … in skill
content" (body, not frontmatter — same reading as TP-0016's research).

**Why it fits the ticket.sh preamble poorly** (facts for the
adopt-or-reject decision):

1. ticket.sh takes the **canonical** ticket ID as its argument, but the
   commands normalize user input in-model first (`42`/`tp-42`/`TP-42` →
   `TP-0042`, per the project `tickets.md` adapter — `research.md` step 1,
   `work.md` Phase 1a). Preprocessing runs before any model reasoning, so an
   injected `` !`ticket.sh $ARGUMENTS` `` would receive the *raw* argument.
   Whether `$ARGUMENTS` is even substituted before injection runs is not
   stated in the docs.
2. `/tce:research` also accepts free-form research questions with no ticket at
   all (`argument-hint: "[ticket-id | research question]"`) — an unconditional
   injection would run ticket.sh on a non-ID.
3. Injection output lands at the top of the command prompt once; the
   parent-epic lookup (`research.md:94`) is conditional on what the first
   lookup finds — not expressible as static preprocessing.
4. Undocumented: whether `` !`cmd` `` requires a matching `allowed-tools` Bash
   rule (the pre-merge docs required it; current docs are silent but their
   example still pairs them), and any output size limit.

### 7. Provenance and reliability of the originating review finding

The review (`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`,
Section 2 finding 4, lines 168–176) recommends the four adoptions but **cites
no specific doc pages for them and verified none of the mechanisms in a
plugin context** — its factual claims about tce's current state (no
`disable-model-invocation`, no `allowed-tools`, all agents `inherit`) are
file-level observations at commit 5c622ef and were re-confirmed by this
research; its mechanism claims were doc-recollections that this research has
now independently verified (and in one case corrected: its proposed
disable-set of "`init`, `implement`, `quickfix`, `commit`" would break
quickfix's `tce:implement` delegation and all prose `commit` delegation).
Two adjacent review items are explicitly out of TP-0017's scope per the
ticket: `context: fork` for research (finding 2.3) and subagent output caps
(finding 2.5, folded into the review's priority list but ticketed elsewhere).

## Code References

- `plugins/tce/commands/quickfix.md:108,160,184` — the three explicit
  Skill-tool invocations (`tce:ticket`, `tce:plan`, `tce:implement`)
- `plugins/tce/commands/work.md:20,65,95,122,189,204,218,236,262` —
  Skill-phrasing convention; inline deferrals to research/plan/implement;
  prose `/tce:commit` references; DECISION.md grep
- `plugins/tce/commands/research.md:84,94,281,291` — ticket.sh call sites;
  prose `/tce:commit` references
- `plugins/tce/commands/plan.md:68,440` — ticket.sh call site; `/tce:commit`
- `plugins/tce/commands/implement.md:48,61,229` — ticket.sh call sites;
  `/tce:commit` workflow reference
- `plugins/tce/commands/review.md:116` — ticket.sh call site
- `plugins/tce/commands/ticket.md:177-180,276-291` — commit handled via
  adapter / deferred to caller in autonomous mode
- `plugins/tce/agents/codebase-locator.md:2-5`,
  `plugins/tce/agents/thoughts-locator.md:2-5` — the two `model: inherit` →
  `haiku` candidates (tools: Grep/Glob/LS(+LSP) only)
- `plugins/tce/agents/web-search-researcher.md:5` — `color: yellow` (likely
  inert for plugin agents)
- `plugins/tce/commands/init.md:127,180,398` — legacy-template
  `scripts/ticket.sh` deletions (frozen names, unrelated to the plugin script)
- `plugins/tce/hooks/hooks.json:3-13`, `plugins/tmt/hooks/hooks.json:3-22` —
  hooks reference only `check-init.sh` / ticket-status scripts; no interaction
  with the frontmatter levers
- `plugins/tmt/commands/create.md:50`, `plugins/tmt/commands/update.md:57`,
  `plugins/tmt/commands/list.md:10` — tmt script call sites (same permission
  mechanics, outside the ticket's acceptance criteria)

## Architecture Documentation

- **Commands are skills.** The former slash-commands doc now redirects to the
  skills page; plugin `commands/*.md` are "skills as flat Markdown files" and
  support the full skill frontmatter menu: `name`, `description`,
  `when_to_use`, `argument-hint`, `arguments`, `disable-model-invocation`,
  `user-invocable`, `allowed-tools`, `disallowed-tools`, `model`, `effort`,
  `context: fork` + `agent`, `hooks`, `paths`, `shell`.
- **Two distinct hiding levers**: `user-invocable: false` (hide from the `/`
  menu, model can still invoke) vs `disable-model-invocation: true` (model
  blocked + description out of context, user can still invoke). tce's
  composites need the latter applied only to non-delegated commands.
- **Permission layering**: agent `tools` field = availability allowlist (no
  permission grant); command `allowed-tools` = permission grant (no
  availability restriction); settings `permissions.allow` = session-wide.
  A `Skill(name)` permission rule is the non-frontmatter way to gate specific
  skill invocation without hiding it — the documented fallback if a delegated
  command ever needs user-side control.
- **Plugin-agent frontmatter subset**: `name`, `description`, `model`,
  `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`,
  `background`, `isolation` — `hooks`/`mcpServers`/`permissionMode` ignored
  for security; plugin agents load at lowest precedence and require
  `/reload-plugins` (not live-watched).
- **Skill listing budget**: all skill names always listed; descriptions
  truncated to a budget of 1% of the context window — `disable-model-invocation`
  removes an entry entirely, which is the context-hygiene rationale.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` —
  Section 2 finding 4 spawned TP-0017 (see Detailed Finding 7 for its
  reliability assessment); finding 2.3 (`context: fork`) and 2.5 (output
  caps) are adjacent but out of scope here.
- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md`
  — lines 48–54: independently recorded that `allowed-tools` grants without
  prompting, that `${CLAUDE_PLUGIN_ROOT}` inside `allowed-tools` values or
  `` !`cmd` `` injections is undocumented, and deferred all frontmatter
  adoption to TP-0017. Line 144: confirmed the frontmatter inventory.
- `thoughts/shared/plans/2026-07-03-TP-0015-fix-review-prompt-defects.md` —
  lines 95–96: explicitly excluded frontmatter adoption as TP-0017's scope.
- `thoughts/shared/tickets/TP-0016-shrink-command-prompts-reference-files.md`
  — established the `references/` runtime-read convention TP-0017 must not
  disturb (reference files are read via `${CLAUDE_PLUGIN_ROOT}/references/…`
  Bash-independent Read calls — no permission interaction).

## Related Research

- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md`
  — closest overlap (skills-doc findings, compaction behavior, sync surface)
- `thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md`
  — review-defect fixes touching the same command files
- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md`
  — the composite delegation architecture (work inlines, quickfix delegates)
  this ticket's constraint rests on

## Open Questions

1. **Classification sign-off**: research establishes which commands *can*
   take `disable-model-invocation: true` (`init`, `refresh`, `work`,
   `quickfix`, `review`, `discuss`, `design_explore`) — but whether to apply
   it to all seven or a subset (e.g. leave `review`/`discuss` model-invocable
   for conversational use) is a judgment call.
2. **ticket.sh pre-approval mechanism**: try
   `allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh:*)` (matches
   current call sites; substitution in frontmatter undocumented — needs an
   empirical test) vs. move the script to `plugins/tce/bin/` under a
   collision-safe name (documented mechanism; touches 6 call sites + docs).
3. **tmt commands**: formally outside the acceptance criteria — apply the same
   classification/pre-approval treatment to tmt in this ticket, or leave for a
   follow-up?
4. **`` !`cmd` `` injection**: the facts point to rejection (normalization
   happens in-model; research accepts non-ticket arguments) — confirm and
   record the rejection note per acceptance criterion 4.
5. Whether `$ARGUMENTS` substitutes before `` !`cmd` `` preprocessing runs is
   undocumented — only relevant if injection is adopted despite point 4.
