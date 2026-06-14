# Status: TP-0005 — Streamline tce command names

Plan: `thoughts/shared/plans/2026-06-14-TP-0005-streamline-tce-command-names.md`

- [x] Phase 1 — Rename the three command files + fix their bodies
- [x] Phase 2 — Update remaining tce-plugin references
- [x] Phase 3 — Update tmt + CLAUDE.md + repo's own tce config
- [x] Phase 4 — Version bumps, validation, tags

## Notes
- Survivors (left unchanged): `plugins/tce/scripts/check-init.sh:61`, `CLAUDE.md:113`.
- Validation: `claude plugin validate` passes for marketplace, tce, tmt.
- Grep gate (outside `thoughts/`): only the two survivors remain.
- Released tce 3.0.0, tmt 1.0.1. Tags created locally; push is the human's call.
