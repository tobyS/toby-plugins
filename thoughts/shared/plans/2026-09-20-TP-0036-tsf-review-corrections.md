# tsf post-1.0.0 review corrections (TP-0036) Implementation Plan

## Overview

Twelve corrections (C1–C12) from the post-1.0.0 review of tsf, landing under one
ticket as a sequence of commits grouped by their same-commit spans, with a
single version bump and tag at the end. They fix defects that stop or loop the
factory on normal paths: a resume that only works before implementation, a
re-pick livelock after every rework, a rework step that never receives the
review, a landing that cannot decide, unbounded CI waiting on conflicted pull
requests, contract scripts cut short by the Bash timeout, and a dispatcher that
is told both to avoid artifact bodies and to extract criteria from them.

## Current State Analysis

tsf 1.0.0 is internally coherent within each slice and breaks at the seams
between them. Slice 1's resume and validation logic maps four of the nine
`Next step` values; the scan record grew pull-request fields across slices 2
and 3 without becoming a declared machine contract; and two read/write paths
the state machine names were never implemented.

Key constraints established by research (`thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md`):

- **Step 3 decides actionability from the scan alone, before any branch is
  checked out** (`cycle.md:76`, `:98-101`). A `tsf:verify` ticket with
  `ci: pending` is skipped there and never reaches a dispatch row
  (`cycle.md:80-81`, `cycle-dispatch.md:142`), so a conflict probe cannot live
  in a row as written.
- **`/tsf:cycle`'s `allowed-tools` grants each script by exact prefix**
  (`cycle.md:4`). A shell redirect changes the command string and would not
  match, so any script output the dispatcher must not read has to be written by
  the script through its own `--out` flag.
- **`review_ref:` is one field with two types** — a commit sha for an approval,
  a timestamp for a changes-requested review (`scan.sh:42`, `:178-186`) — and is
  consumed as a sha at `cycle-dispatch.md:182`, `:222-224`, `:235`, as a
  timestamp at `:187-189`, and as a sort key at `cycle.md:103`.
- **`scan.sh:197`** blanks review data for every state but `tsf:needs-review`
  and `tsf:rework`, so a landing record carries `review: skipped` /
  `review_ref: -`.
- **Counters are read from disk, never from conversation**
  (`cycle-dispatch.md:298-318`).
- **Every reported outcome exits 0; only usage errors exit 1** — the shared
  script contract (`lib.sh`, all six scripts).

### Key Discoveries:

- A timed-out Bash command is documented as **moved to the background, not
  killed**; what `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` does to one is **not
  documented**. Either way the cycle breaks. `BASH_MAX_TIMEOUT_MS` has **no
  documented ceiling**, and the effective ceiling is
  `max(BASH_MAX_TIMEOUT_MS, BASH_DEFAULT_TIMEOUT_MS)` — so raising
  `BASH_DEFAULT_TIMEOUT_MS` to 600000 buys a ten-minute default *and* a
  ten-minute ceiling entirely inside documented behaviour.
- A **failing** Bash command returns only ~10,000 characters head-and-tail
  **with no file path**. The dispatcher already redirects `verify` output to a
  file (`cycle-dispatch.md:126-128`); the agents that run `verify` themselves do
  not.
- **C3 and C5 collide**: the landing decision cycle posts a gate one-liner on
  the pull request (`cycle-write-phase.md:152-153`), so a timestamp-based
  staleness rule applied to approvals would stale a landing's own approval.
  Resolved by decision: the recency test applies to **CHANGES_REQUESTED only**;
  approvals keep `diff.sh ancestor` as their guard, which is what
  `cycle-dispatch.md:181-186` and DESIGN.md §4 row 10 already specify.
- **`result-block.md:83-84` has no row** for a batched implement return
  (`implement | continued | tsf:implement | implement`), so C10 is a
  machine-contract change.
- **The dispatcher contradicts invariant 3 in five places**, not two:
  `cycle-dispatch.md:134-136`, `:152-156`, `:226-227`, `:354-355`, `:360-366`.
- **`GET /pulls/{n}/reviews/{id}/comments` returns the "Legacy Review Comment"
  schema** without `line`/`side`/`start_line`; `GET /pulls/{n}/comments`
  carries them plus `pull_request_review_id`, so the filter is client-side.
