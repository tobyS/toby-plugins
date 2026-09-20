---
date: 2026-09-20T15:20:00+02:00
git_commit: 100a2f6ad86b121e5c06baba07176d99326357ce
branch: main
repository: toby-plugins
topic: "TP-0036 — tsf corrections from the post-1.0.0 real-world review"
tags: [research, codebase, tsf, dispatcher, scan, gh-read, gh-write, preflight, diff, gates, journal, ci, github-rest]
status: complete
last_updated: 2026-09-20
---

# Research: TP-0036 — tsf corrections from the post-1.0.0 real-world review

**Date**: 2026-09-20T15:20:00+02:00
**Git Commit**: 100a2f6ad86b121e5c06baba07176d99326357ce
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0036 collects twelve corrections (C1–C12) agreed in the post-1.0.0 review of
tsf. What exactly exists today in each of the twelve places, what is the
mechanism of each defect, what contracts and same-commit spans does a fix
touch, and which platform facts the ticket rests on hold up?

## Summary

Every one of the twelve findings reproduces against the shipped code. The
plugin is internally coherent within each slice and breaks at the seams between
them, exactly as the ticket states: slice 1's resume/validation logic maps four
of the nine `Next step` values, the scan record grew PR fields in slice 2/3
without becoming a declared machine contract, and two read paths the state
machine names (`pulls/<n>/comments`, a PR title/body write) were never
implemented.

Three things the research changes about the ticket's own premises:

1. **C1's stated mechanism is wrong in its detail, right in its conclusion.**
   The Claude Code docs say a timed-out Bash command is **moved to the
   background, not killed**; what `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` does
   to a timed-out command is **not documented at all**. Either way a `verify`
   slower than the timeout breaks the cycle (killed → red; backgrounded → the
   dispatcher's foreground requirement is violated and the turn ends with work
   running). Also: `BASH_MAX_TIMEOUT_MS` has **no documented ceiling** — 600000
   is its *default*, not a maximum — and the effective ceiling is
   `max(BASH_MAX_TIMEOUT_MS, BASH_DEFAULT_TIMEOUT_MS)`.
2. **C3 and C5 collide.** C3 makes an approval stale when it is not newer than
   the factory's last PR comment; C5 makes the scan read reviews for
   `tsf:landing`. The landing's own decision cycle posts a gate one-liner **on
   the pull request** (`cycle-write-phase.md:152-153`), so after attempt 1 the
   approval is older than the factory's last PR comment and would read as
   `review: none` — re-creating the exact failure C5 exists to fix. The plan
   must reconcile these two, not implement them independently.
3. **C10 needs a new row in the result block's allowed-outcomes table.** The
   table has no `implement | continued | tsf:implement | implement` row
   (`result-block.md:83-84` only maps implement/continued → `tsf:verify`), so a
   batched implement return is invalid under the current parsing rules.

Two further findings that are not in the ticket but bear on it: the dispatcher
already contradicts invariant 3 in **five** named places (not the two the
ticket cites), and `/tsf:cycle`'s `allowed-tools` grants the scripts by exact
prefix — so any new script output that the dispatcher must not read has to be
written by the script through its own `--out` flag, never by a shell redirect
(a redirect changes the command string and breaks prefix matching).

## Detailed Findings

### C1 — Contract scripts and the Bash timeout

**What exists.** Nothing in `plugins/tsf/` mentions a timeout. Confirmed by
grep across `commands/`, `agents/`, `references/` and `scripts/`: zero hits.

- `plugins/tsf/scripts/preflight.sh:27-39` is the full output contract: `now:`,
  five contract-script lines, `foreground:`, `identity:`, `login:`, `result:`,
  `detail:`. All eleven lines print unconditionally at `:148-163`.
- `preflight.sh:109-117` is the `--foreground` check — a literal string compare
  of `$CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` against `"1"`; any other value is
  `missing` and appends to `FAILURES`.
- `result: incomplete` is driven solely by `FAILURES` being non-empty
  (`preflight.sh:157-163`); a `skipped` line never blocks `ok`.
- `preflight.sh:148` — `now:` is `date -u +%Y-%m-%dT%H:%MZ`, i.e. the **local
  machine clock**, minute resolution, computed at print time.
- The dispatcher runs `verify` itself in row 6 with no timeout
  (`cycle-dispatch.md:126-128`), and the four contract scripts as bare command
  lines (`cycle.md:117`, `:124`, `:128-131`).
- Agents run the project's verification with no timeout either:
  `implement.md:64-67`, `verify-fix.md:51-54` and `:58`, `manual-verify.md:51-57`,
  `merge-resolver.md:68-71`.

**Platform facts (Claude Code docs).**

- `BASH_DEFAULT_TIMEOUT_MS` — "Default timeout for long-running bash commands
  (default: 120000, or 2 minutes)".
- `BASH_MAX_TIMEOUT_MS` — "Maximum timeout the model can set … (default:
  600000, or 10 minutes). **The effective ceiling is the larger of this and
  `BASH_DEFAULT_TIMEOUT_MS`**". No maximum value for the variable itself is
  documented.
- The per-call `timeout` parameter exists but is model-set: "you never set a
  per-command timeout"; it is capped by the effective ceiling.
- On timeout: "Claude Code moves it to the background instead of stopping it,
  unless the command starts with `sleep`." And:
  "`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` disables auto-backgrounding along
  with the rest of the background task functionality." **What then happens to a
  timed-out command is not documented.**
- Settable both as a shell export and in `settings.json` under `env` — the
  docs' own example uses `BASH_DEFAULT_TIMEOUT_MS` in an `env` block — and "When
  the same variable is set in both your shell and a settings file `env` block,
  the settings file value applies."
- **Output limits, not in the ticket but load-bearing for verify-fix**: a
  command that **fails** (non-zero exit, which a red test suite is) returns only
  "roughly 10,000 characters" head-and-tail **with no file path**; only a
  successful result gets the 30,000-character / file-path treatment.
  `BASH_MAX_OUTPUT_LENGTH` caps at 150,000 and applies to valid results.
  `cycle-dispatch.md:126-128` already redirects `verify` output to a file under
  `.tsf-tmp/`, which side-steps this; the agents that run `verify` themselves
  (`verify-fix.md:51-58`, `implement.md:64-67`) do not.

**Governance constraint.** The ticket's Open Question 1 is real: CLAUDE.md's
rule "`/tsf:init`'s allowlist append is the second sanctioned `settings.json`
edit … Never widen it — never `git push`, never `gh`, never any other key"
forbids init writing an `env` key. The existing runner variables
(`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`, `GH_TOKEN`) are shell exports in the
clone checklist (`init.md:393-396`, `README.md:86-90`) and checked by the
preflight — an identical mechanism exists for these two.

