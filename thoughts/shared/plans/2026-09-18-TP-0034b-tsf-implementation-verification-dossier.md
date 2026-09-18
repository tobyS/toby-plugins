# TP-0034b: tsf slice 2 — implementation, verification pipeline, and the dossier — Implementation Plan

## Overview

Make the factory produce code. On top of slice 1's dispatcher this adds
DESIGN.md §4 rows 5–11: implementation from the approved plan (with rework and
fix modes), the pull request, local and CI verification with bounded fixing, the
three context-starved gates, the dossier, and the reading of the human's review.
After this slice a ticket goes from an approved plan to a PR the human can
approve or send back; only the landing (TP-0034c) is missing.

The binding specification remains `plugins/tsf/DESIGN.md` v1.4. This plan bakes
in the six decisions taken with the user on 2026-09-18 (see "Implementation
Approach") and surfaces every deviation from DESIGN.md it needs, per the epic's
rule that deviations are surfaced, never silently made.

## Current State Analysis

Slice 1 (`0.1.0`, commits `bf58f3c`…`5fa4b8a`) shipped the dispatcher up to the
plan gate and left the seams for this slice deliberately visible:

- All fourteen `tsf:*` labels already exist — `/tsf:init` creates
  `tsf:verify`, `tsf:dossier`, `tsf:rework`, `tsf:landing` and
  `tsf:needs-review` although no slice-1 path sets them
  (`plugins/tsf/commands/init.md:279-292`).
- The dispatcher has a **re-pick** branch built for later-slice rows: it adds
  the ticket to the skipped list and returns to the pick, writing nothing
  (`plugins/tsf/commands/cycle.md:113-117`,
  `plugins/tsf/references/cycle-dispatch.md:69-70`).
- `gh-write.sh marker` already accepts `--pr P` and composes the PR link; the
  write phase simply never passes it (`plugins/tsf/scripts/gh-write.sh:178`
  versus `plugins/tsf/references/cycle-write-phase.md:43-44`).
- `scan.sh`'s `--poll` loop is the working precedent for per-ticket REST probes
  (`plugins/tsf/scripts/scan.sh:92-107`), and its record is produced by a single
  `jq` whose field list mirrors the documented header block (`:109-118`,
  `:22-29`).
- `config.md`'s `verify_fix_bound` and `gate_fix_bound` (both default 3) are
  referenced by no slice-1 code (`plugins/tsf/templates/tsf/config.md:71-74`).
- Only `prepare` of the five contract scripts is ever executed
  (`cycle.md:94,99`); `env_up`, `env_reset`, `env_check` and `verify` are
  validated by the preflight and never run (`preflight.sh:94-107`).

Four vocabularies are closed and must grow together: the result block's
allowed-outcomes table (`references/templates/result-block.md:49-59`), the
journal's `Next step` set (`references/templates/journal-entry.md:44-58`), the
dispatch rows (`references/cycle-dispatch.md:72-113`) and the report's skip
reasons (`references/cycle-report.md:38-41`).

### Platform and API facts the plan rests on (research §3–§5)

- **Actions results are check runs and never appear in
  `GET /commits/{ref}/status`.** CI state must come from
  `GET /repos/{o}/{r}/commits/{ref}/check-runs`.
- **Reviews return in chronological order with no `sort` parameter**; `state` has
  no documented enum; `PENDING` reviews carry no `submitted_at`; a dismissal
  mutates the existing review rather than adding one. "The reviewer's latest
  review" is derived by the caller.
- **A PR's conversation comments are issue comments** — the PR number *is* the
  issue number, so slice 1's `comment` helper already works against a PR.
- **The REST diff carries hard caps** (300 files, files only on page 1, 20,000
  lines / 1 MB, an undocumented `406` above them). A local
  `git diff <base>...HEAD` has none of them.
- **`POST /pulls` returns `422` when a PR already exists** for the head/base
  pair — the practical idempotency signal. `draft`'s default is undocumented, so
  it is passed explicitly.
- **Secondary limits**: 80 content-generating requests per minute, and the
  documented rule "wait at least one second between each request" for runs of
  writes.
- **The subagent concurrency cap is 20**, error string
  `Concurrent subagent limit reached`, with no queue. Three gates are safe.
- **Whether several `Agent` calls in one message run concurrently is
  undocumented** — "in parallel" is best-effort; only "all three complete before
  the write phase" is load-bearing.
- **A plugin cannot force foreground dispatch** (`background: true` exists,
  `background: false` does not); the consumer's
  `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, already required and checked by the
  preflight, is the only lever.
- **The subagent output scan inserts backslashes** into instruction-shaped text
  and prepends a `[harness: …]` marker line; it never removes or rewords.

## Desired End State

`/tsf:cycle` advances a ticket from `tsf:implement` to `tsf:needs-review` and
reads the human's verdict:

- implement → per-increment commits, push, a non-draft PR from the pr-body
  template, the PR number in the marker block, `tsf:verify`;
- verify → `env_up`, `env_reset` on ticket switch, `env_check`, the project's
  `verify` script, the attempted manual items; red → bounded verify-fix per
  episode; CI read at pickup on the PR head;
- gates → three read-only agents in one foreground cycle on the PR diff, three
  numbered reports naming the logic head, one PR comment each; any "not met" or
  blocking finding → implement in fix mode, bounded by `gate_fix_bound`;
- dossier → `reports/dossier.md` committed and posted to the PR,
  `tsf:needs-review`;
- review → an approving review at or after the logic head → `tsf:landing`
  (skipped in this slice as "landing not implemented in this slice"); a
  changes-requested review newer than the factory's last dossier comment →
  `tsf:rework`.

`claude plugin validate` passes for the marketplace and the plugin at `0.2.0`;
CLAUDE.md records the same-commit spans this slice creates.

### Key Discoveries:

- The `--poll` loop is the template for PR/CI/review probes
  (`scan.sh:92-107`), and failure propagation is already patterned (`:96-99`).
- The gates have `Read` but no `Bash`, so a diff **file path** reaches them
  without weakening starvation (research §5, DESIGN.md §11.2).
- `prepare` runs `git clean -fd` every cycle
  (`plugins/tsf/templates/tsf/scripts/prepare.sh:31`), so an untracked temp file
  in the clone is cleaned up exactly one cycle later, with no new grant and no
  path outside the sandbox's filesystem grant.
- The logic head is `git rev-list -1 HEAD -- . ':(exclude)thoughts/'`; approval
  validity is `git merge-base --is-ancestor`, the same reachability probe
  `plugins/tce/scripts/baseline.sh` uses.
- `plugins/tce/agents/plan-compliance-checker.md:14-99` is the gate skeleton:
  isolation clause, three-part envelope, closed verdict enum with an evidence
  obligation, "Emit only this" output, and a tie-break.
- tle's bounded escalation reads its counter **from disk, never from
  conversation** (`plugins/tle/commands/run.md:128-138`) — the pattern for
  episodes and rounds.

## What We're NOT Doing

- The landing loop, the integration gate, the merge, the root README catalog and
  the `tsf--v1.0.0` tag (TP-0034c). A `tsf:landing` ticket is reported as
  "landing not implemented in this slice" and never ends a cycle while other
  tickets are actionable.
- Anything DESIGN.md §14 lists as a v1 non-goal.
- Detecting "this repository has no CI at all" (user decision 3): a working
  factory presupposes PR CI, and zero check runs is treated as "not started
  yet". Recorded in a new `plugins/tsf/TODO.md` as an init-time precheck to add
  later.
- Editing DESIGN.md. The deviations below are recorded here and in file
  comments, not applied to the design document.
- Any change to tce, tmt or tle; any dependency between tsf and them.
- Dogfooding tsf in this repo.

## Implementation Approach

Bottom-up again, one validatable layer per phase: scripts first (testable
against a scratch repository and a fake `gh`), then the templates the agents and
the dispatcher read, then the agents, then the dispatcher rows that orchestrate
them, then docs and the version bump.

**Decisions taken with the user (2026-09-18), applied throughout:**

1. **The gates receive the diff as a file path.** A shipped `diff.sh` writes the
   three-dot diff to `.tsf-tmp/pr-diff.patch` **inside the clone** — within the
   sandbox's filesystem grant and the session's working directory, so the gates
   `Read` it with no extra permission — and `prepare`'s `git clean -fd` removes
   it on the next cycle. The dispatcher never holds diff content.
2. **Verification attempts the manual items.** After the project's `verify`
   script is green, a dedicated `tsf:manual-verify` agent attempts every plan
   item flagged `**Manual**` with whatever it takes (project commands, throwaway
   scripts, MCP servers) and returns per-item evidence. Only items that
   genuinely need a human (visual judgment, subjective acceptance, credentials
   the factory lacks) reach the dossier's open items.
3. **"No CI configured" is out of scope.** Zero check runs = `pending`.
4. **`env_reset` runs when the branch checked out before `prepare` differs from
   the ticket's branch** — the switch *is* the signal; no new state.
5. **A `tsf:verify` ticket's actionability is decided from scan data**: CI
   pending → not actionable, skipped, the pending head named in the report.
   `verify` runs only once the ticket is picked.
6. **The three gates share one episode and one round number** and are dispatched
   in one message, foreground; the cycle waits for all three before it writes.

**Deviations from DESIGN.md surfaced by this plan:**

- **The gates receive a diff file path, not the diff in the spawn prompt**
  (§11.2). Their inputs are unchanged in substance; only the transport differs.
- **Manual verification is attempted before it is escalated** (§7 collects
  "needs human verification" verdicts into the dossier). The dossier now carries
  evidence for attempted items and lists only what truly needs a person.
- **An implement-parked ticket resumes through `tsf:plan`, not through the
  parking step** (slice 1's rule is "the step that parked resumes"). This is what
  the ticket's own AC asks for: implement's questions are plan-gate questions,
  so `tsf:plan` folds the reply into `plan.md`, re-summarizes, and the ticket
  goes back through the plan gate.
- **The dispatcher computes the diff and the logic head with `git` in the
  clone**, not over REST (§3.5 does not say how they are computed).
- **`env_up` runs before `verify` in the same cycle**, and `env_check` only when
  registered — §8 states the cadence but not the order within a cycle.

**Precondition:** none beyond slice 1 being on `main` (it is, `a87deec`).

---

## Phase 1: PR, CI and review reads; PR creation

### Overview

Teach the script layer about pull requests. Everything a dispatcher needs about
a PR — that it exists, its head, its CI state, its reviews, the factory's last
comment on it — and the one new write, PR creation. All REST through `gh api`,
all following slice 1's trailer and classification contracts.

### Changes Required:

#### 1. `gh-read.sh` — four new subcommands

**File**: `plugins/tsf/scripts/gh-read.sh`
**Changes**: add to the usage block, the argument validation and the `case`.

```
pr       --branch B
  exists:    yes | no
  number:    <n> | -
  url:       <html_url> | -
  head:      <head sha> | -
  base:      <base branch> | -
  title:     <title, one line> | -
  <trailer>
  GET /repos/O/R/pulls?head=<owner>:<branch>&state=open  (owner = the repo's owner half).
  Empty array -> exists: no, result ok. More than one -> result mismatch with the
  numbers in detail: the design assumes one open PR per ticket branch.

checks   --ref SHA
  state:     success | failure | pending
  counts:    total=<n> success=<n> failure=<n> pending=<n>
  failed:    <check name, comma-separated> | -
  <trailer>
  GET /repos/O/R/commits/{SHA}/check-runs?filter=latest (paged).
  Mapping: any run whose status is not "completed" -> pending; else any conclusion
  in failure, timed_out, action_required, cancelled -> failure; success, neutral,
  skipped -> success. total_count 0 -> pending (a factory presupposes CI; see
  TODO.md). GitHub Actions results are check runs and never appear in the
  combined-status endpoint, which is why that endpoint is not used.

reviews  --pr N
  approval:        <commit_id> | none      (latest APPROVED among current reviews)
  changes:         <submitted_at> | none   (latest CHANGES_REQUESTED)
  reviewers:       <n>
  <trailer>
  then "detail-list:" and one verbatim line per reviewer's latest review:
  --- <login> <state> <commit_id> <submitted_at> ---
  GET /repos/O/R/pulls/N/reviews (chronological, paged to the end).
  Derivation: drop reviews without submitted_at (PENDING) and with a null user;
  per login keep the latest by submitted_at among APPROVED, CHANGES_REQUESTED and
  DISMISSED; COMMENTED is non-decisive and ignored for the two roll-ups.

pr-comments --pr N --factory-login L
  last-factory:    <created_at> | none
  id:              <comment id> | -
  <trailer>
  GET /repos/O/R/issues/N/comments (a PR's conversation comments are issue
  comments). Sorted client-side by created_at, then id: the endpoint documents no
  ordering.
```

#### 2. `gh-write.sh` — `pr-create`

**File**: `plugins/tsf/scripts/gh-write.sh`
**Changes**:

```
pr-create --branch B --base BASE --title T --body-file F
  number:    <n>
  url:       <html_url>
  head:      <head sha>
  result:    created | exists | rejected | denied | failed | no-credential
  POST /repos/O/R/pulls with {title, head: B, base: BASE, body, draft: false}
  (draft is passed explicitly: its default is undocumented).
  422 -> GET /repos/O/R/pulls?head=<owner>:B&state=open; a match -> result exists
  with that PR's fields (idempotent re-run), no match -> tsf_api_fail.
  Read-back: the 201 body carries number, html_url and head.sha.
```

#### 3. `scan.sh` — PR-side probes

**File**: `plugins/tsf/scripts/scan.sh`
**Changes**: a new flag group, a second per-ticket probe loop modeled on
`--poll` (`:92-107`), and five new record fields (default `skipped`).

```
Usage adds: [--pr-probe --branch-pattern P --factory-login L]

New record fields, after "reply:":
  pr:        <number> | none | skipped
  pr_head:   <sha> | -
  ci:        success | failure | pending | skipped
  review:    approved | changes-requested | none | skipped
  review_ref: <commit_id or submitted_at> | -
  factory_comment: <created_at> | none | skipped

Probed only for tickets whose state is one of tsf:verify, tsf:dossier,
tsf:needs-review, tsf:rework, tsf:landing. Branch name = the pattern with <n>
replaced (tsf_branch_for). Per probed ticket: pulls?head= -> checks on the head
-> reviews -> issue comments (the last two only for tsf:needs-review and
tsf:rework). A failed probe aborts the scan exactly as --poll does
(count: 0 then tsf_api_fail).
```

### Success Criteria:

#### Automated Verification:

- [x] `bash -n` passes for all changed scripts; `claude plugin validate ./plugins/tsf` passes
- [x] `grep -rnE 'gh (issue|pr|label|auth|run)\b' plugins/tsf/scripts/` still finds nothing
- [x] Each new subcommand run without its required flags prints `Error:` to stderr and exits 1
- [x] Against a fake `gh` on `PATH`: `checks` maps a not-completed run to `pending`, a `failure` conclusion to `failure`, `success`+`skipped` to `success`, and `total_count: 0` to `pending`
- [x] Against the fake: `reviews` returns the latest APPROVED per reviewer, ignores a later COMMENTED, drops a PENDING review with no `submitted_at`, and reports `changes` from the newest CHANGES_REQUESTED
- [x] Against the fake: `pr-create` reports `created` on 201 and `exists` (with the existing number) on a 422 followed by a successful lookup
- [x] Against the fake: `scan.sh --pr-probe` fills the five new fields for a `tsf:verify` ticket and leaves them `skipped` for a `tsf:queued` one

#### Manual Verification:

- [ ] Against the scratch GitHub repository: `pr` finds a real open PR by branch and reports its head; `checks` reports the real CI state for that head; `reviews` reflects a real approval and a real changes-requested review

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `f7547405d39a60611719e58e70eba357205a90eb`
- **Commit**: `<phase-1>` feat(TP-0034b): add the tsf pull-request, CI and review reads
- **Did**: `gh-read.sh` gained `pr`, `checks`, `reviews`, `pr-comments`;
  `gh-write.sh` gained `pr-create` (422 → `exists` via lookup, `draft:false`
  explicit); `scan.sh` gained `--pr-probe --branch-pattern --factory-login` and
  six new record fields.
- **Issues**: `tsf_api_list` merged pages with `+`, which fails on the
  check-runs endpoint because it wraps its array in an object — found by the
  fake-`gh` tests, fixed with an optional array-key argument (`check_runs`)
  rather than per-caller unwrapping. Two further failures were artefacts of the
  test fake's pagination stub, not of the scripts.
- **Verification**: ✅ 18 new fake-`gh` checks, ✅ slice-1 suites (30 + 12) still
  green, ✅ live read-only scan, ✅ validate

---

## Phase 2: The diff, the logic head and approval validity

### Overview

One new script for the three git facts §3.5 defines, so no command ever
composes a raw `git diff` and the dispatcher never holds diff content.

### Changes Required:

#### 1. `diff.sh`

**File**: `plugins/tsf/scripts/diff.sh` (new, executable)
**Changes**: three subcommands, the house `report()` contract, run in
`tsf_project_root`.

```
Usage: diff.sh pr-diff   --base BASE [--out FILE]
       diff.sh logic-head
       diff.sh ancestor  --commit A --of B
       diff.sh clean

pr-diff   git diff <base>...HEAD -- . ':(exclude)thoughts/' written to FILE
          (default .tsf-tmp/pr-diff.patch, relative to the project root; the
          directory is created). <base> is resolved as origin/<base> when that
          ref exists, else <base>. Also writes FILE.stat with --stat output.
            file:      <path relative to the project root>
            stat:      <path>
            files:     <n>
            lines:     <n>
            result:    ok | empty        (empty: the diff has no content)
          The file is untracked and lives exactly one cycle: prepare's
          `git clean -fd` removes it. It is never staged.

logic-head  git rev-list -1 HEAD -- . ':(exclude)thoughts/'
            logic_head: <sha> | -
            short:      <short sha> | -
            result:     ok | none
            (§3.5: the newest commit touching a path outside thoughts/. Before
            TP-0034c there are no mechanical sync merges to exclude.)

ancestor    git merge-base --is-ancestor A B
            result: yes | no | unknown   (unknown: either commit is missing)

clean       remove .tsf-tmp/ (for a cycle that wants to tidy up early)
```

### Success Criteria:

#### Automated Verification:

- [x] `bash -n` passes; the script is executable and carries the byte-identical lib bootstrap
- [x] Against a scratch git repository: `pr-diff` on a branch with one code commit and one `thoughts/` commit reports `files: 1` and the patch contains no `thoughts/` path
- [x] `pr-diff` writes to `.tsf-tmp/pr-diff.patch` by default, creates the directory, and a subsequent `git clean -fd` removes it
- [x] `logic-head` returns the code commit, not the later `thoughts/`-only commit
- [x] `ancestor` reports `yes` for an ancestor, `no` for a sibling, `unknown` for a missing sha
- [x] `pr-diff` on an unchanged branch reports `result: empty`

#### Manual Verification:

- [ ] None.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-2>` feat(TP-0034b): add the tsf diff and logic-head script
- **Did**: `plugins/tsf/scripts/diff.sh` with `pr-diff`, `logic-head`,
  `ancestor` and `clean`. The base resolves to `origin/<base>` when the
  remote-tracking ref exists, since a factory clone may never check the base
  branch out. Additions over the plan: `pr-diff` also reports `failed` for a
  missing base branch, and writes `<out>.stat` beside the patch.
- **Issues**: none.
- **Verification**: ✅ 14 checks against a scratch bare remote (exclusion of
  `thoughts/`, untracked + removed by `git clean -fd`, logic head skipping a
  journal commit, reachability in both directions, empty diff, missing base)

---

## Phase 3: Reference templates for reports, dossier and the PR body

### Overview

The document skeletons the gates, the dossier agent and the dispatcher read at
the point of use, plus the two slice-1 machine contracts that must grow.

### Changes Required:

#### 1. `references/templates/report.md` (new)

The gate report the dispatcher writes to
`thoughts/factory/GH-<n>/reports/<gate>-<episode>-<round>.md`. Two machine lines
first, then prose:

```markdown
head: <logic head sha>
verdict: pass | fail

## <Gate name> — GH-<n>

**Overall:** <one line>

| # | Criterion / Finding | Verdict | Evidence |
...
```

`verdict: fail` iff any criterion is "not met" or any finding is blocking.
Preamble states: the dispatcher writes this file (the gates have no `Write`);
a report naming another logic head is stale and counts as missing (§4 row 8);
the two machine lines are parsed, so they come first and are never reordered.

#### 2. `references/templates/dossier.md` (new)

`reports/dossier.md`, posted to the PR. The five §9.1 sections — condensed
narrative, where to look (permalinks with one sentence each on *why*), open
items (gate verdicts needing a human, advisory security findings, the plan's
deviation addenda, manual items that could not be attempted), overlap warning
(other open factory PRs touching the same files), closing line (approve or
request changes with a native review; anything else goes on the issue, because
the factory does not read free-text PR comments). Plus the **addendum** shape
for a later round, and the rule that attempted manual items appear with their
evidence rather than as a to-do list (decision 2).

#### 3. `references/templates/pr-body.md` (new)

Title `<type>(GH-<n>): <spec title>` in the project's commit convention — the
squash commit's subject — and a body with the closing keyword (`Closes #<n>`),
the spec link, the plan summary and the artifact links.

#### 4. `references/templates/result-block.md` (extend)

New steps and rows; the gates are explicitly **not** result-block producers.

| step | outcome | next-label | next-step |
|---|---|---|---|
| implement | continued | tsf:verify | verify |
| implement | parked | tsf:needs-answer | implement |
| verify-fix | continued | tsf:verify | verify |
| manual-verify | continued | tsf:verify | gates |
| dossier | continued | tsf:needs-review | review |
| (any) | blocked | tsf:needs-human | the step itself |

Plus a new optional `tsf-result` field `manual:` (`<k> attempted, <m> need a
human`) for `manual-verify`, and a note that `implement` in fix or rework mode
uses the same rows as normal mode.

#### 5. `references/templates/journal-entry.md` (extend)

- `Next step` vocabulary grows to `triage | research | plan | implement | verify
  | gates | dossier | review | landing`.
- A new line, **only** on entries that transition the ticket into `tsf:verify`:
  `- Episode: <n>` — the verification episode the transition opens (§6.7,
  §16.37). Filenames cannot distinguish episodes; this line can.
- Two new dispatcher-written entry shapes: the **gate cycle** (the gates return
  report content, not result blocks) and the **review read** (row 10, which
  dispatches no agent).

### Success Criteria:

#### Automated Verification:

- [x] Nine files under `plugins/tsf/references/templates/`; each starts with `<!--` and contains `Contents:`
- [x] `report.md`'s skeleton has `head:` on line 1 and `verdict:` on line 2 of the report body
- [x] `grep -c 'Episode' plugins/tsf/references/templates/journal-entry.md` ≥ 1
- [x] The allowed-outcomes table in `result-block.md` contains a row per new step (`grep` for `implement |`, `verify-fix |`, `manual-verify |`, `dossier |`)
- [x] No angle brackets inside the result block's three inner fences (the slice-1 check still passes)
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] Read the dossier template as the dossier agent would and confirm the five sections are unambiguous and nothing is project-specific

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-3>` feat(TP-0034b): add the tsf report, dossier and PR-body templates
- **Did**: `references/templates/{report,dossier,pr-body}.md`; `result-block.md`
  gained the four new steps, five rows and the optional `manual:` field;
  `journal-entry.md` gained the extended `Next step` vocabulary, the `Episode:`
  line and two dispatcher-written shapes (gate cycle, review read).
- **Issues**: none. The gates deliberately do **not** produce result blocks —
  the report's two machine lines are their contract instead, which the
  result-block template now states so the two cannot drift.
- **Verification**: ✅ nine templates with preambles, ✅ the machine lines,
  ✅ the new rows, ✅ no angle brackets in the result fences, ✅ validate

---

## Phase 4: Worker agents — implement, verify-fix, manual-verify, dossier

### Overview

Four read-write agents, each the system prompt of one step, all carrying the §6
common contract, the §11.1 tool set (no `gh`, never push, `Agent` omitted) and
the three-part envelope.

### Changes Required:

#### 1. `agents/implement.md` (new, `model: sonnet`)

Modes in the spawn payload: `mode: fresh | rework | fix`.

- **fresh** — re-read `spec.md` → `research.md` → `plan.md` from disk; work
  increment by increment; run each increment's own automated verification
  immediately after building it; one commit per increment in the project's
  convention with scope `GH-<n>`.
- **Deviations** from the plan that survive contact with reality are written
  into `plan.md` as a dated `## Addenda` entry that **restates the affected
  increment's verification criteria** — never journal-only, because the
  plan-compliance gate never sees the journal.
- **A mismatch too large for an addendum** → `outcome: parked`,
  `next-label: tsf:needs-answer`, a batched numbered question comment; the
  questions also go into `plan.md`'s `## Open questions`.
- **rework** — the review's comments arrive in the payload (`review-comments:`);
  record them as a plan addendum **before** implementing, then implement,
  commit, return `continued`.
- **fix** — the failing gate reports arrive in the payload (`reports:` as paths
  on the branch, which the agent reads); fix exactly what the reports evidence,
  nothing else; commit; return `continued`.
- Never pushes, never opens a PR, never comments — the dispatcher does all of
  that from the result block.

#### 2. `agents/verify-fix.md` (new, `model: sonnet`)

§6.7. Payload carries `failure: local | ci`, the verify output path (local) or
the failing check names (CI), and the attempt number. Diagnoses **by local
reproduction first** — CI logs only when reachable — fixes, commits, returns
`continued` to `tsf:verify`. CI-red-with-local-green is reported as an
environment difference rather than flailing: `outcome: blocked` with that
statement.

#### 3. `agents/manual-verify.md` (new, `model: sonnet`)

Decision 2. Payload: the plan path and the list of `**Manual**` items (verbatim,
numbered). For each item it **attempts** a real check — project commands,
throwaway scripts in `.tsf-tmp/`, an MCP server the project provides — and
returns one line per item: `attempted / passed`, `attempted / failed`, or
`needs a human` with the reason it cannot be automated (visual judgment,
subjective acceptance, credentials the factory lacks). Writes
`reports/manual-<episode>.md` content into its result block for the dispatcher
to write; commits nothing. A failed item routes exactly like a red verification.

#### 4. `agents/dossier.md` (new, `model: opus`)

§9.1. Deliberately **not** context-starved: it reads everything on the branch
(spec → research → plan → journal → reports). The dispatcher passes the PR diff
file path, the PR's current title and body, and the other open factory PRs with
their touched files (the agent has no `gh`). Returns the dossier content and a
verdict on whether the PR title/body match the template.

#### 5. Shared frontmatter

```yaml
tools: Read, Write, Edit, Grep, Glob, Bash
```

`Agent` omitted (workers stay inline, TP-0034a decision 3); descriptions begin
"Internal to `/tsf:cycle` — not for direct use".

### Success Criteria:

#### Automated Verification:

- [ ] Seven agent files in `plugins/tsf/agents/`; the four new ones have `tools: Read, Write, Edit, Grep, Glob, Bash` exactly and no `Agent` in `tools:`
- [ ] `model:` is `sonnet` for implement, verify-fix and manual-verify; `opus` for dossier
- [ ] Every description starts with `` Internal to `/tsf:cycle` — not for direct use ``
- [ ] Each file has the three envelope headings and reads `result-block.md` at the point of use
- [ ] `grep -n 'git push\|gh api' plugins/tsf/agents/*.md` shows only prohibitions, never instructions to run them
- [ ] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] In a scratch project, dispatch `tsf:implement` headless on a two-increment plan and confirm: one commit per increment, each increment's verification run, a valid result block, nothing pushed
- [ ] Dispatch `tsf:manual-verify` on a plan with one automatable manual item and one genuinely human one; confirm the first is attempted with evidence and the second is reported as needing a human

