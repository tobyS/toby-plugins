# TP-0005: Streamline tce command names

**Status:** Done
**Estimated Complexity:** Medium
**Created:** 2026-06-14
**Updated:** 2026-06-14

## Problem Statement

The tce workflow commands carry verbose, partly inaccurate names. `/tce:research_codebase`
also researches the web (not just the codebase), so the `_codebase` suffix understates
what it does. `/tce:create_plan` keeps a `create_` prefix that only made sense when a
sibling `create_ticket` command existed; ticket creation now lives in tmt, so the prefix
is vestigial. And `/tce:implement_plan` pairs awkwardly with a renamed `/tce:plan`. The
net effect is command names that are longer than necessary and no longer reflect the
workflow's actual shape.

## Desired Outcome

The three core workflow commands are renamed to short, accurate names, and every live
reference across both plugins and this repo's own dogfooded config points at the new
names. Invoking the workflow reads as `/tce:research` → `/tce:plan` → `/tce:implement`.

Renames (hard rename — no backward-compatible aliases or stubs; the old command names
cease to exist):

- `research_codebase` → `research`
- `create_plan` → `plan`
- `implement_plan` → `implement`

## User Stories / Use Cases

- As a tce user, I want to type `/tce:research`, `/tce:plan`, and `/tce:implement` so the
  command names are short and match what each step actually does.
- As a maintainer of this repo, I want every cross-reference (composite commands, docs,
  hooks, templates, CLAUDE.md) updated in lockstep so no command points at a name that no
  longer exists.

## Acceptance Criteria

- [ ] The three command files are renamed on disk: `plugins/tce/commands/research_codebase.md`
      → `research.md`, `create_plan.md` → `plan.md`, `implement_plan.md` → `implement.md`.
- [ ] Every **live** reference to the old command names (as `/tce:research_codebase`,
      `/tce:create_plan`, `/tce:implement_plan`, or the bare `research_codebase` /
      `create_plan` / `implement_plan` forms) is updated to the new names across:
      the renamed command bodies themselves, the composite commands `work.md` and
      `quickfix.md`, any cross-references in `discuss.md`, `code_review.md`, and the other
      tce commands, `plugins/tce/scripts/check-init.sh`, `plugins/tce/README.md`,
      `plugins/tce/templates/tce/tickets.md`, the root `CLAUDE.md`, `plugins/tmt/commands/create.md`,
      `plugins/tmt/README.md` (if it references them), and this repo's own
      `.claude/tce/profile.md` and `.claude/tce/tickets.md`.
- [ ] The composite-command sync rule and the refresh↔init sync rule in `CLAUDE.md` still
      hold: `work.md` / `quickfix.md` describe the renamed steps, and any prose naming the
      chain (e.g. "ticket → research → plan → implement") is consistent.
- [ ] No **live** plugin or config file contains a stale old-name reference (a grep for the
      old names over everything except `thoughts/` returns only intentional survivors —
      see the check-init.sh caveat below).
- [ ] Historical `thoughts/` documents (past tickets, research, plans, status files) are
      **not** modified — they are point-in-time records.
- [ ] `claude plugin validate .`, `claude plugin validate ./plugins/tce`, and
      `claude plugin validate ./plugins/tmt` all pass after the rename.
- [ ] tce's version is bumped and tagged (and tmt's, if its command/README text changed),
      per the marketplace release flow, with `marketplace.json` kept in sync.

## Out of Scope

- Renaming any other tce command (`code_review`, `commit`, `design_explore`, `discuss`,
  `init`, `quickfix`, `refresh`, `work`) — only the three named above change.
- Backward-compatible aliases, deprecation stubs, or forwarding for the old names.
- Rewriting historical `thoughts/` documents to use the new names.
- Any behavioral change to the commands — this is a pure rename + reference update.

## Open Questions

_None — scope decisions (hard rename, also shorten `implement_plan`, leave history alone)
were settled during ticket creation._

## Questions for Research/Planning

- [ ] **check-init.sh has two distinct kinds of reference — disentangle them.** The script
      uses `.claude/commands/research_codebase.md` as a *claude-template detection signature*
      (the legacy template's filename, which must stay to keep migrating old installs), but
      may also reference `/tce:research_codebase` in its *nudge text* (which should update to
      `/tce:research`). Confirm which occurrences are which before editing.
- [ ] Does `plugins/tce/README.md` (and `plugins/tmt/README.md`) describe the workflow chain
      anywhere beyond bare command links that also needs prose updates?
- [ ] Are the new command names free of collisions with any existing command across both
      plugins (`research`, `plan`, `implement` are currently unused — confirm)?
- [ ] Which plugins actually need a version bump (tce certainly; tmt only if its shipped
      files change), and what bump level — does a command rename count as a breaking change
      warranting a minor/major rather than patch?
- [ ] Do any hook configs (`plugins/*/hooks/hooks.json`) or scripts reference the command
      names and need updating?

## References

- `CLAUDE.md` — "Composite commands must track the single-step commands", "`/tce:refresh`
  re-analysis must track `/tce:init`", and the AskUserQuestion-duplication rule all govern
  files touched by this rename.
- Prior naming/reference work: TP-0002 (prefixed command references).

## Implementation Plan

[Leave empty - will be filled when plan is created]

## Notes & Updates

### 2026-06-14
Created after a scoping discussion. Key decisions:
- **Hard rename, no aliases** — tce exposes no external stable-command-name contract, so a
  clean break is acceptable.
- **Three renames, not two** — `implement_plan` → `implement` was added alongside the two
  originally requested so the workflow reads `/tce:plan` + `/tce:implement` consistently.
- **History is immutable** — only live plugin files and this repo's `.claude/tce/` config
  are updated; `thoughts/` records stay as written.
- Flagged the check-init.sh template-signature-vs-nudge-text subtlety as the main trap for
  planning.

### 2026-06-14 — Implemented (Done)
- `git mv`'d the three command files to `research.md`/`plan.md`/`implement.md` and updated
  every live reference across both plugins + this repo's `.claude/tce/` config and `CLAUDE.md`.
- The two survivor lines were left intact: `check-init.sh:61` (claude-template detection
  signature) and `CLAUDE.md:113` (prose documenting it). The feared check-init.sh
  "nudge-text" reference did not exist — its only occurrence was the survivor.
- Released **tce 3.0.0** (major — removing user-facing command names is breaking) and
  **tmt 1.0.1** (patch — doc-suggestion strings only) in `plugin.json` + `marketplace.json`.
- All three `claude plugin validate` runs pass; grep gate confirms only the two survivors
  remain outside `thoughts/`.
