---
date: 2026-08-19T15:50:17Z
git_commit: 0ae89dc4f769c4a65e39c7c2983f12bcac31fe48
branch: main
repository: toby-plugins
topic: "TP-0025 — tle plugin: loop-engineering workflow (goal definition + convergence loop)"
tags: [research, codebase, plugins, tle, agents, commands, goal, compaction, mcp]
status: complete
last_updated: 2026-08-19
---

# Research: TP-0025 — tle plugin (loop-engineering workflow)

**Date**: 2026-08-19T15:50:17Z
**Git Commit**: 0ae89dc4f769c4a65e39c7c2983f12bcac31fe48
**Branch**: main
**Repository**: toby-plugins

## Research Question

What does building `tle` — a third marketplace plugin implementing a goal-definition
command, an internally-looping convergence runner, and three subagents with file-only
handoffs — require, given (a) this repo's existing plugin/command/agent conventions and
governance rules, and (b) the Claude Code platform mechanics the design depends on
(`/goal`, subagent tool inheritance and MCP, command frontmatter, compaction)?

The ticket's five "Questions for Research/Planning" are answered under
[Open Questions](#open-questions).

## Summary

**The repo side is well-trodden and low-risk.** Adding a third plugin is a documented,
purely additive operation: a `plugins/tle/` directory with its own
`.claude-plugin/plugin.json`, one entry in `.claude-plugin/marketplace.json`, and doc
updates in four places that currently hardcode "two plugins". Commands, agents, hooks,
scripts, references and templates are all auto-discovered from conventional directory
names — no manifest declares them. There is no `tle` or loop-related artifact anywhere in
the repo today; this is greenfield.

**The platform side contains one finding that directly contradicts the design's central
mechanism.** The discussion doc specifies that `/tle:run` "loops internally … within one
session" while `/goal` acts as the backstop that decides when the session may stop. But
`/goal`'s evaluator is documented to run **once per turn, at Stop** — so a runner that
performs many iterations *inside a single turn* receives **zero** evaluations until that
turn ends. `/goal` cannot interrupt or bound an internal loop; it is a between-turn
mechanism only. Two secondary facts compound this: evaluation is **skipped entirely for
any turn that ends with a subagent or background shell still running**, and an active goal
is **not observable by any script, hook, env var, or CLI flag** — so the runner's opening
"check that a goal condition is set" step has no programmatic implementation. Reconciling
the engine model is the single most consequential decision for the planning phase.

**Three further platform findings shape the agents and the file layout:**

1. Plugin subagents **may not declare `mcpServers`** (the field is silently ignored), and
   a `tools:` allowlist has a documented history of stripping inherited MCP tools. The
   only configuration that reliably inherits chrome-devtools-mcp *and* cannot fail to
   launch when it is absent is to **omit `tools` entirely** and constrain via
   `disallowedTools`, with graceful degradation handled in the prompt body.
2. Compaction truncation is documented and exact: an invoked command body is re-injected
   after compaction **keeping only the first 5,000 tokens**, within a **25,000-token
   budget shared across all re-attached skills, oldest dropped first**. A long-running
   loop runner is the archetypal session that compacts — which makes point-of-use
   reference-file reads (already this repo's rule) load-bearing rather than stylistic.
3. The docs now recommend `skills/<name>/SKILL.md` over `commands/*.md` **for new
   plugins**; both work and both produce `/tle:<name>`.

**All existing tce agents are read-only by tool omission.** tle inverts this: its verifier
must execute commands and drive a browser, and its implementer must edit and commit. The
isolation tce achieves through tool restriction must, for tle, be achieved
*informationally* (fresh context, no access to the implementer's reasoning) instead.

## Detailed Findings

### 1. Adding a third plugin — the mechanical surface

Everything a plugin consists of is auto-discovered; **no manifest lists commands, agents,
hooks, scripts, references, or templates**.

**Two files must change outside `plugins/tle/`:**

- `.claude-plugin/marketplace.json:10-23` — the `plugins` array. Exactly four fields per
  entry are in use: `name`, `source` (`"./plugins/<name>"`), `description`, `version`.
  No `author`, `category`, `strict`, or `license` appears.
- Docs that hardcode the plugin count (see finding 6).

**`plugins/tle/.claude-plugin/plugin.json`** follows `plugins/tmt/.claude-plugin/plugin.json:1-15`
— fields in use across both existing manifests: `name`, `version`, `description`,
`author.{name,email}`, `keywords[]`, and (tce only) `userConfig`. Never used: `homepage`,
`repository`, `license`, path overrides, `mcpServers`.

Version conventions (`CLAUDE.md`, "Releasing" / "Versioning convention"): every plugin
starts at `1.0.0`; the version is declared in **both** `plugin.json` and the marketplace
entry (currently consistent: tce `1.0.1`, tmt `1.0.0`); tags are `<plugin>--v<version>`
(`tce--v1.0.0`, `tce--v1.0.1`, `tmt--v1.0.0` exist as loose refs), created by
`claude plugin tag ./plugins/<name>`.

**Optional infrastructure tle may or may not need:**

- `hooks/hooks.json` — tce uses **exec form** (`command` + `args`) because
  `${user_config.*}` appears in it (`plugins/tce/hooks/hooks.json:6-11`); tmt uses **shell
  form** with the plugin root double-quoted (`plugins/tmt/hooks/hooks.json`). The
  distinction is documented in `CLAUDE.md` and is a hard-fail if violated.
- `scripts/lib.sh` — both plugins define a project-root resolver that never assumes the
  script's location maps to the project: `tce_project_root()`
  (`plugins/tce/scripts/lib.sh:11-13`) and `tmt_project_root()`
  (`plugins/tmt/scripts/lib.sh:12-14`), both `printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"`.
  Sourcing idiom, identical in every executable script (e.g.
  `plugins/tmt/scripts/next-ticket.sh:14-16`):

  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=lib.sh
  . "$SCRIPT_DIR/lib.sh"
  ```

  `set -e` goes before any work in user-invoked scripts; hook scripts read stdin **first**,
  then enable `set -e` with an `ERR` trap.
- `templates/tle/` — only if tle writes per-project config. The design has tle reading
  tce's profile opportunistically and otherwise taking its facts from the goal file, so
  **no `.claude/tle/` config is implied by the ticket**.

`.gitignore` ignores only `.DS_Store`, `.claude/settings.local.json`, `.claude-commit` —
the whole plugin tree is tracked.

### 2. Command conventions

**Frontmatter fields in use across all 17 existing commands**: `description`,
`argument-hint`, `allowed-tools`, `disable-model-invocation`, `model`. Nothing else.

`disable-model-invocation: true` is carried by exactly 8 files, all tce:
`init.md:3`, `refresh.md:3`, `work.md:4`, `quickfix.md:4`, `review.md:4`, `discuss.md:4`,
`design_explore.md:4`, `implement_eco.md:5`. The five delegation targets (`ticket`,
`research`, `plan`, `implement`, `commit`) and all four tmt commands omit the key entirely
— it is never written as `false`.

`model` is set exactly once: `plugins/tce/commands/implement_eco.md:4` (`model: sonnet`).

`allowed-tools` syntax — one unquoted line, comma-separated, script path double-quoted
inside the `Bash(...)` matcher with a `:*` wildcard:

```
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)
```

(`research.md:4`, `plan.md:4`, `work.md:5`, `review.md:5`; the longest is
`implement.md:4`, which adds `Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*)`.)

**Arguments.** No command uses positional `$1`/`$2`; `$ARGUMENTS` appears in exactly two
files (`review.md:63,69` and `implement_eco.md:18`), everything else refers to the argument
in prose. Every argument-taking command has an explicit **skip-the-greeting branch** plus a
no-argument fallback that prints a fenced message and waits — e.g. `research.md:135-154`.
(The independent review flagged the absence of that branch as a real defect that could
stall a command invoked *with* an argument —
`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:50-57`.)

A flag-style argument precedent exists: `ticket.md:65-66` handles `--autonomous` passed by
`/tce:quickfix`.

**Command skeleton**, in order: frontmatter → `# Title Case Heading` → a "You are tasked
with…" role paragraph → `## Project context` (in 10 of 13 tce commands) → the
`### AskUserQuestion dialog guidelines` block (9 files, byte-identical) → `---` →
`## Workflow Context` table → body → `## Important Rules` in the composites.

The `## Project context` block (`research.md:11-17`) is the pattern tle's commands would
mirror, adapted: it names the plugin, asserts agnosticism, instructs reads of project
config with a fallback, and defines the placeholder convention.

**Variable spelling**: `${CLAUDE_PROJECT_DIR}` for reads of *project* config, always inside
backticks; `${CLAUDE_PLUGIN_ROOT}` for *shipped* assets, appearing in three positions —
`allowed-tools`, double-quoted inside fenced bash blocks, and inline in prose for reference
files.

**Subagent dispatch** is written as bare bold agent names — "Use the **codebase-locator**
agent" (`research.md:174-224`). The strings `subagent_type` and "Agent tool" appear nowhere
in any command; "Task agents" is the only tool-ish phrasing. Dispatch steps are followed by
an explicit join ("**Wait for all sub-agents to complete…**", `research.md:226`).

**Skill delegation between commands** uses a declared convention plus a guarded imperative.
Declared once in the composite's Project context (`quickfix.md:21`, `work.md:22`):

> When these instructions tell you to invoke another workflow command **via the Skill
> tool**, use its namespaced name (e.g., `tce:plan`). In prose, sibling commands are
> referenced by their installed, prefixed name (e.g., `/tce:plan`).

Then per call site (`quickfix.md:159-161`, `:183-185`; the whole body of `implement_eco.md:16-18`):

```
**CRITICAL: You MUST run the full `/tce:X` process.**
**Invoke the `tce:X` skill** (via the Skill tool) with <args> as args
```

Each such phase is followed by a `**MANDATORY OUTPUT**:` assertion naming the file that
must exist on disk (`quickfix.md:146`, `:170`) — a directly reusable pattern for a loop
whose every iteration must produce artifacts.

**Sizes**: single-step workflow commands 340–450 lines; composites 250–270; script-wrapping
or convention commands 20–90; the pure delegation wrapper 18 (`implement_eco.md`).

### 3. Agent conventions and the isolation pattern

**Frontmatter across the 7 tce agents**: `name`, `description`, `tools` (always a *single
comma-separated string*, never a YAML list), `model` (every agent declares it — five
`inherit`, the two cheap locators `haiku`), and `color` on one file only
(`web-search-researcher.md:5`).

**No agent grants a mutating tool.** Tool names in use: `LSP`, `Read`, `Grep`, `Glob`,
`LS`, `WebSearch`, `WebFetch`, `TodoWrite`. No `Edit`, `Write`, `Bash`, `Task`, and **no
MCP tool name anywhere**. This is a deliberate enforcement mechanism, not an accident —
TP-0020 research records read-only-by-tool-omission as how the compliance gate's
constraints are made structural.

> Factual note: `LS` does not appear in the current Claude Code tools reference (the
> documented list has `Glob`, `Grep`, `Read`, … but no `LS`). The entries are inert
> because other entries in each list resolve; recorded here only because tle's agents will
> otherwise copy the same list.

**`plan-compliance-checker.md`** (99 lines) is the isolation pattern the ticket names as
the verifier's model. Section order: frontmatter → role paragraph → `## What you receive`
→ `## CRITICAL:` → `## Verdicts` → `## Process` → `## Output Format` →
`## Important Guidelines` → `## What NOT to Do` → `## REMEMBER:`.

Its read boundary is stated three times in three registers (`:14-26` as MAY/may-NOT prose
with the rationale inline, `:54` as an operational sentence, `:83` as a flat prohibition):

> You do NOT receive — and must NOT seek out — the ticket's problem statement, the plan's
> rationale, the research document, or the conversation that produced the code. Judging the
> change *without* the reasoning that produced it is the entire point of this check. You
> MAY open the **post-change source files** touched by or directly referenced in the diff …
> You may NOT open the ticket, the plan, the research, or any `thoughts/` document.

Four verdicts, each with an evidence or behavioral obligation (`:37-47`): **met** (with
`path:line`), **not met**, **cannot verify from diff**, **needs human verification**
(MANUAL items — "do not guess it"). Tie-break rule at `:79`: "When in doubt between met and
not met, use cannot verify from diff."

Output is a fenced table prefixed "**Emit only this**" (`:57-71`) — the other agents say
"Structure your findings like this", i.e. shape guidance without the exclusivity clause.
TP-0020 research adds an output budget decision: cap the report at **~1–2k tokens**,
verdicts and evidence refs only.

**The three-part envelope** (`## CRITICAL: YOUR ONLY JOB IS …` with all-caps `DO NOT`
bullets closing on a single `ONLY` bullet → `## What NOT to Do` with sentence-case `Don't`
bullets → `## REMEMBER: You are an X, not a Y` plus a metaphor paragraph) is invariant in
shape across four of the seven agents and varies only in domain nouns. TP-0020 records the
rule for exceptions: use a **narrow parenthetical carve-out**, never soften the block
(`codebase-analyzer.md:91,149,153` is the cited precedent).

**Profile reads.** Exactly four agents read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`,
all with an explicit fallback when it is missing (`codebase-analyzer.md:10-12`,
`codebase-locator.md:12`, `codebase-pattern-finder.md:12`, and
`web-search-researcher.md:46-52` which reads one named section). `${CLAUDE_PLUGIN_ROOT}`
**never appears in any agent file** — no agent reads a reference file.

**How tle departs from this.** tce's verification agent is isolated *by tool omission*
(read-only, so the caller must pre-compute the diff and inline it —
`implement.md:259-266`). tle's verifier must run tests, check exit codes and drive a
browser; its implementer must edit and commit. The isolation tle needs is therefore
**informational** — fresh context, reads the goal file and its own verification methods,
never the implementer's claims or reasoning — not tool-based. The design's "diff-reviews
test files (tests may not be edited to pass)" rule is the tle-specific analogue of the
read-boundary.

### 4. Reference files vs. inline templates

Two mechanisms coexist, and TP-0016 established the partition.

**Reference files** (`plugins/tce/references/`, 2 files) carry *stable reference material*:
`research-document-template.md` (141 lines, two templates — the document template and the
conditional Impact Analysis section) and `plan-document-template.md` (231 lines, five
sections mixing fenced templates with unfenced guidance). Each opens with an HTML comment
header stating when it is read, by whom, that it is never copied into projects, which
governance rule applies to edits, and a numbered Contents list.

**Inline templates** live in the command body for: the ticket body (`ticket.md:275-321`),
the review document (`review.md:286+`), the discussion document (`discuss.md:70-110`), the
design DECISION.md (`design_explore.md:298+`), and the implementation log/closeout blocks
(`implement.md:97-107`, `:113-119`).

**The read instruction is the contract.** All five reference-file read sites inline the
`${CLAUDE_PLUGIN_ROOT}/references/...` path at the point of use, and four of five carry the
recurring clause:

> read `${CLAUDE_PLUGIN_ROOT}/references/<file>` now — in full, even if you read it earlier
> in this session — and …

(`research.md:266`, `research.md:341-343`, `work.md:89`, `work.md:197`, `quickfix.md:144`;
`plan.md:397` uses the variant "even if you read it in Step 3".)

The rationale, from TP-0016 research `:233`: "a reference file is only re-read if the
surviving body still instructs the read at the moment of use — placement of the read
instruction within the first 5,000 tokens (or at the point of use in a numbered step)
matters; **nothing in the docs automates re-reading**."

**Measured extraction thresholds** (TP-0016 research `:33`, `:72-91`): plan.md was 769
lines with ~330 lines (43%) of fixed template; research.md 475 lines with ~130 (27%). The
official length guidance is **under 500 lines** per skill body, with reference material one
level deep and a table of contents for files over 100 lines.

### 5. Generated-artifact conventions

**Metadata gathering** is a fixed four-command recipe (`research.md:247-253`), enforced by
"Fill in the metadata gathered in step 5 — NEVER write the research document with
placeholder values" (`research.md:267`):

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"; git rev-parse HEAD; git branch --show-current; git config --get remote.origin.url
```

**Frontmatter**: research documents get 8 fields (`date`, `git_commit`, `branch`,
`repository`, `topic`, `tags`, `status`, `last_updated`); plan documents get **none**
(provenance lives in a `## References` section); review/discussion/design artifacts get
3–6 fields defined inline in their commands.

**Filenames**: `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md`,
`thoughts/shared/plans/...`, `thoughts/shared/reviews/YYYY-MM-DD-[PREFIX]-XXXX-review.md`,
`thoughts/shared/discussions/YYYY-MM-DD-<slug>.md`. The canonical ticket ID in the filename
is what links a document to its ticket (the discovery script globs for it).

**The closest precedent for tle's per-goal directory** is `/tce:design_explore`, the one
command that creates a **directory of artifacts** rather than a single file:
`thoughts/shared/mockups/<YYYY-MM-DD>-<slug>/` (`design_explore.md:158`) containing
`index.html`, `<approach-slug>.html`, and `DECISION.md` (`:247`, `:296`, `:329`).
`thoughts/shared/loops/<goal-slug>/` follows the same shape, minus the date prefix.

**The closest precedent for append-per-iteration state** is the in-plan implementation log
(`implement.md:97-119`) — terse blocks, "target ≤ 8 lines, never prose journaling"
(`implement.md:109`), with the **base commit recorded at start time in the durable
artifact** (`implement.md:101`, `:127`) so the diff is precise later. TP-0023 eliminated a
separate `.status.md` file in favor of this in-plan log; the independent review had flagged
the two-file version as double bookkeeping (`:256-259`).

### 6. Documentation surfaces that enumerate the plugins

Four files hardcode "two plugins" or list them individually:

| File | Lines | What is there |
|---|---|---|
| `README.md` | `:15-20` | The **plugin catalog** — a `Plugin \| What it does \| Docs` table, one row per plugin. Also `:3-4` names both plugins in the subtitle and `:6-8` uses "either"/"both". No layout tree. |
| `CLAUDE.md` | `:3-8` | "There are two plugins: **`tce`** … and **`tmt`** …". Layout tree at `:17-42` (with the "To add another plugin" note at `:41-42`); also `:370-371` (validate commands), `:376-378` (end-to-end install), `:321-322` (the nine AskUserQuestion copies). |
| `CONTRIBUTING.md` | `:3-8`, `:12`, `:29-48`, `:76-78` | "a monorepo containing two Claude Code plugins", the two README links, the layout tree, the validate commands. |
| `.claude-plugin/marketplace.json` | `:10-23` | The `plugins` array. |

**Plugin README shape** (tmt's, at 136 lines, is the closer model than tce's 283-line
long-form): title `# <plugin> — <Expanded Name>` → intro → the shared "Built by Toby"
blockquote (byte-identical in all three READMEs) → `## What you get` → `## Requirements`
(a `Tool | Needed for | Required?` table) → `## Install` (a 3-line bash block:
`marketplace add` + `install <plugin>@toby-plugins`) → `## Set up a project` →
`## Commands` (a flat `Command | Purpose` table — `plugins/tmt/README.md:80-87`) →
plugin-specific sections → `## Update` → `## Contributing` linking `../../CONTRIBUTING.md`.

The Requirements table is where the ticket's "chrome-devtools-mcp as a documented (not
shipped) project-level dependency" belongs — tce's equivalent row for a ticket system is
`plugins/tce/README.md:122`.

