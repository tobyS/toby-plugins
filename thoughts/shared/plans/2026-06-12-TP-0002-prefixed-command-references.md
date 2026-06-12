# TP-0002: Use installed (prefixed) command names in all plugin command references — Implementation Plan

**Date:** 2026-06-12
**Ticket:** `thoughts/shared/tickets/TP-0002-prefixed-command-references.md`
**Research:** `thoughts/shared/research/2026-06-12-TP-0002-prefixed-command-references.md`

## Overview

Replace every un-prefixed tce/tmt slash-command reference inside the plugins
with its installed, prefixed form (`/create_plan` → `/tce:create_plan`, …), so
that any command name a user copies from a command's output or docs is a
working invocation. Text-only; no behavior change.

## Current State Analysis

Research compiled the definitive list (see the research doc for the full
per-line table). Un-prefixed references exist in **exactly 7 files, all in
`plugins/tce/commands/`**:

| File | Change sites |
|------|--------------|
| `research_codebase.md` | 6 lines: workflow table (47–49), next-command hint (326), `/commit` refs (332, 342) |
| `create_plan.md` | 14 lines: table (47–50), prose (90, 310, 318, 601), tips (198–199), dialog copy (314), next-command hint (583), `/commit` (598), stale `/implementation_plan` (762) |
| `implement_plan.md` | 7 lines: table (27–30), prose (66, 179), dialog copy (177) |
| `code_review.md` | 8 lines: table (32–35), tip (104), example invocations (442, 451, 461) |
| `work.md` | 23 lines: prose cross-refs, Usage line (24), `/commit` refs, convention line (20), verbatim dialog copy (154, 156) |
| `quickfix.md` | 17 lines: prose cross-refs, convention line (20), inlined ticket template (152, 161), `/commit` refs |
| `discuss.md` | 1 line (15) |

Additionally (per user decision at the question checkpoint): root `CLAUDE.md`
lines 130–134 describe the composite chains un-prefixed and will be fixed too.