---

## Phase 5: The three gates

### Overview

Three mechanically read-only agents, context-starved by configuration and by
prompt, each receiving exactly its §11.2 inputs and returning report content.

### Changes Required:

#### 1. Shared shape

**Files**: `plugins/tsf/agents/{plan-compliance,spec-coverage,security}.md`
**Frontmatter**:

```yaml
tools: Read, Grep, Glob
model: sonnet          # security: opus
```

No `Bash`, no `Write` — the starvation contract is enforced by configuration,
and the dispatcher writes the report file. Body follows
`plugins/tce/agents/plan-compliance-checker.md`: role paragraph → "What you
receive" with the explicit *does not receive and must not seek out* list →
`## CRITICAL:` → verdict enum with evidence obligations and a tie-break →
process → "Emit only this" output block (the `report.md` skeleton) →
`## What NOT to Do` → `## REMEMBER: You are a X, not a Y`.

#### 2. Per-gate contracts

- **`tsf:plan-compliance`** — inputs: the plan's per-increment verification
  criteria (verbatim, numbered, **addenda included**) + the diff file path. One
  evidenced verdict per criterion: met / not met / cannot verify from diff /
  needs human verification. May read post-change source; may not read
  `thoughts/` documents.
- **`tsf:spec-coverage`** — inputs: `spec.md`'s content (passed verbatim) + the
  diff file path. Verdicts against the *spec's* requirements, independently of
  the plan — the spec-drift catcher. Never research, never plan.
