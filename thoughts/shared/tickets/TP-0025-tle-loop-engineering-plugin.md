# TP-0025: tle plugin — loop-engineering workflow (goal definition + convergence loop)

**Status:** In Progress
**Estimated Complexity:** Large
**Created:** 2026-08-19
**Updated:** 2026-08-19

## Problem Statement

The marketplace has no way to run an autonomous convergence loop: "keep iterating
until a defined goal is verifiably reached." tce's ticket → research → plan →
implement chain is deliberately ceremony-heavy and human-gated — the right shape
for existing codebases, but too heavy for greenfield "build this small web app
until it works" projects. The user wants to experiment with loop engineering on a
new private tool, and the design for a dedicated plugin (tle — Toby Loop
Engineering) has been settled in a technical discussion.

## Desired Outcome

A third plugin `tle` exists in the toby-plugins marketplace, installable and
validating cleanly, implementing the design in
`thoughts/shared/discussions/2026-08-19-tle-loop-engineering-plugin.md`: an
interactive goal-authoring command, a slim agent-based convergence-loop runner
designed to run under Claude Code's built-in `/goal` backstop, and three
subagents (verifier, spec+plan, implementer) with file-only handoffs in
`thoughts/shared/loops/<goal-slug>/`. A user can take a prepared greenfield
web-app project from "goal discussed" to "goal verifiably reached" with three
inputs: `/tle:define`, one `/goal <condition>` paste, `/tle:run <goal-file>`.

## User Stories / Use Cases

- As a plugin user, I want to define a loop goal interactively so that the loop
  converges on a granular, machine-checkable definition of done instead of a
  vague prose goal.
- As a plugin user, I want to start a convergence loop that verifies, specs, and
  implements one small step per iteration so that a small web app gets built
  toward the goal without me driving each step.
- As a plugin user, I want every loop artifact (goal file, per-iteration verify
  reports and plans, loop log) persisted under `thoughts/shared/loops/<goal-slug>/`
  so that I can audit what the loop did after the fact and use tle and tce side
  by side in one project.
- As the marketplace maintainer, I want tle to follow the repo's design rules
  (project-agnostic, coordination only through project config files) so that it
  stays maintainable alongside tce and tmt.

## Acceptance Criteria

- [ ] `plugins/tle/` exists with its own `.claude-plugin/plugin.json` (version
      1.0.0) and an entry in `.claude-plugin/marketplace.json`;
      `claude plugin validate .` and `claude plugin validate ./plugins/tle` pass.
- [ ] `/tle:define` (flagged `disable-model-invocation: true`) runs a guided
      discussion and writes `thoughts/shared/loops/<goal-slug>/goal.md`
      containing: a granular checklist with per-item pass state and per-item
      verification method (command-with-exit-code preferred; browser checks as
      user-level scenarios, never selectors), ops facts (boot command, test
      command, base commit), budgets (at minimum max iterations), and a
      ready-to-paste `/goal` condition string.
- [ ] `/tle:run <goal-file>` (unflagged) first checks a goal condition is set
      (instructs the user to paste it if not), then loops: baseline check →
      dispatch verifier → surface the one-line verdict into the transcript →
      stall check (verify report identical to previous → escalate: fresh-context
      retry, strategy change, stop) → dispatch spec+plan agent → dispatch
      implementer → append iteration line to `loop-log.md`; the loop ends when
      the verifier reports all items passing or an escalation stops it.
- [ ] Three agents exist in `plugins/tle/agents/`: a fresh-context **verifier**
      that executes each checklist item's stated verification method,
      diff-reviews test files (tests may not be edited to pass), and writes
      per-item verdicts to `NNN-verify.md`; a **spec+plan agent** that reads
      goal + latest verify report and writes one small step to `NNN-plan.md`;
      an **implementer** that reads the plan file, implements, commits the green
      increment, and returns one line.
- [ ] File-only handoffs hold throughout: the runner's main context carries only
      file paths and one-line statuses, never document contents, diffs, or test
      output.
- [ ] Every tle agent reads `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` if
      present, as optional enrichment only — tle works without tce installed.
- [ ] `plugins/tle/README.md` documents the user flow (define → paste `/goal`
      condition → run), the greenfield-first scope, and chrome-devtools-mcp as a
      documented (not shipped) project-level dependency for browser
      verification; the root README catalog lists tle.
- [ ] No project-specific or stack-specific literals in any tle command, agent,
      or script (core design rule).

## Out of Scope

- A Stop-hook-based loop engine (the ralph-wiggum pattern) — documented fallback
  if same-session context accumulation bites in practice; separate ticket if
  needed.
- `/loop` compatibility work beyond leaving the runner unflagged.
- An initializer agent or project scaffolding — groundwork (dev env, boot
  script, basics) is done manually before the loop starts.
- Mid-run goal revision — goal files are immutable once a loop starts; a loop
  runs to its end or is killed, and a changed goal means a fresh `/tle:define`
  (new slug, new folder) and a new loop. `/tle:define` never edits an existing
  goal file.
- Non-web-app verification profiles beyond commands + browser scenarios.
- Any tce/tmt integration beyond the optional profile read.

## Open Questions

None — the design was resolved in the referenced discussion.

## Questions for Research/Planning

- [ ] Exact command frontmatter (`disable-model-invocation`, any
      `allowed-tools`) per the TP-0017 classification, and how the runner's
      internal loop interacts with per-iteration skill re-injection under
      compaction.
- [ ] What `/tle:run` can actually observe to check "a goal condition is set"
      (is an active `/goal` detectable at all, or does the check reduce to
      instructing the user?).
- [ ] Agent tool lists: what the verifier needs (Bash for commands,
      chrome-devtools-mcp tools) and how agent frontmatter references MCP tools
      without hardcoding a server the project may not have.
- [ ] Whether the goal.md skeleton and per-iteration file formats ship as
      reference files (TP-0016 pattern) or inline in the commands.
- [ ] Naming/format details for `NNN-verify.md`, `NNN-plan.md`, `loop-log.md`
      (zero-padding, append format, what the stall-check comparison hashes).

## References

- `thoughts/shared/discussions/2026-08-19-tle-loop-engineering-plugin.md` — the
  settled design (authoritative for this ticket)
- `plugins/tce/agents/plan-compliance-checker.md` — isolation pattern the
  verifier mirrors
- `CLAUDE.md` — core design rule, cross-plugin coordination, TP-0016/TP-0017
  conventions
- https://code.claude.com/docs/en/goal — `/goal` condition semantics
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
  — checklist-as-oracle pattern

## Implementation Plan

`thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md`

## Notes & Updates

### 2026-08-19

Ticket created from the tle design discussion (same day). Key decisions
inherited from it: `/goal` backstop instead of `/loop` as the engine; three
agents instead of four (spec+plan merged, loop breaker dropped as an agent);
file-only handoffs as the core rule; greenfield-first scope. Single ticket for
the whole plugin per user decision — the units are a few markdown prompts, not
separable subsystems. No mid-run goal revision (user decision): loops run to
completion or are killed and replaced; no re-entrant edit mode for
`/tle:define`.
