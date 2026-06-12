# TP-0001: Prescribed copy for AskUserQuestion dialogs

**Status:** Done
**Estimated Complexity:** Small
**Created:** 2026-06-12
**Updated:** 2026-06-12

## Problem Statement

The AskUserQuestion dialogs in the tce and tmt commands have no prescribed
copy: the commands say *that* a question must be asked (and roughly which
options to offer) but not *how* to phrase it. The wording is improvised at
runtime, so every run can sound different — and the first dogfood run of
`/tmt:init` and `/tce:init` produced awkward phrasing, e.g. context crammed
into parentheticals inside the question text ("(tickets will be named TP-0001,
… source: derived from the repo name — no existing tickets or legacy config
found)").

What worked well and should be kept as a pattern: the detected/recommended
option listed first with "(Recommended)" in its label and the detection
reasoning in its description.

## Desired Outcome

- **Predictable dialogs carry verbatim copy in the command files**: intro text
  (printed as a normal message above the dialog), question text, header chip,
  option labels, and option descriptions. Concretely: the `/tmt:init` prefix
  question and the `/tce:init` ticket-system, status-transitions, and
  ticket-creation questions.
- **Dynamic dialogs follow shared copy guidelines** (content depends on the
  run: `/tce:work`'s open-questions checkpoint, the research sufficiency
  check, `/tce:create_plan`'s open questions): structure (short intro
  paragraph, then the dialog), tone (plain, concise, no nested
  parentheticals), recommended-first with reasoning in the description, and
  respect for the tool's limits (≤4 questions per call, ≤4 options, "Other"
  is added automatically — never offer it as an option).
- Every run of the init commands sounds the same; copy improvements are
  versioned like code.

## User Stories / Use Cases

- As a plugin user running an init command, I want clearly phrased setup
  questions with brief context above them, so that I can decide quickly
  without re-reading.
- As the plugin author, I want the question copy fixed in the command files,
  so that every run sounds the same and copy improvements are versioned like
  code.

## Acceptance Criteria

- [x] `/tmt:init` contains verbatim intro + question + option copy for the
      prefix dialog
- [x] `/tce:init` contains verbatim intro + question + option copy for the
      ticket-system, status-transitions, and ticket-creation dialogs
- [x] All other AskUserQuestion sites in tce/tmt commands reference shared
      copy guidelines (intro-text pattern, recommended-first with reasoning,
      concise phrasing, tool limits)
- [x] The verbatim copy was reviewed and approved by Toby before merging
      (interactive copy-review checkpoint during implementation)
- [x] Composite commands (`work.md`, `quickfix.md`) are updated in the same
      commit where they mirror affected dialogs

## Out of Scope

- Redesigning *which* questions the init flows ask, or the flows themselves
- Copy of non-AskUserQuestion prose blocks (proposal templates, hand-off
  messages, etc.)

## Open Questions

None — the one judgment call (the actual wording) is deliberately deferred to
the in-implementation review checkpoint with Toby.

## Questions for Research/Planning

- [ ] Inventory all AskUserQuestion mentions across `plugins/tce/commands/`
      and `plugins/tmt/commands/` — which are predictable (verbatim copy) vs
      dynamic (guidelines)?
- [ ] Where should the shared copy guidelines live so both plugins' commands
      can follow them without cross-plugin references — repeated per command,
      or one block per plugin?
- [ ] Does the AskUserQuestion tool render markdown in option descriptions,
      and what length limits apply (header ≤12 chars; sensible label/
      description lengths)?

## References

- Dogfood session 2026-06-11/12: first runs of `/tmt:init` and `/tce:init`
  where the improvised question copy felt off
- AskUserQuestion tool constraints: ≤4 questions per call, 2–4 options each,
  automatic "Other" option, header chip ≤12 chars

## Implementation Plan

[Leave empty - will be filled when plan is created]

## Notes & Updates

### 2026-06-12
- Keep the "(Recommended)"-first pattern with detection reasoning in the
  option description — confirmed helpful in the dogfood run.
- Intro text above dialogs confirmed possible: text printed before the
  AskUserQuestion invocation renders above the dialog; prescribed copy comes
  as intro + question pairs so question text stays short.
- Complexity Small: markdown-only edits to command files, no script changes.