- **`before`/`after` on `synchronize` are undocumented** by GitHub (present as
  required properties in octokit's generated schema) and **absent on `opened`**;
  `paths`/`paths-ignore` on `pull_request` evaluate the **three-dot** diff, so a
  path filter cannot express "this push touched only `thoughts/`".
- **`plugins/tce/scripts/stage.sh`'s TP-0033 lesson applies to any plan parser**:
  fenced code blocks must be stripped before headings are matched.
- `plugins/tsf/TODO.md:80-110` and `:112-132` (the two deferred review items)
  are **already committed** in `100a2f6`; the ticket's "commit them with this
  ticket" is done.

## Desired End State

A factory that survives its first real tickets unattended. Verifiable by:

- `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass.
- Each new or changed script behaves as specified against a fake `gh` on `PATH`
  and a throwaway project directory (per CLAUDE.md "Testing changes").
- Every same-commit span named in the repository `CLAUDE.md` that a correction
  touches is honoured, and the three new spans this ticket creates have rule
  text of their own.
- `plugins/tsf/.claude-plugin/plugin.json` and the marketplace entry read
  `1.1.0`, and `tsf--v1.1.0` exists as a git tag.

## What We're NOT Doing

- The end-to-end smoke test against a real GitHub repository — still deferred by
  earlier decision, and strongly recommended directly after this ticket.
- The two deferred review items (the factory session's permission mode;
  counting only responders' reviews) — they stay in `plugins/tsf/TODO.md`.
- Anything already recorded in DESIGN.md §14/§15.
- The redesigns rejected in the review discussion: moving the journal off the
  branch, an extraction agent instead of the plan-check script, a
  batch-size-1-only implementation loop.
- Revising DESIGN.md's own §-numbered design text beyond what a correction makes
  factually wrong. Where a correction changes a documented mechanism, the design
  document gets a revision-log entry rather than a rewrite.

## Implementation Approach

Eleven phases, ordered so that each one leaves the plugin self-consistent:

1. **C1** first — cheapest, self-contained, and the factory cannot run a real
   suite without it.
2. **C7 → C3+C5 → C6** next, in that order. All three change the scan record;
   required-check names make "zero check runs" meaningful, and the landing must
   be able to decide before CI waiting is bounded.
3. **C4, then C12+C8** — the missing GitHub read and the two write-path fixes.
4. **C2** — resume, which depends on nothing above.
5. **C11 before C10** — the plan check defines the addendum shape that batched
   implementation writes.
6. **C9** last of the corrections — a project-side artifact with no runtime
   dependency.
7. **Governance, docs and release** as the closing phase.

Two structural moves keep the dispatcher from growing twice: the sync sequence
(server-side update-branch, then `tsf:merge-resolver` on conflict) becomes a
named sub-section of `cycle-dispatch.md` that both the new conflict path and
row 12 step 1 reference; and the `Next step` → label map becomes one table that
both the Validation section and row 3 read.

---

## Phase 1: Raise and enforce the Bash timeout (C1)

### Overview

The factory session runs with a raised Bash timeout; `preflight.sh` reports it
and refuses the cycle without it; the dispatcher and the worker agents ask for
the maximum timeout when they run a contract script or the project's
verification.

### Changes Required:

#### 1. The preflight check

**File**: `plugins/tsf/scripts/preflight.sh`
**Changes**: A new `--bash-timeout` flag beside `--foreground`, and one new
output line in the fixed-length contract, placed after `foreground:`:

```
bash_timeout: ok | too-low | missing | skipped
```

`ok` when `BASH_DEFAULT_TIMEOUT_MS` is set and numerically ≥ `600000`;
`too-low` when set and below it; `missing` when unset or non-numeric;
`skipped` without the flag. A non-`ok` result appends to `FAILURES` exactly as
the foreground check does (`preflight.sh:109-117` is the pattern), so
`result: incomplete` follows from the existing `:157-163` logic. Update the
header contract block at `:27-39`.

Only `BASH_DEFAULT_TIMEOUT_MS` is checked: the effective ceiling is
`max(BASH_MAX_TIMEOUT_MS, BASH_DEFAULT_TIMEOUT_MS)`, so 600000 on the default
raises both without relying on the undocumented behaviour of
`BASH_MAX_TIMEOUT_MS` above its own default.

#### 2. The dispatcher

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: add `--bash-timeout` to the Step 1 invocation (`:54-56`). In Step 4
(`:120-136`) and in the `verify` run named by `cycle-dispatch.md:126-128`, state
that a contract script and the project's verification are run with the Bash
tool's **maximum** timeout, and that `verify`'s output goes to a file under
`.tsf-tmp/` (already true for the dispatcher — keep it explicit).

#### 3. The worker agents

**Files**: `plugins/tsf/agents/implement.md`, `verify-fix.md`,
`manual-verify.md`, `merge-resolver.md`
**Changes**: where each runs the project's verification or an increment's own
command (`implement.md:64-67`, `verify-fix.md:51-54` and `:58`,
`manual-verify.md:51-57`, `merge-resolver.md:68-71`), add one clause: run it
with the Bash tool's maximum timeout, and redirect its output to a file under
`.tsf-tmp/` before reading it — a failing command returns only a truncated
excerpt with no file path.

#### 4. The human-facing setup

**Files**: `plugins/tsf/commands/init.md`, `plugins/tsf/README.md`
**Changes**: the clone checklist (`init.md:393-396`) and the README's session
block (`README.md:86-90`) gain
`export BASH_DEFAULT_TIMEOUT_MS=600000` beside the two existing exports. The
Phase 2 proposal block (`init.md:135-137`) names it with the same one-sentence
reason. The README explains that a suite longer than ten minutes needs
`BASH_MAX_TIMEOUT_MS` raised too, and that values above its 600000 default are
not documented as supported.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` passes
- [ ] `claude plugin validate ./plugins/tsf` passes
- [x] `BASH_DEFAULT_TIMEOUT_MS=600000 CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 CLAUDE_PROJECT_DIR=<tmp> plugins/tsf/scripts/preflight.sh --prepare <p> --env-up <p> --env-reset <p> --verify <p> --foreground --bash-timeout` prints `bash_timeout: ok` and `result: ok`
- [x] The same call with `BASH_DEFAULT_TIMEOUT_MS=120000` prints `bash_timeout: too-low` and `result: incomplete`, naming the variable in `detail:`
- [x] The same call with the variable unset prints `bash_timeout: missing` and `result: incomplete`
- [x] Without `--bash-timeout` the line reads `skipped` and does not affect `result:`
- [x] The preflight still prints exactly its documented lines, in order, in every case

#### Manual Verification:

- [ ] A factory session started with the three exports runs `/tsf:cycle` past the preflight

### Implementation log

**Status**: ✅ Complete
**Base commit**: `de99b93`
**Commit**: `421a13d`
**Did**: `preflight.sh` gained `--bash-timeout` and a `bash_timeout:` line in the
fixed-length contract, checking `BASH_DEFAULT_TIMEOUT_MS >= 600000`. `cycle.md`
passes the flag and tells Step 4 and row 6 to run contract scripts and `verify`
with the tool's maximum timeout; `cycle-dispatch.md` row 6 says the same and now
states *why* the `.tsf-tmp/` redirect matters. The four agents that run project
commands (`implement`, `verify-fix`, `manual-verify`, `merge-resolver`) got the
same two clauses. `init.md`'s proposal block and clone checklist and the README's
session block gained the export.
**Issues**: two findings worth recording. (1) Only `BASH_DEFAULT_TIMEOUT_MS` is
checked, not `BASH_MAX_TIMEOUT_MS`: the effective ceiling is the larger of the
two, so raising the default to 600000 raises both and keeps the factory inside
documented behaviour — `BASH_MAX_TIMEOUT_MS` above its own default is
undocumented. (2) The research finding that a **failing** command returns only
~10,000 characters with no file path made the `.tsf-tmp/` redirect a correctness
requirement for the agents, not just tidiness; the dispatcher already did it, the
agents did not. The `bash_timeout:` key is wider than the block's 12-column pad,
so it takes a single space after the colon — `scan.sh`'s existing convention for
`review_ref:` and `factory_comment:`.
**Verified**: all five automated criteria run against a throwaway project under
the scratchpad; `claude plugin validate .` and `./plugins/tsf` pass.

---

## Phase 2: Required check names (C7)

### Overview

The project declares which checks are required; the scan and `gh-read.sh checks`
evaluate only those. `none` means the project has no pull-request CI, which
settles the first `TODO.md` item.

### Changes Required:

#### 1. Configuration

**File**: `plugins/tsf/templates/tsf/config.md`
**Changes**: a new entry under `## GitHub`, after `Base branch`:

```
- **Required checks:** `<check display name>`, …   [the display names of the
  checks the base branch's ruleset requires — the check run's name, not the job
  id and not the workflow name. `none` means this project runs no CI on pull
  requests; the factory then never waits for a check and the gates run on local
  evidence alone]
```

#### 2. The scan

**File**: `plugins/tsf/scripts/scan.sh`
**Changes**: a **repeatable `--required-check NAME`** flag plus a `--no-ci`
boolean, exactly one of which is required whenever `--pr-probe` is given. The
check-runs reduction (`:155-160`) first filters `check_runs` to entries whose
`.name` is in the list (case-sensitive — GitHub display names are), then applies
today's precedence unchanged. With `--no-ci`, the endpoint is not called at all
and `ci:` is the new value `no-ci`. Update the record header (`:31-52`) for the
new `ci:` value.

> **Addendum (2026-09-20, during implementation).** This was planned as one
> `--required-checks "a,b"` flag with the literal value `none`. That cannot
> work: a check run's display name routinely contains commas — the first
> consumer's is `verify (lint, depcruise, typecheck, test)` — so a
> comma-separated list cannot carry the very names it exists to carry, and a
> project could in principle have a check named `none`. The repeatable flag has
> no delimiter and no reserved value. `gh-read.sh checks` takes the same pair.

#### 3. The checks reader

**File**: `plugins/tsf/scripts/gh-read.sh`
**Changes**: `checks` gains the same `--required-check` / `--no-ci` pair,
applying the filter before its reduction (`:303-320`); `--no-ci` yields
`state: no-ci` with zero counts and makes no call. The `failed:` line continues
to name run names, now only required ones. Update the header's `checks`
documentation.

#### 4. The consumers

**Files**: `plugins/tsf/commands/cycle.md`, `plugins/tsf/references/cycle-dispatch.md`
**Changes**: Step 2 passes `--required-checks` (`cycle.md:64-69`). Step 3's
actionability (`:78-96`) treats `ci: no-ci` as not-waiting. Row 7
(`cycle-dispatch.md:140-146`) gains a `no-ci` branch: CI is not a precondition
for this project, so local green proceeds to row 8; row 12's merge cycle step 2
(`:256-260`) likewise treats `no-ci` as "nothing to wait for".

#### 5. Setup and docs

**Files**: `plugins/tsf/commands/init.md`, `plugins/tsf/README.md`,
`plugins/tsf/TODO.md`
**Changes**: `init.md` Phase 1 detects candidate names from
`.github/workflows/` (the job's `name:` where present, else the job id) and
Phase 2 asks for them with those as the recommended answer; Phase 4 step 1
writes them; the Idempotency upgrade list gains a `1.1.0` bullet. `README.md`
documents the field and the `none` case, and the troubleshooting entry at
`:297-300` is rewritten. `TODO.md`'s first item ("Detect that a repository has
no pull-request CI", `:8-33`) is **removed** — it is closed by this phase.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [x] Against a fake `gh` returning two check runs — one required and successful, one optional and failed — `scan.sh … --required-check "<required name>"` emits `ci: success`
- [x] The same fixture with neither `--required-check` nor `--no-ci` is rejected as a usage error (exit 1) when `--pr-probe` is given, and so is passing both
- [x] `--no-ci` emits `ci: no-ci` and makes no check-runs call (the fake `gh` records no such invocation)
- [x] A fixture whose required check is `in_progress` emits `ci: pending`
- [x] A fixture with no run matching the required name emits `ci: pending`
- [x] A required check whose display name contains a comma is matched (the first consumer's real case)
- [x] `gh-read.sh checks --ref <sha> --required-check "<name>"` reports `state:` and `failed:` over the required check only, and `--no-ci` reports `state: no-ci` without calling
- [x] `TODO.md` no longer contains the "no pull-request CI" item

#### Manual Verification:

- [ ] `/tsf:init` on a project with a named required check proposes that exact display name

### Implementation log

**Status**: ✅ Complete
**Commit**: `906c6cb`
**Did**: `scan.sh` and `gh-read.sh checks` gained `--required-check` (repeatable)
and `--no-ci`, exactly one of which is mandatory; both filter check runs to the
required names before reducing, and `--no-ci` short-circuits to the new `no-ci`
state without calling GitHub. `cycle.md` passes the flags from the config and
treats `ci: no-ci` as not-waiting; `cycle-dispatch.md` row 7 gains a `no-ci`
branch (with the mode-`ci`-plus-no-CI contradiction parked rather than guessed)
and the landing's merge cycle likewise. `config.md` gained `Required checks`,
`init.md` a detection step (1.5b), a confirmation ask against the ruleset and a
`1.1.0` upgrade bullet. The README's "ci pending forever" entry was rewritten
from "GitHub cannot tell us" to the four things that actually cause it, and
`TODO.md`'s first item was removed as closed.
**Issues**: **one real design fault, caught by the first test run.** The plan
specified a comma-separated `--required-checks`. The very first fixture used the
first consumer's real check name — `verify (lint, depcruise, typecheck, test)` —
which contains three commas, so the filter matched nothing and a green build
read as `pending`. A delimited list cannot carry GitHub display names. Replaced
with a repeatable flag and a separate `--no-ci` boolean, which also removes the
reserved-value problem (`none` as a literal check name). Recorded as an addendum
above. Second finding: converting the check-runs block to `if/elif` on
`PR_NUMBER` initially skipped the review probe for `--no-ci` projects; the fix
is a nested `if` inside the existing `PR_NUMBER != none` branch, so review data
is unaffected by the CI decision.
**Verified**: eight scan cases and three `gh-read.sh checks` cases against a
fake `gh` (fixtures in the session scratchpad); both validates pass.

---

## Phase 3: The scan's review fields and changes-requested staleness (C3, C5)

### Overview

The scan emits the approval's commit id and the decisive review's timestamp as
separate fields, probes reviews for `tsf:landing` too, and reports no review
when a CHANGES_REQUESTED review is not newer than the factory's last
pull-request comment. Row 10's stale outcomes stop writing.

### Changes Required:

#### 1. The record

**File**: `plugins/tsf/scripts/scan.sh`
**Changes**:

- `tsf:landing` joins `tsf:needs-review|tsf:rework` in the `case "$STATE"`
  (`:161-198`), so it gets review and `factory_comment:` data.
- `review_ref:` is replaced by two fields, keeping the record's field order
  otherwise intact:

```
  review_commit: <commit_id of the approving review> | -
  review_at:     <submitted_at of the decisive review> | -
```

- Staleness, applied to **CHANGES_REQUESTED only**: when the winning review's
  state is `CHANGES_REQUESTED` and its `submitted_at` is not newer than
  `factory_comment:`, emit `review: none` with both new fields `-`. An approval
  is never staled here — `diff.sh ancestor` remains its guard (DESIGN.md §4
  row 10).
- Update the header block (`:31-52`) accordingly; it is the record's
  documentation.

#### 2. The consumers

**Files**: `plugins/tsf/commands/cycle.md`, `plugins/tsf/references/cycle-dispatch.md`
**Changes**:

- `cycle.md:103-105` orders landings by **`review_at:`**, oldest approval first.
- `cycle-dispatch.md:181-186` (row 10, approval) uses `review_commit:`; its
  `no` branch becomes a **re-pick** — "add the ticket to the skipped list as
  `approval behind the logic head` and return to Step 3" — replacing "journal
  the stale approval".
- `cycle-dispatch.md:187-191` (row 10, changes-requested) drops the timestamp
  comparison entirely: the scan has already decided it. A
  `review: changes-requested` record is by construction current, so the branch
  is simply `→ tsf:rework`.
- `cycle-dispatch.md:222-224` and `:235` (row 12) use `review_commit:`.
- `cycle.md:82` is unchanged in wording but now rests on a scan that never
  reports a superseded changes-requested review.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [x] Against a fake `gh`: a CHANGES_REQUESTED review **older** than the factory's last pull-request comment scans as `review: none`, `review_commit: -`, `review_at: -`
- [x] The same review **newer** than that comment scans as `review: changes-requested` with `review_at:` set
- [x] An APPROVED review older than the factory's last comment still scans as `review: approved` with `review_commit:` set (the collision case)
- [x] A `tsf:landing` ticket's record carries `review: approved`, a 40-character `review_commit:` and an ISO `review_at:`
- [x] No record anywhere still carries a `review_ref:` line
- [x] `grep -rn 'review_ref' plugins/tsf/` returns nothing

#### Manual Verification:

- [ ] On a real pull request, a rework round no longer produces a journal commit per cycle

### Implementation log

**Status**: ✅ Complete
**Commit**: `<this phase's commit>`
**Did**: `scan.sh` now probes reviews for `tsf:landing` as well, emits
`review_commit:` and `review_at:` in place of the overloaded `review_ref:`, and
reports a CHANGES_REQUESTED review that is not newer than the factory's last
pull-request comment as `review: none`. Approvals are deliberately never staled
by age. `cycle.md` orders landings by `review_at:`; row 10's approval branch
uses `review_commit:` and became a **re-pick that writes nothing**, and its
changes-requested branch lost its timestamp comparison because the scan has
already made it. Row 12's two `diff.sh` calls take `review_commit:`.
**Issues**: none. Two implementation notes. (1) The factory-comment read now
happens **before** the review read, because the staleness test needs it — the
two calls were independent before. (2) The two duplicated jq reductions became
one that emits three lines, read with a heredoc; keeping them separate would
have meant a third copy of the same nine-line reduction, and they must agree on
which review wins by construction, not by review.
**Verified**: five scan cases against a fake `gh` — the two changes-requested
recency cases, the approval-collision case, a landing record, and a
repository-wide grep for `review_ref`; both validates pass.

---

## Phase 4: Conflict detection and the CI-pending bound (C6)

### Overview

A `tsf:verify` ticket whose required checks have not started is examined once:
a conflicted pull request is synced the way a landing is, and a head that has
been pending beyond `ci_pending_bound` parks for a human.

### Changes Required:

#### 1. The scan's signal

**File**: `plugins/tsf/scripts/scan.sh`
**Changes**: a new field after `ci:`, so the pick can tell "no run has started"
from "a run is in flight":

```
  checks:    <number of required check runs on the head> | -
```

`-` when CI was not probed or `ci:` is `no-ci`. Header block updated.

#### 2. The pull-request probe

**File**: `plugins/tsf/scripts/gh-read.sh`
**Changes**: `pr-state` gains one line, `head_at:`, the head commit's committer
date, from a second call to `GET repos/O/R/commits/<head sha>`
(`.commit.committer.date`), or `-` when that call is not `ok`. `mergeable:` and
its existing 3×2s null-poll (`:282-291`) are unchanged.

#### 3. The pick

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: Step 3's `tsf:verify` rule (`:80-81`, `:92`) becomes: a
`tsf:verify` ticket with `ci: pending` is skipped **unless** `checks: 0`, in
which case run `gh-read.sh pr-state` once and keep its `mergeable:` and
`head_at:` values:

- `mergeable: false` → **actionable**, reason `conflicted`;
- otherwise, when `head_at:` is older than `ci_pending_bound` before the
  preflight's `now:` → **actionable**, reason `ci pending too long`;
- otherwise skip as today.

This is the one REST read Step 3 performs; it needs no branch, so the
"decided from the scan alone" constraint on the landing rule is untouched
(state that explicitly).

#### 4. The dispatch row

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: row 7's `pending` branch (`:142`) is rewritten from "not
actionable" to the two cases Step 3 now lets through:

- **conflicted** → run **the sync sequence** (new shared sub-section, below).
  A clean or resolved sync pushes and restarts CI; the ticket stays
  `tsf:verify`. The resolution's mechanical/logic classification works exactly
  as at landing — a logic resolution advances the logic head, so the gates
  re-run through row 8.
- **pending too long** → park `tsf:needs-human`, journal naming the head, the
  elapsed time and the bound.

**The sync sequence** is factored out of row 12 step 1 (`:207-219`) into its own
named sub-section and referenced from both places. It is unchanged in substance:
`gh-write.sh update-branch`, then `synced` → re-run `prepare`; `up-to-date` →
continue; `head-moved` → end with no write; `conflict` → `tsf:merge-resolver`,
with "do not run `prepare` after the resolver".

#### 5. The constant and its docs

**Files**: `plugins/tsf/templates/tsf/config.md`, `plugins/tsf/commands/init.md`,
`plugins/tsf/README.md`
**Changes**: `## Constants` gains

```
- **ci_pending_bound:** 120   [minutes a required check may stay unstarted on a
  head before the ticket parks for a human. The net under a missing workflow, a
  path filter, a stuck runner and anything else undocumented]
```

`init.md`'s Idempotency list gains it in the same `1.1.0` bullet as the required
checks; a config without the line falls back to 120. The README documents it
with the other bounds and notes the clock caveat: the comparison is the head
commit's committer date against the runner's own clock, at minute resolution.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] Against a fake `gh` with zero required check runs, the scan emits `ci: pending` and `checks: 0`
- [ ] With one required run in flight it emits `ci: pending` and `checks: 1`
- [ ] With `ci: no-ci`, `checks:` is `-`
- [ ] `gh-read.sh pr-state --pr <n>` prints `head_at:` with the committer date from the fake `gh`, and `-` when the commit call is refused
- [ ] `pr-state`'s output lines are otherwise unchanged in name and order
- [ ] The sync sequence appears once in `cycle-dispatch.md` and is referenced from both row 7 and row 12 (`grep -c 'update-branch' plugins/tsf/references/cycle-dispatch.md` shows the single invocation)

#### Manual Verification:

- [ ] A pull request made to conflict with its base branch is synced by the next cycle instead of waiting
- [ ] A head with no CI at all parks after the bound with a readable reason

---

## Phase 5: The rework brief (C4)

### Overview

A new `gh-read.sh` subcommand writes the latest CHANGES_REQUESTED review — its
body and its inline comments with file, line and text — to a file, and the
rework payload passes the path.

### Changes Required:

#### 1. The reader

**File**: `plugins/tsf/scripts/gh-read.sh`
**Changes**: a new subcommand

```
review-brief --repo O/R --as … --credential … --pr N --out FILE
```

1. `GET repos/O/R/pulls/N/reviews` (paged), reduced exactly as `reviews` does
   (`:325-331`) to the latest decisive review per reviewer, then the latest
   overall; proceed only when its state is `CHANGES_REQUESTED`. Keep its `id`,
   `user.login`, `submitted_at`, `body`.
2. `GET repos/O/R/pulls/N/comments` (paged), filtered client-side to
   `.pull_request_review_id == <id>`. The modern endpoint is used rather than
   `pulls/N/reviews/<id>/comments` because the latter returns the Legacy Review
   Comment schema without `line`/`side`/`start_line`.
3. Write markdown to `--out`: a heading naming the reviewer and the timestamp,
   the review body verbatim, then one section per comment with
   `` `<path>:<line>` `` (`line`, falling back to `original_line` when `line` is
   null — an outdated comment) and its body verbatim.
4. Print only `review: <id> | none`, `comments: <k>`, and the trailer. **The
   content never reaches stdout**, so the dispatcher never holds it.

`result: ok | none | rejected | denied | failed | no-credential`; `none` when
the latest decisive review is not CHANGES_REQUESTED.

#### 2. The dispatcher

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: row 11 (`:194-198`) calls `review-brief … --out .tsf-tmp/review-brief.md`
and passes `review-brief:` **the path**, replacing "the review's body and its
comments, fetched with `gh-read.sh reviews` and `gh-read.sh pr-comments`". A
`result: none` here is a state mismatch (the ticket is `tsf:rework` but no
changes-requested review exists) → park. The payload list (`:349-351`) is
updated to name `review-brief:` instead of `review-comments:`.

#### 3. The agent

**File**: `plugins/tsf/agents/implement.md`
**Changes**: the payload contract (`:39`) becomes
`review-brief:` "the path of a file holding the review's body and its inline
comments (`rework` only)"; rework mode step 1 (`:80`) reads that file instead of
an inline field. The `## CRITICAL` envelope is unchanged — the agent still never
touches GitHub.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] Against a fake `gh`: `review-brief` writes a file containing the review body and one section per inline comment with its path and line, and prints `review:` and `comments:` but no comment text
- [ ] A comment whose `line` is null renders with its `original_line`
- [ ] Comments belonging to a different review are excluded from the file
- [ ] A pull request whose latest decisive review is APPROVED yields `result: none` and writes no file
- [ ] `grep -rn 'review-comments:' plugins/tsf/` returns nothing

#### Manual Verification:

- [ ] A real "request changes" review with inline comments reaches `tsf:implement` complete

---

## Phase 6: The pull-request write path and the asynchronous sync (C12, C8)

### Overview

`gh-write.sh` gains the PR title/body write the dossier's write phase already
names, and `update-branch` polls until the head actually moves.

### Changes Required:

#### 1. The PR edit

**File**: `plugins/tsf/scripts/gh-write.sh`
**Changes**: a new subcommand

```
pr-edit --repo O/R --as … --credential … --pr N [--title T] [--body-file F]
```

At least one of `--title`/`--body-file` required. `PATCH repos/O/R/pulls/N`,
then a read-back `GET` comparing the fields that were sent, following the
`ref-create`/`contents-put` pattern (`:336-341`, `:398-401`). Prints `number:`,
`title:`; `result: updated | mismatch | rejected | denied | failed | no-credential`.
Header documentation added alongside the other subcommands.

#### 2. The polling sync

**File**: `plugins/tsf/scripts/gh-write.sh`
**Changes**: on the 202, `update-branch` (`:407-430`) polls
`GET repos/O/R/pulls/N` up to 6 times, 3 seconds apart, until `.head.sha`
differs from `--expected-head`. Output gains `new_head:` beside the existing
`previous_head:`; `result: synced` now means observed, not accepted. A head that
never moves within the bound is the new outcome

```
result: not-moved
```

with the detail naming the bound. The header block (`:66-85`) is updated: the
"the head moves shortly" sentence is replaced by the poll and its bound, and
`not-moved` joins the documented result list.

#### 3. The callers

**File**: `plugins/tsf/references/cycle-write-phase.md`
**Changes**: "The dossier's writes" (`:131-133`) names the subcommand and its
flags concretely, matching every other invocation in the file.

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: the sync sequence's `synced` branch runs `prepare` against the
**observed** `new_head:`; a `not-moved` result ends the cycle with no write, as
`head-moved` does, and the next cycle re-reads. Both row 7's conflict path and
row 12 step 1 inherit this through the shared sub-section.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] Against a fake `gh`: `pr-edit --title X --body-file F` issues one PATCH and one GET, prints `result: updated`, and reports `mismatch` when the read-back disagrees
- [ ] `pr-edit` with neither flag is a usage error (exit 1)
- [ ] Against a fake `gh` whose PR head changes on the second read, `update-branch` prints `result: synced` with `new_head:` naming the new sha
- [ ] Against a fake `gh` whose head never changes, it prints `result: not-moved` and exits 0
- [ ] The three 422 branches (`up-to-date`, `conflict`, `head-moved`) still report as before
- [ ] `cycle-write-phase.md` contains no bare `gh-write.sh` mention without a subcommand

