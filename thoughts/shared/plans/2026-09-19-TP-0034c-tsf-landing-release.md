# tsf slice 3 — landing loop, integration gate, and the 1.0.0 release

## Overview

This plan implements the last region of the tsf state machine: DESIGN.md §4
row 12, the landing loop of §9.3. After it, an approved pull request lands
without the human touching anything — the branch is synced, the integration
gate judges the combination, the merge decision is recorded, and a later cycle
merges and cleans up. The plugin then reaches `1.0.0`, is listed in the
marketplace catalog, and is tagged.

It is the third of three slices (TP-0034a/b/c) under the epic TP-0034.

## Current State Analysis

Slice 2 stopped exactly at the landing and left a clean seam: seventeen places
name `tsf:landing` and defer it, while several structures the landing needs are
already in place. `scan.sh --pr-probe` already probes landing tickets
(`plugins/tsf/scripts/scan.sh:137`), so a landing ticket already arrives with
`pr`, `pr_head`, `ci`, `review`, `review_ref` and `factory_comment` filled;
`journal-entry.md:60` already carries `landing` in the closed `Next step`
vocabulary; row 10 already *produces* the label
(`plugins/tsf/references/cycle-dispatch.md:176-181`); and `/tsf:init` already
creates it (`plugins/tsf/commands/init.md:286`).

What is missing is the dispatch row, two agents, six script capabilities, and
the documentation and release work.

### Platform and API facts the plan rests on (research + the 2026-09-19 spike)

The consumer-side spike required by the ticket's Dependencies section **was
run** on 2026-09-19 in `tobyS/chat-sustainability` as the factory identity
`tobySagent`. Its outcome selects the mechanism per operation, which the ticket
requires this plan to record:

| Operation | Result | Mechanism selected |
|---|---|---|
| `PUT …/pulls/67/update-branch` | 202, GitHub headers | **REST** |
| `PUT …/pulls/67/merge` (squash, `sha` guard), with approval | 200, `merged=true` | **REST** |
| Same merge without an approving review | 405, body "Repository rule violations found - At least 1 approving review is required…"; `mergeable_state: blocked` | — |
| `DELETE …/git/refs/heads/spike-a` | 204; re-read returns 404 | **REST** |

**The label-bridge fallback of §10 / §16.4 is therefore not built.** It remains
a documented contingency for a future consumer whose sandbox refuses a call.

Further facts the spike established or confirmed:

- **The sync commit's author is the calling identity** (`tobySagent`), not
  GitHub — so authorship cannot distinguish a mechanical sync merge from an
  ordinary factory commit. Its **committer** is `GitHub <noreply@github.com>` /
  login `web-flow`, it has **two parents**, and it is GitHub-signed.
- **`mergeable_state: behind` is real** — observed under the strict
  up-to-date rule, closing the question left open by
  `thoughts/shared/research/2026-09-10-GH-56-deploy-key-push-test-findings.md:177-182`.
  `mergeable` was non-null after a single poll.
- **`GET /repos/{owner}/{repo}` (the bare repository object) was proxy-denied**
  under an allowlist carrying only the `/**` pattern. The plugin must never
  depend on it — in particular it must not read `delete_branch_on_merge`.
- **The update-branch async window is short** (~6 s to a changed head, ~8 s to
  the first check run); a zero-check-run window was never observed.
- Refusals arrive as **405 with the reason in the body**, not 409. 409 remains
  untested and is the reason to pass `sha` on the merge.
- Commits created through the contents API are **unsigned**, while
  update-branch and merge commits are GitHub-signed.

From the research, the REST surface itself:

- `update-branch` is **merge-only** — the endpoint has no `merge_method` or
  rebase parameter (the UI's "Update with rebase" is GraphQL-only). This
  happens to match §16.5's "rebase stays forbidden".
- `expected_head_sha` defaults to the current head, so **omitting it is not a
  guard**; a short SHA is rejected with 422.
- 422 on `update-branch` is a **family** — conflict, "no new commits on the base
  branch", and SHA mismatch all arrive as 422, so the `message` is the only
  discriminator.
- `mergeable` / `mergeable_state` exist **only on the single-PR endpoint**;
  `gh-read.sh pr` reads the list endpoint (`gh-read.sh:224`), whose objects lack
  them. `mergeable` is computed asynchronously and is `null` until ready.
- `gh pr merge`, `gh pr update-branch` and `gh pr checks` are all
  **GraphQL-backed** and are forbidden by §10; everything here is `gh api`.
- Deleting an already-gone ref is reported as **422 "Reference does not
  exist"**, not 404.

## Desired End State

`/tsf:cycle` handles `tsf:landing`. A cycle picks landing tickets before all
other work, keeps at most one landing in flight, and advances it: a **decision
cycle** that syncs, gates, decides and records; then a **write-free merge
cycle** that confirms and merges. A landed issue is closed, carries no `tsf:*`
state label, has its branch deleted, and is never picked again. tsf is
`1.0.0`, listed in the root README, and tagged `tsf--v1.0.0`.

### Key Discoveries:

- The `Next step` vocabulary needs no growth — `landing` is already in it
  (`plugins/tsf/references/templates/journal-entry.md:60`); the **`step:`**
  vocabulary on the entry heading does (`journal-entry.md:30`).
- `cycle-dispatch.md:34-35` restricts a readable `Next step` to
  `triage | research | plan | implement` — narrower than the closed vocabulary
  itself, and it must widen.
- `gh-write.sh labels` rejects a bare `tsf:` (`gh-write.sh:134`) and always
  appends `$SET` (`:171`); the full-set machinery around it already does
  everything a clear mode needs.
- `push.sh` hard-codes the refspec `refs/heads/B:refs/heads/B`
  (`push.sh:82`, `:88`), so ref deletion cannot go through it.
- `cycle.md` is 201 lines / 10.7 KB against the slice-2 budget of ≤ 230 lines /
  ≤ 18 KB — roughly 7 KB of headroom, so row 12's detail lives in the
  references.
- Slice 2's plan-compliance gate caught two "counter that nothing writes" bugs
  (`…TP-0034b…md:975-989`). The landing attempt counter is the same hazard and
  is specified from the journal, not from report filenames, for that reason.

## What We're NOT Doing

- **The label-bridge merge workflow** (§10, §16.4) — the spike proved REST
  works; the fallback stays documented, unbuilt.
- **Reducing the number of CI runs per landing** — a landing costs up to two
  runs per attempt (the sync push and the decision push). Recorded in
  `TODO.md` instead (user decision, 2026-09-19).
- **Detecting "this repository has no PR CI"** — already deferred in
  `plugins/tsf/TODO.md:8-33`; unchanged.
- The release/deploy step (§15 item 2) and everything else in §14 — curated
  rebase, merge queue, auto-merge, parallel execution.
- The consumer project's own changes (its handover document lists them).
- **The end-to-end smoke test** is authored here but, like slices 1 and 2's,
  runs at the first real factory setup — see "Testing Strategy".

## Implementation Approach

Bottom-up, one validatable layer per phase, as in slices 1 and 2: scripts
first (testable against a scratch repository and a fake `gh`), then the
contracts the agents and dispatcher read, then the agents, then the dispatcher
row that orchestrates them, then docs and the release.

### Decisions taken with the user (2026-09-19)

1. **The landing builds on REST**, per the spike. The fallback is documented,
   not built.

2. **The logic head excludes a commit iff it has two parents AND either its
   committer is `web-flow` or it carries the trailer `Tsf-Resolution:
   mechanical`.** A purely git-visible rule would exclude a *logic* resolution
   too — also a two-parent merge — silently leaving a stale approval valid. So
   the merge-resolver records its classification as a commit trailer, and
   `diff.sh logic-head` consults it. (Research options A **and** B; A alone is
   insufficient.)

3. **The silent restart is bounded at 3** (`landing_attempt_bound`, a new
   config constant), and **restarts are made visible** in the cycle's closing
   report before the bound bites. §9.3 says the restart is silent and names no
   bound; without one, a base branch that moves faster than a landing window
   (~2 CI runs) livelocks the landing invisibly while burning CI.

4. **The main-delta range** comes from the main head recorded in the last
   `integration-<n>.md`; on a first attempt, from the merge-base of the
   approving review's `commit_id` with `origin/<base>`. §3.5 forbids recorded
   base commits, so the report's recorded main head is the only durable anchor
   — which is why the integration report gains a second machine line.

5. **One journal entry per cycle** (§3.3), even when the merge-resolver ran in
   the same decision cycle: one combined entry covering the resolution and the
   decision.

6. **Post-merge write failures are reported, never parked.** A `tsf:needs-human`
   label on a **closed** issue is invisible to the open-only scan (§5.1, §9.4),
   so parking there loses the ticket. The failure is named prominently in the
   closing report instead.

7. **The decision entry names the logic head**; the merge cycle identifies the
   decided PR head as **the commit that introduced the decision entry**, which
   is the commit the required check actually ran on. It is derived, not
   recorded (§3.5: no base commit is recorded anywhere).

8. **A logic-changing resolution routes through `tsf:verify` first**, then to
   `tsf:needs-review` — it advances the logic head and starts CI, so it is
   re-gated exactly as §16.40 requires for the CI-red path.

9. **The dossier addendum reuses** `references/templates/dossier.md:114-148`,
   extended with a step-4 refusal case. No new template file.

10. **The bare repository object is never read.** Post-merge branch handling
    uses the race-free sequence (read the ref, delete if present, accept both
    204 and "Reference does not exist") and never reads
    `delete_branch_on_merge`.

11. **The missing tags are backfilled** and CLAUDE.md gains a rule that makes
    tagging part of the release, so it stops being forgotten.

### Clarification on decision 5

Decision 5 fixes the journal at one entry and the **issue** at one comment per
cycle. The integration gate's **one-line PR comment** is additional and is not
that comment: §7 already requires every gate report to be summarized in a
one-line PR comment, and §3.4 keeps the two channels separate (the issue is the
conversation channel; the PR carries only the dossier, the gates' one-liners
and the human's review). So a decision cycle posts one issue comment — the
resolver's when it ran, otherwise a short dispatcher-composed outcome line —
plus the gate's one-liner on the PR when the gate ran. The **merge cycle posts
nothing at all**: §3.3 and §9.3 step 5 make it write-free, and the merge is
visible on the PR and the issue by itself.

### Deviations from DESIGN.md (surfaced, not silently made)

1. **`landing_attempt_bound`** is an addition — §9.3 bounds nothing here
   (decision 3).
2. **Restarts are named in the closing report** — §9.3 says "silently". No
   comment and no label change is made, so the *GitHub-visible* silence the
   design wanted is preserved; only the runner's report changes (decision 3).
3. **The `Tsf-Resolution` commit trailer** is an addition — §3.5 defines the
   exclusion but names no mechanism (decision 2).
4. **The integration report carries three machine lines**, not two — `head:`,
   `main-head:`, `verdict:` — because §16.46's re-run rule needs the recorded
   main head that §7's two-line contract cannot carry (decision 4).
5. **The integration gate's verdict vocabulary is `safe` / `risk`**, not
   `pass` / `fail`. §7 specifies safe/risk for gate 4 while `report.md`
   specifies pass/fail generally; mapping risk onto fail would be wrong,
   because risk routes to `tsf:needs-review`, not into fix mode.
6. **Post-merge write failures are reported rather than parked** — §10's
   retry-then-park would park a closed issue (decision 6).

### Precondition

None beyond slice 2, which is complete and released at `0.2.0`.

---

## Phase 1: The landing's REST calls

### Overview

Every GitHub operation the landing needs, added to the two REST helpers. This
phase is fully testable against a scratch GitHub repository and, for the
failure paths, against a fake `gh` on `PATH`.

### Changes Required:

#### 1. `gh-write.sh` — four new arms

**File**: `plugins/tsf/scripts/gh-write.sh`
**Changes**: add `update-branch`, `merge` and `ref-delete` subcommands, and a
`--clear` mode on the existing `labels` arm. Each needs its block in the header
table, its `usage()` line, its validation arm, and its `case` arm — the four
places every existing subcommand touches.

```
# update-branch --issue is not used; the PR number is explicit
gh-write.sh update-branch --repo O/R --as factory --credential env|proxy \
    --pr N --expected-head SHA

    PUT repos/O/R/pulls/N/update-branch with expected_head_sha (full 40 chars;
    a short SHA is rejected 422). Prints:
      result: synced       202 — the server merged the base branch in
      result: up-to-date   422 whose message says there are no new commits
      result: conflict     422 whose message names a merge conflict
      result: head-moved   422 whose message names an expected-head mismatch
      result: rejected | denied | failed | no-credential
    synced also prints  previous_head: <sha>
    up-to-date, conflict and head-moved are ROUTINE outcomes: they are not
    retried and never park (DESIGN.md §9.3, §16.46).
    An unrecognized 422 prints result: failed with the body in detail:, so an
    unknown message is never silently read as one of the three above.

gh-write.sh merge --repo O/R --as factory --credential env|proxy \
    --pr N --sha SHA --title T --message-file F

    PUT repos/O/R/pulls/N/merge with merge_method=squash, commit_title,
    commit_message and sha. --sha is MANDATORY (a merge without the head
    guard could merge a commit nobody reviewed). Prints:
      result: merged     200 — also merge_sha: <sha>  merged: true
      result: blocked    405 — also reason: <the body's message, one line>
      result: head-moved 409 — the sha guard fired
      result: rejected | denied | failed | no-credential
    blocked and head-moved are ROUTINE.

gh-write.sh ref-delete --repo O/R --as factory --credential env|proxy \
    --branch B

    DELETE repos/O/R/git/refs/heads/B. Prints:
      result: deleted   204
      result: absent    404, or 422 whose message says the reference does
                        not exist
      result: rejected | denied | failed | no-credential
    absent is a SUCCESS outcome, not a failure: the repository setting or a
    concurrent delete got there first.

gh-write.sh labels --repo … --issue N --clear

    Mutually exclusive with --set; exactly one of the two is required. Builds
    the same full label set as --set but WITHOUT appending a state label:
    every non-tsf:* label, plus tsf:priority when present. Read-back and the
    mismatch comparison are unchanged. Prints previous: and labels: as today.
```

#### 2. `gh-read.sh` — the single-PR read

**File**: `plugins/tsf/scripts/gh-read.sh`
**Changes**: a new `pr-state` subcommand. The existing `pr` arm reads the list
endpoint and must stay as it is — the dossier and row 9 depend on it.

```
gh-read.sh pr-state --repo O/R --as factory --credential env|proxy --pr N

    GET repos/O/R/pulls/N (the single-PR endpoint; the list endpoint's
    objects carry no mergeable fields). Prints:
      number:           N
      state:            open | closed
      merged:           yes | no
      head:             <sha>
      base:             <ref>
      mergeable:        true | false | unknown
      mergeable_state:  clean | dirty | behind | blocked | unstable |
                        draft | has_hooks | unknown
      title:            <one line>
      result: ok | failed | rejected | denied | no-credential

    mergeable is computed asynchronously and is null until GitHub's background
    job finishes; a push or an update-branch resets it. The script therefore
    re-reads up to 3 times, 2 seconds apart, while mergeable is null, and then
    reports mergeable: unknown / mergeable_state: unknown rather than blocking.
    The caller treats unknown as "not actionable this cycle".

    mergeable_state is an UNDOCUMENTED GitHub field (staff: "unofficial, in
    flux, may possibly go away"). It is a routing hint only; the merge call
    with --sha remains the authority on whether a merge happens. An
    unrecognized value is passed through verbatim.
```

### Success Criteria:

#### Automated Verification:

- [x] `bash -n` passes for both scripts; both stay executable and keep the byte-identical lib bootstrap
- [x] `grep -rnE 'gh (issue|pr|label|auth|run)\b' plugins/tsf/scripts/` still finds nothing (REST-only rule)
- [x] `grep -n 'repos/[^/]*/[^/]*\"' plugins/tsf/scripts/*.sh` finds no read of the bare repository object
- [x] Against a fake `gh` on `PATH`: a 202 yields `result: synced`; the three distinct 422 message shapes yield `up-to-date`, `conflict`, `head-moved`; an unrecognized 422 yields `failed`
- [x] Against a fake `gh`: a 403 with `X-GitHub-Request-Id` yields `rejected`, and a 403 without any GitHub header yields `denied`, for each new subcommand
- [x] Against a fake `gh`: `merge` yields `merged` on 200, `blocked` with a `reason:` line on 405, `head-moved` on 409
- [x] Against a fake `gh`: `ref-delete` yields `absent` for both 404 and a 422 "Reference does not exist"
- [x] `merge` without `--sha` exits 1 with a usage error
- [x] `labels --clear` and `labels --set` together exit 1; neither exits 1
- [x] Against a fake `gh`: `labels --clear` sends a label set containing the non-`tsf:*` labels and `tsf:priority`, and no `tsf:<state>`
- [x] Against a fake `gh` returning `mergeable: null` three times, `pr-state` prints `mergeable: unknown` and `result: ok`
- [x] Every new subcommand exits 0 for every reported outcome and 1 only for usage

#### Manual Verification:

- [ ] Against a scratch GitHub repository, each new subcommand performs its real REST call and reports the expected `result:` (subsumed by the end-to-end test)

### Implementation log

**Status**: ✅ Complete
**Base commit**: `73c8d91`
**Commit**: `9287d8c`
**Did**: `gh-write.sh` gained `update-branch`, `merge` and `ref-delete`, and a
`--clear` mode on `labels`; `gh-read.sh` gained `pr-state`. Each new subcommand
touches the four places every existing one does (header table, `usage()`,
validation arm, `case` arm).
**Issues**: none. Two details worth recording: `update-branch` validates the
40-character sha itself rather than letting GitHub's 422 swallow it among the
other three 422 meanings; and `ref-delete` reads the ref first, so "already
gone" is reported as `absent` from either a 404 on the read or a 422
"Reference does not exist" on the delete.
**Verification**: all twelve automated criteria pass against the fake `gh`
(scratchpad `fakebin/gh`, which emits a status line, optional
`x-github-request-id` headers, a blank line and a JSON body). The
`mergeable: null` poll took 4.077 s wall clock, confirming three reads and two
sleeps; a `null` first read followed by a populated one resolves to
`mergeable: true` / `mergeable_state: clean`.

---

## Phase 2: The logic head and the main delta

### Overview

`diff.sh` gains the two derivations the landing needs, and `logic-head` finally
implements the half of §3.5 that has had nothing to exclude until now. This is
the highest-blast-radius change in the slice: `logic-head` feeds gate staleness
(row 8), approval validity (row 10) and the derived state for **every** ticket,
not only landing ones.

### Changes Required:

#### 1. `diff.sh logic-head` — exclude mechanical sync merges

**File**: `plugins/tsf/scripts/diff.sh`
**Changes**: replace the single `git rev-list -1` with a walk that skips
mechanical sync merges. Update the header comment at `:49-50`, which currently
says they do not exist yet.

```
logic-head  (unchanged CLI)

    Walk commits newest-first that touch a path outside thoughts/:
        git rev-list HEAD -- . ':(exclude)thoughts/'
    and skip a commit iff it is a MECHANICAL SYNC MERGE, i.e. it has two
    parents AND either
      (a) its committer is GitHub's web-flow — a server-made update-branch
          merge (verified 2026-09-19: committer GitHub <noreply@github.com>,
          author is the CALLING identity, so author must not be used), or
      (b) its commit message carries the trailer  Tsf-Resolution: mechanical
          — a merge-resolver resolution the agent classified mechanical.
    The first commit not skipped is the logic head.

    A resolution WITHOUT that trailer, or with  Tsf-Resolution: logic , is a
    logic head: it advances the head, invalidates a prior approval and makes
    the gate reports stale, which is exactly what §3.5 intends.

    Prints logic_head:, short:, result: ok | none | failed  (unchanged).
```

#### 2. `diff.sh main-delta` — the integration gate's second input

**File**: `plugins/tsf/scripts/diff.sh`
**Changes**: a new subcommand beside `pr-diff` and `files`.

```
diff.sh main-delta --base BASE (--from SHA | --approval SHA) [--out FILE]

    What the base branch gained since a point. Resolves BASE to origin/BASE
    when the remote-tracking ref exists, as pr-diff does.
      --from SHA      the start point directly (the main head a previous
                      integration report recorded)
      --approval SHA  first attempt: the start point is
                      git merge-base SHA origin/BASE
    Then:
      git diff <start>..<base ref> -- . ':(exclude)thoughts/'   -> OUT
      git diff <start>..<base ref> --stat -- . ':(exclude)thoughts/' -> OUT.stat
    Default OUT is .tsf-tmp/main-delta.patch (untracked, removed by the next
    prepare's git clean -fd, exactly like pr-diff.patch).
    Prints file:, stat:, main_head: (the base ref's sha), moved: yes|no,
    files:, lines:, result: ok | empty | failed.
    moved: no / result: empty means the base branch has not moved: the gate is
    skipped.
```

#### 3. `diff.sh decision-head` — which commit the decision named

**File**: `plugins/tsf/scripts/diff.sh`
**Changes**: a new subcommand. The dispatcher must not compose raw `git
rev-list` in prose (CLAUDE.md, TP-0034b's diff.sh rule), so this derivation
gets a subcommand of its own.

```
diff.sh decision-head --journal PATH

    git rev-list -1 HEAD -- PATH   — the newest commit touching the ticket's
    journal, which after a decision cycle IS the decision commit: the merge
    cycle writes nothing, so nothing newer can touch the journal.
    Prints:
      decision_head: <sha> | -
      pr_head:       <sha>        (HEAD, after prepare = the branch's tip)
      unchanged:     yes | no     (decision_head == pr_head)
      result: ok | none | failed
    This is how the merge cycle checks "the decided head is still the PR head"
    without any recorded SHA (§3.5: no base commit is recorded anywhere).
    unchanged: no means someone pushed after the decision — the decision is
    void and the landing restarts at the sync.
```

### Success Criteria:

#### Automated Verification:

- [x] `bash -n` passes; the script stays executable
- [x] Scratch repo: an ordinary code commit is the logic head; a later `thoughts/`-only commit does not become it (unchanged behaviour)
- [x] Scratch repo: a two-parent merge committed with `GIT_COMMITTER_NAME=GitHub GIT_COMMITTER_EMAIL=noreply@github.com` is skipped, and the code commit beneath it is the logic head
- [x] Scratch repo: a two-parent merge carrying `Tsf-Resolution: mechanical` is skipped
- [x] Scratch repo: a two-parent merge carrying `Tsf-Resolution: logic` is **not** skipped and becomes the logic head
- [x] Scratch repo: a two-parent merge with neither marker is **not** skipped (fail closed)
- [x] Scratch repo: an ordinary single-parent commit by any committer is never skipped
- [x] `main-delta --approval <sha>` on a branch whose base moved reports `moved: yes` and a patch containing no `thoughts/` path; with an unmoved base it reports `moved: no` and `result: empty`
- [x] `main-delta --from <sha>` reports the same `main_head:` as `--approval` when both resolve to the same start
- [x] `decision-head` reports `unchanged: yes` right after a journal commit, and `unchanged: no` after any later commit
- [x] `decision-head` on a branch with no journal reports `result: none`
- [x] Every subcommand exits 0 for reported outcomes, 1 for usage and non-repo

#### Manual Verification:

- [ ] ~~Against the real repository the spike used: `logic-head` skips the actual server-made sync commit `db28d9d`~~ — **not runnable**: the spike's branch was deleted, so that commit is no longer reachable in the clone (`git cat-file -e` fails). The property it would test — two parents plus committer `GitHub <noreply@github.com>` — is exactly what the spike recorded and what the scratch-repo case above reproduces with the same committer identity.

### Implementation log

**Status**: ✅ Complete
**Commit**: `27ce7a9`
**Did**: `logic-head` now implements §3.5's second half — it walks candidates
newest-first and skips a commit with two parents whose committer is GitHub's
web-flow, or which carries `Tsf-Resolution: mechanical`. `main-delta` and
`decision-head` were added.
**Issues**: **One real bug, caught by the test and worth recording.** The first
implementation walked `git rev-list HEAD -- . ':(exclude)thoughts/'`. A sync
merge makes the base branch's commits reachable from the ticket branch, so the
newest *main* commit became the logic head — which would have invalidated the
approval on **every** sync and defeated the exact purpose of excluding sync
merges. The walk is now `--first-parent`, and a comment in the script says why
that flag is load-bearing rather than an optimization. Nothing in the design or
the research predicted this; only running it did.
**Verification**: twelve automated criteria pass against two scratch
repositories. The five classification cases were each built as real git
history: a server-made merge (committer forced to `GitHub
<noreply@github.com>`), a `mechanical` resolution, a `logic` resolution, a
merge with no trailer, and a single-parent commit with GitHub's committer —
which is correctly *not* skipped, since the two-parent test comes first. One
test-harness artifact was diagnosed and dismissed: a scratch `git add .` had
committed `.tsf-tmp/` into the repo, so `main-delta` diffed its own output. In
a real clone that directory is untracked and `prepare`'s `git clean -fd`
removes it, which is what the shipped `pr-diff` already relies on.

---

## Phase 3: Contracts — templates, the trailer, and the landing bound

### Overview

Everything the agents and the dispatcher read, before either exists. Four
machine contracts change here, each governed by a CLAUDE.md same-commit rule.

### Changes Required:

#### 1. `report.md` — the integration report

**File**: `plugins/tsf/references/templates/report.md`
**Changes**: the machine-line section gains the integration gate's three-line
form and its verdict vocabulary; the naming section gains `integration-<n>.md`.

```
The three post-implement gates keep the two-line block, unchanged:
    head: <logic head sha>
    verdict: pass | fail

The integration gate's block is three lines, in this order:
    head: <logic head sha>
    main-head: <the base branch head it judged>
    verdict: safe | risk

main-head is what a restarted landing compares against to decide whether the
gate must run again (§16.46). The gate writes both sha lines as "unknown" and
the dispatcher fills them in, as it already does for head:.

verdict: risk does NOT mean the same as fail — it never routes into fix mode;
it sends the ticket to tsf:needs-review with a dossier addendum.

Naming: integration reports are reports/integration-<n>.md, numbered per
LANDING ATTEMPT — not <episode>-<round>. Nothing is overwritten, so a
restarted landing keeps the earlier report and its recorded main head.
```

#### 2. `journal-entry.md` — the landing decision entry and the `step:` vocabulary

**File**: `plugins/tsf/references/templates/journal-entry.md`
**Changes**: add `landing` to the `step:` list on the entry heading (`Next
step` already has it); add the landing decision entry shape; state that the
merge cycle writes no entry.

```
step: […| dossier | review | landing]

The landing decision entry (written by the dispatcher from the decision
cycle's outcome; when the merge-resolver ran, this ONE entry covers both the
resolution and the decision — §3.3, one entry per cycle):

## Cycle [now] — step: landing
- Outcome: [synced (up to date | server-side merge | resolved mechanically | resolved with a logic change)]; [integration gate safe | gate skipped, main had not moved | gate risk]; merge when CI on head [sha] is green
- Questions asked: none
- Commits: [the decision commit and, when it ran, the resolution commit]
- Label: tsf:landing
- Attempt: [n]
- Next step: landing

The `- Attempt: [n]` line is the landing attempt counter (see below). The head
named in the Outcome is the LOGIC head; the commit the required check ran on is
the commit that introduces this very entry, which the merge cycle derives with
diff.sh decision-head — it cannot be named here, because it does not exist yet.

THE MERGE CYCLE WRITES NO JOURNAL ENTRY AT ALL (§3.3, §9.3 step 5): a push at
that point would move the PR head past the commit CI checked and the merge
would be refused. The merge is visible on the pull request and the issue.

## The attempt line

A landing ATTEMPT is one decision cycle. The attempt number is the count of
`step: landing` entries written since the ticket most recently entered
tsf:landing — i.e. since the newest `step: review` entry whose `- Label:` is
tsf:landing — plus one. Counting from the journal rather than from
integration-<n>.md filenames is deliberate: the gate does not run on every
attempt (it is skipped when the base branch has not moved), so filenames would
undercount. Bound: landing_attempt_bound from the config.
```

#### 3. `dossier.md` — the step-4 refusal addendum

**File**: `plugins/tsf/references/templates/dossier.md`
**Changes**: extend the existing addendum section (`:114-148`) with the
landing's refusal case. No new file.

```
Add to the addendum's causes: a landing that could not be decided (§9.3
step 4). Such an addendum states exactly what was decided and why, using the
cause that applies:
  - the conflict resolution changed behaviour (Tsf-Resolution: logic), so the
    approval no longer covers the code;
  - the integration gate returned risk, with its concrete description;
  - the approving review is behind the logic head.
Its closing line stays the fixed re-review copy already in the template.
```

#### 4. `result-block.md` — the resolver's outcomes

**File**: `plugins/tsf/references/templates/result-block.md`
**Changes**: add `merge-resolver` to the `step:` enum and add its rows to the
allowed-outcomes table. It returns the standard **three** fences (it leaves no
report file of its own; the integration report is the gate's).

```
step: [… | dossier | merge-resolver]
outcome: continued  -> the merge is resolved; next-label: tsf:landing,
                       next-step: landing
outcome: blocked    -> unresolvable; next-label: tsf:needs-human,
                       next-step: landing. The comment states the CONCRETE
                       decision a human must take — never a bare "this does
                       not merge".
The resolver's classification does not travel in the result block: it is a
commit trailer on the resolution commit (below), because diff.sh logic-head
must read it from git long after this conversation is gone.
```

#### 5. The `Tsf-Resolution` trailer — a new machine contract

**File**: `plugins/tsf/references/templates/result-block.md` (a short section)
**Changes**: define the trailer once, where both the resolver and `diff.sh`
can be pointed at it.

```
A merge-resolver resolution commit MUST carry exactly one trailer line:
    Tsf-Resolution: mechanical
or  Tsf-Resolution: logic
as the last line of the commit message, after a blank line.
mechanical = independent hunks, imports, lockfiles, formatting, renames.
logic      = a choice between behaviours, or adapting the PR to a contract the
             base branch changed.
diff.sh logic-head skips a mechanical resolution and does not skip a logic one.
A resolution commit WITHOUT the trailer is treated as logic (fail closed): the
approval is invalidated and the human is asked again, which is the safe error.
```

#### 6. `config.md` and `/tsf:init`'s upgrade list

**File**: `plugins/tsf/templates/tsf/config.md`, `plugins/tsf/commands/init.md`
**Changes**: a third constant, and the matching Idempotency entry (the CLAUDE.md
rule: a tsf version that changes what `config.md` must contain extends init's
upgrade list in the same commit).

```
## Constants
- **verify_fix_bound:** 3   [verification fix attempts per verification episode]
- **gate_fix_bound:** 3     [gate fix rounds per verification episode]
- **landing_attempt_bound:** 3   [landing attempts before parking; one attempt
  is one decision cycle, and a restart happens when the base branch moves
  before the merge]

init.md Idempotency, 1.0.0 upgrade entry: "adds landing_attempt_bound (default
3) to ## Constants; a 0.x config without it is upgraded by appending the line."
```

### Success Criteria:

#### Automated Verification:

- [x] `grep -c 'integration-' plugins/tsf/references/templates/report.md` ≥ 1 and the three-line block appears verbatim
- [x] `grep -q 'safe | risk' plugins/tsf/references/templates/report.md`
- [x] `grep -q 'step: landing' plugins/tsf/references/templates/journal-entry.md` and the `step:` enum on the entry heading contains `landing`
- [x] `grep -q 'Attempt:' plugins/tsf/references/templates/journal-entry.md`
- [x] `grep -q 'Tsf-Resolution' plugins/tsf/references/templates/result-block.md` and both values are defined
- [x] `grep -q 'landing_attempt_bound' plugins/tsf/templates/tsf/config.md` and `plugins/tsf/commands/init.md`
- [x] Each edited template still opens with its HTML-comment header naming the CLAUDE.md rule that governs it
- [x] No template contains an angle bracket inside a fenced block that a result block would carry
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] Read `report.md` and `journal-entry.md` end to end as an agent would, confirming the new blocks are unambiguous without the surrounding conversation

### Implementation log

**Status**: ✅ Complete
**Commit**: `d9245d4`
**Did**: `report.md` gained the integration gate's three machine lines, its
`safe`/`risk` vocabulary, its `integration-<attempt>.md` naming and its own
skeleton; `journal-entry.md` gained `landing` in the `step:` enum, the landing
decision entry, the attempt line and the statement that the merge cycle writes
no entry; `result-block.md` gained the `merge-resolver` row and the
`Tsf-Resolution` trailer section; `dossier.md`'s addendum gained the landing
refusal with its three causes; `config.md` gained `landing_attempt_bound` and
`init.md`'s upgrade list gained its `1.0.0` entry (plus a `0.2.0` line that was
missing).
**Issues**: two contracts needed widening beyond the plan's list, both found by
re-reading the files rather than by a test: `result-block.md`'s `next-step` and
`next-label` enums did not contain `landing` / `tsf:landing`, so a
merge-resolver return would have been rejected as invalid by parsing rule 4;
and the same file's `step:` enum needed `merge-resolver`. The plan named the
outcomes table but not these three enum lines.
**Verification**: nine automated criteria pass; `claude plugin validate
./plugins/tsf` passes. The angle-bracket check was run by extracting every
fenced block from `journal-entry.md` and `result-block.md` and grepping for
`<` or `>` — none, so nothing the harness would escape travels in a result
block.

---

## Phase 4: The two agents

### Overview

`tsf:merge-resolver` (a worker) and `tsf:integration` (gate 4). Both follow the
house patterns exactly: the worker's `tools: Read, Write, Edit, Grep, Glob,
Bash` without `Agent`, the gate's `tools: Read, Grep, Glob` with the three-part
constraint envelope, both descriptions opening "Internal to `/tsf:cycle` — not
for direct use", both pinned to a model alias.

### Changes Required:

#### 1. `tsf:merge-resolver`

**File**: `plugins/tsf/agents/merge-resolver.md` (new)
**Changes**: a worker agent modelled on `implement.md`.

```
---
name: merge-resolver
description: Internal to `/tsf:cycle` — not for direct use. Resolves a conflict
  between an approved pull request branch and the base branch in the factory's
  clone, classifying the resolution mechanical or logic. Returns a result block.
tools: Read, Write, Edit, Grep, Glob, Bash
model: opus
---

Sections, in the worker order: preamble; ## CRITICAL: (the standard no-GitHub
bullets — no push, no gh, no labels, no comments, no other agents); ## What you
receive; ## Project context; ## Process; ## Commit rules; ## Return; ## What
NOT to Do; ## REMEMBER:.

## What you receive
  ticket:, branch:, base-branch:, repo:, templates:, and
  main-delta:   the path of the base branch's delta (diff.sh main-delta)
  pr-diff:      the path of the pull request's own diff
  The clone is already on the ticket branch and the server-side sync has
  FAILED, so the branch is untouched.

## Process
  1. git merge origin/<base-branch> in the clone, and resolve every conflicted
     file by editing it — never by taking one side wholesale without reading
     both.
  2. Classify the WHOLE resolution:
       mechanical — independent hunks, imports, lockfiles, formatting, renames
       logic      — you had to choose between behaviours, or adapt this branch
                    to an API or contract the base branch changed
     One logic hunk makes the whole resolution logic.
  3. If you cannot resolve it, git merge --abort and return blocked — with the
     CONCRETE decision a human must take, never a bare "this does not merge".
  4. Do not run the project's verification: the dispatcher's next cycles do
     that on the real combination.

## Commit rules
  - Commit the merge with the project's commit convention, scope GH-<n>.
  - The message MUST end with the trailer  Tsf-Resolution: mechanical  or
    Tsf-Resolution: logic  (result-block.md defines it). Omitting it is an
    invalid return: logic-head then reads the resolution as logic and the
    human is asked to approve again for nothing.
  - Never --no-verify, never amend, never push.
```

#### 2. `tsf:integration`

**File**: `plugins/tsf/agents/integration.md` (new)
**Changes**: gate 4, modelled on `spec-coverage.md`.

```
---
name: integration
description: Internal to `/tsf:cycle` — not for direct use. Judges whether an
  approved pull request and the changes the base branch took since its approval
  can break each other in ways the tests would not catch. Receives only the two
  diff paths and the spec text.
tools: Read, Grep, Glob
model: opus
---

## What you receive
  - the PR diff's path and its --stat path
  - the MAIN DELTA's path: what the base branch gained since this pull
    request was approved (or since the last integration report)
  - the spec's text, verbatim

  Starvation paragraph, house shape: "You do NOT receive — and must NOT seek
  out — the plan, the research, the journal, any other gate's report, or the
  reasoning that produced the code." + why (you judge a COMBINATION; the
  authors of neither side saw the other) + "You MAY open the post-change source
  files in the clone, which holds the merged head" + "You may NOT open anything
  under thoughts/ other than the two diff files you were given."

