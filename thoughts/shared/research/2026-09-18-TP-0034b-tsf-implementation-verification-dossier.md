---
date: 2026-09-18T06:45:55Z
git_commit: a87deec081664f945a72b3529562cf3dffff030e
branch: main
repository: toby-plugins
topic: "TP-0034b — tsf slice 2: implementation, the verification pipeline, the three gates, the dossier and review handling"
tags: [research, codebase, tsf, github-rest, pull-requests, check-runs, reviews, gates, subagents, dispatcher]
status: complete
last_updated: 2026-09-18
---

# Research: TP-0034b — tsf slice 2 (implementation, verification pipeline, dossier)

**Date**: 2026-09-18T06:45:55Z
**Git Commit**: a87deec081664f945a72b3529562cf3dffff030e
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0034b asks for the second tsf slice: the factory must produce code. That means
DESIGN.md §4 rows 5–11 — implement (plus rework and fix modes), verify-fix per
episode, the three post-implement gates in one foreground cycle, the dossier, and
the review-state transitions to `tsf:landing` / `tsf:rework` — on top of slice 1's
dispatcher. Its four planning questions are mechanical: the prompt size when a
full diff reaches three gates at once, how the dispatcher computes the logic head
and compares it with a review's `commit_id`, the subagent concurrency cap against
three foreground gates, and how the pick learns "local verification green" for a
ticket it has not picked yet.

This document records what exists — slice 1's contracts and their seams, the
GitHub REST surface the PR workflow needs (and the parts GitHub does not
document), the platform rules for dispatching several agents in one turn, and the
repo's patterns for read-only gate agents and bounded fix loops.

## Summary

**Slice 1 left the seams where slice 2 attaches, deliberately and visibly.** The
label vocabulary is already complete — `/tsf:init` creates all fourteen labels
including `tsf:verify`, `tsf:dossier`, `tsf:rework`, `tsf:landing` and
`tsf:needs-review`, none of which any slice-1 path sets
(`plugins/tsf/commands/init.md:279-292`). The dispatcher already carries a
**re-pick** branch built for exactly this moment: a derived step of `implement`
adds the ticket to the skipped list and returns to the pick without writing
anything (`plugins/tsf/references/cycle-dispatch.md:69-70`,
`plugins/tsf/commands/cycle.md:113-117`). `gh-write.sh marker` already accepts
`--pr P` and composes the PR link, and slice 1 simply never passes it
(`plugins/tsf/scripts/gh-write.sh:25,125,178` versus
`plugins/tsf/references/cycle-write-phase.md:43-44`). The `--poll` loop in
`scan.sh:92-107` is the working precedent for "one extra REST call per ticket in
a given state, reduced with `jq`, merged back into the records" — the exact shape
the PR/CI/review probes need. Four vocabularies are closed and must be extended
in lock-step: the result block's allowed-outcomes table
(`references/templates/result-block.md:49-59`), the journal's `Next step` set
(`references/templates/journal-entry.md:44-58`), the dispatch rows
(`references/cycle-dispatch.md:72-113`) and the report's skip reasons
(`references/cycle-report.md:38-41`).

**The GitHub half is fully available over REST, but four things a PR bot wants
are undocumented** and must be explicit assumptions rather than inferred
invariants: `mergeable_state` has no documented enum at all; "no checks
configured" cannot be distinguished from "checks have not started yet" on the
check-runs endpoint; neither commit endpoint says which checks are *required*
(only the admin-only branch-protection endpoint does, and repository rulesets are
not reflected there at all); and the behaviour of the `.diff` media type above
GitHub's size limits is unspecified (the widely observed `406` appears nowhere in
the docs). Two further facts change the shape of the verify step: **GitHub
Actions results are check runs and never appear in
`GET /commits/{ref}/status`** — a dispatcher reading the combined-status endpoint
would see "pending" forever on an Actions-only repository — and **reviews are
returned in chronological order with no `sort` parameter**, so "the reviewer's
latest review" is something the dispatcher derives itself, after paging to the
end.

**The diff should be computed locally, not fetched.** The dispatcher runs in the
clone with the branch checked out and `origin` freshly fetched by `prepare`, so
`git diff <base>...HEAD` is the three-dot diff §3.5 defines, with no 300-file
cap, no 20,000-line cap, no 1 MB cap and no undocumented `406`. The REST compare
endpoint is the documented three-dot route (it returns `merge_base_commit`) but
carries every one of those limits, and the PR `.diff` media type is not even
documented as three-dot. The same reasoning settles the logic head: with no
mechanical sync merges before TP-0034c, §3.5 reduces to "newest commit touching a
path outside `thoughts/`", which is one `git rev-list` in the clone.