#### Manual Verification:

- [ ] A real landing's sync reports the merged head and the following `prepare` finds it

---

## Phase 7: Resume from every state (C2)

### Overview

A `tsf:queued` ticket with a journal is resumed by mapping the last entry's
`Next step` onto its label across the whole closed vocabulary; stale
factory-side labels of every kind are corrected.

### Changes Required:

#### 1. One map, two readers

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: a new table in the Derived-state section, covering all nine values:

| `Next step` | label |
|---|---|
| `triage` | `tsf:queued` |
| `research` | `tsf:research` |
| `plan` | `tsf:plan` |
| `implement` | `tsf:implement` |
| `verify` | `tsf:verify` |
| `gates` | `tsf:verify` |
| `dossier` | `tsf:dossier` |
| `review` | `tsf:needs-review` |
| `landing` | `tsf:landing` |

The Validation section's factory-side correction (`:55-61`) is widened from
"`tsf:research` or `tsf:plan`" to **every factory-side label** — `tsf:research`,
`tsf:plan`, `tsf:implement`, `tsf:verify`, `tsf:dossier`, `tsf:rework`,
`tsf:landing` — whose step disagrees with the derived step, and uses the table
instead of its own four-entry list. The label→step mapping at `:47-49` is
extended to the same set.

#### 2. Row 3's resume

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: the `tsf:queued`-with-journal branch (`:115-118`) becomes: set the
label from the table, write the resume journal entry, and **end the cycle** —
the next scan then carries the pull-request data that later states need, which
a `tsf:queued` record does not have (`scan.sh:137`). `triage`, `research` and
`plan` keep their present behaviour of dispatching immediately, since nothing
they need comes from the scan's PR probe. A resume whose target is `verify` or
`gates` carries the next `- Episode:` number, so an exhausted
`verify_fix_bound`/`gate_fix_bound` does not re-park the ticket on its first
cycle back.