### C2 — Resume past planning

**What exists.**

- The closed vocabulary is nine values (`cycle-dispatch.md:35-37`,
  `journal-entry.md:52-63`): `triage | research | plan | implement | verify |
  gates | dossier | review | landing`.
- Row 3's resume mapping (`cycle-dispatch.md:116-118`) covers **four**:
  `triage` → triage resume, `research` → research fresh, `plan` → plan fresh,
  `implement` → **re-pick**. A re-pick "writes nothing — it is not a park, and
  it never changes a label" (`cycle-dispatch.md:79-80`), so the ticket is
  skipped every cycle forever.
- `verify`, `gates`, `dossier`, `review`, `landing` have **no mapping at all**
  in row 3 — and an unmapped value falls through to the row table, where a
  `tsf:queued` label matches only rows 2 and 3.
- The Validation section's factory-side correction (`cycle-dispatch.md:55-61`)
  is triggered only for "`tsf:research` or `tsf:plan` whose step is not the
  derived step", and its target mapping names four labels
  (`cycle-dispatch.md:58-59`). `tsf:implement`, `tsf:verify`, `tsf:dossier`,
  `tsf:rework`, `tsf:landing` are never corrected.
- The label→step mapping at `cycle-dispatch.md:47-49` covers `tsf:queued`,
  `tsf:research`, `tsf:plan`, `tsf:answered` only.
- `scan.sh:137` probes pull-request data only for `tsf:verify`, `tsf:dossier`,
  `tsf:needs-review`, `tsf:rework`, `tsf:landing`; a `tsf:queued` record
  carries `pr: skipped`, `pr_head: -`, `ci: skipped`, `review: skipped`
  (`scan.sh:217-222`). So a resume cannot decide anything that needs PR data in
  the same cycle — which is what makes "correct the label and end the cycle"
  the right shape.
- `README.md:248-250` is the only resume instruction: "remove `tsf:needs-human`
  and add `tsf:queued`: the factory continues where the journal says it stood."

**This was already flagged.** `thoughts/shared/research/2026-09-18-TP-0034c-tsf-landing-release.md:164`
recorded it during slice 3: "This must widen for `landing` (and, as written,
**already excludes `verify`/`gates`/`dossier`/`review`** — worth re-reading
during planning)." It was not acted on.

**Episode interaction.** `journal-entry.md:65-74`: the entry that performs a
transition into `tsf:verify` carries `- Episode: [n]`, and the dispatcher reads
the **last** such line. `cycle-dispatch.md:302-305`: "A ticket entering
`tsf:verify` from **implement** or **rework** opens the next one". A resume
into `verify`/`gates` that must open a new episode therefore has to **write a
journal entry** — which means the resume is not a pure label PATCH after all,
or the episode has to be opened elsewhere. `cycle.md:138-153` lists five Step-5
outcomes; a label-correction-and-end is closest to "a decision without an
agent" (→ Step 7), which writes a journal entry, a comment and a label.

### C3 — The rework re-pick livelock

**What exists.**

- `cycle.md:82` makes `tsf:needs-review` actionable when `review:` is
  `approved` **or** `changes-requested`, with no recency test.
- `scan.sh:168-186` determines "the latest review": drop `submitted_at == null`
  and `user == null`, keep `APPROVED|CHANGES_REQUESTED|DISMISSED`, group by
  lower-cased login, take each reviewer's latest, then the single global latest.
  `review_ref:` is the **`commit_id`** for an approval and the **`submitted_at`**
  for a changes-requested (`scan.sh:42`, `:185-186`) — one field, two types.
- `scan.sh:187-195` fills `factory_comment:` from the PR's *issue*-comments
  endpoint, factory-authored, newest `created_at`.
- Row 10 (`cycle-dispatch.md:187-191`) compares `review_ref:` with
  `factory_comment:`: "Older or equal → it is the review a previous rework
  already addressed: **ignore it, journal that**, and leave the ticket parked."
  A journal entry is a commit and a push (`cycle-write-phase.md:35-47`) — and,
  on an open PR, a CI run.
- Sorting: `cycle.md:113-115` puts in-flight before `tsf:queued`, so the
  livelocking ticket outranks every queued one and every younger in-flight one
  on `created` order.
- The approval-stale branch (`cycle-dispatch.md:183-186`) has the same shape:
  "journal the stale approval and write nothing else".

**Mechanism.** Reviews are per-reviewer state, not events: GitHub keeps one
state per reviewer and a dismissal mutates the existing review rather than
adding one (`b:186`). After a rework the human's CHANGES_REQUESTED review is
still the latest decisive review, so `review: changes-requested` persists
indefinitely, the ticket stays actionable, and row 10's "ignore it, journal
that" writes every cycle.

### C4 — Rework never receives the review

**What exists.**

- `cycle-dispatch.md:194-196`: "`review-comments:` the review's body and its
  comments, fetched with `gh-read.sh reviews` and `gh-read.sh pr-comments`".
- `gh-read.sh reviews` (`:322-341`) projects to
  `{login, state, commit_id, submitted_at}` at `:328` — **the body is discarded**
  — and prints `approval:`, `changes:`, `reviewers:` plus a `detail-list:` of
  `--- <login> <state> <commit_id|-> <submitted_at> ---` lines.
- `gh-read.sh pr-comments` (`:343-354`) reads `issues/<n>/comments`, filters to
  the **factory** login, and prints exactly `last-factory:` and `id:` — no text,
  and nothing by anyone else.
- No tsf script touches `pulls/<n>/comments` or `pulls/<n>/reviews/<id>/comments`
  (grep over `plugins/tsf/scripts/` returns nothing).
- `implement.md:39` expects `review-comments:` "the review's comments, verbatim"
  **inline in the prompt**; `implement.md:20` forbids it reading GitHub itself.

So `tsf:implement` in `mode: rework` receives an empty or meaningless brief.

**Platform options for the fix.**

- `GET /pulls/{n}/reviews/{review_id}/comments` exists and is documented
  ("Lists comments for a specific pull request review") but returns the
  **"Legacy Review Comment"** schema — `id, body, created_at, updated_at, user,
  path, position, commit_id, diff_hunk, html_url` — which is *not* guaranteed
  to carry the modern `line`, `start_line`, `side`, `start_side`, `subject_type`.
