# Implementation Status: TP-0011 — User-First README Rework + CONTRIBUTING.md

## Phase 1: Create root CONTRIBUTING.md
- **Status**: ✅ Complete
- **Started**: 2026-06-17 04:35
- **Completed**: 2026-06-17 04:35

### Steps Performed
1. Created `CONTRIBUTING.md` at repo root: welcome/intro, "Two names" note,
   repository layout tree, working-on-the-plugins conventions (work-on-main,
   conventional commits, never auto-push) with a pointer to `CLAUDE.md` for the deep
   design rules, validating changes (validate commands + scratch-project script
   smoke test), update gating, and releasing.
2. Relocated the marketplace README's `## Development` content (two-names note,
   layout, update gating, validate & release) into it; referenced `CLAUDE.md`
   instead of duplicating its rules.
3. Marked ticket `TP-0011` **In Progress**.

### Issues Encountered
- None.

### Verification
- ✅ `CONTRIBUTING.md` exists
- ✅ No `TODO.md` references (grep count 0)
- ✅ `claude plugin validate .` passes

### Commit
- (recorded below after commit)

---

## Phase 2: Rework marketplace README.md
- **Status**: ⬚ Not started

## Phase 3: Rework plugins/tce/README.md
- **Status**: ⬚ Not started

## Phase 4: Rework plugins/tmt/README.md
- **Status**: ⬚ Not started
