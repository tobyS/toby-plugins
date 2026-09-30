# TP-0044: tsf — a rejected result block must not strand pushed work

**Status:** Open
**Estimated Complexity:** Large
**Created:** 2026-09-29
**Updated:** 2026-09-30

From the chat-sustainability GH-41 run, the same ticket TP-0043 was raised from,
one layer further down. TP-0043 fixed why the return was rejected and how the
human was told about it. This ticket is about what the rejection *destroyed*: the
implement agent had already built, verified, committed and **pushed** all three
increments and `pr-body.md` when its result block was refused. The factory has no
record that any of it happened, and no cycle since has been able to move the
ticket. It is a permanent deadlock, not a slow one.

## Problem Statement

The record of which increments are built exists in exactly one place — the
`- Increments:` line of an **accepted** agent `tsf-journal` block. A dispatcher
written park entry cannot carry one. So an implement cycle that does the work and
then fails its return leaves the branch ahead of the journal, permanently.

**Four** mechanisms compound — the research corrected the count and the order.
They fire in this sequence, and the first one alone is enough to park the ticket
forever:

1. **Progress is recorded in the return, but made on the branch.** The work is
   pushed before the result block is parsed. Reject the block and the commits
   survive while the record of what they are does not. The dispatcher even lists
   the commits in the park entry — it knows something was built, just not what.
   This is the root enabler; the three below are what it triggers.
2. **An implement cycle with nothing to build is an invalid return.**
   `MANDATORY OUTPUT` (`cycle.md:236-243`) requires "at least one new commit for
   implement". A cycle whose work is already in the branch makes no commit, so
   the return is refused before anything else is consulted. **This is what parks
   GH-41 today** — the journal says so: *"agent returned no valid result twice
   (no new commit: …)"*. The agent has no legal alternative either: the only
   instruction covering an empty remainder (`implement.md:74-82`) is scoped to
   unsatisfiable dependencies and prescribes `outcome: blocked`.
3. **The no-progress guard cannot tell "already finished" from "stalled".** With
   an empty built set the next cycle dispatches the same batch; the agent looks,
   correctly reports that the increments are already in the branch history, and
   builds nothing. The guard (`cycle-dispatch.md:217-222`) reads a cycle that
   added no increment and parks `tsf:needs-human`. It fires *because* the
   previous cycle made progress. It is downstream of 2 and has never yet been
   reached on this ticket.
4. **Nothing opens the pull request off the happy path.** It opens on a fresh
   last batch, or on a format-fix return whose `resume-to:` was `verify`
   (`cycle-write-phase.md:71-98`, TP-0043's walkthrough gap). A ticket that
   reaches `verify` any other way has no pull request and no row that will ever
   create one — and `verify` is defined as "the pull request is open".

Each on its own is survivable. Together they are a trap with no exit: the state
the factory is in cannot be reached again by any path that would repair it.

## Evidence from the run

- Journal `2026-09-27T18:07Z` — `step: implement`, parked `tsf:needs-human` on
  the plan check, `Commits: 1183108 29801ed b7c2955 b81f440 353f939`, **no**
  `- Increments:` line. Those commits are the three increments and `pr-body.md`.
- Journal `2026-09-29T13:38Z`, tsf 1.3.0, a fresh loop with TP-0043's artifacts:
  "no new commit: it reported increments 1-3 and pr-body.md as already committed
  in 1183108 29801ed b7c2955 b81f440, but no journal entry records them as
  built". The agent's report was correct and the park was still correct by the
  rules as written.
- `git diff --stat origin/main...origin/gh-41 -- . ':(exclude)thoughts/'` — 14
  files, +1025/−134, tests included. All of it verified and pushed.
- `plan.sh check --plan …` on the branch → `result: ok`. The original cause is
  gone; the deadlock outlived it.
- `gh pr list --head gh-41 --state all` → empty. No pull request, after four
  implement cycles.
- The built set is anchored on "the newest entry whose `- Label:` is
  `tsf:implement` and whose `step:` is not `implement`"
  (`journal-entry.md`, "The increments line"). For GH-41 that is the
  `2026-09-27T18:03Z` plan entry, and every `step: implement` entry after it is a
  dispatcher-written park. The union is empty and cannot become non-empty.
- TP-0043's format-fix escape did not apply: the park predates it (no
  `- Resume at:` line), and the plan was repaired by hand in `f116634` outside
  the factory, so no reply ever arrived to route through row 1.

