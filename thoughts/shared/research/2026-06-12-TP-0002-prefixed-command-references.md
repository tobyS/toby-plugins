---
date: 2026-06-12
ticket: TP-0002
topic: "Use installed (prefixed) command names in all plugin command references"
status: complete
git_commit: 161df12119e772712957785a600a138d8cce7aaf
branch: main
---

# Research: TP-0002 — Use installed (prefixed) command names in all plugin command references

**Date:** 2026-06-12
**Ticket:** `thoughts/shared/tickets/TP-0002-prefixed-command-references.md`
**Git commit at research time:** `161df12` (main)

## Research Question

Since the tce/tmt plugin split, commands are installed with a plugin prefix
(`/tce:research_codebase`, `/tmt:create`, …), but the command files still
reference each other un-prefixed (`/research_codebase`, `/create_plan
[PREFIX]-XXXX`, …). Compile the definitive list of un-prefixed references in
`plugins/` and determine how to fix each, distinguishing real command
references from generic English ("commit the file") and from false substring
matches.

## Summary

An exhaustive grep over `plugins/` (commands, agents, hooks, scripts,
templates, READMEs, plugin manifests) found **un-prefixed command references in
exactly 7 files, all in `plugins/tce/commands/`**: `research_codebase.md`,
`create_plan.md`, `implement_plan.md`, `code_review.md`, `work.md`,
`quickfix.md`, and `discuss.md`. Everything else — the entire tmt plugin, tce's
`init.md`/`commit.md`/`design_explore.md`, all agents, hooks, scripts
(including `check-init.sh`'s additionalContext text), templates, READMEs, and
both `plugin.json` manifests (including the `userConfig` greeting) — is already
prefixed or contains no command references. The fix is a mechanical
text replacement plus three special cases: a convention-stating line duplicated
in `work.md`/`quickfix.md` that itself prescribes bare names, verbatim
AskUserQuestion dialog copy governed by the TP-0001 contract, and a stale
`/implementation_plan` example in `create_plan.md` (a command name that never
existed). The repo-root `CLAUDE.md` also has a few un-prefixed references but
is outside the ticket's stated scope (decision deferred to the user).

## Detailed Findings

### Change sites (definitive work list)

Classification: (a) user-facing "next command" hint, (b) workflow-overview
table, (c) internal cross-reference in prose, (d) self-reference / usage line /
example invocation.

#### `plugins/tce/commands/research_codebase.md` — 6 lines

| Line | Class | Reference |
|------|-------|-----------|
| 47 | b, d | `/research_codebase` (own row in workflow table) |
| 48 | b | `/create_plan` |
| 49 | b | `/implement_plan` |
| 326 | a | `Next command: /create_plan [PREFIX]-XXXX` — the ticket's headline breakage |
| 332 | c | "use the `/commit` command to commit it" (tce command, not generic) |
| 342 | c | "use the `/commit` command to commit the updated research document" |

#### `plugins/tce/commands/create_plan.md` — 14 lines

| Line | Class | Reference |
|------|-------|-----------|
| 47–50 | b | workflow table: `/research_codebase`, `/create_plan` (own row), `/design_explore`, `/implement_plan` |
| 90 | c | "already been completed by `/research_codebase`" |
| 198–199 | d | usage tips: `/create_plan [PREFIX]-0001`, `/create_plan think deeply about [PREFIX]-0001` |
| 310, 318 | c | suggest/stop-for `/design_explore`, return to `/create_plan` |
| 314 | a | verbatim user-facing copy: "Would you like to run `/design_explore` first…" |
| 583 | a | `Next command: /implement_plan [PREFIX]-XXXX` |
| 598 | c | "use the `/commit` command to commit it" |
| 601 | c | "The user will start the implementation themselves by running `/implement_plan`" |
| 762 | d | `User: /implementation_plan` — **stale name; no such command ever existed** (real command: `implement_plan`). Fix to `/tce:implement_plan`. |

#### `plugins/tce/commands/implement_plan.md` — 7 lines

| Line | Class | Reference |
|------|-------|-----------|
| 27–30 | b | workflow table: `/research_codebase`, `/create_plan`, `/design_explore`, `/implement_plan` (own row) |
| 66 | c | "assembled by `/research_codebase` and `/create_plan`" |
| 177 | a | verbatim user-facing copy: "Would you like to run `/design_explore` first…" |
| 179 | c | "The user will run `/design_explore`…" |

#### `plugins/tce/commands/code_review.md` — 8 lines

| Line | Class | Reference |
|------|-------|-----------|
| 32–35 | b | workflow table: `/research_codebase`, `/create_plan`, `/implement_plan`, `/code_review` (own row) |
| 104 | d | tip: `/code_review [PREFIX]-0001 focus on security concerns` |
| 442, 451, 461 | d | example invocations `User: /code_review …` |

#### `plugins/tce/commands/work.md` — 23 lines

| Line | Class | Reference |
|------|-------|-----------|
| 14 | c | chain description: `/research_codebase` → `/create_plan` → `/implement_plan`, plus `/commit` |
| 20 | **convention line** | "…use its namespaced name (e.g., `tce:create_plan`). **In prose, sibling commands are referenced by their bare name** (e.g., `/research_codebase`)." — states the very convention TP-0002 abolishes; must be reworded, not just substituted |
| 22, 50, 65, 74, 77, 79, 88, 90, 179, 187, 189, 207, 219, 252 | c | prose cross-references to `/research_codebase`, `/create_plan`, `/implement_plan` |
| 24 | d | `**Usage:** /work [PREFIX]-XXXX` (self-reference) |
| 94, 193, 224, 250 | c | `/commit` workflow references (tce command) |
| 154, 156 | a | **verbatim AskUserQuestion dialog copy** (TP-0001 contract): "Run /design_explore before planning?" + option text "you run /design_explore to pick a direction" |

#### `plugins/tce/commands/quickfix.md` — 17 lines

| Line | Class | Reference |
|------|-------|-----------|
| 14–15 | c | chain description: `/research_codebase` → `/create_plan` → `/implement_plan`, plus `/commit` |
| 20 | **convention line** | second copy of the work.md:20 convention line (example: `/create_plan`) — reword in lock-step |
| 22 | c | lock-step rule mentions `/research_codebase`, `/create_plan`, `/implement_plan`, `/commit` |
| 152, 161 | d | **inside the inlined ticket template** (text emitted into consuming projects' ticket files): "Quickfix initiated via `/quickfix` command", "Quickfix ticket auto-created from `/quickfix` command" → `/tce:quickfix` |
| 164, 191, 213, 276 | c | `/commit` workflow references |
| 175, 179, 187, 200, 209, 222, 232, 273 | c | prose cross-references (`/research_codebase`, `/create_plan`, `/implement_plan`, `/design_explore`) |

#### `plugins/tce/commands/discuss.md` — 1 line

| Line | Class | Reference |
|------|-------|-----------|
| 15 | c | "NOT: … planning (`/create_plan`), implementation (`/implement_plan`), or codebase research (`/research_codebase`)" — `/tmt:create` on the same line is already prefixed |

### Already clean (verified, no changes needed)

- **Entire tmt plugin**: `commands/{init,create,list}.md`, `scripts/*`
  (error messages already say "Run /tmt:init"), `hooks/hooks.json`,
  `plugin.json`, `templates/tmt/` — the ticket's AC4 is already satisfied.
- **tce**: `init.md` (17 prefixed refs), `commit.md`, `design_explore.md`,
  `agents/*.md` (no command refs), `hooks/hooks.json`,
  `scripts/check-init.sh` (additionalContext heredoc uses `/tce:init`
  exclusively — answers the ticket's research question 4), `scripts/lib.sh`,
  `scripts/ticket.sh`, `templates/tce/*`, `README.md`,
  `.claude-plugin/plugin.json` (userConfig title/description use `/tce:init`).
- **Repo root `README.md`**: zero un-prefixed refs.

### False positives — must NOT be changed

- `init.md:85` — `/work` substring inside `.github/workflows/*`.
- `init.md:271` — `/commit` substring inside "filenames/commit scopes".
- `research_codebase.md` / `discuss.md` etc. — `/discuss` substring inside
  `thoughts/shared/discussions/` paths.
- `ticket.sh:4,20` — "Usage: ticket.sh" refers to the shell script, not a command.
- Generic English "commit", "create", "list", "work", "discussion(s)" in prose
  and agent files.
- `CLAUDE.md:141–142` — bare names (`research_codebase`, `create_plan`, …) name
  the command *files* for the composite-command rule, and `:158–159` is a
  file-path glob.
- Skill-tool invocation names (`tce:create_plan` etc., no slash) — already
  namespaced; these are the Skill tool's identifier form, not user-facing
  slash invocations. Correct as-is.

### Out of ticket scope, but found

- **Repo-root `CLAUDE.md` lines 130–134**: the composite-command section
  describes the chains with un-prefixed names (`/research_codebase` →
  `/create_plan` → `/implement_plan` ×2). The ticket's Out of Scope limits
  changes to `plugins/` (+ READMEs/templates if affected); CLAUDE.md is this
  repo's own instructions file. Whether to fix it alongside is a user
  decision (open question 1).

### Special cases and how they interact with repo rules

1. **The convention line (work.md:20 / quickfix.md:20).** It currently
   *prescribes* bare names in prose — the exact behavior TP-0002 abolishes. A
   plain find-replace would leave a self-contradictory sentence. It must be
   reworded to prescribe the prefixed form in prose too (e.g. "In prose,
   sibling commands are referenced by their installed, prefixed name (e.g.,
   `/tce:research_codebase`)."). The two copies differ only in the example
   command and must be updated in lock-step (composite-command rule).
2. **Verbatim AskUserQuestion dialog copy (work.md:154–156; create_plan.md:314
   carries the equivalent single-step wording, implement_plan.md:177 likewise).**
   Per the TP-0001 contract, this wording is part of the commands' contract and
   changes go through normal commits/review — which this ticket's workflow is.
   Changing `/design_explore` → `/tce:design_explore` inside the dialog copy is
   in scope and *required* (it is the most user-facing place of all). The
   composite-command rule requires work.md's dialog question and
   create_plan.md/implement_plan.md's prose offers to stay consistent.
3. **`/commit` disambiguation (ticket research question 2).** Every `/commit`
   occurrence in plugins/ that has a leading slash refers to the tce command
   (always phrased "the `/commit` command" or "the `/commit` workflow") →
   all become `/tce:commit`. Generic commit prose never uses a slash, so the
   slash is a reliable discriminator. Verified: no exceptions.
4. **The `/implementation_plan` typo (create_plan.md:762).** Stale name in an
   example dialogue; fix to `/tce:implement_plan` (typo fix riding along —
   strictly more correct than a pure prefix substitution).
5. **quickfix's inlined ticket template (quickfix.md:152,161).** This text is
   written into consuming projects' ticket files. tmt's `/tmt:create` template
   has no corresponding "Quickfix initiated" line, so no cross-plugin
   template sync is triggered; the change is local to quickfix.md.
6. **The duplicated AskUserQuestion *guidelines* block** (six copies) contains
   no slash-command references — TP-0002 does not touch it, so the
   byte-identical-duplication rule is not triggered.

## Code References

- `plugins/tce/commands/research_codebase.md:326` — headline breakage (`Next command: /create_plan …`)
- `plugins/tce/commands/create_plan.md:583` — second next-command hint
- `plugins/tce/commands/create_plan.md:762` — stale `/implementation_plan`
- `plugins/tce/commands/work.md:20`, `plugins/tce/commands/quickfix.md:20` — convention line to reword
- `plugins/tce/commands/work.md:154-156` — TP-0001-governed dialog copy with `/design_explore`
- `plugins/tce/commands/quickfix.md:152`, `:161` — inlined ticket template
- `plugins/tce/scripts/check-init.sh:58-73` — verified already prefixed
- `plugins/tce/.claude-plugin/plugin.json:19-20` — userConfig greeting, verified already prefixed

## Historical Context (from thoughts/)

- `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md` — TP-0001
  research; established that dialog copy in these same files is contractual and
  wording changes go through commits/review (which permits this ticket's edits).
- `thoughts/shared/plans/2026-06-12-TP-0001-askuserquestion-copy.md` — TP-0001
  plan; the dialog-copy regions it touched in `work.md` overlap with TP-0002's
  edit at lines 154–156 (TP-0001 landed first; no conflict, just adjacency).

## Open Questions

1. **Root `CLAUDE.md` (lines 130–134):** fix its un-prefixed chain descriptions
   in the same commit (consistent, but beyond the ticket's stated `plugins/`
   scope), or leave as-is per the ticket's Out of Scope?

All other ticket research questions are resolved:
- Definitive file/line list: compiled above (7 files, all in `plugins/tce/commands/`).
- `/commit` handling: leading slash reliably marks the tce command → `/tce:commit`; slash-less prose untouched.
- Composite-command rule: work.md/quickfix.md edits are part of the same change set; the convention line is duplicated and must change in both.
- `check-init.sh` and the userConfig greeting: already prefixed, nothing to do.