#### 3. The resume journal entry

**File**: `plugins/tsf/references/templates/journal-entry.md`
**Changes**: a new dispatcher-only shape beside the five existing ones
(`:91-164`):

```markdown
## Cycle [now] — step: [derived step]
- Outcome: resumed from tsf:needs-human at [derived step]
- Questions asked: none
- Commits: none
- Label: [the label from the map]
- Episode: [n]   (only when the label is tsf:verify)
- Next step: [derived step]
```

#### 4. The dispatcher's outcome list

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: Step 5's outcome list (`:144-153`) names the resume explicitly
under "a decision without an agent", so it reaches Step 7 and its write phase.

#### 5. The human's instruction

**File**: `plugins/tsf/README.md`
**Changes**: `:248-250` gains one sentence: the resume takes one cycle to put
the label back and the next cycle continues the work, whatever state the ticket
was parked in.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] The `Next step` → label table in `cycle-dispatch.md` lists all nine values of the closed vocabulary in `journal-entry.md:52-63` (compare the two lists)
- [ ] `cycle-dispatch.md` no longer says "`implement` → re-pick" in row 3
- [ ] The Validation section names every factory-side label, and `tsf:needs-*` appears only under the human-side rule

#### Manual Verification:

- [ ] A ticket parked at `tsf:verify`, `tsf:dossier`, `tsf:needs-review` and `tsf:landing` in turn is resumed correctly by removing `tsf:needs-human` and adding `tsf:queued`
- [ ] A resume into verification starts a fresh episode rather than re-parking