- **`tsf:security`** — inputs: the diff file path only. May read the touched
  files and their surroundings. Each finding classified **blocking** (a
  concrete, evidenced defect) or **advisory** (a judgment call for the human).
  Never `thoughts/` documents. The gate classifies; it never fixes.

#### 3. Reading the diff

Each gate is told: "Read the diff file at the path you were given, in full,
before judging anything. It is the complete PR diff with `thoughts/` excluded;
nothing else about this change is available to you, by design."

### Success Criteria:

#### Automated Verification:

- [ ] Three files with `tools: Read, Grep, Glob` exactly — no `Bash`, no `Write`, no `Agent`
- [ ] `model:` is `sonnet` for plan-compliance and spec-coverage, `opus` for security
- [ ] Each has the three envelope headings and an "Emit only this" output section referencing `report.md`
- [ ] Each states what it must NOT receive or seek out (`grep -c 'must NOT seek out\|may NOT open'` ≥ 1 per file)
- [ ] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] Dispatch all three headless against a scratch diff file with a deliberate gap (one increment not implemented) and confirm: plan-compliance reports it "not met" with evidence, spec-coverage judges the spec independently, security classifies findings blocking/advisory, and none of them opens a `thoughts/` document (check the subagent transcripts' tool calls)

---

## Phase 6: `/tsf:cycle` rows 5–11

### Overview

Wire the new steps into the dispatcher without growing `cycle.md` past the
compaction budget: the body gains the new actionable/skip vocabulary and the
gate-cycle step; the rows, the write phase and the report shapes grow in the
references, which are read at the point of use.

### Changes Required:

#### 1. `commands/cycle.md`

- `allowed-tools` gains `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/diff.sh":*)` and
  `Bash(git rev-list:*)`, `Bash(git merge-base:*)` (only if the dispatcher calls
  them directly — with `diff.sh` it does not, so prefer granting only the
  script).
- **Step 2 Scan** passes `--pr-probe --branch-pattern <pattern> --factory-login
  <login>`.
- **Step 3 Pick**: actionable grows to `tsf:implement`, `tsf:verify` (unless
  `ci: pending`), `tsf:dossier`, `tsf:rework`, and `tsf:needs-review` **with** a
  review signal. Skip reasons grow: `ci pending on <sha>`, `waiting on review`,
  `landing not implemented in this slice`.
- **Step 4 Prepare** gains, in order: record the branch checked out **before**
  `prepare` (decision 4) → `prepare` → `env_up` → `env_reset` when the recorded
  branch differs from the ticket branch → `env_check` when registered. A
  non-zero exit from `env_up`/`env_reset`/`env_check` parks the ticket
  `tsf:needs-human` (§8).
- **Step 6 Dispatch** gains the **gate cycle**: all three gates dispatched in one
  message, foreground, waited for together; a MANDATORY OUTPUT check per gate
  (its returned report content is non-empty and starts with `head:`/`verdict:`).
- Invariant 3 gains one clause: the diff is passed **by path**; the dispatcher
  never reads it.

#### 2. `references/cycle-dispatch.md` — rows 5–11

```
Row 5  tsf:implement -> tsf:implement agent, mode: fresh.
Row 6  tsf:verify, local verification red -> tsf:verify-fix (attempt counter from
       reports/verify-fix-<episode>-*.md; episode from the journal's last
       transition into tsf:verify). Exhausted (verify_fix_bound) ->
       tsf:needs-human with a summary of what was tried.
Row 7  tsf:verify, local green (or mode ci), CI pending -> not actionable (the
       pick already skipped it). CI red -> tsf:verify-fix against CI.
Row 8  tsf:verify, local and CI green, gate reports missing or naming another
       logic head -> the three gates in one cycle. Any "not met" or blocking
       finding -> tsf:implement mode: fix (round = highest round in
       reports/<gate>-<episode>-*.md + 1; bounded by gate_fix_bound; the ticket
       stays tsf:verify). All green -> tsf:dossier.
Row 9  tsf:dossier -> tsf:dossier agent -> tsf:needs-review.
Row 10 tsf:needs-review, read from GitHub (scan fields review/review_ref/
       factory_comment): an APPROVED review whose commit_id is at or after the
       logic head (diff.sh ancestor) -> tsf:landing (then reported as "landing
       not implemented in this slice"). An approval behind the logic head is
       stale: the ticket stays parked. A CHANGES_REQUESTED review whose
       submitted_at is newer than the factory's last dossier/addendum comment ->
       tsf:rework; an older one is ignored.
Row 11 tsf:rework -> tsf:implement agent, mode: rework, with the review comments
       in the payload -> tsf:verify as a NEW episode.
```

Plus: the **manual-verify** step between a green `verify` and the gates; the
**distillation mapping** gains `implement -> plan.md`, resumed by **`tsf:plan`**
(the surfaced deviation); the spawn payload gains `diff:`, `reports:`,
`review-comments:`, `manual-items:`, `episode:`, `attempt:`/`round:` as each
step needs them.

#### 3. `references/cycle-write-phase.md`

- **PR creation** after a successful implement: `push.sh` → `gh-write.sh
  pr-create` → `marker … --pr <n>` → comment → label. The PR number reaches the
  journal in the **next** cycle's entry (§3.2, §16.41).
- **Gate cycle writes**: three report files committed together
  (`reports/<gate>-<episode>-<round>.md`), pushed, then **one one-line PR
  comment per gate** — with the documented one-second spacing between
  content-generating requests — then the label.
- **Dossier writes**: `reports/dossier.md` committed and pushed, then posted as
  a PR comment, then `tsf:needs-review`.
- Every new write keeps the read-back / retry-once / park rule.

#### 4. `references/cycle-report.md`

New skip reasons (`ci pending on <sha>`, `waiting on review`, `landing not
implemented in this slice`) and a **Gates** line for a gate cycle
(`plan-compliance pass · spec-coverage pass · security 1 blocking`). The
suggested-wait table gains: a ticket waiting on CI → 5 minutes.

### Success Criteria:

#### Automated Verification:

- [ ] `wc -c plugins/tsf/commands/cycle.md` ≤ 18000 and `wc -l` ≤ 230 (the compaction budget)
- [ ] `cycle.md` still has no `disable-model-invocation` and no `model:`; `## Invariants` still precedes `## Project context`
- [ ] `allowed-tools` grants `diff.sh` and still grants neither `git push` nor `gh`
- [ ] `grep -q 'landing not implemented in this slice'` in `cycle.md` and `cycle-report.md`
- [ ] Rows 5–11 appear in `cycle-dispatch.md` (`grep -c '^Row \|^\*\*Row '` ≥ 7)
- [ ] `grep -q 'env_reset' plugins/tsf/references/cycle-dispatch.md` or `cycle.md` and the branch-comparison rule is stated
- [ ] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] End-to-end on the scratch project: a ticket at `tsf:implement` reaches `tsf:verify` with a non-draft PR whose body matches the template and whose marker block carries the PR link
- [ ] With CI still running, the next cycle skips the ticket, names the pending head, and works another ticket
- [ ] With CI green, one cycle runs all three gates, writes three reports naming the logic head, posts three one-line comments, and moves the ticket to `tsf:dossier`
- [ ] A deliberate gap sends the ticket to fix mode and the gates re-run on the new logic head; `gate_fix_bound` exhaustion parks it `tsf:needs-human` with the reports linked
- [ ] The dossier appears on the PR with all five sections; the issue carries `tsf:needs-review`
- [ ] Requesting changes moves it to `tsf:rework`; the rework round returns it to `tsf:needs-review` with an addendum, and the following cycle does **not** send it back to rework
- [ ] Approving moves it to `tsf:landing`, and the next cycle reports it as "landing not implemented in this slice"

