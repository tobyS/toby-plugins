---
date: 2026-09-16T06:02:16Z
git_commit: 84009343281624bef2e52a9c8d94b8450c558182
branch: tsf-design
repository: toby-plugins
topic: "TP-0034a — tsf slice 1: the plugin scaffold, /tsf:init, /tsf:spec and the /tsf:cycle dispatcher up to the plan gate"
tags: [research, codebase, tsf, plugin-scaffolding, dispatcher, agents, github-rest, github-actions, loop, permissions]
status: complete
last_updated: 2026-09-16
---

# Research: TP-0034a — tsf slice 1 (foundation, init, spec, cycle to the plan gate)

**Date**: 2026-09-16T06:02:16Z
**Git Commit**: 84009343281624bef2e52a9c8d94b8450c558182
**Branch**: tsf-design
**Repository**: toby-plugins

## Research Question

TP-0034a asks for the first of three slices of the tsf plugin: the scaffold,
`/tsf:init`, `/tsf:spec`, and a `/tsf:cycle` dispatcher covering DESIGN.md §4
rows 1–4 and 13 (distill, triage, research, plan, skip parked), with the
dispatcher owning every GitHub write from the start. Its "Questions for
Research/Planning" name seven implementation-mechanical unknowns: the agent
result-block format and how the dispatcher parses it; whether `config.md` needs
a machine-readable companion; where the allowlist is written given
workspace-trust rules; how the closing report conveys a wait suggestion to the
self-paced `/loop`; whether worker agents stay inline; which agent folds a
research-parked answer; and whether `/tsf:spec` and `/tsf:init` go through the
one REST write helper.

This research documents what exists — the repo's house style for every artifact
tsf needs, the platform mechanics the dispatcher depends on, the GitHub REST
surface for slice 1's operations, and the verified environment of the first
consumer project.

## Summary

**The house-style half is fully determined by the repo, with no invention
required.** tce, tmt and tle between them demonstrate every artifact type slice
1 needs. Three patterns are directly transplantable and are the backbone of the
implementation:

1. **The `report()` stdout contract** (`plugins/tce/scripts/baseline.sh:46-51`,
   `plugins/tce/scripts/branch.sh:81-86`) — a fixed set of `key: value` lines
   then `exit 0`, with only usage errors and "not a git repository" exiting
   non-zero. This is exactly the shape tsf's scan and write helpers need, and it
   lets the script body be a flat sequence of guards with no `else` branches.
2. **The four-part verbatim dialog frame** used at every dialog site in
   `plugins/tce/commands/init.md` and `plugins/tmt/commands/init.md`: a sentence
   naming the topic and pointing at the guidelines, "Use this copy verbatim —
   print the intro, then ask", a fenced `Intro (message above the dialog):`, and
   `Question: "…" — header: "…", options:` with `**Label** — description`.
3. **The one-iteration-per-turn dispatcher** of `plugins/tle/commands/run.md` —
   invariants above `## Project context` (truncation keeps the start of a file),
   bare-bolded agent names, a `MANDATORY OUTPUT` artifact gate per dispatch, and
   a machine-parsed `<!-- verdict-vector -->` block.

**The platform half is settled but for one material conflict with a DESIGN.md
premise.** Since **fork mode became the interactive default (v2.1.232)**, the
sub-agents docs state that in an interactive session Claude Code "runs the
subagent in the background, forks and non-fork subagents alike, **and Claude
can't ask for the foreground**." DESIGN.md requires foreground dispatch in four
places (§5.1 step 5, §7, §11, §16.25) and the epic's acceptance criteria make it
a cross-cutting rule. A command body cannot satisfy it by prose; the only levers
are consumer-set environment variables. This is recorded as the first open
question and is **for discussion, not unilateral resolution** — the ticket
reserves design changes for discussion.

**Three findings change the shape of slice 1's mechanics**, each replacing a
premise that would otherwise have been assumed:

- **The scan cannot use `/search/issues`.** The first consumer's proxy scopes
  GitHub access to `/repos/{owner}/{repo}/**` (plus `GET /` and `GET /user`), so
  the search endpoint is denied outright; it is additionally an index with no
  freshness guarantee and a 30 req/min limit. `GET /repos/{o}/{r}/issues?state=open`
  with client-side `jq` filtering on the `tsf:` prefix is the only shape that
  works — and it sidesteps the fact that whether `labels=a,b` means AND or OR is
  **undocumented by GitHub**.
- **A skill's `allowed-tools` is never gated by workspace trust**, in any
  session, including `claude -p` in a folder that was never trusted — whereas a
  project's `permissions.allow` is ignored until the trust dialog is accepted and
  the dialog never appears under `-p`. That makes command frontmatter, not
  `settings.json`, the reliable place for the grants an unattended run needs.
- **`${CLAUDE_PLUGIN_ROOT}` substitution inside `allowed-tools` frontmatter is
  now explicitly documented** for plugin skills. The repo's existing grants were
  on undocumented ground (flagged as an open question by TP-0017 and again by the
  epic research); they are now sanctioned.

**Two of the ticket's seven planning questions are answered outright** by
observation rather than by inference: the harness marker on agent output was
observed twice in this session's own subagent returns, and the allowlist question
is reframed by the workspace-trust finding above. The rest are narrowed to
concrete options, recorded under Open Questions.

## Detailed Findings

### 1. What tsf must add to this marketplace

Registration is entirely convention-driven — no manifest key lists commands,
agents, hooks or templates; all are auto-discovered from their directories.
`plugins/tsf/` exists today containing **only `DESIGN.md`** and is invisible to
the marketplace until a manifest and an entry exist.

**Plugin manifest** — the field set in use across all three plugins is `name`,
`version`, `description`, `author{name,email}`, `keywords[]`, plus `userConfig`
on tce alone. tmt's and tle's manifests have no `userConfig`.

**Marketplace entry** — `.claude-plugin/marketplace.json` has top-level `name`,
`metadata.description`, `owner{name,email}`, `plugins[]`; each entry uses exactly
four keys in order: `name`, `source` (`"./plugins/tsf"`), `description` (shorter
than the manifest's), `version` (mirroring the plugin's own).

**Validation baseline (run at research time, all green):** `claude plugin
validate .`, `./plugins/tce` and `./plugins/tle` all pass. Notably, the tle plan
recorded that `claude plugin validate ./plugins/tle` **accepts a manifest-only
plugin** (`plans/2026-08-19-TP-0025-…:297-298`), so a scaffold phase stands on
its own.

