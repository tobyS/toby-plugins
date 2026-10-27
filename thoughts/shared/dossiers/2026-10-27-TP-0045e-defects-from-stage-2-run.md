# Dossier: TP-0045e — defects found in the stage-2 verification run

## Summary

tce 1.5.1 fixes the four defects TP-0045c's headless run found: the autonomous intent now prints only its return line and quickfix reads it by an explicit rule, the preflight refusal is a fixed block printed as the whole reply, the script grants are unquoted so they match headless, and an implementer re-run commits a stray plan-log edit on its own before doing phase work.

Criteria met 34/34 · fix rounds 3 · tests added 0 · decisions made for you 10 · for you to check 0

**Start here:** Phase 5 used all 3 of its fix rounds and changed text the plan had not specified: quickfix's intent hand-off (with the matching sentence in `intent.md`) and the wording of Step 0's refusal. Both were only checked with a few headless runs each. [`plugins/tce/commands/quickfix.md:37-57`](https://github.com/tobyS/toby-plugins/blob/aa782a43c02d563f997efa0758305e05ba89d41b/plugins/tce/commands/quickfix.md#L37-L57), [`plugins/tce/references/work-loop.md:90-104`](https://github.com/tobyS/toby-plugins/blob/aa782a43c02d563f997efa0758305e05ba89d41b/plugins/tce/references/work-loop.md#L90-L104)

## What was built

The headless grant issue was investigated first, on Claude Code 2.1.310. A grant with quotes inside the pattern (`Bash("${CLAUDE_PLUGIN_ROOT}/scripts/x.sh":*)`) matched only calls where the model had quoted the script path. Calls with the path unquoted were denied under `claude -p` and prompted interactively. The unquoted form matched both kinds of call. So all 30 script grants in the nine tce commands, plus the example in `CLAUDE.md`, were unquoted, and the README gained a "Headless runs" note. Step 0's refusal lost its `<command>` placeholder and gained a rule that makes the block the entire reply. The autonomous intent's output rule now covers its whole output. Quickfix decides on the last line starting `intent:` or `insufficient:`, checks an `intent:` path with `work.sh artifact`, and stops with a fixed message when neither prefix appears. Phase 5's reproductions found two more problems, and both were fixed in that phase. First, the refusal was still paraphrased or put in a code fence. Second, quickfix ended its turn on the intent's line instead of acting on it. After the fixes: 15/15 refusals byte-exact and 3/3 quickfix stops exact. Defect 4 is solved by a new step 0 in the implementer, and its reproduction (an interrupted state built by hand) produced a separate docs-only commit before phase 2's feature commit.

## Where to look

- [`plugins/tce/commands/intent.md:396-403`](https://github.com/tobyS/toby-plugins/blob/aa782a43c02d563f997efa0758305e05ba89d41b/plugins/tce/commands/intent.md#L396-L403): this sentence says both "your entire output is exactly one line" and "go straight back to quickfix's section 2 and follow the bullet". The two hold together only because the skill runs inline in quickfix's turn. Standalone runs printed one line (3/3, 5/5), but the wording is a judgment call that a later edit could easily break.
- [`plugins/tce/references/work-loop.md:90-104`](https://github.com/tobyS/toby-plugins/blob/aa782a43c02d563f997efa0758305e05ba89d41b/plugins/tce/references/work-loop.md#L90-L104): the refusal is still produced by the model, not by a script, so byte-for-byte output rests on the prompt. It was exact in 15 runs after the fix, but it failed in the first round.
- [`plugins/tce/agents/implementer.md:89-95`](https://github.com/tobyS/toby-plugins/blob/aa782a43c02d563f997efa0758305e05ba89d41b/plugins/tce/agents/implementer.md#L89-L95): step 0 commits any dirty plan before phase work, in phase and fix mode. It cannot tell the stray log edit apart from some other uncommitted plan edit you made by hand. Both get committed as "the interrupted phase's log".
- [`plugins/tce/README.md:335-348`](https://github.com/tobyS/toby-plugins/blob/aa782a43c02d563f997efa0758305e05ba89d41b/plugins/tce/README.md#L335-L348): the headless note is the documented result of the investigation. It names the version that was verified and the `--allowedTools` workaround for 1.5.0 and earlier.

## Decided for you

- **Reproduce the grant issue with `/tce:list` plus one `/tce:plan` preflight, in a scratch project with `--setting-sources project`** — over re-running full step commands: one script call isolates the grant, and the user's own allowlist cannot hide a miss
- **Add a "Headless runs" README note in every outcome** — over a note only when the grants cannot be fixed: it records the version verified and the `--allowedTools` workaround for older versions
- **If both grant forms fail only under `-p`, leave the grants unchanged and document the limitation** — over trying further pattern variants: the intent prefers documenting a platform limit to working around it
- **Static block opens with "This tce command"** — over naming the command: a name means a placeholder the model fills in
- **Leave `work.sh preflight`'s `detail:` line as it is** — over aligning it with the block: nothing relays it
- **The dirty-plan commit lives in the implementer, in both phase and fix mode** — over a check in the orchestrator, which commits nothing today, and over phase mode only, since fix commits are feature commits too
- **Defect 4 is reproduced from an interrupted state built by hand** — over killing a live run at the right moment: a timed kill is not repeatable
- **The reproductions run before the release phase** — over releasing first as TP-0045c did: the tag then lands on verified code
- **Patch release 1.5.1, no Idempotency entry** — over 1.6.0: defects only, no new behaviour or project config
- **If a refusal is still paraphrased after the fix, stop with `needs decision`** — over switching to a script-sourced block unasked: the static block was your choice

## For you to check

None.

## Concerns

- TP-0045c recorded no denied command strings or `--allowedTools` values, so defect 3 could not be settled from the records. Phase 1 reproduced it on 2.1.310 instead (the quoted grant missed only unquoted calls).
- Under `claude -p`, a folder that was never trusted ignored the project's `settings.json` allow rules and `additionalDirectories`, and every read of tce's references was denied. The README note says this.
- New defect, out of scope: `init.md:588` offers `Read(<that path>/**)` for a tce loaded from its source directory. With a single leading slash it is denied even in a trusted folder. Only `Read(//abs/**)` matched. Worth a ticket.
- The scratch test folder is now marked trusted in your Claude config, a side effect of the interactive check.
- Phase 5 went beyond the plan text with two fixes: Step 0's "entire reply" wording, and the quickfix/intent hand-off with verbatim stops. It used 3/3 fix rounds.
- The reproductions ran with test-harness flags (`acceptEdits`, Skill and test allowances), and Run C/D needed `--allowedTools "Skill(tce:list)"`. So the evidence covers the script grants, not a run with no flags at all.
- Phase 5's D3 was ticked even though its run had one denial. That denial was the model's own `for` loop, not a tce script, the same as in Phase 1.
- The Defect 4 verifier run stopped once on a harness denial for writes under `.git/`, which is unrelated to tce.
- `claude plugin tag` could not sign in the sandbox, so `tce--v1.5.1` is an unsigned annotated tag on `4e88a20`, per the plan's fallback.

## Artifacts

- Intent: `thoughts/shared/intents/2026-10-27-TP-0045e-defects-from-stage-2-run.md`
- Research: `thoughts/shared/research/2026-10-27-TP-0045e-defects-from-stage-2-run.md`
- Plan: `thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md` (its `## Verification` section holds the evidence per criterion)