### 7. Platform mechanics — `/goal`

Source: [Keep Claude working toward a goal](https://code.claude.com/docs/en/goal).

`/goal` is documented as "a wrapper around a session-scoped prompt-based Stop hook". One
goal per session; the condition can be **up to 4,000 characters**; setting a goal "starts a
turn immediately, with the condition itself as the directive".

**Evaluation timing — the load-bearing finding:**

> "Each time Claude finishes a turn, Claude Code sends the condition and the conversation
> so far to your configured small fast model, which defaults to Haiku on the Claude API."

> "The evaluator runs on whichever provider your session is configured for. **It does not
> call tools, so it can only judge what Claude has already surfaced in the conversation.**"

Consequence for the design as written: a runner that performs N iterations **inside one
turn** gets **zero** evaluations until that turn ends. `/goal` is a between-turn backstop;
it cannot interrupt or bound an internal loop. For `/goal` to act per iteration, each
iteration must **end a turn** — at which point `/goal`'s own "not yet met → Claude starts
another turn instead of returning control to you" is what drives the next iteration, making
`/goal` the engine rather than a backstop.

**Verdicts** (three): *Not yet met* → "Claude keeps working and takes the reason as
guidance for the next turn"; *Met* → goal cleared, achieved entry recorded; *Impossible* →
goal cleared, failed entry recorded with the reason.

**Stall guard**: "If Claude keeps answering the evaluator without making progress (**no
tool use for several turns in a row**), Claude Code stops the loop, prints a warning, and
returns control to you **with the goal still set**." The underlying Stop-hook block cap is
documented as eight consecutive blocks without progress.

