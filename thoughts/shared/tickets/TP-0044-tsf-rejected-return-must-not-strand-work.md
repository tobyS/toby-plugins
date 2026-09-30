# TP-0044: tsf — a rejected result block must not strand pushed work

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-29
**Updated:** 2026-09-29

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

Three gaps compound:

1. **Progress is recorded in the return, but made on the branch.** The work is
   pushed before the result block is parsed. Reject the block and the commits
   survive while the record of what they are does not. The dispatcher even lists
   the commits in the park entry — it knows something was built, just not what.
2. **The no-progress guard cannot tell "already finished" from "stalled".** With
   an empty built set the next cycle dispatches the same batch; the agent looks,
   correctly reports that the increments are already in the branch history, and
   builds nothing. The guard reads a cycle that added no increment and parks
   `tsf:needs-human`. It fires *because* the previous cycle made progress, and it
   will fire identically on every future cycle.
3. **Nothing opens the pull request off the happy path.** It opens on a fresh
   last batch, or on a format-fix return whose `resume-to:` was `verify`
   (`cycle-write-phase.md:70-99`, TP-0043's walkthrough gap). A ticket that
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

**Done when.** An implement cycle whose result block is rejected after it pushed
leaves a built set the next cycle reads correctly, and GH-41's branch as it
stands today yields `1,2,3`.

### C2 — a complete built set is completion, not stalling

**Finding.** The guard (`cycle-dispatch.md:217`) fires on "the return's
`- Increments:` line adds no number the built set did not already have". It has
no notion of the plan being finished, so the terminal state and the stalled state
are the same observation.

**Fix.** The guard is two conditions, not one: the built set did not grow **and
increments remain**. A cycle that adds nothing because nothing is left is the
last batch — it returns `next-step: verify`, and the write phase opens the pull
request. With C1 in place this is what heals GH-41 on its own.

**Done when.** A ticket whose branch already carries every increment advances to
`tsf:verify` on its next cycle instead of parking, and a genuinely stalled cycle
with increments outstanding still parks.

### C3 — the pull request opens whenever it is missing

**Finding.** Two specific returns open it. Every other route to `verify` — C2's
heal, a resume, whatever the next slice adds — leaves the ticket at a step whose
definition presumes a pull request that does not exist.

**Fix.** Open it on the condition rather than on the route: `pr-body.md` is
committed on the branch and no pull request exists for it. `pr-create` already
answers `exists` harmlessly, which is what TP-0043 relied on to make the
format-fix path safe to reach twice; the same property makes this safe as a
standing check.

**Done when.** A ticket that arrives at `verify` by any path has its pull request
opened in that cycle, and a ticket that already has one is untouched.

## Acceptance Criteria

- [ ] C1: increment commits carry `Tsf-Increment: <n>`; a `diff.sh` subcommand
      derives the built set from the branch; the dispatcher's `built:` reads it.
- [ ] C1: a return claiming an increment with no matching trailer is an invalid
      return whose message shows the required trailer form.
- [ ] C1: the journal's `- Increments:` line is narrative only — no reader
      derives state from it.
- [ ] C2: the no-progress guard requires both "no growth" and "increments
      remain"; a complete built set returns `next-step: verify`.
- [ ] C3: the pull request is opened whenever `pr-body.md` is committed and none
      exists, independent of which return arrived.
- [ ] GH-41's branch as it stands is walked on paper end to end and reaches
      `tsf:verify` with a pull request, with no human step.
- [ ] `claude plugin validate ./plugins/tsf` passes; the CLAUDE.md same-commit
      spans for the journal's derived state, the batching rule, the result block
      and `diff.sh`'s git facts are honoured.

## Out of Scope

- Unblocking GH-41 by hand. The point of this ticket is that it heals itself; a
  manual repair would remove the only live test case we have.
- The plan parser and the format-fix path — TP-0043, already released as 1.3.0.
- Deriving *which* increment a commit implements from anything other than the
  agent stating it. Inferring it from the diff or the message is the kind of
  guess the factory is built to refuse.
- Rework and fix mode. Neither is batched and neither carries `built:`.

## Open Questions

- C1: does the `- Increments:` line stay at all once nothing reads it?
  Recommendation: keep it, purely as narrative — the journal is what a human
  reads to understand a ticket's history, and dropping it makes implement entries
  say less than every other step's.
- C3: should the standing check live in the write phase (where `pr-create` is
  today) or in row 6's preconditions? The write phase runs on every cycle and
  already owns the `exists` tolerance, which argues for it.

## Questions for Research/Planning

- [ ] Whether `Tsf-Increment:` belongs on `diff.sh` (git facts about the branch,
      which is what it owns) or on `plan.sh` (which owns increment numbers), and
      what the subcommand's record shape should be.
- [ ] Exactly where `built:` is composed today, so C1 changes one site rather
      than several — `cycle.md` Step 3/4, `cycle-dispatch.md` row 5, or both.
- [ ] Whether the no-progress guard has any other caller or restatement beyond
      `cycle-dispatch.md` row 5 and `journal-entry.md`'s "The increments line".
- [ ] What a resume into `tsf:implement` does with a git-derived built set, given
      the current anchor ("since the ticket most recently entered
      `tsf:implement`") exists only to scope a journal scan and may become moot.

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