**Docs surfaces that enumerate plugins** — four, not two: `README.md:19-23`
(the catalog table), `CONTRIBUTING.md:32-57` (the repository-layout tree),
`CLAUDE.md` (layout block + rule sections), and `.claude/tce/profile.md:27-48`
(the code map and the "three plugins" sentence). The tle plan updated all four
in its Phase 5 (`plans/2026-08-19-TP-0025-…:872-928`). TP-0034a's ACs name only
`CLAUDE.md`; the root `README.md` catalog is explicitly deferred to TP-0034c.

### 2. Command anatomy and the invocation-flag classification

**Frontmatter.** No command uses `name:` — the command name is the filename,
namespaced by plugin. Five keys occur across all 20 command files, always in this
order: `description` → `argument-hint` → `model` → `disable-model-invocation` →
`allowed-tools`.

- `argument-hint` is a double-quoted bracketed string; note tle's deliberate
  distinction between required and optional: `"<goal-file>"` (run.md) versus
  `"[goal description]"` (define.md).
- `allowed-tools` is comma-separated on one line, with the script path
  double-quoted *inside* `Bash(...)` and `:*` outside the quotes:
  `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`
  (`plugins/tce/commands/research.md:4`). Plain git grants use the unquoted form
  `Bash(git diff:*)`.
- `model:` appears exactly once on a command, `implement_eco.md:4` (`sonnet`).

**The flag classification for tsf is already fixed by DESIGN.md §12 and matches
TP-0017's rule**: `init` and `spec` carry `disable-model-invocation: true`;
**`cycle` must not**, because `/loop` fires it as a prompt. This is now
documented platform behaviour rather than lore — the scheduled-tasks page lists
"Skills marked `disable-model-invocation: true`" among the things that "reach
Claude as plain text instead of executing" when a scheduled fire passes them as
the prompt. tle's `/tle:run` is the precedent, and its plan states the rule
positively: "the flag is never written as `false`, it is omitted."

**Body skeleton** (canonical order): H1 in Title Case → role paragraph →
`## Project context` (the runtime-config read block) → `### AskUserQuestion
dialog guidelines` (where there is a dialog site) → `---` → `## Workflow
Context` table → CRITICAL block(s) → input-discovery section → `## Initial
Setup` (the two-branch parameter check ending in a fenced usage message) →
ordered execution body → closing `## Important Rules`. Init commands close with
`## Idempotency` + `## Notes` instead.

tle's `run.md` deviates deliberately and instructively: its four invariants sit
at lines 10–18, **before** `## Project context`, with an explicit precedence
clause — "These govern everything below. If anything later in this file appears
to conflict with them, they win." The tle plan's automated success criteria
asserted that placement (`:790-793`), because compaction truncation keeps the
start of a file.

### 3. The init model for `/tsf:init`

`plugins/tce/commands/init.md` (575 lines) is the template; `plugins/tmt/commands/init.md`
(247) is the same structure at smaller scale; `plugins/tce/commands/refresh.md`
(164) is the re-analysis counterpart.

**Phases**: `## Phase 0: Preflight — check dependencies` → `## Phase 1: Analyze
the project` → `## Phase 2: Propose` → `## Phase 3: Refine` → `## Phase 4: Write
(only after explicit confirmation)` → `## Idempotency` → `## Notes`. The write
gate is carried in the heading itself, and restated in the preamble: "**Do not
write any files until the user confirms** (Phase 4). Analyze first, propose,
discuss, then write." (`init.md:13-14`).

**Preflight style** — `command -v X >/dev/null && echo "ok" || echo "MISSING
(why)"` one-liners, then a bullet per non-fatal case naming *which command* needs
the tool and *under what condition* it escalates from optional to required, then
"Continue with setup regardless — these are warnings, not blockers."
(`init.md:63-70`). tmt's spells the consequence out in three parts — what breaks,
what still works, how to fix it (`tmt/init.md:47-55`).

**Detection heuristics** are written as evidence-file enumerations with explicit
fallback chains and a closing "This is only a suggestion" (`init.md:80-155`).
The branch-convention item (`:146-155`) is the closest model for tsf's GitHub
coordinates: a *fact* with a fallback chain (base branch from
`git symbolic-ref --short refs/remotes/<remote>/HEAD`, else current branch, else
"no remote") plus a *model guess* from history, each labelled.

**The verbatim dialog frame** (four parts, used at five sites in tce's init and
two in tmt's) is quoted in the Summary above. Two sub-patterns matter for tsf:
the **reorder-by-detection instruction** ("Move the system detected in Phase 1 to
position 1, append ' (Recommended)' to its label, and prefix its description with
the detection reasoning", `init.md:224-229`), and the **computed-option list**
where labels are bracketed placeholders and a paragraph explains how to reach the
tool's two-option minimum (`tmt/init.md:92-118`).

**Phase 4's template contract**: `mkdir -p` then `cp
"${CLAUDE_PLUGIN_ROOT}/templates/…" "${CLAUDE_PROJECT_DIR}/…"`, then fill —
"`templates/tce/` is the single source of truth for their structure, so don't
reproduce it from memory" (`init.md:369-377`). The version marker is filled "with
the installed plugin version (the `version` field of
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`)" (`:384-386`).

**Idempotency** is a two-outcome version comparison — same version → "already up
to date (v[X.Y.Z])"; older or missing → walk through the required changes, then
update the marker — followed by a **dated upgrade list** where each bullet names
the missing artifact, the version that added it and why, the exact insertion
point, and where the value comes from (re-ask / derive / never guess)
(`init.md:526-553`).

**Verifying access before writing config** already exists as a pattern:
"For non-file ticket systems, **verify access before writing**: ask the user for
an existing ticket reference and try the read mechanism … `tickets.md` must only
document mechanisms that actually work." (`init.md:348-351`). DESIGN.md §12's
contract check and credential check are the stricter variant of this.

**Printing a checklist the command cannot apply** is also an established pattern
— `/tce:ticket` prints a finished ticket for the user to paste when creation is
not allowed (`ticket.md:250-257`), `/tle:define` prints the `/goal` condition
"with a note that `/goal` is a built-in and cannot be invoked on the user's
behalf, which is why this paste is manual" (`define.md:197-207`). DESIGN.md
§12 already chose this shape for the ruleset settings.

**The settings.json posture** is the constraint on `/tsf:init`'s allowlist offer:
both inits state "This command never edits `.claude/settings.json`", with exactly
one sanctioned exception in the whole repo — `/tmt:init` removing two legacy
PostToolUse entries, approval-gated, "edit surgically: remove only those two
entries …; every other key stays byte-identical" (`tmt/init.md:176-190`). See
finding 9 for why the platform now points away from `settings.json` anyway.

**`/tce:refresh`'s classification** — factual sections (Tech stack, Commands,
Code map, Commit convention, the backend adapter) are refresh targets;
hand-authored ones (Conventions, Branch convention, Preferred research sources,
the policy choices) are preserved; only **high-confidence** differences are
flagged; writes are `Edit` in place, "never copy a template skeleton over them"
(`refresh.md:95-152`).

