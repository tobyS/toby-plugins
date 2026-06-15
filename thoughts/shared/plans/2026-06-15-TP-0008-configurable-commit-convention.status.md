# Status: TP-0008 configurable commit convention

Plan: `thoughts/shared/plans/2026-06-15-TP-0008-configurable-commit-convention.md`

## Phase 1 — Core read path: profile template + commit.md
- [x] Done — added `## Commit convention` to profile template; commit.md reads it with Conventional fallback. Validated.

## Phase 2 — /tce:init: detect, propose, write, upgrade, version bump
- [x] Done — Phase 1 detect item 9; verbatim Phase 2 dialog; Phase 3 refine list; Phase 4 fill step; v3.2.0 upgrade bullet; version bumped 3.1.0→3.2.0 in plugin.json + marketplace.json. Both validate.

## Phase 3 — /tce:refresh: full reconciliation
- [x] Done — Phase 1 detect item 5; `## Commit convention` added to factual refresh targets, distinguished from free-form `## Conventions`. Validated.

## Phase 4 — Neutralize inlined literals, composite sync, docs
- [x] Done — quickfix (3 commit steps + summary + rule #4), ticket.md, implement.md status example made convention-dependent; commit.md frontmatter neutralized; README updated (init blurb, file tree, parameterization, command table). work.md only defers (no change). Guidelines block unchanged across 9 files. Validated.

## Phase 5 — Ticket update + dogfood + final validation
- [ ] Not started
