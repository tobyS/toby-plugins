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

## Phase 2 — Git-tag reset — IN PROGRESS

- Local tag deletion + `claude plugin tag` for both plugins: pending.
- Remote tag deletion + pushing new tags: SURFACED for author to authorize
  (no-auto-push rule). Ticket stays In Progress until the author runs the pushes.