---

## Phase 8: The plan check and criteria extraction (C11)

### Overview

One script validates a plan's increment fields and extracts the numbered
criteria to a file. The gates and `tsf:manual-verify` receive paths; the
dispatcher stops reading plan and spec bodies.

### Changes Required:

#### 1. The plan format

**File**: `plugins/tsf/references/templates/plan.md`
**Changes**: the format rules gain the two enforced requirements — every
increment carries `**Verification:**` or `**Manual:**`, and increment numbers
are unique — and `## Addenda` (`:80-83`) gains a per-entry skeleton, which it
lacks today:

```markdown
### YYYY-MM-DD — Increment N: [the increment's name]

- **Why:** [what reality forced]
- **Verification:** [the increment's verification as it now stands, restated in full]
- **Manual:** [restated in full when the increment has one; omit otherwise]
```

An addendum **restates** rather than amends: the newest addendum for an
increment supersedes the increment's own fields.

#### 2. The script

**File**: `plugins/tsf/scripts/plan.sh` (new)
**Changes**: a multi-mode script in `diff.sh`'s shape.

`plan.sh check --plan <path>` — **strips fenced code blocks before matching any
heading** (the TP-0033 lesson from `plugins/tce/scripts/stage.sh`), then:

- collects `### Increment <N>: <name>` headings under `## Increments`;
- requires each to carry `**Verification:**` or `**Manual:**`;
- requires `<N>` to be unique;
- requires each `### <date> — Increment <N>: <name>` under `## Addenda` to name
  an existing increment and to carry the same fields.

