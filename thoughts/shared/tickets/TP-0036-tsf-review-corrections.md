# TP-0036: tsf — corrections from the post-1.0.0 real-world review

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-09-20
**Updated:** 2026-09-20

Follow-up to the epic TP-0034 (slices TP-0034a/b/c). Collects every correction
agreed in the review discussion of 2026-09-20 into one ticket, by explicit user
decision.

## Problem Statement

tsf 1.0.0 shipped without ever running end to end: all three slices deferred
their smoke test to the first real factory setup. A review of design, tickets
and implementation on 2026-09-20 — reading every file, plus a stub run of
`scan.sh` against a fake `gh` — found defects that stop or loop the factory on
**normal** paths (not edge cases), and several that stall it silently. None is
an architectural flaw; they are wiring between the slices that was never
exercised: the slice-1 resume and validation logic was never widened to the
states slices 2 and 3 added, the scan does not deliver what rows 10–12 consume,
and two read paths the state machine depends on do not exist.

## Desired Outcome

A factory that survives its first real tickets unattended: parked tickets
resume from every state, a rework round receives the review it must address and
does not livelock afterwards, a landing can decide and merge, CI waiting is
bounded and conflict-aware, slow contract scripts are not killed, bookkeeping
pushes do not burn CI minutes, implementation progress survives a crash, and
the gates receive machine-extracted criteria. Each correction below states the
finding, the agreed fix, and how "done" is observed.

## Corrections

The numbering is this ticket's own; "review #n" is the number used in the
review discussion.

### C1 — Contract scripts slower than two minutes are killed and read as red (review #2)

**Finding.** A Bash tool call times out after 120 s by default, 600 s at most
(`BASH_DEFAULT_TIMEOUT_MS`, `BASH_MAX_TIMEOUT_MS`). With
`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` — which the preflight requires — a
timed-out command is **killed**, not backgrounded (verified against the Claude
Code docs). The dispatcher runs the project's `verify` itself in every
`tsf:verify` cycle (`references/cycle-dispatch.md` row 6), and the agents run
`verify`, tests and `env_up`. A suite slower than two minutes therefore reads as
red, burns `verify_fix_bound` on a non-failure, and parks the ticket. Nothing in
`plugins/tsf` mentions a timeout.

**Agreed fix.** The factory session must run with both timeout variables
raised; `scripts/preflight.sh` checks them (a new runner check next to
`--foreground`) and the cycle refuses to run without them; the dispatcher and
the worker agents are told to pass the maximum timeout when they run a contract
script or the project's verification.

### C2 — A ticket parked `tsf:needs-human` cannot be resumed once it is past planning (review #3)

**Finding.** The README tells the human to swap `tsf:needs-human` for
`tsf:queued`. `references/cycle-dispatch.md` row 3 maps the journal's
`Next step` only for `triage`, `research` and `plan`; for `implement` it says
"re-pick" (line 118), which writes nothing and changes no label, so the ticket
is skipped forever. `verify`, `gates`, `dossier`, `review` and `landing` have no
mapping at all, and a `tsf:queued` ticket gets no pull-request data from the
scan (`scan.sh` probes only the five PR states). The "Validation" section has
the same slice-1 scope: a stale factory-side label is only corrected for
`tsf:research`/`tsf:plan` ("Cases in this slice"). Most human parks happen in
exactly the later states: exhausted bounds, environment failures, failed pushes,
CI-red-with-local-green, a blocked merge-resolver.

**Agreed fix.** Resume is a **pure label correction**: `tsf:queued` with a
journal maps the last entry's `Next step` to its label over the whole closed
vocabulary (`implement` → `tsf:implement`, `verify`/`gates` → `tsf:verify`,
`dossier` → `tsf:dossier`, `review` → `tsf:needs-review`, `landing` →
`tsf:landing`, plus the three existing ones), sets it, and ends the cycle — the
next scan then carries the right data. A resume into verification opens a **new
episode**, so an exhausted `verify_fix_bound`/`gate_fix_bound` does not re-park
the ticket on its first cycle. The stale-factory-label correction in
"Validation" is widened to every factory-side label.

### C3 — After every rework round the ticket is re-picked every cycle until the human reviews again (review #4)

