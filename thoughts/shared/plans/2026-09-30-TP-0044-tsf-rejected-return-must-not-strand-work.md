# TP-0044: a rejected result block must not strand pushed work — Implementation Plan

## Overview

Make tsf's implementation step recoverable. Today an implement cycle that builds,
verifies, commits and pushes its batch and *then* fails its result block loses
every record of what it built, and four mechanisms in sequence make that loss
permanent. This plan puts the progress record on the branch where the work is
(`Tsf-Increment` commit trailer + `diff.sh built`), makes "the plan is already
built" a legal outcome instead of an invalid return, splits the no-progress guard
so completion and stalling stop being the same observation, and opens the pull
request on a condition rather than on two enumerated routes.

## Current State Analysis

The record of which increments are built exists in exactly one place: the
`- Increments:` line of an **accepted** agent `tsf-journal` block
(`plugins/tsf/references/templates/journal-entry.md:52-67`). The work is pushed
*before* the return is judged, and the entry the dispatcher writes when a return
is refused (`:217-224`) has no such field. So a refused return strands the work.

Four mechanisms then fire, in this order (research §"The four mechanisms"):

1. `MANDATORY OUTPUT` requires "at least one new commit for implement"
   (`plugins/tsf/commands/cycle.md:236-243`) — a cycle whose increments are
   already in the branch makes no commit and is refused. **This is what parks
   GH-41 today.**
2. The result-block parse itself accepts such a return (`commits: none` is legal,
   the `implement | continued | tsf:verify | verify` row exists), so mechanism 1
   is the one that bites.
3. The no-progress guard (`plugins/tsf/references/cycle-dispatch.md:217-222`)
   would park it next: the return adds no number the (empty) built set lacks.
4. Nothing would open the pull request: only a fresh last batch or a format-fix
   return whose `resume-to:` was `verify`
   (`plugins/tsf/references/cycle-write-phase.md:71-98`).

Two constraints discovered in research bound the fix:

- **`plan.sh` never emits the increment numbers.** `check` prints a count; the
  numbers live only in the criteria file, which invariant 3 forbids the
  dispatcher to open (`plugins/tsf/references/cycle-dispatch.md:266-267`).
  Numbers are strings and only checked for uniqueness, so contiguous `1..n` is
  not enforced and a count comparison would be wrong on a plan numbered 1,2,7.
- **A trailer cannot recover a branch built before the trailer existed.** GH-41's
  three implementation commits carry only `Co-Authored-By:`, measured. And git's
  empty trailer read is ambiguous — "absent", "block unrecognized" and "no body"
  are indistinguishable, and one prose line in a commit's final paragraph voids
  every trailer in it (`Co-authored-by:` is not one of the two git-generated
  prefixes that buy the 25% tolerance).

## Desired End State

An implement cycle's progress survives any failure of its own return, and a
branch that is already fully built advances to verification on its next cycle
instead of parking.

Verifiable by: `plan.sh check` reporting a plan's increment numbers;
`diff.sh built --base <base> --expect <numbers>` reporting the built set and what
remains; and a paper walkthrough of GH-41's live branch reaching `tsf:verify`
with a pull request open, requiring nothing from a human but the `tsf:queued`
relabel every park needs.

### Key Discoveries:

- `built:` is composed at exactly **one** site,
  `plugins/tsf/references/cycle-dispatch.md:213-216` (row 5) — `cycle.md` never
  computes it.
- The guard has exactly **two** statements —
  `plugins/tsf/references/cycle-dispatch.md:217-222` and
  `plugins/tsf/references/templates/journal-entry.md:60-64` — plus reader-facing
  paraphrases in `README.md:191-196` and `DESIGN.md:1792-1798`.
- `diff.sh` already has the whole idiom a built-set subcommand needs:
  `logic-head`'s `git rev-list --first-parent` walk fed through a here-doc, with
  per-commit `git show -s --format='%(trailers:key=…)'` reads
  (`plugins/tsf/scripts/diff.sh:259-279`).
- `pr-create` is idempotent by construction: 422 → `exists` with the number
  (`plugins/tsf/scripts/gh-write.sh:57-65`, `:432-450`). So "does a pull request
  exist" never has to be answered.