Prints `increments:`, `addenda:`, `result: ok | invalid`, `detail:` naming the
first failure.

`plan.sh criteria --plan <path> --out <file> --manual-out <file>` — writes the
numbered criteria list (each increment's effective `**Verification:**`, with
`**Manual:**` items marked `MANUAL`, addenda superseding), and the manual items
alone to `--manual-out`. Prints `criteria:`, `manual:`, `result: ok | invalid`,
and fails loudly (`invalid`) when an increment yields no criterion. Content
never reaches stdout.

#### 3. The dispatcher

**Files**: `plugins/tsf/commands/cycle.md`, `plugins/tsf/references/cycle-dispatch.md`
**Changes**:

- `cycle.md:4` grants `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/plan.sh":*)`.
- `cycle.md:182-187` (MANDATORY OUTPUT) gains: when `tsf:plan` or
  `tsf:implement` returns, run `plan.sh check`; `result: invalid` is an invalid
  return — one re-dispatch with a `note:`, then a park. A plan that does not
  parse therefore never reaches the human's approval.
- `cycle-dispatch.md:134-136` (row 6, manual items) runs `plan.sh criteria` and
  passes `manual-items:` **the path**; the "when `plan.md` has `**Manual**`
  items" test becomes `manual:` being non-zero.
- `cycle-dispatch.md:152-156` (row 8) passes `criteria:` the path to
  plan-compliance and `spec:` the path `thoughts/factory/GH-<n>/spec.md` to
  spec-coverage.
- `cycle-dispatch.md:226-227` (row 12) passes `spec:` the path to integration.
- The payload section (`:354-366`) is rewritten to paths throughout; the closing
  rule "Never pass a gate the plan's prose, the research, the journal…" stays,
  with the criteria file named as the one plan-derived input.
- `cycle.md:24-27` (invariant 3) gains one clause: the criteria and the spec
  reach the gates as paths, like the diff.

#### 4. The agents

**Files**: `plugins/tsf/agents/plan-compliance.md`, `spec-coverage.md`,
`integration.md`, `manual-verify.md`, `plan.md`, `implement.md`
**Changes**: each gate's "What you receive" names a **path** instead of verbatim
text, and its `thoughts/` prohibition is widened by exactly the named files
("other than the diff file and the criteria file you were given"). `tsf:plan`
and `tsf:implement` gain one line in their format rules: an increment must carry
`**Verification:**` or `**Manual:**`, addenda restate in the template's shape,
and a return that fails `plan.sh check` is re-dispatched.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] `plan.sh check` reports `invalid` for a plan whose increment has neither `**Verification:**` nor `**Manual:**`, naming the increment
- [ ] `plan.sh check` reports `invalid` for an addendum written as free prose, and for two increments sharing a number
- [ ] `plan.sh check` reports `ok` for a plan whose only offending `### Increment 9:` heading sits inside a fenced code block
- [ ] `plan.sh criteria` writes a numbered file in which a later addendum's restatement replaces the increment's original wording
- [ ] `plan.sh criteria` marks `**Manual:**` items `MANUAL` in `--out` and writes them alone to `--manual-out`
- [ ] `plan.sh criteria` reports `invalid` when an increment yields no criterion
- [ ] Neither mode prints criteria text on stdout
- [ ] `grep -n 'verbatim' plugins/tsf/references/cycle-dispatch.md` shows no remaining plan or spec payload

#### Manual Verification:

- [ ] A real gate cycle's plan-compliance report judges against the extracted file and cites the same criteria a human reads in the plan

---

## Phase 9: Batched implementation (C10)

### Overview

Fresh-mode implementation works a bounded number of increments per cycle and
pushes at the end of each; progress lives in the journal; a cycle that builds
nothing parks.

### Changes Required:

#### 1. The constant

**File**: `plugins/tsf/templates/tsf/config.md`
**Changes**: `## Constants` gains

```
- **implement_batch:** 3   [increments built per implementation cycle in fresh
  mode. Each cycle pushes what it built, so a crash costs at most one batch;
  rework and fix mode are one cycle each regardless]
```

`init.md`'s `1.1.0` upgrade bullet covers it; absent, the default is 3.

#### 2. The journal

**File**: `plugins/tsf/references/templates/journal-entry.md`
**Changes**: the entry shape (`:30-39`) gains one conditional field, after
`Commits:`:

```
- Increments: [the numbers built in this cycle] of [total]   (only on a step: implement entry)
```

and a paragraph: the increments a ticket has built are the union of the
`- Increments:` lines of its `step: implement` entries since the ticket last
entered `tsf:implement`; that is the batch boundary and the no-progress test.

#### 3. The result block

**File**: `plugins/tsf/references/templates/result-block.md`
**Changes**: one new row in the allowed-outcomes table (`:75-89`):

```
| implement | continued | tsf:implement | implement |
```

