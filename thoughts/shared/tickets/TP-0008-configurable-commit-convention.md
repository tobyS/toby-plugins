# TP-0008: Make commit convention configurable via /tce:init

**Status:** Open
**Estimated Complexity:** Medium
**Created:** 2026-06-15
**Updated:** 2026-06-15

## Problem Statement

tce hardcodes **Conventional Commits** in `plugins/tce/commands/commit.md` (the `<keyword>(<ticket-id>): <description>` format, fixed keyword list, 72-char rule). Every command that writes a commit — `/tce:commit`, the commit steps in `/tce:implement` and `/tce:quickfix`, and `/tce:ticket`'s docs-only ticket commit — inherits this style. That convention is the maintainer's personal preference, baked into the plugin, which violates the core design rule that nothing project-specific belongs in a command. A consuming team that uses a different commit convention has no way to express it.

## Desired Outcome

`/tce:init` lets the project agree a **commit convention** from a small set of standard options, persists the choice (and its full message-format spec, including ticket-ID placement) to `.claude/tce/profile.md`, and every commit-writing tce command reads that config and follows it instead of assuming Conventional Commits. A freshly initialised project that picks a non-default convention produces commits in that style with no further configuration.

## User Stories / Use Cases

- As a developer adopting tce in a team that already uses a fixed commit convention, I want to select that convention at init so tce's commits match my repo's history and pass our commit linters.
- As the tce maintainer, I want my Conventional Commits style to be the recommended default so my own projects keep working unchanged.
- As a developer on an issue-tracker-backed project, I want a `#<ticket-number>: <message>` style so commits link to issues the way that backend expects.
- As a developer initialising tce in an existing repo, I want init to detect the convention already used in git history and pre-select it, so I usually just confirm.

## Acceptance Criteria

- [ ] `/tce:init` presents a commit-convention choice with at least: **Conventional Commits** (recommended default), **Plain/freeform**, and **`#<ticket-number>: <message>`**.
- [ ] During init, recent git history is inspected and the matching convention is offered as the pre-selected default; if detection is inconclusive, Conventional Commits is the default.
- [ ] The chosen convention is persisted to `.claude/tce/profile.md` as a named section that records both the convention and its concrete message-format spec, including where the ticket ID goes for that convention.
- [ ] Each convention defines its own ticket-ID placement (e.g. Conventional `type(TP-0008): …`; `#<n>` style `#8: …`; plain `TP-0008: …`), and the stored spec captures it unambiguously.
- [ ] `/tce:commit` reads the convention from `profile.md` and writes messages in that style; with no config present it falls back to Conventional Commits (today's behaviour).
- [ ] The commit steps in `/tce:implement`, `/tce:quickfix`, and `/tce:ticket`'s docs-commit produce messages consistent with the configured convention (composite/derived commands stay in sync per the repo's composite-command rule).
- [ ] Re-running `/tce:init` on a project initialised before this feature detects the missing commit-convention config and walks the user through choosing it (added to init's Idempotency upgrade list), and the `tce-config-version` marker is bumped accordingly.
- [ ] `plugins/tce/README.md`, the `profile.md` template, and `commit.md` are updated together so the documented behaviour, the seeded config structure, and the runtime instruction don't drift.

## Out of Scope

- Extending `/tce:refresh` to reconcile commit convention (deliberate: this ticket handles existing projects through init's idempotency upgrade only). See the open question below about the Phase-1 mirror rule.
- Gitmoji and other conventions beyond the three listed (can be added later once the mechanism exists).
- Enforcing/validating commit messages against the chosen convention via a hook (tce writes messages; it doesn't police hand-written ones).
- Per-commit-type keyword customisation within Conventional Commits.
- Changing tmt's ticket envelope, status hooks, or anything under `thoughts/shared/`.

## Open Questions

None blocking — the convention set and ID-placement model are decided.

## Questions for Research/Planning

- [ ] Where exactly in `profile.md` should the commit-convention section live, and what structure best lets `commit.md` read it deterministically at runtime (it's markdown, not machine config)?
- [ ] How should the ticket-ID token resolve per backend? For tmt the canonical ID is `TP-0008`, so `#<ticket-number>` needs a defined mapping (bare number vs full ID) — coordinate with `.claude/tce/tickets.md`'s canonical-ID rules.
- [ ] How robust can git-history detection be, and what heuristic distinguishes Conventional from plain from `#<n>` styles? What's the fallback when history is empty or mixed?
- [ ] The repo rule "when `/tce:init` Phase 1 detects something new, update `/tce:refresh` Phase 1 in the same commit" — does adding history-based convention detection to init trigger it, even though refresh reconciliation is out of scope? Resolve during planning.
- [ ] Exact spec text for each convention's format (keyword list, subject rules, ID placement) to store in the profile and reference from `commit.md`.

## References

- `plugins/tce/commands/commit.md` (current hardcoded Conventional Commits format)
- `plugins/tce/commands/{implement,quickfix,ticket}.md` (other commit-writing sites)
- `plugins/tce/templates/tce/profile.md` (where the new config section is seeded)
- `plugins/tce/commands/init.md` (Idempotency upgrade list + version marker)
- CLAUDE.md: core design rule, composite-command sync rule, migrations & version markers

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-06-15
- Convention set decided: Conventional Commits (default), Plain/freeform, `#<ticket-number>: <message>`; git-history detection pre-selects the default. (Gitmoji dropped from the initial set; deferred to Out of Scope.)
- Ticket-ID placement: each convention owns its placement; init stores the full format spec ("Convention decides").
- Existing-project migration via init's idempotency upgrade list; `/tce:refresh` deliberately out of scope, with a flagged question about the Phase-1 mirror rule.
- Complexity Medium: touches init (new dialog + detection + upgrade list + version marker), profile template, commit.md, and three derived commit sites, plus docs — broad but mechanical, no architectural risk.
