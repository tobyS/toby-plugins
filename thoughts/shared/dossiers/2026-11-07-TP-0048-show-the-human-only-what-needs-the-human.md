# Dossier: TP-0048 — show the human only what needs the human

## Summary

tce 1.8.0 asks every loop and intent question in prose. tce's five scripts move into the init/refresh allowlist so a reply in a later turn keeps running. A new read-only presenter agent writes every human-facing summary to the profile's new `## Presentation` preset, and research proposes standing rules from counted evidence.

Criteria met 41/53 · fix rounds 0 · tests added 0 · decisions made for you 17 · for you to check 5

**Start here:** the allow rule that every later-turn reply depends on ([`plugins/tce/commands/init.md:651-662`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/plugins/tce/commands/init.md#L651-L662)). It was proven only with `claude -p`, not in a trusted interactive session. Then the three intent criteria the plan's own decisions retire (eight block copies instead of nine, Full instead of byte-identical, the per-phase list kept under Full; see "For you to check").

All links are at `9ceac21a26cfdbe67287bfdfdf919fa85b37b298`.

## What was built

Seven commits (`04979a3`…`2c04a84`) changed 20 files outside `thoughts/` (+1190/−425). `work-loop.md` and `/tce:intent` no longer use AskUserQuestion. Questions, the plan approval and Step 12's closing check are prose that ends the turn. `/tce:init` and `/tce:refresh` now offer one `Bash(...)` rule per shipped script. A marketplace install gets the corrected wildcard `<home>/.claude/plugins/cache/*/tce/*/scripts/<x>.sh *`. The intent's shape `…/plugins/*/tce/scripts/…` was denied on a real run. The new `presenter` agent (`Read, Grep, Glob, LS`) writes the plan brief, the push-back delta, the dossier summary and the intent summary. It follows `work-brief.md`'s contract: the always-shown items, exceptions, three likely push-backs, and a line budget whose overflow is named by topic. The plan challenger gained `mode: brief`, a five-point check of the presenter's brief, bounded to one round. Its old item 6 was removed. The planner lost its own `mode: brief`. Research documents gained `## Practice candidates`. The planner asks about them as one `Practices` item, and the orchestrator appends accepted rules under `## Standing rules` in CLAUDE.md and declined ones in a profile section. `/tce:refresh` gained a read-only mining pass through `tce:thoughts-analyzer`. The release is tce 1.8.0. Its tag was handed over, not created.

## Where to look

- [`plugins/tce/commands/init.md:651-662`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/plugins/tce/commands/init.md#L651-L662) — the script allow rules. They are the riskiest part: a rule that does not match puts a permission prompt after every prose reply, and only the `claude -p` probe has exercised the form.
- [`plugins/tce/commands/refresh.md:161-184`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/plugins/tce/commands/refresh.md#L161-L184) — refresh's new allowlist re-offer, a widening of tce's sanctioned `settings.json` edit. Refresh's in-sync early stop was changed so the re-offer still runs.
- [`plugins/tce/references/work-loop.md:229-252`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/plugins/tce/references/work-loop.md#L229-L252) — Step 6's new order: challenge, present, brief check, print, then approve in prose. This is the loop's control flow, and the approval now ends the turn.
- [`plugins/tce/references/work-loop.md:255-270`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/plugins/tce/references/work-loop.md#L255-L270) — the orchestrator writes to the project's CLAUDE.md and profile. It is a new, externally visible write to a file every session loads.
- [`plugins/tce/references/work-brief.md:198-209`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/plugins/tce/references/work-brief.md#L198-L209) — the budget rule. Decisions are never cut, which is why this plan's Compact brief came out at 27 lines against a budget of 20.
- [`plugins/tce/agents/presenter.md:21-30`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/plugins/tce/agents/presenter.md#L21-L30) — the new agent's read-only envelope. It now authors everything the human reads.
- [`CLAUDE.md:427-432`](https://github.com/tobyS/toby-plugins/blob/9ceac21a26cfdbe67287bfdfdf919fa85b37b298/CLAUDE.md#L427-L432) — where the "absent section = byte-identical" guarantee is relaxed for `## Presentation`. It deviates from the intent and from the guard every other agreed section keeps.

## Decided for you

- **Step 12's closing check also becomes a prose question** — over keeping its dialog: the intent's criterion requires no AskUserQuestion site in `work-loop.md`.
- **Under Pull request delivery, `git push` and `gh pr create` may prompt once after a prose approval** — over allowlisting them: the intent keeps "never `git push`, never `gh`" as the allowlist's guard.
- **The brief drops "Decisions for you"; a question that arises while writing returns `needs decision` and is asked as a prose round** — over keeping a second in-brief ask path: the questions-first round covers it, and the presenter does not own questions.
- **On push-back the planner returns a one-line-per-change list, and the presenter renders the delta from it and the plan** — over the presenter diffing two plan versions: the presenter is read-only without `git`.
- **The planner's `mode: brief` is removed; position row 8 dispatches the presenter** — over keeping a planner-written brief for resumed runs: one author of human-facing text.
- **New `step:` values `present` and `brief-check`; the presenter may write a body** — over reusing `brief` and `challenge`: the orchestrator tells the returns apart by `step:`.
- **The brief check runs on plan briefs and deltas only, not on the intent or dossier summaries** — over checking every presentation: the intent scopes the check to the plan.
- **After the one brief-check round, the brief is printed with any remaining fail lines under "Challenger notes:"** — over stopping the run: the intent bounds the check to one round and a stop would cost an approval for a wording issue.
- **`/tce:quickfix`'s not-small stop reads the phase total from `stage.sh`'s `progress:` line** — over the brief's `Phases:` line: Compact drops it.
- **`/tce:intent` writes and commits the intent after its last question round, then presents it; corrections rewrite it in place** — over a separate "ready to write?" round: the presenter's return is the human's check.
- **`/tce:intent` dispatches the presenter without the foreground preflight** — over requiring the two environment variables: the presenter dispatches nothing itself, so a background run only delays its single result.
- **Guided asks four things — line budget, items shown per touchpoint, the sample on or off, formatting — and writes a Custom section** — over a free-form description: the presenter needs the same sub-fields under every preset.
- **The preset choice in `/tce:init` uses its existing AskUserQuestion dialog style** — over prose: init keeps its block, and three fixed options fit a dialog.
- **Practice candidates come from the documents the researcher's thoughts pass already reads for this ticket, counted once per ticket, two tickets minimum** — over scanning every intent and plan on each research run: the full scan is `/tce:refresh`'s catch-up.
- **The orchestrator appends accepted rules under a `## Standing rules` heading at the end of the project's CLAUDE.md and writes declined ones into a hand-authored `## Declined standing rules` profile section** — over agents writing them: agents write only under `thoughts/shared/`.
- **`/tce:refresh` gains an allowlist re-offer and a read-only mining pass through `tce:thoughts-analyzer`** — over leaving both to `/tce:init`: the intent assigns both to refresh, and refresh still never writes under `thoughts/`.
- **Release as tce 1.8.0** — over 2.0.0: no config file breaks; new behaviour is a minor bump, as for 1.5.0, 1.6.0 and 1.7.0.

## For you to check

- [ ] 2, 3, 6. Confirm that the plan's *(yours)* decisions retire three intent criteria as they are worded. First, there are eight block copies, not nine. Second, no section means the Full preset through the presenter, not output byte-identical to 1.7.1. Third, Full keeps the per-phase list, so "no per-phase list" holds only under Compact and Guided. If you accept, say so, and amend the intent's criteria if you want them to match. If not, that is a fix round. Pass looks like your explicit OK. This is your decision, not something a run can show.
- [ ] 1, 18, 23, 35, 41. In a scratch consuming project, trusted and interactive, start `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 BASH_DEFAULT_TIMEOUT_MS=600000 claude --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce` and run `/tce:init`.
  - Pass for init: it offers the five `Bash(<plugin root>/scripts/<x>.sh *)` entries and the Compact / Full / Guided choice. Compact writes its seven sub-fields; Guided asks four questions and writes **Custom**.
  - Then run `/tce:intent <ID>` on a small ticket. Pass: one question round, then the intent is written and the presentation printed, with no draft.
  - Then run `/tce:work <ID>` and answer the planner's questions and the approval in later turns. Pass:
    - no AskUserQuestion box;
    - no permission prompt until the dossier summary (note whether the `tce:commit` Skill call or the planner's `SendMessage` resume prompted);
    - a Compact brief of about 20 lines (a plan with many decided-for-you lines may go over, as the contract allows);
    - a closing summary with the dossier path, counted facts, pending items and exceptions.
  - Why you: a project's allow rules apply only in a trusted folder, which `claude -p` in a scratch directory is not (TP-0045g), and the dialog and the prompts only show up interactively.
- [ ] 48. In a consuming project where two tickets' intents or plans share a decision, run `/tce:research <third ID>`. Pass looks like this:
  - the research lists the decision under `## Practice candidates` with "2 tickets: <IDs>";
  - the planner asks `Practices` once;
  - accepting appends one line under `## Standing rules` in CLAUDE.md, and declining adds it under `## Declined standing rules`;
  - a later research run does not propose it again.

  Why you: it needs a multi-ticket project and interactive answers.
- [ ] 49. Run `/tce:refresh` in this repository. Pass: the standing-rule catch-up prints a numbered draft list mined from `thoughts/shared/intents/` and `thoughts/shared/plans/`, and nothing is written under `thoughts/`. Expect items such as "never widen the allowlist" to be left out, because CLAUDE.md already states them. Decline everything if you only want to look. Why you: refresh is interactive, and it edits the profile and `settings.json` once you approve.
- [ ] 10, 53. Outside the sandbox, run `git tag -s tce--v1.8.0 2c04a84 -m "tce 1.8.0"` on the bump commit (HEAD has moved past it), then `git tag -v tce--v1.8.0`. Pass: a good signature, and `git tag --list 'tce--v*'` shows `tce--v1.8.0`. Why you: the signing key is not reachable from the sandbox.

## Concerns

- Allowlist (`init.md`, `refresh.md`): the startup wildcard warning and project-settings matching in a trusted folder were not verified interactively. The probe used `claude -p` with `--settings`.
- Research (`bin/` fallback, not taken): the `bin/` support version, v2.1.91, comes from a release-notes mirror, not from the official changelog.
- `work-loop.md` Step 12: its dialog also became prose, because of the criterion "no AskUserQuestion site in `work-loop.md`".
- Untested: whether the Skill call to `tce:commit` prompts after a prose reply. The real-run check covers it.
- Untested: whether a planner resume or the `tce:commit` call in a later turn prompts. Phase 1's manual run checks this.
- `.claude/tce/profile.md` (this repo): the version marker says 1.7.0, but the plugin is now 1.8.0. `/tce:refresh` or `/tce:init` fixes it. Two agents returned this concern.
- Intent: its criterion "a profile without the section is byte-identical to 1.7.1" is superseded by the Full preset decision.
- `refresh.md`: refresh used to stop early when the profile was in sync. That path now jumps to the new Script allowlist step at the end of Phase 3, so the re-offer always runs.
- Brief-layout span: between Phase 3 and Phase 4 the span sat across two commits. `work-brief.md`'s brief template had already lost "Decisions for you" while `planner.md` and Step 6 still mentioned it. Phase 4 completed the span, as the plan scoped it.
- Step 6 and the `/tce:quickfix` lane: "Decisions for you" is gone, so a question that comes up mid-write is asked as a prose round.
- Step 6 brief check: it re-runs once after the presenter's fix, so the remaining fail lines are real ones. It still counts as one fix round.
- Intent criteria 2, 3 and 6 are not met as the intent words them. The plan's *(yours)* decisions retire them, so confirm them or reopen.
- The interactive consuming-project run of init, intent and work is still unchecked (criteria 1, 18, 23, 35, 41).
- Practice candidates have not been checked end to end across two tickets (criterion 48).
- Run `/tce:refresh` in this repo to see its mined draft list (criterion 49).
- The signed tag `tce--v1.8.0` on `2c04a84` still has to be created outside the sandbox (criteria 10, 53). Phase 7's log records it as handed over, not created.

## Artifacts

- Intent: `thoughts/shared/intents/2026-11-07-TP-0048-show-the-human-only-what-needs-the-human.md`
- Research: `thoughts/shared/research/2026-11-07-TP-0048-show-the-human-only-what-needs-the-human.md`
- Plan: `thoughts/shared/plans/2026-11-07-TP-0048-show-the-human-only-what-needs-the-human.md` (its `## Verification` section holds the evidence per criterion)
