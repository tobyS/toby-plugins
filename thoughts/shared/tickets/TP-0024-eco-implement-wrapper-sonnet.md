# TP-0024: Opt-in eco wrapper command to run /tce:implement on Sonnet

**Status:** In Progress
**Estimated Complexity:** Small
**Created:** 2026-07-05
**Updated:** 2026-07-05

## Problem Statement

All tce commands inherit the session model. The community-standard cost pattern
"big model plans, Sonnet implements" — endorsed by Anthropic via the `opusplan`
model alias and its cost guidance ("Sonnet handles most coding tasks well…
reserve Opus for complex architectural decisions"), and rational given small
SWE-bench deltas at ~5x price — therefore requires the user to manually switch
models between phases (`/model sonnet` before `/tce:implement`, switch back
after). That is a real ergonomic burden, and hooks cannot change the active
model, so no config-driven automation exists.

tce is unusually well positioned for this pattern: the research and plan
documents are precisely the detailed, self-contained context that makes
Sonnet-class execution safe ("a plan written for a gifted engineer with bad
judgment"). Execution consumes most session tokens, so routing it to Sonnet
captures most of the possible saving; on subscription plans it also stretches
Opus/Fable usage limits.

Hardcoding `model: sonnet` into `implement.md` was considered and rejected:
there is no per-skill override mechanism for plugin consumers, so it would
silently remove model choice — against tce's everything-agnostic design.

## Desired Outcome

A user can run implementation on a Sonnet-class model by invoking a single
opt-in wrapper command instead of `/tce:implement` — no manual model
switching. The wrapper carries `model: sonnet` in its frontmatter and its body
only delegates to the `tce:implement` skill, passing arguments through. The
session returns to the user's model on their next prompt. Plain
`/tce:implement` remains model-agnostic (`inherit` behavior, unchanged). The
tce README documents the cost-tuning pattern and when to use the wrapper.

## User Stories / Use Cases

- As a cost-conscious tce user on API billing, I want implementation to run on
  Sonnet without manual model switching so that I keep most of the workflow's
  quality at a fraction of the execution cost.
- As a subscription (Max) user, I want implement runs to draw on Sonnet quota
  so that my Opus/Fable limits last longer across the week.
- As a quality-first user, I want the default `/tce:implement` untouched so
  that staying on my chosen model requires no action at all.

## Acceptance Criteria

- [ ] A new wrapper command file exists in `plugins/tce/commands/` with
      `model: sonnet` and `disable-model-invocation: true` frontmatter; its
      body only invokes the `tce:implement` skill with the caller's arguments
      (no workflow content of its own — drift-free by construction).
- [ ] Invoking the wrapper verifiably runs the implementation turn on a
      Sonnet-class model, and the session reverts to the user's model on the
      next prompt (empirically confirmed in a scratch project, not assumed
      from docs).
- [ ] `/tce:implement` itself is unchanged (no `model` frontmatter added).
- [ ] `plugins/tce/README.md` gains a cost-tuning section explaining the
      "big model plans, Sonnet implements" pattern, why tce's plan documents
      make it safe, and when to use the wrapper vs. plain `/tce:implement`.
- [ ] The repo `CLAUDE.md` invocation-control classification (TP-0017 section)
      lists the wrapper as user-only, and the new delegation edge
      (wrapper → `tce:implement`) is reflected where the delegation graph is
      described.

## Out of Scope

- Eco variants for the composites `/tce:work` and `/tce:quickfix` — possible
  follow-up once the mechanism is proven and the naming is settled.
- Hardcoding `model:` into `implement.md` (rejected: removes user choice with
  no escape hatch).
- Per-phase or per-code-change subagent orchestration for implementation
  (rejected in the research discussion: token multiplier, lossy handoff, no
  AskUserQuestion in subagents).
- Making the wrapper's model configurable (haiku, full model IDs, per-project
  config) — the `sonnet` alias tracks the latest Sonnet release; that is
  enough for now.

## Open Questions

- **The wrapper's name.** "eco" is a working placeholder — candidates include
  `implement_eco`, `implement_sonnet`, `eco_implement`, or something
  model-name-free. Must be decided before implementation; the name is the
  user-facing opt-in surface, so it should say what it does without implying
  reduced correctness.

## Questions for Research/Planning

- [ ] Empirically verify the documented behavior: a user-invoked command with
      `model: sonnet` frontmatter switches the turn's model and reverts on the
      next prompt.
- [ ] Empirically verify the undocumented, load-bearing behavior: the
      wrapper's model override persists into the Skill-invoked
      `tce:implement` (which has no `model` field) for the rest of the turn.
      If it does NOT hold, the wrapper design fails — return the ticket for
      re-scoping (fallback candidates from the research discussion:
      hardcode on `implement.md`, or a per-phase implementer agent with
      documented agent-model semantics).
- [ ] Verify `$ARGUMENTS` pass-through from the wrapper to the Skill-invoked
      `tce:implement` (ticket ID / plan path must arrive intact).
- [ ] Confirm `disable-model-invocation: true` on the wrapper has no side
      effects on the delegation graph (expected: none — the wrapper has no
      inbound delegation edges).
- [ ] Where the README cost-tuning section fits best, and wording that
      positions the plan documents as what makes Sonnet execution safe.

## References

- Claude Code docs: skills frontmatter `model` semantics
  (https://code.claude.com/docs/en/skills), sub-agents model resolution
  (https://code.claude.com/docs/en/sub-agents), model configuration /
  `opusplan` (https://code.claude.com/docs/en/model-config), cost guidance
  (https://code.claude.com/docs/en/costs).
- Anthropic engineering: multi-agent research system (Opus lead, Sonnet
  workers, ~15x tokens) —
  https://www.anthropic.com/engineering/multi-agent-research-system
- Session research (2026-07-04): hooks cannot change the active model (hooks
  reference); no per-skill model override exists for plugin consumers;
  Skill-invocation model semantics undocumented.
- TP-0017 (frontmatter machinery) — established the invocation-control
  classification and the agent `model:` precedent (locators on haiku).

## Implementation Plan

## Notes & Updates

### 2026-07-05

- Created from a research discussion on "delegate all implementation to
  Sonnet": orchestrator/subagent-per-change was rejected (raises total tokens,
  degrades interaction contract); the opt-in wrapper was chosen over
  hardcoding to preserve user model choice and tce's model-agnostic identity.
- Composites explicitly out of scope; README cost-tuning section explicitly in
  scope (user decisions during ticket authoring).
- The wrapper name is deliberately undecided and captured as an Open Question.