---

## Phase 7: Docs, governance and the 0.2.0 release

### Overview

Bring the consumer docs and the repo's rule sections up to slice 2, record the
deferred CI precheck, and bump the version.

### Changes Required:

#### 1. `plugins/tsf/TODO.md` (new)

Deferred items with their reasoning. First entry: **detecting "this repository
has no PR CI"** — zero check runs is currently read as "not started yet"; the
real fix is an init-time precheck that the repository runs CI on pull requests
(user decision, 2026-09-18).

#### 2. `plugins/tsf/README.md`

Slice 2 scope replaces slice 1's: what now works (implementation through
review), what is still missing (landing). New sections: the verification
pipeline (local verify → attempted manual items → CI → three gates), the
dossier and how to review it, the rework loop, and the two constants.

#### 3. `CLAUDE.md` — new rule sections

1. **tsf: the gate report is a machine contract** — `head:`/`verdict:` lines
   parsed by the dispatcher; the span is `report.md`, the three gate agents and
   `cycle-dispatch.md`.
2. **tsf: fix mode is entered from the reports, never from a label** — the
   ticket stays `tsf:verify`; the round counter is derived from report
   filenames, the episode from the journal.
3. **tsf: the environment contract's cadence** — `env_up` every
   implementation-flavored cycle, `env_reset` on ticket switch (the pre-`prepare`
   branch is the signal), `env_check` when registered.
