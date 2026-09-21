# TP-0037: tsf — corrections from the final pre-first-run review

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-21
**Updated:** 2026-09-21

Follow-up to TP-0036. Collects the three corrections the user accepted from the
final code-only review of `plugins/tsf/` on 2026-09-21. A fourth finding of that
review (an environment-wide `prepare` failure parking the backlog one ticket per
cycle) was deliberately deferred and is recorded in `plugins/tsf/TODO.md`, not
here.

## Problem Statement

The final review read every command, reference, agent, script and template of
tsf for inconsistencies that would hurt the first real factory run. It found
three places where two files of the plugin contradict each other on a **normal**
path, so the outcome at runtime is either a ticket that can never be resumed or
behaviour that depends on which instruction the model happens to obey:

1. A `blocked` return from two agents writes a journal state the dispatcher
   itself rejects as unreadable.
2. Opening the pull request, and refusing a landing, both require the dispatcher
   to read and write artifact content, which its own top invariant forbids.
3. A failed manual verification item has a routing rule that no component can
   execute.

None of these is a design flaw. Each is a contract that one side of a seam
states and the other side cannot honour.

## Desired Outcome

Every state an agent can return is a state the dispatcher can read back, the
dispatcher never needs spec, plan or dossier content in its own context to
complete a cycle, and every routing rule in the dispatch reference can be
carried out with the data the result block actually carries. Each correction
below states the finding, the agreed fix and how "done" is observed.

## Corrections

The numbering is this ticket's own; "review #n" is the number used in the review
discussion.

### C1 — A blocked verification step writes an unresumable state (review #1)

**Finding.** A ticket's state is the `Next step` line of its last journal entry,
and `cycle-dispatch.md` treats any value outside the closed vocabulary
(`triage | research | plan | implement | verify | gates | dossier | review |
landing`) as unreadable and parks the ticket. `result-block.md`'s
allowed-outcomes table has one wildcard row, `any | blocked | tsf:needs-human |
the step itself`. For `tsf:verify-fix` and `tsf:manual-verify` "the step itself"
is `verify-fix` / `manual-verify`, which is not in the vocabulary, and neither
agent's `## Return` section names a value (`merge-resolver.md` does:
`landing`). The parsing rules accept the row, so the value reaches the journal.
When the human re-queues the ticket, the derived step is unreadable, the ticket
parks again, and the mismatch entry repeats the unreadable value, so it re-parks
on every resume until someone hand-edits the journal on the branch. Verify-fix
blocking is a designed, likely path ("CI red with local green").

**Agreed fix.** Replace the wildcard row with explicit `blocked` rows per step,
each naming a `next-step` inside the closed vocabulary: `verify-fix` and
`manual-verify` map to `verify`, `merge-resolver` to `landing`, every other step
to itself. State the value in the `## Return` sections of `verify-fix.md` and
`manual-verify.md`.

**Done when.** No (`step`, `blocked`) combination in the table yields a
`next-step` outside the vocabulary, and a ticket blocked by verify-fix resumes
through the documented re-queue path into `tsf:verify` with a new episode.

### C2 — The dispatcher is told to author content its invariant forbids (review #2)

**Finding.** `cycle.md` invariant 3 says the dispatcher never reads the body of
a spec, research, plan or diff and never writes artifact content, and that the
invariants win any conflict. Two places contradict it:

- `cycle-write-phase.md`, "Opening the pull request", has the dispatcher compose
  the title from the spec's title and a body (`pr-body.md`) holding a summary of
  the spec's desired outcome and the plan's decisions. This runs on **every**
  ticket, at the last implementation batch.
- `cycle-dispatch.md` row 12, "Not decided", has the dispatcher produce a
  dossier addendum naming the cause (`dossier.md`, "The landing refusal"), which
  is a rated, narrated document.

At runtime the model either violates the invariant (pulling spec and plan text
into the long-running loop context) or produces an empty body, unpredictably.

**Agreed fix.**

- The implement agent's **final fresh-mode batch** (the return whose
  `next-step:` is `verify`) authors the pull request title and body from
  `pr-body.md`. The text is handed over **as a file path, never as result-block
  content**, so no spec or plan text enters the dispatcher's context — the same
  paths-only pattern the diff, the criteria and the review brief already follow.
  The dispatcher passes the path to `gh-write.sh pr-create` without opening the
  file.
- The landing-refusal addendum is written by the **dossier agent**, dispatched
  for that purpose; the dispatcher only posts what it returns.

**Done when.** No instruction in `cycle.md`, `cycle-dispatch.md` or
`cycle-write-phase.md` requires the dispatcher to read a spec, plan, research or
dossier body or to compose artifact text; a pull request opened by the factory
carries the `pr-body.md` shape; and a refused landing posts an addendum the
dossier agent wrote.

### C3 — A failed manual item has a route nothing can execute (review #4)

**Finding.** `cycle-dispatch.md` row 6 says a `failed` manual item "routes
exactly like a red verification" into `tsf:verify-fix` with `failure: local`.
But `tsf:manual-verify` can only return `continued | tsf:verify | gates`; its
result block carries `manual: k attempted, m need a human` with no failed count,
so the dispatcher can only learn of a failure by reading comment or report
content; the routing would be a second dispatch in the same cycle; and
verify-fix would receive the output of a **green** suite and nothing about the
manual item, so it would block. The dossier template already lists attempted
manual items that failed as open items, so the human sees them regardless.