and a rider: an intermediate batch returns that row; the last batch returns
`tsf:verify`/`verify` as today. The rider at `:91-92` ("implement uses the same
two rows in all three of its modes") is corrected — the new row is fresh mode
only.

#### 4. The agent

**File**: `plugins/tsf/agents/implement.md`
**Changes**: the payload gains `batch:` (the constant) and `built:` (the
increments already built, from the journal). Fresh mode (`:59-76`) builds at
most `batch:` increments not already built, respecting `**Depends on**`, then
returns: increments remaining → `continued` / `tsf:implement` / `implement`;
none remaining → `continued` / `tsf:verify` / `verify` as today. Its
`tsf-journal` block carries the `- Increments:` line. Rework and fix mode are
explicitly unchanged.

#### 5. The dispatcher and the write phase

**Files**: `plugins/tsf/references/cycle-dispatch.md`,
`plugins/tsf/references/cycle-write-phase.md`, `plugins/tsf/commands/cycle.md`
**Changes**:

- Row 5 (`cycle-dispatch.md:123-124`) computes `built:` from the journal and
  passes `batch:`; **the no-progress guard**: an implement return whose
  `- Increments:` adds nothing new is treated as `blocked` → park
  `tsf:needs-human`, derived from the journal alone.
- `cycle-write-phase.md:67-68`: the pull request opens after a fresh-mode
  implement whose `next-step:` is `verify` — i.e. the last batch — not after
  every fresh implement.
- `cycle-write-phase.md:50-53`: on an intermediate batch the comment is **not
  posted** (the agent still returns a non-empty `tsf-comment`, so the parsing
  rules are untouched); the journal entry, commit, push and marker call happen
  as usual.
- `cycle.md:182-187` (MANDATORY OUTPUT) already requires "at least one new
  commit for implement", which an intermediate batch satisfies.

#### 6. Setup and the deferred item

**Files**: `plugins/tsf/commands/init.md`, `plugins/tsf/README.md`,
`plugins/tsf/TODO.md`
**Changes**: `init.md` warns when a workflow providing a required check also
triggers on `push` to ticket branches — every batch push would then cost a run.
The README explains batching, the bound and the park. `TODO.md` gains an entry:
a crash that repeats on every implementation cycle leaves no trace on disk and
is not detected; what would close it is a per-cycle marker the journal cannot
carry because the crash precedes the write phase.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] `result-block.md`'s table contains the new row, and its rider says fresh mode only
- [ ] `journal-entry.md`'s entry shape lists `- Increments:` in the fixed field order, marked conditional
- [ ] `cycle-write-phase.md` opens the pull request only on `next-step: verify`
- [ ] `TODO.md` contains the crash-loop entry with a "What would close it" paragraph, matching the file's existing item shape

#### Manual Verification:

- [ ] A plan with more increments than `implement_batch` takes several cycles, each pushing its batch, with no pull request and no issue comment before the last
- [ ] A cycle that builds nothing parks the ticket

---

## Phase 10: The CI fast path (C9)

### Overview

A snippet the project installs inside the job that provides its required check:
when a push's own delta touches only `thoughts/`, the job inherits the parent
commit's concluded result instead of running the suite.

### Changes Required:

#### 1. The snippet

**File**: `plugins/tsf/templates/github/tsf-ci-fast-path.yml` (new)
**Changes**: a **steps fragment**, not a standalone workflow — its header says
so, and says it must be pasted into the job that provides the required check,
before the expensive steps, and that the job needs `checks: read` (declaring any
permission sets every unlisted one to `none`). The fragment:

- runs only when `github.event_name == 'pull_request' && github.event.action == 'synchronize'`
  — `before` is absent on `opened`, so there is no fast path there;
- reads the push's own delta with
  `GET /repos/{owner}/{repo}/compare/{before}...{after}` and its `files[].filename`,
  rather than `git diff` — the required job checks out `refs/pull/N/merge` at
  depth 1, so `before` is usually not in the local history;
- when every filename starts with `thoughts/`, reads
  `GET /repos/{owner}/{repo}/commits/{before}/check-runs?check_name=<this job's display name>&filter=latest`
  and sets one output: `success` → skip the suite and exit successfully;
  `failure` → fail immediately; **anything else — cancelled, still running,
  missing, or any API error — → run the full suite**. The third case is
  load-bearing: at landing the server's sync merge and the decision commit
  arrive as two pushes and the second cancels the first's run, so without it a
  docs-only commit could report green on a combination nobody tested;
- `before` being empty or the compare call failing also falls to "run".

The header states plainly that `before` is not in GitHub's documented
`pull_request` payload, which is why every unexpected value falls back to a full
run.

#### 2. The offer

**File**: `plugins/tsf/commands/init.md`
**Changes**: Phase 2 offers the fast path alongside the comment-pickup workflow;
Phase 4 gains a step that copies the fragment into the project (or prints it)
and **asks the user to confirm it is installed in the required job** — init
cannot verify a workflow's behaviour itself, so the confirmation is the check.
The ruleset checklist (`:378-388`) gains a line for it beside the existing
no-path-filter requirement.

#### 3. The docs