- `GET /pulls/{n}/comments` returns the modern schema with those fields,
  supports `sort`/`direction`/`since`, and carries `pull_request_review_id` —
  but has **no query parameter to filter by review**, so filtering is
  client-side over a full paginated fetch.
- `line` can become `null` on an outdated comment; `original_line` +
  `original_commit_id` is what survives. This is **not documented**.
- The review body itself comes from `GET /pulls/{n}/reviews` (field `body`,
  required, string).

### C5 — The landing cannot decide

**What exists.**

- `scan.sh:161-198`: the `case "$STATE"` gives review data to
  `tsf:needs-review|tsf:rework` only; everything else, `tsf:landing` included,
  falls to `*) REVIEW="skipped"; FACTORY_COMMENT="skipped"` at `:197`, with
  `REVIEW_REF` left at its `:148` default `-`.
- `cycle.md:103-105` orders landings "by `review_ref:`, **oldest approval
  first**" — a field that is `-` for every landing ticket, and would be a
  **commit sha, not a timestamp**, even when filled.
- Row 12 feeds `review_ref` to `diff.sh ancestor --of <review_ref>`
  (`cycle-dispatch.md:235`) and to `diff.sh main-delta --approval <review_ref>`
  (`cycle-dispatch.md:224`). `diff.sh:371-375` returns `result: unknown` when
  either rev fails to resolve; `diff.sh:312-317` leaves `START` empty and
  reports `failed` when `git merge-base` cannot use the argument.
- `cycle-dispatch.md:230-235`'s decide condition requires the `ancestor` probe
  to be `yes`; `unknown` is not `yes`, so the landing is "not decided" → dossier
  addendum → `tsf:needs-review` (`:239-240`) → row 10 approves again →
  `tsf:landing` → repeat, one addendum per round.

**The C3 collision (new finding).** `cycle-write-phase.md:149-153`: the landing
decision cycle posts "**One comment on the issue**" *and* "**The gate's
one-liner on the pull request** when the gate ran". `scan.sh:192-195` reads
`factory_comment:` from the PR. So after a landing decision cycle that ran the
integration gate, the factory's last PR comment is newer than the approval's
`submitted_at`. If C3's rule ("the record reports no review" when the review is
not newer than the factory's last PR comment) is applied to approvals for
landing tickets, the landing loses its `review:` and `review_ref:` again on the
second cycle. Planning must decide where the recency rule applies — plausibly:
to changes-requested only at scan level, with approvals keeping `diff.sh
ancestor` as their guard (which is what row 10 already does and what
DESIGN.md §4 row 10 specifies), and C3's "both kinds" being the part to
revise.

### C6 — Conflicted PRs wait for CI forever; `pending` is unbounded

**What exists.**

- `scan.sh:155-160`: zero check runs → `pending`; any run not `completed` →
  `pending`; any conclusion in `failure|timed_out|action_required|cancelled` →
  `failure`; else `success`.
- `cycle.md:80-81` and `:92`: a `tsf:verify` ticket with `ci: pending` is **not
  actionable and is skipped by Step 3** — it never reaches row 6 or row 7. Row
  7's `pending` branch (`cycle-dispatch.md:142`) is unreachable in practice:
  "Step 3 already skipped it".
- There is no time bound anywhere; `cycle-report.md:68-76` only paces `/loop`.
- `scan.sh:141` uses the **list** pulls endpoint, whose objects carry no
  `mergeable`/`mergeable_state` at all. Only `gh-read.sh pr-state` (`:278-301`)
  reads the single-PR endpoint, with a 3-attempt / 2-second poll while
  `mergeable` is null.

**Consequence for the fix's placement.** Because Step 3 skips the ticket before
any row runs, a conflict probe cannot live in row 6/7 as written. Either Step 3
gains the probe, or the scan gains a field that distinguishes "pending with zero
check runs" from "pending with runs in flight" so the pick can act on it. The
scan currently collapses both into `pending` (`scan.sh:157-158`).

**Platform facts.**

- Confirmed verbatim: "Workflows will not run on `pull_request` activity if the
  pull request has a merge conflict. The merge conflict must be resolved
  first." No per-activity-type exception is documented (so "all types" is
  inference from silence).
- **CI restarting is not documented and is not automatic in general.** A
  resolution pushed to the **head** branch produces `synchronize` and thus a
  run; a conflict cleared by a change to the **base** branch produces **no
  `pull_request` event at all**. The factory's resolution is a push to the head
  branch, so it does restart CI — but the detector must not assume an event
  will arrive in the general case.
- `mergeable` is documented (`true|false|null`; `null` means a background job is
  computing it; "After giving the job time to complete, resubmit the request").
  No interval, timeout or callback is documented.
- `mergeable_state` **is** in the REST schema but as a bare `string` with **no
  description and no enum**; the eight known values are undocumented. Prior
  research recorded a GitHub-staff statement that it is "unofficial, in flux,
  may possibly go away" (`…TP-0034c…:229-238`), and the slice-3 spike observed
  `behind` as real (`…TP-0034c…:696-700`).
- Also undocumented but real: the `stale` check-run conclusion ("You cannot
  change a check run conclusion to `stale`, only GitHub can set this") is
  absent from the documented enum and from both of tsf's classification sets
  (`scan.sh:159`, `gh-read.sh:309-310`).

**Time source for the age bound.** `preflight.sh:148`'s `now:` is the local
clock at minute resolution. Candidate reference points for "how long has this
head been pending": the head commit's committer date in the clone (available
after `prepare`; set by GitHub for a server-made sync merge, by the factory for
its own pushes), the PR object's `updated_at`, or a check suite's `created_at`.
Clock skew between the runner and GitHub is unbounded and undocumented.

### C7 — CI state counts every check run

**What exists.** `scan.sh:150-160` and `gh-read.sh:303-320` reduce **all** check
runs on the head; neither takes a check-name argument, reads branch protection
or rulesets, nor distinguishes required from optional. Commit **statuses** are
never read (`gh-read.sh:79-81`), which is correct for Actions —
"GitHub Actions results are check runs and never appear in
`GET /commits/{ref}/status`" (`…TP-0034b…:69-72`, `:185`). `gh-read.sh:317`
prints failing run **names** (`failed:`), the only check-name data available
today.