**Three platform facts constrain the gate cycle.** The concurrency cap is 20 with
the error string `Concurrent subagent limit reached` and **no queue** — three
gates are far under it. Whether several `Agent` calls in one assistant message
actually run concurrently is **undocumented**: the SDK's parallel-tool rule
classifies read-only versus state-modifying tools and never places `Agent` in
either bucket, so "in parallel" is best-effort and only "all three complete
before the write phase" is load-bearing. And there is **no documented
`background: false`** — a plugin cannot force its agents into the foreground from
frontmatter; the only lever is the consumer's
`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, which slice 1's preflight already
requires and checks.

**One new hazard for the machine contracts.** The docs now describe the
subagent-output scan precisely: it "never removes or rewords anything" but
performs **backslash insertion** into text that imitates Claude Code's own
output, plus the `[harness: …]` marker line. Slice 1's result block already
survives this by forbidding angle brackets and undoing `<\`
(`references/templates/result-block.md:19-24,75`); slice 2's gate reports and
dossier — which quote diffs, file paths and findings — are the first returns
likely to *contain* instruction-shaped text, so the same discipline has to reach
them.

## Detailed Findings

### 1. Where rows 5–11 attach in slice 1's code

The dispatcher's shape (`plugins/tsf/commands/cycle.md`) is eight steps:
preflight → scan → pick → prepare → decide → dispatch → write → report, with five
invariants above `## Project context` (`:14-32`) that win over anything later.
Rows 5–11 touch six of the eight:

| Site | Today | What slice 2 adds |
|---|---|---|
| `cycle.md:74-80` | actionable = `tsf:answered`, `tsf:queued`, `tsf:research`, `tsf:plan` | `tsf:implement`, `tsf:verify`, `tsf:dossier`, `tsf:rework`, `tsf:needs-review` (with a reply/review signal) |
| `cycle.md:82-88` | later-slice states skipped with "not implemented in this slice" | only `tsf:landing` keeps that reason |
| `cycle.md:113-117` | Step 5's three outcomes incl. **re-pick** | re-pick also serves CI-pending tickets (§4 rows 6–7) |
| `cycle.md:131-133` | artifact table triage→`spec.md`, research→`research.md`, plan→`plan.md` | implement/verify-fix → commits; dossier → `reports/dossier.md`; gates → three reports |
| `cycle-dispatch.md:35-38` | derived step from artifacts (`triage`/`research`/`plan`) | PR existence, CI state, review state and report files join the derivation |
| `cycle-write-phase.md:43-44` | `marker … --journal`, never `--pr` | `--pr` at PR creation (§3.2) |

Two constraints are stated in the files themselves and govern the extension:
"Dispatch rows grow only with a slice" (`cycle-dispatch.md:12`) and the journal's
`Next step` vocabulary is closed, "the dispatcher rejects anything else — and
grows only with a slice" (`journal-entry.md:46-48`).

The one live edge already pointing into slice 2: `tsf:plan` is the only agent that
emits `next-step: implement` / `next-label: tsf:implement`
(`plugins/tsf/agents/plan.md:107-108`, `result-block.md:57`), which the dispatcher
currently converts into a re-pick.

### 2. The shipped script layer and its extension points

`scripts/lib.sh` is the shared layer. Its outcome classification (`lib.sh:100-110`)
is the load-bearing logic: `auth` (gh exit 4), `transport` (no status line,
retried once), `ok` (2xx), `rejected` (non-2xx **with** `X-GitHub-Request-Id`),
`denied` (non-2xx **without** GitHub headers — a proxy refused before GitHub).
`tsf_api_list` (`lib.sh:132-152`) pages at 100/page to a cap of 10 pages and
leaves `TSF_API_*` describing a failing call; `tsf_trailer` / `tsf_api_fail`
(`lib.sh:154-175`) define the three-line trailer every script ends with.

**`scan.sh` is where the PR, CI, review and last-comment facts must come from.**
Today it makes exactly two kinds of call: the open-issues listing (`scan.sh:76`)
and, under `--poll`, issue comments per parked ticket (`scan.sh:95`). Its record
is produced by one `jq -r` (`scan.sh:109-118`) whose field list mirrors the header
block at `scan.sh:22-29` — a new field is one line in each. The `--poll` loop
(`scan.sh:92-107`) is the precedent for per-ticket probes: filter by state
(`:94`), call (`:95`), reduce with `jq` (`:100-103`), accumulate into a side map
(`:104-105`), join back with `--slurpfile` (`:109`). Failure propagation is
already patterned: `count: 0` then `tsf_api_fail` (`:96-99`). Note the script has
**no branch pattern**: `tsf_branch_for` exists in the library (`lib.sh:196-200`)
but `scan.sh` never calls it and its flag set is fixed (`:52-62`), so a
branch→PR probe needs a new flag.