- The `Tsf-Resolution` precedent occupies **five** sites in `merge-resolver.md`
  (`:29-30`, `:73-83`, `:94-99`, `:132-133`, `:148-149`) with its authority in
  `result-block.md:191-219`. `implement.md` contains no `Tsf-*` string at all.
- The scan does not probe for a pull request in `tsf:implement`
  (`plugins/tsf/scripts/scan.sh:192`) — `pr: skipped`.
- Git-derivation of the built set was **never weighed** when batching was
  designed: *"an unexamined premise, not a researched decision"*
  (`thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md:458-460`).

## What We're NOT Doing

- **Unblocking GH-41 by hand.** No manual journal entry, no hand-created pull
  request, no branch checkout. It is the live test case.
- **Backfilling trailers onto GH-41's existing commits.** The recovery path
  (Phase 5) is what handles a pre-trailer branch; rewriting pushed history is not.
- **Inferring which increment a commit implements** from its diff or its message.
  The agent states it or it is not known.
- **Reading a trailer off a squash commit.** Unsound (GitHub drops or buries
  them) and unnecessary: the built set is read on the branch, pre-merge.
- **Touching the plan parser's field tolerance or the format-fix path** — TP-0043,
  shipped as 1.3.0.
- **Rework and fix mode.** Neither is batched and neither carries `built:`; their
  commits deliberately carry no increment trailer.
- **Closing `plugins/tsf/TODO.md`'s "implementation that crashes on every cycle"**
  — that is a cycle which never *returns*, a different failure with no trace on
  disk.

## Implementation Approach

Scripts first, because they are the only parts of this change that can be
verified automatically — TP-0036 shipped batching with its own plan recording
*"no automated test — it is prompt behaviour"*, and both of its manual criteria
were left unticked. Phases 1 and 2 are real bash with real fixtures, including
GH-41's actual plan and branch; Phase 2 is where the pre-trailer-branch
expectation gets proven, at the cheapest possible point.

Then the independent prompt change (Phase 3), then the trailer (Phase 4), then
the recovery path that depends on all three (Phase 5), then restatements and
rules (Phase 6), then the walkthrough and the release (Phase 7).

One design decision shapes two phases: **`diff.sh built` takes the plan's numbers
as an argument and reports what remains**, rather than the dispatcher doing set
arithmetic in prose. `plan.sh` emits `numbers:`, the dispatcher passes it through
as `--expect`, and `diff.sh` answers `remaining:`. That keeps the arithmetic in a
script without `diff.sh` ever parsing a plan — the `branch.sh` / `stage.sh`
division of labour.

---

## Phase 1: `plan.sh` reports the increment numbers

### Overview

`check` gains one line so that "which increments does this plan have" is
answerable without opening the criteria file.

### Changes Required:

#### 1. The parser's output

**File**: `plugins/tsf/scripts/plan.sh`
**Changes**: `check` prints a `numbers:` line after `increments:`. The value is
the increment numbers in **file order**, comma-separated, or `-` when there are
none. Derived from the existing normalized stream's `INC` records — no new
parsing.

```bash
# after the existing INCREMENTS/ADDENDA greps (around :250-251)
NUMBERS="$(awk -F'\t' '$1 == "INC" { printf "%s%s", sep, $2; sep="," }' "$STREAM")"
[ -n "$NUMBERS" ] || NUMBERS="-"
```

```
increments: 3
numbers:    1,2,3
addenda:    1
result:     ok
detail:     3 increment(s) and 1 addendum(s), every increment verifiable
```

Key padding stays at column 13, matching `increments:` / `addenda:` / `result:` /
`detail:`. The line is printed on every `check` path including the failure paths,
exactly as the two count lines already are (`-` when the stream has no `INC`
record).

`criteria` does **not** gain the line: the dispatcher runs `check` on both the
plan and the implement return, which is precisely when the numbers are needed,
and `criteria` is called by rows that do not need them.

#### 2. The header block

**File**: `plugins/tsf/scripts/plan.sh`
**Changes**: add `numbers:` to `check`'s documented record in the header, and one
sentence saying the numbers are the plan's own order and are **strings** — `01`
and `1` are distinct, nothing enforces contiguous `1..n`, and a consumer must
compare them as a set rather than counting them.

