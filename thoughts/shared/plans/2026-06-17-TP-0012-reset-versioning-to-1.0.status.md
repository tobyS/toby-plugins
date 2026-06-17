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

## Phase 2 — Git-tag reset — DONE

- Deleted pre-1.0 tags locally (7 tce + 3 tmt).
- Created `tce--v1.0.0` and `tmt--v1.0.0` on the reset commit `a239f93` (= HEAD).
- Author pushed: deleted the 8 pre-1.0 tags that existed on origin (the two
  unpushed ones — tce--v2.0.0, tmt--v1.0.0 — were never on the remote) and pushed
  the new tags + main.
- Verified on origin: only `tce--v1.0.0` and `tmt--v1.0.0` remain, both
  dereferencing to `a239f93`; `origin/main` == `9a75115`.

## Result

Both plugins are at 1.0.0 everywhere; remote tag timeline starts at v1.0.0.
Ticket Done.