**Why config must carry the names.** Required checks are not discoverable by
the API tsf can use: "neither commit endpoint says which checks are *required*
(only the admin-only branch-protection endpoint does, and **repository rulesets
are not reflected there at all**)" (`…TP-0034b…:63-66`). The first consumer's
required check is a display name — `verify (lint, depcruise, typecheck, test)`,
marked "LOAD-BEARING NAME" in
`/Users/toby/code/work/chat-sustainability/.github/workflows/verify.yml:24-30`.
The check-runs endpoint does offer a `check_name` query parameter ("Returns
check runs with the specified name"), one name per call; client-side `jq`
filtering over the existing single call covers a set of names.

**The TODO item it settles.** `plugins/tsf/TODO.md:8-33`, "Detect that a
repository has no pull-request CI", already names exactly this fix: "a precheck
in `/tsf:init` … and records the answer in `.claude/tsf/config.md`, so the cycle
can distinguish 'waiting' from 'this project has none'". `README.md:297-300`
repeats the symptom.

### C8 — The server-side sync is asynchronous

**What exists.** `gh-write.sh:407-430`: one `PUT …/pulls/<n>/update-branch` via
`tsf_api_retry`, any 2xx → `previous_head: <what was sent>` and
`result: synced`, detail "the head moves shortly". **No poll, no read-back** —
the value printed is the value supplied, not an observed new head. The 422
family is discriminated by message into `up-to-date`, `conflict`, `head-moved`,
else `failed` (`:417-427`). The header documents the asynchrony at
`gh-write.sh:76-77`.

`cycle-dispatch.md:209-211` then runs `prepare` "**again** so the clone holds
the merged head" immediately.

**Platform facts.** The 202 is documented; `expected_head_sha` is documented as
the optimistic-concurrency guard ("If the expected SHA does not match … you will
receive a 422"). **There is no documented completion signal** — no job resource,
no webhook contract; polling `GET /pulls/{n}` until `head.sha` differs is an
inference. The slice-3 spike measured the head as already moved on the first
poll at ~6 s, with the first check run ~8 s after the sync commit, and never
observed a zero-check-run window (`…TP-0034c…:709-713`) — which lowers but does
not remove the risk.

**Precedent for bounded polling in-repo**: `gh-read.sh:282-291` polls the
single-PR endpoint 3 times with `sleep 2` while `mergeable` is null.

### C9 — Every bookkeeping push costs a CI run

**What exists.** Journal, report, dossier and decision commits are all pushed to
an open PR (`cycle-write-phase.md:40-47`, `:110-112`, `:125`, `:142-147`), and
the PR is never a draft, so each starts the full required check.
`plugins/tsf/TODO.md:35-60` records the landing's two runs and states the wrong
fix explicitly: "the wrong fix — path-filtering the workflow — breaks the merge
outright, because a filtered-out required check stays 'expected' forever".

**Platform facts confirming that.**

- Required checks that never report block the PR: "Associated checks stay in a
  'Pending' state and block merging", with the docs' own advice "Avoid requiring
  workflows that can be skipped." (The literal UI word "Expected" is community
  lore, not documentation; the documented strings are "Pending" and "Waiting for
  status to be reported".)
- `paths`/`paths-ignore` on `pull_request` evaluate the **three-dot diff**:
  "a comparison between the most recent version of the topic branch and the
  commit where the topic branch was last synced with the base branch" — the whole
  PR diff, not the single push. This is why a path filter cannot express
  "this push touched only `thoughts/`".
- `before`/`after` on `synchronize`: **not in GitHub's documented payload table**.
  They are required properties in octokit's generated schema for
  `pull_request/synchronize`, with no descriptions; `opened` has neither
  property at all. On a force-push `before` may be unreachable.
  `pull_request.base.sha` / `head.sha` are documented; `before` is not.
- Reading the parent's result inside the job:
  `GET /repos/{owner}/{repo}/commits/{ref}/check-runs` accepts a SHA and a
  `check_name` filter, with `filter=latest` the default.
  `GITHUB_TOKEN` needs `checks: read`, and critically: "If you specify the access
  for any of these permissions, all of those that are not specified are set to
  `none`." The first consumer's workflow already declares
  `permissions: contents: read` (`verify.yml:19-20`), so `checks: read` must be
  added explicitly.
- Conclusions: `success, failure, neutral, cancelled, skipped, timed_out,
  action_required, null` — plus the undocumented `stale`.

**Why the third case of the inherit rule is load-bearing.** The first consumer's
workflow sets `concurrency: cancel-in-progress: true` keyed on `head_ref`
(`verify.yml:14-16`). At landing, the server's sync merge and the factory's
decision commit arrive as two pushes; the second cancels the first's run, which
is exactly the "cancelled" case the ticket's rule routes to a full run.

**Existing template shape to follow.** `plugins/tsf/templates/github/` holds one
file, `tsf-comment-pickup.yml`, with a `__TSF_RESPONDERS_JSON__` placeholder
substituted by `init.md:370`; `init.md:363-373` is the install step, and it
tells the user the workflow "fires only once the file is on the default branch;
pushing it needs the `workflow` token scope".

### C10 — Implementation is all or nothing

**What exists.** `implement.md:59-76` (fresh mode) works through every increment
in one context; nothing is pushed until it returns (`implement.md:102`,
`cycle-write-phase.md:44-47`). `prepare` hard-resets the clone every cycle
(`prepare.sh:16-20`, `cycle.md:124-126`), so an unreturned context's commits are
discarded. `mode: fresh` receives no statement of what already exists
(`implement.md:33-41`).

**What a fix touches beyond the agent.**

- **The allowed-outcomes table has no row for it.** `result-block.md:83-84`:
  `implement | continued | tsf:verify | verify` and `implement | parked |
  tsf:needs-answer | implement`. A batched return of
  `continued / tsf:implement / implement` fails parsing rule 4
  (`result-block.md:121-126`) and triggers the re-dispatch-then-park path.
- **The journal entry shape** would gain a done-increments field
  (`journal-entry.md:30-39` fixes the field list and its order), which is the
  span named in CLAUDE.md's "journal's `Next step` is the derived state" rule.
- **The PR-open trigger** is "After a successful **implement** in `mode: fresh`"
  (`cycle-write-phase.md:67-68`) — it needs a "and this was the last batch"
  qualifier.
- **The one-comment-per-step rule** (DESIGN.md §10) is what item 4's "no issue
  comment before the last batch" bends; `result-block.md:121-126` requires
  `tsf-comment` to be **non-empty** for a valid return.
- **Increment identity.** Plans number increments `### Increment N: [name]`
  (`plan.md:53`, `:64`). Nothing enforces uniqueness or stability today.
- **Prior research never considered this.** None of the three slice research
  documents discusses batching, per-cycle scope or resumability of
  implementation — it is an unexamined premise, not a researched decision.

### C11 — Criteria extraction vs. invariant 3

**What exists.** Invariant 3 verbatim (`cycle.md:24-27`):

> **No content work.** Never read the body of a spec, research, plan or diff,
> never write artifact content, never judge a step's output. You read only:
> labels, file existence, the journal's last entry, result blocks and a gate
> report's two machine lines. The diff reaches the gates **as a path**.

The dispatcher is nevertheless instructed to extract plan/spec content in
**five** places (the ticket names two):

1. `cycle-dispatch.md:152-156` — row 8: "for plan-compliance, the plan's
   numbered per-increment criteria including addenda; for spec-coverage, the
   spec's text".
2. `cycle-dispatch.md:134-136` — row 6: "when `plan.md` has `**Manual**` items
   … dispatch **tsf:manual-verify** with them".
3. `cycle-dispatch.md:226-227` — row 12 step 2: integration gets "the two diff
   paths and **the spec's text**".
4. `cycle-dispatch.md:354-355` — payload: `manual-items:` "(the plan's
   `**Manual**` items, verbatim and numbered)".
5. `cycle-dispatch.md:360-366` — payload: criteria verbatim for
   plan-compliance, spec text verbatim for spec-coverage **and** integration.

**Why the diff was already moved and the criteria were not.**
`…TP-0034b…:468-477` records the decision: three options were weighed for the
diff, "(b) the dispatcher writes the diff to a file … and passes the **path** …
**(b) looks right and is a deviation from §11.2's 'in the spawn prompt' worth
surfacing**". The criteria were left on the inherited tce precedent — "criteria
passed **verbatim in the prompt** rather than read from files" (`…TP-0034a…:736-740`)
— with no corresponding analysis. The asymmetry is unexamined, not decided.

**What the plan format offers a checker.** `plan.md:40-84` is the full skeleton:
`## Increments`, then `### Increment N: [name]` with `**What changes:**`,
`**Where:**`, `**Verification:**`, `**Manual:**` (conditional, "omit the line
otherwise"), `**Depends on:**` (conditional). `## Addenda` is a bare section
(`plan.md:80-83`) described only as "[Deviations recorded during
implementation, each restating the affected increment's verification. Empty
until implementation.]" — **no per-entry shape, no date format, no increment
back-reference syntax**. `## Feedback` by contrast does have one
(`plan.md:78`).

**A parsing hazard with direct in-repo precedent.** CLAUDE.md's TP-0033 rule for
`plugins/tce/scripts/stage.sh`: "**Fenced code blocks are stripped before any
heading is matched.** Plans in a plugin repo quote the plugin's own markdown, so
in-fence `## Phase N:` … headings are real, confirmed false positives." A tsf
plan for a project that documents markdown has the same exposure for
`### Increment N:`.

**Agent-side reads.** `plan-compliance.md:22-24` and `spec-coverage.md:22-23`
describe their inputs as verbatim text today; `plan-compliance.md:29-33` and
`spec-coverage.md:28-33` forbid opening anything under `thoughts/` "other than
the diff file you were given" — so switching criteria to a path means widening
that permission by exactly one named file, in the gate prompts.

**Template reads inside subagents.** `…TP-0034c…:530-532`: point-of-use template
reads use the `templates:` payload value "**because `${CLAUDE_PLUGIN_ROOT}` is
not expanded inside a subagent prompt**".

### C12 — No write path for the PR title and body

**What exists.** `cycle-write-phase.md:131-133`: "When the agent reported that
the pull request's title or body does not match the template, fix it with
`gh-write.sh` before posting the dossier" — **no subcommand, no flags**, the only
such mention in the file (compare the concrete invocations at `:49`, `:52`,
`:55`, `:74`, `:181`, `:215`).

The complete write set of `gh-write.sh` is: `POST issues/<n>/comments` (`:223`),
`PUT issues/<n>/labels` (`:241`), `PATCH issues/<n>` (`:280`), `POST issues`
(`:292`), `POST labels` (`:305`), `PATCH labels/<name>` (`:314`),
`POST git/refs` (`:326`), `POST pulls` (`:352`), `PUT contents/<p>` (`:394`),
`PUT pulls/<n>/update-branch` (`:409`), `PUT pulls/<n>/merge` (`:436`),
`DELETE git/refs/heads/<b>` (`:460`). There is **no `PATCH repos/O/R/pulls/<n>`**.
A PR title is sent only at creation (`gh-write.sh:350-351`).

`PATCH /repos/{owner}/{repo}/pulls/{pull_number}` is documented with `title`,
`body`, `state`, `base`, `maintainer_can_modify`. (The success status code was
retrieved as 201 and is conventionally 200; immaterial here, since `tsf_api`
classifies any 2xx as `ok` — `lib.sh:104-105`.) The `ref-create`/`contents-put`
read-back pattern (`gh-write.sh:336-341`, `:398-401`) is the in-repo precedent
for "read back, else `mismatch`".

## Defect Mechanism

Six of the twelve are state-machine defects whose mechanism is worth tracing
end to end; the others are missing implementations (C4, C12), a missing bound
(C6b), a missing filter (C7), a missing poll (C8) and an unexamined premise
(C10).

**C2 — the silent skip.** Intended (DESIGN.md §3.4, §4 row 3): "the dispatcher
treats `tsf:queued` on a ticket that already has a journal as 'resume at the
journal's `Next step`'". Actual: `cycle-dispatch.md:116-118` maps four of nine
values and answers `implement` with a re-pick. Divergence: a re-pick "writes
nothing … and never changes a label" (`cycle-dispatch.md:79-80`), so the ticket
is re-scanned, re-picked, re-skipped every cycle, and the five later values are
not mapped at all — they fall through row 3 and match no other row for a
`tsf:queued` label. Symptom: a ticket parked anywhere from implementation
onwards can never be resumed, which is where most parks happen (exhausted
bounds, environment failures, failed pushes, CI-red-with-local-green, a blocked
merge-resolver).

**C3 — the livelock.** Intended (DESIGN.md §4 row 10): a changes-requested
review counts only when newer than the factory's last dossier/addendum comment;
an older one "is the review the rework already addressed and is ignored".
Actual: "ignored" is implemented as *actionable, then journalled*
(`cycle.md:82` makes it actionable; `cycle-dispatch.md:189-191` journals).
Divergence: a journal entry is a commit + push (`cycle-write-phase.md:40-47`),
so "ignore" costs a CI run. Propagation: the ticket sorts as in-flight
(`cycle.md:113-115`), so it is picked first every cycle and starves the queue —
at the `/loop` pace of one to five minutes (`cycle-report.md:68-76`).

**C5 — the bounce.** Intended (§9.3 step 4): decide for the merge when the
approval is at or after the logic head. Actual: `scan.sh:197` sets
`review: skipped` / `review_ref: -` for `tsf:landing`. Divergence:
`diff.sh ancestor --of -` fails the rev check at `diff.sh:371-372` and returns
`result: unknown`; the decide condition (`cycle-dispatch.md:234-235`) requires
`yes`. Propagation: not decided → dossier addendum + `tsf:needs-review`
(`:239-240`) → row 10 reads an approval → `tsf:landing` → repeat, one addendum
per round, until `landing_attempt_bound`… which is itself never incremented,
because the attempt counter counts `step: landing` entries since the ticket
entered landing (`journal-entry.md:78-84`) and a bounce re-enters landing each
time.

**C6a — the invisible wait.** Intended: CI is read at pickup and a red or green
result routes the ticket. Actual: a conflicted PR runs no workflow at all, so
the head has zero check runs; `scan.sh:157` maps zero runs to `pending`;
`cycle.md:80-81` makes `pending` not actionable. Divergence: the ticket is
skipped by Step 3 before any row can notice the conflict, and conflicts are
only resolved at landing — after approval, which this ticket will never reach.

**C9 — the CI amplifier.** Intended (§3.5): "every journal, report and dossier
commit is inert by construction". Actual: inert *for the logic head*, not for
CI — the required check is evaluated on the plain PR head, which every such
commit moves. Divergence: the logic-head abstraction was built to keep gates and
approvals stable across bookkeeping commits, and nothing was built to keep CI
stable across them.

**C11 — the contradiction.** Intended: invariant 3, "Never read the body of a
spec, research, plan or diff". Actual: five instructions to do exactly that
(listed above). Divergence: the diff was given a pass-by-path mechanism in slice
2 and the criteria were not, so the invariant holds for the larger payload and
is violated for the smaller one — with no enforcement that a plan is even
parsable, since a model writes it.

## Impact Analysis

### Existing usages found

- **The scan record** — one producer (`scan.sh:208-226`), one consumer
  (`cycle.md:74-118` Step 3 and `cycle-dispatch.md:42-45`). Fields consumed:
  `state`, `priority`, `created`, `reply`, `pr`, `pr_head`, `ci`, `review`,
  `review_ref`, `factory_comment`.
- **`review_ref:`** — read as a **commit sha** at `cycle-dispatch.md:182`,
  `:222-224`, `:235`; as a **timestamp** at `cycle-dispatch.md:187-189`; as a
  **sort key** at `cycle.md:103`.
- **`ci:`** — `cycle.md:80-81`, `:92`, `:106-107`; `cycle-dispatch.md:140-146`,
  `:256-257`.
- **`gh-read.sh checks`** — one caller, `cycle-dispatch.md:143-145`.
- **`gh-write.sh update-branch`** — one caller, `cycle-dispatch.md:207-219`.
- **The result block's allowed-outcomes table** (`result-block.md:75-89`) —
  applied by `cycle.md:176-180` on every worker return.
- **The journal entry shape** (`journal-entry.md:30-39`) — written by
  `cycle-write-phase.md:35-39` and by every worker's `tsf-journal` fence.
- **`preflight.sh`'s output** — `cycle.md:52-62` (`now:`, `result:`, `detail:`)
  and `init.md:263-272` (`result: incomplete`).
- **`config.md`'s `## Constants`** — three today (`verify_fix_bound`,
  `gate_fix_bound`, `landing_attempt_bound`), documented in
  `templates/tsf/config.md:71-78`, `init.md:425-430`, `README.md:271-276`,
  `:200-203`.

