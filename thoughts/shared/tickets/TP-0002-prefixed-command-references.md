# TP-0002: Use installed (prefixed) command names in all plugin command references

**Status:** Done
**Estimated Complexity:** Small
**Created:** 2026-06-12
**Updated:** 2026-06-12

## Problem Statement

Since the tce/tmt plugin split, the workflow commands are installed and invoked
with a plugin prefix (`/tce:research_codebase`, `/tce:create_plan`,
`/tce:implement_plan`, `/tce:design_explore`, `/tce:code_review`,
`/tce:commit`, `/tce:quickfix`, `/tce:work`, `/tce:discuss`). However, the tce
command files still reference these commands in their original, un-prefixed
form (`/research_codebase`, `/create_plan [PREFIX]-XXXX`, …). When a command
tells the user "Next command: `/create_plan [PREFIX]-XXXX`" and the user types
that verbatim, Claude Code reports an unknown command — and the model itself is
primed to suggest the wrong names.

## Desired Outcome

Every reference to a tce (or tmt) command inside the plugins uses the
installed, prefixed form. A user who copies any suggested next command verbatim
gets a working invocation.

## User Stories / Use Cases

- As a tce user, I want the "next command" hints at the end of each workflow
  step to be copy-pasteable so that I can move to the next step without
  guessing the real command name.
- As a tce user reading a command's workflow table, I want to see the actual
  command names so that the docs match what my `/` autocomplete shows.

## Acceptance Criteria

- [x] All user-facing "next command" recommendations use the prefixed form
      (e.g. `research_codebase.md` suggests `/tce:create_plan [PREFIX]-XXXX`,
      `create_plan.md` suggests `/tce:implement_plan [PREFIX]-XXXX`, the
      `/design_explore` suggestions in `create_plan.md` and
      `implement_plan.md` become `/tce:design_explore`).
- [x] All other references are prefixed too: workflow-overview tables in every
      tce command header, usage examples/tips (e.g. `code_review.md`,
      `create_plan.md`), and internal cross-references like "follow the
      process from `/research_codebase`" in `work.md` and `quickfix.md`.
- [x] `grep -rn` over `plugins/` for the un-prefixed command names
      (`/research_codebase`, `/create_plan`, `/implement_plan`,
      `/design_explore`, `/code_review`, `/quickfix`, `/work`, `/discuss`,
      `/commit` where it means the tce command) returns no hits that refer to
      a tce/tmt command without its plugin prefix.
- [x] tmt command files are checked the same way (current grep suggests they
      are already prefixed, e.g. `tmt/commands/create.md`).

## Out of Scope

- Renaming any command or changing command behavior — this is a text-only
  consistency fix.
- Changes to project-side files (`.claude/tce/`, `.claude/tmt/`,
  `thoughts/`) of consuming projects; only the plugin sources in `plugins/`
  (and, if affected, their READMEs/templates) are in scope.
- Making the prefix configurable or detecting how the plugin was installed —
  the marketplace install form (`tce:`/`tmt:`) is the canonical invocation.

## Open Questions

None.

## Questions for Research/Planning

- [ ] Compile the definitive list of files/lines with un-prefixed references
      (initial grep found them in `work.md`, `quickfix.md`,
      `research_codebase.md`, `create_plan.md`, `implement_plan.md`,
      `code_review.md`; check `commit.md`, `discuss.md`, `design_explore.md`,
      hooks/scripts output strings, READMEs, and `templates/` too).
- [ ] Decide how to handle `/commit` mentions — distinguish the tce command
      from generic "commit" prose.
- [ ] Composite-command rule: `work.md` and `quickfix.md` mirror the
      single-step commands — confirm the renamed references stay in sync per
      the repo's composite-command rule.
- [ ] Check whether `check-init.sh`'s `additionalContext` text and the
      `userConfig` greeting mention commands un-prefixed.

## References

- `plugins/tce/commands/research_codebase.md:305` — `Next command:
  /create_plan [PREFIX]-XXXX` (example of the user-facing breakage)
- `plugins/tce/commands/create_plan.md:551` — `Next command:
  /implement_plan [PREFIX]-XXXX`
- Repo instructions (`CLAUDE.md`) — composite commands must track single-step
  commands; update `work.md`/`quickfix.md` in the same commit.

## Implementation Plan

`thoughts/shared/plans/2026-06-12-TP-0002-prefixed-command-references.md`
(research: `thoughts/shared/research/2026-06-12-TP-0002-prefixed-command-references.md`)

## Notes & Updates

### 2026-06-12
- Scope decision: fix **all** un-prefixed references (user-facing hints,
  workflow tables, and internal cross-references), not just the "next
  command" hints — for consistency and so the model isn't primed to suggest
  non-existent command names.
- Complexity rated Small: text-only edits across ~7 command files, no
  behavior change.
- Implemented and verified: un-prefixed references existed only in 7 tce
  command files; tmt, scripts, templates, manifests were already prefixed.
  Per user decision, root `CLAUDE.md` chain descriptions were prefixed too
  (beyond the original `plugins/` scope). The convention line in
  `work.md`/`quickfix.md` was reworded to prescribe prefixed names in prose,
  and the stale `/implementation_plan` example in `create_plan.md` was fixed
  to `/tce:implement_plan`.