4. **tsf: the logic head and the PR diff are computed by `diff.sh`** — never by
   a raw `git diff` in prose, never over REST; no base commit is recorded
   anywhere.
5. **tsf: the gates are read-only by configuration** — `tools: Read, Grep, Glob`
   and the diff by path; never add `Bash` or `Write` to a gate.

#### 4. Version bump

`plugins/tsf/.claude-plugin/plugin.json` and the marketplace entry → `0.2.0`;
the manifest description's slice sentence updated.

### Success Criteria:

#### Automated Verification:

- [ ] `jq -r '.plugins[] | select(.name=="tsf") | .version' .claude-plugin/marketplace.json` prints `0.2.0` and equals the manifest's `version`
- [ ] `plugins/tsf/TODO.md` exists and mentions the CI precheck
- [ ] `grep -c 'tsf:' CLAUDE.md` grows by the five new rule sections (`grep -c '^## tsf:'` ≥ 12)
- [ ] `claude plugin validate .` and all four plugin validations pass
- [ ] `grep -rn 'chat-sustainability\|nono' plugins/tsf/ --include='*.md' --include='*.sh'` finds nothing outside `DESIGN.md`

#### Manual Verification:

- [ ] Read the README as a consumer who has slice 1 running and confirm the new pipeline is followable without DESIGN.md