### Current contract

- Every tsf script: sub-command first, long `--flag value` pairs, three-line
  trailer (`result:`/`status:`/`detail:` or a per-script variant), **every
  reported outcome exits 0, only usage errors exit 1**, no script reads
  `config.md` (`lib.sh:9-10`).
- `tsf_api` classes: `ok | rejected | denied | transport | auth`
  (`lib.sh:100-110`); one retry, transport only (`lib.sh:125-130`);
  `tsf_api_list` pages 100×10 = 1000 items max, silently truncated
  (`lib.sh:141-161`).
- Gates: `tools: Read, Grep, Glob`, report content returned, `head:`/`verdict:`
  parsed and nothing else (`report.md:39-76`).
- `/tsf:cycle`'s `allowed-tools` (`cycle.md:4`) grants each script by exact
  prefix `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh":*)` plus six read/commit
  `git` verbs. It grants **no** `Write`/`Edit` and no project contract scripts —
  those come from the project allowlist `init.md:320-361` writes.

### Adaptation requirements

- `scan.sh` — new fields (C5's approval timestamp, C6's zero-check-run signal,
  C7's required-name filtering, C3's staleness) mean the header block at
  `:31-52` and the `jq` emitter at `:208-224` move together; `cycle.md` Step 3
  and `cycle-dispatch.md` follow. The record is **not** currently listed among
  the repo's declared machine contracts (CLAUDE.md names the result block, the
  journal `Next step`, and the gate report) — the ticket's Governance criterion
  asks for that rule.
