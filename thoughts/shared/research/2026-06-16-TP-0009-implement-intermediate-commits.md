---
date: 2026-06-16
ticket: TP-0009
branch: main
commit: 9cf66d7ffddfce796bbf27df676bf74a53e871c5
topic: "/tce:implement makes no intermediate commits"
status: complete
---

# Research: /tce:implement makes no intermediate commits (TP-0009)

## Research Question

`/tce:implement` never instructs the agent to commit during implementation — it
only reserves a slot to *record* a commit hash. The fix should make implement
commit in logical groups, validate tests before each commit, and use the
configured commit convention. What exactly is the gap, how does the `/tce:commit`
workflow it should use behave, what phrasing pattern is idiomatic in this repo,
and which other files must change in lock-step?

## Summary

The gap is confirmed and precisely located: **`implement.md` contains no
imperative commit instruction and never references `/tce:commit`.** Its only
commit touchpoints are passive — a `### Commit` slot in the status-file template
(lines 116-117), and two "record the commit hash" rules, one of them guarded
with the tell-tale conditional "**if** a commit was made" (line 140). Its
"Verification Approach" (208-219) and "Final Verification" (221-239) sections
never mention committing.

Meanwhile both composites already assume per-phase commits happen:
- `work.md:234` **instructs** "Commit after each verified phase (using
  `/tce:commit` with full pre-commit checklist for code commits)", reinforced at
  `work.md:260`.
- `quickfix.md:185` **asserts** the implement process runs "…committing after
  each phase" — describing behavior `implement.md` does not actually instruct.

So the composites mirror an instruction the single-step command lacks — the
inverse of the usual drift, and a direct violation of the repo's "composites must
track single-step commands" rule. The fix is to add the imperative commit step to
`implement.md` (delegating to `/tce:commit`, matching every other command in the
repo), then align the two composites so their claims are backed by the
single-step command.

The `/tce:commit` workflow already delivers everything TP-0009's acceptance
criteria need (read convention from profile.md, run tests/typecheck/lint for code
commits, skip them for docs-only, never push), so implement should **delegate to
it** rather than inline equivalent steps — consistent with research, plan, ticket,
work, and quickfix, all of which route commits through `/tce:commit`.

## Detailed Findings

### 1. The gap in `implement.md` (the thing to fix)

`plugins/tce/commands/implement.md` — every commit-related line is passive:

- Status-file template, lines 116-118:
  ```
  ### Commit
  - `abc1234` <commit subject per the project's commit convention>
  ```
- Rule 5 (line 131): "…record … verification results, and the commit hash."
- "Writing Status Updates" (line 140): "The commit hash **if a commit was made**"
  — the conditional that betrays no commit is ever mandated.
- Ticket Status Transitions (lines 248-249): commits mentioned only as the
  vehicle for the status-line edit ("include the ticket file in the next commit").

The string `/tce:commit` does **not** appear in `implement.md` at all. The
"Verification Approach" section (208-219) lists: run success-criteria checks, run
code-style checks, fix issues, update plan/todos, update the status file — **no
commit step**. "Final Verification Before Closing a Ticket" (221-239) covers
running all affected test suites — **no commit step**. Line 219 even says "Don't
let verification interrupt your flow - batch it at natural stopping points,"
which is the natural place a "then commit" instruction belongs.

### 2. The `/tce:commit` contract (what implement should delegate to)

`plugins/tce/commands/commit.md` (90 lines). It is stack-agnostic; all concrete
commands and the message convention are read from `profile.md` at runtime.

- **a) Determine commit type** (lines 25-28): if the commit touches only `.md`
  files → **docs-only**, skip steps b/c/d; otherwise → **code commit**, run them.
- **b/c/d) Tests / typecheck / lint** (lines 30-40): run the project's
  test/typecheck/lint commands **from `profile.md`**; all must pass.
- **e) Review staged files** (lines 44-48): check `git status` / `git diff
  --staged`; expects intended changes staged (it reviews staging, it does not
  prescribe the `git add`/`git commit` mechanics — those come from the agent's
  global git workflow; no `.claude-commit`/`git commit -F` is written here).
- **Ticket state** (lines 52-57): include ticket-status changes in the **same
  commit**; if the project's policy forbids tce transitioning, remind instead.
- **Message** (lines 59-82): format per the `## Commit convention` section of
  `profile.md` (Conventional Commits fallback); ticket ID where the convention
  dictates; under 72 chars; explain what/why.
