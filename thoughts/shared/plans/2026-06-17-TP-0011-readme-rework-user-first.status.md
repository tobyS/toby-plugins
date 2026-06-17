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
- `027a0ac` docs(TP-0011): add root CONTRIBUTING.md (phase 1)

---

## Phase 2: Rework marketplace README.md
- **Status**: ✅ Complete
- **Started**: 2026-06-17 04:38
- **Completed**: 2026-06-17 04:38

### Steps Performed
1. Rewrote `README.md` value-first: H1 `# toby-plugins` (rent-the-toby.com removed
   from heading), one-line tagline, short value paragraph, then the agreed
   rent-the-toby.com callout after the value section.
2. Preserved the `## Plugins` catalog, `## Add the marketplace`, and `## Update`
   sections (facts unchanged; "Description" column header reworded to "What it does").
3. Removed the `## Development` section (now in CONTRIBUTING.md); added a `##
   Contributing` section linking CONTRIBUTING.md, with `## License` last.

### Issues Encountered
- None.

### Verification
- ✅ No `## Development` section (grep 0)
- ✅ Contributing link present (grep 1)
- ✅ rent-the-toby.com not in H1
- ✅ `claude plugin validate .` passes

### Commit
- `f3f9b0e` docs(TP-0011): rework marketplace README value-first (phase 2)

---

## Phase 3: Rework plugins/tce/README.md
- **Status**: ✅ Complete
- **Started**: 2026-06-17 04:42
- **Completed**: 2026-06-17 04:42

### Steps Performed
1. Rewrote `plugins/tce/README.md` value-first: H1 exactly
   `# tce — Toby Context Engineering` (rent-the-toby.com removed from heading),
   tagline + value lead, then the agreed callout after the value section.
2. Added a Contents (TOC) section linking all headings (tce only).
3. Replaced the single Step-column command table with four role-grouped tables
   (Core workflow / Shortcuts / Helpers / Maintenance), each with a one-line intro;
   reused each command's existing one-line purpose; kept the profile-drift note.
4. Preserved Why context engineering, Requirements, Install, Set up a project (incl.
   migration note), Update, Agents, and How project parameterization works.
5. Added a bottom `## Contributing` linking `../../CONTRIBUTING.md`.

### Issues Encountered
- `/tce:work`'s old purpose said "steps 2→4"; reworded to "research→implement" since
  the Step numbers were dropped. Same meaning, no Step column.

### Verification
- ✅ H1 exact (`# tce — Toby Context Engineering`)
- ✅ All 12 commands referenced (grep distinct = 12)
- ✅ Contributing link present (`../../CONTRIBUTING.md`)
- ✅ `claude plugin validate ./plugins/tce` passes

### Commit
- (recorded after commit)

## Phase 4: Rework plugins/tmt/README.md
- **Status**: ⬚ Not started