**Finding (confirmed by a stub run).** After a rework the human's old
CHANGES_REQUESTED review is still the latest review. `commands/cycle.md` Step 3
treats `tsf:needs-review` with `review: approved | changes-requested` as
actionable without any recency test; row 10 then finds the review older than
the factory's last PR comment and says "ignore it, journal that". That is a
journal commit and a push — and a CI run — every cycle at the one-minute pace,
and because the ticket sorts as in-flight it starves every `tsf:queued` ticket
and every younger in-flight one. A stale approval (row 10, approval behind the
logic head) behaves the same. This is the normal path after *every* rework.

**Agreed fix.** Staleness is decided in `scripts/scan.sh`: when the latest
decisive review's `submitted_at` is not newer than the factory's last PR
comment's `created_at`, the record reports no review (both kinds). Row 10 keeps
its `diff.sh ancestor` check as the guard for approvals, and its stale outcome
becomes a silent skip (a re-pick) — never a journal entry.

### C4 — Rework never receives the review it must address (review #5) — IMPORTANT

**Finding.** Row 11 passes `review-comments:` "the review's body and its
comments, fetched with `gh-read.sh reviews` and `gh-read.sh pr-comments`".
`gh-read.sh reviews` prints only a commit id and a timestamp per reviewer;
`pr-comments` prints only the timestamp of the factory's own last comment; and
no tsf script reads a pull request's inline review comments
(`pulls/<n>/comments`) at all. The dispatcher may not call the API directly, so
`tsf:implement` in `mode: rework` gets an empty brief. The human's one feedback
channel on finished work does not reach the factory.

**Agreed fix.** A new `gh-read.sh` subcommand returns the latest
CHANGES_REQUESTED review — its body plus that review's inline comments with
file, line and the comment text — written to a file that the rework payload
passes **by path** (keeps the dispatcher's context free of content, invariant
3). Row 11, the spawn-payload list and `agents/implement.md` follow.

### C5 — The landing cannot reach a merge decision (review #6)

**Finding (confirmed by a stub run).** `scan.sh` reads reviews only for
`tsf:needs-review` and `tsf:rework` (the `case "$STATE"` at lines 161–198); a
`tsf:landing` record carries `review: skipped` and `review_ref: -`. But Step 3
orders landings "by `review_ref:`, oldest approval first" — a field that is
empty there and would be a commit sha, not a time, even when filled — and row 12
feeds `review_ref` to `diff.sh ancestor` (returns `unknown`, so "not decided")
and to `diff.sh main-delta --approval` (fails). The ticket bounces between
`tsf:needs-review` and `tsf:landing`, posting an addendum each round.

**Agreed fix.** The scan probes reviews for `tsf:landing` too and emits the
approval's **commit id and its `submitted_at` as separate fields**; Step 3
orders by the timestamp, row 10 and row 12 use the commit id. The record format
is a machine contract: `scan.sh`'s header, `cycle.md` Step 3 and
`cycle-dispatch.md` move together.

### C6 — A pull request that conflicts with the base branch waits for CI forever; "ci pending" has no bound (review #7)