**Agreed fix.** Delete the routing sentence from row 6. A failed manual item
travels to the dossier as an open item, which is what the rest of the plugin
already does. Make sure `agents/dossier.md`'s open-items list names failed
manual items as explicitly as the template does.

**Done when.** No file claims a failed manual item enters the fix loop, and the
dossier agent's instructions and the dossier template agree that a failed
manual item is an open item with its evidence.

## User Stories / Use Cases

- As the engineer running the factory, I want a ticket that an agent blocked to
  resume when I re-queue it, so that fixing the cause is all I have to do.
- As the engineer running the factory, I want the dispatcher's context to stay
  free of spec and plan text, so that a long `/loop` session stays cheap and its
  routing stays trustworthy.
- As a reviewer, I want a manual check the factory saw fail to reach me in the
  dossier with its evidence, so that I never approve a change believing the
  check passed.

## Acceptance Criteria

- [ ] `result-block.md`'s allowed-outcomes table has no wildcard `blocked` row;
      every `blocked` row names a `next-step` from the closed vocabulary.
- [ ] `verify-fix.md` and `manual-verify.md` state `next-step: verify` for a
      `blocked` return.
- [ ] The implement agent's final fresh-mode batch produces the pull request
      title and body, and the dispatcher receives them by file path only.
- [ ] `cycle-write-phase.md` no longer instructs the dispatcher to compose the
      pull request title or body.
- [ ] Row 12's "Not decided" path dispatches the dossier agent for the refusal
      addendum; the dispatcher writes none of its text.
- [ ] `cycle.md` invariant 3 and the rest of the dispatcher's instructions no
      longer contradict each other on any path.
- [ ] Row 6 of `cycle-dispatch.md` no longer routes a failed manual item into
      verify-fix; `agents/dossier.md` names failed manual items as open items.
- [ ] Every same-commit span the root `CLAUDE.md` names for the touched
      contracts (result block, journal `Next step`, dispatcher-owns-writes,
      batched implementation) is updated together, and `CLAUDE.md` records any
      new rule these corrections create.
- [ ] `claude plugin validate ./plugins/tsf` and `claude plugin validate .`
      pass; the tsf version is bumped in both manifests and tagged.

## Out of Scope

- The environment-wide `prepare` / push failure that parks one ticket per cycle
  (review #3) — deferred by user decision, recorded in `plugins/tsf/TODO.md`.
- The merge cycle's handling of `mergeable_state: unstable`, and the built-set
  reset after an implementation question — noted in the review as lower
  priority, not accepted into this ticket.
- The factory session's permission mode — already recorded in `TODO.md`.
- Any change to DESIGN.md's state machine beyond what these three corrections
  force.

## Open Questions

None.

## Questions for Research/Planning

- [ ] C2: should the pull-request text file be **untracked** (under
      `.tsf-tmp/`, deleted by the next `prepare`) or **committed** on the branch
      (e.g. `thoughts/factory/GH-<n>/pr-body.md`)? Untracked matches the diff
      and criteria files. Committed survives a cycle that dies between the push
      and `pr-create` — today that gap leaves a `tsf:verify` ticket with no pull
      request and, with an untracked file, no text to open one from — and gives
      the dossier agent a file to validate the live body against. Review
      recommendation: committed.
- [ ] C2: the title is a single line. Does it travel in the file as well (first
      line, or a `--title-file` flag on `gh-write.sh pr-create`), or as one
      result-block field? A flag change falls under the "dispatcher owns every
      GitHub write" span (`cycle.md`, `cycle-write-phase.md`, `spec.md`,
      `init.md`).
- [ ] C2: how does the dossier agent learn it is being dispatched for a landing
      refusal (a `mode:` value, a `refusal-cause:` field), and which cycle posts
      its addendum given the landing's write rules?
- [ ] C2: the dispatcher's own one-line comments (parks, the landing decision
      line) are not artifact content — confirm invariant 3's wording leaves
      them clearly allowed after the edit.
- [ ] C1: does `journal-entry.md`'s "failed write / invalid return" shape ("the
      step itself if none was valid") have the same out-of-vocabulary hole for
      `verify-fix`, `manual-verify` and `merge-resolver`?
- [ ] Which version does this ship as (a patch on 1.1.0), and does `/tsf:init`'s
      Idempotency list need an entry (expected: nothing to migrate)?

## References

- The review discussion of 2026-09-21 (this session).
- `plugins/tsf/references/templates/result-block.md` — allowed-outcomes table.
- `plugins/tsf/references/cycle-dispatch.md` — derived state, rows 6 and 12.
- `plugins/tsf/references/cycle-write-phase.md` — "Opening the pull request".
- `plugins/tsf/commands/cycle.md` — invariant 3.
- `plugins/tsf/agents/{verify-fix,manual-verify,implement,dossier}.md`.
- `plugins/tsf/references/templates/{pr-body,dossier}.md`.
- TP-0036 — the previous review-corrections ticket.

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-09-21

- Scope fixed by the user from the review's four main findings: #1, #2 and #4
  accepted with their recommended fix; #3 deferred to `TODO.md`.
- On #2 the user asked whether a temporary file would serve better than a
  result-block fence, to keep the text out of the dispatcher's context. Agreed:
  the handover is by file path. Whether that file is untracked or committed is
  left to planning, with the review's recommendation (committed) recorded above.
- Complexity Medium: three small corrections, but each crosses a same-commit
  span named in the root `CLAUDE.md`, and C2 adds a new agent-to-dispatcher
  handover.