## Corrections

### C1 — the built set is a fact on the branch, not a line in the journal

**Finding.** `- Increments:` is the only source, it is only writable by a return
that parses, and the work it describes is pushed before that return is judged.
The ordering guarantees that a rejected return loses progress that has already
landed.

**Fix.** Make the built set derivable from git, the way the logic head already
is. Each increment commit carries a trailer — `Tsf-Increment: <n>` — and a new
`diff.sh` subcommand walks the branch and prints the set. The dispatcher's
`built:` comes from there. This follows the `Tsf-Resolution` precedent exactly:
a machine fact the agent states in the commit, read back with
`git show -s --format='%(trailers:key=…)'` (`diff.sh:272`), surviving anything
that happens to the conversation or the result block.

**One source, not two that must agree** — TP-0043's lesson from `check` and
`criteria`. Git is the source of truth for `built:` and for the guard. The
journal's `- Increments:` line stays as the readable narrative of a cycle, and
never as an input.

**A forgotten trailer must be loud.** If an agent omits it, the increment is
invisible and the factory rebuilds it. `cycle.md` Step 6 should reject a return
whose claimed increments are not all carried by trailers — an invalid return with
the shape shown, per TP-0043's rule, not silent drift.

**The trailer's failure direction is the opposite of `Tsf-Resolution`'s, and
that is the one thing this correction must get right.** git returns the empty
string indistinguishably for "no such trailer", "the trailer block was not
recognized" and "no body", and a single non-trailer line in the commit's last
paragraph silently voids every trailer in it (`Co-authored-by:` is **not** one of
the two git-generated prefixes that buy the 25% tolerance — only
`Signed-off-by: ` and `(cherry picked from commit ` are). For the logic head,
empty → `logic` → one avoidable re-approval, which is why failing closed works
there. For a built set, empty → "not built" → the factory rebuilds an increment
that is already in the branch. So the trailer secures the *future* and C4 is what
makes the *present* recoverable; neither substitutes for the other.

**This correction does not heal GH-41**, and that is measured rather than
assumed: its three implementation commits carry only `Co-Authored-By:`, so a
trailer-derived built set for `gh-41` is empty, exactly as the journal-derived one
is. The heal comes from C4.

**Done when.** An implement cycle whose result block is rejected after it pushed
leaves a built set the next cycle reads correctly, on a branch whose commits
carry the trailer.

### C2 — a complete built set is completion, not stalling

**Finding.** The guard (`cycle-dispatch.md:217`) fires on "the return's
`- Increments:` line adds no number the built set did not already have". It has
no notion of the plan being finished, so the terminal state and the stalled state
are the same observation.

**Fix.** The guard is two conditions, not one: the built set did not grow **and
increments remain**. A cycle that adds nothing because nothing is left is the
last batch — it returns `next-step: verify`, and the write phase opens the pull
request.