**Finding (verified against GitHub's docs, raw source of "Events that trigger
workflows").** "Workflows will not run on `pull_request` activity if the pull
request has a merge conflict. The merge conflict must be resolved first." No
activity type is exempt, so a fix push to an open, conflicted PR starts nothing.
Zero check runs reads as `pending`, `pending` has no time bound, and conflicts
are only resolved at landing — after approval. With serial landings a ticket in
a fix round will routinely conflict with what just landed. Only `tsf:verify` can
stall this way (`tsf:needs-review` pushes nothing, `tsf:dossier` does not wait
on CI, landing resolves conflicts). Not documented, and therefore not to be
relied on alone: what the check-runs endpoint returns in that state, the values
of `mergeable_state` (GitHub staff call the field unofficial), and whether CI
restarts after the conflict is resolved. The REST field `mergeable` **is**
documented; `false` is the reliable conflict signal.

**Agreed fix — both parts.**
- **Conflict check.** When a `tsf:verify` ticket reports pending with zero
  check runs, the cycle reads the single pull request once and looks at
  `mergeable`. `false` → the same sync the landing uses: server-side
  update-branch first, `tsf:merge-resolver` on conflict. The resolution push
  restarts CI. The mechanical/logic classification works as today (a logic
  resolution moves the logic head and the gates re-run).
- **Age bound.** A new constant (proposed `ci_pending_bound`, default two
  hours) parks a ticket `tsf:needs-human`, with the reason, when CI on its head
  has been pending longer than that — measured from the head commit's date to
  the preflight's `now:`. This is the net under everything undocumented, and it
  also catches missing CI, path filters and stuck runners.

### C7 — CI state counts every check run on the commit (review #8)

**Finding.** `scan.sh` (lines 150–160) and `gh-read.sh checks` reduce **all**
check runs on the head: one failing optional check — a preview deploy, a
coverage bot — sends the ticket into verify-fix against something it cannot
fix. CI that reports through commit statuses is never seen. And zero check runs
cannot be told from "this repository has no CI" (`TODO.md`, first item).

**Agreed fix.** `.claude/tsf/config.md` gains the **required check names**; the
scan and `checks` evaluate only those. The value `none` means "this project has
no pull-request CI" and settles the TODO item "Detect that a repository has no
pull-request CI" (remove or rewrite it in the same commit). `/tsf:init` asks for
the names and its Idempotency upgrade list gains the entry.

### C8 — The server-side sync is asynchronous, but the clone is refreshed at once (review #10)

**Finding.** `gh-write.sh update-branch` returns `synced` on the 202 and says
"the head moves shortly"; row 12 step 1 then runs `prepare` immediately. If the
merge commit has not arrived, the decision commit is built on the old head, the
push is rejected as non-fast-forward, and the ticket parks.

**Agreed fix.** `update-branch` polls the pull request until its head differs
from `--expected-head` (bounded), and reports the **new head**; a head that
never moves is a distinct, reported outcome. `cycle-dispatch.md` row 12,
`cycle-write-phase.md` and the script header move together (the "dispatcher
owns every GitHub write" span).

### C9 — Every bookkeeping push starts a full CI run, and the next verify step waits for it (review #11)

**Finding.** Journal, report, dossier and decision commits touch only
`thoughts/`, yet each is a push to an open PR and starts the full suite —
roughly ten runs per ticket, not just the landing's two that `TODO.md` names —
and every `tsf:verify` step then waits for that run. Path filters and skip-CI
commit messages are not available: a required check that does not report stays
"expected" and blocks the merge, and for `pull_request` events path filters look
at the whole PR diff, not the single push.

**Agreed fix — a CI fast path the project installs, which init ships and the
user confirms.** Inside the job that provides the required check, before the
expensive steps: when the **push's own delta** (`before..after` of the
synchronize event) touches only `thoughts/`, the job **inherits the parent
commit's concluded result** for the required check:

- parent concluded **success** → report success at once;
- parent concluded **failure** → report failure at once (the code is still red;
  a full run would only say the same);
- anything else — cancelled, still running, missing — → run the full suite.

The third case is load-bearing: at landing the server's sync merge and the
factory's decision commit arrive as two pushes and the second cancels the
first's run, so without it a docs-only decision commit would report green on a
combination nobody tested. `/tsf:init` ships the snippet under
`templates/github/`, explains it, and **asks the user to confirm it is
installed** (it cannot verify a workflow's behaviour itself); the README and
the ruleset checklist say the same. Rewrite the TODO item "Reduce the CI runs a
landing costs" accordingly.

### C10 — Implementation is all or nothing per cycle (review #12)

**Finding.** `tsf:implement` builds every increment in one agent context and
nothing is pushed until it returns. A crash, a usage limit or a dead session
loses every increment at the next `prepare`, and a re-run in `mode: fresh` is
not told what is already built.

**Agreed fix.**
1. **Fresh mode runs in batches**, one batch per cycle, pushed at the end of
   the cycle. Batch size is a new constant (proposed `implement_batch`, default
   **3** increments).
2. **The pull request still opens only after the last batch** — exactly as
   today. With pull-request-triggered CI the intermediate pushes start nothing.
3. **Rework and fix mode stay one cycle each.**
4. **Progress lives in the journal**: each implement entry records which
   increments are done; `Next step` stays `implement` (label `tsf:implement`)
   until all are. Intermediate cycles post **no** issue comment; only the final
   one does.
5. **No-progress guard**: an implement cycle that returns without a newly done
   increment counts as `blocked` and parks the ticket. Derived from the journal
   alone.
6. **`/tsf:init`'s CI check warns** when the verification workflow also
   triggers on `push` to ticket branches (then every batch push would cost a
   run).
7. A crash that repeats on every cycle leaves no trace on disk and is **not**
   solved here: record it in `TODO.md`.

### C11 — The dispatcher must not read plan or spec, yet must extract criteria for the gates (review #13)

**Finding.** `cycle.md` invariant 3 forbids reading a plan's or spec's body;
`cycle-dispatch.md` row 8 and the spawn payload require "the plan's numbered
per-increment criteria including addenda, verbatim", the `**Manual**` items and
"the spec's text, verbatim". Model extraction is lossy and bloats the one
long-lived context. A script can only do it if the plan is reliably parsable —
and a model writes the plan, so conformance cannot be guaranteed, only
**enforced**.

**Agreed fix.** One new script validates and extracts:
- **check** — every increment heading carries a `**Verification:**` or
  `**Manual:**` field; addenda repeat the increment heading with the same
  fields (tighten `references/templates/plan.md` and the agents accordingly).
  The dispatcher runs it **when `tsf:plan` returns** and again **when
  `tsf:implement` returns** (addenda are written then). A failure is an invalid
  return: one re-dispatch with a note, then a park — so a plan that does not
  parse never reaches the human's approval.
- **criteria** — writes the numbered criteria (and the manual items) to a file;
  it fails loudly when an increment yields none. The gates and
  `tsf:manual-verify` receive **paths**; `tsf:spec-coverage` and
  `tsf:integration` receive the spec by path. The gate payload rule ("never the
  plan's prose") stays intact: the criteria file is the only plan-derived input.

### C12 — No write path for the pull request's title and body (review #14)

**Finding.** `cycle-write-phase.md` ("The dossier's writes") tells the
dispatcher to fix a mismatching PR title or body "with `gh-write.sh`", but no
such subcommand exists.

**Agreed fix.** Add one (PATCH on the pull request, read back), and name it in
the write phase.

### Deferred by decision — recorded in `plugins/tsf/TODO.md` on 2026-09-20

- **The factory session's permission mode** (review #1): the first consumer
  runs the factory sandboxed with permissions bypassed, so it does not bite
  now.
- **Count only responders' reviews** (review #9): irrelevant on a private
  single-engineer repository.

Both entries are already written (uncommitted at ticket creation); commit them
with this ticket.

## Acceptance Criteria

- [ ] **C1**: `preflight.sh` reports the timeout variables like it reports
      `foreground:` and yields `result: incomplete` when they are missing or
      too low; `cycle.md`, the worker agents, the README, `/tsf:init`'s clone
      checklist and `templates/tsf/config.md` (if a value lives there) agree.
- [ ] **C2**: for each `Next step` in the closed vocabulary, a `tsf:queued`
      ticket with a journal gets the matching label and the cycle ends; a resume
      into verification carries a new `Episode:`; a stale factory-side label of
      any kind is corrected. `README.md` resume text matches.
- [ ] **C3**: against a stub `gh`, a CHANGES_REQUESTED review older than the
      factory's last PR comment scans as no review, a newer one as
      `changes-requested`; same for approvals. Row 10's stale outcome writes
      nothing.
- [ ] **C4**: against a stub `gh`, the new subcommand prints the latest
      CHANGES_REQUESTED review's body and its inline comments with path and
      line; the rework payload carries the file path; `agents/implement.md`
      reads it.
- [ ] **C5**: against a stub `gh`, a `tsf:landing` record carries the
      approval's commit id and timestamp; Step 3 orders by timestamp; row 12's
      `ancestor` and `main-delta` calls receive a commit id.
- [ ] **C6**: a `tsf:verify` ticket with zero check runs and `mergeable: false`
      is synced (merge-resolver on conflict); a ticket pending beyond
      `ci_pending_bound` parks with the reason. Constant in the config template,
      init's upgrade list, README.
- [ ] **C7**: with required check names configured, a failing non-required
      check run does not read as `failure`; `none` reads as "no CI" and the
      cycle does not wait; the TODO item is settled.
- [ ] **C8**: against a stub `gh` whose PR head changes on the second read,
      `update-branch` reports `synced` with the new head; a head that never
      moves is reported as its own outcome.
- [ ] **C9**: the snippet exists under `templates/github/`; it implements the
      three-way inherit rule; `/tsf:init` offers it and asks for confirmation;
      README, ruleset checklist and `TODO.md` agree.
- [ ] **C10**: a plan with more increments than `implement_batch` takes several
      cycles, each pushed; the journal lists done increments; no PR and no issue
      comment before the last batch; a no-progress return parks; init warns on
      push-triggered CI; the crash-loop TODO entry exists.
- [ ] **C11**: the script rejects a plan with an increment lacking both fields
      and an addendum in free prose; `criteria` output is what the gates and
      manual-verify receive by path; the dispatcher no longer reads plan or
      spec bodies anywhere in `cycle.md`/`cycle-dispatch.md`.
- [ ] **C12**: against a stub `gh`, the new subcommand patches title and body
      and reads them back.
- [ ] **Governance**: every same-commit span in the repository `CLAUDE.md` that
      a correction touches is honoured (dispatcher-owns-every-write, result
      block, journal `Next step`, gate report, fix mode/episodes, environment
      cadence, `diff.sh`, landing, one-landing-in-flight, config-is-prose-only —
      every new value a script needs arrives as an **argument**); new CLAUDE.md
      rule text where a correction creates a new span (scan record fields, the
      plan-check script, the batch/progress entry).
- [ ] **Release**: `config.md` gains required content (required checks,
      `ci_pending_bound`, `implement_batch`), so `/tsf:init`'s Idempotency
      upgrade list gains the entry and the version is bumped in both manifests;
      `claude plugin validate` passes for the marketplace and the plugin; the
      tag is created in the same session as the bump.

## Open Questions

1. **C1 — where the timeout variables are set.** The discussion agreed "init
   writes them into the clone's settings". But the repository rule "`/tsf:init`'s
   allowlist append is the second sanctioned `settings.json` edit … never any
   other key" forbids an `env` key. Alternative with no rule change: they join
   `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` and `GH_TOKEN` as **shell exports**
   in the clone checklist, enforced by the preflight exactly like the foreground
   variable. Recommended: the shell export — same mechanism as the existing
   runner variables, no governance change. The preflight check is the agreed
   substance either way.

## Questions for Research/Planning

- C1: which values to require, and whether `BASH_MAX_TIMEOUT_MS` may exceed the
  documented 600 s ceiling (verify against the Claude Code docs).
- C6: the time source for the age bound — the head commit's committer date is
  local to the clone after `prepare`; confirm it is robust for a server-made
  sync merge.
- C9: how the job reads the parent's concluded result with the built-in token
  (check-runs for the `before` sha, filtered to the required check's name), and
  what `before` is on the `opened` event (no fast path there — full run).
- C10: the journal line's exact shape for done increments (it joins the entry
  shape contract in `journal-entry.md`), and how increments are identified
  stably (the plan's `### Increment N` numbers; C11's check can enforce
  uniqueness).
- C11: whether the script lives next to `diff.sh` as its own file or as a
  `diff.sh`-style multi-mode script; the addendum shape in `plan.md`.

## Out of Scope

- The two deferred TODO items above, and everything already in DESIGN.md §14/§15.
- The end-to-end smoke test itself — still deferred to the first real factory
  setup by earlier decision. **Strongly recommended directly after this
  ticket**: the dispatcher is about a thousand lines of prose executed by a
  model, and the first run will surface more.
- Redesigns considered and rejected in the discussion: moving the journal off
  the branch, an extraction agent instead of the plan-check script, a
  per-increment (batch size 1) implementation loop as the only mode.

## Notes & Updates

- 2026-09-20: created from the review discussion. Evidence: a stub `gh` run of
  `scan.sh` reproduced C3 and C5; the Claude Code docs confirmed the timeout and
  kill behaviour behind C1; GitHub's docs (raw source of "Events that trigger
  workflows") confirmed the merge-conflict rule behind C6.
- Review findings not carried: none silently — #1 and #9 are in `TODO.md`.
