---
date: 2026-08-11T13:55:30Z
git_commit: a134d79
branch: tsf-design
repository: toby-plugins
topic: "Implementing the tsf plugin v1 per DESIGN.md — existing plugin patterns and the platform mechanics the design depends on"
tags: [research, codebase, tsf, plugin-scaffolding, agents, commands, gh-cli, headless, permissions]
status: complete
last_updated: 2026-09-11
last_updated_note: "Renumbered TP-0025 → TP-0034 and repointed git_commit after rebasing tsf-design onto main (original commit 99605c3 was rewritten to a134d79)"
---

# Research: Implementing the tsf plugin v1 per DESIGN.md

**Date**: 2026-08-11T13:55:30Z
**Git Commit**: a134d79 (rebased; originally 99605c3)
**Branch**: tsf-design
**Repository**: toby-plugins

## Research Question

TP-0034 (created as TP-0025, renumbered on 2026-09-11 after the branch was
rebased onto `main`) asks for a complete, installable v1 of the tsf plugin implementing
`plugins/tsf/DESIGN.md` in full. The ticket's "Questions for Research/Planning"
name five implementation-mechanical unknowns:

1. How `/tsf:cycle` spawns the named `tsf:*` plugin agents, and what each spawn
   prompt must carry.
2. The single-`gh`-query scan design (§5.1) and what `scripts/` should wrap.
3. How `/tsf:run` self-paces within one session.
4. What of tce's command/agent prose is worth mining as *drafting reference*
   while keeping tsf standalone (§2).
5. Which parts of the §6 step specs live in agent system prompts vs
   point-of-use reference templates.

## Summary

