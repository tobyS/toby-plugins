---
date: 2026-06-14
planner: Claude (tce:work)
ticket: TP-0005
research: thoughts/shared/research/2026-06-14-TP-0005-streamline-tce-command-names.md
status: ready
tags: [plan, tce, rename, refactor, command-names]
---

# Implementation Plan: Streamline tce command names — TP-0005

## Overview

Hard-rename three tce workflow commands and update every live reference, then release
both touched plugins:

- `research_codebase` → `research`
- `create_plan` → `plan`
- `implement_plan` → `implement`

No aliases; old names cease to exist. Historical `thoughts/` docs are left untouched.
Two survivor occurrences must NOT change (they document the claude-template detection
signature, unrelated to tce's own command name).

## Current State

The reference surface is fully enumerated in the research doc. Command identity is
filename-derived (no `name:` frontmatter), so `git mv` of each file performs the rename;
all remaining edits are textual reference updates. tce is at `2.1.0`, tmt at `1.0.0`.

## Desired End State

- `plugins/tce/commands/{research,plan,implement}.md` exist; the old-named files are gone.
- A repo-wide grep for `research_codebase|create_plan|implement_plan` outside `thoughts/`
  matches **only** the two survivors: `plugins/tce/scripts/check-init.sh:61` and
  `CLAUDE.md:113`.
- `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` all pass.
- tce released at `3.0.0`, tmt at `1.0.1` (version in both `plugin.json` and the
  `marketplace.json` entry; git tags created).

## What We're NOT Doing

- No backward-compatible aliases/stubs.
- No renaming of any other command.
- No edits to `thoughts/` history (incl. the TP-0005 ticket's own old-name mentions).
- No change to the two survivor lines.

## Implementation Approach

Surgical, file-by-file edits (the repo mandates this for its long prompt files), with a
grep gate after each phase. `git mv` for the three renames to preserve history.

---

### Phase 1: Rename the three command files + fix their bodies

1. `git mv plugins/tce/commands/research_codebase.md plugins/tce/commands/research.md`
2. `git mv plugins/tce/commands/create_plan.md plugins/tce/commands/plan.md`
3. `git mv plugins/tce/commands/implement_plan.md plugins/tce/commands/implement.md`
4. In each renamed file, update in-body references (self-references and sibling-command
   references) from `/tce:research_codebase`→`/tce:research`, `/tce:create_plan`→`/tce:plan`,
   `/tce:implement_plan`→`/tce:implement`, and bare `research_codebase`/`create_plan`/
   `implement_plan` likewise. Leave `description:`/`argument-hint:` frontmatter as-is (no
   command name appears there).

**Verify:** `ls plugins/tce/commands/` shows the new names; `grep -n` of the three files
shows no old names remain.

### Phase 2: Update remaining tce-plugin references

Surgically update all old-name references (to the new names) in:

- `plugins/tce/commands/work.md` (composite — mirrors the three; the chain prose + Skill
  invocation names + "as /tce:… specifies" references)
- `plugins/tce/commands/quickfix.md` (composite — same)
- `plugins/tce/commands/init.md`
- `plugins/tce/commands/code_review.md`
- `plugins/tce/commands/discuss.md`
- `plugins/tce/templates/tce/tickets.md` (the clarification-round line referencing
  `/tce:research_codebase`)
- `plugins/tce/README.md` (the `gh` tool-table row, the numbered workflow table rows 2–4,
  and any surrounding prose naming the steps)

**Verify:** `grep -rn -E 'research_codebase|create_plan|implement_plan' plugins/tce` returns
only `scripts/check-init.sh:61`.

### Phase 3: Update tmt + repo CLAUDE.md + repo's own tce config

1. `plugins/tmt/commands/create.md` — lines 21–22 (the "picked up by /tce:…" workflow note)
   and line 393 (the "When ready, run: /tce:research_codebase" suggestion).
2. `CLAUDE.md` — update the 9 references (lines ~157–161 composite-chain prose, ~168–169 the
   composite-tracking RULE command list, ~192 drift-detection prose, ~200–201 the
   AskUserQuestion-duplication **filename** list `{init,research_codebase,create_plan,…}` →
   `{init,research,plan,…}`). **Do NOT touch line 113** (`.claude/commands/research_codebase.md`
   detection-signature prose — survivor).
3. `.claude/tce/tickets.md` — the clarification-round line (`/tce:research_codebase`).
4. `.claude/tce/profile.md` — the composite-tracking convention bullet listing
   `research_codebase`/`create_plan`/`implement_plan`.

**Verify:** `grep -rn -E 'research_codebase|create_plan|implement_plan' . | grep -v '/thoughts/'`
returns exactly two lines: `CLAUDE.md:113` and `plugins/tce/scripts/check-init.sh:61`.

### Phase 4: Version bumps, validation, tags

1. tce → `3.0.0`: edit `plugins/tce/.claude-plugin/plugin.json` and tce's entry in
   `.claude-plugin/marketplace.json`.
2. tmt → `1.0.1`: edit `plugins/tmt/.claude-plugin/plugin.json` and tmt's `marketplace.json`
   entry.
3. Run `claude plugin validate .`, `claude plugin validate ./plugins/tce`,
   `claude plugin validate ./plugins/tmt` — all must pass.
4. After the implementation commit(s) land, create tags:
   `claude plugin tag ./plugins/tce` and `claude plugin tag ./plugins/tmt`.

**Verify:** all three validations pass; `git tag` lists `tce--v3.0.0` and `tmt--v1.0.1`.

---

## Testing Strategy

- **Automated:** `claude plugin validate .` + `./plugins/tce` + `./plugins/tmt` (the
  project's only "test"). Plus the grep gate proving only the two survivors remain.
- **Manual smoke (optional):** confirm `/tce:research`, `/tce:plan`, `/tce:implement` resolve
  by filename (they're new files in `commands/`); confirm `/tce:research_codebase` no longer
  exists.

## Success Criteria

### Automated
- [ ] `claude plugin validate .` passes
- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `claude plugin validate ./plugins/tmt` passes
- [ ] `grep -rn -E 'research_codebase|create_plan|implement_plan' . | grep -v '/thoughts/'`
      returns only `CLAUDE.md:113` and `plugins/tce/scripts/check-init.sh:61`
- [ ] `plugins/tce/commands/{research,plan,implement}.md` exist; old-named files gone

### Manual / judgment
- [ ] Composite commands (`work.md`, `quickfix.md`) read coherently with the new names and
      still satisfy the CLAUDE.md composite-tracking rule
- [ ] No `thoughts/` file was modified by the rename
- [ ] tce `3.0.0` / tmt `1.0.1` reflected in both `plugin.json` and `marketplace.json`;
      tags created

## References

- Ticket: `thoughts/shared/tickets/TP-0005-streamline-tce-command-names.md`
- Research: `thoughts/shared/research/2026-06-14-TP-0005-streamline-tce-command-names.md`
