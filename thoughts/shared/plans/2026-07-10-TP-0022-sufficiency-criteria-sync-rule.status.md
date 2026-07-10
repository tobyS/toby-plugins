# Implementation Status: TP-0022 — Sufficiency-criteria sync rule

**Base commit**: d6f9da0d6f63dbf2babb84053273962b35136737

## Phase 1: Reconcile the drift and add the sync rule
- **Status**: ✅ Complete
- **Started**: 2026-07-10 10:38
- **Completed**: 2026-07-10 10:40

### Steps Performed
1. Added the "code area" anchor example to `plugins/tce/commands/research.md:123`
   (the one substantive drift), matching the canonical `tickets.md` copy. Left
   register wording unchanged; `work.md` untouched (per checkpoint decisions).
2. Inserted the new `## … keep the three-part test in sync (TP-0022)` sync-rule
   section into `CLAUDE.md`, immediately after the AskUserQuestion rule and
   before `## Testing changes` — names all three copies, designates `tickets.md`
   canonical, requires same-commit substance updates, framed as a
   semantic-mirror (register-tolerant) rule distinct from the byte-identical
   AskUserQuestion rule.
3. Set ticket `TP-0022` status to In Progress.

### Issues Encountered
- None.

### Verification
- ✅ `claude plugin validate .` / `./plugins/tce` / `./plugins/tmt` all pass
- ✅ `grep` confirms "code area" in research.md:123 and the new rule heading in CLAUDE.md
- ✅ Manual read: the two full copies now share the anchor set; rule matches
  neighboring sync-rule style; no register normalization; work.md unchanged

### Commit
- (pending — this phase commit)