**Budgets are condition text only** — there is no flag or parameter: "To bound how long a
goal runs, **include a turn or time clause in the condition**, such as `or stop after 20
turns`." Enforcement is a Haiku-class evaluator reading the transcript, i.e. **soft**.

**Subagent interaction — two documented facts, both material:**

> "**If a subagent or a background shell command is still running when a turn ends, Claude
> Code skips the evaluation for that turn.** It evaluates at the end of the next turn that
> finishes with no background work running."

and the evaluator sees only what reached the conversation. The design's step "surface the
verdict into the transcript (for `/goal`'s Haiku)" is therefore **exactly what the docs
prescribe** — the runner should restate the verdict as plain assistant text mirroring the
condition's wording, rather than relying on a tool result being visible to the evaluator
(unconfirmed whether the evaluator prompt includes tool results). Dispatching the verifier
as a **background** subagent would silently skip that turn's evaluation.

**Lifecycle**: `/goal clear` (aliases `stop`, `off`, `reset`, `none`, `cancel`); `/clear`
removes it; a goal active at session end **is restored on `--resume`/`--continue` with the
turn count, timer and token baseline reset**; ordinary auto-compaction does **not** clear it,
but "a context overflow that auto-compaction couldn't clear" does. `/goal` is unavailable
when hooks are disabled (`disableAllHooks`, `allowManagedHooksOnly`, or workspace-trust).

**Detectability — answered negatively.** No hook input field, no status-line field, no env
var reporting state, no CLI flag, no `stream-json` event, no documented state file. Checked:
hooks reference (the string "goal" does not appear), status line schema (~35 fields),
CLI reference, env vars (only `CLAUDE_CODE_GOAL_CHECKIN_MINUTES`, an input knob),
headless/`stream-json` event list, slash-command reference, changelog and issues. Bare
`/goal` shows condition, elapsed time, turns evaluated, token spend and the latest reason —
but that is TUI output only. The only real signal is **model-observable**: the condition
enters the transcript as a directive at set time, and each "not yet met" reason is fed back
as system-reminder context.

**Documented alternative**: a plugin ships hooks, so a **prompt-based Stop hook in
`hooks/hooks.json`** is the documented per-scope equivalent — it *is* under the plugin's
control and receives JSON input, sidestepping the detectability problem entirely. The
ticket places a Stop-hook engine out of scope; recorded here as a factual property of the
option space, not as a proposal.

### 8. Platform mechanics — subagents, tools, MCP

Sources: [Subagents](https://code.claude.com/docs/en/sub-agents),
[Tools reference](https://code.claude.com/docs/en/tools-reference),
[Plugins reference](https://code.claude.com/docs/en/plugins-reference),
[MCP](https://code.claude.com/docs/en/mcp).

**Fields supported for *plugin* agents**: `name`, `description`, `model`, `effort`,
`maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`, `background`, `isolation`.
**`hooks`, `mcpServers` and `permissionMode` are ignored for plugin subagents** ("For
security reasons… These fields are ignored when loading agents from a plugin"). `tools`
accepts a comma-separated string **or** a YAML list.

**Tool resolution matrix:**

- Neither field set → inherits **every tool available to subagents, including MCP tools**.
- `tools` only → only the listed tools.
- `disallowedTools` only → every parent tool except those listed.
- Both → `disallowedTools` wins.

MCP naming: `mcp__<server>__<tool>`; server-level patterns `mcp__<server>` and
`mcp__<server>__*` work in both fields; `mcp__*` works only in `disallowedTools`. There is
**no wildcard for built-in tools** and **no concept of an optional tool**.

**Failure mode**: "If no entry in the list resolves to a tool, the subagent usually fails to
launch with an error naming the entries." The **partial**-unresolved case (some entries
resolve, some don't) is **not documented** — silent-drop is a strong inference from the
"every entry" wording and is corroborated by this repo's own agents listing the non-existent
`LS` and working, but it is not a guarantee.

**Reliability history is poor for MCP-in-subagent**, and specifically for the configuration
chrome-devtools-mcp typically uses (project/user-scoped): issues
[#13898](https://github.com/anthropics/claude-code/issues/13898) (closed — project-scoped
MCP servers unreachable from custom subagents, which hallucinated instead),
[#30280](https://github.com/anthropics/claude-code/issues/30280) (open — subagents don't
reliably inherit MCP tools, contradicting the docs),
[#25200](https://github.com/anthropics/claude-code/issues/25200) and
[#34935](https://github.com/anthropics/claude-code/issues/34935) (both closed as not
planned). Two plugin-agent-specific `tools:` regressions:
[#52055](https://github.com/anthropics/claude-code/issues/52055) (plugin subagents never
received `Grep`/`Glob`) and
[#60237](https://github.com/anthropics/claude-code/issues/60237) (first and last entries of
a `tools:` array silently dropped).

**Context isolation.** A non-fork subagent receives: its own prompt + environment details,
the delegation prompt, the **full CLAUDE.md hierarchy**, a git-status snapshot, and the full
content of any `skills:` named. It does **not** receive: conversation history, output style,
auto memory, skills invoked in the main session, or **files already read in the main
session**. It returns **only its final message**; full history and tool calls stay in its own
transcript. This is the platform enforcing exactly what TP-0013's re-read rule asks for.

**Limits**: 20 concurrent subagents (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`); nesting up to
3 layers (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`); per-agent `maxTurns` (no documented
default); **no documented token budget or wall-clock timeout**.

**Model field**: `sonnet | opus | haiku | fable | <full model ID> | inherit`, default
`inherit`. Resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` → per-invocation `model` param →
frontmatter → main conversation model. Org `availableModels` blocks degrade gracefully.

**Discovery and naming**: auto-discovered from `agents/` at plugin root, no manifest entry;
scanned **recursively**, with subfolders becoming part of the name (`agents/review/security.md`
→ `my-plugin:review:security`); namespaced `plugin-name:agent-name`; **lowest precedence** of
five scopes, so a same-named project or user agent shadows a plugin agent — an argument for
distinctive names. `name` may not contain `:`. `/reload-plugins` reloads agents; they are not
live-watched.

**Permissions caveat for the implementer agent**: launching a subagent does not itself
prompt, but "Claude Code checks the subagent's own tool calls against your permission rules
as it runs" — and since plugin agents cannot set `permissionMode`, an implementer's
Bash/Edit/commit calls are governed by the *user's* settings and **will prompt** unless
allowlisted. A plugin cannot pre-approve them from the agent file.

**Subagents can never use `AskUserQuestion`** (universally filtered) — so all user
interaction must live in `/tle:define`, never in an agent.

### 9. Platform mechanics — command frontmatter, compaction, `/loop`

Sources: [Skills](https://code.claude.com/docs/en/skills) (the `/slash-commands` URL now
serves this page — commands are skills), [Context window](https://code.claude.com/docs/en/context-window),
[Scheduled tasks](https://code.claude.com/docs/en/scheduled-tasks).

**Command files support the full skill frontmatter** except `name` and `paths`. Fields
beyond what this repo currently uses, and relevant to tle: `disallowed-tools`, `when_to_use`,
`arguments`, `context: fork`, `agent`, `background`, `effort`, `hooks`, `shell`, `metadata`.

`disallowed-tools` is documented with tle's exact use case: "Tools removed from Claude's
available pool while this skill is active. Use for autonomous skills that should never call
certain tools, **such as `AskUserQuestion` for a background loop**."

**`allowed-tools`, `disallowed-tools`, `model` and `effort` are turn-scoped**: "The grant
clears when you send your next message, even though the skill content stays in context."
Session-wide pre-approval requires permission settings, not frontmatter. For a loop that
spans user messages, the grant is gone after the first one.

**`disable-model-invocation: true`** blocks all Skill-tool invocation and "removes the skill
from Claude's context entirely"; it also prevents preloading into subagents and — since
v2.1.196 — prevents the skill running when a scheduled task fires with it as the prompt. A
`/loop`-fired flagged skill "reach[es] Claude as plain text instead of executing".

**Argument substitution gotcha**: `$0` is the **first** argument and `$1` the **second**
(`$N` is shorthand for `$ARGUMENTS[N]`, 0-based) — not the shell-like convention. An indexed
placeholder with no corresponding argument **stays in the content unchanged**.

**Compaction — exact figures:**

> "Auto-compaction carries invoked skills forward within a token budget. … Claude Code
> re-attaches the most recent invocation of each skill after the summary, **keeping the
> first 5,000 tokens of each. Re-attached skills share a combined budget of 25,000 tokens.**
> Claude Code fills this budget starting from the most recently invoked skill, so older
> skills can be dropped entirely."

> "**Truncation keeps the start of the file**, so put the most important instructions near
> the top."

Also: skill *descriptions* are not re-injected after compaction; tool outputs are cleared
**first**, before summarization; and the summary "replaces the verbatim conversation: full
tool outputs and intermediate reasoning are gone." The documented remedy for a truncated
skill is to **re-invoke it**.

For tle this means: the runner body should be under ~5,000 tokens with loop invariants at
the very top; every skeleton and log must be re-read from disk at point of use inside the
iteration step; and a runner that Skill-delegates to several other skills competes for the
25,000-token budget with itself as the oldest, hence first-dropped, entry.

**No documented guidance exists for a command body that loops internally for many turns.**
The docs instead route this need to three supported mechanisms, with an explicit comparison
table: `/goal` (next turn starts when the previous finishes), `/loop` (when a time interval
elapses; **minimum 1 minute**), and a **Stop hook** (previous turn finishes; your script or
prompt decides). Treat a long internal loop instruction as undocumented behavior.

**`/loop` specifics**: same accumulating session (not fresh context); 1-minute minimum;
dynamic mode picks 1–60 min delays and can self-terminate via `ScheduleWakeup(stop: true)`;
recurring tasks expire after 7 days; jitter up to 30 min or half the interval; 50 tasks per
session; `Esc` clears a pending wakeup; starting a new conversation clears session-scoped
tasks.

**Skills vs commands for a new plugin.** The plugins reference lists both `skills/` and
`commands/` as valid locations and states: "Skills are directories with `SKILL.md`; commands
are simple markdown files. **Use `skills/` for new plugins**." Both yield `/tle:<name>`.
`skills/` additionally supports bundled supporting files and `${CLAUDE_SKILL_DIR}` (whose
value for a *flat* command file is undocumented). One operational note: `/reload-plugins`
reports skill counts only for `commands/` directories, so it can print `0 skills` for a
`skills/`-based plugin that reloaded fine.

### 10. Repo governance rules a new plugin triggers

From `CLAUDE.md`, the rules that would apply to or need extending for tle:

- **Core design rule** — nothing project-specific in a plugin; no stack or ticket-system
  literals; per-project data lives in the consuming project.
- **Cross-plugin coordination** — "The plugins coordinate **only through project config
  files**, never by calling into each other (there is no cross-plugin
  `${CLAUDE_PLUGIN_ROOT}`)." tle reading `.claude/tce/profile.md` if present is exactly the
  sanctioned form; a `${CLAUDE_PLUGIN_ROOT}` reference into tce would not be.
- **TP-0017 invocation control** — the classification section must be re-derived whenever a
  command or delegation edge is added. The rule is **inbound-edge-only**: a command may
  carry the flag iff nothing delegates *into* it. Prose references ("use the `/tce:X`
  command") count as delegation edges.
- **TP-0016 reference files** — "part of the command contract", read at point of use;
  editing one is editing the command.
- **TP-0013 re-read rule** — every consuming command must instruct an explicit,
  unconditional, full re-read of its input context documents in chain order on every
  invocation.
- **TP-0020 gate-spans-four-files rule** and the **composite-tracking rule** — both are
  instances of the general principle stated in the independent review (`:261-263`): every
  deliberate duplicate needs an explicit rule naming all copies. If any tle skeleton or
  instruction is mirrored across the two commands, the sync rule belongs in `CLAUDE.md` in
  the same commit.
- **AskUserQuestion block** — currently duplicated byte-identically across **nine** files.
  `/tle:define` is an interactive command with dialog sites, so adding it would make **ten**
  copies, and the `CLAUDE.md` rule text (which says "nine" and enumerates the files) would
  need updating in the same commit.
- **Conventions** — always work on `main`, no branches or PRs; conventional commits;
  never auto-push; surgical edits over rewrites in markdown-heavy prompt files.

## Code References

- `.claude-plugin/marketplace.json:10-23` — the plugins array a tle entry joins
- `plugins/tmt/.claude-plugin/plugin.json:1-15` — the simpler manifest model for tle
- `plugins/tce/.claude-plugin/plugin.json:16-23` — the sole `userConfig` entry
- `plugins/tce/hooks/hooks.json:6-11` — exec form (required with `${user_config.*}`)
- `plugins/tmt/hooks/hooks.json` — shell form with quoted plugin root
- `plugins/tce/scripts/lib.sh:11-13`, `plugins/tmt/scripts/lib.sh:12-14` — project-root resolvers
- `plugins/tmt/scripts/next-ticket.sh:14-16` — the lib-sourcing idiom
- `plugins/tce/agents/plan-compliance-checker.md:14-26` — the read-boundary statement
- `plugins/tce/agents/plan-compliance-checker.md:37-47` — the four-verdict vocabulary
- `plugins/tce/agents/plan-compliance-checker.md:57-71` — "Emit only this" output template
- `plugins/tce/agents/plan-compliance-checker.md:28-35`, `:81-90`, `:92-99` — the three-part envelope
- `plugins/tce/agents/codebase-analyzer.md:10-12` — the `## Project context` profile-read paragraph
- `plugins/tce/commands/implement.md:244-297` — the Plan-Compliance Gate (criteria assembly, diff, delegation, gating)
- `plugins/tce/commands/implement.md:97-119` — implementation log + closeout inline templates
- `plugins/tce/commands/research.md:174-224` — subagent dispatch phrasing
- `plugins/tce/commands/research.md:266` — the point-of-use reference-file read clause
- `plugins/tce/commands/research.md:135-154` — argument check + no-argument fallback
- `plugins/tce/commands/quickfix.md:21`, `:159-161`, `:183-185` — Skill-delegation convention and call sites
- `plugins/tce/commands/quickfix.md:146`, `:170` — the `MANDATORY OUTPUT` assertion pattern
- `plugins/tce/commands/implement_eco.md:1-18` — the 18-line pure delegation wrapper
- `plugins/tce/commands/design_explore.md:158`, `:296` — the directory-of-artifacts precedent
- `plugins/tce/references/research-document-template.md:1-16` — reference-file header convention
- `plugins/tmt/README.md:80-87` — the flat `Command | Purpose` table
- `README.md:15-20` — the marketplace plugin catalog
- `CLAUDE.md:3-8`, `:17-42` — plugin count and layout tree
- `CONTRIBUTING.md:3-8`, `:29-48`, `:76-78` — plugin count, layout tree, validate commands

## Architecture Documentation

The marketplace is a monorepo of independently versioned, self-contained plugins. Each
plugin is a directory with a manifest plus conventional subdirectories that Claude Code
auto-discovers. Plugins never reference each other's `${CLAUDE_PLUGIN_ROOT}`; they
coordinate only by reading per-project config files, which is why tle's "read
`.claude/tce/profile.md` if present" is architecturally clean while a direct tce call would
not be.

Within tce, the prevailing architecture is **context artifacts on disk plus fresh-context
subagents**: commands are long prompts that read their inputs from files at the point of
use, delegate deep reading to subagents whose returns are condensed, and write durable
artifacts under `thoughts/`. The mechanisms that enforce this — point-of-use reference
reads, chain-order re-reads, criteria-only delegation to an isolated checker — all exist
because conversation state is unreliable across compaction. tle's file-only-handoff rule is
the same architecture applied to a loop, and the platform's subagent isolation guarantees
(no inherited conversation, no inherited file reads, final message only) enforce it for free.

The one structural inversion is tool posture: tce's agents are uniformly read-only, and
verification is achieved by having the *caller* pre-compute evidence. tle's agents must act
— execute, browse, edit, commit — so its verification integrity rests on informational
isolation and on the "tests may not be edited to pass" rule being stated in both the
verifier's and the implementer's prompts, plus the verifier's diff-review of test files.

## Historical Context (from thoughts/)

- `thoughts/shared/discussions/2026-08-19-tle-loop-engineering-plugin.md` — the settled tle
  design; authoritative for the ticket. Records the `/goal`-over-`/loop` engine choice, the
  4→3 agent reduction, dropping the loop-breaker agent, and the accepted trade-offs.
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` — established
  `disable-model-invocation` semantics (blocks *all* Skill-tool invocation, removes the
  description from context) and the inbound-edge-only delegation rule; documented that
  `allowed-tools` grants permission without restricting availability; that
  `${CLAUDE_PLUGIN_ROOT}` in frontmatter is undocumented-but-verified; and that subagents
  can never use `AskUserQuestion`.
- `thoughts/shared/research/2026-07-12-TP-0024-eco-implement-wrapper-sonnet.md` — the most
  recent command addition; the Skill-delegation wording, and the checklist of what a new
  command touches (command file, `CLAUDE.md` classification, plugin README; no manifest
  entry). Records that command-level `model:` propagation across a Skill boundary is
  **unverified**.
- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md` —
  the compaction figures and the stable-reference-vs-per-invocation-behavior partition;
  also that commands are officially skills and `skills/` is recommended for new plugins.
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` — the isolation
  contract, the base-commit diff mechanism, the verdict contract and caller gating, the
  ~1–2k-token output cap, and the decision that the gate runs on **every** closing (a
  "gate only when criteria exist" option was rejected as a silent bypass).
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — pitfalls directly
  applicable to a loop plugin: the missing skip-the-greeting branch (`:50-57`); dead
  machinery that "trains [the model] that instructions in this prompt are optional"
  (`:59-70`); load-bearing step numbering (`:72-75`); asserted rather than checked
  invariants (`:82-90`); depending on harness built-ins that may not exist (`:97-100`);
  the compaction cliff for long prompts (`:123-137`); instruction-budget overflow
  (`:139-149`); running multiple phases in one context window, with the suggested fixes of
  forking the noisiest phase into a subagent or advising a fresh session at a phase
  boundary (`:151-164`); missing subagent output budgets (`:178-181`); and hard behavioral
  blocks colliding with legitimate task types, to be fixed by bounded carve-outs rather
  than softening (`:183-190`).
- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md` — why
  consuming steps must re-read their inputs rather than lean on conversation history.

## Related Research

All prior research documents live in `thoughts/shared/research/`. The five most relevant to
this ticket are the TP-0016, TP-0017, TP-0020, TP-0024 and TP-0013 documents listed above.
No prior research covers loops, `/goal`, scheduled tasks, or autonomous iteration — this is
the first.

## Open Questions

### Answers to the ticket's "Questions for Research/Planning"

1. **Command frontmatter per the TP-0017 classification.** Derived from the inbound-edge
   rule: `/tle:define` has no inbound edges (nothing delegates into it; the ticket
   explicitly forbids `/tle:run` editing goal files) → it may carry
   `disable-model-invocation: true` as the ticket specifies. `/tle:run` also has no inbound
   edges today, so the flag would be *permissible* — the ticket keeps it unflagged
   deliberately, to preserve `/loop`-schedulability, which the docs confirm is the right
   call (a flagged skill fired by a scheduled task arrives as plain text). Note the flag's
   cost is asymmetric: flagging removes the description from every session's skill listing.
   `allowed-tools` grants are **turn-scoped**, which for a multi-turn loop means they lapse
   after the user's next message — an open decision on whether to rely on them at all
   versus documenting a permission-settings allowlist. The `disallowed-tools` field (not
   yet used anywhere in this repo) is documented specifically for background loops that
   must not call `AskUserQuestion`.
   **Skill re-injection under compaction is now precisely known** (5,000 tokens/skill,
   25,000 shared, start-of-file kept) — see finding 9 for what that implies about body size
   and ordering.

2. **What `/tle:run` can observe to check "a goal condition is set" — nothing.** There is no
   hook field, env var, status-line field, CLI flag, `stream-json` event, or documented state
   file. The check reduces to (a) instructing the user, (b) prompt-level inference from the
   goal directive and evaluator system-reminders already in the runner's own context, or
   (c) not detecting it and designing the runner to be correct either way. Whether goal
   verdicts land in the `transcript_path` JSONL (parseable) or only in the TUI is
   **undocumented** — treat parsing it as a version-fragile hack.

3. **Agent tool lists and MCP.** Plugin agents cannot declare `mcpServers`. Omitting `tools`
   and constraining with `disallowedTools` is the only configuration that inherits MCP tools
   by documented contract and cannot hit the zero-tools launch refusal when
   chrome-devtools-mcp is absent; the agent prompt then handles the optional dependency by
   checking for `mcp__chrome-devtools__*` and reporting "browser verification unavailable"
   rather than faking it. If a `tools:` allowlist is used anyway, it must include at least
   one certainly-resolvable built-in. Caveat: MCP-in-subagent has a documented history of
   bugs precisely in the project-scoped configuration chrome-devtools-mcp typically uses.

4. **Reference files vs inline.** TP-0016's own partition puts the goal.md skeleton and the
   per-iteration file formats squarely in the reference-file class (stable fill-in
   skeletons, not per-invocation branching), and the compaction figures make it
   near-mandatory for a loop runner: an inline skeleton past the first 5,000 tokens is gone
   after the first compaction and is not restored. The read must be instructed **inside the
   iteration step**, not once at the top. Remaining decision: whether `/tle:define`'s goal
   skeleton and `/tle:run`'s per-iteration formats live in one reference file (like
   `research-document-template.md`, which holds two templates) or several.

5. **Naming/format details for `NNN-verify.md`, `NNN-plan.md`, `loop-log.md`.** No repo
   precedent exists for numbered per-iteration files. The two closest precedents are
   `/tce:design_explore`'s directory-of-artifacts (`thoughts/shared/mockups/<date>-<slug>/`
   with an in-directory `DECISION.md`) and `/tce:implement`'s append-per-phase log with its
   "target ≤ 8 lines, never prose journaling" cap and its **base commit recorded at start
   time** so later diffs are precise. What the stall check compares is undecided; the
   options range from a byte-identical comparison of the verify report to a comparison of
   just the per-item verdict vector (which would be robust to timestamp/prose noise) — the
   latter needs the verify report to carry a stable, extractable verdict block.

### Questions this research raises that the ticket did not anticipate

6. **The engine model needs reconciling — the most consequential open item.** The design has
   `/tle:run` looping internally while `/goal` backstops it, but `/goal` evaluates only at
   turn end, so an internal loop is entirely unsupervised until it finishes. Three coherent
   resolutions exist: (a) one iteration per turn, letting `/goal`'s "not yet met" restart
   drive iteration — which makes `/goal` the engine and the runner a single-iteration
   command, contradicting "loops internally" but matching the platform; (b) keep the
   internal loop and accept that `/goal` only backstops the *outermost* completion, with
   budgets and stall detection enforced entirely by the runner's own deterministic checks;
   (c) the out-of-scope Stop-hook engine. This is a design decision, not a research gap.

7. **Background dispatch would silently disable the backstop.** If the runner dispatches the
   verifier as a background subagent, the goal evaluation for that turn is skipped by
   documented behavior. Whichever engine model is chosen, agent dispatch should be
   foreground.

8. **`skills/` vs `commands/`.** The docs recommend `skills/<name>/SKILL.md` for new
   plugins; this repo uses `commands/*.md` throughout. Both produce `/tle:<name>`. Adopting
   `skills/` for tle alone would make the repo internally inconsistent (and `/reload-plugins`
   would report `0 skills`); keeping `commands/` stays consistent but diverges from current
   guidance. Worth an explicit decision rather than defaulting.

9. **The implementer agent will hit permission prompts.** Plugin agents cannot set
   `permissionMode`, so its Bash/Edit/commit calls are checked against the user's own
   permission rules. An "autonomous" loop that prompts on every commit is not autonomous —
   the plugin README likely needs to document a recommended allowlist, since the plugin
   cannot grant it.

10. **The AskUserQuestion duplication count changes.** `/tle:define` is interactive, so
    adding it makes ten byte-identical copies and requires updating the `CLAUDE.md` rule
    text that currently says "nine" and enumerates the files.

11. **Unverified-by-spec mechanisms this design would rely on**, all flagged by the source
    research as needing empirical confirmation in a scratch project: `${CLAUDE_PLUGIN_ROOT}`
    substitution in frontmatter (works, undocumented); the partial-unresolved-`tools`-entry
    behavior; whether a plugin command may dispatch its own agent by scoped
    `subagent_type`; and whether the `/goal` evaluator sees tool results or only assistant
    text (which decides how emphatically the runner must restate verdicts).