### Success Criteria:

#### Automated Verification:

- [ ] `plugins/tsf/scripts/plan.sh check --plan <GH-41's plan>` prints
      `numbers:    1,2,3` and still `result: ok`
- [ ] A synthetic plan numbered 1, 2, 7 prints `numbers:    1,2,7` — proving the
      numbers are read, not counted
- [ ] A synthetic plan whose increments appear in the order 2, 1 prints
      `numbers:    2,1` (file order, not sorted)
- [ ] A plan with no `## Increments` section prints `numbers:    -` with
      `increments: 0` and `result: invalid`
- [ ] A plan whose fenced code block quotes `### Increment 9: …` does **not**
      list 9 — the TP-0033 fence-stripping regression
- [ ] An addendum-bearing plan is unchanged in `increments:`, `addenda:`,
      `result:` and `detail:` — the line is additive
- [ ] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] The header block's new text reads in the file's existing register and its
      key alignment matches the surrounding record blocks

---

## Phase 2: `diff.sh built` derives the built set from the branch

### Overview

A new subcommand reads the `Tsf-Increment` trailers of the branch's own commits
and reports what is built and — given the plan's numbers — what remains.

### Changes Required:

#### 1. The subcommand

**File**: `plugins/tsf/scripts/diff.sh`
**Changes**: new `built` mode following the file's established scaffolding — one
`usage()` line, one initializer on the flag-init line, one flag arm per new flag,
one per-mode requirement arm, one dispatch arm, plus the header entry.

```
#   built     The increments already built on this branch: the Tsf-Increment
#             trailer values of the branch's OWN commits (§3.5's first-parent
#             chain), deduplicated and sorted. --expect takes the plan's
#             increment numbers (plan.sh check's `numbers:` line, passed
#             through verbatim) and the answer names what is still missing, so
#             the caller performs no set arithmetic of its own.
#
#             --base is required and load-bearing: a ticket branch that was
#             merged with a real merge commit makes ANOTHER ticket's increment
#             commits reachable from HEAD, and their trailers would otherwise
#             join this branch's set.
#
#             An empty result is AMBIGUOUS and must be read as "unknown", never
#             as "nothing was built": git returns the empty string alike for a
#             missing trailer, a commit whose final paragraph stopped being a
#             trailer block, and a commit with no body. A branch built before
#             this trailer existed reports `-` while being wholly built.
#
#               built:     <comma-separated numbers, ascending> | -
#               count:     <number of increments found>
#               remaining: <comma-separated numbers> | -   (only with --expect)
#               result:    ok | none | failed
#               detail:    <one line>
```

Walk and read:

```bash
git rev-list --first-parent "$BASE_REF..HEAD"
# per commit:
git show -s --format='%(trailers:key=Tsf-Increment,valueonly,separator=%x2C,unfold)' "$CANDIDATE"
```

`--first-parent` for the same reason `logic-head` needs it — the branch's own
line of development. **No `thoughts/` pathspec exclusion**: an increment commit
may legitimately carry `plan.md` alongside its code (the addendum rule), and a
commit is selected by its trailer rather than by its paths.

`unfold` is added (the existing `logic-head` read omits it); a folded value would
otherwise arrive with an embedded newline. Values are trimmed, split on the
separator, deduplicated, and sorted **ascending numerically** so the output is
stable. A commit carrying two values is reported in `detail:` — the commit rules
say one commit per increment — but both values are still counted, because
discarding a stated fact would be worse than reporting an irregular one.

`result:` is `none` when no trailer is found anywhere (with `built: -`,
`count: 0`), `ok` when at least one is, `failed` when the base ref cannot be
resolved. Every reported outcome exits 0, per the file's closing rule.

#### 2. The base-ref resolution

**File**: `plugins/tsf/scripts/diff.sh`
**Changes**: copy the existing three-line `origin/$BASE`-or-`$BASE` block
verbatim from `pr-diff` (`:185-191`), as `files` and `main-delta` already do.
There is no helper and this plan does not introduce one — four copies of three
lines is not the problem this ticket is fixing.

