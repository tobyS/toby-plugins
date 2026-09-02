# TP-0030: Make the research drift check survive rewritten history (squash/rebase merges)

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-09-02
**Updated:** 2026-09-02

## Problem Statement

`/tce:implement` decides whether a research document still describes the current
codebase by comparing the commit recorded in the document's `git_commit`
frontmatter against `HEAD` (the "Repository state check" in
`plugins/tce/commands/implement.md`). That comparison assumes the recorded commit
stays reachable from `HEAD` — an assumption that holds only for history-preserving
merge commits.

Squash merges and rebase merges both rewrite history. Once the PR lands and the
source branch is deleted, the commit the research was written at no longer exists
in the mainline history, and after garbage collection (or on any fresh clone) the
object is absent entirely. The check's instruction has no branch for "the baseline
does not resolve": `git diff --stat <research_commit>..HEAD` fails with
`fatal: bad object`, and the command has nothing to fall back on, so the staleness
check is dropped without saying so — precisely in the situation where research is
most likely to be stale.

There is a milder second-order case as well: where the object still exists locally
as a dangling commit, the diff *succeeds* but reports the branch's own squashed
changes as drift, which is noise rather than signal.

The drift check is tce's only guard against implementing from research that
describes a codebase that has since moved. Losing it silently is worse than not
having it, because the command still reports the check as performed. In effect,
tce currently only works correctly on repositories that merge without rewriting
history.

## Desired Outcome

`/tce:implement` establishes research freshness — or explicitly reports that it
cannot — under any merge strategy. An unresolvable baseline is a named, visible
state with defined follow-on behaviour, never a silently skipped check and never
an errored git invocation.

## User Stories / Use Cases

- As a developer on a squash-merge repository, I want `/tce:implement` to still
  tell me whether the research is stale, so that I don't implement against a
  description of the codebase that no longer matches.
- As a developer picking up a ticket weeks later on a fresh clone, I want the
  command to say plainly that the research baseline is gone, so that I can decide
  whether to re-run `/tce:research` rather than trusting it blindly.
- As a tce maintainer, I want the check's behaviour specified for every history
  shape, so that the model doesn't improvise a different response on each run.

## Acceptance Criteria

- [ ] Before diffing, `/tce:implement` establishes whether the recorded baseline
      actually resolves in the current repository, and takes a defined path when it
      does not — no command is run that can fail with `fatal: bad object`.
- [ ] When the baseline is unresolvable, the command states this in its output,
      naming the research document and what it is doing as a consequence.
- [ ] The unresolvable case has a specified fallback that still yields a staleness
      judgment (or an explicit "cannot determine" plus heightened verification of
      the research's claims about the files being relied on). It is never treated
      as "no drift".
- [ ] The resolvable paths are unchanged: matching SHA ⇒ documents current;
      differing SHA ⇒ the existing diff-and-spot-verify flow; the same-session fast
      path still short-circuits.
- [ ] Verified in a scratch repository that reproduces the failure: research
      document committed on a branch, branch squash-merged into main and deleted,
      fresh clone, then `/tce:implement` — the check reports correctly instead of
      erroring or going quiet.
- [ ] Wherever the check is described (`implement.md`, plus any composite that
      re-describes it, per the composite-tracking rule in `CLAUDE.md`) the
      descriptions agree; if the research frontmatter contract changes,
      `references/research-document-template.md` and every producer
      (`research.md`, `quickfix.md`) change in the same commit.

## Out of Scope

- Prescribing or changing any project's merge strategy — tce adapts to the
  repository, not the reverse.
- Automatically re-running research, or repairing/rewriting stale research
  documents.
- Reworking `/tce:review`'s own frontmatter SHA (it records provenance and is not
  consumed as a drift baseline) — unless research shows it shares the same failure.
- Any tle change (tle has no drift check).

## Open Questions

- [ ] **Unresolved — decide before planning.** When the baseline genuinely cannot
      be recovered, should `/tce:implement` **stop and ask** the user (offering to
      re-run research versus proceeding), or **proceed with heightened
      spot-verification** behind a loud warning? Recommendation on the table:
      proceed-with-warning, matching the command's existing "spot-verify then
      continue" posture. Not yet confirmed by the ticket author.

## Questions for Research/Planning

- [ ] Which fallback baselines are available and reliable? Candidates worth
      evaluating: the commit that *added* the research file
      (`git log --diff-filter=A -1 --format=%H -- <research-file>`, robust because
      research documents are always committed); the frontmatter `date` /
      `last_updated` fed to `git rev-list -1 --before=<date> HEAD`; or recording a
      more durable anchor at research time.
- [ ] Is a probe such as `git cat-file -e <sha>^{commit}` the right resolvability
      test, and how should it treat dangling-but-present objects (where the SHA
      resolves locally yet the resulting diff is misleading post-squash)?
- [ ] Does anything besides `implement.md` read `git_commit` / `branch`, and does
      `plan.md`'s use of `last_updated` have an analogous weakness?
- [ ] Does the fix belong purely in the `implement.md` prose, or does it warrant a
      small shipped script under `plugins/tce/scripts/` (consistent with how tce
      ships helpers)?
- [ ] Which composite paths need mirroring — `work.md` currently omits the
      repository state check entirely. Is that intentional (its research and plan
      are same-session, so the fast path applies) or a second gap?

## References

- `plugins/tce/commands/implement.md:58` — the Repository state check
- `plugins/tce/references/research-document-template.md:11,25` — the frontmatter
  contract, including the note that `implement.md` reads `git_commit` / `branch`
- `plugins/tce/commands/research.md:251`,
  `plugins/tce/commands/quickfix.md:143` — the producers of the recorded SHA
- `CLAUDE.md` — "Composite commands must track the single-step commands"

## Implementation Plan

[To be filled when the plan is created.]

## Notes & Updates

### 2026-09-02

- Reported from a live session as "squashed-away research SHA breaking
  `/tce:implement`'s drift check — after a squash merge and branch deletion, the
  `git_commit` SHA in a research document's frontmatter is unreachable from main,
  so the drift comparison silently loses its baseline."
- Verified before writing: the drift check exists in exactly one place
  (`implement.md:58`); `work.md` does not re-describe it.
- Sized Medium because the fix requires designing a fallback baseline rather than
  a one-line edit, and may touch the research frontmatter contract, which has
  three producers and two consumers.
- The rewritten-history problem was framed during authoring as broader than squash
  merges: rebase merges rewrite commits too, so the reachability assumption fails
  for every non-merge-commit strategy.
- The Open Question (ask versus warn on an unrecoverable baseline) was raised but
  **not answered** before the ticket was written; it is recorded as a blocker for
  the planning phase.
