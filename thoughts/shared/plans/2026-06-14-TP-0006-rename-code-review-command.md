---
date: 2026-06-14
planner: Claude (tce:quickfix)
ticket: TP-0006
research: thoughts/shared/research/2026-06-14-TP-0006-rename-code-review-command.md
status: ready
tags: [plan, tce, rename, refactor, command-names]
---

# Implementation Plan: Rename tce `/code_review` → `/review` — TP-0006

## Overview

Hard-rename the tce `code_review` command to `review` (no alias) and update
every live reference, mirroring TP-0005. Single phase — the change is purely
mechanical text/file edits in markdown + one config file. Version bump/release
is deferred (human-gated) and out of scope.

## Phase 1: Rename command + update references

### Changes

1. **Rename the command file** (skill name derives from filename):
   - `git mv plugins/tce/commands/code_review.md plugins/tce/commands/review.md`

2. **Update the command's own internal references** in `review.md`:
   - Line 35: workflow table row `**`/tce:code_review`**` → `**`/tce:review`**`
   - Line 104: combine tip `/tce:code_review` → `/tce:review`
   - Lines 442, 451, 461: example `User: /tce:code_review …` → `User: /tce:review …`
   - H1 `# Code Review` stays (descriptive title); frontmatter `description:` stays.

3. **Update live references elsewhere:**
   - `plugins/tce/README.md:140` — catalog row `/tce:code_review` → `/tce:review`
   - `plugins/tce/templates/tce/tickets.md:70` — `/tce:code_review` → `/tce:review`
   - `.claude/tce/tickets.md:71` — dogfooded copy, same edit
   - `plugins/tce/commands/init.md:123` — migration list `code_review` → `review` (TP-0005 precedent)

4. **Leave unchanged:**
   - `plugins/tce/.claude-plugin/plugin.json:14` keyword `"code-review"` (descriptive, not a command name)
   - all `thoughts/` history

### Verification

- [ ] `claude plugin validate .` passes
- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `grep -rn "tce:code_review\|commands/code_review\|/code_review" plugins/ .claude/ README.md` → no hits
- [ ] `plugins/tce/commands/review.md` exists; `code_review.md` is gone (tracked by git as a rename)

## Out of Scope / Follow-ups

- tce plugin version bump + `claude plugin tag` (release) — human decides the
  version and when to tag.
- Whether `init.md`'s migration list should track claude-template's literal
  legacy filenames instead of tce's current names (pre-existing question).