### Success Criteria:

#### Automated Verification:

- [ ] In a scratch repo: three commits trailered `Tsf-Increment: 1` / `2` / `3`
      on a branch off `main` → `built: 1,2,3`, `count: 3`, `result: ok`
- [ ] With `--expect 1,2,3` → `remaining: -`; with `--expect 1,2,3,4` →
      `remaining: 4`; with `--expect 1,2,7` → `remaining: 7`
- [ ] A commit with no trailer is skipped; a branch with none →
      `built: -`, `count: 0`, `result: none`
- [ ] Ascending numeric sort: trailers written 3, 1, 2 → `built: 1,2,3`, and
      `10` sorts after `9`
- [ ] A trailer with a prose line appended after it in the same paragraph is
      **not** found — pinning the documented ambiguity as observed behaviour
- [ ] A commit trailered alongside `Co-Authored-By:` in one clean paragraph **is**
      found — the shape the implement agent actually writes
- [ ] `--base` excludes another ticket's trailered commits made reachable through
      a merge commit
- [ ] A missing `--base` is a usage error (exit 1); an unresolvable base is
      `result: failed` (exit 0)
- [ ] **Against GH-41's live branch**: `built: -`, `count: 0`, `result: none`,
      and with `--expect 1,2,3` → `remaining: 1,2,3` — the pre-trailer-branch
      case Phase 5 exists to recover
- [ ] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] The header entry's alignment and register match the six existing entries

---

## Phase 3: the pull request opens on a condition, not on two routes

### Overview

Any implement return heading to `verify` opens the pull request, whatever its
mode. This retires the class of bug TP-0043 patched one instance of.

### Changes Required:

#### 1. The trigger

**File**: `plugins/tsf/references/cycle-write-phase.md` (the
`# Opening the pull request` section, currently `:71-98`)
**Changes**: replace the two enumerated triggers with one condition. The new
opening states: after a successful **implement** return whose `next-step:` is
`verify` — **in any mode** — the ticket gets its pull request, between step 3
(push) and step 4 (marker). An intermediate batch (`next-step: implement`) pushes
and stops there, unchanged, with its existing reason (a CI run per batch on
unfinished code).

The format-fix paragraph (`:80-85`) is **deleted**, not amended: it is subsumed.
Its load-bearing sentence is promoted into the rule's justification — `exists` is
a fine answer, which is what makes the step safe to reach any number of times —
and the reason is stated as a rule rather than as an exception: a route-by-route
trigger has already been wrong twice, and the condition cannot be wrong for a
route nobody has thought of yet.

Add one sentence recording that rework and fix mode now reach this step too and
that this is intended: their pull request has existed for ages, so they get
`exists` and one idempotent REST call.

Keep unchanged: the `--pr <number>` hand-off to step 4's marker call, and the
note that the number reaches the journal only in the next cycle's entry.

#### 2. The commit-requirement cross-reference

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: `MANDATORY OUTPUT`'s `pr-body.md` clause stays **fresh-mode only**
(rework and fix never write the file; it has existed since the last fresh batch),
and the existing `mode: format-fix` carve-out paragraph keeps its `pr-body.md`
sentence. Only its now-stale justification — that the pull request would
otherwise never open — is dropped, since Phase 3 makes that true of no route.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tsf` passes
- [ ] No occurrence of `resume-to:` remains in
      `plugins/tsf/references/cycle-write-phase.md`'s pull-request section
- [ ] `grep -c 'mode: fresh' plugins/tsf/references/cycle-write-phase.md` shows
      the pull-request section no longer gates on mode

#### Manual Verification:

- [ ] Reading the section cold, a fresh last batch, a format-fix resume, a
      rework return and a fix return all clearly reach the same step
- [ ] The intermediate-batch exclusion is still unmistakable

---

## Phase 4: the `Tsf-Increment` trailer

### Overview

Each increment commit states its own number in a trailer, so the built set
becomes a fact about the branch rather than a line only an accepted return can
write.

### Changes Required:

#### 1. The contract

**File**: `plugins/tsf/references/templates/result-block.md`
**Changes**: add a fifth numbered part, `# The increment trailer`, after
`# The resolution trailer`, and add it to the contents list at `:24`
(`5. The increment trailer (implement; read by diff.sh built)`).