---

## Testing Strategy

### Unit Tests:

- Script checks in a scratch directory and against a fake `gh` on `PATH`: the
  check-run state mapping (including `total_count: 0` → pending), the review
  derivation (latest per reviewer, COMMENTED ignored, PENDING dropped),
  `pr-create`'s 422 → `exists` path, the scan's new fields, and `diff.sh`'s three
  subcommands against a real scratch git repository.
- Markdown-contract checks: frontmatter greps for the seven agents, the
  allowed-outcomes table rows, the `head:`/`verdict:` lines, `cycle.md`'s size.

### Integration Tests:

- The scratch GitHub repository and the second GitHub account from TP-0034a's
  smoke test, now driven from `tsf:implement` through `tsf:needs-review`.

### Manual Testing Steps:

1. Take a ticket the factory has planned and approved to `tsf:implement`.
2. `/loop /tsf:cycle` in the factory clone until the PR exists and CI runs.
3. Watch one cycle skip the ticket while CI is pending, and another advance it.
4. Confirm the gate cycle writes three reports and posts three comments.
5. Introduce a deliberate gap and watch fix mode, the re-run gates and the bound.
6. Read the dossier; request changes; watch the rework round and the addendum.
7. Approve; confirm `tsf:landing` and the "not implemented in this slice" report.