- `gh-read.sh` — a new subcommand for C4 must write its payload to a **file**
  via its own flag: a shell redirect (`… > file`) changes the command string and
  would not match the `allowed-tools` prefix, and the dispatcher must not hold
  the content (invariant 3). Same for C11's criteria file.
- `gh-write.sh` — C8 turns `update-branch` into a polling call (its `result:`
  gains an outcome and its output gains an observed head); C12 adds a
  `PATCH pulls/<n>` subcommand. Both are inside the "dispatcher owns every
  GitHub write" span: `cycle.md`, `cycle-write-phase.md`, `spec.md`, `init.md`.
- `preflight.sh` — two new lines in a fixed-length output contract; `cycle.md`
  Step 1 and `init.md` Phase 4 step 3 read it.
- `config.md` — new required content (required check names, `ci_pending_bound`,
  `implement_batch`) triggers CLAUDE.md's "extend `/tsf:init`'s Idempotency
  upgrade list in the same commit" rule (`init.md:422-433`) and a version bump
  in both manifests (currently `1.0.0` in
  `plugins/tsf/.claude-plugin/plugin.json:3` and
  `.claude-plugin/marketplace.json:33`).

### Backward compatibility options

- **Scan record** — Option A: extend in place, new fields defaulting to
  `skipped`/`-` where not probed (the slice-2 precedent, `…TP-0034b…:436-446`).
  Option B: rename the overloaded `review_ref:` into two fields. B is what C5
  asks for and is the breaking one; both consumers are in this repo, so the
  breakage is contained — but it is a machine-contract change, so the header,
  `cycle.md` Step 3 and `cycle-dispatch.md` must move in one commit.
