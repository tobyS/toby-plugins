# Dossier: TP-0045c — stage 2 — the single-step commands and quickfix on the shared agents

## Summary

`/tce:research`, `/tce:plan`, `/tce:implement` and `/tce:quickfix` are now thin lanes over one shared loop (`references/work-loop.md`) that dispatches the TP-0045b step agents, every step command and `/tce:work` also accept a ticketless intent path, quickfix starts from an autonomously written intent instead of a ticket, and tce ships as 1.5.0.

Criteria met 67/67 · fix rounds 1 · tests added 0 · decisions made for you 12 · for you to check 0

**Start here:** the Entry, which decides between a ticket run and a ticketless run, and the new first position row, which keeps a standalone `/tce:implement` deliverable under Pull request delivery. Every lane depends on both. [`plugins/tce/references/work-loop.md:74-88`](https://github.com/tobyS/toby-plugins/blob/9d6e8967b98809604e16434779d6c99f68dee274/plugins/tce/references/work-loop.md#L74-L88), [`plugins/tce/references/work-dispatch.md:48`](https://github.com/tobyS/toby-plugins/blob/9d6e8967b98809604e16434779d6c99f68dee274/plugins/tce/references/work-dispatch.md#L48)

## What was built

`work.md`'s Steps 0–12, its invariants and its AskUserQuestion block moved into the new `references/work-loop.md`, parametrized by `<command>` and `<ID>` (ticket ID or intent slug). Each step command now only declares a lane: the position rows it starts from, the steps it runs, and what it prints for any other row. Every command is 41–87 lines, and the step working lives only in the agents and the loop file. The agents accept `ticket: none` and name ticketless documents `YYYY-MM-DD-<slug>.md`, which the existing `stage.sh` and `ticket.sh` find from the bare slug with no script change. `/tce:intent --autonomous` writes a ticketless intent or returns `insufficient: <part> — …`. Quickfix runs research → planning without approval → implement → verify → dossier → closeout, and stops when the brief shows more than two phases or the planner asks the design-exploration question. `implement_eco.md` and `/tce:ticket --autonomous` are gone. In CLAUDE.md the composite-tracking rule is removed, the gate, branch, re-read and orchestrator spans are re-pointed, and the AskUserQuestion block dropped from 13 copies to 10. The real run was headless `claude -p` in a scratch consuming project: a FAKE ticket step by step, an interrupted implement resumed, quickfix on a typo and on an oversized change, and the preflight and free-form refusals.

## Where to look

- [`plugins/tce/references/work-loop.md:250-262`](https://github.com/tobyS/toby-plugins/blob/9d6e8967b98809604e16434779d6c99f68dee274/plugins/tce/references/work-loop.md#L250-L262): the *no delivery* variant and the row-1 delivery path. A wrong Merge reference here either strands work or reports it as done when it was never delivered.
- [`plugins/tce/commands/intent.md:411-415`](https://github.com/tobyS/toby-plugins/blob/9d6e8967b98809604e16434779d6c99f68dee274/plugins/tce/commands/intent.md#L411-L415): the slug-uniqueness glob, the only guard against slug collisions. Ticketless intents written by the interactive `/tce:intent` check only `intents/`, so a collision there goes unnoticed (accepted risk in the plan).
- [`plugins/tce/commands/quickfix.md:61-69`](https://github.com/tobyS/toby-plugins/blob/9d6e8967b98809604e16434779d6c99f68dee274/plugins/tce/commands/quickfix.md#L61-L69): the not-small stop. It is a judgment threshold (more than 2 phases) read from the brief, with no size field in any agent return.
- [`plugins/tce/commands/quickfix.md:39-45`](https://github.com/tobyS/toby-plugins/blob/9d6e8967b98809604e16434779d6c99f68dee274/plugins/tce/commands/quickfix.md#L39-L45): quickfix no longer refuses on `tickets.md`'s ticket-creation policy. This differs from the ticket's acceptance criterion and follows your decision (see Concerns).
- `CLAUDE.md` (357 changed lines): the rewritten spans are where future edits will be steered. Its span file names were checked for existence, but its wording has not been reviewed beyond that.

## Decided for you

- **The loop's file is a new `references/work-loop.md`, and `work-dispatch.md`/`work-brief.md`/`agent-returns.md` keep their names** — over merging everything into one file or renaming the `work-*` family: the agents already read those three by name, and the step sequence is a separate concern from payloads and layouts.
- **Each command declares a lane (start rows, steps, stop point) in its own body; `work-loop.md` holds the steps** — over one parametrized "mode" table inside `work-loop.md`: a command stays readable on its own, and the lane is the only per-command text.
- **`/tce:plan` refuses without research and points to `/tce:research`; `plan.md`'s Step 2 (planning without research) is dropped** — over carrying it: the planner requires research, and `/tce:work` already does.
- **`implement.md`'s own design-exploration check is dropped** — over keeping it: the planner's `questions` mode asks it before any plan exists.
- **Invoking `/tce:implement` on a written but unstarted plan counts as approval** — over running the brief and approval dialog again: the human approved the plan by asking for implementation; `/tce:plan` owns approval.
- **`/tce:research` on a ticket whose research exists reports the path and the next command and stops** — over re-running the researcher: a re-run would write a second research document; deleting the old one is the human's call.
- **Standalone `/tce:implement` under Pull request delivery writes `undelivered: <branch> @ <sha>` as the merge reference, and a new first position row sends `/tce:work` to delivery for it (the old rows 1–9 become 2–10)** — over recording `direct:`: the work stays deliverable by `/tce:work` instead of being reported done.
- **A ticketless closeout's ticket line reads `none (ticketless intent)`, and the `git log --grep` base-commit fallback is skipped** — over inventing an ID: a slug in commit messages is not guaranteed.
- **Autonomous `/tce:intent` checks slug uniqueness with a Glob over `thoughts/shared/**/*<slug>*`, not with `ticket.sh`** — over calling the script: a Skill-invoked skill's `allowed-tools` reaching its caller's turn is undocumented.
- **`/tce:ticket` stays unflagged with its quickfix edge gone; `research`, `plan` and `implement` stay unflagged with no Skill caller left** — over flagging them: the intent keeps them as delegation targets, and flagging would change behaviour this ticket does not ask for.
- **`branch.sh switch`'s `missing` detail names `/tce:intent` instead of `/tce:research`** — over leaving the stale text: `/tce:research` no longer creates branches.
- **tce goes to 1.5.0** — over 1.4.4: new input form (intent paths) and a removed command.

## For you to check

None.

## Concerns

- `plan-document-template.md` header, implementation-time note and UI/UX note were also re-pointed from `/tce:plan` and `implement.md` to the agents, beyond the lines the plan listed.
- `plan-document-template.md` header named only the planner agent as reader while the old `/tce:plan` still read it until Phase 3 (transient; Phase 3 rewired `/tce:plan`).
- `dossier-template.md` header also re-pointed from `work.md` to `work-loop.md`, beyond the listed files.
- `work-loop.md` Step 4 gained lane gating (start rows, otherwise line), which the Lanes section needs but the plan did not list.
- `quickfix.md` still Skill-delegated to `tce:plan` and `tce:implement` between Phases 3 and 4, which then ran the preflight and the approval dialog (transient; Phase 4 rewrote it).
- `branch.sh` header comments re-pointed to the new callers, beyond the plan's listed detail line.
- Quickfix prints `/tce:work` with the intent path wherever the loop prints a re-run line, because a quickfix re-run would write a second intent.
- Autonomous intent omits the `source:` line as the intent template says to; the plan said `source: none`.
- README quickfix wording that called it fully autonomous was left for Phase 5 (Phase 5 rewrote it).
- `claude plugin tag` failed to sign (key path blocked by the nono sandbox). The signed tag `tce--v1.5.0` was made with `git tag -a` on the bump commit `67b7dd2`, with the agent key, not the key earlier tags used.
- The research template's step numbers were re-pointed to the researcher's Process steps (they were off by one), and the CLAUDE.md `implement_eco` mention was reworded to satisfy the phase grep (Phase 5 log).
- The real run (all six Phase 6 Manual items) was not done in an interactive session in a real project. The verifier ran it headless (`claude -p`) in a scratch consuming project, and all six were met there.
- Headless `claude -p` did not apply a step command's `allowed-tools` to the absolute-path script call, so the grants had to be passed on the CLI.
- Autonomous `/tce:intent` printed prose before its `insufficient:` line, but the mode requires exactly one return line.
- The preflight refusal was paraphrased by the model instead of printed as the fixed block.
- An interruption right after a phase commit left the plan's log edit uncommitted, and the next phase's feature commit absorbed it.
- Criterion 53's example expects `insufficient: anchor`. The vague input correctly yields `scope`, which is the first failing part per `intent.md`; a separate anchor-only input yielded `anchor`.
- Criterion 3 (ticket: quickfix refuses on the `tickets.md` policy) conflicted with intent criterion 18. You decided the intent wins: "We follow the intent. If people call quickfix, they agree on autonomous creation of the intent and no ticket is touched."

## Artifacts

- Intent: `thoughts/shared/intents/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
- Research: `thoughts/shared/research/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
- Plan: `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md` (its `## Verification` section holds the evidence per criterion)
