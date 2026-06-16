# TP-0010: Offer a commit-frequency preference during /tce:init

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-06-16
**Updated:** 2026-06-16

## Problem Statement

Once `/tce:implement` commits in logical groups (TP-0009), how often it commits
is currently a fixed default. Different teams and developers prefer different
commit granularity — some want a commit per phase, some per small logical unit,
some only at meaningful checkpoints. There is no per-project way to express that
preference, so the behavior can't be tuned without editing the command.

This is the TODO captured during TP-0009: we could ask the user for their commit
frequency preference during `/tce:init` and record it in the project profile so
`/tce:implement` (and the composites) honor it.

## Desired Outcome

`/tce:init` offers the user a commit-frequency preference, stores it in
`.claude/tce/profile.md`, and `/tce:implement` reads it to decide how granularly
to commit — with a sensible default when unset.

## User Stories / Use Cases

- As a developer setting up tce in a project, I want to state how often I want
  implementation commits so that the workflow matches my team's history style
  without me editing command files.
- As a developer, I want a sensible default if I don't care, so init doesn't
  force a decision on me.

## Acceptance Criteria

- [ ] `/tce:init` asks for a commit-frequency preference (e.g. per logical group
      / per phase / single commit at end) via an AskUserQuestion dialog, with a
      recommended default and the option to skip.
- [ ] The chosen preference is written to `.claude/tce/profile.md` in a clear,
      documented location.
- [ ] `/tce:implement` reads the preference from `profile.md` and adjusts commit
      granularity accordingly; absent/unset falls back to the TP-0009 default
      (per logical group).
- [ ] `/tce:refresh` reconciles the preference (preserves an existing value,
      can add it if missing) consistent with how it handles other profile
      sections.
- [ ] The `profile.md` template skeleton in `plugins/tce/templates/tce/`
      documents the new field.

## Out of Scope

- The core "commit in logical groups + validate tests before commit" behavior
  in `/tce:implement` (delivered by TP-0009 — this ticket only makes the
  granularity configurable).

## Open Questions

- [ ] What is the right set of preference options, and what should the default
      be? (Leaning: per logical group as default, matching TP-0009.)

## Questions for Research/Planning

- [ ] Where in `profile.md` should the preference live, and how should it be
      phrased so `/tce:implement` can read it unambiguously (it's markdown, not
      machine-parsed config)?
- [ ] Per CLAUDE.md "/tce:refresh re-analysis must track /tce:init's analysis":
      any new field init detects/writes must be reconciled by refresh in the same
      change.
- [ ] Per the AskUserQuestion duplicated-guidelines rule, adding a dialog to
      `init.md` must follow the shared dialog-guidelines block.
- [ ] Should composites `/tce:work` / `/tce:quickfix` expose or override the
      preference, or simply inherit whatever `/tce:implement` reads?

## References

- TP-0009 — `/tce:implement` intermediate commits (prerequisite; defines the
  default granularity this preference overrides).
- `plugins/tce/commands/init.md`, `plugins/tce/commands/refresh.md`.
- `plugins/tce/templates/tce/profile.md` — profile skeleton.
- CLAUDE.md — "/tce:refresh re-analysis must track /tce:init's analysis";
  "AskUserQuestion guidelines block is duplicated".

## Implementation Plan

## Notes & Updates

### 2026-06-16

Split out of TP-0009 at ticket-creation time: rather than fold the init
commit-frequency idea into the implement fix, it becomes its own ticket.
Depends on TP-0009 establishing the baseline commit behavior and default
granularity.
