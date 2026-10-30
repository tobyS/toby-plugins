# Dossier: TP-0045d — improvements collected from real orchestrator runs

## Summary

tce 1.7.0 closes the orchestrator improvements collector: an older project profile now gets a bold warning and the run carries on, three spots of Step 6 are tightened, the "for you to check" count now means list bullets, and every other routing row is moved to a sub-ticket, closed with a reason or dropped.

Criteria met 35/40 · fix rounds 1 · tests added 0 · decisions made for you 11 · for you to check 3

**Start here:** The planner's `Understood:` and `Approach:` lines sit at the top of the question dialog, not above it as criterion 25 says, because a message before the dialog failed in all 25 further runs across five wordings. That is your decision to accept. [`plugins/tce/references/work-loop.md:51-55`](https://github.com/tobyS/toby-plugins/blob/5ffe87667f4fb4469ac9507c84a85acfd8d1c323/plugins/tce/references/work-loop.md#L51-L55)

## What was built

`work.sh preflight` now compares the profile's `tce-config-version` with the plugin's and reports it on a new `profile:` line, and an older profile gets a three-line bold warning before the run continues. Anything that cannot be compared stays silent, and a failed environment check still prints only its refusal block. Step 6 of `work-loop.md` now names the artifact check after `challenge-fix` and `revise`, says which header `answers:` carries, and requires the planner's intro. `verifier.md` and `dossier-template.md` now count the same thing: one bullet per thing you have to do, and a criterion a bullet names is not met yet. Verification measured two obstacles: the warning reached the terminal in only 5 of 10 runs and the intro in 0 of 3, so the one fix round moved the warning's words and the instruction to print them into `preflight`'s output (10 of 10 interactive, 4 of 4 `-p`) and the intro into the dialog (9 of 9). No agent's return field or status changed, and the moved items are filed as TP-0045h, i, j and k.

Item outcomes:

- **A, progress lines:** nothing built. The terminal's own agent panel shows enough during a foreground dispatch, by your observation in the plan's question round (2026-10-30). Agent-sent lines are not possible: an agent's only channel is its final message, and the orchestrator is blocked meanwhile.
- **B, older profile:** shipped in `128caf8`, fixed in `413ca06`.
- **C, pull-request body:** closed with a reason. In GH-37 the orchestrator edited a copy before posting, following that project's `tickets.md` transition; tce's Step 10 posts the dossier as-is. The remaining gap moved to TP-0045j.
- **D, check count:** shipped in `5e3dfd3`.
- **E, artifact check after `challenge-fix`:** shipped in `bd91144` (the intent's "tick" changed to Build by you).
- **F, answer headers:** shipped in `bd91144` (same).
- **G, intro before the questions:** shipped in `bd91144` (same), fixed in `413ca06`.
- **H, design exploration in the intent:** moved to TP-0045h.
- **I, concerns across a session break:** moved to TP-0045i.
- **J, delivery and permalinks:** moved to TP-0045j.
- **K, model pins:** moved to TP-0045k.
- **L, enforcing "next ticket after merge":** dropped; no real run has asked for it, and the profile states it as your rule.

## Where to look

- [`plugins/tce/scripts/work.sh:124-130`](https://github.com/tobyS/toby-plugins/blob/5ffe87667f4fb4469ac9507c84a85acfd8d1c323/plugins/tce/scripts/work.sh#L124-L130): a deviation from the plan. The warning's words and an instruction to the model now live in the script's output, not in `work-loop.md`, because only that made the warning appear reliably. Plain prose in `preflight` is a new pattern for tce.
- [`plugins/tce/references/work-loop.md:215-219`](https://github.com/tobyS/toby-plugins/blob/5ffe87667f4fb4469ac9507c84a85acfd8d1c323/plugins/tce/references/work-loop.md#L215-L219): the rule that puts the intro inside the first question, with the exception stated below the byte-identical dialog guidelines. It departs from criterion 25's wording.
- [`plugins/tce/scripts/work.sh:58-99`](https://github.com/tobyS/toby-plugins/blob/5ffe87667f4fb4469ac9507c84a85acfd8d1c323/plugins/tce/scripts/work.sh#L58-L99): the first shipped script that reads `plugin.json` and compares versions. Every path that cannot compare reports `ok`, so a malformed marker gets no warning, by decision.
- [`plugins/tce/agents/verifier.md:126-130`](https://github.com/tobyS/toby-plugins/blob/5ffe87667f4fb4469ac9507c84a85acfd8d1c323/plugins/tce/agents/verifier.md#L126-L130): the judgment call you made, that defining a bullet removes an ambiguity and is not a contract change, under a ticket that rules out contract changes.
- [`plugins/tce/references/work-loop.md:228-238`](https://github.com/tobyS/toby-plugins/blob/5ffe87667f4fb4469ac9507c84a85acfd8d1c323/plugins/tce/references/work-loop.md#L228-L238): the artifact check at Step 6 (item E). Like item F's header rule, it was verified as text only, so its effect shows on the next real runs.

## Decided for you

- **`preflight` gains one labelled `profile:` line** — over a separate `work.sh` mode: no second call at Step 0, and the reader already reads by label.
- **Versions are compared part by part with `[ -lt ]`** — over `sort -V`: no new tool and it follows the numeric precedent at `work.sh:54`.
- **Anything that cannot be compared stays silent (no marker, `FILLED-BY-INIT`, unreadable file, or a marker newer than the plugin)** — over warning on those: the intent requires silence for no marker, and `/tce:init` has no path for a newer one.
- **A failed environment check prints only its refusal block, without the warning** — over printing both: TP-0045e measured that block as byte-identical and it must stay so.
- **`answers:` carries the header the dialog showed** — over the planner's original header: it is what the human answered, and the planner still has the order to match on.
- **The artifact check is named at both `challenge-fix` and `revise` in Step 6** — over `challenge-fix` only: both resume the planner inside the same loop.
- **Outcomes live in a new `## Item outcomes` section of this plan rather than inside `## Implementation Closeout`** — over the Closeout: its lines are fixed and written after the last phase, so no phase can fill it.
- **The new sub-tickets do not hold the epic open: its done check stays a to d, and each stub says so** — over the epic waiting for them: the intent closes this collector so the epic is not held up, and no session edits the epic's body.
- **Ticket boxes are ticked with no commit text added, including item A's** — over appending hashes as the ticket's own criterion words it: the exception covers ticks only, and `## Item outcomes` carries the commits.
- **tce goes to 1.7.0** — over 1.6.1: a new warning is new visible behaviour.
- **Item A leaves no text in the plugin** — over a README note about the panel: the intent asks for the reason on record, which `## Item outcomes` is.

## For you to check

- [ ] 3, 13, 40. Create the release tag — run `git tag -s tce--v1.7.0 413ca06635401ac1b56136d8ed44e99684936bf8 -m "tce 1.7.0"`, then `git tag --list 'tce--v*'` and `git tag -v tce--v1.7.0`; pass looks like `tce--v1.7.0` listed with a good signature, after which the done transition is due. It needs your personal signing key, which the sandbox denies. `413ca06` is the last commit touching plugin files, and it already says 1.7.0.
- [ ] 25. Decide whether the intro's place is acceptable — run `sed -n '/Understood/,$p' /Users/toby/code/work/toby-plugins/.git/tce/final/plan-d1.txt | tail -28`, or follow the plan's "Manual Testing Steps" 2; pass looks like you accepting the `Understood:` and `Approach:` lines at the top of the dialog, above the question, in place of the criterion's "above the dialog". It is your decision because phase 2's log records 25 failed runs of a message before the dialog; rejecting it means a new approach, not a text fix.
- [ ] 39. Read pull request 123's edit history — run `gh api graphql -f query='{repository(owner:"tobyS",name:"chat-sustainability"){pullRequest(number:123){lastEditedAt editor{login} userContentEdits(first:10){nodes{editedAt editor{login}}}}}}'`; pass looks like empty `lastEditedAt` and `userContentEdits` (nobody edited it after creation), and anything else is a web-UI edit, still outside tce, so row C's reason stands with that added. `gh` is denied in the sandbox.

## Concerns

- `gh` is denied in this sandbox, so the live body and edit history of pull request 123 are unchecked; a web-UI edit cannot be excluded. The read-only query is in the research document under item C.
- Claude Code hooks and sub-agents pages were read through an extraction model, so quotes may be slightly reworded; the changelog was read back only to about v2.1.290.
- E, F and G counts come from transcripts, with versions inferred from `plugin.json` at the run's time; they record what was written, not what the terminal rendered. Scratch runs may not be comparable.
- The research document's permalinks point at `cf5dec5`, on `main` but not yet pushed; they resolve once pushed. The same holds for this dossier's permalinks at `5ffe876`.
- Plan challenger's item 6: the delta says 1 risk but names none and the plan never uses the word; a person must confirm the risk in the full brief is backed by the plan.
- The ticket's "bumps and tags tce" box is ticked as the plan directs, but `tce--v1.7.0` does not exist until you run the tag command; the plan's Manual item tracks it.
- The ticket's "ticked with the commit" criterion is met through the plan's Item outcomes, not in the ticket, by the plan's decision to add no text there.
- `claude plugin tag --dry-run` refuses uncommitted release files, so it ran after the bump commit rather than before it; no fix round was used.
- Evidence is in `.git/tce/` (`int-*`, `op-*`, `m19-*` logs); the scratch project is deleted.
- Real `claude` sessions ran in the scratch project; the trust prompt was accepted there, and a transcript folder remains under `~/.claude/projects/` for that temp path.
- Criterion 25 says above the question dialog. The lines now sit inside the dialog, at the top, above the question, because 25 more runs never sent a message before it. You must accept this placement — see For you to check.
- The tag target moved from `ed4f286` to `413ca06` so the tag holds the fix. An agent reported the plan's For you to check command as still naming `ed4f286`; it has since been corrected, and the plan's `## Verification` and phase 5's log both name `413ca06`.
- Criterion 17's four labelled lines still hold, but an older profile now adds an unlabelled block after them (`plugins/tce/scripts/work.sh:124-130`).
- Create the tag (criteria 3, 13, 40); the done transition follows. Needs the personal signing key — see For you to check.
- Decide whether the intro lines at the top of the dialog, not above it, are acceptable (criterion 25). Rejecting means a new approach: phase 2's log records 25 failed runs of a message before the dialog — see For you to check.
- Read pull request 123's edit history outside the sandbox (criterion 39) — see For you to check.

## Artifacts

- Intent: `thoughts/shared/intents/2026-10-30-TP-0045d-orchestrator-improvements.md`
- Research: `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md`
- Plan: `thoughts/shared/plans/2026-10-30-TP-0045d-orchestrator-improvements.md` (its `## Verification` section holds the evidence per criterion)
