---
date: 2026-10-27
ticket: TP-0045e
ticket_ref: thoughts/shared/tickets/TP-0045e-defects-from-stage-2-run.md
size: Medium
status: agreed
last_updated: 2026-10-27
---

# Intent: defects found in the stage-2 verification run

## Ticket

TP-0045e (`thoughts/shared/tickets/TP-0045e-defects-from-stage-2-run.md`),
sub-ticket of the TP-0045 epic. The ticket is the human's; this file is the
agreement on what it means here.

## Scope

**In:**
- Autonomous `/tce:intent` returns exactly its one return line, and
  `/tce:quickfix` reads that line reliably.
- The preflight refusal reaches the user as the fixed block.
- Establish why the `allowed-tools` script grants did not match under headless
  `claude -p`; then fix the grant or document the limitation.
- A run interrupted between a phase commit and its log commit never folds the
  log edit into a later feature commit.
- tce version bump and tag.

**Out:**
- TP-0045d's improvements (progress heads-up lines and the like).
- Any agent return-contract change beyond what a fix needs.
- Analogous issues in tsf or tle.
- Widening `/tce:init`'s allowlist as a workaround for the headless grant
  issue.

## Observable outcome

Re-running the four reproductions from TP-0045c's verification in a scratch
consuming project shows: only the `insufficient:` line from an autonomous
intent; the preflight block exactly as written; a documented answer for
headless permissions; and, after an interruption, the plan log edit committed
on its own rather than inside the next phase's feature commit.

## Anchors

- `plugins/tce/commands/intent.md` — `## Autonomous mode`, step 6 "Return"
- `plugins/tce/commands/quickfix.md:43-44` — where quickfix reads `intent:` /
  `insufficient:`
- `plugins/tce/references/work-loop.md:90-99` — Step 0 Preflight and its fixed
  block
- `plugins/tce/scripts/work.sh` — the `preflight` subcommand
- The `allowed-tools` lines of `plugins/tce/commands/research.md`, `plan.md`,
  `implement.md`, `quickfix.md` and `work.md`
  (`Bash("${CLAUDE_PLUGIN_ROOT}/scripts/…":*)` form)
- `plugins/tce/agents/implementer.md:138-149` — the log's `**Commit**` line and
  the follow-up plan commit
- Evidence: `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:860`,
  `:924`, `:926`

## Acceptance criteria

- [ ] Autonomous `/tce:intent` on an insufficient description prints exactly
      one line, `insufficient: <part> — …`, and nothing before or after it.
- [ ] `/tce:quickfix` continues or stops correctly even if the intent step
      emits other text before its return line — by an explicit rule, not by
      luck.
- [ ] With `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` unset, every step command's
      refusal shows the Step 0 block byte for byte.
- [ ] The headless grant issue is reproduced or ruled out in both an
      interactive and a `claude -p` session; the result is either corrected
      `allowed-tools` entries that match in both, or a tce README note naming
      the headless limitation and the CLI flag that works around it.
- [ ] Killing a run right after a phase commit and re-running it leaves no
      plan log edit inside the next phase's feature commit — either one commit
      carries phase and log, or the stray edit is committed on its own first.
- [ ] `claude plugin validate` passes for the marketplace and all four plugins.
- [ ] tce version bumped in both manifests and tagged.

## Decisions

- **One sub-ticket and one release for all four defects** — over four
  tickets: each fix is small and they share the verification setup.
- **For the headless grant issue, establish the cause first and document a
  platform limit rather than work around it** — over adding the scripts to
  `/tce:init`'s allowlist: CLAUDE.md forbids widening that allowlist.
- **A fixed message counts only if it reaches the user verbatim** — over "the
  message mentions the export lines": a paraphrase is exactly what failed.

## Open questions

None.

## Questions for research

- [ ] Can a prompt-level "print verbatim" be made reliable, or must the fixed
      text come from script output (as `work.sh preflight` already prints
      `detail:`)?
- [ ] How are `${CLAUDE_PLUGIN_ROOT}` patterns in `allowed-tools` matched after
      substitution, interactive versus `claude -p`?
- [ ] Can the implementer record the log hash without a second commit (log
      written before the commit, or a re-run committing a stray log edit
      first)?

## Notes

Size Medium: four independent small fixes, one of which (the headless grant
issue) needs investigation first, across several shared files. All four were
recorded as concerns in
`thoughts/shared/dossiers/2026-10-17-TP-0045c-single-step-commands-on-agents.md`.