- **`config.md` constants** — the `landing_attempt_bound` precedent
  (`init.md:428-430`) is "a config without the line is upgraded by appending it;
  until then the landing falls back to 3", i.e. a documented default in the
  consuming prose so an un-upgraded project keeps working. The same shape is
  available for `ci_pending_bound` and `implement_batch`; **required check
  names have no safe default** — absent, the only non-breaking reading is
  today's "all checks count".

## Code References

- `plugins/tsf/scripts/scan.sh:31-52` — the record format header (the contract).
- `plugins/tsf/scripts/scan.sh:137`, `:148`, `:161-198` — which states get PR,
  CI and review data; the `*)` fallback that blanks review data for landings.
- `plugins/tsf/scripts/scan.sh:155-160` — CI reduction; zero runs → `pending`.
- `plugins/tsf/scripts/scan.sh:168-186` — latest-review reduction; `review_ref:`
  as commit_id or submitted_at.
- `plugins/tsf/scripts/scan.sh:187-195` — `factory_comment:` from the PR's
  issue-comments.
- `plugins/tsf/scripts/gh-read.sh:303-320` — `checks`, all runs, no name filter.
- `plugins/tsf/scripts/gh-read.sh:322-341` — `reviews`, body discarded at `:328`.
- `plugins/tsf/scripts/gh-read.sh:343-354` — `pr-comments`, factory only, two lines.
- `plugins/tsf/scripts/gh-read.sh:278-301` — `pr-state`, the 3×2s `mergeable` poll.
- `plugins/tsf/scripts/gh-write.sh:66-85` — `update-branch` header docs.
- `plugins/tsf/scripts/gh-write.sh:407-430` — `update-branch` implementation, no poll.
- `plugins/tsf/scripts/gh-write.sh:221-472` — the complete subcommand set (no PR PATCH).
- `plugins/tsf/scripts/preflight.sh:27-39` — the output contract.
- `plugins/tsf/scripts/preflight.sh:109-117` — the `--foreground` check.
- `plugins/tsf/scripts/preflight.sh:148`, `:157-163` — `now:` and `result:`.
- `plugins/tsf/scripts/diff.sh:294-343` — `main-delta`, `--from` vs `--approval`.
- `plugins/tsf/scripts/diff.sh:370-385` — `ancestor`, `unknown` on an unresolvable rev.
- `plugins/tsf/scripts/diff.sh:249-292` — `logic-head`, first-parent walk + trailer.
- `plugins/tsf/scripts/lib.sh:100-110`, `:125-130`, `:141-161` — API classes,
  retry, pagination.
- `plugins/tsf/commands/cycle.md:4` — `allowed-tools`.
- `plugins/tsf/commands/cycle.md:24-27` — invariant 3.
- `plugins/tsf/commands/cycle.md:74-118` — Step 3, actionability, landing order,
  global order.
- `plugins/tsf/commands/cycle.md:120-136` — Step 4, the environment cadence.
- `plugins/tsf/commands/cycle.md:138-153` — Step 5's five outcomes.
- `plugins/tsf/references/cycle-dispatch.md:35-49` — the closed vocabulary, the
  derived step, the label→step map.
- `plugins/tsf/references/cycle-dispatch.md:51-81` — Validation and the re-pick.
- `plugins/tsf/references/cycle-dispatch.md:111-119` — row 3.
- `plugins/tsf/references/cycle-dispatch.md:126-138` — row 6 (`verify` run, manual items).
- `plugins/tsf/references/cycle-dispatch.md:148-163` — row 8 (gates, criteria).
- `plugins/tsf/references/cycle-dispatch.md:178-192` — row 10 (review read).
- `plugins/tsf/references/cycle-dispatch.md:194-198` — row 11 (rework).
- `plugins/tsf/references/cycle-dispatch.md:200-293` — row 12 (landing).
- `plugins/tsf/references/cycle-dispatch.md:298-328` — the counters.
- `plugins/tsf/references/cycle-dispatch.md:330-372` — the spawn payload.
- `plugins/tsf/references/cycle-write-phase.md:35-63` — the write sequence.
- `plugins/tsf/references/cycle-write-phase.md:99-119` — the gate cycle's writes.
- `plugins/tsf/references/cycle-write-phase.md:121-133` — the dossier's writes
  (the unnamed `gh-write.sh`).
- `plugins/tsf/references/cycle-write-phase.md:135-169` — the landing's two cycles.
- `plugins/tsf/references/templates/result-block.md:75-89` — allowed outcomes.
- `plugins/tsf/references/templates/result-block.md:112-132` — parsing rules.
- `plugins/tsf/references/templates/journal-entry.md:30-39` — the entry shape.
- `plugins/tsf/references/templates/journal-entry.md:65-84` — Episode and Attempt.
- `plugins/tsf/references/templates/report.md:39-76` — the machine lines.
- `plugins/tsf/references/templates/plan.md:40-84` — the plan skeleton and `## Addenda`.
- `plugins/tsf/agents/implement.md:29-42` — the payload contract.
- `plugins/tsf/agents/implement.md:59-93` — the three modes.
- `plugins/tsf/agents/plan-compliance.md:20-33` — criteria verbatim, diff by path.
- `plugins/tsf/agents/spec-coverage.md:20-33` — spec verbatim, diff by path.
- `plugins/tsf/commands/init.md:320-361` — the allowlist append.
- `plugins/tsf/commands/init.md:375-397` — the ruleset and clone checklists.
- `plugins/tsf/commands/init.md:409-433` — Idempotency and the upgrade list.
- `plugins/tsf/templates/tsf/config.md:71-78` — the three constants.
- `plugins/tsf/TODO.md:8-33`, `:35-60` — the two TODO items the ticket settles.
- `/Users/toby/code/work/chat-sustainability/.github/workflows/verify.yml:14-16`,
  `:24-30`, `:19-20`, `:74-76` — the first consumer's concurrency, required
  check display name, permissions block, and merge-ref checkout.

## Architecture Documentation

- **Counters are read from disk, never from conversation** — episode from the
  journal's last `- Episode:`, verify-fix attempt and gate round from report
  filenames, landing attempt from `step: landing` entry counts
  (`cycle-dispatch.md:298-318`). Any new counter C10 introduces is expected to
  follow this.