## The question
  Can these two changes break each other in ways the tests would not catch? The
  categories §7 names: a changed contract the pull request calls, migration
  ordering, shared configuration, duplicated behaviour.

## Verdicts
  safe — no concrete interaction found.
  risk — a concrete interaction, described concretely: what in the delta, what
         in the pull request, and what breaks.
  Tie-break: when you cannot name the two specific places that interact and
  what goes wrong between them, the verdict is safe. A risk verdict costs the
  human a review round, so it must be earned — but a missed interaction is
  what this gate exists to catch, so do not talk yourself out of one you can
  name.

## Emit only this
  Read report.md now — in full — and emit the three machine lines (head:
  unknown, main-head: unknown, verdict:), the roll-up and one row per finding.
  With no findings: verdict: safe, an **Overall:** line saying so, empty table.
```

### Success Criteria:

#### Automated Verification:

- [x] Both files exist and `claude plugin validate ./plugins/tsf` passes
- [x] `grep -l 'Internal to `/tsf:cycle` — not for direct use' plugins/tsf/agents/*.md | wc -l` equals the number of agents (**12**, not 13 as this criterion first said — 8 workers + 4 gates)
- [x] `integration.md` has `tools: Read, Grep, Glob` — no `Bash`, no `Write`, no `Agent`
- [x] `merge-resolver.md` has `tools: Read, Write, Edit, Grep, Glob, Bash` — no `Agent`
- [x] Neither agent's body contains `gh `, `git push`, or `--no-verify` except as a prohibition
- [x] Both carry a `model:` alias (never `inherit`, never a model ID)
- [x] `integration.md` contains all three of `## CRITICAL:`, `## What NOT to Do`, `## REMEMBER:`
- [x] `grep -q 'Tsf-Resolution' plugins/tsf/agents/merge-resolver.md`
- [x] Both read their template at the point of use with the `templates:` fallback

#### Manual Verification:

- [ ] A real dispatch of each agent resolves its `model:` pin as intended, confirmed in the subagent transcript's `message.model` (TP-0029's runbook)
- [ ] The merge-resolver, given a genuine mechanical conflict, resolves and commits it with the correct trailer
- [ ] The integration gate, given a delta that changes a function the PR calls, returns `risk` naming both places

### Implementation log

**Status**: ✅ Complete
**Commit**: `38da762`
**Did**: added `plugins/tsf/agents/merge-resolver.md` (worker, `model: opus`,
the standard no-GitHub `## CRITICAL:` bullets, the trailer in its commit rules)
and `plugins/tsf/agents/integration.md` (gate 4, `tools: Read, Grep, Glob`,
the three-part envelope, the house starvation paragraph, `safe`/`risk`).
**Issues**: **a DESIGN.md discrepancy surfaced and corrected.** §11.1's worker
table never listed `tsf:manual-verify`, which slice 2 shipped, so §12's
"7 workers + 4 gates" and §11.4's "eleven short descriptions" had been
undercounts since `0.2.0`. With merge-resolver added the shipped roster is
**8 workers + 4 gates = 12**. The table gained the missing row and both counts
were corrected — arithmetic and an omission, not a design change, but it does
touch the binding document and is called out here for that reason. This
slice's own plan repeated the wrong number (13) in a criterion; that is
corrected above too.
**Verification**: nine automated criteria pass; `claude plugin validate
./plugins/tsf` passes. The `gh`/`git push`/`--no-verify` grep returns exactly
one line, the resolver's own prohibition.

---

## Phase 5: The dispatcher — row 12 and the landing's two cycles

### Overview

The orchestration: the pick order's landing tier, one landing in flight, row
12's five steps across two cycles, the write phase's landing variants, and the
closing report's new vocabulary. Detail lives in the references; `cycle.md`
gains only what the budget allows.

### Changes Required:

#### 1. `cycle.md` — actionability, the pick, and the removal of the deferral

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: `tsf:landing` becomes actionable; the pick gains the landing tier;
Step 5's re-pick yield and Important Rule 4 lose their landing wording; the
`allowed-tools` frontmatter is unchanged (the new script calls are covered by
the existing `gh-read.sh` / `gh-write.sh` / `diff.sh` grants).

```
Actionable gains:
  - tsf:landing, but only the ONE landing in flight (§5.2, §9.3). A landing
    ticket is in flight when its journal's last entry is step: landing; every
    OTHER tsf:landing ticket is not actionable while one is in flight.
  - the in-flight landing itself is not actionable while CI on its decided head
    is still pending: the pick moves on to non-landing work and the report
    names the pending head.

Pick order becomes (§5.2):
  1. the landing in flight, when actionable
  2. then other tsf:landing tickets, oldest approval first — at most one
     becomes the landing in flight
  3. then in-flight non-landing tickets
  4. then tsf:priority, then oldest created

Step 5's re-pick yield stays (it is the cycle's only backtrack) but its reason
changes from "landing is a later slice" to "another landing is in flight".

Important Rule 4 becomes: there are no later-slice states; every tsf:* state
label has a row.
```

#### 2. `cycle-dispatch.md` — row 12

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: widen the readable `Next step` set; replace the blanket landing
re-pick rule; add row 12 in the row-8 style; extend the counters section.

```
Derived state: a readable Next step becomes the full closed vocabulary of
journal-entry.md (triage | research | plan | implement | verify | gates |
dossier | review | landing); anything else is a mismatch.

**Row 12 — `tsf:landing`.** Two cycles. Which one this is: read the journal's
last entry.

- Last entry is NOT step: landing -> this is the DECISION cycle.
  1. Sync. gh-write.sh update-branch --pr <n> --expected-head <pr_head>.
     - synced -> run the project's prepare again so the clone holds the merged
       head (§16.39), then continue.
     - up-to-date -> continue; nothing moved.
     - head-moved -> a human pushed; re-read the PR and restart this cycle's
       step 1 once, then continue or end the cycle.
     - conflict -> dispatch **tsf:merge-resolver** with main-delta: and
       pr-diff:. blocked -> park tsf:needs-human with its comment. continued ->
       the resolution is committed locally; it is pushed in the write phase.
       Do NOT run prepare after the resolver (it would discard the merge).
     - rejected | denied | failed | no-credential -> park (§10).
  2. Integration gate. diff.sh main-delta --base <base> --from <the main-head
     of the newest reports/integration-*.md> or, when there is none,
     --approval <the approving review's commit_id>.
     moved: no -> skip the gate, and say so in the journal.
     moved: yes -> dispatch **tsf:integration** (foreground, alone) with the
     two diff paths and the spec's text. Write its report to
     reports/integration-<attempt>.md, filling head: and main-head:.
  3. Decide. The merge is decided only when ALL of:
       - the sync ended synced or up-to-date (the branch is up to date);
       - no resolution ran, or it was classified mechanical;
       - the gate returned safe, or was skipped;
       - the latest approving review's commit_id is at or after the logic head
         (diff.sh ancestor --commit <logic head> --of <review_ref>).
     Decided -> the write phase's decision variant: the landing decision entry
     with its Attempt line, committed WITH the integration report, pushed; the
     label stays tsf:landing; one issue comment; the gate's one-liner on the PR
     when it ran. The cycle then ENDS — CI must run on the decision commit.
     Not decided -> a dossier addendum naming the cause (logic resolution, gate
     risk, or stale approval) and the label tsf:needs-review.
     A logic-classified resolution additionally goes to **tsf:verify** first as
     a NEW EPISODE (§16.40, decision 8): it advanced the logic head, so the
     gates re-run and a dossier addendum precedes the next review.
  4. Attempt bound. The attempt number is the journal-derived count
     (journal-entry.md). If it would exceed landing_attempt_bound, park
     tsf:needs-human saying the base branch moved N times during landing and
     the factory cannot converge.

- Last entry IS step: landing -> this is the MERGE cycle. IT WRITES NOTHING TO
  THE REPOSITORY AND POSTS NO COMMENT.
  1. diff.sh decision-head --journal thoughts/factory/GH-<n>/journal.md.
     unchanged: no -> a human pushed; the decision is void; restart at the
     decision cycle's step 1 silently (count the attempt).
  2. The scan's ci: for the decided head. pending -> not actionable; the report
     names the head. failure -> the ticket leaves landing for **tsf:verify** as
     a NEW EPISODE (§6.7, §9.3 step 3): verify-fix, the gates on the new logic
     head, a dossier addendum, tsf:needs-review, re-approval through row 10,
     and the landing restarts at the sync.
  3. gh-read.sh pr-state --pr <n>.
       behind  -> main moved since the decision; the decision is void; restart
                  at the decision cycle's step 1 SILENTLY (count the attempt).
                  This is ROUTINE — never §10's retry-then-park.
       clean   -> merge.
       unknown -> not actionable this cycle; report and move on.
       dirty | blocked | anything else -> restart at step 1; a second
                  consecutive non-clean state of the same value parks
                  tsf:needs-human with the value.
  4. Merge. gh-write.sh merge --pr <n> --sha <decided head> --title <the PR's
     title> --message-file <the closing keyword body>.
       merged     -> continue to step 5.
       blocked    -> report the reason: line and end the cycle; the next cycle
                     re-evaluates. Never retry in-cycle.
       head-moved -> the decision is void; restart at step 1.
  5. After the merge — GitHub writes only (§3.2, §9.4):
       a. gh-write.sh labels --issue <n> --clear  (the closed issue keeps no
          state label).
       b. gh-read.sh branch --branch <branch>: exists: no -> done. exists: yes
          -> gh-write.sh ref-delete --branch <branch>; deleted and absent are
          both success.
     NEVER read the bare repository object to learn delete_branch_on_merge
     (proxy-denied, verified 2026-09-19).
     A failure in a or b is REPORTED, never parked (decision 6): a
     tsf:needs-human label on a closed issue is invisible to the open-only
     scan. Name the failed operation and its detail: prominently in the
     closing report.

Counters: add the landing attempt, derived from the journal per
journal-entry.md, bounded by landing_attempt_bound.
```

#### 3. `cycle-write-phase.md` — the landing variants

**File**: `plugins/tsf/references/cycle-write-phase.md`
**Changes**: two variants beside the existing PR-opening and gate-cycle ones.

```
The landing decision cycle:
  - When the resolver ran, git add the resolved files and its commit are
    already local — push them with the journal commit.
  - Write reports/integration-<attempt>.md when the gate ran, filling head:
    and main-head:; git add it WITH journal.md; one commit
    (docs(GH-<n>): landing decision, attempt <n>); push; marker.
  - One issue comment: the resolver's tsf-comment when it ran, otherwise a
    short dispatcher-composed line naming the decided head.
  - The gate's one-line PR comment when the gate ran, a second apart.
  - The label is NOT changed: it stays tsf:landing.

The merge cycle:
  - NO journal entry, NO commit, NO push, NO marker update, NO comment. Its
    only writes are the merge, the label clear and the optional ref deletion,
    in that order, a second apart.
  - This is the second write-free path in this file; the first is "prepare
    failed", which is different: that one writes nothing because it CANNOT.
```

#### 4. `cycle-report.md` — the vocabulary

**File**: `plugins/tsf/references/cycle-report.md`
**Changes**: remove the slice-2 skip reason, add the landing's.

```
Skipped reasons: remove "landing not implemented in this slice"; add
  - "another landing is in flight"
  - "ci pending on <sha> (landing)"
Ticket line for a merge cycle that merged:
  GH-<n> — landing (tsf:landing -> none): merged as <sha>, branch deleted
Ticket line for a restart (decision 3 — restarts are VISIBLE here even though
they are silent on GitHub):
  GH-<n> — landing restarted (attempt <n> of <bound>): <why — the base branch
  moved | the head moved>
Writes line for the merge cycle: "merge <sha> · label cleared · branch deleted"
— or the failed operation with its detail:.
Suggested wait: a landing awaiting CI paces like row 7's — 5 minutes, naming
the pending head.
```

### Success Criteria:

#### Automated Verification:

- [x] `wc -c plugins/tsf/commands/cycle.md` ≤ 18000 and `wc -l` ≤ 230 (the compaction budget) — 12388 bytes, 227 lines
- [x] `cycle.md` still carries no `disable-model-invocation` and no `model:`; `## Invariants` still precedes `## Project context`
- [x] `cycle.md`'s `allowed-tools` still grants neither `gh` nor `git push`
- [x] `grep -rq 'not implemented in this slice' plugins/tsf/` finds nothing — except `README.md`, which is Phase 6's
- [x] `grep -c '^\*\*Row ' plugins/tsf/references/cycle-dispatch.md` ≥ 13 (row 12 present) — 13
- [x] `grep -q 'landing_attempt_bound' plugins/tsf/references/cycle-dispatch.md`
- [x] `grep -q 'decision-head' plugins/tsf/references/cycle-dispatch.md`
- [x] The merge-cycle section of `cycle-write-phase.md` states no journal, no commit, no push and no comment
- [x] `claude plugin validate ./plugins/tsf` and `claude plugin validate .` pass

#### Manual Verification:

- [ ] End-to-end (see Testing Strategy): two approved PRs land, each across a decision and a merge cycle, the second not actionable while the first is in flight
- [ ] A deliberately conflicting third PR is resolved and classified by the merge-resolver, and `logic-head` treats a mechanical resolution as inert
- [ ] A landing whose base branch moves between the decision and the merge restarts silently on GitHub and visibly in the report
- [ ] Each landed issue is closed, carries no `tsf:*` state label, and is never picked again

### Implementation log

**Status**: ✅ Complete
**Commit**: `f0fb2a2`
**Did**: `cycle.md` — `tsf:landing` became actionable, the pick gained the
landing tier and the one-landing-in-flight rule, Important Rule 4 now states
the merge cycle's silence, and the integration gate's solo dispatch is
described. `cycle-dispatch.md` — row 12 in full (both cycles), the derived
state's `Next step` widened to the closed vocabulary, the re-pick given a real
definition, the landing attempt counter, and the payloads for the two new
agents. `cycle-write-phase.md` — the decision cycle's writes and the merge
cycle's non-writes. `cycle-report.md` — the landing's Ticket lines, the new
skip reasons, the integration verdict and the landing wait.
**Issues**: two corrections to the plan's own design, both found while writing:
(a) the plan detected "one landing in flight" from **the journal's last entry**,
which is impossible at pick time — Step 3 has only scan records and no branch
is checked out. The rule now orders `tsf:landing` tickets by `review_ref:`
(oldest approval first) and treats that first ticket as the in-flight one,
which is equivalent because an approval does not move while a landing runs, and
uses the scan's own `ci:` for the between-cycles wait. (b) With landing
implemented, the re-pick yield lost its only producer, so rather than leave a
mechanism with no caller it was re-specified and given row 12's
`mergeable: unknown` case.
**Verification**: nine automated criteria pass. `cycle.md` sits at 12,388 bytes
and 227 lines against the 18,000/230 budget — only three lines of headroom, so
row 12's detail went entirely into `cycle-dispatch.md` as intended. Both
`claude plugin validate` invocations pass. `cycle-report.md`'s header contract
note, which told editors to keep the slice-2 deferral string in step with
`cycle.md`, was retargeted at the skip-reason vocabulary.

---

## Phase 6: Docs, governance and the 1.0.0 release

### Overview

The consumer-facing and repository documentation, the CLAUDE.md rule sections
this slice's same-commit spans require, the deferred items, the version bump
and the tags.

### Changes Required:

#### 1. Root `README.md` and the marketplace metadata

**File**: `README.md`, `.claude-plugin/marketplace.json`
**Changes**: tsf joins the catalog. The intro sentence (`README.md:3-10`) names
four plugins; the `## Plugins` table gains a tsf row linking
`plugins/tsf/README.md`. The marketplace `metadata.description` gains tsf.

#### 2. `plugins/tsf/README.md`

**File**: `plugins/tsf/README.md`
**Changes**: replace the "Slice 2 (0.2.0) scope" box (`:18-30`) with the v1
story; drop the label table's *(slice 3)* marker (`:193`); add the landing
section and the ruleset settings.

```
New "From your approval to the merge" section:
  - the two-cycle landing and WHY (the required check is evaluated on the PR
    head, so the decision must be recorded and the merge cycle must write
    nothing);
  - one landing in flight, oldest approval first;
  - the sync is a server-side merge, never a rebase, never a force-push;
  - a conflict is resolved in the clone and classified; a logic-changing
    resolution costs a new verification episode and a second approval;
  - the integration gate runs only when the base branch moved;
  - landing_attempt_bound and what parking on it means;
  - after the merge: the issue closes, the state label is removed, the branch
    is deleted.

Ruleset settings the landing relies on (§9.2) — as a checklist:
  - a pull request is required, with ONE approving review;
  - the required status check with strict "up to date" ON;
  - "dismiss stale reviews on push" OFF and "require approval of the most
    recent reviewable push" OFF — otherwise the factory's own mechanical sync
    push dismisses the human's approval and the landing can never complete;
  - the factory identity on no bypass list;
  - the CI workflow must NOT path-filter thoughts/** — a filtered-out required
    check stays "expected" and blocks the merge forever, and the decision
    commit touches only thoughts/.

Troubleshooting gains: "A landing keeps restarting" — the base branch moves
faster than a landing window; and "the merge says blocked" with the reason:
line's meaning.
```

#### 3. `plugins/tsf/TODO.md` — two new deferred items

**File**: `plugins/tsf/TODO.md`
**Changes**: append two entries in the existing shape (what, why deferred, what
would close it, symptom).

```
1. "Reduce the CI runs a landing costs" (user decision, 2026-09-19). A landing
   costs up to two runs per attempt — the sync push and the decision push — and
   a restart repeats both. What would close it: a way to record the decision
   without moving the PR head (a check-suite-neutral commit, or holding the
   decision outside the branch), which the current "the journal is the state"
   model does not have. Symptom: CI minutes dominated by landings on an active
   base branch.
2. "Signed commits" — commits the factory creates through the contents API are
   unsigned (verified 2026-09-19), while its update-branch and merge commits
   are GitHub-signed. A project whose ruleset requires signed commits would
   reject the factory's own commits. What would close it: an init-time precheck
   for a signature requirement, and a documented refusal.
```

#### 4. `CLAUDE.md` — the slice's rule sections

**File**: `CLAUDE.md`
**Changes**: four new tsf sections in the established style (what the rule is,
why it is load-bearing, the same-commit span), plus one edit to Releasing.

```
a) "tsf: the landing is a decision cycle plus a write-free merge cycle" —
   why the split exists (the required check is evaluated on the PR head), that
   the merge cycle writes nothing at all, and the span: cycle.md,
   cycle-dispatch.md, cycle-write-phase.md, cycle-report.md, journal-entry.md.

b) "tsf: one landing in flight" — why (every landing makes the other approved
   PRs behind under the strict rule), how it is detected (the journal's last
   entry is step: landing), and the span: cycle.md's pick + cycle-dispatch.md
   row 12.

c) "tsf: the CI workflow must not path-filter thoughts/**" — a filtered-out
   required check stays "expected" and blocks the merge forever, and the
   decision commit touches only thoughts/. The span: init.md's ruleset
   checklist, plugins/tsf/README.md, DESIGN.md §9.2/§12.

d) "tsf: the logic head's mechanical-merge exclusion spans a script and a
   trailer" — authorship cannot discriminate (the sync commit's author is the
   calling identity); the discriminators are the web-flow committer and the
   Tsf-Resolution trailer; a resolution without the trailer is treated as
   logic. The span: diff.sh, merge-resolver.md, result-block.md — and note
   that logic-head feeds gate staleness and approval validity for EVERY
   ticket, so a change here is never landing-local.

e) Releasing gains: "Tagging is part of the release, not an afterthought: a
   version bump that is committed without its tag is an incomplete release.
   Run `claude plugin tag ./plugins/<name>` in the same session as the bump
   (it validates plugin.json against the marketplace entry and tags HEAD), and
   verify with `git tag --list '<name>--v*'` before calling the release done.
   To tag a release that was missed, the tag is created directly at its
   version-bump commit — `claude plugin tag` only ever tags HEAD."
```

#### 5. The version bump and the tags

**File**: `plugins/tsf/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Changes**: `0.2.0` → `1.0.0` in both, and both `description` fields lose
"Slice 2 … landing excepted" in favour of the v1 description.

Then the tags. `claude plugin tag` only tags HEAD, so the two missed ones are
created directly at their version-bump commits (verified: at each of those
commits `plugin.json` and the marketplace entry agree):

```
git tag tsf--v0.1.0 bf58f3c    # feat(TP-0034a): register the tsf plugin at 0.1.0
git tag tsf--v0.2.0 06c9390    # docs(TP-0034b): document tsf slice 2 and release 0.2.0
claude plugin tag ./plugins/tsf    # creates tsf--v1.0.0 at HEAD
```

Adjacent housekeeping, in the same phase: `tle--v1.0.0` is also missing and is
created at `2ef4201` (`feat(TP-0025): add the tle plugin manifest and
marketplace entry`). It is not part of this ticket's scope — drop it if you
would rather keep the commit clean.

### Success Criteria:

#### Automated Verification:

- [x] `grep -c tsf README.md` ≥ 2 (intro and table row) and the table links `plugins/tsf/README.md` — 3
- [x] `grep -q tsf .claude-plugin/marketplace.json` in `metadata.description`
- [x] `grep -rq 'slice 3\|Slice 2' plugins/tsf/README.md plugins/tsf/.claude-plugin/plugin.json` finds nothing
- [x] `jq -r .version plugins/tsf/.claude-plugin/plugin.json` is `1.0.0`, and the marketplace entry agrees
- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [x] `claude plugin tag ./plugins/tsf --dry-run` reports `tsf--v1.0.0`
- [x] `git tag --list 'tsf--v*'` lists `tsf--v0.1.0`, `tsf--v0.2.0`, `tsf--v1.0.0`
- [x] the backfilled tags sit at their release commits, and the manifest at each carries the matching version (verified with `git show <tag>:…/plugin.json`)
- [x] CLAUDE.md contains the four new section headings and the Releasing paragraph
- [x] `plugins/tsf/TODO.md` has **three** `##` entries (the existing one plus two — the criterion said five, which was simply wrong arithmetic)

#### Manual Verification:

- [ ] Read `plugins/tsf/README.md` end to end as a new consumer: the landing and the ruleset checklist are followable without DESIGN.md
- [ ] `/plugin marketplace update toby-plugins` in a scratch project offers 1.0.0

### Implementation log

**Status**: ✅ Complete
**Commit**: `4a9caf1` (docs and version); tags created separately, see below
**Did**: the root README and the marketplace metadata list tsf; the consumer
README lost its slice-2 scope box and gained the landing section, the ruleset
checklist and four troubleshooting entries; `TODO.md` gained the CI-cost and
signed-commits deferrals; `CLAUDE.md` gained this slice's four rule sections
and a Releasing paragraph making tagging part of the release; both manifests
went to `1.0.0` with new descriptions.
**Issues**: `claude plugin tag` can only tag **HEAD** — it validates
`plugin.json` against the marketplace entry, which at HEAD reads `1.0.0` — so
the two missed tsf tags could not be created with it. They were created
directly at their version-bump commits with `git tag -a … <sha>`, and each was
verified by reading `plugin.json` out of the tagged tree. Bare `git tag` also
failed with "no tag message?" (this repo forces annotated tags), so all three
backfills use `-m` in `claude plugin tag`'s own message format. `tle--v1.0.0`
was backfilled in the same pass — adjacent housekeeping, called out here
because it is outside this ticket's scope.
**Verification**: ten automated criteria pass; both `claude plugin validate`
invocations pass. Final tag list: `tce--v1.0.0`, `tce--v1.0.1`, `tce--v1.2.0`,
`tmt--v1.0.0`, `tle--v1.0.0`, `tsf--v0.1.0`, `tsf--v0.2.0`, `tsf--v1.0.0`.
Nothing was pushed — the human decides that.

---

## Testing Strategy

### Unit Tests:

There is no test runner in this repository. Per-script verification is by
`bash -n`, by direct invocation against a scratch git repository, and by a fake
`gh` first on `PATH` that answers with a status line, `X-GitHub-Request-Id`
headers and a JSON body — a **missing header block is how a proxy denial
looks**, which is what separates `denied` from `rejected`.

The fake-`gh` cases this slice needs, beyond slice 2's: the three distinct 422
message shapes on `update-branch`; an unrecognized 422; 405 with a rule-violation
body; 409; 204 and 422-"does not exist" on the ref delete; and a `mergeable:
null` response repeated three times.

The `diff.sh` cases need a scratch repository with a deliberately constructed
history: a two-parent merge committed with GitHub's committer identity, one
carrying each `Tsf-Resolution` value, and one carrying neither.

### Integration Tests:

`claude plugin validate .` plus `claude plugin validate ./plugins/tsf` after
every phase that touches a manifest, an agent or a command.

### Manual Testing Steps:

The end-to-end smoke test (ticket AC 6) needs the setup slices 1 and 2 also
deferred: a scratch project with a real GitHub repository, a second GitHub
account as the factory identity, the ruleset of §9.2, a factory clone, and the
contract scripts. It therefore runs at the first real factory setup and covers
slices 1–3 at once.

1. Two tickets reach `tsf:landing` with approving reviews.
2. One cycle lands the first: the decision cycle syncs, gates (or skips), and
   records; the closing report names the pending head; the second landing ticket
   is skipped as "another landing is in flight".
3. The merge cycle merges. The issue closes with no `tsf:*` state label, the
   branch is deleted, and neither is picked again.
4. The second landing then proceeds, and its sync is a real server-side merge
   because the first landing moved the base branch.
5. A third PR is made to conflict deliberately. The merge-resolver resolves and
   classifies it; with `Tsf-Resolution: mechanical`, `logic-head` is unmoved and
   the approval still counts; forced to a logic resolution, the ticket goes to
   `tsf:verify` as a new episode and comes back for a second approval.
6. Move the base branch between a decision and its merge cycle: the landing
   restarts silently on GitHub and visibly in the report, and the attempt
   counter advances.
7. Exhaust `landing_attempt_bound` and confirm the park names the cause.

## Performance Considerations

A landing costs up to two CI runs per attempt and at least two cycles. On a
base branch that moves often, restarts multiply that; `landing_attempt_bound`
caps the waste at three attempts, and `TODO.md` records the optimization.

`pr-state` polls up to three times at two-second intervals within one cycle —
the only in-cycle sleep in the plugin. The spike observed `mergeable` non-null
after a single poll, so this should almost never be reached.

## Migration Notes

`0.2.0` consumers upgrade with `/plugin marketplace update toby-plugins`.
`config.md` gains `landing_attempt_bound`, so `/tsf:init`'s Idempotency list
gains its first real upgrade entry: a `0.x` config without the constant is
upgraded by appending the line, and a project that never re-runs `/tsf:init`
falls back to the default of 3.

Tickets parked mid-slice-2 are unaffected: row 12 only fires on a label slice 2
set but never acted on, and a ticket sitting at `tsf:landing` from a slice-2
run is picked up correctly — its journal's last entry is a `step: review`
entry, so the dispatcher reads it as a fresh landing and starts at the decision
cycle.

## References

- Original ticket: `thoughts/shared/tickets/TP-0034c-tsf-landing-release.md` (see `## Implementation Closeout` at the end)
- Epic: `thoughts/shared/tickets/TP-0034-implement-tsf-plugin-v1.md`
- Research: `thoughts/shared/research/2026-09-18-TP-0034c-tsf-landing-release.md`
  (including the 2026-09-19 spike update)
- Design: `plugins/tsf/DESIGN.md` §3.2–3.5, §4 row 12, §5.2, §7 gate 4,
  §9.2–9.4, §10, §11, §12, §16.30, §16.40, §16.41, §16.43, §16.45, §16.46,
  §16.48
- Predecessor plans: `thoughts/shared/plans/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`,
  `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md`
- Row-authoring style to copy: `plugins/tsf/references/cycle-dispatch.md:142-157`
- Gate skeleton to copy: `plugins/tsf/agents/spec-coverage.md`
- Worker skeleton to copy: `plugins/tsf/agents/implement.md`

## Implementation Closeout

All six phases complete, one commit each, on base `73c8d91`:

| Phase | Commit | What |
|---|---|---|
| 1 | `9287d8c` | the landing's REST calls (`gh-write.sh`, `gh-read.sh`) |
| 2 | `27ce7a9` | the logic head's sync-merge exclusion, `main-delta`, `decision-head` |
| 3 | `d9245d4` | the machine contracts (report, journal, result block, dossier, config) |
| 4 | `38da762` | `tsf:merge-resolver` and `tsf:integration` |
| 5 | `f0fb2a2` | row 12 — the landing's two cycles |
| 6 | `4a9caf1` | docs, governance, `1.0.0` |

### Plan-compliance gate

**PASS on the first run** — 29 criteria, **26 met, 0 not met**, 3 "needs human
verification". Baseline `73c8d91` (`baseline.sh`: `source: recorded`), diff
`git diff 73c8d91 -- . ':(exclude)thoughts/'` — 22 files, 1,258 insertions,
112 deletions.

Of the three the gate could not judge, **two were executed in this session**
and are green; the checker has no shell, which is the only reason it could not
say so:

- *`claude plugin validate` passes for the marketplace and the plugin* —
  **verified**: all five targets pass (`.`, `./plugins/tce`, `./plugins/tmt`,
  `./plugins/tle`, `./plugins/tsf`).
- *`claude plugin tag ./plugins/tsf` creates `tsf--v1.0.0`* — **verified**: the
  tag exists at `4a9caf1`. The two missed tsf tags and `tle--v1.0.0` were
  backfilled at their own version-bump commits, each confirmed by reading
  `plugin.json` out of the tagged tree.

The third — the **end-to-end smoke test** — is a genuine escalation and is
**not** claimed here.

### Manual verification state

**Deferred to the first real factory setup** — the same decision slices 1 and 2
took, for the same reason: every remaining manual item needs a real GitHub
repository, a second GitHub account as the factory identity, the §9.2 ruleset,
a factory clone and the project's contract scripts. Slice 3's items subsume
slice 1's and slice 2's, so one setup discharges all three.

Outstanding, by phase: phase 1's real-REST check; phase 3's read-through of the
templates; phase 4's three (the model pins on a real dispatch, the resolver on
a real conflict, the integration gate on a real delta); phase 5's four landing
scenarios; phase 6's two.

One item is **not runnable as written** and is marked so in place: phase 2's
check against the spike's sync commit `db28d9d`, whose branch was deleted, so
the commit is unreachable. The scratch-repo case reproduces the property it
tested — two parents plus committer `GitHub <noreply@github.com>`.

### Deviations from DESIGN.md, and one correction to it

Six deviations were planned and made, each recorded under "Implementation
Approach": `landing_attempt_bound`; restarts visible in the closing report;
the `Tsf-Resolution` trailer; the integration report's third machine line; its
`safe`/`risk` vocabulary; and post-merge write failures being reported rather
than parked.

Two further corrections were made during implementation and are recorded in
their phases' logs: the `--first-parent` walk in `logic-head` (without it a
sync merge invalidates the approval it was supposed to preserve), and the
one-landing-in-flight rule being decided from the scan rather than the journal
(the journal is not readable at pick time).

**DESIGN.md itself was corrected**: §11.1's worker table never listed
`tsf:manual-verify`, which slice 2 shipped, so §12's "7 workers + 4 gates" and
§11.4's "eleven short descriptions" had been undercounts. The shipped roster is
**8 workers + 4 gates**.

### How this reached the main branch

Directly — this repository commits to `main` and uses no branching or PR
strategy (`CLAUDE.md` Conventions). Nothing was pushed; the tags are local
until the human pushes them.

### Ticket

TP-0034c → **Done**. The end-to-end smoke test is deferred to the first
full-factory run by explicit user decision (2026-09-20) — the same call slices
1 and 2 made. The epic TP-0034 is now eligible to close.

A suspicion worth carrying forward is recorded in the ticket's
`## Notes & Updates`: the first consumer's habit of a direct
`docs(...): record the merge reference` commit on `main` after every merge is
exactly what voids a landing decision, so landings there may restart routinely
and hit `landing_attempt_bound` on healthy pull requests. Check the "landing
restarted" lines in the cycle reports on the first real run.
