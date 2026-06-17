# Status: TP-0012 reset versioning to 1.0.0

Plan: `thoughts/shared/plans/2026-06-17-TP-0012-reset-versioning-to-1.0.md`

## Phase 1 — Reset versions + collapse migration list — DONE

- Edited tce/tmt `plugin.json` + both `marketplace.json` entries → `1.0.0`.
- Updated `.claude/tce/profile.md:1` marker → `1.0.0`.
- Collapsed `init.md` migration list (removed v3.1.0/v3.2.0 sub-bullets, folded
  the generic marker-missing case into the "Older or missing" bullet).
- Verified: `claude plugin validate` passes for marketplace + both plugins;
  stale-version grep clean.
- Ticket set to In Progress.

## Phase 2 — Git-tag reset — LOCAL DONE, REMOTE PENDING AUTHOR

- Deleted pre-1.0 tags locally (7 tce + 3 tmt).
- Created `tce--v1.0.0` and `tmt--v1.0.0` on the reset commit `a239f93` (= HEAD).
  Verified `git tag --list "tce--*" "tmt--*"` shows only the two v1.0.0 tags.
- REMAINING (author authorizes — pushes):
  - `git push origin --delete tce--v2.0.0 tce--v2.1.0 tce--v3.0.0 tce--v3.0.1 tce--v3.1.0 tce--v3.2.0 tce--v3.2.1`
  - `git push origin --delete tmt--v1.0.0 tmt--v1.0.1 tmt--v1.1.0`
  - `git push origin refs/tags/tce--v1.0.0 refs/tags/tmt--v1.0.0`
  - Then push the branch commits (a239f93 + the doc commits).
- Ticket stays **In Progress** until the remote tags are reset; the acceptance
  criteria for remote state can't be met without the author's pushes.