**"Increments remain" is not computable today.** `plan.sh check` prints
`increments: 3` — a count. The numbers exist only inside the criteria file, which
`cycle.md` invariant 3 forbids the dispatcher to open (and
`cycle-dispatch.md:266-267` says so outright: "Do not open either file — the
counts are all you need"). Numbers are kept as strings and only checked for
uniqueness, so nothing enforces contiguous `1..n` and a count comparison would be
wrong on a plan numbered 1,2,7. So `plan.sh` must emit the increment numbers, and
that puts this correction inside the plan contract's same-commit span.

`diff.sh` must not gain the plan side of this: `plan.sh` is the only thing that
parses a plan. The division is `plan.sh` emits the numbers, `diff.sh` emits the
built set, the dispatcher compares two lists.

**Done when.** A ticket whose branch already carries every increment advances to
`tsf:verify` on its next cycle instead of parking, and a genuinely stalled cycle
with increments outstanding still parks.

### C3 — the pull request opens whenever it is missing

**Finding.** Two specific returns open it. Every other route to `verify` — C2's
heal, a resume, whatever the next slice adds — leaves the ticket at a step whose
definition presumes a pull request that does not exist.

**Fix.** Open it on the condition rather than on the route: **any** implement
return whose `next-step:` is `verify` opens the pull request, with no mode
conditional at all.

The existence of a pull request never has to be established, which is what makes
this cheap. The scan does not probe for one in `tsf:implement` (`pr: skipped`,
`scan.sh:192`), so the fact is not in hand — but `pr-create` answers a 422 by
looking the pull request up and reporting `exists` with its `number:`
(`gh-write.sh:57-65`, `:432-450`). TP-0043 already leaned on exactly that to make
the step safe to reach twice; stating it as a condition retires the whole class
instead of patching a third route. The cost is one idempotent REST call on each
rework and fix cycle, where the pull request has existed for ages.

**Done when.** A ticket that arrives at `verify` by any path has its pull request
opened in that cycle, and a ticket that already has one is untouched.

### C4 — a cycle with nothing left to build is a legal outcome

**Finding.** This is the mechanism that actually parks GH-41, and it fires before
C2's guard. `MANDATORY OUTPUT` requires "at least one new commit for implement"
(`cycle.md:236-243`), so a cycle whose increments are all already in the branch
cannot return successfully — and the agent has no legal way to say so either
(`implement.md:74-82` prescribes `outcome: blocked`, and that clause is about
unsatisfiable dependencies).

**Fix.** Make "the plan is already built" a first-class return rather than an
exception: the commit requirement gains a carve-out beside the existing
`mode: format-fix` one (`cycle.md:245-248`), the agent gets an explicit
instruction for an empty remainder that returns `next-step: verify`, and C2's
guard recognizes the completion case.

**The factory accepts the agent's report here, and that is deliberate** (decided
2026-09-30). The agent has the plan and the branch in front of it; verification
and the four gates exist precisely to catch an implementation that is not
actually complete. Parking at implement to protect verify defends a line that is
already defended downstream, and it is the reason a fully built, fully verified,
fully pushed plan has sat behind a red label for three days. This does not weaken
"never guess a state": the dispatcher still invents nothing — it believes a
worker's report about its own domain, as it does for every other step.

**Done when.** GH-41's branch as it stands, with no trailers and no manual entry,
reaches `tsf:verify` with a pull request open.

## Acceptance Criteria

- [ ] C1: increment commits carry `Tsf-Increment: <n>`; a `diff.sh` subcommand
      derives the built set from the branch; the dispatcher's `built:` reads it.
- [ ] C1: a return claiming an increment with no matching trailer is an invalid
      return whose message shows the required trailer form.
- [ ] C1: the journal's `- Increments:` line is narrative only — no reader
      derives state from it.
- [ ] C1: the trailer is written as the sole content of a clean final paragraph,
      and an empty read is treated as "unknown", never as "not built".
- [ ] C2: `plan.sh` emits the increment numbers, so "increments remain" is
      computable without opening the criteria file.
- [ ] C2: the no-progress guard requires both "no growth" and "increments
      remain"; a complete built set returns `next-step: verify`.
- [ ] C3: the pull request is opened on any implement return whose `next-step:`
      is `verify`, with no mode conditional; a ticket that has one is untouched.
- [ ] C4: an implement cycle whose increments are all already built returns
      successfully — `MANDATORY OUTPUT` permits the absent commit and the agent
      has an explicit instruction for the empty remainder.
- [ ] **GH-41's branch as it stands reaches `tsf:verify` with a pull request
      open, with no human step** — walked on paper against the edited files, and
      confirmed on the live ticket when the next loop runs.
- [ ] `claude plugin validate ./plugins/tsf` passes; the CLAUDE.md same-commit
      spans for the journal's derived state, the batching rule, the result block,
      the plan parser and `diff.sh`'s git facts are honoured.