It states: one `Tsf-Increment: <n>` line, the increment's number exactly as the
plan writes it, in the commit's trailer paragraph after a blank line; one
increment per commit, so one trailer per commit; **only** fresh-mode increment
commits carry it — never a fix, rework, format-fix, `pr-body.md` or plan-only
commit, because the trailer is the sole thing distinguishing an increment commit
from any other factory commit.

And the polarity, stated as the contract's own caveat rather than left to the
reader: `diff.sh built` reads an absent trailer as **unknown**, never as "not
built", because git cannot distinguish "no trailer" from "the final paragraph
stopped being a trailer block". This is the opposite of `Tsf-Resolution`'s
fail-closed reading, and the difference is deliberate — one costs a re-approval,
the other would rebuild finished work.

#### 2. The agent

**File**: `plugins/tsf/agents/implement.md`
**Changes**: the five positional slots the `Tsf-Resolution` precedent occupies in
`merge-resolver.md`, in the same order:

- `## CRITICAL` closing `ONLY` bullet (`:28-29`) — name the trailer alongside
  committing.
- `## Process` → `### Fresh` step 2 (`:83-92`) — at the point the increment is
  committed, the trailer goes on that commit.
- `## Commit rules` (`:166-173`) — a new **bullet 2 of 5**, immediately after the
  convention bullet and before the `plan.md` bullet, mirroring merge-resolver's
  placement: the message must end with `Tsf-Increment: <n>` after a blank line;
  `result-block.md` defines it; `diff.sh built` reads it, and it is what lets a
  later cycle know this increment is done even if this return is refused.
- `## Return` post-skeleton (`:206-207`) — one sentence: the `- Increments:` line
  is the cycle's narrative; the machine fact is the trailer.
- `## What NOT to Do` (`:254-264`) — don't omit it, and don't put it on a fix,
  rework or `pr-body.md` commit.

One addition the precedent does not have: the trailer must be the **sole tsf
content of the commit's last paragraph**, sitting with whatever attribution
trailers the project adds and nothing else — no prose after it. A single
non-trailer line in that paragraph makes git drop every trailer in it.

#### 3. The claimed-increments cross-check

**File**: `plugins/tsf/commands/cycle.md` (Step 6)
**Changes**: a new mechanical detector, placed between the `MANDATORY OUTPUT`
carve-outs and `THE PLAN MUST PARSE`. On a fresh-mode implement return carrying a
`- Increments:` line, run `diff.sh built` and require every number the return
**claims to have built this cycle** to appear in the result. A number that does
not is an invalid return.

Per TP-0043's rule, the note carries the required **shape**, not just the
complaint — the literal `Tsf-Increment: <n>` line, its position after a blank
line at the end of the message, and pointers to both `result-block.md` and the
agent's own `## Return` section. One re-dispatch, then park `tsf:needs-human`,
the bound the other artifact detectors share.

Update the sentence at `:279-281` that counts "the other three invalidity
detectors" — there are now four.

Note what this detector deliberately does **not** check: whether the built set
covers the whole plan. That is Phase 5's discrepancy rule, and conflating the two
would re-break every pre-trailer branch.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tsf` passes
- [ ] `grep -c 'Tsf-Increment' plugins/tsf/agents/implement.md` finds it at all
      five slots
- [ ] `plugins/tsf/references/templates/result-block.md`'s contents list has five
      numbered parts and the fifth matches the new heading
- [ ] The detector count in `plugins/tsf/commands/cycle.md` reads four, not three

#### Manual Verification:

- [ ] The five agent slots read in `implement.md`'s register and sit where the
      merge-resolver equivalents sit, checked side by side
- [ ] The new detector's note names one canonical shape, not a set of tolerated
      ones (TP-0043's asymmetry rule)
- [ ] The trailer's prohibition on fix/rework/`pr-body.md` commits is stated in
      both the contract and the agent

---

## Phase 5: the empty cycle is legal, and the guard has two conditions

### Overview

The recovery path. A cycle that finds the plan already built returns
successfully, the guard stops confusing completion with stalling, and `built:`
comes from the branch.

### Changes Required:

#### 1. The commit-requirement carve-out

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: a second carve-out paragraph beside the `mode: format-fix` one
(`:245-248`): a fresh-mode implement return that reports every increment already
built makes no commit, and is not invalid for that reason. It still owes a
committed `pr-body.md` — the fresh-mode clause is unchanged, and on a branch that
reached a last batch the file is already there.

#### 2. The agent's empty-remainder instruction

**File**: `plugins/tsf/agents/implement.md` (`### Fresh`, step 1, `:74-82`)
**Changes**: distinguish three cases that today collapse into one `blocked`:

