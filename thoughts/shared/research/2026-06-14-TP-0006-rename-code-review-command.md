---
date: 2026-06-14
researcher: Claude (tce:quickfix)
ticket: TP-0006
topic: "Rename tce /code_review command to /review (the one TP-0005 missed)"
status: complete
base_commit: 0229353177ae9bd6648ca7cfd265546684f4e2b9
tags: [research, tce, rename, refactor, command-names]
---

# Research: Rename tce `/code_review` → `/review` — TP-0006

## Research Question

Rename the tce workflow command `code_review` → `review` as a hard rename (no
alias), mirroring TP-0005. Find **every live reference** to the old name across
both plugins and this repo's own config, categorize each as update / keep /
leave-as-history, and surface any traps that make this more than a blind
find-and-replace.

## Summary

The rename is mechanical and low-risk. The command is defined by a single file
(`plugins/tce/commands/code_review.md`) whose **filename determines the skill
name** (`tce:code_review` → `tce:review`); there is no `name:` in its
frontmatter, so a `git mv` plus reference updates is the whole job. Crucially,
**no sibling command cross-references it** (verified against work/quickfix/plan/
implement/discuss/design_explore), so there is no composite lock-step work
beyond the rename — `work.md`/`quickfix.md` never mention `/tce:code_review`.

Live references total six locations; one is intentionally left unchanged (a
descriptive keyword), and `thoughts/` history is never rewritten.

## Detailed Findings

### The command file itself

`plugins/tce/commands/code_review.md`:
- Skill name derives from filename → `git mv` to `review.md` makes it `tce:review`.
- Frontmatter `description:` (line 2) describes the review; no `name:` field, no change needed for the rename to take effect.
- H1 `# Code Review` (line 6) is a human-readable title — descriptive, can stay.
- Internal self-references to update: line 35 (workflow table row), line 104 (combine tip), lines 442 / 451 / 461 (example `User:` invocations).

### Live references elsewhere (must update)

| Location | What it is | Action |
|----------|-----------|--------|
| `plugins/tce/README.md:140` | command catalog table row `/tce:code_review` | → `/tce:review` |
| `plugins/tce/templates/tce/tickets.md:70` | "review checklist by `/tce:code_review`" | → `/tce:review` |
| `.claude/tce/tickets.md:71` | this repo's own (dogfooded) copy of the same line | → `/tce:review` |
| `plugins/tce/commands/init.md:123` | claude-template migration cleanup list | → `code_review`→`review` (see nuance below) |

### Reference intentionally kept

- `plugins/tce/.claude-plugin/plugin.json:14` — `"code-review"` is a **search
  keyword** describing the plugin's capability, not a command name. Renaming the
  command doesn't change that the plugin offers code review. Keep as-is. (The
  word "review" also appears descriptively in the `description` and `userConfig`
  text on lines 4/20 — already generic, no change.)

### Left as history (NOT touched)

All `thoughts/shared/{research,plans,tickets}/*` occurrences of `code_review`
are records of prior work (TP-0001/0002/0003/0005). Per repo convention,
historical thoughts are not rewritten.

## The one nuance: `init.md:123`

`init.md:123` lists the claude-template predecessor's command files that
`/tce:init` removes during migration:
`.claude/commands/{research,plan,implement,commit,code_review,design_explore,discuss}.md`.

The claude-template's *actual* legacy filenames were the long forms
(`research_codebase.md`, etc. — confirmed by `check-init.sh:61`, which keys on
`.claude/commands/research_codebase.md` as the template signature). **TP-0005
nonetheless rewrote this list to tce's *new* names** (git history:
`research_codebase,create_plan,implement_plan` → `research,plan,implement`).
So the list already tracks tce command names rather than the literal legacy
filenames.

Decision for this rename: follow the TP-0005 precedent and change `code_review`
→ `review` here too, so the entry doesn't become the lone old-name outlier in a
list that otherwise uses tce names. Whether that list *should* instead list the
template's literal legacy filenames is a pre-existing question, explicitly out
of scope for this quickfix (flagged to the user).

## Code References

- `plugins/tce/commands/code_review.md` — the command (rename target)
- `plugins/tce/README.md:140` — catalog row
- `plugins/tce/templates/tce/tickets.md:70` — template checklist line
- `.claude/tce/tickets.md:71` — dogfooded copy
- `plugins/tce/commands/init.md:123` — migration cleanup list
- `plugins/tce/.claude-plugin/plugin.json:14` — keyword (kept)
- `plugins/tce/scripts/check-init.sh:61` — claude-template signature (context)

## Profile Drift

None. `.claude/tce/profile.md` accurately describes the repo (markdown/bash/JSON
monorepo; commands = `claude plugin validate`; code map matches). No drift.

## Verification

- `claude plugin validate .`
- `claude plugin validate ./plugins/tce`
- `grep -rn "tce:code_review\|/code_review\|commands/code_review" plugins/ .claude/ README.md` → no hits (the rename target file is gone; thoughts/ excluded).