Everything else is already clean: the entire tmt plugin, tce's
`init.md`/`commit.md`/`design_explore.md`, agents, hooks, all scripts
(including `check-init.sh`'s additionalContext), templates, READMEs, and both
`plugin.json` manifests.

## Desired End State

- `grep -rn` over `plugins/` for the un-prefixed forms returns no hits that
  refer to a tce/tmt command (the only remaining matches are the documented
  false positives, which are substrings of paths/filenames, not command refs).
- All "Next command:" hints, workflow tables, usage tips, example invocations,
  dialog copy, and internal cross-references use `/tce:<name>` (tmt already
  uses `/tmt:<name>`).
- The convention line in `work.md`/`quickfix.md` prescribes the prefixed form.
- Root `CLAUDE.md` chain descriptions use prefixed names.

### Verification

- Automated: targeted greps return zero command-reference hits; `claude plugin
  validate` passes for the marketplace and both plugins.
- Manual: spot-read the edited next-command hints and dialog copy.

## What We Are NOT Doing

- No command renames, no behavior changes, no file moves.
- No changes to consuming-project files or templates (`templates/` verified
  clean), no prefix configurability.
- Not touching the false positives: `init.md:85` (`.github/workflows/*`),
  `init.md:271` (`filenames/commit scopes`), `discussions/` paths,
  `ticket.sh` usage strings, slash-less generic prose ("commit the ticket"),
  Skill-tool identifier names (`tce:create_plan` — already namespaced,
  correct form for the Skill tool), `CLAUDE.md:141–142` bare names (they name
  command *files* in the composite-command rule) and `:158–159` (path glob).
- Not editing the duplicated AskUserQuestion *guidelines* block (contains no
  command references; its six-copy sync rule is not triggered).

## Implementation Approach

One phase, one commit: the composite-command rule requires `work.md` and
`quickfix.md` to change in the same commit as the single-step commands they
mirror, and CLAUDE.md rides along. Edits are surgical per-line replacements
(preserve structure/altitude — no rewrites).

**Replacement map** (leading slash required; slash-less occurrences are
generic prose or Skill identifiers and stay):

| Old | New |
|-----|-----|
| `/research_codebase` | `/tce:research_codebase` |
| `/create_plan` | `/tce:create_plan` |
| `/implement_plan` | `/tce:implement_plan` |
| `/implementation_plan` (stale, create_plan.md:762) | `/tce:implement_plan` |
| `/design_explore` | `/tce:design_explore` |
| `/code_review` | `/tce:code_review` |
| `/commit` | `/tce:commit` |
| `/work` (self-ref in work.md:24) | `/tce:work` |
| `/quickfix` (quickfix.md:152, 161) | `/tce:quickfix` |

## Phase 1: Prefix all command references

### Changes Required

1. **`plugins/tce/commands/research_codebase.md`** — lines 47–49 (workflow
   table), 326 (`Next command: /tce:create_plan [PREFIX]-XXXX`), 332, 342
   (`/tce:commit`).
2. **`plugins/tce/commands/create_plan.md`** — lines 47–50, 90, 198–199, 310,
   314 (dialog copy sentence), 318, 583 (`Next command: /tce:implement_plan
   [PREFIX]-XXXX`), 598, 601, 762 (`User: /tce:implement_plan` — also fixes
   the stale name).
3. **`plugins/tce/commands/implement_plan.md`** — lines 27–30, 66, 177 (dialog
   copy sentence), 179.
4. **`plugins/tce/commands/code_review.md`** — lines 32–35, 104, 442, 451, 461.
5. **`plugins/tce/commands/work.md`** — all 23 sites. Special handling:
   - Line 20 (convention line): reword to prescribe prefixed prose form, e.g.
     "When these instructions tell you to invoke another workflow command
     **via the Skill tool**, use its namespaced name (e.g., `tce:create_plan`).
     In prose, sibling commands are referenced by their installed, prefixed
     name (e.g., `/tce:research_codebase`)."
   - Lines 154, 156 (verbatim AskUserQuestion dialog copy, TP-0001 contract):
     `/design_explore` → `/tce:design_explore` inside the quoted copy — this
     ticket's commit/review IS the sanctioned wording-change route.
   - Line 24: `**Usage:** /tce:work [PREFIX]-XXXX`.
6. **`plugins/tce/commands/quickfix.md`** — all 17 sites. Special handling:
   - Line 20 (convention line): same rewording as work.md, keeping its own
     example (`/tce:create_plan`) — the two copies stay in lock-step.
   - Lines 152, 161 (inlined ticket template): `/tce:quickfix`.
7. **`plugins/tce/commands/discuss.md`** — line 15.
8. **Root `CLAUDE.md`** — lines 130–134: prefix the chain descriptions
   (`/tce:research_codebase` → `/tce:create_plan` → `/tce:implement_plan`).
   Leave lines 141–142 and 158–159 untouched (file names / glob).

### Success Criteria

#### Automated Verification

- [x] Zero un-prefixed command references in plugins (fixed-string greps; the
      prefixed form `tce:` has no `/` directly before the name, so plain
      substring greps are exact):
      `grep -rn -e "/research_codebase" -e "/create_plan" -e "/implement_plan" -e "/implementation_plan" -e "/design_explore" -e "/code_review" -e "/quickfix" plugins/` → no hits
- [x] `grep -rn "/commit" plugins/` → only `init.md:271` (`filenames/commit`)
- [x] `grep -rn -e "/work" -e "/discuss" plugins/` → only `init.md:85`
      (`workflows`) and `discussions/`-path lines
- [x] `claude plugin validate .` passes
- [x] `claude plugin validate ./plugins/tce` passes
- [x] `claude plugin validate ./plugins/tmt` passes

#### Manual Verification

- [x] Spot-read the two "Next command:" hints and the three dialog-copy
      sentences (create_plan.md:314, implement_plan.md:177, work.md:154–156)
      for natural wording after substitution
- [x] Convention line reads consistently in both work.md and quickfix.md
- [x] CLAUDE.md composite-command section still reads correctly

## Testing Strategy

No scripts or manifests change, so the manifest validations are a regression
guard only. The greps above are the real acceptance test, mirroring the
ticket's AC3. tmt files require no edits (AC4 verified by research).

## References

- Ticket: `thoughts/shared/tickets/TP-0002-prefixed-command-references.md`
- Research: `thoughts/shared/research/2026-06-12-TP-0002-prefixed-command-references.md`
- Composite-command same-commit rule: `CLAUDE.md` ("Composite commands must
  track the single-step commands")
- TP-0001 dialog-copy contract: `CLAUDE.md` ("The AskUserQuestion guidelines
  block is duplicated…"), `thoughts/shared/tickets/TP-0001-askuserquestion-copy.md`