- increments remain → build at most `batch:` of them, as now;
- **`built:` may under-report.** It is what the branch's trailers record, and a
  branch built before the trailer existed carries none. So before building an
  increment, check whether it is already present in the code; if every increment
  is, build nothing and return `outcome: continued`, `next-step: verify`,
  `commits: none`, no `- Increments:` line, and a comment saying the plan was
  already built and by which commits;
- an increment whose `**Depends on**` names an unbuilt one waits, and if that
  empties the batch it is still `outcome: blocked` — unchanged, and now visibly
  separate from the case above.

#### 3. Row 5

**File**: `plugins/tsf/references/cycle-dispatch.md` (`:208-226`)
**Changes**:

- `built:` is now `diff.sh built --base <base branch> --expect <the `numbers:`
  line from the `plan.sh check` this cycle already ran>`; its `built:` line
  becomes the payload's `built:` and `-` becomes `none`.
- **The no-progress guard becomes two conditions**: park `tsf:needs-human` only
  when the return added no new increment **and** `remaining:` is non-empty. A
  return whose `remaining:` is empty is the last batch and goes to `verify`.
- **The discrepancy rule** (decided 2026-09-30): when the return says
  `next-step: verify` while `remaining:` is non-empty, **advance anyway** and
  record the gap in the journal. The agent has the plan and the branch in front of
  it; the plan-compliance gate judges the built code against the plan's criteria,
  so completeness is re-checked one step later rather than guessed at here. State
  the reason inline — this is the clause that recovers a pre-trailer branch, and
  a future reader must not "tidy" it into a park.

#### 4. The journal

**File**: `plugins/tsf/references/templates/journal-entry.md`
**Changes**:

- `- Increments:` is demoted to **narrative**: it records what a cycle built for a
  human reader, and no reader derives state from it. The built-set definition in
  "The increments line" (`:52-67`) is replaced by a pointer to `diff.sh built`,
  and the journal-scan anchor ("since it most recently entered `tsf:implement`")
  goes with it — a branch-derived set has no such boundary.
- The guard's restatement (`:60-64`) gains the second condition.
- **A new `- Built set: <built> of <expected>` line** on `step: implement`
  entries, written by the **dispatcher** from `diff.sh built`. This is the one
  stated exception to "the body is the agent's `tsf-journal` block, verbatim",
  and the exception is why it earns its place: it is the derived fact sitting
  beside the agent's narrative, and it is what makes a discrepancy visible to a
  human later. GH-41's recovery cycle will record `- Built set: - of 1,2,3`.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tsf` passes
- [ ] `plugins/tsf/references/cycle-dispatch.md` row 5 references
      `diff.sh built` and no longer derives `built:` from journal text
- [ ] `plugins/tsf/references/templates/journal-entry.md` documents
      `- Built set:` and the verbatim exception together

#### Manual Verification:

- [ ] Walk a normal three-batch implementation on paper: batch 1 commits with
      trailers, `built: 1,2,3` grows per cycle, `remaining:` shrinks, the last
      batch opens the pull request
- [ ] Walk a genuinely stalled cycle — increments remain, the agent builds
      nothing — and confirm it still parks `tsf:needs-human`
- [ ] Walk a refused return after a push: the next cycle's `built:` includes the
      pushed increments, so the batch is not rebuilt
- [ ] The three cases in the agent's step 1 are distinguishable on one read

---

## Phase 6: restatements and the CLAUDE.md rules

### Overview

Bring the reader-facing descriptions and the repo's same-commit rules in line, so
the next change to any of this does not silently drift.