- **Reachability, never existence** — `diff.sh ancestor` uses
  `git merge-base --is-ancestor` (`diff.sh:377`) and `logic-head` walks
  `--first-parent` (`diff.sh:277-279`). The TP-0030 lesson.
- **Pass-by-path for anything the dispatcher must not read** — the diff
  (`cycle.md:164-166`), the local verify output (`cycle-dispatch.md:126-128`),
  the gate reports (`cycle-dispatch.md:159-160`).
- **The dispatcher writes what read-only agents cannot** — gate reports
  (`report.md:23-28`), the `head: unknown` substitution
  (`cycle-write-phase.md:104-107`).
- **Two-tier failure handling** — a `result:` the state machine expects is a
  branch, not a failure (`gh-write.sh:66-68`); anything else parks via
  `cycle-write-phase.md:171-183`.
- **Dialog copy and reference files** — twelve byte-identical AskUserQuestion
  blocks (two of them tsf's, `init.md:31-49` and `spec.md`); reference files are
  read at the point of use "now — in full".
- **Compaction budget** — `cycle.md` is 12,388 bytes (~3,100 tokens) against the
  5,000-token per-skill budget recorded in `…TP-0034b…:522-525`;
  `cycle-dispatch.md` is 20,128 bytes. C2, C6, C7, C10 and C11 all add
  dispatcher prose.

## Historical Context (from thoughts/)

- `thoughts/shared/research/2026-09-18-TP-0034c-tsf-landing-release.md:164` —
  **already flagged C2**: the readable-`Next step` set "must widen for
  `landing` (and, as written, already excludes `verify`/`gates`/`dossier`/`review`)".
- `…TP-0034c…:664-692` — the sync merge is authored by the calling identity and
  committed by `web-flow`; hence the two-discriminator `logic-head` rule.
- `…TP-0034c…:709-713` — the update-branch spike: head moved by ~6 s, first check
  run ~8 s, no zero-check-run window observed.
- `…TP-0034c…:550-556` — "the end-to-end smoke test was never run"; and the
  cautionary precedent that slice 2's own plan-compliance gate "caught two real
  gaps on its first run, both about counters/inputs that nothing actually wrote".
- `thoughts/shared/research/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md:468-477`
  — the diff-pass-by-path decision, explicitly "a deviation from §11.2 … worth
  surfacing"; the criteria were never given the same treatment.
- `…TP-0034b…:506-511` — the zero-check-runs ambiguity, with "the first
  consumer's required check is identified by **display name** … which also
  argues for reading check runs by name" (C7's fix, proposed two slices ago).
- `…TP-0034b…:54-57` — the list of closed vocabularies that must move in
  lock-step; **the scan record is not in it**.
- `…TP-0034b…:512-517` — instruction-shaped text in agent returns and the
  harness's backslash insertion; relevant to C4, whose payload is human-written
  review text handed to an agent with a shell.
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md:506`
  — the only prior record of the Bash timeout ("2 min / 10 min ceiling… A longer
  sleep is killed, not backgrounded"), dated 2026-08-11 and never re-verified;
  the current docs contradict the "killed" half for non-`sleep` commands.
- `plugins/tsf/TODO.md:80-110`, `:112-132` — the two deferred review items
  (permission mode; responder-scoped reviews) are already committed, in
  `100a2f6`, so the ticket's "commit them with this ticket" is done.

## Related Research

- `thoughts/shared/research/2026-09-16-TP-0034a-tsf-foundation-human-gates.md`
- `thoughts/shared/research/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`
- `thoughts/shared/research/2026-09-18-TP-0034c-tsf-landing-release.md`
- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` (the
  review DESIGN.md came out of)

## Open Questions

1. **C3 × C5 (the one that must be settled first).** Does the scan-level
   staleness rule apply to approvals, given that the landing's own decision
   cycle posts a PR comment and would thereby stale its own approval? The
   design's existing answer for approvals is `diff.sh ancestor` (§4 row 10), not
   a timestamp.
2. **C2 — is the resume a pure label PATCH?** A resume into `verify`/`gates`
   must open a new episode, and the episode number lives in a journal entry
   (`journal-entry.md:65-74`) — so either the resume writes an entry, or the
   episode is opened by whatever runs next.
3. **C6 — where the conflict probe lives**, given that Step 3 skips a
   `ci: pending` ticket before any row runs, and the scan cannot today
   distinguish "zero check runs" from "runs in flight".
4. **C6 — the time source** for `ci_pending_bound`: the head commit's committer
   date in the clone, the PR's `updated_at`, or a check suite's `created_at` —
   against `preflight.sh`'s local-clock, minute-resolution `now:`.
5. **C1 — which values to require**, and whether to require them as shell
   exports (no governance change) or to revisit the settings.json rule. Note
   `BASH_MAX_TIMEOUT_MS` has no documented ceiling and the effective ceiling is
   `max(MAX, DEFAULT)`.
6. **C9 — `before` is undocumented** on `synchronize` and absent on `opened`.
   Does the snippet key on it, or on `pull_request.base.sha`/`head.sha` (both
   documented) with a different definition of "the push's own delta"?
7. **C10 — the allowed-outcomes row and the journal field**: what exactly a
   batched implement return looks like, and how increments are identified
   stably enough for a no-progress guard.
8. **C11 — one script or a `diff.sh`-style multi-mode script**, and the addendum
   shape `plan.md` must gain. Whichever it is, fenced code blocks must be
   stripped before headings are matched (the TP-0033 lesson).
9. **Ordering and slicing.** Twelve corrections across ~20 files with six
   declared same-commit spans; the ticket does not say whether they land as one
   release or several. C3+C5 are coupled; C7 is a prerequisite for C6's
   zero-check-run signal being meaningful; C11 changes what the gates receive
   and therefore touches every gate agent.
10. **`/tsf:cycle`'s size** against the 5,000-token per-skill compaction budget,
    given that five corrections add dispatcher prose.

## tce Config Drift

No drift found between `.claude/tce/profile.md` / `.claude/tce/tickets.md` and
the repository: the stack, the test command (`claude plugin validate` for the
marketplace and all four plugins), the code map and the tmt backend adapter all
match. `/tce:refresh` is not indicated.

(Separately — not tce config, so not a refresh matter — the repository
`CLAUDE.md`'s Layout block for `plugins/tsf/` is stale against slices 2 and 3:
`scripts/*.sh` omits `diff.sh`, and `agents/*.md` still reads "triage, research,
plan (slice 1)" where twelve agents now exist. The ticket's Governance
acceptance criterion touches CLAUDE.md anyway.)
