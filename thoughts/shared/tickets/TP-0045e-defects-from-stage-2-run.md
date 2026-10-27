# TP-0045e: defects found in the stage-2 verification run

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-10-27
**Updated:** 2026-10-27

Sub-ticket of TP-0045 (the epic). Defects, not improvements: TP-0045d
explicitly excludes them ("a run that breaks is a bug ticket").

## Problem Statement

TP-0045c's verifier ran the rewired step commands headless (`claude -p`) in
a scratch consuming project. Every criterion was met, but the run surfaced
four places where a command or agent does not behave as its own text says:

1. **Autonomous `/tce:intent` prints prose before its return line.** The
   `--autonomous` mode promises exactly one line (`intent: <path>` or
   `insufficient: <part> — …`); on an insufficient description the model
   printed explanatory prose first. `/tce:quickfix` reads that line, so extra
   output makes the hand-off fragile.
2. **The preflight refusal is paraphrased.** When
   `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` / `BASH_DEFAULT_TIMEOUT_MS` are
   missing, `work-loop.md` Step 0 prescribes a fixed block naming the exact
   `export` lines; the model reworded it instead of printing it verbatim.
3. **`allowed-tools` did not cover the absolute-path script calls headless.**
   Under `claude -p`, a step command's `allowed-tools` grant for
   `"${CLAUDE_PLUGIN_ROOT}/scripts/…"` did not match the substituted
   absolute-path call; the grants had to be passed on the CLI.
4. **An interruption after a phase commit leaves the log edit uncommitted.**
   The implementer commits the phase, then records the commit hash in the
   plan's implementation log in a second commit. Interrupted between the two,
   the log edit stayed uncommitted and the next phase's feature commit
   absorbed it.

## Desired Outcome

Each of the four either behaves as the text says or the text is changed to
match a behaviour that is deliberately accepted — with item 3 first
established as a tce problem or a platform limitation of headless runs (and,
if the latter, documented rather than worked around).

## Acceptance Criteria

- [ ] Autonomous `/tce:intent` output on an insufficient description is
      exactly the one `insufficient:` line (or quickfix tolerates leading
      prose by an explicit rule).
- [ ] The preflight refusal reaches the user as the fixed block, byte for
      byte.
- [ ] Item 3 is reproduced or ruled out interactively; the outcome is a fix
      in the commands' `allowed-tools` or a documented headless limitation in
      the tce README.
- [ ] A run interrupted between the phase commit and the log commit leaves
      either nothing uncommitted or an uncommitted log edit that the next
      dispatch commits on its own, never folded into a feature commit.
- [ ] tce version bumped and tagged.

## Out of Scope

- Improvements without a defect (TP-0045d).
- Changes to an agent's contract beyond what a fix requires.

## Open Questions

None at this time.

## Questions for Research/Planning

- [ ] Whether a prompt-level "print verbatim" can be made reliable, or the
      fixed text must come from a script's output (as `work.sh preflight`
      already prints `detail:`).
- [ ] How `allowed-tools` patterns with `${CLAUDE_PLUGIN_ROOT}` are matched
      after substitution, interactive versus `claude -p`.
- [ ] Whether the log hash can be written before the phase commit (amend-free)
      so one commit carries both.

## References

- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md` — the epic
- `thoughts/shared/dossiers/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
  — Concerns, where the four were recorded
- `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
  — `## Verification`, the run's evidence
- `plugins/tce/commands/intent.md` (Autonomous mode),
  `plugins/tce/references/work-loop.md` (Step 0),
  `plugins/tce/agents/implementer.md` (log and commit)

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-10-27

- Filed from TP-0045c's verification concerns as a sub-ticket of the epic.
