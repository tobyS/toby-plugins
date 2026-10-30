# TP-0045j: what delivery leaves behind

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-10-30
**Updated:** 2026-10-30

Sub-ticket of TP-0045 (the epic), moved out of TP-0045d. Not part of the epic's
done check, which names a to d.

## Problem Statement

Four gaps share one cause: delivery ends tce's view of the work, while the work
goes on changing.

- **Two owners of delivery.** In GH-37 Step 10 took Direct delivery (no
  `## Delivery` in the profile), while the project's `tickets.md` "complete"
  transition pushed and opened a pull request anyway.
- **A stale merge reference.** The Closeout recorded `direct: gh-37 @ ea06599`,
  which was stale after the squash merge.
- **Dead permalinks.** All 9 dossier links pointed at a branch commit that the
  squash merge left unreachable from main. tsf rewrites its links to the merge
  commit (TP-0039), but it merges itself; tce never sees the merge commit.
- **A posted body that goes stale.** Step 10 posts the dossier as-is and Step 12
  ticks only the plan, so under Pull request delivery the body and the committed
  dossier both show items as open after the human confirmed them.

### Evidence from GH-37

From TP-0045d's research, item C. Session `c054a8a7`, 2026-10-14, times UTC:

- 17:49:44: the orchestrator starts the `tickets.md` "complete" transition.
- 17:50:03: "The PR body copies the dossier, which still lists the checks and
  two concerns as open. I'm updating those lines in the PR body only; the
  committed dossier stays as written."
- 17:50:05-11: four edits on a scratchpad copy of the dossier.
- 17:50:14: `POST .../pulls` with that copy as the body, creating pull request
  123.

So the body was changed before posting, by the orchestrator, outside Step 10.
The human did not ask for it.

The same path came up again: on 2026-10-29 a session in the same project ran
`PATCH .../pulls/132` with a new body, a real edit after posting, from the main
session.

## Desired Outcome

It is settled which of Delivery and the backend's "complete" transition owns
delivery, and what the merge reference is when the backend delivers. Dossier
links keep resolving after a squash merge, or say plainly which commit they
mean. A posted body does not show confirmed items as open, or the human knows
why it does.

Options for the links to evaluate first, cheapest first:

1. Under Pull request delivery GitHub keeps the commits reachable through
   `refs/pull/<n>/head`, so `blob/<sha>` links most likely keep resolving after
   the branch is deleted. Not verified; verify before relying on it.
2. Under Direct delivery there is no such ref, so links would name the file at
   the base branch, or give `path:line` plus the SHA as text.

## Out of Scope

- tce merging anything: it never does.
- Enforcing "the next ticket starts only after the previous pull request is
  merged" (dropped in TP-0045d).

## References

- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` —
  findings 4 and 5, and finding 7's pull-request body item
- `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md` —
  "Item C: the pull-request body in GH-37", and "Items H to L"
- `plugins/tce/references/work-loop.md:287-312` — Step 10
- `plugins/tce/references/work-loop.md:348-353` — Step 12's "All pass"
- `plugins/tce/references/dossier-template.md:109-113` — the permalink rule
- `thoughts/shared/tickets/TP-0039-tsf-first-run-corrections.md` — tsf's link
  rewrite after a merge
