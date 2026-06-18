# Status: TP-0013 — Explicit re-reading of input context documents

Plan: thoughts/shared/plans/2026-06-18-TP-0013-explicit-context-document-reads.md

- [x] Phase 1: Add the CLAUDE.md rule
- [x] Phase 2: Tighten the single-step consuming commands (research, plan, implement, review)
- [x] Phase 3: Tighten the composite commands (work, quickfix)

## Log

### 2026-06-18
- Ticket → In Progress; status file created. Beginning Phase 1.
- Phase 1 committed (bb1684e): CLAUDE.md rule.
- Phase 2: added unconditional ordered re-read clauses to research/plan/implement/review;
  reordered implement.md reads to ticket → research → plan; preserved all source-file
  "DO NOT re-read" guidance. `claude plugin validate ./plugins/tce` passed.
- Phase 3: work.md Phase 3 re-reads ticket → research, Phase 4 re-reads ticket → research
  → plan (removed "already in context, but verify"); quickfix.md Phase 3 reads ticket
  FULLY (Phases 4/5 inherit via skill delegation). All three validators passed.
