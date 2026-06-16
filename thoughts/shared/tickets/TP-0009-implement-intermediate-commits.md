# TP-0009: /tce:implement makes no intermediate commits

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-06-16
**Updated:** 2026-06-16

## Problem Statement

`/tce:implement` executes an approved plan phase by phase but never actually
commits anything. It only *records* a commit hash in the per-phase `### Commit`
slot of the status file ("the commit hash **if** a commit was made") and tells
the agent to run tests at verification points — it never instructs the agent to
make a commit. As a result, a full multi-phase implementation can land as one
giant uncommitted (or single-commit) working tree, losing the per-phase history
the workflow was designed around.

Archaeology (recorded for context, see Notes): this is not a deleted
instruction. The bare original template (`fb68d34`) had no commit handling at
all. The status-file format with a per-phase `### Commit` slot arrived in
`62e9a81` ("merge workflow improvements"), carried over from the upstream
template — but the imperative to actually commit per phase was never written
into this repo's lineage. The recording slot survived; the action instruction
was never there.

This regresses the intended behavior (per-phase commits) that the upstream
template assumed, and it now also needs to align with TP-0008 (configurable
commit convention) and the existing `/tce:commit` skill.

## Desired Outcome

When `/tce:implement` runs, it commits work in logical groups as it goes,
validating the relevant tests before each commit, using the project's configured
commit convention — and the status file's per-phase `### Commit` slot reflects
real commit hashes.

## User Stories / Use Cases

- As a developer running `/tce:implement`, I want each logical group of changes
  committed as it completes so that I get reviewable, revertable history and
  don't end up with one undifferentiated diff at the end.
- As a developer resuming a partially-implemented plan, I want completed phases
  to already be committed so that the status file's recorded hashes are real and
  I can trust what's done.
- As a developer, I want tests validated *before* each commit (not only at the
  very end) so that no commit captures a known-broken state.

## Acceptance Criteria

- [ ] `/tce:implement` commits in **logical groups** — typically one commit per
      plan phase, splitting finer when a phase contains independent units of
      work. (Granularity decision: per logical group, not strictly per phase.)
- [ ] Before each commit, the implementer runs the relevant test / lint /
      typecheck suites (per `profile.md`) and only commits when they pass; a
      failing suite blocks the commit and is surfaced, not silently committed.
- [ ] Commit messages use the project's **configured commit convention** (read
      from `profile.md` per TP-0008) — no hardcoded Conventional Commits.
- [ ] Each commit's hash is recorded in the status file's existing per-phase
      `### Commit` slot, and the "if a commit was made" hedge is replaced with a
      definite expectation that commits happen.
- [ ] The existing "Final Verification Before Closing a Ticket" full-suite run
      is preserved (it complements, does not replace, the per-commit checks).
- [ ] The ticket-status transition (e.g. `In Progress` / `Done`) is committed
      together with the related work, consistent with the current status policy.

## Out of Scope

- Asking the user for a commit-frequency preference during `/tce:init` and
  storing it in `profile.md` — split into its own ticket (TP-0010).
- Changing the commit-convention mechanism itself (delivered by TP-0008).
- Any change to `/tce:commit` as a standalone command beyond possibly being
  referenced for its pre-commit-check logic.

## Open Questions

None — well understood.

## Questions for Research/Planning

- [ ] Should the per-commit pre-checks **reuse the `/tce:commit` skill's**
      existing pre-commit-check logic (tests/typecheck/lint from profile +
      convention-formatted message) to avoid drift, or inline an equivalent in
      `implement.md`? Commands don't read each other's markdown at runtime, so
      reuse means describing the same steps — weigh duplication vs. a shared
      mechanism.
- [ ] Per the CLAUDE.md "Composite commands must track the single-step commands"
      rule: how must `/tce:work` and `/tce:quickfix` be updated to mirror the new
      commit behavior? They must change in the same commit as `implement.md`.
- [ ] How to phrase the commit step so it respects the project's commit
      convention and the `.claude-commit` file workflow without becoming
      stack-specific.

## References

- `plugins/tce/commands/implement.md` — status-file format (`### Commit`),
  Verification Approach, Final Verification, Ticket Status Transitions.
- TP-0008 — configurable commit convention (`profile.md`).
- `/tce:commit` skill — existing pre-commit checks + convention-formatted message.
- Original template `fb68d34:.claude/commands/implement_plan.md` (no commits);
  `62e9a81` introduced the status-file `### Commit` slot.
- CLAUDE.md — "Composite commands must track the single-step commands".

## Implementation Plan

## Notes & Updates

### 2026-06-16

Created from a regression report: `/tce:implement` performs no intermediate
commits. Git archaeology established that the imperative commit instruction was
never present in this repo's lineage (only a status-file recording slot, added in
`62e9a81`), so this is a "never-written" instruction rather than a deleted one.

Decisions made at ticket creation:
- Commit granularity: **per logical group** (one commit per phase, finer when a
  phase has independent units) — not strictly one-per-phase.
- The commit-frequency-at-init idea is split into a separate ticket (TP-0010)
  rather than folded into this one.