The **house-style half of this ticket is fully determined by the existing
repo**: tce and tmt between them demonstrate every artifact type tsf needs —
plugin manifest, marketplace entry, command frontmatter classes, command body
skeleton, agent files with a three-part constraint envelope, `lib.sh` +
script idioms, hook JSON, template skeletons with version markers, and
point-of-use reference files. tsf can be written by re-instantiating those
patterns in its own words (§2's standalone rule), with no invention required.

The **platform half is mostly settled, with four material surprises** — all of
which touch premises DESIGN.md states as fact. In order of design impact:

1. **`disable-model-invocation: true` on `/tsf:cycle` is incompatible with
   `/loop 5m /tsf:cycle`** (DESIGN.md §5.3 supervised burst) and with any
   scheduled-task runner. A flagged skill passed as a loop/cron prompt "reaches
   Claude as plain text instead of executing." AC "All four commands carry
   `disable-model-invocation: true` (§12)" and the `/loop` runner cannot both
   hold.
2. **Subagents can spawn subagents** (depth 3 by default since v2.1.219). §11's
   "A constraint that shapes the roster: subagents cannot spawn subagents" is
   stale — the constraint it accepts no longer exists at the platform level.
3. **There is no callable "wait N seconds" primitive** for `/tsf:run`'s
   self-pacing. `ScheduleWakeup` is documented as internal to a self-paced
   `/loop` ("you don't call it directly"), and Claude Code *never* auto-backgrounds
   a Bash command starting with `sleep`, which is additionally capped by the Bash
   timeout ceiling (2 min default / 10 min max).
4. **`LS` is not a Claude Code tool.** DESIGN.md §11.2 prescribes
   `tools: Read, Grep, Glob, LS` for the gates (inherited from tce's agent files,
   which list it too). The current tools reference has `Glob`, `Grep`, `Read`,
   `LSP` — no `LS`.

Additionally, the single-`gh`-query scan of §5.1 is **two cheap queries, not
one**, and the second one is trivial because tsf branch names are deterministic
(`tsf/GH-<n>` → `gh pr list --json headRefName,...`). And the `/tsf:init`
permission allowlist has a **workspace-trust gotcha**: `permissions.allow` in a
project's `.claude/settings.json` is ignored until the trust dialog is accepted,
and under `claude -p` no dialog appears and the rules stay ignored.

## Detailed Findings

### 1. What a third plugin needs to exist in this marketplace

The scaffolding surface is small and entirely convention-driven — no manifest
key lists commands, agents, or hooks; all are auto-discovered from their
directories.

- **Marketplace entry** — `.claude-plugin/marketplace.json:10-23`. Top level is
  `name`, `metadata.description`, `owner{name,email}`, `plugins[]`. Each entry
  uses exactly four keys in order: `name`, `source` (`"./plugins/tce"`),
  `description` (shorter than the plugin manifest's), `version` (mirroring the
  plugin's own). No `category`, `author`, `homepage`, or `license` on entries.
- **Plugin manifest** — `plugins/tce/.claude-plugin/plugin.json` uses `name`,
  `version`, `description`, `author` (object: `name` + `email`), `keywords[]`,
  and (tce only) `userConfig`. tmt's has no `userConfig`. Neither declares
  `commands`, `agents`, or `hooks` paths.
- **Validation baseline** (run at research time, both pass):
  `claude plugin validate .` and `claude plugin validate ./plugins/tce`.
- **Docs surface to update** beyond the ticket's AC: the root `README.md`
  plugin table (`README.md:17-20`) *and* `CONTRIBUTING.md`'s repository-layout
  tree (`CONTRIBUTING.md:29-48`), which enumerates both plugins' directories
  — the AC mentions only README + CLAUDE.md.
- A design-only `plugins/tsf/` already exists containing just `DESIGN.md`; it is
  invisible to the marketplace until a manifest and an entry are added.

### 2. Command anatomy (the house style tsf's four commands must match)

**Frontmatter.** No command uses `name:` — the command name is the filename,
namespaced by plugin. Only five keys occur across all 17 command files, always
in this order: `description` → `argument-hint` → `model` → `disable-model-invocation`
→ `allowed-tools`.

- `description` is one sentence; chain commands end it with a workflow-position
  clause ("Step 2 of the tce workflow.", `plugins/tce/commands/research.md:2`).
- `argument-hint` is always a double-quoted bracketed string, e.g.
  `"[ticket-id | plan path]"`.
- `allowed-tools` is comma-separated with the path double-quoted inside
  `Bash(...)`: `allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)`
  (`plugins/tce/commands/research.md:4`); `implement.md` adds
  `Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*)`.
- `model:` appears exactly once, on `implement_eco.md:4` (`sonnet`).

**Body skeleton** (canonical order, from the workflow commands):

1. H1 title in Title Case, not the command name (`# Research Codebase`).
2. Role paragraph, almost always "You are tasked with …".
3. `## Project context` — the runtime-config read block (10 of 13 tce commands;
   never in tmt).
4. `### AskUserQuestion dialog guidelines` — the byte-identical 19-line block,
   in nine files (`plugins/tce/commands/{init,research,plan,ticket,work,quickfix,refresh}.md`,
   `plugins/tmt/commands/{init,update}.md`).
5. `---` rule closing the preamble.
6. `## Workflow Context` table (`| Step | Command | Purpose |`, current step
   bolded and arrow-marked) — only in the four chain-adjacent commands.
7. CRITICAL block(s), either as a heading (`## CRITICAL: YOUR ONLY JOB IS …`)
   or an inline bolded line (`**CRITICAL: This phase MUST produce a research
   document written to disk.**`, `quickfix.md:129`).
8. Input-discovery section (`## Ticket Document Discovery`, 3 numbered steps).
9. Entry-point section (`## Initial Setup:` / `## Initial Response`), whose
   shape is fixed: "1. **Check if parameters were provided** … 2. **If no
   parameters provided**, respond with:" + a fenced literal message ending in a
   `Tip:` line.
10. Ordered execution body in one of three styles: numbered `## Steps to follow`,
    `## Phase N: Title` with `### Na.` sub-steps (used by `init`, `refresh`,
    `work`, `quickfix`, `tmt/init` — the closest match for `/tsf:init` and
    `/tsf:cycle`), or topic sections without global numbering (`implement.md`).
11. Output-document template — either inline in a ` ```markdown ` fence or
    externalised to `references/` and read at point of use.
12. Closing `## Important Rules` / `## Guidelines`; init commands close with
    `## Idempotency` + `## Notes`.

**Reading project config at runtime** — three documented degradation levels:

- *advise-and-continue*: "Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` …
  If it's missing, suggest the user run `/tce:init`."
  (`plugins/tce/commands/research.md:13-17`)
- *fall-back-to-detection*: `plugins/tce/commands/commit.md:15-19`
- *hard stop*: "If the file is missing, tell the user to run `/tce:init` and
  stop." (`plugins/tce/commands/ticket.md:25-28`), plus a **content-keyed
  precondition stop** in `quickfix.md:19`.

**Referencing plugin-shipped files** — three fixed phrasings:

- scripts: `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0001` in a bash
  fence, mirrored in `allowed-tools` (`research.md:94-100`).
- references, at point of use: "Read `${CLAUDE_PLUGIN_ROOT}/references/…` **now
  — in full, even if you read it earlier in this session** — and …"
  (`research.md:266`; `plan.md:348` and `:397` read the same file twice at two
  different moments).
- templates: literal `cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/profile.md"
  "${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md"` (`init.md:317-318`).

**Argument handling.** There is no `ARGUMENTS:` trailer convention. Literal
`$ARGUMENTS` appears in only two files (`review.md:63`, `implement_eco.md:18`);
the dominant pattern is a prose presence check in the entry section. Mode flags
are sniffed from prose: "when the invocation arguments contain `--autonomous`"
(`ticket.md:65-66`).

### 3. Agent anatomy (what tsf's 7 workers + 3 gates should look like)

Seven agent files exist, all auto-discovered (no manifest key). Frontmatter key
order is `name`, `description`, `tools`, [`color`], `model`. **`tools:` is always
a single-line comma-separated scalar, never a YAML list.** `model:` is always
present: `haiku` for the two locators (which lack `Read` entirely), `inherit`
for the other five.

The **three-part constraint envelope** is the load-bearing pattern and the one
DESIGN.md §11.2 explicitly re-uses:

- `## CRITICAL: <ALL-CAPS one-sentence job statement>` placed *before* the
  responsibilities, with 6-8 `DO NOT` bullets and exactly one closing `ONLY …`
  bullet (`plugins/tce/agents/plan-compliance-checker.md:28-35`,
  `codebase-analyzer.md:37-45`).
- `## What NOT to Do` — ~10 `Don't` bullets, after the work sections
  (`plan-compliance-checker.md:81-90`).
- `## REMEMBER: You are a X, not a Y` + 1-2 paragraphs restating the role via a
  metaphor (`plan-compliance-checker.md:92-99`: "A checker prompted to find
  problems always finds some").

`plan-compliance-checker.md` is the direct model for tsf's three gates. Its
structure: role statement (`:8-12`) → `## What you receive` with the isolation
clause (`:14-26`) → `## Verdicts` (closed four-value set, `:37-47`) →
`## Process` (4 steps, `:49-55`) → `## Output Format` ("Emit only this", a
markdown table, `:57-71`) → `## Important Guidelines` (tie-breaking rules,
`:73-79`) → envelope parts 2 and 3. Prohibitions are repeated at three
altitudes: frontmatter `description`, an in-body clause at the point of use, and
the closing `## What NOT to Do`.

Two facts that matter for §11.3's "Internal to `/tsf:cycle`" convention:

- No existing agent file names a spawning command or declares itself
  internal-only. The closest is provenance prose ("This agent ships in the
  **tce** workflow plugin and is stack-agnostic.") and a lifecycle moment in the
  description ("Call it at the end of implementation …").
- Descriptions are written as a pitch addressed to the calling model, in second
  person, often "Call X when …". tsf's "Internal to `/tsf:cycle` — not for
  direct use" prefix would be a new convention in this repo, not a copy of one.

### 4. Scripts, `lib.sh`, and hook idioms

Nine scripts exist (2 tce, 7 tmt). Every one is `#!/bin/bash` and resolves the
project root through its plugin's `lib.sh`, never through its own location.

- **The sourcing idiom** is byte-identical in all seven sibling scripts:
  `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, a
  `# shellcheck source=lib.sh` directive, then `. "$SCRIPT_DIR/lib.sh"`.
  `SCRIPT_DIR` is used *only* to find `lib.sh`.
- **Project root**: `printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"`
  (`plugins/tce/scripts/lib.sh:11-13`, `plugins/tmt/scripts/lib.sh:12-14`).
  `lib.sh` files have no `set` line — pure function definitions, safe to source.
- **Config parsing is `.`-sourcing, not parsing** (`plugins/tmt/scripts/lib.sh:28`):
  the config file is executed as shell, so unknown keys like `TMT_CONFIG_VERSION`
  are inert. Search order is `.claude/tmt/config` then the legacy
  `.claude/tce/config`, breaking on first non-empty value.
- **Error conventions**: user-invoked scripts `echo "Error: …" >&2; exit 1`;
  hook scripts always `exit 0` and communicate only via a
  `{"hookSpecificOutput":{"hookEventName":…,"additionalContext":…}}` heredoc on
  stdout. tmt hook scripts read stdin *before* enabling `set -e`, then install an
  ERR trap (`check-ticket-status.sh:26-30`).
- **JSON escaping** has two variants: jq-free awk (`check-init.sh:105`) and
  `jq -Rs '.'` (tmt's two hook scripts — note `$ESCAPED_FEEDBACK` is
  interpolated *without* surrounding quotes because jq emits them).
- **hooks.json forms**: tce uses **exec form** (`command` = bare path, `args` array
  carrying `"${user_config.show_setup_reminders}"`); tmt uses **shell form** with
  the plugin-root variable explicitly double-quoted inside the JSON string.

**No script in the repo invokes `gh` or any GitHub API.** git usage is two
read-only calls in one hook (`git diff --cached`, `git log`). All existing `gh`
material is *prose* in command markdown (the GitHub Issues backend adapter
examples in `init.md:291,352-357`, the permalink step in `research.md:270-276`).
tsf's `scripts/` would be the repo's first real shell-level GitHub integration.

### 5. Init, templates, references, version markers

**Init phase structure** (the model for `/tsf:init`), from
`plugins/tce/commands/init.md`:

- Preamble: "**Do not write any files until the user confirms** (Phase 4).
  Analyze first, propose, discuss, then write." (`:13-14`)
- `## What gets created` file-tree block *before* any phase (`:36-56`).
- **Phase 0: Preflight** — `command -v git`/`gh` checks that report and continue
  ("these are warnings, not blockers", `:58-70`). tmt escalates a missing `jq` to
  a functional warning (`tmt/init.md:45-55`).
- **Phase 1: Analyze** — numbered detection targets with concrete heuristics
  (manifest/lockfile sniffing, `git log --format=%s -n 30` for commit
  convention, `:140-145`); ordered fallbacks for a single value
  (`tmt/init.md:57-76`); a pass that records superseded artifacts for the
  Phase-3 cleanup.
- **Phase 2: Propose** — a fenced verbatim report template, then dialogs whose
  **copy is frozen into the command** ("Use this copy verbatim — print the
  intro, then ask:", `:191-219`), including an instruction to reorder options by
  detection and the "tool needs ≥2 options" fallback (`tmt/init.md:115-118`).
- **Phase 3: Refine** — iterate; and for non-file backends, "**verify access
  before writing**" by actually running the read mechanism (`:290-292`).
- **Phase 4: Write** — `mkdir -p` + `cp` the skeleton from
  `${CLAUDE_PLUGIN_ROOT}/templates/`, then fill it ("`templates/tce/` is the
  single source of truth for their structure, so don't reproduce it from
  memory", `:311-313`); scaffold directories with `.gitkeep`; final "confirm and
  hand off" fenced block; "Do **not** commit automatically."
- `## Idempotency` — never clobber; show diffs; ask per value. Plus the version
  comparison: same version → "already up to date (v[X.Y.Z])"; older/missing →
  walk through the required config changes, then update the marker (`:444-477`).
- `## Notes` — the settings.json posture (see §9 below).

**Version markers**: `<!-- tce-config-version: FILLED-BY-INIT -->` on line 1 of
the profile skeleton (`plugins/tce/templates/tce/profile.md:1`) and
`TMT_CONFIG_VERSION=` in tmt's shell config
(`plugins/tmt/templates/tmt/config:7-10`). Both are filled from "the `version`
field of `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`".

**Template skeleton conventions**: H1, then a `>` blockquote explaining who
reads the file and how it's maintained; `[bracketed guidance]` /
`` `<command>` `` / `[not set]` placeholder styles; tables with an explicit
"drop rows that don't apply" instruction; a whole option list inside one bracket
where init picks one (`templates/tce/profile.md:53-68`); and one
backend-independent section marked keep-as-is by HTML comment
(`templates/tce/tickets.md:64-91`). tsf's `templates/tsf/config.md` is a
**markdown** config (unlike tmt's shell-sourced one), so it follows the
profile.md/tickets.md prose-skeleton style, not the `KEY=VALUE` style — unless
tsf's scripts need to parse it, which is an open question (see below).

**Reference files** open with an HTML-comment preamble declaring the read-points,
that changes to the file are command-contract changes, and a numbered `Contents:`
list (`plugins/tce/references/research-document-template.md:1-16`,
`plan-document-template.md:1-22`). A single reference file carries **multiple
template sections**, each an H1 with a fenced block, and consumers point at "the
second section of …". Fences use **four backticks** when the template itself
contains fenced blocks (`plan-document-template.md:26`).

`/tce:refresh` is the pattern for re-analysis: it classifies sections as
*factual* (refresh targets) vs *hand-authored* (preserved), flags only
**high-confidence** differences, shows before/after per section, and edits in
place with `Edit` — "never copy a template skeleton over them"
(`plugins/tce/commands/refresh.md:90-146`).

### 6. Claude Code platform mechanics for plugin agents (Q1, Q5)

All from the official docs (`code.claude.com/docs/en/sub-agents`,
`plugins-reference`, `tools-reference`, `skills`), verified 2026-08-11.

**Frontmatter supported for plugin agents** (plugins-reference): `name`,
`description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`,
`skills`, `memory`, `background`, `isolation`. For security, `hooks`,
`mcpServers`, and **`permissionMode` are ignored for plugin-shipped agents** —
so a tsf agent cannot grant itself a permissive posture; that must come from
settings (§9).

- `name` **cannot contain `:`** — "reserved for plugin-scoped identifiers";
  Claude Code refuses to load such a file (v2.1.218+). So the files are
  `agents/triage.md` with `name: triage`, and `tsf:triage` is derived.
- **Namespacing is real and automatic**: "Agents appear in the @-mention
  typeahead under their scoped name, such as `my-plugin:code-reviewer`". A
  subfolder deepens it: `agents/review/security.md` → `my-plugin:review:security`.
  Plugin agents load at **lowest precedence** (5 of 5) — a project or user agent
  with the same `name` wins.
  *Direct confirmation in this session*: the available agent types are listed as
  `tce:codebase-locator`, `tce:plan-compliance-checker`, etc. Note this
  **contradicts** `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md:68-74`
  ("Agents are invoked by bare name, never namespaced"), which described the
  prose convention in tce's commands rather than the tool-level identifier.
- **`tools:` restriction is mechanical**: "A tool you leave out isn't in the
  subagent's session at all… with no permission prompt or error." Restricting to
  `Read, Grep, Glob` does exclude `Bash`, `Write`, `Edit`, `WebFetch`,
  `WebSearch`, and all MCP tools — which is exactly the enforcement §11.2 relies
  on. `disallowedTools` is applied first, then `tools` resolves against the
  remainder.
- **`LS` is not in the current tools reference.** The listed tools are `Agent,
  Artifact, AskUserQuestion, Bash, Cron*, Edit, …, Glob, Grep, ListAgents, LSP,
  Monitor, …, Read, …` — no `LS`. When *nothing* in a `tools` list resolves,
  Claude Code refuses to launch the agent ("would be spawned with zero tools —
  refusing"); behaviour with one bad entry among good ones is **undocumented**.
  tce's shipped agents all list `LS` and work, which is weak evidence that a
  single unresolvable entry is tolerated — but it is not a documented guarantee.
- **`model:`** accepts `sonnet | opus | haiku | fable | <full-id> | inherit`;
  defaults to `inherit`. Resolution order: `CLAUDE_CODE_SUBAGENT_MODEL` →
  per-invocation `model` param → frontmatter → main conversation.
- **Always stripped from every subagent, even if listed**: `AskUserQuestion`,
  `EndConversation`, `Enter/ExitPlanMode`, `ScheduleWakeup`, `TaskOutput`,
  `WaitForMcpServers`, `Workflow`, and `Agent` at the depth limit. **An agent can
  never ask the user a question** — which is consistent with tsf's design (all
  human contact goes through GitHub) but must be remembered when writing worker
  prompts.
- **Background subagents get a narrowed built-in tool set** and, as of v2.1.198,
  subagents run in the background *by default*. The retained set is `Read, Grep,
  Glob, Bash, PowerShell, Edit, Write, NotebookEdit, WebFetch, WebSearch,
  TodoWrite, Skill, ToolSearch, EnterWorktree, ExitWorktree, Monitor, TaskStop,
  SendMessage, Artifact` — everything tsf's workers need, and nothing the gates
  lose. "The same definition can resolve to different tools in the foreground and
  the background."
- **`isolation: worktree`** is supported for plugin agents (only valid value) —
  relevant to §15's future parallelism, out of scope for v1.

**How a command spawns a named agent (Q1).** There is **no documented
tool-call syntax available to a command body**. The documented mechanisms are:

- **Prose delegation** — "For natural language, there's no special syntax. Name
  the subagent and Claude typically delegates: `Use the test-runner subagent to
  fix failing tests`." The SDK docs are stronger: naming the agent "bypasses
  automatic matching and directly invokes the named subagent." This is exactly
  what tce does (`research.md:181`, `implement.md:265-271`).
- **`context: fork` + `agent:` skill frontmatter** — the one *declarative*
  binding, but it runs the **whole command** as one agent ("The skill content
  becomes the prompt that drives the subagent"), so it cannot serve a dispatcher
  that fans out to different agents per cycle. Also undocumented whether `agent:`
  accepts a plugin-scoped name.
- **What crosses the boundary**: "The only content you pass from parent to
  subagent is the Agent tool's prompt string, so include any file paths, error
  messages, or decisions the subagent needs directly in that prompt." A
  non-fork subagent additionally starts with its own system prompt, environment
  details, all CLAUDE.md levels, a git-status snapshot, and any `skills:`
  preloaded content — but **not** the parent's conversation.
- **What comes back**: "a single text result… The parent doesn't see the
  subagent's intermediate tool calls or outputs, only that final result." No
  structured output exists for subagents in interactive Claude Code
  (`outputFormat`/JSON-schema is an SDK `query()`-level option only). So the
  gates' report content must come back as **markdown text the dispatcher then
  writes to `reports/<gate>.md`** — which is exactly §11.2's design.
- Since v2.1.210, subagent output is **scanned** and may be prefixed with a
  `[harness: subagent output matched instruction-shaped pattern(s): …]` marker
  and have `<` escaped inside instruction-shaped text. A dispatcher that writes a
  gate's returned text verbatim into a report file will occasionally carry that
  marker — worth handling.
- **No documented prompt-size limit** for the Agent tool prompt (neither a cap
  nor an explicit "no limit"). This matters because the gates receive a full diff
  inline.
- **Concurrency cap**: 20 concurrent subagents per session
  (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`); no total-per-session cap since
  v2.1.224.

**Subagent nesting (contradicts DESIGN.md §11).** Official: "By default, a
subagent can spawn subagents of its own, **up to three layers below the main
conversation**." History: nesting by default to depth 5 from v2.1.172; default 1
in v2.1.217-218; **default 3 since v2.1.219**. Configurable with
`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (`1` disables). To keep a specific agent
from spawning, "omit `Agent` from its `tools` list or add it to
`disallowedTools`" — which the gates get for free, and which workers would need
explicitly if the design wants to preserve the inline-work property.

**Hiding an agent from ambient context (§11.3).** There is **no plugin-author-side
mechanism**. `disable-model-invocation` and `user-invocable` are *skill* fields
only. The only suppression is consumer-side: `permissions.deny:
["Agent(tsf:triage)"]`, `claude --disallowedTools "Agent(…)"`, or denying the
`Agent` tool entirely. §11.3's accepted trade-off therefore stands as the only
option, and the "Internal to `/tsf:cycle`" description prefix is the whole
mitigation.

### 7. Dispatch and GitHub mechanics (Q2)

Verified locally against **gh 2.97.0** (`gh --version`), which is authoritative
for field availability.

**The scan.** §5.1 says "one gh query for issues carrying `tsf:*` labels +
PR/CI state". That is **not achievable in one `gh` sub-command**, but it is two
cheap ones:

- Issues: `gh issue list --json number,title,labels,createdAt,url,body` — the
  available `--json` fields are `assignees, author, blockedBy, blocking, body,
  closed, closedAt, closedByPullRequestsReferences, comments, createdAt, id,
  isPinned, issueType, labels, milestone, number, parent, projectCards,
  projectItems, reactionGroups, state, stateReason, subIssues, subIssuesSummary,
  title, updatedAt, url`. There is **no `linkedBranches`** field.
  Note `-l/--label` is repeatable with **AND** semantics
  (`gh issue list --label "bug" --label "help wanted"` = both), so "any `tsf:*`
  label" needs either `--search 'label:tsf:ready,tsf:needs-human,…'` (comma = OR
  in GitHub search syntax) or a plain listing filtered with `jq`. Default
  `--limit` is 30.
- PRs: `gh pr list --json number,headRefName,isDraft,statusCheckRollup,reviewDecision,url,closingIssuesReferences`
  — all of those exist. **Because tsf branch names are deterministic
  (`tsf/GH-<n>`), `headRefName` alone joins PRs to tickets** with no linkage
  API needed; `gh pr list --head tsf/GH-123` narrows to one.

So the state machine's inputs (§4) are: labels (issue query), `spec.md`/
`research.md`/`plan.md`/`reports/*` existence (filesystem on the ticket branch),
PR existence + `isDraft` (PR query), CI colour (`statusCheckRollup`), and
approval (`reviewDecision`).

**CI status.** `gh pr checks [<number>|<branch>] --json bucket,name,state,link,workflow,startedAt,completedAt,description,event`.
The `bucket` field "categorizes the `state` field into `pass`, `fail`,
`pending`, `skipping`, or `cancel`" — a ready-made red/green/pending predicate.
**Exit code 8 = "Checks pending"** and it exits non-zero on failure, so any
wrapper script must not run under bare `set -e` without handling that.
`gh pr view --json statusCheckRollup` gives the same rollup in the PR query.

**CI logs for the ci-fix step.** `gh run view <run-id> --log-failed` prints only
failed steps' logs (`--log` for everything, `-j/--job` to narrow). The run id is
reachable from `gh pr checks --json link` or `gh run list --branch tsf/GH-<n>`.
The help text warns that when >25 job logs can't be associated, the operation
fails — worth a fallback.

**Approval.** `gh pr view --json reviewDecision,reviews,latestReviews`
(`reviewDecision` ∈ APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED) is the §9.2
final gate signal, and `reviews` carries the change-request comments that
§9.2 routes back as input.

**Labels.** `gh label create <name> [-c hex] [-d desc] [-f]` — "Create a new
label…, or update an existing one with `--force`", so `/tsf:init`'s label
creation is idempotent with `--force`. Label mutation on issues is
`gh issue edit --add-label/--remove-label`.

**Other verified affordances**: `gh pr list --head <branch>`, `--draft`,
`--base`, `--search`, `--state`; `gh pr create --draft`; `gh pr merge --squash`;
`gh auth status` for the §12 auth check.

**What `scripts/` should wrap** follows from the repo's own conventions rather
than from `gh`: existing scripts wrap things that are (a) multi-step pipelines,
(b) needed by hooks, or (c) usefully allowlistable as a single prefix. The
allowlist angle is the strongest argument here — `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh":*)`
in `allowed-tools` is one rule, whereas inline `gh` calls need several
(see §9's fragility warning about argument-constrained Bash patterns).

### 8. Runners and self-pacing (Q3)

**`disable-model-invocation` conflicts with the `/loop` runner.** Documented
semantics: it "prevent[s] Claude from automatically loading this skill… Also
prevents the skill from being preloaded into subagents. As of v2.1.196, also
prevents the skill from running when a scheduled task fires with the skill as
its prompt." The scheduled-tasks doc is explicit that skills marked
`disable-model-invocation: true` "reach Claude as plain text instead of
executing." `/loop` is built on the same scheduled-task machinery, and the docs
advertise passing a skill as the loop body (`/loop 20m /review-pr 1234`).
→ **DESIGN.md §5.3's `/loop 5m /tsf:cycle` and §12's blanket
`disable-model-invocation: true` cannot both be true.** This also removes the
future "GitHub Action triggers a cycle" path (§15.2) from anything that fires a
flagged skill as a prompt.

**Self-pacing primitives available:**

| Mechanism | Fits `/tsf:run`? |
|---|---|
| `ScheduleWakeup` tool | Documented as internal to a self-paced `/loop` — "you don't call it directly". Also on the always-stripped list for subagents. Not available on Bedrock/Vertex/Foundry. |
| Bash `sleep` | Works, but **"Claude Code never auto-backgrounds a command that starts with `sleep`"**, and it is capped by `BASH_DEFAULT_TIMEOUT_MS` (2 min) / `BASH_MAX_TIMEOUT_MS` (10 min ceiling). A longer sleep is killed, not backgrounded. |
| `Monitor` tool | Runs a background script and streams each stdout line back as an event; docs recommend it over polling. Uses the same permission rules as Bash. Could watch GitHub for answers/approvals instead of re-scanning. |
| `/loop` (fixed or self-paced) | The documented loop. Self-paced picks 1 min–1 h per iteration and can end itself via `ScheduleWakeup(stop: true)`. Blocked by the flag above. |
| `/goal` | Stop-hook wrapper; runs turns back-to-back until a condition model says done. `claude -p "/goal …"` runs to completion in one invocation. |

**Loop/cron limits that bound an overnight run**: tasks are session-scoped and
die with the session; **recurring tasks expire 7 days after creation**; max 50
scheduled tasks per session; recurring fires get up to 30 min of jitter (not
applied to self-paced); a task fires only *between* turns, never mid-response;
missed intervals do not catch up.

**Cost/caching interaction**: "Claude Code sends your full conversation with
every request", and the prompt cache lifetime is **one hour on a subscription**
(five minutes once drawing on usage credits or on an API key). A self-paced
delay near 60 minutes therefore risks a full-context cache miss every
iteration — an argument for the dispatcher context staying thin (which §5.1
already asserts) and for shorter idle delays than the maximum.

**Headless (§5.3 "Future")**: the design's economic premise **currently holds
but is explicitly provisional**. The official support article states: "We're
pausing the changes to Claude Agent SDK usage described below. For now, nothing
has changed: Claude Agent SDK, `claude -p`, and third-party app usage still draw
from your subscription's usage limits." Two ways to lose it accidentally:
`ANTHROPIC_API_KEY` present is "always used when present" in `-p` mode, and
`--bare` "doesn't use your subscription login" at all. For CI without a browser,
`claude setup-token` mints a one-year `CLAUDE_CODE_OAUTH_TOKEN`.

Relevant `-p` flags: `--output-format text|json|stream-json`, `--permission-mode`
(`default|acceptEdits|plan|auto|dontAsk|bypassPermissions|manual`),
`--allowedTools`, `--disallowedTools`, `--max-turns` (print mode only; **exits
with an error when the limit is reached**), `--resume`/`--continue`/`--fork-session`,
`--session-id` (must be a UUID). Slash commands work in `-p`: "include
`/skill-name` in the prompt string and Claude Code expands it before running."

### 9. Permissions, settings, and the unattended posture (§5.3, §12)

**Rule syntax.** Evaluation is deny → ask → allow, first match wins, and
"rule specificity doesn't change the order" — a broad deny cannot carry allowlist
exceptions. `Bash(gh issue:*)` ≡ `Bash(gh issue *)`; the `:*` suffix "is only
recognized at the end of a pattern". A trailing ` *` enforces a word boundary
(`Bash(ls *)` matches `ls -la`, not `lsof`). Shell operators are parsed:
"`&&`, `||`, `;`, `|`, `|&`, `&`, and newlines. A rule must match each subcommand
independently" — confirming this repo's no-chaining rule. Wrappers `timeout,
time, nice, nohup, stdbuf, command, builtin, noglob` and bare `xargs` are
stripped before matching; `npx`, `docker exec`, `devbox run` etc. are **not**.
`watch`, `setsid`, `flock`, and `find -exec/-delete` can never be auto-approved.
Argument-constraining patterns are documented as **fragile** (variables, option
order, and extra spaces all defeat them) — an argument for wrapping tsf's `gh`
usage in scripts.

**The workspace-trust gotcha, which directly affects §12's allowlist offer:**
`permissions.allow` in a project's `.claude/settings.json` is applied "**only
after you accept the workspace trust dialog**"; `.claude/settings.local.json` is
exempt *unless the repository could have supplied it* (i.e. when it is committed
to git). And: "**In non-interactive mode with `-p`, no dialog appears and the
rules stay ignored.**" So an allowlist written to a committed project settings
file is precisely the case that silently fails for the future headless runner.

**Sandbox facts relevant to "permissive inside the cage"**: the Bash sandbox has
**no pre-allowed domains** — the first command needing a new host prompts;
`sandbox.network.strictAllowlist` (v2.1.219+) denies instead of prompting but
"setting it in a repository's `.claude/settings.json` or `.claude/settings.local.json`
has no effect" (user/managed/CLI only). Credential masking exists with
`injectHosts` (the docs' own example masks `GH_TOKEN` for `api.github.com`).
Even in sandbox auto-allow mode, "content-scoped ask rules like
`Bash(git push *)` still force a prompt". And plugin agents cannot set
`permissionMode`, so the unattended posture must be a session/settings decision,
never something a tsf agent grants itself. `dontAsk` mode ("auto-denies tools
unless pre-approved") is the documented shape for unattended runs that should
fail rather than hang.

**Repo posture on settings.json**: both inits state "This command never edits
`.claude/settings.json`" (`plugins/tce/commands/init.md:479-483`), with exactly
one sanctioned, approval-gated exception in `/tmt:init` (removing two legacy
PostToolUse entries, `plugins/tmt/commands/init.md:176-190`). **No command in the
repo currently writes `permissions.allow` entries** — `/tsf:init`'s allowlist
offer (§12) would be the first, and it lands against an explicit existing rule.

### 10. Where DESIGN.md's premises meet current platform reality

Recorded as facts, not as proposals — the ticket reserves design changes for
discussion.

| DESIGN.md statement | Current platform fact |
|---|---|
| §11: "subagents cannot spawn subagents" (shapes the roster; steps "work inline") | Nesting is on by default to depth 3 (v2.1.219+), configurable; opt out per agent by omitting `Agent` from `tools`. |
| §12: all four commands `disable-model-invocation: true` + §5.3 `/loop 5m /tsf:cycle` | A flagged skill passed as a loop/scheduled-task prompt "reach[es] Claude as plain text instead of executing." Mutually exclusive. |
| §11.2: gates get `tools: Read, Grep, Glob, LS` | `LS` is not in the current tools reference. All-unresolvable lists are refused; partial-unresolvable is undocumented. |
| §5.1: "one gh query for issues carrying tsf:* labels + PR/CI state" | No built-in `gh` *sub-command* does it; two (`gh issue list`, `gh pr list`) joined on the deterministic `tsf/GH-<n>` head branch do, and a hand-written `gh api graphql` query does it in one call (see Follow-up Research). `--label` is AND, so multi-label OR needs `--search` or jq. |
| §5.3: "`claude -p` under Pro/Max draws from the subscription allowance" | True today, and explicitly a *paused* policy change, not a stable guarantee. Silently voided by `ANTHROPIC_API_KEY` or `--bare`. |
| §12: "offers the permission allowlist for unattended runs" | Allow rules in committed project settings need workspace trust, which never appears under `-p`. Also the repo's first settings.json write of this kind. |
| §11.3: agent descriptions sit in ambient context, mitigated by a prefix | Confirmed: no plugin-side hiding mechanism exists; only consumer-side `permissions.deny: Agent(name)`. |
| §6 common contract: workers post comments, ask nothing | Consistent — `AskUserQuestion` is stripped from every subagent regardless of frontmatter. |

## Code References

- `.claude-plugin/marketplace.json:10-23` — plugin entry shape (`name`, `source`, `description`, `version`)
- `plugins/tce/.claude-plugin/plugin.json:1-23` — manifest keys incl. the `userConfig` entry shape
- `plugins/tce/commands/research.md:1-5` — workflow-command frontmatter with `allowed-tools`
- `plugins/tce/commands/work.md:1-6` — composite frontmatter with `disable-model-invocation`
- `plugins/tce/commands/implement_eco.md:1-6` — the only `model:` override in the repo
- `plugins/tce/commands/research.md:19-37` — the byte-identical AskUserQuestion block (9 copies)
- `plugins/tce/commands/research.md:13-17` — the `## Project context` runtime-config read
- `plugins/tce/commands/research.md:94-100` — `${CLAUDE_PLUGIN_ROOT}/scripts/…` invocation shape
- `plugins/tce/commands/research.md:266` — point-of-use reference read phrasing
- `plugins/tce/commands/implement.md:244-271` — the plan-compliance gate: criteria assembly, diff assembly, delegation
- `plugins/tce/commands/init.md:36-56` — "What gets created" block; `:58-70` Phase 0 preflight; `:309-329` Phase 4 write; `:444-477` Idempotency + version comparison; `:479-488` the settings.json posture
- `plugins/tce/commands/refresh.md:90-146` — factual-vs-hand-authored classification, high-confidence gate, edit-in-place
- `plugins/tce/agents/plan-compliance-checker.md:14-26` — the isolation clause; `:37-47` verdict vocabulary; `:57-71` "Emit only this" output; `:28-35`/`:81-90`/`:92-99` the three-part envelope
- `plugins/tce/agents/codebase-analyzer.md:37-45,142-155,157-161` — the same envelope re-pointed to a documentarian
- `plugins/tce/scripts/lib.sh:11-13` — `tce_project_root`
- `plugins/tmt/scripts/lib.sh:12-14,25-34,40-42` — project root, config sourcing with legacy fallback, status enum
- `plugins/tmt/scripts/check-ticket-status.sh:26-30,101-115` — stdin-then-`set -e` ordering and the hook output envelope
- `plugins/tce/hooks/hooks.json:1-16` — exec form with `${user_config.*}` in `args`
- `plugins/tce/references/research-document-template.md:1-16` — reference-file preamble convention
- `plugins/tce/templates/tce/profile.md:1` — the `<!-- tce-config-version: … -->` marker
- `plugins/tmt/templates/tmt/config:7-10` — the `TMT_CONFIG_VERSION=` marker
- `plugins/tmt/commands/init.md:176-190` — the one sanctioned, approval-gated settings.json edit
- `README.md:17-20` and `CONTRIBUTING.md:29-48` — the two catalog/layout surfaces that list plugins

## Architecture Documentation

- **Auto-discovery everywhere.** Neither `plugin.json` declares `commands`,
  `agents`, or `hooks`; all three are found by directory convention. Adding
  `plugins/tsf/{commands,agents,scripts,references,templates}/` plus a manifest
  and a marketplace entry is the whole registration story.
- **Two config registers.** tce's project config is *prose markdown read by the
  model* (`profile.md`, `tickets.md`); tmt's is *machine-readable shell sourced
  by scripts* (`.claude/tmt/config`). DESIGN.md §12 puts tsf's config in the
  first register (`config.md`) while also giving tsf `scripts/` — if any tsf
  script needs the factory-clone path or the CI-fix bound, it will have to parse
  markdown, or the config will need a machine-readable companion. Unresolved.
- **The three sync-rule shapes in CLAUDE.md** that a new plugin may need to
  join: byte-identical duplication (AskUserQuestion block), semantic mirroring
  (composite-tracking, TP-0013 re-read, TP-0022 sufficiency), and
  ownership-boundary rules (tce/tmt). tsf is standalone (§2), so it inherits
  none of them automatically — but its own dispatcher/agent split reproduces the
  same drift hazard: `/tsf:cycle`'s dispatch table (§4) and the agents' own
  label-adjustment duties (§6 common contract) are two descriptions of one
  state machine.
- **Auto-compaction survivability** (why §6's re-read discipline is right):
  project-root CLAUDE.md and auto memory are re-injected from disk after
  compaction; *invoked skill bodies* are re-attached only to a 5,000-token-per-skill
  / 25,000-token-total budget, oldest dropped first; **skill descriptions are not
  re-injected at all**; `paths:`-scoped rules and nested CLAUDE.md are lost until
  re-read. Truncation keeps the *start* of a file. This is the platform-level
  justification for both this repo's point-of-use reference reads and DESIGN.md's
  "re-read all input artifacts from disk" contract.
- **Repo working convention vs current state**: CLAUDE.md and
  `CONTRIBUTING.md:57` both say "Work directly on `main` — this repository uses
  no branching or PR strategy", but the current checkout is on branch
  `tsf-design` (clean, at `99605c3`). Worth resolving before the implementation
  produces commits.

## Historical Context (from thoughts/)

- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` — the
  background review DESIGN.md came out of. Establishes the seven-layer factory
  reference architecture, the documented failure modes (DORA amplification,
  rubber-stamp review past ~400-line diffs, the "80% problem", spec drift), and
  the practitioner lesson that "a checker agent that sees the implementer's
  reasoning will rationalize gaps" — the direct ancestor of §7's context-starved
  gates. Also the source of §9.1's dossier reasoning (Finster).
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` —
  established that commands *are* skills and share the skill frontmatter menu;
  the `disable-model-invocation` semantics (blocks Skill-tool invocation
  entirely + removes the description from context); that `allowed-tools` is a
  *permission grant*, not a restriction, while an agent's `tools` is an
  *availability allowlist* with no permission grant; and the standing caveat
  that `${CLAUDE_PLUGIN_ROOT}` substitution *inside frontmatter* is
  undocumented (only `${CLAUDE_PROJECT_DIR}` is, v2.1.196+) — which matters
  because tsf's commands will want `allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/…":*)`.
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` — the
  design record for the context-starved gate: criteria passed **verbatim in the
  prompt** rather than read from files (reading them "would defeat the
  adversarial isolation"), the diff computed by the caller because a read-only
  agent has no Bash, `profile.md` deliberately withheld, the four-verdict
  vocabulary, and markdown (not machine-parsed) output. Its claim that agents are
  "invoked by bare name, never namespaced" is superseded (see §6).
- `thoughts/shared/research/2026-07-12-TP-0024-eco-implement-wrapper-sonnet.md` —
  `model:` on a command applies "for the rest of the current turn"; whether it
  propagates through a Skill-tool-nested command is undocumented, with a
  precedent (issue #17283) of a frontmatter field failing to propagate that way.
- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md`
  — the origin of the `references/` mechanism and the point-of-use read rule.
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — the
  review that generated TP-0015…TP-0022.

## Related Research

- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` (design background)
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` (frontmatter machinery)
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` (context-starved gate)
- `thoughts/shared/research/2026-06-12-TP-0003-init-upgrade-migration.md` (version markers, init idempotency)
- `thoughts/shared/research/2026-07-10-TP-0023-merge-status-file-into-plan.md` (why `.status.md` files are legacy)

## Open Questions

Design-level items that surfaced from platform facts and are **for discussion,
not unilateral resolution** (ticket "Out of Scope": "material deviations from
DESIGN.md require discussion"):

1. **`/tsf:cycle` invocation flag vs the `/loop` runner** — §12's blanket
   `disable-model-invocation: true` forecloses §5.3's supervised-burst runner
   and the §15.2 Action trigger. Which one gives way?
2. **The nesting premise** — now that subagents may nest to depth 3, does §11's
   "each step works inline" stay a deliberate design choice (and get enforced by
   omitting `Agent` from worker `tools`), or is fan-out inside the research step
   reconsidered?
3. **`/tsf:run`'s pacing mechanism** — with no callable wait primitive, the
   realistic shapes are bounded `sleep` in Bash (≤10 min ceiling, never
   backgrounded), `Monitor` on a GitHub poll, or dropping `/tsf:run` in favour of
   `/loop` (which requires resolving item 1).
4. **`tools:` list for the gates** — drop `LS`, keep it for symmetry with tce's
   agents, or add `LSP`?
5. **Is `.claude/tsf/config.md` also machine-readable?** If any tsf script needs
   the factory-clone path or the CI-fix attempt bound, prose markdown is the
   wrong register for it.
6. **Where the `/tsf:init` allowlist is written** — a committed project
   `settings.json` needs workspace trust (and is ignored under `-p`); the repo's
   current rule says init commands never write settings.json at all.
7. **Branch/PR convention for this ticket's own implementation** — the repo says
   "always work on `main`", but the work is currently on `tsf-design`.

Mechanical items not resolved by research and best settled during planning:

8. Which §6 step content lives in agent system prompts vs `references/templates/`
   (Q5). The repo pattern points to: *procedure* in the agent prompt, *document
   skeletons* in point-of-use reference files — the split tce already uses
   between `commands/*.md` and `references/*.md`.
9. Whether `${CLAUDE_PLUGIN_ROOT}` substitutes inside `allowed-tools` frontmatter
   (undocumented; TP-0017 flagged the same gap and it remains open). Needs an
   empirical check in a scratch project.

## Follow-up Research 2026-08-11T18:23:00Z

The `gh`-CLI web research (outstanding when the document was first written)
returned. It confirms the locally-verified facts above and adds the following,
sourced from `cli.github.com/manual`, GitHub Docs, and the `cli/cli` source on
`trunk`.

### §5.1's "one gh query" *is* achievable — via GraphQL

The correction to the table row above: no built-in `gh` sub-command returns
issue + linked PR + CI status together, but `gh api graphql` does it in one
call. A working shape (the `statusCheckRollup` fragment is copied from `gh`'s
own `api/query_builder.go`, i.e. exactly what `gh pr view --json
statusCheckRollup` sends):

```
search(query: $q, type: ISSUE, first: $n) { nodes { ... on Issue {
  number title url createdAt labels(first: 20) { nodes { name } }
  closedByPullRequestsReferences(first: 5) { nodes {
    number url state isDraft reviewDecision mergeStateStatus mergeable headRefName
    commits(last: 1) { nodes { commit { statusCheckRollup { state
      contexts(first: 100) { checkRunCountsByState { state count } ... } } } } } } } } } }
```

Trade-offs recorded rather than decided:

- **Cost.** `cli/cli#7421` documents that using the aggregate fields
  (`checkRunCount`, `checkRunCountsByState`, `statusContextCount`,
  `statusContextCountsByState`) instead of enumerating `contexts.nodes` cut
  query time by 1-2s on large repos; `cli/cli#13433` reports `gh`-issued OAuth
  tokens hitting the GraphQL points limit. A query nesting
  search → issues → PRs → commits → rollup is the expensive shape.
- **Coverage.** `closedByPullRequestsReferences` only covers *closing*
  references, and `gh` hardcodes its sub-selection to `id, number, url,
  repository` — so via `--json` you get the PR number and URL only, never its
  state or CI. A PR that merely mentions `#123` is invisible to it. Community
  discussion #40860 further reports `linkedBranches` empties out once a branch
  becomes a PR, with `timelineItems(itemTypes: [CONNECTED_EVENT,
  CROSS_REFERENCED_EVENT])` as the reliable signal.
- This is moot for tsf as designed: the deterministic `tsf/GH-<n>` branch name
  makes `headRefName` the join key, so none of GitHub's linkage machinery is
  needed. It matters only if the design ever drops the naming convention.
- **Label wildcards do not exist server-side.** `--label` is repeatable and
  AND-ed (`pkg/search/query.go` emits repeated `label:x label:y`). The three
  options are: enumerate via `gh label list --json name` and OR them in
  `--search 'label:"a","b"'`; over-fetch and prefix-filter with `--jq`; or the
  GraphQL search query above.

### Exit-code semantics (the scripting traps)

Traced through `internal/ghcmd/cmd.go`: `exitOK 0`, `exitError 1`,
`exitCancel 2`, `exitAuth 4`, `exitPending 8`.

- **`gh pr checks`**: `0` all passed; `1` any failed **or the PR has no checks
  at all** ("no checks reported on the '%s' branch"); `8` any pending. So the
  §6.7 "read CI at pickup" step must distinguish 1 from 8, and must
  disambiguate "failed" from "no checks" by inspecting the output. Also
  `cli/cli#9682`: `--required` fails when there are no required checks.
- **`gh auth status --json` always exits 0** "regardless of any authentication
  issues, unless there is a fatal error". §12's auth verification must either
  use the bare command's exit code or inspect `.hosts[…][].state`. The `--json`
  flag itself requires gh ≥ 2.81.0 (`cli/cli#11544`).
- **Exit code 4 from *any* `gh` command** means an auth error — a usable global
  "credentials died mid-run" signal for an unattended dispatcher.
- `gh pr view` always exits 0 and returns the raw rollup, making it the safer
  shape when the dispatcher wants data rather than a signal.

### Comment, issue-body, and PR affordances the design calls for

- **§10 "exactly one comment"**: `gh issue comment --edit-last --create-if-none
  --body-file -` maintains a single self-updating comment without spamming the
  thread. (`--create-if-none`'s introduction version is unconfirmed.)
- **§3.2's marker block**: there is **no append primitive** — `--body`/
  `--body-file` replace the whole body, so the pattern is read
  (`gh issue view --json body --jq -r '.body'`) → splice → write back
  (`gh issue edit --body-file -`). Critically, this `PATCH` has **no
  optimistic-concurrency check**: two interleaved dispatcher runs lose an
  update. An append-only comment is the collision-free alternative.
- **§9.3 integration**: `gh pr merge --squash --match-head-commit <SHA>` refuses
  the merge if anyone pushed since the check — race-safe integration for free.
  `gh pr update-branch [--rebase]` (gh ≥ 2.53.0) is the documented way to bring
  a behind branch forward; it no-ops with "PR branch already up-to-date" and
  reports "merge conflict between base and head" on conflict. The state signal
  is `mergeStateStatus` ∈ `CLEAN` / `BEHIND` / `BLOCKED` / `DIRTY`, which is a
  cheap machine input for §9.3's escalation decision.
- **A new argument for the §9.3 squash decision**: `--subject`/`--body` are
  meaningless for `--rebase` (there is no single commit to title), so
  **`--squash` is the only strategy that gives the integration agent control
  over the commit message** — which §9.3 requires ("one well-formed
  conventional commit message referencing `GH-<n>`").
- **§6.6 draft PR**: `gh pr create --draft` prints the created PR's URL on
  success (capture stdout for the number); `gh pr ready` un-drafts,
  `--undo` re-drafts.
- `gh label create --force` updates an existing label instead of failing, and
  without `--color` a **random** colour is assigned — so §12's label creation
  should always pass `--color` for stable colours across re-runs.

### Auth scopes for §12's preflight

`gh`'s own minimum for classic tokens is `repo` + `read:org` (+ `gist`), per
`pkg/cmd/auth/shared/login_flow.go`. For everything tsf does, `repo` covers
issues, labels, PRs, comments, merging, and reading Actions runs/logs. Two
additions worth stating in the preflight:

- **`workflow`** is needed to *push* changes to `.github/workflows/**`. Reading
  run logs does not need it, but a `ci-fix` step that edits CI config will have
  its push rejected without it — a silent failure mode for the factory.
- `read:project` is needed for the `projectCards`/`projectItems` JSON fields and
  is not granted by default (`cli/cli#11308`). tsf does not use them.

Fine-grained-PAT equivalents (flagged by the researcher as derived, not quoted,
because the docs page fetched without its permissions table): Issues RW,
Pull requests RW, Contents RW, Actions R, Metadata R.

**Relevant to §15.2 (the future Action trigger):** the default `GITHUB_TOKEN`
**cannot trigger workflow runs on PRs it creates**. A factory running inside
Actions would open PRs on which CI never fires — which would break the §6.7
"CI-green gates everything" premise. Not a v1 concern (v1 runs locally against
the user's own `gh` auth), but it constrains the migration path.

### Version floors for the features cited

`gh pr checks --json`/`bucket` ≥ 2.50.0; `gh pr update-branch` ≥ 2.53.0;
`--json closedByPullRequestsReferences` ≥ 2.73.0; `gh auth status --json` ≥
2.81.0. The local install is **gh 2.97.0**, so all are available here, but
`/tsf:init`'s preflight may want a `gh --version` floor rather than only a
presence check (tce's Phase 0 checks presence only).
