---
date: 2026-06-14
researcher: Claude (tce:work)
ticket: TP-0005
topic: "Streamline tce command names (research_codebase→research, create_plan→plan, implement_plan→implement)"
status: complete
base_commit: 98f1c53270947832a96da248283ebaea852787ea
tags: [research, tce, rename, refactor, command-names]
---

# Research: Streamline tce command names — TP-0005

## Research Question

Rename three tce workflow commands — `research_codebase`→`research`, `create_plan`→`plan`,
`implement_plan`→`implement` — as a hard rename (no aliases). Find **every live reference**
to the old names across both plugins and this repo's own config, categorize each as
update / keep / leave-as-history, and surface any traps that make this more than a blind
find-and-replace.

## Summary

This is a mechanical rename with a **well-bounded, fully enumerated** reference surface and
exactly **two "survivor" occurrences** that must NOT change. The headline trap flagged on
the ticket (the `check-init.sh` template-signature vs. nudge-text ambiguity) resolves
cleanly in our favor: `check-init.sh` contains only **one** occurrence of an old name, and
it is the survivor — there is no nudge-text reference to update.

Key facts that de-risk the change:

- **Command name = filename.** The three command files' frontmatter has only `description:`
  and `argument-hint:` — **no `name:` field** — so Claude Code derives `/tce:<x>` from the
  filename. Renaming the file is necessary and sufficient; no frontmatter edit needed, and
  no `description` string contains a command name.
- **No collisions.** `research.md`, `plan.md`, `implement.md` do not exist in either
  plugin's `commands/`.
- **Two survivors** (must stay literally `research_codebase`):
  1. `plugins/tce/scripts/check-init.sh:61` — the claude-template **detection signature**
     `$ROOT/.claude/commands/research_codebase.md`. This is the *legacy template's* filename
     in a consuming project, not tce's command; it must stay to keep migrating old installs.
  2. `CLAUDE.md:113` — the prose that documents that same signature
     (`.claude/commands/research_codebase.md`).
- **History is immutable.** All `thoughts/` occurrences (TP-0001…TP-0004 docs, plus the
  TP-0005 ticket itself) are point-in-time records and are left untouched per the ticket's
  scope decision.

The change spans **two plugins** → both need a version touch: tce (the real change) and tmt
(only doc-suggestion strings in `commands/create.md`).

## Detailed Findings

### Full live-reference inventory (everything outside `thoughts/`)

Counts are occurrences of any of the three old names per file. "Action" is what the rename
requires.