### 4. Agent anatomy: two tool-scoping idioms

Eleven agent files exist (7 tce, 4 tle), all auto-discovered. **The repo contains
two distinct idioms**, and DESIGN.md prescribes the older one:

- **tce — `tools:` allowlist.** A single-line comma-separated scalar, never a
  YAML list. `plan-compliance-checker.md:4` is `tools: Read, Grep, Glob, LS`,
  which is what §11.2 prescribes for tsf's gates (minus `LS`, dropped by §16.14).
  `model:` is always present: `haiku` for the two locators, `inherit` for the
  rest.
- **tle — `disallowedTools:` denylist, no `tools:` key at all.** E.g.
  `loop-verifier.md:5` is `disallowedTools: AskUserQuestion, Edit, NotebookEdit,
  Task`. tle's README explains the motive: the agents "inherit whatever MCP tools
  your project has", which an allowlist would foreclose. All four deny
  `AskUserQuestion` and `Task`.

This is a live choice for tsf's eleven agents. The gates want the allowlist
(mechanical read-only enforcement is the point of §11.2); the workers need Bash
and the project's commands, which is the case tle's denylist was designed for.

**Model pins** — tle pins deliberately (`sonnet` for verifier and implementer,
`opus` for the spec-planner, `inherit` for the define-time critic), per TP-0029
and the CLAUDE.md rule that the pins are load-bearing for an unattended loop's
cost. tsf's loop is likewise unattended; the pins are an open decision its plan
must make explicitly.

**The three-part constraint envelope** is the load-bearing pattern §11.2 reuses:
`## CRITICAL: <ALL-CAPS one-sentence job statement>` with `DO NOT` bullets and
exactly one closing `ONLY …` bullet, placed *before* the responsibilities; then
`## What NOT to Do` (~10 `Don't` bullets) after the work sections; then
`## REMEMBER: You are a X, not a Y` restating the role via a metaphor.
`plugins/tce/agents/plan-compliance-checker.md:28-35,73-99` is the direct model
for tsf's gates, down to the tie-break rule and the "Emit only this" output
section. Its closing line — "A checker prompted to find problems always finds
some" — is the reasoning the gates inherit.

**Two facts about the "Internal to `/tsf:cycle`" convention (§11.4)**: no
existing agent file names a spawning command or declares itself internal-only,
and tle's four agents are phrased purely functionally (three end "Returns one
line."). The prefix would be a **new convention in this repo**, not a copy of
one. There is no plugin-author-side mechanism to hide an agent's description from
ambient context; the only suppression is consumer-side (`permissions.deny:
["Agent(tsf:triage)"]`), so §11.4's accepted trade-off stands as the only option.

### 5. The dispatcher precedent: `/tle:run`

`plugins/tle/commands/run.md` is the closest existing analogue of `/tsf:cycle`
and is worth reading in full before writing it. Its mechanics:

- **Frontmatter is only `description` + `argument-hint`** — no `allowed-tools`,
  no `model`, and deliberately no `disable-model-invocation`.