- **Never push** (line 86).
- **No interactive dialogs** — it proceeds through the checklist without
  confirmation, so it is safe to invoke autonomously (quickfix already does).

Implication: delegating to `/tce:commit` for a **code** commit automatically
satisfies TP-0009's "validate the relevant test/lint/typecheck suites before each
commit" and "use the configured commit convention" criteria — no need to restate
them in implement.

### 3. Idiomatic phrasing in this repo

There are two established shapes (no command uses the literal phrase "logical
groups"; the granularity concept is always "commit after each (verified) phase"):

- **Terse one-liner** (work.md:93-95, 201-203): "Use the `/tce:commit` command to
  commit the research document. Since this is a docs-only commit, skip
  tests/typechecks."
- **Code-commit one-liner** (work.md:234): "Commit after each verified phase
  (using `/tce:commit` with full pre-commit checklist for code commits)".
- **Checkpoint rationale** (research.md:360-363, plan.md:596-599): "use the
  `/tce:commit` command to commit it / This ensures the … is saved as a
  checkpoint before moving to the … phase."
- **Detailed recipe** (quickfix.md:116-122, 147-152, 171-176): "**Immediately
  commit the <thing>** using the `/tce:commit` workflow:" + stage / message
  (formatted per convention, e.g. `docs([PREFIX]-XXXX): …`) / "docs-only commit —
  skip tests/typecheck/lint".

For implement's per-phase **code** commit, the natural fit is the work.md:234
form, optionally expanded with a short recipe (stage the phase's files + the
ticket file if its status changed; message per convention e.g.
`feat([PREFIX]-XXXX): <what the phase did>`; full pre-commit checklist).

### 4. Lock-step files (repo rule)

CLAUDE.md "Composite commands must track the single-step commands" lists
`implement` among the single-step commands whose changes require checking
`work.md` and `quickfix.md` in the same commit. Current state:

- `work.md:234` + `:260` already carry the per-phase commit instruction → after
  the fix, verify wording still matches implement's (likely no change needed, or
  a small tweak so it reads as a mirror, not the source of truth).
- `quickfix.md:185` asserts implement commits per phase → becomes accurate once
  implement actually does; verify the wording.

No other file needs the behavior. The status-file `### Commit` slot (116-118) and
its "if a commit was made" hedge (140) should be tightened to expect a commit.

### 5. Repo-specific wrinkle (noted, not in scope)

In *this* repo the "code" is markdown command files. `/tce:commit`'s docs-only
test (lines 25-28) classifies a commit touching only `.md` files as docs-only and
**skips validation** — so committing a change to `implement.md` itself would skip
`claude plugin validate`. That is a property of the docs-only heuristic, not of
TP-0009, and TP-0009's deliverable (the implement command text) is project-
agnostic. Out of scope here; flagged only so the implementer isn't surprised when
committing this very ticket's changes.

## Code References

- `plugins/tce/commands/implement.md:116-118` — passive `### Commit` status slot
- `plugins/tce/commands/implement.md:131,140` — record-hash rules ("if a commit was made")
- `plugins/tce/commands/implement.md:208-239` — Verification / Final Verification (no commit step)
- `plugins/tce/commands/commit.md:25-28` — docs-only vs code-commit determination
- `plugins/tce/commands/commit.md:30-40,44-48,59-82,86` — pre-commit checklist, staging review, message, no-push
- `plugins/tce/commands/work.md:234,258-260` — existing per-phase commit instruction
- `plugins/tce/commands/quickfix.md:185` — asserts per-phase commits via implement
- `plugins/tce/commands/research.md:360-363` / `plan.md:596-599` — checkpoint commit phrasing
- `CLAUDE.md` — "Composite commands must track the single-step commands"

## Open Questions

None requiring human judgment. The two ticket "Questions for Research/Planning"
are resolved by the findings above:
- **Reuse `/tce:commit` vs inline?** → Delegate to `/tce:commit`. Every other
  command does; inlining would duplicate the checklist and invite drift.
- **How must the composites change?** → `work.md` already instructs it (verify
  wording mirrors implement); `quickfix.md:185`'s assertion becomes true (verify
  wording). Likely small/no edits, but both must be checked in the same commit.

## tce Config Drift

None. `profile.md` (stack, commands `claude plugin validate`, code map) and
`tickets.md` (tmt backend) match the repo.