## Out of Scope

- Unblocking GH-41 by hand. The point of this ticket is that it heals itself; a
  manual repair would remove the only live test case we have.
- The plan parser and the format-fix path — TP-0043, already released as 1.3.0.
- Deriving *which* increment a commit implements from anything other than the
  agent stating it. Inferring it from the diff or the message is the kind of
  guess the factory is built to refuse.
- Rework and fix mode. Neither is batched and neither carries `built:`.

## Open Questions

- ~~C1: does the `- Increments:` line stay at all once nothing reads it?~~
  **Resolved 2026-09-30: keep it, purely as narrative** — the journal is what a
  human reads to understand a ticket's history, and dropping it makes implement
  entries say less than every other step's.
- ~~C3: should the standing check live in the write phase or in row 6's
  preconditions?~~ **Resolved 2026-09-30: the write phase**, and it is not a
  check — `pr-create`'s own 422 → `exists` means existence never has to be
  established, so it is an unconditional call on any verify-bound implement
  return.
- ~~Does the heal come from the trailer or from accepting the agent's report?~~
  **Resolved 2026-09-30: both, for different halves.** The trailer (C1) fixes the
  root enabler for future runs; accepting the report (C4) is what recovers a
  branch whose commits predate the trailer, GH-41 included.
- What bound replaces the guard's purpose for the stalled case? The guard exists
  to stop a plan-length loop of empty cycles; C2's "increments remain" removes the
  terminal case but not the stalled one, which still needs to park.

## Questions for Research/Planning

- [x] Whether `Tsf-Increment:` belongs on `diff.sh` or on `plan.sh`, and what the
      subcommand's record shape should be. → **`diff.sh`**: it owns git facts
      about the branch and already has the idiom — `logic-head`'s
      `git rev-list --first-parent` walk fed through a here-doc, with per-commit
      `git show -s --format='%(trailers:key=…)'` reads (`diff.sh:259-279`).
      `plan.sh` must not learn about git, and `diff.sh` must not learn to parse a
      plan. Record shape follows the house form: aligned `key: value` lines plus
      `result:`/`detail:`, exit 0 on every reported outcome.
- [x] Exactly where `built:` is composed today. → **One site**,
      `cycle-dispatch.md:213-216` (row 5). `cycle.md` never computes it;
      `cycle-dispatch.md:573` only lists it among row 5's payload fields.
- [x] Whether the no-progress guard has any other caller or restatement. →
      **Two statements only**: `cycle-dispatch.md:217-222` (primary) and
      `journal-entry.md:60-64`. Reader-facing paraphrases in
      `plugins/tsf/README.md:191-196` and `DESIGN.md:1792-1798` must follow.
