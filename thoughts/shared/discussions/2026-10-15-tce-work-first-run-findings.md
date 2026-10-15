---
date: 2026-10-15
topic: "The first real /tce:work run (GH-37, chat-sustainability) — findings"
status: complete
---

# The first real `/tce:work` run — findings

The epic's b→c gate (TP-0045b): one real ticket through the orchestrating
`/tce:work`. Ticket GH-37 in chat-sustainability ("chat export and per-answer
copy button", 4 phases, design exploration included) ran from intent to the
merged pull request #123 under tce 1.4.2, across four invocations with two
intentional interrupts. Sessions: `d4ab9499` (ticket + intent), `fc6359bb`
(first `/tce:work`), `ed764eea` (`/tce:design_explore`), `c054a8a7` (resumed
`/tce:work` to the merge). Reviewed by a fresh-context agent from the
transcripts and the resulting artifacts; this document records the findings
and the human's decisions on them. Items marked **→ TP-0045d** are for that
collector; the human ticks them into it.

## What worked

- The position was derived correctly from disk on all four invocations —
  including a mid-planning interrupt and the resume after `/tce:design_explore`.
- 17 agent returns, all with a readable `tce-return` block, 0 retries; no
  document was pasted into a prompt.
- The plan challenger caught a real brief-vs-plan mismatch (a "rejected"
  alternative the plan did not contain); one `challenge-fix` round closed it.
- The verifier proved 19 manual items in the browser and escalated only the 3
  that need Word or Google Docs.
- Per-phase logs, commits and `stage.sh` progress were exact (1→4/4); 95 tests
  added; CI green on the first ready-for-review.

## Fixed inside TP-0045b

- **`thoughts/CLAUDE.md` blocked tce's directories.** The claude-template's
  `thoughts/CLAUDE.md` forbids directories it does not list; `intents/` stopped
  `/tce:intent`'s commit and `dossiers/` the verifier's dossier step, both
  patched by hand during the run. `/tce:init` also never scaffolded
  `dossiers/`. Fixed in tce 1.4.3: init scaffolds `dossiers/`, detects such a
  rules file and proposes the missing entries on approval.

## Findings for later

1. **Design exploration belongs in the intent phase. → TP-0045d** The planner
   raised "stop for `/tce:design_explore`?" as question 1 of 8; the human chose
   stop, the run ended without asking the other 7, and that planner run
   (112k tokens) was wasted. Human decision: move the design-exploration check
   into `/tce:intent`, which records the outcome (the `DECISION.md` path, or
   "plan directly"); the planner follows it and asks only for older intents.
   Two related defects from the same run: `/tce:design_explore` named the
   mockup folder without the ticket ID (`ticket.sh` cannot find it) and left
   `DECISION.md` uncommitted.

2. **How questions are asked. → TP-0047** Plan approval and the closing check
   were asked in prose instead of AskUserQuestion, so the run spanned four
   turns. Human decision: prose is often better when a question needs context;
   leave the form to the agents and let the profile describe the communication
   style. TP-0047 covers both, including loosening `/tce:work`'s invariant 5.

3. **Profile older than the plugin goes unnoticed. → TP-0045d** The profile
   was still at config 1.2.0 (no `## Delivery`, no `## Reader`) under tce
   1.4.2. The research drift check did not flag it, because it compares the
   profile with the *repository* (stack, commands, code map, ticket backend),
   never with the *plugin version*; the version comparison exists only in a
   `/tce:init` re-run. Proposal: `work.sh preflight` compares the profile's
   `tce-config-version` with the plugin's version and refuses with "run
   `/tce:init`" when the profile is older.

4. **Delivery vs the ticket backend's completion step. → TP-0045d** With no
   `## Delivery`, Step 10 took Direct, while the project's `tickets.md`
   "complete" transition pushed and opened a pull request anyway. The Closeout
   recorded `direct: gh-37 @ ea06599`, stale after the squash merge. Settle
   which of the two owns delivery, and what the merge reference is when the
   backend delivers.

5. **Dossier permalinks die after a squash merge. → TP-0045d** All 9 links
   point at a branch commit that the squash merge left unreachable from main.
   tsf fixes this by rewriting its links to the merge commit after merging
   (TP-0039) — possible because the factory merges itself. tce never merges,
   so it never sees the merge commit; rewriting would need a post-merge step
   the human triggers. Cheaper options to evaluate first:
   - Under Pull request delivery GitHub keeps the pull request's commits
     reachable through `refs/pull/<n>/head`, so `blob/<sha>` links into them
     most likely keep resolving even after the branch is deleted. Not verified
     (the review session's sandbox could not run `gh`); verify before relying
     on it.
   - Under Direct delivery there is no such ref; links would have to name the
     file at the base branch, or `path:line` plus the SHA as text.

6. **Concerns are lost across a session break. → TP-0045d** Concerns live only
   in the orchestrator's conversation until the dossier dispatch, so the
   researcher's "4 web sources blocked by the sandbox" never reached the
   dossier after the resume. Durable fix: every agent writes each concern into
   its own artifact as well — the research document, the phase log's
   `**Issues**` line, `## Verification`, the plan's `## Decisions`/risk — and
   the verifier's dossier mode collects them from disk. The return's
   `concerns:` stays as the in-run signal but is no longer the only copy.

7. **Small contract misses. → TP-0045d**
   - No `work.sh artifact` check after `challenge-fix`.
   - Answer headers in the `mode: write` payload differed from the dialog's
     12-character headers.
   - The pull-request body was edited after posting, so it no longer matches
     the committed dossier.
   - The orchestrator printed no `Understood:`/`Approach:` intro before the
     planner's questions.
   - The dossier's "for you to check" count (2) differed from the verifier's
     (3) because two items were merged.

8. **The allowlist was not exercised.** The human runs every session in a nono
   sandbox with bypass permissions, so no prompt could occur. Decision: not
   tested further; act on a bug report if one comes.

## Cost

[Filled from the cost comparison below.]