## Performance Considerations

- REST per cycle grows by the PR probes: one `pulls` lookup, one `check-runs`
  read, and for review-state tickets one `reviews` and one comments read — per
  *in-flight* ticket, not per ticket. Writes per gate cycle: three comments plus
  the label, spaced one second apart per GitHub's documented rule.
- The diff never enters the dispatcher's context; the gates read it from disk.
- `cycle.md` must stay under the 5,000-token re-attachment budget, which is why
  rows 5–11 live in the references.

## Migration Notes

- `0.1.0` consumers upgrade by `/plugin marketplace update toby-plugins`. The
  config file gains nothing, so `/tsf:init`'s upgrade list stays "nothing to
  migrate" — but the two constants become live, so a project that edited them
  now sees them take effect.
- Tickets parked mid-slice-1 are unaffected: the new rows only fire on labels
  slice 1 never set.

## References

- Original ticket: `thoughts/shared/tickets/TP-0034b-tsf-implementation-verification-dossier.md`
- Epic: `thoughts/shared/tickets/TP-0034-implement-tsf-plugin-v1.md`
- Research: `thoughts/shared/research/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`
- Slice 1: `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md`
- Binding design: `plugins/tsf/DESIGN.md` v1.4 — §3.5, §4 rows 5–11, §5.2, §6.6,
  §6.7, §7, §8, §9.1, §9.2, §11.1–11.4, §16.41, §16.43–16.45
- Precedents: `plugins/tce/agents/plan-compliance-checker.md:14-99` (gate shape),
  `plugins/tce/commands/implement.md:262-328` (running a gate),
  `plugins/tle/commands/run.md:128-138` (bounded escalation from disk),
  `plugins/tsf/scripts/scan.sh:92-107` (per-ticket probe loop)