- [x] What a resume into `tsf:implement` does with a git-derived built set. →
      The journal anchor ("since the ticket most recently entered
      `tsf:implement`") exists only to scope a journal scan and becomes moot: a
      branch-derived set has no such boundary. That is simpler, but it makes the
      trailer the **only** thing distinguishing an increment commit from a rework
      or fix commit — so the trailer must not appear on the latter.
- [x] Does `plan.sh` expose the increment numbers? → **No.** `check` prints a
      count; the numbers reach only the criteria file's prose. C2 therefore
      requires a `plan.sh` change (see C2).
- [x] Is the trailer mechanism sound as a machine contract? → **Yes, with two
      constraints.** git 2.22.0 floor for `key=`/`valueonly`/`separator=` (the
      repo already depends on it via `diff.sh:272`; local toolchain is 2.54.0,
      smoke-tested). But the trailer block must be the last paragraph and all
      trailers, `Co-authored-by:` does not buy the 25% tolerance, and an empty
      read is ambiguous — hence C1's polarity caveat. Reading a trailer off a
      squash commit is unsound and out of scope: the built set is read on the
      branch, pre-merge.

## References

- Run: chat-sustainability GH-41, journal entries `2026-09-27T18:07Z`,
  `2026-09-28T05:12Z`, `2026-09-28T08:21Z`, `2026-09-29T13:38Z`; branch `gh-41`
  at `11ea83a`; issue label `tsf:needs-human`; no pull request.
- `plugins/tsf/references/templates/journal-entry.md` — "The increments line"
  (the built-set definition and the guard's rationale).
- `plugins/tsf/references/cycle-dispatch.md` row 5 (`built:`, the no-progress
  guard); row 1 (the `- Resume at:` format-park override).
- `plugins/tsf/references/cycle-write-phase.md:70-99` — "Opening the pull
  request", including TP-0043's format-fix clause.
- `plugins/tsf/agents/implement.md` — fresh mode step 1 (skip `built:`), step 5
  (`pr-body.md`, last batch only), "Commit rules".
- `plugins/tsf/commands/cycle.md` — MANDATORY OUTPUT, the plan check, the
  format-fix commit exemption.
- `plugins/tsf/scripts/diff.sh:272` — the `Tsf-Resolution` trailer read, the
  precedent C1 follows.
- TP-0043 — the same run; its notes record the pull-request gap C3 generalizes.
- `thoughts/shared/research/2026-09-30-TP-0044-tsf-rejected-return-must-not-strand-work.md`
  — the research: the four mechanisms in firing order, the measured defect
  mechanism, and the option analysis behind the 2026-09-30 decisions.
- `thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md:458-460`
  — "Prior research never considered this … an unexamined premise, not a
  researched decision." Git-derivation was never weighed against the journal.

## Implementation Plan

## Notes & Updates

### 2026-09-29

- Raised after a fresh loop on tsf 1.3.0 parked GH-41 a fourth time. TP-0043's
  fixes work and were not enough: they address the rejection, not its wake.
- The deadlock is self-reinforcing, which is what makes it worth a ticket rather
  than a manual repair — the guard that parks the ticket does so *because* the
  work was done, so every retry confirms the trap.
- C1 and C2 are one mechanism seen from two sides: once the built set is a fact
  about the branch, "did this cycle achieve anything" and "is the plan finished"
  become separate questions, and today they are the same one.

### 2026-09-30 — after research, three corrections to this ticket

- **The count was wrong: four mechanisms, not three**, and the one this ticket
  opened by blaming — the no-progress guard — is not the one that parks GH-41. The
  proximate cause is `MANDATORY OUTPUT`'s commit requirement, which fires first
  and has never let the guard be reached. C4 was added for it, and the Problem
  Statement now lists the four in firing order. The lesson is worth keeping: the
  ticket reasoned from the guard's *rationale* rather than from the journal's own
  outcome line, which said "no new commit" all along.
- **Two premises failed measurement.** `plan.sh` prints an increment count and
  never the numbers, so C2's "increments remain" test was not computable by any
  reader invariant 3 permits — C2 now carries a `plan.sh` change. And GH-41's
  commits carry no trailers, so C1 cannot heal the very ticket this was raised
  from; the original acceptance criterion ("yields `1,2,3`") was unachievable and
  is replaced by "reaches `tsf:verify` with a pull request open".
- **Decisions taken with the user (2026-09-30).** (1) Do both C1 and C4: the
  trailer secures future runs, accepting the agent's report recovers the present,
  and neither substitutes for the other. (2) The fix must heal GH-41 with no human
  step — it stays the live test case, which is also why unblocking it by hand
  remains out of scope.
- **The trailer's polarity is the subtle part.** `Tsf-Resolution` can afford an
  ambiguous empty read because empty → `logic` costs one re-approval. A built set
  cannot: empty → "not built" → rebuild. Same mechanism, opposite consequence, and
  the reason C1 alone was never going to be enough.
- **C3 got smaller, not bigger.** Because `pr-create` is idempotent by 422 lookup,
  the condition "does a pull request exist" never has to be answered — so the rule
  is "any verify-bound implement return", with no mode conditional. TP-0043 patched
  this per-route after a paper walkthrough found route two; stating it as a
  condition retires route three and every route after it.