**Files**: `plugins/tsf/README.md`, `plugins/tsf/TODO.md`
**Changes**: the README explains the fast path, the three-way rule and why a
path filter is the wrong fix. `TODO.md`'s "Reduce the CI runs a landing costs"
(`:35-60`) is **rewritten**: the landing's two runs are addressed by the fast
path; what remains open is the case where the project does not install it.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] The fragment is valid YAML (`python3 -c` is not available per repo rules — validate by `yq`/`ruby -ryaml` if present, otherwise by eye against the existing template's shape)
- [ ] The fragment's header names: fragment-not-workflow, the required `checks: read`, the `synchronize`-only guard, and the three-way rule
- [ ] Every branch that is not a concluded `success`/`failure` on the parent leads to the full suite
- [ ] `TODO.md`'s landing-CI item is rewritten, not deleted

#### Manual Verification:

- [ ] Installed in the first consumer's `verify.yml`, a `thoughts/`-only push reports the required check in seconds and a code push still runs the suite
- [ ] A landing's decision commit does not start a full run

---

## Phase 11: Governance, documentation and release

### Overview

The repository's rule file gains the spans this ticket creates, the stale parts
of its layout block are corrected, and tsf is released as 1.1.0.

### Changes Required:

#### 1. New and updated CLAUDE.md rules

**File**: `CLAUDE.md`
**Changes**: three new sections, in the style of the existing tsf rules:

- **"tsf: the scan record is a machine contract"** — `scan.sh`'s header block is
  its documentation; change a field, its vocabulary or which states carry it and
  you update `scan.sh`, `commands/cycle.md` Step 3 and
  `references/cycle-dispatch.md` in the same commit. Names the
  `review_commit:`/`review_at:` split and why `review_ref:` was retired, and the
  rule that the recency test applies to changes-requested reviews only while an
  approval's guard is `diff.sh ancestor`.
- **"tsf: the plan is checked and its criteria extracted by a script"** —
  `scripts/plan.sh` is the only plan parser; the increment fields are a
  contract shared with `references/templates/plan.md` and the agents that write
  or read plans; fenced blocks are stripped before headings are matched
  (the TP-0033 lesson); the gates receive paths, never plan prose.
- **"tsf: implementation is batched and progress lives in the journal"** —
  `implement_batch`, the `- Increments:` line, the new allowed-outcomes row, the
  no-progress park, and the rule that the pull request opens only on the last
  batch. Names `implement.md`, `result-block.md`, `journal-entry.md`,
  `cycle-dispatch.md` and `cycle-write-phase.md` as the span.

Existing rules amended where a correction moved a boundary: the
dispatcher-owns-every-write rule gains `pr-edit`; the environment-cadence rule
gains the maximum-timeout requirement; the `diff.sh` rule is untouched.

**The Layout block** for `plugins/tsf/` is corrected: `scripts/*.sh` gains
`diff.sh` and `plan.sh`; `agents/*.md` reads "12 step agents: 8 workers + 4
gates" instead of "triage, research, plan (slice 1)"; `templates/github/` names
both files.

#### 2. Design record

**File**: `plugins/tsf/DESIGN.md`
**Changes**: a revision-log section for 2026-09-20 recording the corrections
that changed a documented mechanism — the widened resume (§3.4, §4 row 3), the
changes-requested staleness moving into the scan (§4 row 10), the conflict path
under `tsf:verify` (§4 row 7), batched implementation (§6.6), criteria
extraction by script (§7, §11.2), the required-check names and the CI fast path
(§12) — each with its reason. `**Status:**` is updated to v1.5.

#### 3. Release

**Files**: `plugins/tsf/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`
**Changes**: `1.0.0` → `1.1.0` in both, then
`claude plugin tag ./plugins/tsf`, in this session.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` passes
- [ ] `claude plugin validate ./plugins/tsf` passes (and the other three plugins still validate)
- [ ] Both manifests read `1.1.0` (`jq -r .version plugins/tsf/.claude-plugin/plugin.json` and the marketplace entry agree)
- [ ] `git tag --list 'tsf--v*'` includes `tsf--v1.1.0`
- [ ] `CLAUDE.md`'s tsf Layout block lists `diff.sh` and `plan.sh`
- [ ] Every file named in a new CLAUDE.md rule exists
- [ ] The twelve AskUserQuestion guideline blocks are still byte-identical (extract and diff them)

#### Manual Verification:

- [ ] `/plugin marketplace update toby-plugins` in a scratch project offers 1.1.0
- [ ] `/tsf:init` re-run against a 1.0.0 config walks the upgrade list and adds the three new config values

---

## Testing Strategy

### Script smoke tests

Per CLAUDE.md "Testing changes": a throwaway project directory plus a fake `gh`
first on `PATH` that answers with a status line, `X-GitHub-Request-Id` headers
and a JSON body (a missing header block is how a proxy denial looks). Fixtures
live in the session scratchpad, not in the repository — this repo ships no test
suite and this ticket does not add one.

Per phase, the fixtures needed:

- **Phase 1**: no `gh`; environment variables only.
- **Phase 2**: check-runs responses with a required and an optional run.
- **Phase 3**: reviews and issue-comments responses covering the four
  combinations of review state × relative age.
- **Phase 4**: a zero-check-runs head, a `mergeable: false` PR, a commit
  response carrying a committer date.
- **Phase 5**: a reviews list and a review-comments list spanning two reviews,
  one comment with `line: null`.
- **Phase 6**: a PR whose head changes on the second read, and one that never
  changes; a PATCH plus read-back pair.
- **Phase 8**: plan fixtures — valid; missing fields; duplicate increment
  numbers; a heading inside a fenced block; a free-prose addendum; a superseding
  addendum.

### Prompt-document changes

The markdown commands, references and agents have no automated test. They are
verified by: (a) the cross-file consistency checks listed as automated criteria
above (greps and list comparisons), (b) `claude plugin validate`, and (c) the
manual end-to-end run, which stays out of scope for this ticket.

### Manual Testing Steps

1. In a scratch project with the marketplace added, run `/tsf:init` against a
   1.0.0 config and confirm the upgrade walk adds `Required checks`,
   `ci_pending_bound` and `implement_batch`.
2. Start a factory session with the three exports and run `/tsf:cycle` once;
   confirm the preflight reports `bash_timeout: ok`.
3. Park a ticket at each of `tsf:verify`, `tsf:dossier`, `tsf:needs-review` and
   `tsf:landing`, resume each with `tsf:queued`, and confirm the label returns
   and the next cycle continues.
4. Request changes on a real pull request with inline comments; confirm the
   rework brief file contains them and that no journal commit is written on the
   following cycles.
5. Make a pull request conflict with its base; confirm the next cycle syncs it.
6. Run a ticket whose plan has more than three increments and confirm the batch
   behaviour end to end.

## Performance Considerations

The added REST cost is bounded and conditional: one `pr-state` call per
`tsf:verify` ticket that has zero required check runs (Phase 4), one extra
commit read inside that call, one `review-brief` call per rework dispatch
(Phase 5), and up to six polls per `update-branch` (Phase 6). Nothing is added
to the per-cycle scan. Against that, Phase 3 removes a journal commit, a push
and a CI run per cycle from every reworked ticket, and Phase 10 removes most of
the landing's CI cost.

`cycle.md` is 12,388 bytes today against a 5,000-token per-skill compaction
budget; `cycle-dispatch.md` is 20,128 bytes and is read in full at Step 5. Five
phases add dispatcher prose, so each must pay for itself: Phase 4 and Phase 6
factor the sync sequence out rather than duplicating it, and Phase 7 replaces
two partial lists with one table. Re-measure both files at Phase 11 and, if
`cycle.md` has grown materially, move prose into `cycle-dispatch.md`, which is
read from disk rather than compacted.

## Migration Notes

`.claude/tsf/config.md` gains three values. Following the
`landing_attempt_bound` precedent (`init.md:428-430`), each is documented with a
fallback so an un-upgraded project keeps working — `ci_pending_bound` 120,
`implement_batch` 3 — **except `Required checks`, which has no safe default**:
absent, the factory must keep today's "every check run counts" behaviour and
say so in the cycle's report, because guessing `none` would march a change to
the dossier with CI never having run. `/tsf:init`'s Idempotency upgrade list
gains one `1.1.0` bullet covering all three.

## References

- Original ticket: `thoughts/shared/tickets/TP-0036-tsf-review-corrections.md`
- Related research: `thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md`
- Prior slices: `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md`,
  `2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`,
  `2026-09-19-TP-0034c-tsf-landing-release.md`
- The binding design: `plugins/tsf/DESIGN.md` (§3.4, §3.5, §4, §6.6, §7, §9.3, §11, §12)
- The fenced-block lesson: `plugins/tce/scripts/stage.sh` and CLAUDE.md's TP-0033 rule
- The first consumer's CI: `/Users/toby/code/work/chat-sustainability/.github/workflows/verify.yml`