| File | Refs | Action |
|------|-----:|--------|
| `plugins/tce/commands/research_codebase.md` | 4 | **Rename file → `research.md`**; update self/sibling refs in body |
| `plugins/tce/commands/create_plan.md` | 10 | **Rename file → `plan.md`**; update body refs |
| `plugins/tce/commands/implement_plan.md` | 4 | **Rename file → `implement.md`**; update body refs |
| `plugins/tce/commands/work.md` | 16 | Update all (composite — mirrors the three) |
| `plugins/tce/commands/quickfix.md` | 13 | Update all (composite — mirrors the three) |
| `plugins/tce/commands/init.md` | 5 | Update all |
| `plugins/tce/commands/code_review.md` | 3 | Update all |
| `plugins/tce/commands/discuss.md` | 1 | Update |
| `plugins/tce/templates/tce/tickets.md` | 1 | Update (the `/tce:research_codebase` clarification-round line) |
| `plugins/tce/README.md` | 5 | Update (tool table + 3-step workflow table + prose) |
| `plugins/tce/scripts/check-init.sh` | 1 | **KEEP — survivor (line 61 detection signature)** |
| `plugins/tmt/commands/create.md` | 3 | Update (lines 21–22 workflow note; line 393 "When ready, run" suggestion) — **tmt change** |
| `CLAUDE.md` | 10 | Update 9, **KEEP 1** (line 113 detection-signature prose) |
| `.claude/tce/tickets.md` | 1 | Update (this repo's own config — line 74 clarification-round line) |
| `.claude/tce/profile.md` | 1 | Update (this repo's own config — composite-tracking convention list, ~line 56–58) |

No occurrences in: `agents/*.md`, `hooks/*.json`, `*/scripts/*.sh` other than check-init.sh,
plugin/marketplace manifests, `next-ticket.sh`/`lib.sh`/`ticket.sh`/`open_tickets.sh`. So
**hooks and shell scripts need no edits** (beyond not touching check-init.sh line 61).

### The `check-init.sh` trap — resolved

`plugins/tce/scripts/check-init.sh:61`:
```sh
if [ -f "$ROOT/scripts/next-ticket.sh" ] && [ -f "$ROOT/.claude/commands/research_codebase.md" ]; then
```
This detects a **claude-template** install in the *consuming* project (the template shipped
a file literally named `research_codebase.md`). It has nothing to do with tce's own command
filename and must stay. There is **no** `/tce:research_codebase` string in the nudge heredocs
— the nudge offers `/tce:init`, not the research command — so the feared
"signature-vs-nudge" disambiguation has no second half. One line, keep it, done.

### `CLAUDE.md` — mixed file (9 update, 1 keep)

- **KEEP** line 113: `.claude/commands/research_codebase.md` — documents the check-init.sh
  detection signature (Migrations section).
- **UPDATE** lines 157–161 (composite-chain prose for `/tce:work` and `/tce:quickfix`),
  168–169 (the composite-tracking RULE's single-step command list), 192 (drift-detection
  prose), 200–201 (the AskUserQuestion-duplication file list `{init,research_codebase,
  create_plan,…}` → `{init,research,plan,…}`).

This file demands **surgical edits**, not a global replace, because of the line-113 survivor.

### Command name resolves from filename (no frontmatter change)

```
plugins/tce/commands/research_codebase.md  → description: "...Step 2..."  (no name:)
plugins/tce/commands/create_plan.md        → description: "...Step 3..."  (no name:)
plugins/tce/commands/implement_plan.md     → description: "...Step 4..."  (no name:)
```
Renaming the file changes the invocable command. `git mv` preserves history.

### Composite + sync rules that this change must honor (from CLAUDE.md & profile.md)

1. **Composite commands track single-step commands** — `work.md`/`quickfix.md` re-describe
   and delegate to the three renamed commands; they're in the inventory and updated in the
   same change. (`profile.md:55-58`, `CLAUDE.md:153-173`)
2. **AskUserQuestion block duplicated byte-identically across 7 files** — renaming files
   doesn't alter the block's content, but `CLAUDE.md:200-201` lists the *filenames* and must
   be updated to the new names. The block bytes stay identical.
3. **`/tce:refresh` ↔ `/tce:init` sync** — not affected (neither command's analysis text
   names the three commands; refresh has 0 refs).

### Cross-plugin / release implications

- **tce**: the substantive change. Current version `2.1.0`. Removing user-facing command
  names (`/tce:research_codebase` etc. stop existing) is a **breaking** interface change.
- **tmt**: only `commands/create.md` doc-suggestion strings change (tmt points users at the
  downstream tce commands). Current version `1.0.0`. A doc-text touch → patch-level.
- Release flow (profile.md:62-64): bump `plugin.json` **and** the `marketplace.json` entry,
  then `claude plugin tag ./plugins/<name>`.

## Code References

- `plugins/tce/scripts/check-init.sh:61` — survivor #1 (template detection signature)
- `CLAUDE.md:113` — survivor #2 (prose documenting that signature)
- `CLAUDE.md:157-161` — composite-chain prose (update)
- `CLAUDE.md:168-169` — composite-tracking RULE command list (update)
- `CLAUDE.md:200-201` — AskUserQuestion-duplication filename list (update)
- `plugins/tmt/commands/create.md:21-22,393` — tmt's references to the tce chain (update)
- `plugins/tce/README.md:57,136-139` — tool table + workflow table (update)
- `.claude/tce/tickets.md:74`, `.claude/tce/profile.md:55-58` — this repo's own config (update)

GitHub blob base (pushed `HEAD`): `https://github.com/tobyS/toby-plugins/blob/98f1c53/`

## Architecture Insights

- The repo's own conventions (`CLAUDE.md`) are the single biggest source of "trap"
  references because they *document* the migration-detection signature using the very string
  being renamed. The discipline of surgical edits the repo already mandates is exactly what's
  needed here.
- Because command identity is filename-derived with no `name:` frontmatter, the rename is
  robust: there is no second place where the old name is authoritatively bound.

## Open Questions

Only one decision needs human judgment (everything else is resolved above):

- **Version bump levels.** tce removes user-facing command names — semantically breaking.
  Recommended: tce `2.1.0 → 3.0.0` (major), tmt `1.0.0 → 1.0.1` (patch, doc-only). The repo's
  versioning has been loose historically (tce already at 2.1.0), so a minor bump for tce is
  defensible if breaking-ness is judged low. → taken to the question checkpoint.
