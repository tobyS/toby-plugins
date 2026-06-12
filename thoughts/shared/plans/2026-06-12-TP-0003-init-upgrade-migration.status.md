# TP-0003 Implementation Status

**Plan:** `thoughts/shared/plans/2026-06-12-TP-0003-init-upgrade-migration.md`
**Started:** 2026-06-12
**Completed:** 2026-06-12

## Phases

- [x] Phase 1: Version markers (templates + both inits' write/idempotency)
- [x] Phase 2: /tmt:init template detection & migration
- [x] Phase 3: /tce:init template detection & migration
- [x] Phase 4: check-init.sh nudge + documentation

## Notes

- Phase 1: validations + fake-project smoke test pass; `TMT_CONFIG_VERSION`
  in the sourced config is inert to existing scripts as researched.
- Phase 2: cleanup is one batched AskUserQuestion call (template files /
  settings.json entries / legacy config); the fresh-derivation provenance
  example now also mentions template scripts so the copy stays accurate.
- Phase 3: customized design-system files are moved in Phase 4 step 3 (the
  copy step's exception), pristine ones ride the cleanup deletion list; the
  old "suggest deleting .claude/tce/config" advice now defers to /tmt:init's
  deletion offer.
- Phase 4: three-fixture smoke test passes (template → tailored nudge, clean
  → generic nudge, initialized / reminders-off → silent); JSON jq-parses.
  Repo CLAUDE.md gained a "Migrations & version markers (TP-0003)" section;
  its stale hook-event list was trimmed while touching the nudge section.
- End-to-end test against a real claude-template clone (install plugins, run
  both inits) is recommended before tagging a release — manual step.