`gh-write.sh` subcommands and their result vocabularies are exhaustive in
`gh-write.sh:9-51`; every call goes through `tsf_api_retry`, and read-back is per
subcommand (the 201 body for `comment`, an explicit GET for `labels`, `marker`,
`ref-create`, `contents-put`). Slice 2 adds PR creation — and PR creation is a
`POST` whose response carries `number`, `html_url` and `head.sha`, the same shape
`issue-create` already handles (`gh-write.sh:206-215`).

`gh-read.sh` prints verbatim text (`body:`, `text:`) **after** the trailer
precisely so it can contain anything (`gh-read.sh:44-45`) — the pattern a
`pr-comments` or review read would reuse.

`push.sh` pushes exactly `refs/heads/<B>:refs/heads/<B>`, never force, and refuses
an ssh remote under the `env` credential source (`push.sh:16-18,73-78`).

### 3. The GitHub REST surface slice 2 needs

Neither prior research document covers a single pull-request endpoint — the
epic's material is `gh` porcelain (`gh pr create`, `gh pr checks`, `gh pr view
--json reviewDecision`) and is superseded by the REST-only rule, which the slice-1
research states explicitly. The endpoints, from the current REST reference
(api version `2022-11-28`, the default for requests without the header):

| Operation | Endpoint | Documented semantics that matter |
|---|---|---|
| Create PR | `POST /repos/{o}/{r}/pulls` | `title`, `head` (bare branch for same-repo), `base`, `body`; returns `number`, `html_url`, `head.sha`; `422` when one already exists for the head/base pair — the practical idempotency signal. **`draft`'s default is not documented** — pass `draft: false` explicitly. "This endpoint triggers notifications… may result in secondary rate limiting." |
| Find PR for a branch | `GET /repos/{o}/{r}/pulls?head={owner}:{branch}&state=open` | The **only documented input form is `owner:branch`**; a bare branch name is undocumented. No uniqueness guarantee — the response is a list. A malformed `head` returns `200 []`, so "no PR" and "filter typo" are indistinguishable. |
| CI state | `GET /repos/{o}/{r}/commits/{ref}/check-runs` | `{total_count, check_runs[]}`; `status` ∈ queued, in_progress, completed, waiting, requested, pending; `conclusion` ∈ success, failure, neutral, cancelled, skipped, timed_out, action_required, null. Limits check runs to the 1000 most recent check suites. |
| (not this one) | `GET /repos/{o}/{r}/commits/{ref}/status` | **Actions results never appear here.** Documented aggregation: "pending if there are no statuses or a context is pending". |
| Reviews | `GET /repos/{o}/{r}/pulls/{n}/reviews` | "The list of reviews returns in chronological order" — no `sort`/`direction`; fields `state`, `commit_id`, `submitted_at`, `user`. `PENDING` reviews have **no `submitted_at`**. Dismissal mutates the existing review to `DISMISSED` rather than adding one. |
| PR conversation comments | `GET`/`POST /repos/{o}/{r}/issues/{n}/comments` | "Every pull request is an issue" — the PR number *is* the issue number, so slice 1's comment helper already works on a PR. The per-issue list documents **no ordering** and offers no `sort`; `since` filters on *last updated*, not created. |
| Three-dot diff | `GET /repos/{o}/{r}/compare/{base}...{head}` | The documented three-dot route (returns `merge_base_commit`). Limits: 250 commits, **300 files, files only on page 1**, 20,000 lines / 1 MB per diff, "larger diffs may time out and return a 5xx". |

The `state` enum on reviews is typed as a plain string with **no enum in the
schema**; the values (`APPROVED`, `CHANGES_REQUESTED`, `COMMENTED`, `PENDING`,
`DISMISSED`) are only derivable from the sibling create/submit/dismiss endpoints.
"The reviewer's latest review" has no documented semantics at all: the dispatcher
must group by `user.login`, drop entries without `submitted_at`, and decide
whether a later `COMMENTED` supersedes an earlier `APPROVED` (GitHub's own merge
gate treats `COMMENTED` as non-decisive).

Rate limits: 5,000 requests/hour for a PAT; secondary limits of 100 concurrent
requests, 900 points/minute, and **80 content-generating requests per minute /
500 per hour**. The documented procedure for a bot posting several comments per
cycle is explicit: "If you are making a large number of POST, PATCH, PUT, or
DELETE requests, wait at least one second between each request." A cycle that
posts three gate one-liners plus a dossier comment is four content-generating
requests — comfortably inside the limits, but the one-second spacing is a
documented rule the write phase can honour cheaply.

### 4. Computing the PR diff and the logic head

§3.5 defines the PR diff as the three-dot diff against the base branch with
`thoughts/` excluded, and the logic head as the newest commit that is not a
mechanical sync merge and touches a path outside `thoughts/`. Both are computable
in the clone, where the dispatcher already stands after `prepare`:

- **Diff**: `git diff <base>...HEAD -- . ':(exclude)thoughts/'` — `git`'s
  three-dot form is merge-base-to-head, identical in meaning to what GitHub's
  Files tab shows, and subject to none of REST's caps. `prepare` has just run
  `git fetch --prune origin` (`templates/tsf/scripts/prepare.sh:32`), so
  `origin/<base>` is current.
- **Logic head**: `git rev-list -1 HEAD -- . ':(exclude)thoughts/'`. Every
  journal, report and dossier commit is inert by construction, which is the
  property §16.43 wanted. Before TP-0034c there are no sync merges, so the "not a
  mechanical sync merge" clause has nothing to exclude yet.
- **Approval validity** (§4 row 10, "the review's `commit_id` at or after the
  logic head"): `git merge-base --is-ancestor <logic-head> <review commit_id>`,
  which is exactly the reachability probe `plugins/tce/scripts/baseline.sh` uses
  for its own baseline question (`baseline.sh` probes reachability rather than
  existence, per TP-0030). The review's `commit_id` is a commit on the branch, so
  it is present in the clone after `prepare`.

This keeps the dispatcher's context free of diff content (invariant 3) only if the
diff never passes *through* it — see Open Question 1.

### 5. Dispatching three gates in one turn

Documented, and quoted here because each part bears on the design:

- **The cap**: "when 20 subagents are running in a session, spawning another with
  the Agent tool fails with `Concurrent subagent limit reached`, and the error
  tells Claude not to retry." There is **no queue**. Three gates is far under 20.
- **Parallelism is not documented for `Agent`.** The only parallel-execution rule
  lives on the SDK agent-loop page and covers read-only versus state-modifying
  tools; `Agent` is listed under "Orchestration" and placed in neither bucket. The
  prose guidance ("spawn multiple subagents to work simultaneously… This works
  best when the research paths don't depend on each other") is the strongest
  documented statement.
- **Foreground precedence**, in order: an agent-team teammate's subagent →
  foreground; `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` → foreground "in every kind
  of session"; fork mode on (the interactive default since v2.1.232) → background,
  "and Claude can't ask for the foreground"; fork mode off (`-p`, SDK) →
  foreground "when it needs the result before continuing".
- **A plugin cannot force foreground.** `background: true` exists as frontmatter
  ("keep this subagent in the background even when Claude asks to run it in the
  foreground"); there is **no `background: false`**. The consumer's environment
  variable is the only lever — which slice 1 already made a runner requirement and
  checks in `preflight.sh:110-117`.
- **Background subagents lose tools**: the background set omits, among others, the
  full foreground toolset — "The same definition can resolve to different tools in
  the foreground and the background." A gate that silently ran in the background
  would still have `Read, Grep, Glob`, but the dispatcher would not have its
  verdict in the same turn.
- **Returns**: a single final text result; no structured output in interactive
  Claude Code; partial output is returned with a note if the agent is cut off.
- **The output scan**: "The scan never removes or rewords anything; it makes two
  kinds of change you may notice in a report: **Backslash insertion** … and a
  **Marker line** starting with `[harness: subagent output matched
  instruction-shaped pattern(s):`". Two of this session's own research returns
  carried the marker.

Undocumented and worth stating plainly: there is **no size limit documented** for
an Agent prompt or a returned result (the tools reference documents caps for Bash
output and Read, and nothing equivalent for Agent); and whether a skill's
`allowed-tools` grant reaches subagents dispatched during that turn is **not
documented** — TP-0034a established empirically that it does *not*, which is why
`/tsf:init` now offers `Read(~/.claude/plugins/**)`.

### 6. Gate agents and bounded fix loops: the repo's patterns

`plugins/tce/agents/plan-compliance-checker.md` is the direct model for all three
gates: read-only `tools:` (`:4`), a "What you receive" isolation clause naming
what the agent does **not** receive and must not seek out (`:14-26`), the
three-part envelope (`## CRITICAL:` `:28-35`, `## What NOT to Do` `:81-90`,
`## REMEMBER: You are a compliance checker, not a code reviewer` `:92-99`), a
closed four-value verdict enum with an evidence obligation per value (`:37-47`),
an "Emit only this" output block with an `**Overall:**` roll-up (`:57-71`), and a
tie-break ("When in doubt between met and not met, use cannot verify from diff").
Its closing line is the reasoning the tsf gates inherit: "A checker prompted to
find problems always finds some."

`plugins/tce/commands/implement.md:262-328` is how a caller runs such a gate:
criteria assembled verbatim and numbered, the diff assembled by the caller, "Pass
it **only** the numbered criteria list and the diff", then one branch per verdict
value — "not met" **blocks** and loops back through fix → re-verify → **re-run the
gate**; "cannot verify from diff" is treated as not-yet-passed; MANUAL items are
never silently passed. tce's fix loop is **unbounded**; the only bounded-retry
pattern in the repo is tle's escalation rungs (`plugins/tle/commands/run.md:128-138`),
where the rung is **read back from a log file, not from conversation memory**, and
the final rung stops and escalates with the stalled state and the report paths.

For report artifacts the repo has both shapes: tle's verifier **writes the file
itself** and returns one line, with the caller enforcing a `MANDATORY OUTPUT`
check (`run.md:95-108`); tce's checker **returns content** and the caller acts on
it. DESIGN.md §11.2 chooses the second for tsf's gates — they have no `Write` —
so the dispatcher writes `reports/<gate>-<episode>-<round>.md` itself, with the
`head:` line naming the logic head.

`plugins/tle/agents/loop-verifier.md:76-100` is the model for specifying a
machine-parsed block inside an agent prompt: label it "a **machine contract**",
name the consumer and what it does with it, and state the layout constraints
exactly. tsf's equivalent is already shipped in `result-block.md`.

### 7. The environment contract in slice 2

`preflight.sh` validates all five contract scripts every cycle (`:94-107`), but
slice 1 **runs only `prepare`** (`cycle.md:94,99`). Slice 2 is where `env_up`,
`env_reset`, `env_check` and `verify` first execute. Their documented cadence
(DESIGN.md §8, restated in the skeletons): `env_up` in every
implementation-flavored cycle and therefore idempotent
(`templates/tsf/scripts/env_up.sh:7-11`); `env_reset` **on ticket switch**, not
every cycle, so consecutive cycles on one ticket keep a warm environment
(`env_reset.sh:7-11`); `env_check` a fast probe before implementation whose
failure parks the ticket for a human (`env_check.sh:7-9`); `verify` the suite
whose exit code is the verdict (`verify.sh:7-10`).

"On ticket switch" needs a memory of the previous ticket. Nothing in slice 1
records one: the journal is per-ticket, and the dispatcher keeps nothing between
cycles by invariant 4. The cheapest readable signal is the clone itself — the
branch checked out when the cycle starts, before `prepare` switches it
(`git rev-parse --abbrev-ref HEAD`, already granted in `cycle.md:4`).

`config.md`'s two constants — `verify_fix_bound` and `gate_fix_bound`, both
default 3 (`templates/tsf/config.md:71-74`) — are referenced by no slice-1 code.
Slice 2 is their first consumer.

### 8. Episodes, rounds and report files

DESIGN.md §6.7 and §16.37 are explicit that **filenames alone cannot distinguish
"episode 1, attempt 3" from "episode 2, attempt 1"**, so the episode number lives
in the journal: every transition into `tsf:verify` is journaled with its episode
number, and the attempt/round counter is derived from the files on the branch
(`reports/verify-fix-<episode>-<attempt>.md`,
`reports/<gate>-<episode>-<round>.md`). This is tle's disk-derived counter
generalized, and it means the journal entry shape gains a field — a change to a
closed contract (`journal-entry.md`), with the same-commit rule attached.

A fix-mode return to `tsf:verify` stays **within** the current episode (the round
advances, the episode does not); only implement and rework open a new one (the
ticket's own AC, and §6.7).

### 9. Docs surfaces and the version bump

The release plan is `0.1.0 → 0.2.0 → 1.0.0` across the slices (§12, §16.38), so
slice 2 bumps `plugins/tsf/.claude-plugin/plugin.json` and the marketplace entry
to `0.2.0`. The surfaces that enumerate tsf's contents and now exist:
`plugins/tsf/README.md` (slice-1 scope section, the labels table, the
troubleshooting list), `CLAUDE.md` (the layout tree plus seven tsf rule sections),
`CONTRIBUTING.md` and `.claude/tce/profile.md`. The root `README.md` catalog stays
deferred to TP-0034c.

## Code References

- `plugins/tsf/commands/cycle.md:14-32` — the five invariants; `:74-95` the pick and its skip vocabulary; `:113-117` the re-pick branch; `:131-137` the MANDATORY OUTPUT and branch recheck
- `plugins/tsf/references/cycle-dispatch.md:21-42` — derived state; `:44-70` validation and the `implement`→re-pick rule; `:72-113` rows 1–4 and 13; `:115-136` the spawn payload
- `plugins/tsf/references/cycle-write-phase.md:19-53` — the six-step write sequence and its deliberate order; `:55-67` parking on a failed write; `:83-100` prepare/push failure
- `plugins/tsf/references/cycle-report.md:22-30` — the report shape; `:44-56` the suggested-wait table
- `plugins/tsf/references/templates/result-block.md:19-47` — the three fences; `:49-59` the allowed-outcomes table; `:67-85` the parsing rules
- `plugins/tsf/references/templates/journal-entry.md:30-42` — the entry shape; `:44-58` the closed `Next step` vocabulary; `:60-86` dispatcher-only entries
- `plugins/tsf/references/templates/plan.md:18-33` — the increment fields the gates and the implementer read; `:80-83` the empty `## Addenda` section
- `plugins/tsf/scripts/lib.sh:100-110` — the outcome classification; `:132-152` `tsf_api_list`; `:154-175` the trailer and failure mapping
- `plugins/tsf/scripts/scan.sh:92-107` — the `--poll` per-ticket probe loop; `:109-118` the record's single `jq`
- `plugins/tsf/scripts/gh-write.sh:141-150` — `comment`; `:152-172` the full-set label replace with read-back; `:174-204` the marker block (note `--pr` at `:178`); `:206-215` `issue-create` as the model for PR creation
- `plugins/tsf/scripts/gh-read.sh:98-113` — `issue` with verbatim body after the trailer; `:115-131` `reply`
- `plugins/tsf/scripts/preflight.sh:94-107` — contract validation; `:110-117` the foreground check
- `plugins/tsf/templates/tsf/scripts/prepare.sh:30-44` — reset, fetch, checkout, prune; `env_up.sh:7-11`, `env_reset.sh:7-11`, `env_check.sh:7-9`, `verify.sh:7-19` — the cadences and the deliberately failing verify skeleton
- `plugins/tsf/templates/tsf/config.md:55-74` — the environment contract fields and the two unused constants
- `plugins/tce/agents/plan-compliance-checker.md:14-26,28-35,37-47,57-71,81-99` — the gate-agent skeleton
- `plugins/tce/commands/implement.md:262-328` — how a caller runs a gate and branches on its verdicts
- `plugins/tle/commands/run.md:95-108` — exact-payload dispatch, wait, MANDATORY OUTPUT; `:128-138` bounded escalation read back from disk
- `plugins/tle/agents/loop-verifier.md:76-100` — specifying a machine-parsed block; `:58-66` a verdict enum with a tie-break
- `plugins/tce/scripts/baseline.sh` — reachability probing with `git merge-base --is-ancestor`, the pattern for approval validity

## Architecture Documentation

- **Two descriptions of one state machine.** `cycle-dispatch.md`'s rows and the
  agents' result-block vocabulary describe the same transitions; slice 1 recorded
  that drift hazard in `cycle-dispatch.md:6-12` and CLAUDE.md's "tsf: the result
  block is a machine contract" rule. Every row slice 2 adds lands in both.
- **The dispatcher owns every write and does no content work.** Invariants 3 and 5
  (`cycle.md:24-32`) are what keep the runner's context small enough for `/loop`.
  Slice 2's biggest pressure on this is the diff: three gates need it, and the
  dispatcher must not hold it.
- **Read-back, retry-once, park.** Every GitHub write is verified and a second
  transport failure parks the ticket (`cycle-write-phase.md:55-67`). PR creation
  and the gate comments inherit this rather than inventing handling.
- **Context starvation is enforced by configuration, not prose.** The gates get
  `tools: Read, Grep, Glob` — no Bash, no Write — which is why the dispatcher
  computes the diff, writes the reports and posts the comments for them (§11.2,
  §11.3).
- **Counters live on disk, never in conversation.** tle reads its rung from the
  log; tsf derives rounds from report filenames and episodes from the journal.
- **The environment contract is the only path to destructive or
  environment-specific operations** (§8): slice 2 runs the project's scripts and
  never an ad-hoc command line.

## Impact Analysis

Slice 2 extends shipped, working code rather than adding an isolated area.

### Existing Usages Found

- `plugins/tsf/commands/cycle.md:66-70` — the only caller of `scan.sh`; its flag list and the record fields it consumes
- `plugins/tsf/references/cycle-write-phase.md:30-50` — the only caller of `gh-write.sh comment|labels|marker` and `push.sh` in the cycle
- `plugins/tsf/commands/spec.md:94-137` — the other caller of `gh-write.sh` (`issue-create`, `ref-create`, `contents-put`, `marker`, `labels`), all `--as ambient`
- `plugins/tsf/commands/init.md:274-315` — the caller of `label-create` and of `preflight.sh --identity`
- `plugins/tsf/agents/{triage,research,plan}.md:96-110` — the three producers of result blocks
- `plugins/tsf/references/templates/result-block.md:49-59` — the table every producer and the dispatcher validate against

### Current Contract

- **scan.sh record**: seven fields per ticket, blank-line separated, oldest first, plus a `count:`/`result:`/`status:`/`detail:` trailer; `reply:` is `skipped` unless `--poll` applied to that ticket.
- **gh-write.sh**: `<subcommand> --repo O/R --as factory|ambient [--credential env|proxy]`, fields then the three-line trailer, `result:` drawn from a per-subcommand vocabulary, exit 0 for every reported outcome.
- **Result block**: three fences, six `tsf-result` fields, a seven-row allowed-outcomes table, five journal lines; validity requires the row to be in the table and the journal lines to agree with `next-label`/`next-step`.
- **Journal entry**: `## Cycle <now> — step: <step>` plus five `- Field:` lines; `Next step` ∈ {triage, research, plan, implement}.
- **Agents**: `tools: Read, Write, Edit, Grep, Glob, Bash` (workers), payload fields fixed at `cycle-dispatch.md:119-135`, commit only their own artifact, never push.

### Adaptation Requirements

- `scan.sh` — new optional per-ticket probes (PR for the branch, check runs for the head, reviews, the factory's last PR comment) behind a flag, plus the branch pattern as an argument; new record fields; the `--poll` loop is the template.
- `gh-write.sh` — a `pr-create` subcommand (and, for the gate one-liners and the dossier, reuse of `comment` against the PR number); `gh-read.sh` — PR, checks, reviews and PR-comment reads.
- `result-block.md` — new steps (`implement`, `verify-fix`, `dossier`) and their rows; the gates return report content and do **not** use the worker result block.
- `journal-entry.md` — the episode number on transitions into `tsf:verify`, and the new steps in the `Next step` vocabulary.
- `cycle-dispatch.md` / `cycle.md` / `cycle-report.md` — rows 5–11, the new actionable/skip vocabulary, the three-gate dispatch and the CI-pending re-pick.
- `plugins/tsf/README.md`, `CLAUDE.md` (new rule sections), both manifests (`0.2.0`).

### Backward Compatibility Options

- **Option A — extend the existing record and vocabularies in place.** One scan
  record shape for all states, new fields defaulting to `skipped`/`-` when not
  probed. Pros: one contract, the `--poll` precedent, no branching in the
  dispatcher. Cons: every consumer sees fields it ignores.
- **Option B — a second script (`scan-pr.sh`) for the PR-side facts.** Pros:
  slice-1 scan untouched; PR probes only run when the dispatcher asks. Cons: two
  scripts to keep in step, a second failure vocabulary, and the dispatcher must
  join two outputs.

Option A matches the existing division of labour (`scan.sh` already conditionally
probes under `--poll`), and a consumer already ignores fields it does not use.

## Historical Context (from thoughts/)

- `thoughts/shared/research/2026-09-16-TP-0034a-tsf-foundation-human-gates.md` — slice 1's research: the REST table for issues/labels/branches/contents, the three consequences (client-side filtering, no concurrency guard, the two "forbidden" shapes), the compaction budget, and the workspace-trust finding that put grants in command frontmatter.
- `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md` — the nine-phase build and its closeout, including the two defects found by running the agents headless (the plugin-template read permission, and a cycle improvising its report).
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md` — the epic's research. Its PR mechanics are `gh` porcelain and superseded; what survives is the join-key principle (a deterministic branch name joins PRs to tickets with no linkage API), the `repo` + `workflow` scope analysis, and the observation that a PR opened with `GITHUB_TOKEN` fires no CI — which is why the factory must be a real second account.
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` — the design record for the context-starved gate: criteria passed verbatim, the diff computed by the caller because a read-only agent has no Bash, the four-verdict vocabulary.
- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` — the practitioner lesson the gates exist for: a checker that sees the implementer's reasoning rationalizes gaps; rubber-stamping past ~400-line diffs.
- `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md` — why reachability, not existence, is the right probe for a commit; the pattern approval-validity reuses.

## Related Research

- `thoughts/shared/research/2026-09-16-TP-0034a-tsf-foundation-human-gates.md` (slice 1 — the shipped foundation)
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md` (the epic; `gh`-porcelain sections superseded)
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` (context-starved gates)
- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md` (bounded escalation, machine-parsed blocks)

## Open Questions

**The ticket's four planning questions, as narrowed:**

1. **Passing the diff to three gates.** No prompt-size limit is documented, for
   either direction. Three options: **(a)** inline in each spawn prompt — the
   TP-0020 precedent, but it puts the whole diff through the dispatcher's context
   three times, against invariant 3; **(b)** the dispatcher writes the diff to a
   file in the clone and passes the **path** — the gates have `Read`, the
   dispatcher never holds the content, and starvation is unaffected because the
   file contains exactly the diff; **(c)** a hybrid, path plus an inline
   `--stat` summary. (b) looks right and is a deviation from §11.2's "in the spawn
   prompt" worth surfacing. Where the file lives also matters: untracked in the
   clone (discarded by the next `prepare`) or in the session's scratchpad.
2. **Logic head and approval validity** — mechanically settled (finding 4):
   `git rev-list -1 HEAD -- . ':(exclude)thoughts/'` for the head,
   `git merge-base --is-ancestor <logic-head> <commit_id>` for "at or after". Open
   only in that it adds two git grants to `cycle.md`'s `allowed-tools`.
3. **Concurrency** — settled: the cap is 20, three gates are safe, and the error
   string is documented. What is *not* documented is whether three `Agent` calls
   in one message run concurrently; the design's "in parallel" is therefore
   best-effort, and only "all three complete before the write phase" is
   load-bearing.
4. **How the pick learns "local green"** for a `tsf:verify` ticket. The pick uses
   scan data only (`cycle.md:74`), and `prepare`/`env_up`/`verify` run after it.
   Options: **(a)** treat every `tsf:verify` ticket as actionable, run `verify`
   after `prepare`, and re-pick (writing nothing) when it is green and CI is
   pending — reusing the re-pick mechanism slice 1 already has, at the cost of a
   verify run per pick; **(b)** record the last local verification result and the
   head it was run against in the journal, and let the *next* cycle read it after
   `prepare` — still after the pick, so it does not help the pick itself;
   **(c)** make CI state alone decide actionability from scan data (CI pending →
   skip; CI red or absent → pick), running `verify` only once picked. (c) matches
   §4 rows 6–7 most closely and costs nothing extra; (a) is the most faithful to
   "local verification is the first precondition".

**New, mechanical:**

5. **"Ticket switch" for `env_reset`** has no recorded signal (finding 7). The
   branch checked out when the cycle starts, before `prepare`, is the cheapest
   one; the alternative is a marker file in the clone, which `prepare`'s
   `git clean -fd` would delete unless it is ignored.
6. **"No checks configured" versus "checks not started yet"** is undocumented on
   the check-runs endpoint. A grace period, or a check-suites probe, or treating
   `total_count: 0` as pending until a configured timeout — each is a behavioural
   assumption the plan must state explicitly rather than infer. The first
   consumer's required check is identified by **display name** ("LOAD-BEARING
   NAME" in its workflow), which also argues for reading check runs by name.
7. **The gate reports and the dossier are the first agent returns likely to
   contain instruction-shaped text** (diff hunks, file paths, findings). The
   documented scan inserts backslashes into such text. The result block's
   no-angle-brackets rule handles the worker returns; the gates return *report
   content* the dispatcher writes to a file verbatim, so the same discipline (or
   an explicit unescaping step) has to be specified for them.
8. **Whether the three gates share one episode/round number** across
   `plan-compliance`, `spec-coverage` and `security`, or each carries its own
   counter. §7's `<gate>-<episode>-<round>.md` implies one shared round (they run
   together), which the plan should state.
9. **`/tsf:cycle`'s size.** It is 171 lines / ~8.5 KB today against a 5,000-token
   per-skill compaction budget. Rows 5–11 roughly double the state machine; what
   stays in the body and what moves into the references is a real decision, not
   formatting.