### Changes Required:

#### 1. Consumer documentation

**File**: `plugins/tsf/README.md` (`:191-199`)
**Changes**: the progress record is the branch, not the journal; a cycle that
builds nothing parks **only while increments remain**; the pull request opens when
a batch finishes the plan, by whichever route.

**File**: `plugins/tsf/DESIGN.md`
**Changes**: §6.6 and decision 59 ("Implementation is batched") updated, plus a
new numbered decision recording that the progress record moved to the branch and
why the dispatcher believes a completeness report.

**File**: `plugins/tsf/templates/tsf/config.md` (`:90-92`)
**Changes**: `implement_batch`'s comment says the journal records which
increments were built; it now says the branch does.

#### 2. The repo's rules

**File**: `CLAUDE.md`
**Changes**: five spans engaged by this ticket:

- *"tsf: implementation is batched; progress lives in the journal"* — retitled and
  rewritten: progress lives on the branch, in the trailer; the journal's line is
  narrative. Its same-commit list gains `diff.sh` and `plan.sh`.
- *"tsf: the logic head and the PR diff are `diff.sh`'s job"* — add `built` to the
  facts `diff.sh` owns, and the "never compose a raw `git` command in prose" rule
  extends to it.
- *"tsf: the plan is parsed by a script"* — `check` now also reports the numbers,
  and they are strings compared as a set.
- *"tsf: the journal's `Next step` is the derived state"* — the `- Built set:` line
  and the one exception to verbatim bodies.
- *"tsf: the result block is a machine contract"* — the fifth part, the increment
  trailer, and its opposite polarity from `Tsf-Resolution`.

Add one new rule of its own: **a progress record must live where the work lands.**
The journal-only built set was not a bad implementation of a good idea; it was a
record kept somewhere the work could outrun it. Any future counter that gates a
step gets the same test — can the thing it describes exist while the record of it
does not?

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] No occurrence of "progress lives in the journal" survives in `CLAUDE.md`,
      `plugins/tsf/README.md` or `plugins/tsf/DESIGN.md`

#### Manual Verification:

- [ ] Each of the five CLAUDE.md spans names every file that must move with it,
      checked against the files this plan actually edits
- [ ] The README's batching paragraph is true of the shipped behaviour read cold
- [ ] DESIGN.md's new decision states the trade-off, not just the outcome

---

## Phase 7: the GH-41 walkthrough, then the 1.4.0 release

### Overview

Prove the acceptance criterion against the live stuck ticket, then release.

### Changes Required:

#### 1. The walkthrough

**Changes**: no files. Trace GH-41 against the edited files and record the result
in the phase log. The expected path:

1. A human replaces `tsf:needs-human` with `tsf:queued`. **This step is required
   and is not a defect**: a parked ticket is not actionable
   (`plugins/tsf/commands/cycle.md` Step 3), and re-queuing is the one gesture
   every park asks for — its comment already says so. "No human step" in the
   acceptance criterion means no manual journal entry, no hand-created pull
   request and no branch checkout.
2. Row 3 resumes at `implement` (the journal's last `Next step`), `mode: fresh`.
3. `plan.sh check` → `numbers: 1,2,3`. `diff.sh built --base main --expect 1,2,3`
   → `built: -`, `remaining: 1,2,3`. Payload carries `built: none`.
4. The agent reads the plan, finds all three increments present in the code,
   builds nothing, returns `outcome: continued`, `next-step: verify`,
   `commits: none`.
5. Step 6: the new carve-out permits the absent commit; `pr-body.md` is committed
   already; `plan.sh check` passes; the claimed-increments detector is inert (the
   return claims none).
6. Row 5: `remaining:` is non-empty but the return says `verify` → the discrepancy
   rule advances it and the entry records `- Built set: - of 1,2,3`.
7. Write phase: journal, commit, push, **`pr-create` → `created`**, marker with
   `--pr`, comment, label `tsf:verify`.

#### 2. The release

**Files**: `plugins/tsf/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`
**Changes**: version `1.3.0` → `1.4.0` in both, then
`claude plugin tag ./plugins/tsf`, then confirm with
`git tag --list 'tsf--v*'`. Tagging happens in this session, per the release rule
— tsf `0.1.0`, `0.2.0` and tle `1.0.0` all shipped untagged and had to be
backfilled.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] Both manifests read `1.4.0` and agree
- [ ] `git tag --list 'tsf--v*'` includes `tsf--v1.4.0`

