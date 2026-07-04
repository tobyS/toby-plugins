# TP-0017: Adopt command/agent frontmatter machinery (invocation control, tool pre-approval, agent models)

**Status:** In Progress
**Estimated Complexity:** Small
**Created:** 2026-07-03
**Updated:** 2026-07-04

## Problem Statement

The independent plugin review (`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`, Section 2,
finding 4) found tce uses none of the newer command/agent frontmatter levers
Claude Code provides. Concrete costs today:

- Side-effectful workflow commands (`init`, `implement`, `quickfix`, `commit`)
  are model-invocable, and their descriptions sit in the always-on skill
  listing even though they should only ever be user-triggered.
- Calls to the shipped `${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh` discovery
  script can trigger a permission prompt on every use because no command
  pre-approves it via `allowed-tools`.
- All six research agents run `model: inherit`; the pure find-and-categorize
  agents (`codebase-locator`, `thoughts-locator`) pay full-model latency and
  cost for work a smaller model does equally well.
- Boilerplate like "first run ticket.sh and read its output" could potentially
  use dynamic context injection instead.

## Desired Outcome

tce commands and agents use the frontmatter features where they help, with one
hard constraint: the composites must keep working. `/tce:work` and
`/tce:quickfix` invoke sibling commands (`tce:ticket`, `tce:plan`,
`tce:implement`, `tce:commit`) via the Skill tool, so blanket
`disable-model-invocation: true` would break them — the classification of
which commands may disable model invocation must respect the delegation graph.

## User Stories / Use Cases

- As a tce user, I want the discovery script to run without a permission
  prompt every time so that research/plan/implement flow without interruption.
- As a tce user, I don't want the model spontaneously invoking `/tce:init` or
  `/tce:quickfix` — those are my calls to make.
- As a tce user, I want locator subagents to return faster and cheaper with no
  loss of quality.

## Acceptance Criteria

- [ ] Every tce command is classified (model-invocable vs user-only) with the
      decision recorded; `disable-model-invocation: true` is applied only
      where it cannot break composite Skill-tool delegation, verified by
      running `/tce:work` and `/tce:quickfix` end-to-end in a scratch project.
- [ ] Commands that call `ticket.sh` declare `allowed-tools` such that the
      script runs without a permission prompt (verified in a scratch project).
- [ ] Agent `model` choices are reviewed; the locator agents are moved to a
      cheaper/faster model if a comparison run shows no quality loss; the
      decision (either way) is recorded.
- [ ] Dynamic context injection (`` !`cmd` ``) is evaluated for the ticket.sh
      preamble; adopted only if it works in plugin commands and simplifies the
      prompt — otherwise explicitly rejected with a note.
- [ ] Every frontmatter field used is verified as supported for plugin
      `commands/*.md` / `agents/*.md` in current Claude Code documentation
      before adoption (no cargo-culting from docs written for project-local
      skills).

## Out of Scope

- `context: fork` for research or any composite-session restructuring (review
  finding 2.3, unticketed).
- Command body length/deduplication (TP-0016).
- Any behavior change to the workflow itself.

## Open Questions

None at ticket level.

## Questions for Research/Planning

- [ ] Map the delegation graph precisely: which commands are invoked via the
      Skill tool by `work.md` and `quickfix.md` (including `/tce:commit`, which
      research/plan also invoke) — these must stay model-invocable.
- [ ] Does `disable-model-invocation` also suppress Skill-tool invocation, or
      only spontaneous model triggering? (Determines whether the constraint
      above binds at all — verify against current docs, don't assume.)
- [ ] Exact `allowed-tools` syntax for pre-approving a
      `${CLAUDE_PLUGIN_ROOT}`-relative script, and whether the substitution
      happens before permission matching.
- [ ] Which model the locators should target and how to spot-check quality
      parity cheaply.

## References

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 2, finding 4 (sources:
  code.claude.com skills/sub-agents docs).
- `plugins/tce/commands/*.md` frontmatter (currently `description` +
  `argument-hint` only), `plugins/tce/agents/*.md` frontmatter (`model:
  inherit` throughout).
- `CLAUDE.md` — composite-tracking rule (the delegation constraint).

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-07-03
Created from the independent plugin review (Fable 5). The composite-delegation
constraint (Skill-tool invocation vs `disable-model-invocation`) was flagged at
ticket creation as the one thing research must resolve before any frontmatter
is applied.
