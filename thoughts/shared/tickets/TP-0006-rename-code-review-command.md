# TP-0006: Rename tce `/code_review` command to `/review`

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-06-14
**Updated:** 2026-06-14

## Problem Statement

TP-0005 streamlined the tce command names (e.g. `research_codebase` → `research`,
`create_plan` → `plan`, `implement_plan` → `implement`) but missed the
`code_review` command. It remains `/tce:code_review`, inconsistent with the
shorter, simpler names the rename established.

## Desired Outcome

The command is named `/tce:review` (file `plugins/tce/commands/review.md`), and
every live reference to `/tce:code_review` across both plugins and this repo's
own dogfooding config is updated to `/tce:review`. No alias — the old name
ceases to exist, matching how TP-0005 handled the other renames.

## User Stories / Use Cases

- As a tce user, I want the review command to follow the same concise naming as
  the other workflow commands so the command set is consistent and predictable.

## Acceptance Criteria

- [ ] `plugins/tce/commands/code_review.md` is renamed to `review.md` (via `git mv`).
- [ ] All live `/tce:code_review` references are updated to `/tce:review`
      (README, tickets.md template, the command's own internal references,
      this repo's `.claude/tce/tickets.md`).
- [ ] The claude-template migration cleanup list in `init.md` is kept consistent
      with how TP-0005 treats it.
- [ ] `claude plugin validate ./plugins/tce` and the marketplace validate pass.
- [ ] Existing tests (manifest validation) continue to pass.

## Out of Scope

- Version bump / release of the tce plugin (human-gated; flagged as follow-up).
- The `code-review` descriptive keyword in `plugin.json` (not a command name).
- Any change to historical `thoughts/` documents (research/plans/tickets are
  records of their time and are not rewritten).
- Fixing the broader question of whether `init.md`'s migration list should track
  claude-template's literal legacy filenames vs. tce's current names.

## Open Questions

None — this is a well-understood quickfix mirroring the TP-0005 rename.

## Questions for Research/Planning

- [ ] Enumerate every live reference to `/tce:code_review` / `code_review.md`
      that must change, and which `thoughts/` occurrences must be left alone.
- [ ] Confirm how TP-0005 handled the `init.md` migration cleanup list so this
      rename stays consistent with that precedent.

## References

- Quickfix initiated via `/tce:quickfix` command
- Precedent: TP-0005 (commit 88fc916, `refactor(TP-0005): streamline tce command names`)

## Implementation Plan

See `thoughts/shared/plans/2026-06-14-TP-0006-rename-code-review-command.md`.

## Notes & Updates

### 2026-06-14
- Quickfix ticket auto-created from `/tce:quickfix` command