#### Manual Verification:

- [ ] The seven-step walkthrough is recorded in the phase log with the actual
      script outputs for steps 3 and 6, run against GH-41's real branch and plan
- [ ] **On the live ticket**: after the `tsf:queued` relabel, one `/tsf:cycle` in
      the factory clone takes GH-41 to `tsf:verify` with a pull request open, and
      its journal entry carries `- Built set: - of 1,2,3`
- [ ] A second `/tsf:cycle` then proceeds with verification rather than re-parking

---

## Testing Strategy

### Unit Tests:

There is no test framework in this repo; the scripts are exercised directly, as
`CLAUDE.md` → "Testing changes" prescribes.

- `plan.sh check` against fixtures in the scratchpad: contiguous, non-contiguous,
  out-of-order, empty, fenced-heading, addendum-bearing — plus GH-41's real plan.
- `diff.sh built` against a purpose-built scratch git repo covering: trailered and
  untrailered commits, out-of-order numbers, two-digit numbers, a trailer followed
  by prose in the same paragraph, a trailer beside `Co-Authored-By:`, another
  ticket's commits reachable through a merge commit, a missing `--base`, an
  unresolvable base — plus GH-41's real branch.

### Integration Tests:

Not available in-session: the dispatcher paths need a GitHub repository and a
second account (`CLAUDE.md` → "tsf end to end"). Phases 3-6 are prompt text, so
their verification is `claude plugin validate` plus the paper walkthroughs, and
the live confirmation is Phase 7's manual criterion on GH-41 itself — which is
the closest thing to an end-to-end test this change can get, because it is a real
stuck ticket rather than a scratch one.

### Manual Testing Steps:

1. Run each phase's script assertions and keep the outputs for the phase logs.
2. Walk the three implementation paths on paper (normal batching, stall, refused
   return after a push) against the edited files.
3. Walk GH-41's seven steps against the edited files.
4. After the release, relabel GH-41 `tsf:queued` and run one `/tsf:cycle` in the
   factory clone; confirm `tsf:verify`, the pull request, and the journal line.

## Performance Considerations

`diff.sh built` adds one `git show -s` per commit on the branch's first-parent
chain — the same per-commit cost `logic-head` already pays, on a branch that is
tens of commits at most. Phase 3 adds one idempotent REST call per rework and fix
cycle, where a pull request already exists.

## Migration Notes

**A branch built before this release carries no trailers**, so `diff.sh built`
reports `-` for it. Phase 5's recovery path is the migration strategy: the agent
inspects the code, reports the plan already built, and the discrepancy rule lets
it through. No history is rewritten and no trailer is backfilled.

**Un-upgraded projects are unaffected.** Nothing in the change reads project
config, and a plan written before this release parses identically — `numbers:` is
additive and the trailer's absence is the migration case, not an error.

**`implement_batch` and the journal's existing entries keep working**: the
built-set derivation stops reading the journal, so old entries are neither
required nor misread.

## References

- Original ticket: `thoughts/shared/tickets/TP-0044-tsf-rejected-return-must-not-strand-work.md`
- Related research: `thoughts/shared/research/2026-09-30-TP-0044-tsf-rejected-return-must-not-strand-work.md`
- The precedent this copies: `plugins/tsf/agents/merge-resolver.md:94-99` and
  `plugins/tsf/references/templates/result-block.md:191-219` (`Tsf-Resolution`)
- The walk idiom: `plugins/tsf/scripts/diff.sh:259-279` (`logic-head`)
- TP-0043 — the same run, one layer up; its plan's Phase 3 log records the
  pull-request gap Phase 3 here generalizes
  (`thoughts/shared/plans/2026-09-28-TP-0043-tsf-format-problems-never-reach-a-human.md:569-581`)
- TP-0036 — where batching, the built set and the guard originate
  (`thoughts/shared/tickets/TP-0036-tsf-review-corrections.md:233-239`)