- **Four invariants at the top** (`:14-17`): one iteration per turn ("Ending the
  turn is what lets `/goal`'s evaluator run"); never carry document contents,
  diffs or test output in this context; foreground dispatch only; read all loop
  state from disk on every invocation ("Previous turns are not reliable memory,
  and compaction may have removed them entirely").
- **Dispatch prose** is the bare bolded agent name plus a parenthetical:
  "Use the **loop-verifier** agent (foreground), passing exactly:" followed by a
  bulleted payload list, then "Pass nothing else", then a standalone "**Wait for
  the agent to complete before continuing.**", then a **`MANDATORY OUTPUT`** gate
  naming the file that must exist on disk afterwards ("Never proceed to planning
  on a missing report, and never reconstruct one yourself"). It never uses the
  namespaced `tle:loop-verifier` form and never names the Agent tool.
- **Return budget is one line per agent**; everything else goes in the file the
  agent writes. Formats are fixed per agent, e.g.
  `iteration NNN: X/Y passing — <one-line gap> — <path to NNN-verify.md>`.
- **Surfacing into the transcript is a numbered step of its own** (`:110-116`),
  because "The `/goal` evaluator does not call tools and judges only what has
  been surfaced in the conversation."
- **The stall check reads the escalation rung back from `loop-log.md`**, "not
  from conversation memory", and escalates over three rungs before stopping.
- **Ending the turn is step 13**, with no next-steps menu and no question to the
  user.

The tle plan's ordering rationale transfers directly: "Build bottom-up so each
phase is independently validatable: manifest first (Phase 1), then the
artifact-producing side … then the workers that consume and produce loop
artifacts, then the runner that orchestrates them, then docs and the repo's
governance rules." The marketplace entry was wired in Phase 1 "so `claude plugin
validate` covers everything added in later phases."

### 6. Shipped-script house style

Twelve `.sh` files exist, all under `plugins/tce/scripts/` and
`plugins/tmt/scripts/`. tle and tsf ship none. **No script anywhere in this repo
calls `gh` or any GitHub API** — every `gh api` string in the repo is prose
inside markdown. tsf's `scripts/` would be the repo's first shell-level GitHub
integration.

- **Shebang** `#!/bin/bash` in every file, including both `lib.sh`.
- **`set -e` only — `set -euo pipefail` appears nowhere.** Safety comes from
  `${VAR:-}` defaults (`"${CLAUDE_PROJECT_DIR:-$PWD}"`, `"${1:-}"`). The two
  `lib.sh` files and `check-init.sh` have no `set` line at all; the tmt hook
  scripts enable `set -e` only *after* reading stdin, then install an `ERR` trap.
- **The lib bootstrap is byte-identical in all ten non-lib scripts**:
  `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, a
  `# shellcheck source=lib.sh` directive, then `. "$SCRIPT_DIR/lib.sh"`.
  `SCRIPT_DIR` is used *only* to find `lib.sh`; the project root always comes
  from `tce_project_root` / `tmt_project_root`.
- **The `report()` contract** (`baseline.sh:46-51`, `branch.sh:81-86`): fixed
  `key: value` lines with padding baked into the format strings, then `exit 0`.
  Vocabularies are documented in the script header and emitted exhaustively from
  a `case`. Callers parse the `result:` line and act on it
  (`research.md:106-110`).
- **Output**: `printf '%s\n'` with single-quoted format strings for contract
  lines; `echo` for usage and errors. Errors are `echo "Error: …" >&2; exit 1`
  and name the fix command where one exists ("Run /tmt:init to set up this
  project.").
- **Hook scripts always exit 0**, never write to stderr, and communicate only via
  a `{"hookSpecificOutput":{…,"additionalContext":…}}` heredoc. A silent no-op is
  a `log` breadcrumb plus `exit 0` with no stdout.
- **JSON**: in with `INPUT=$(cat)` then `jq -r '.path // empty'`; out with
  `jq -Rs '.'` (interpolated *unquoted*, since jq emits the quotes) or, in
  `check-init.sh:104-105`, an awk escaper explicitly chosen "so no jq dependency
  is needed". `jq` is therefore already a de-facto dependency that `/tmt:init`
  escalates to a warning — relevant because a REST helper parsing GitHub JSON
  will want it.
- **`local` is used exactly once in the repo** (`tmt/lib.sh:23`); in-script
  helpers use name-prefixed globals instead.
- **Config is sourced, not parsed** (`tmt/lib.sh:28`), which is why
  `TMT_CONFIG_VERSION=` is inert to the scripts.

**The division of labour between script and command** is a stated repo rule
(CLAUDE.md, TP-0033): `stage.sh` "never reads tce config and receives ticket IDs
as arguments — the `branch.sh` division of labour", because enumeration is
backend-specific and "no shipped script can do this without hardcoding one
backend". This bears directly on the ticket's `config.md` question (see Open
Questions 2).

### 7. GitHub REST for slice 1

All slice-1 operations are available over plain REST. Endpoints, with the
documented semantics that matter:

| Operation | Endpoint | Notes |
|---|---|---|
| Scan open issues | `GET /repos/{o}/{r}/issues?state=open&per_page=100` | Returns PRs too; discriminator is the presence of the `pull_request` key. `labels=a,b` AND-vs-OR is **undocumented**. |
| Read one issue | `GET /repos/{o}/{r}/issues/{n}` | Supports `304` / conditional requests. |
| Read comments | `GET /repos/{o}/{r}/issues/{n}/comments` | "ordered by ascending ID"; **no `sort`/`direction` params**; `since` available. |
| Post a comment | `POST /repos/{o}/{r}/issues/{n}/comments` | `201` returns the full object — read-back needs no follow-up GET. |
| Replace the label set | `PUT /repos/{o}/{r}/issues/{n}/labels` | Replaces all; names travel in the JSON body. |
| Create a label | `POST /repos/{o}/{r}/labels` | `color` is hex without `#`; duplicate expected as `422` + `already_exists`. |
| Update a label | `PATCH /repos/{o}/{r}/labels/{name}` | |
| Edit the issue body | `PATCH /repos/{o}/{r}/issues/{n}` | For the `<!-- tsf:links -->` marker block. |
| Read a ref | `GET /repos/{o}/{r}/git/ref/heads/{branch}` | Path is `heads/x`, **not** `refs/heads/x`. |
| Create a branch | `POST /repos/{o}/{r}/git/refs` | Body `ref` **must** be `refs/heads/x`; note the asymmetry with the GET. |
| Commit a file | `PUT /repos/{o}/{r}/contents/{path}` | `message`, base64 `content`, `branch`, `sha` for updates. |

**Four consequences for the helpers:**

1. **The scan must filter client-side.** `/search/issues` documents the OR
   semantics the design wants (`label:a,b` = OR) but is unusable here: the first
   consumer's proxy allows only `/repos/{owner}/{repo}/**`, `GET /` and
   `GET /user`, so search is denied; it is capped at 1,000 results, rate-limited
   at 30 req/min against core's 5,000/hr, and is an index with an
   `incomplete_results` flag and no published freshness guarantee — hostile to a
   loop that writes a label and re-scans moments later. Fetching open issues and
   filtering on the `tsf:` prefix with `jq` is one allowlisted call against live
   data, and avoids depending on the undocumented `labels=` semantics entirely.
2. **No write endpoint documents any concurrency guard.** There is no `If-Match`,
   no `If-Unmodified-Since`, no ETag precondition and no conflict status on any
   issue, label or comment write; ETags are documented for reads only. Every
   write is last-write-wins, silently. §10's "re-read the label set immediately
   before the PATCH" is a genuine mitigation, not a guarantee, and the helper's
   header comment should say so.
3. **Two different "forbidden" shapes must not be conflated.** GitHub returns
   `404` rather than `403` for missing permissions ("to avoid confirming the
   existence of private repositories"), while a proxy denial in the first
   consumer is a bare `{"error":"Forbidden"}` with **no GitHub response headers**
   (no `Server: github.com`, no `X-RateLimit-*`). Neither is a transport error and
   neither should be retried under §10's retry-then-park rule. Since `gh api`
   exits `1` for *every* failure and prints `gh: <message>` to stderr, the helper
   needs `-i`/`--verbose` to see the status line and headers — header absence is
   the only reliable proxy-denial discriminator.
4. **`PUT .../issues/{n}/labels` also dodges an encoding question**: how a label
   name containing `:` must be percent-encoded in the
   `DELETE .../labels/{name}` path is undocumented. DESIGN.md §3.4 calls the
   operation "the full-set PATCH"; the endpoint is a `PUT`.

**`gh api` mechanics**: `GH_TOKEN` then `GITHUB_TOKEN` "takes precedence over
previously stored credentials", i.e. over a keyring login — which is exactly the
mechanism §12's per-call credential resolution needs, and it means the helper
sets the variable in its own environment rather than passing a flag (there is no
`--token` flag). `gh api` sends **no `Accept` header of its own** unless
`--preview` is passed, and pins an `X-GitHub-Api-Version` whose value is not
documented; GitHub's own examples pass both headers explicitly. `--paginate`
forces `per_page=100` for REST and follows the `link` header. Rate limits: 5,000
req/hr for a PAT, plus secondary limits of 100 concurrent requests and "no more
than 80 content-generating requests per minute". Conditional requests returning
`304` do not count against the primary limit.

### 8. The comment-pickup workflow (§3.4)

Three documented facts, each of which fails **silently** if unhandled:

- **`issue_comment` only triggers from the default branch.** Verbatim: "This
  event will only trigger a workflow run if the workflow file exists on the
  default branch." A PR that adds the workflow does nothing until merged, and it
  cannot be tested from a branch. The polling fallback (§3.4) is what covers that
  window, and `/tsf:init` must state it.
- **`permissions: issues: write` must be declared**, and "If you specify the
  access for any of these permissions, all of those that are not specified are
  set to `none`." A default-configured repository's built-in token has only read
  access to `contents`/`packages`, so relying on the default gives no label write
  at all.
- **Responder logins must be exact, `[bot]` suffix included.** A filtered-out
  commenter produces a run with all jobs skipped and no error.

The issue-vs-PR discriminator is documented as truthiness, not comparison:
`if: ${{ !github.event.issue.pull_request }}`. The label check is
`contains(github.event.issue.labels.*.name, 'x')` and a login allowlist is
`contains(fromJSON('["a","b"]'), github.event.comment.user.login)` — note both
are list-first.

**The recursion rule works in the design's favour here.** Events triggered by
`GITHUB_TOKEN` "will not create a new workflow run", so the workflow's own label
write cannot loop. And because the factory identity is a real second account with
its own PAT rather than `GITHUB_TOKEN`, its comments *do* fire the workflow —
correctly filtered out by the responder check.

Pushing anything under `.github/workflows/**` needs the classic `workflow` scope
or a fine-grained **Workflows: write**; `repo` alone is not enough.

### 9. Claude Code platform facts

Docs read 2026-09-16; the "What's new" index's latest digest is Week 37
(v2.1.263–v2.1.269), so these are current.

**Fork mode and foreground dispatch — the material conflict.** The selection
rules are, in order: an agent-team teammate's subagent runs foreground;
`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` forces foreground everywhere; **"Where
fork mode is on, as it is by default in an interactive session, Claude Code runs
the subagent in the background, forks and non-fork subagents alike, and Claude
can't ask for the foreground"**; where fork mode is off (`-p` and the SDK), Claude
runs it "in the foreground when it needs the result before continuing". Fork mode
became the interactive default in **v2.1.232**. A background subagent's "results
reach Claude as a completion notification in a later turn."

This collides with DESIGN.md §5.1 step 5, §7, §11 and §16.25, and with the
epic-level AC "every agent is dispatched with a fresh context and in the
foreground — no agent or background shell is still running when a cycle ends".
The `/goal` premise it protects is confirmed verbatim: "If a subagent or a
background shell command is still running when a turn ends, Claude Code skips the
evaluation for that turn."

Two notes that keep this from being a settled verdict: the only levers are
**consumer-set environment variables**, not anything a plugin can ship; and tle's
first real run (2026-08-23, per its plan's closeout) was *after* v2.1.232 and the
engine model was reported as "validated in practice". Whether the documented rule
degrades tle's loop today is itself unverified. Recorded as Open Question 1.

**Everything else relevant, confirmed:**

- **Nesting** defaults to three layers (v2.1.219+); to keep an agent from
  spawning, omit `Agent` from `tools` or add it to `disallowedTools`.
- **Concurrency cap 20**, error string `Concurrent subagent limit reached`.
- **`LS` is not a tool** — still absent from the tools reference. When *nothing*
  in a `tools:` list resolves, Claude Code refuses to launch the agent; partial
  resolution is undocumented (tce's agents list `LS` and work, which is weak
  evidence only).
- **Plugin agents**: supported frontmatter is `name`, `description`, `model`,
  `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `memory`,
  `background`, `omitClaudeMd`, `isolation`; **`hooks`, `mcpServers` and
  `permissionMode` are ignored for security**, so no tsf agent can grant itself a
  permissive posture. `name` cannot contain `:`; the namespace is derived.
- **No tool-call syntax is available to a command body** — prose delegation
  remains the documented mechanism. Only the prompt string crosses into a
  non-fork subagent (plus its own system prompt, the CLAUDE.md hierarchy, a git
  status snapshot and any preloaded `skills`), and only a single final text
  result comes back. **No prompt-size limit is documented.**
- **`AskUserQuestion` is stripped from every subagent** regardless of
  frontmatter — consistent with tsf's design, where all human contact is via
  GitHub, but it means every question a worker would want to ask must be settled
  in the command or posted as an issue comment by the dispatcher.
- **`allowed-tools` is a grant, not a restriction**, scoped to "the turn that
  invokes this skill". Because `/tsf:cycle` is re-invoked each turn under `/loop`,
  the grant is re-established every iteration — the turn-scoping problem the tle
  plan noted would bite an internally-looping runner does not arise.
- **`${CLAUDE_PLUGIN_ROOT}` is now documented inside `allowed-tools`** for plugin
  skills, alongside `${CLAUDE_SKILL_DIR}`, `${CLAUDE_PROJECT_DIR}` and
  `${CLAUDE_PLUGIN_DATA}`. This closes TP-0017's long-standing caveat.
- **Auto-compaction**: the most recent invocation of each skill is re-attached
  after the summary, "keeping the first 5,000 tokens of each", with a **combined
  budget of 25,000 tokens** filled most-recent-first — so an earlier command body
  can be dropped *entirely*, not merely truncated. Skill *descriptions* are not
  re-injected at all. File reads are restored. This is the platform-level
  justification for both the point-of-use reference reads and §6's "re-read all
  input artifacts from disk" contract, and it makes `cycle.md`'s size a design
  constraint: tle's `run.md` was measured at "197 lines / ~2.8k tokens (under the
  5k cap)".

**`/loop` self-pacing**: with no interval, "Claude chooses one dynamically …
After each iteration it picks a delay between one minute and one hour based on
what it observed … The chosen delay and the reason for it are printed at the end
of each iteration." `ScheduleWakeup` is model-internal — "you don't call it
directly" — and is stripped from every subagent. If an iteration neither
reschedules nor stops, "Claude Code schedules one fallback wakeup about 20
minutes later and ends the loop when that iteration doesn't reschedule either."
A self-paced `/loop` is **not restored on resume**.

**Permissions and workspace trust** — the finding that reframes the allowlist
question. A project's `permissions.allow` is applied "only after you accept the
workspace trust dialog", and "Claude Code shows the trust dialog in interactive
sessions only. A `claude -p` run or an SDK session never shows it". But the same
table's first row states: **"Workspace trust never gates a skill's `allowed-tools`
in any session"**, reinforced on the skills page — a project skill's
`allowed-tools` applies "including in a `-p` run in a folder you've never
trusted." A git-tracked `settings.local.json` is treated as repository-supplied
and held until trust. Current unattended guidance is `--permission-mode
dontAsk` ("useful for locked-down CI runs") or, from v2.1.259,
`--permission-prompts none`.

### 10. The first consumer (chat-sustainability), verified

This is the environment §8, §9.2, §10 and §12 were written against. Surveyed at
`/Users/toby/code/work/chat-sustainability`.

- **The credential proxy is nono**, profile at
  `~/.config/nono/profiles/chat-sustainability.json`. It injects by **URL path**
  (`{"method": "*", "path": "/repos/tobyS/chat-sustainability/**"}`), not by
  checkout path — confirming §16.29's correction that a second clone needs only a
  filesystem grant. Shape is `network.custom_credentials.<name>` with `upstream`,
  `credential_key` (a 1Password `op://` reference), `env_var` (`GH_TOKEN` for
  REST, `GITHUB_GIT_TOKEN` for git smart-HTTP), and `endpoint_rules`. There is no
  `injectHosts` key.
- **The factory identity already exists**: machine user `tobySagent`, classic PAT
  with `repo` + `workflow`. "The token never enters the sandbox; sessions see a
  phantom."
- **GraphQL is permanently blocked** — `api.github.com/graphql` appears nowhere in
  the allowlist, and the project's own docs say "It will not be opened — do not
  ask for it." REST-only is load-bearing, not defensive.
- **`gh auth status` is explicitly untrustworthy there** ("Do not chase
  permissions, and do not trust `gh auth status`"), so `/tsf:init`'s credential
  check needs a real call whose response headers prove it reached GitHub.
- **Branch convention is `gh-<n>`** (bare number, lower-case, no slug), enforced
  by a `commit-msg` hook, `scripts/commit-msg-ticket-scope.sh`, whose rule is
  `[[ "$branch" =~ ^gh-([0-9]+)$ ]]` → require scope `GH-<n>`.
- **CI**: `.github/workflows/verify.yml`, `pull_request` only, **no path filters
  at all** — so §12's no-path-filter requirement already holds there. Drafts are
  skipped (`if: github.event.pull_request.draft == false`), which is moot since
  tsf never drafts. The required check is the display name `verify (lint,
  depcruise, typecheck, test)`, marked "LOAD-BEARING NAME" in the file. The
  `Protect main` ruleset is strict-up-to-date but currently requires **0
  approving reviews** — §9.2 needs that raised to 1 (consumer-side work).
- **`npm run verify`** is the whole verification suite; the **four contract
  scripts do not exist yet** — creating them is consumer-side work, tracked in
  that repo's `factory-design.md` §3.7.
- **The design's "never an ad-hoc command line" rule is evidenced**: that repo's
  deny list already blocks `Bash(git reset --hard *)`, `Bash(git clean *)` and
  every force-push form in every session (§16.18's reasoning).

One staleness note: `factory-design.md` there (untracked, written against DESIGN
v1.1) still says the clone path "goes into `.claude/tsf/config.md` at
`/tsf:init`", which v1.4 §16.47 removed. It is the consumer's file, not this
slice's, but the smoke test depends on it.

### 11. Reference templates and point-of-use reads

Reference files open with an HTML-comment preamble declaring the read-points,
stating that changes to the file are command-contract changes, and listing a
numbered `Contents:`. A single file carries **multiple template sections**, each
an H1 with a fenced block, and consumers point at "the second section of …".
Fences use **four backticks** when the template itself contains fences.

The point-of-use read phrasing is fixed: "Read `${CLAUDE_PLUGIN_ROOT}/references/…`
**now — in full, even if you read it earlier in this session** — and …"
(`research.md:303`, `plan.md:361` and `:410` reading the same file twice at two
moments, `define.md:191`). DESIGN.md §6 requires exactly this for tsf's eight
templates, and finding 9's compaction budget is why.

## Code References

- `.claude-plugin/marketplace.json:1-31` — the marketplace and its three entries (`name`, `source`, `description`, `version`)
- `plugins/tce/.claude-plugin/plugin.json:1-25` — manifest keys incl. the `userConfig` entry shape
- `plugins/tce/commands/research.md:4` — `allowed-tools` script-grant syntax
- `plugins/tce/commands/research.md:303` — point-of-use reference read phrasing
- `plugins/tce/commands/init.md:13-14` — the "do not write until confirmed" gate; `:36-56` "What gets created"; `:63-70` Phase 0; `:80-155` detection heuristics; `:201-229` the verbatim dialog frame; `:348-351` verify-access-before-writing; `:369-386` template copy + version stamp; `:526-553` Idempotency upgrade list; `:566-575` the settings.json posture
- `plugins/tmt/commands/init.md:47-55` — jq preflight; `:92-118` computed-option dialog; `:176-190` the one sanctioned settings.json edit
- `plugins/tce/commands/refresh.md:95-128` — factual/hand-authored classification and the high-confidence gate
- `plugins/tce/agents/plan-compliance-checker.md:28-35,73-99` — the three-part envelope; `:14-26` the isolation clause
- `plugins/tle/commands/run.md:10-18` — the four invariants above `## Project context`; `:95-108` the dispatch + wait + MANDATORY OUTPUT shape; `:110-116` surfacing into the transcript; `:118-138` convergence and stall checks; `:185-187` ending the turn
- `plugins/tle/agents/loop-verifier.md:1-6` — `disallowedTools` frontmatter and a model pin; `:78-100` the verdict-vector machine contract
- `plugins/tle/references/goal-file-template.md:49-50,62-70` — stable item IDs and the condition string carrying the restart directive
- `plugins/tce/scripts/lib.sh:1-13` — `tce_project_root`, the whole file
- `plugins/tmt/scripts/lib.sh:22-42` — config sourcing with legacy fallback; the status enum as single source
- `plugins/tce/scripts/baseline.sh:46-51` and `plugins/tce/scripts/branch.sh:81-86` — the `report()` stdout contract
- `plugins/tce/scripts/branch.sh:29-36` — the `result:` vocabulary and the exit-code sentence
- `plugins/tce/scripts/check-init.sh:104-114` — jq-free JSON escaping and the hook output envelope
- `plugins/tce/hooks/hooks.json:1-16` — exec form with `${user_config.*}` in `args`
- `plugins/tsf/DESIGN.md:284-347` — the §4 state machine; `:351-376` the §5.1 cycle; `:994-1067` the §11 roster and the dispatcher-owns-writes rule; `:1069-1174` §12 configuration, contract check and release plan
- `README.md:19-23`, `CONTRIBUTING.md:32-57`, `.claude/tce/profile.md:27-48` — the plugin-enumerating docs surfaces

## Architecture Documentation

- **Auto-discovery everywhere.** No `plugin.json` declares `commands`, `agents`
  or `hooks`. Adding `plugins/tsf/{commands,agents,scripts,references,templates}/`
  plus a manifest and a marketplace entry is the whole registration story.
- **Two config registers.** tce's project config is prose markdown read by the
  model (`profile.md`, `tickets.md`); tmt's is machine-readable shell sourced by
  scripts (`.claude/tmt/config`). DESIGN.md §12 puts tsf's `config.md` in the
  first register while also giving tsf `scripts/` — the tension the ticket's
  second planning question names.
- **Script/command division of labour.** Both `branch.sh` and `stage.sh` take
  everything they need as arguments and never read project config; the command
  resolves config and passes values in. This is a stated repo rule (CLAUDE.md,
  TP-0033), and it is the existing answer to "does a script need to parse
  `config.md`?" — it does not have to.
- **Three sync-rule shapes in CLAUDE.md** a new plugin may join: byte-identical
  duplication (the AskUserQuestion block, currently ten copies), semantic
  mirroring (composite-tracking, TP-0013 re-read, TP-0022 sufficiency), and
  ownership-boundary rules. tsf is standalone (§2) so it inherits none
  automatically — but §4's dispatch table and the agents' contracts are two
  descriptions of one state machine, which is the same drift hazard, and §16.23
  (the dispatcher owns every write) is precisely the mitigation.
- **The `/goal`-driven turn is the engine.** tle established that a runner must
  perform one iteration and end its turn, that all dispatch must be foreground,
  and that the condition string carries the restart directive so the loop
  survives compaction. tsf's `/loop` runner is a different driver (no `/goal`
  condition, no verdict vector) but inherits the one-step-per-turn property from
  §5.1 directly.

## Impact Analysis

Slice 1 is greenfield inside `plugins/tsf/`, but it touches shared artifacts.

### Existing Usages Found

- `.claude-plugin/marketplace.json:9-30` — the `plugins[]` array; validated by
  `claude plugin validate .`, and the tle plan asserted `jq -e '.plugins | length == 3'`
  as an automated criterion (that assertion becomes `== 4`).
- `CLAUDE.md` — the layout block and the per-plugin rule sections; TP-0034a's AC
  requires tsf rule sections for the same-commit spans this slice creates.
- `CONTRIBUTING.md:32-57` — the repository-layout tree enumerating all plugins.
- `.claude/tce/profile.md:27-48` — the code map and the "three plugins" sentence.
- `README.md:19-23` — the catalog table (deferred to TP-0034c by the ticket).
- The `### AskUserQuestion dialog guidelines` block — **ten byte-identical
  copies** today; `/tsf:init` and `/tsf:spec` both have dialog sites, which would
  make twelve.

### Current Contract

- Marketplace entries: exactly four keys in order, `version` mirroring the
  plugin manifest. Update gating is per plugin by `version`.
- The AskUserQuestion block: byte-identical across all copies, verified by
  extracting heading-through-last-bullet and diffing (CLAUDE.md rule; the tle
  plan encoded it as an automated criterion).
- CLAUDE.md rule sections: each states a same-commit span and the reason it
  exists.

### Adaptation Requirements

- `.claude-plugin/marketplace.json` — add a fourth entry at `0.1.0`; any
  `length == 3` assertion in a plan's criteria must move to 4.
- `CLAUDE.md` — new tsf sections. The ticket names at least three spans: the
  dispatcher-owns-writes seam, the `cycle`-unflagged rule, and the
  contract-script rule.
- `CONTRIBUTING.md`, `.claude/tce/profile.md` — add `plugins/tsf/` and correct
  "three plugins". (The profile is otherwise accurate today: tsf is not yet a
  plugin, so this is a task for the slice, not pre-existing config drift.)
- The AskUserQuestion block — two new copies, byte-identical; the CLAUDE.md rule
  text stating "ten copies" needs updating in the same commit.

### Backward Compatibility Options

Not applicable in the usual sense — nothing consumes tsf yet, and §2 forbids any
dependency between tsf and tce or tmt. The one compatibility surface is the
marketplace: a consumer running `/plugin marketplace update toby-plugins` sees a
new plugin appear, which is additive. The `0.1.0 → 0.2.0 → 1.0.0` release plan
(§12) exists precisely so a consumer can tell which slice they have.

## Historical Context (from thoughts/)

- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md` —
  the epic's research. Its house-style findings still hold; its `gh`-porcelain
  sections (`gh issue list`, `gh pr checks`, `gh pr merge`, the GraphQL
  single-query shape) are **superseded by §10's REST-only rule**, as TP-0034c's
  references section already notes. Its platform findings are superseded where
  finding 9 above says so.
- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` — the
  background review DESIGN.md came out of: the seven-layer reference
  architecture, the documented failure modes (DORA amplification, rubber-stamp
  review past ~400-line diffs, spec drift), and the practitioner lesson that "a
  checker agent that sees the implementer's reasoning will rationalize gaps" —
  the direct ancestor of §7's context-starved gates and §9.1's dossier.
- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md`
  and `thoughts/shared/plans/2026-08-19-TP-0025-…` — the most recent whole-plugin
  build: bottom-up phase order, marketplace entry in Phase 1, grep/jq automated
  criteria, scratch-project manual criteria with deliberately induced failure
  modes. Its closeout records that the engine model was validated in a real run
  and that the plugin's one real shortcoming was **goal-definition quality**, not
  architecture — a caution for `/tsf:spec`'s sufficiency work.
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` — the
  design record for the context-starved gate: criteria passed **verbatim in the
  prompt** rather than read from files ("reading them would defeat the
  adversarial isolation"), the diff computed by the caller because a read-only
  agent has no Bash, the four-verdict vocabulary, markdown output.
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` —
  `disable-model-invocation` semantics, `allowed-tools` as a grant rather than a
  restriction, and the then-open caveat about `${CLAUDE_PLUGIN_ROOT}` inside
  frontmatter, which finding 9 now closes.
- `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md`
  — why `baseline.sh` probes reachability rather than existence. §3.5's
  three-dot PR diff removes that whole failure class for tsf (§16.44 says so
  explicitly), so tsf needs no `baseline.sh` equivalent.
- `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`
  and the `branch.sh` design — the `result:`-line contract tsf's helpers copy.

## Related Research

- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md` (the epic; shared by all three slices)
- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` (design background)
- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md` (the whole-plugin build precedent)
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` (context-starved gates — bears on slice 2)
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` (frontmatter machinery)
- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md` (the `references/` mechanism and point-of-use reads)

## Open Questions

**For discussion, not unilateral resolution** (the epic's Out of Scope:
"material deviations from DESIGN.md require discussion"):

1. **Foreground agent dispatch versus fork mode.** DESIGN.md requires foreground
   dispatch in four places and the epic makes it a cross-cutting AC, but current
   docs say that in an interactive session — which is what `/loop /tsf:cycle`
   runs in — Claude "can't ask for the foreground". The available responses are
   all consumer-side: document `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` (or
   turning fork mode off) as a requirement `/tsf:init` states and checks; or
   accept background dispatch and redesign the cycle so a step's result arrives
   as a completion notification in a later turn (which changes what "one cycle"
   means); or verify empirically that the documented rule does not in fact
   degrade the pattern, since tle's validated run post-dates the change. The
   env-var name for disabling fork mode (`CLAUDE_CODE_FORK_SUBAGENT=0`) comes
   from a dated release digest rather than the reference section and should be
   confirmed before it is written into shipped docs.

**The ticket's seven planning questions, as narrowed:**

2. **The result-block format and the harness marker** — *partly answered*.
   Subagents have no structured output in interactive Claude Code; only a single
   final text result comes back, so the gates' report content must arrive as
   markdown the dispatcher writes to a file, exactly as §11.2 designs. The marker
   was **observed twice in this session's own subagent returns**, in the form
   `[harness: subagent output matched instruction-shaped pattern(s): settings-json.
   Control tags below are neutralized (\`<\` → \`<\\\`); …]`, with angle brackets
   escaped in the body. A tsf agent's return will routinely look
   instruction-shaped (journal entries, label names, question comments), so this
   is the common case, not the rare one. Open: the exact stripping rule, and
   whether the result block should use a delimiter robust to escaping (tle's
   `<!-- verdict-vector -->` markers are themselves angle-bracketed, which is
   worth checking).
3. **Whether `config.md` needs a machine-readable companion** — the repo's
   existing answer is that it does not have to: `branch.sh` and `stage.sh` take
   everything as arguments and never read config, by an explicit CLAUDE.md rule.
   The alternative is tmt's sourced `KEY=VALUE` file. Which applies depends on
   whether the scan/write helpers are argument-driven (dispatcher reads the prose
   config) or self-sufficient. Note that `config.md` must carry a
   `tsf-config-version` marker on line 1 either way.
4. **Where the allowlist is written** — reframed by finding 9. A skill's
   `allowed-tools` is never gated by workspace trust in any session, while a
   project's `permissions.allow` is ignored until the dialog is accepted and the
   dialog never appears under `-p`. So the grants the cycle itself needs can live
   in `cycle.md`'s frontmatter, and the `settings.json` offer — which would be the
   repo's second sanctioned exception and lands against an explicit existing rule
   — may be reducible to a printed checklist (the shape §12 already chose for the
   ruleset settings). Open: whether the project's own contract scripts, which
   `/tsf:init` registers by path, can be covered by frontmatter at all, since
   their paths are per-project and frontmatter is shipped.
5. **How the closing report conveys the wait suggestion** — self-paced `/loop`
   picks the delay itself ("between one minute and one hour based on what it
   observed") and prints it; `ScheduleWakeup` is not callable from a command
   body. So the report only needs to surface the *facts* the model prices in —
   which tickets were skipped for a pending CI run, and whether anything was
   actionable — as plain text in the turn. Worth noting: if an iteration neither
   reschedules nor stops, one fallback wakeup fires ~20 minutes later and then the
   loop ends.
6. **Whether worker agents stay inline** — nesting is on by default to depth 3,
   so "inline" is now a choice enforced by omitting `Agent` from `tools` (or
   adding `Task`/`Agent` to `disallowedTools`, as all four tle agents do). The
   gates get it for free via their `tools: Read, Grep, Glob`. Unresolved for the
   workers, and it interacts with question 1: nested dispatch inside a background
   subagent compounds the turn-boundary problem.
7. **Which agent folds a research-parked answer** — unchanged by research; §6.3
   sends research's answers into `spec.md` while `research.md` already exists, and
   §4 row 1 continues "with the step the artifacts imply". Whether `tsf:research`
   re-runs or `tsf:plan` folds is a design question this research cannot settle.
8. **Whether `/tsf:spec` and `/tsf:init` go through the REST write helper** —
   mechanically clean either way: `GH_TOKEN` takes precedence over a stored
   keyring login, so a helper that resolves the factory credential sets that
   variable in its own environment, and one running as the human simply does not.
   An identity argument (`--as-factory` / default ambient) would put the
   read-back, full-set-PUT and retry logic in one place as §10 and §11.3 intend.
   Open: whether the retry-then-park rule makes sense at all for interactive
   commands, which have a human present to see a failure.

**New, mechanical:**

9. **Scoped agent dispatch is still unverified in this repo.** tle's plan
   pre-registered this risk and its shipped `run.md` uses the bare bolded name.
   tsf has eleven agents and a dispatch table keyed on them, so the plan should
   settle the phrasing and verify it on a real dispatch.
10. **`cycle.md` must fit the compaction budget.** 5,000 tokens per skill,
    25,000 combined, most-recent-first, with earlier bodies dropped entirely.
    `/tsf:cycle` carries far more than tle's `run.md` did at ~2.8k tokens. What
    moves into `references/` and what must stay in the body is a real design
    decision, not a formatting one — and per §6 every template is read at the
    point of use anyway.
11. **`gh api`'s pinned `X-GitHub-Api-Version` is undocumented**, and it sends no
    `Accept` header of its own. GitHub's own examples pass both explicitly;
    whether the helper should is a small decision with a long tail.
12. **The `PUT .../issues/{n}/labels` vs "full-set PATCH" wording.** DESIGN.md
    §3.4 and §10 describe the operation as a PATCH; the replace-all endpoint is a
    PUT (a `PATCH /issues/{n}` with `labels` also replaces). Worth reconciling the
    design's wording with the endpoint the helper actually calls.
13. **Consumer-side prerequisites are not all in place** for the smoke test: the
    four contract scripts do not exist in chat-sustainability, its ruleset still
    requires 0 approvals, and its `factory-design.md` is written against DESIGN
    v1.1. The ticket's smoke test targets a *scratch* project with a second
    GitHub account, so this does not block slice 1 — but the scratch project needs
    the same four scripts.
