# TP-0029: Pin explicit models on tle's loop agents to cut token burn

**Status:** In Progress
**Estimated Complexity:** Small
**Created:** 2026-08-28
**Updated:** 2026-08-28

## Problem Statement

All four tle agents declare `model: inherit`, so an unattended `/tle:run` loop
executes every verifier, spec-planner and implementer dispatch on whatever the
user's session model is — Opus for most users. The loop is tle's whole cost
centre: the verifier re-runs every checklist item's verification method on every
iteration, and the implementer reads source, edits, runs tests and retries. Over
a 20-iteration budget that is a large, entirely unsupervised spend.

The user cannot economize it today without collateral damage. Because a subagent's
`inherit` resolves against the *active* model at dispatch time, the only lever is
downgrading the whole session — which also downgrades the spec-planner (the loop's
one real decision) and, if done before `/tle:define`, the goal authoring and the
goal critic, where being wrong is most expensive because the goal file is immutable.

TP-0017 already established that agents may carry deliberate pins (tce's locators
run on haiku). TP-0024 established the opposite rule for user-invoked commands:
hardcoding `model:` into `implement.md` was rejected because it "silently removes
model choice" from consumers. tle's agents fall on the first side of that line and
its commands on the second, but nothing in the plugin reflects either yet.

## Desired Outcome

The three agents that do the loop's repeated work carry explicit model pins, so a
tle loop's cost is a property of the plugin rather than of the user's session
model, while every artifact where the user's own model choice matters stays open:

| Artifact | Model | Rationale |
|---|---|---|
| `loop-implementer` | `sonnet` | Largest consumer. The plan file is specified to be sufficient for an implementer with no other context, scope is one small step, a green test run gates the commit, and the verifier re-checks independently — TP-0024's safety argument, with more guardrails. |
| `loop-verifier` | `sonnet` | Highest repeat count (every item, every iteration). Judgment is designed out: explicit `Verify by`, evidence required per `pass`, `cannot-verify` when a method can't run, "when in doubt, fail". |
| `loop-spec-planner` | `opus` | Smallest footprint, highest leverage — the loop's only genuine decision (which failing item, how small a slice, and at rung 2 a different strategy). Pinning also protects it when the loop runs from a Sonnet session. |
| `loop-goal-critic` | stays `inherit` | One dispatch per loop, in an interactive session whose model the user picked; the saving is nil and its miss is expensive. |
| `/tle:define` | no `model:` | Interactive, once per loop, and the highest-leverage tokens in the plugin — it writes the immutable oracle. |
| `/tle:run` | no `model:` | User-invoked (TP-0024's principle), and its own context is tiny by design (invariant 2: paths and one-line statuses only). |

Pinning the three agents explicitly has a second effect worth having: it makes them
immune to a future `model:` on `/tle:run`, which would otherwise cascade into every
agent still saying `inherit`.

## User Stories / Use Cases

- As someone running a long unattended tle loop, I want its cost to be set by the
  plugin's own division of labour so that I don't pay Opus rates for command
  execution and exit-code reading across twenty iterations.
- As a subscription user, I want the loop's bulk work to draw on Sonnet quota so
  that a single overnight loop doesn't consume the week's Opus limit.
- As someone defining a goal, I want `/tle:define` and its critic to keep running
  on the model I chose so that the one immutable artifact in the workflow is
  authored and reviewed at full strength.
- As a plugin maintainer, I want the pins recorded as a deliberate policy so that a
  later change to `/tle:run`'s frontmatter doesn't silently downgrade the loop.

## Acceptance Criteria

- [ ] `plugins/tle/agents/loop-implementer.md` and `loop-verifier.md` declare
      `model: sonnet`; `loop-spec-planner.md` declares `model: opus`;
      `loop-goal-critic.md` still declares `model: inherit`.
- [ ] Model **aliases** are used, not pinned model IDs, so the pins track the
      current release of each tier (TP-0024's precedent).
- [ ] Neither `plugins/tle/commands/run.md` nor `define.md` gains a `model:` field.
- [ ] `claude plugin validate ./plugins/tle` passes.
- [ ] Empirically confirmed in a scratch greenfield project (not assumed from
      docs, and not in this repo — tle is not dogfooded here): across one
      `/tle:run` iteration, each of the three agents runs on its pinned model
      regardless of the session model, and `loop-goal-critic` follows the session
      model during `/tle:define`.
- [ ] The same scratch loop still advances: at least two consecutive iterations
      each produce a verify report, a plan, and a green commit, with no stall
      escalation caused by the pins.
- [ ] `plugins/tle/README.md` documents the model division of labour and why the
      commands stay open, in a form a consumer can act on.
- [ ] The repo `CLAUDE.md` records the policy in the tle section: agents pinned /
      commands open, the pins are deliberate and must not be "tidied" back to
      `inherit`, and adding a `model:` to `/tle:run` would cascade into any agent
      still on `inherit`.

## Out of Scope

- **Pinning or eco-wrapping `/tle:run`.** The `/goal` condition string names
  `/tle:run` by hand, so an eco variant means changing the condition template in
  `references/goal-file-template.md` and the flow in the README under the TP-0025
  three-file sync rule — a separate ticket, not a frontmatter edit.
- Pinning `/tle:define` or `loop-goal-critic`.
- `haiku` anywhere in tle: the plugin has no purely mechanical agent (tce's haiku
  agents are grep/glob locators), and the runner — the only candidate — is exactly
  where refusing to do work matters most.
- Making the pins configurable per project or per user (no per-skill override
  mechanism exists for plugin consumers; the aliases are enough for now).
- TP-0024's pending tce README cost-tuning section. It is still open and shares
  this ticket's framing, but it is tce's work, not tle's.
- Revisiting tce's own agent model assignments.

## Open Questions

None. The one judgment call — the verifier on `sonnet` when it is the component
nothing downstream checks — was adjudicated during ticket authoring (see Notes).

## Questions for Research/Planning

- [ ] How to *observe* which model a subagent actually ran on, so the empirical
      criterion is verifiable rather than asserted (subagent transcript, UI, or
      telemetry?).
- [ ] Whether an invalid or unrecognized `model:` alias in a plugin-shipped agent
      fails loudly or silently falls back — this decides whether the pins need a
      validation guard beyond `claude plugin validate`.
- [ ] Whether context-window alias suffixes (`sonnet[1m]`) are legal in agent
      frontmatter, and whether the implementer or verifier would benefit from one
      given they hold test output and source.
- [ ] Where the README note belongs (Requirements table, a new cost section, or
      alongside "The loop"), and whether to share wording with TP-0024's pending
      tce cost-tuning section.
- [ ] Which existing CLAUDE.md tle section should carry the policy, or whether it
      warrants its own — the file already has TP-0017 (invocation control),
      TP-0025 (engine model) and TP-0025 (verdict vector) sections that this
      partly touches.
- [ ] What the cheapest credible scratch-project setup is for the empirical check
      (it must boot, run tests, and reach a green commit twice).

## References

- TP-0017 — agent `model:` precedent (tce locators on `haiku`) and the
  invocation-control classification.
- TP-0024 — the eco wrapper; rejected hardcoding `model:` into a user-invoked
  command because it removes consumer model choice. Still In Progress; its tce
  README cost-tuning section does not exist yet.
- TP-0025 — tle's engine model and the `/goal` condition string, which is why an
  eco runner is out of scope here.
- Claude Code docs: skills frontmatter `model` semantics
  (https://code.claude.com/docs/en/skills), sub-agents model resolution
  (https://code.claude.com/docs/en/sub-agents), model aliases
  (https://code.claude.com/docs/en/model-config).
- Session analysis (2026-08-28) of tle's per-iteration spend distribution:
  implementer > verifier > planner > runner.

## Implementation Plan

## Notes & Updates

### 2026-08-28

- Two platform facts drive the design, both confirmed against the docs: a
  command's `model:` is turn-scoped (the session reverts on the next prompt), and
  an agent's `inherit` resolves against the active model *at dispatch time* — so a
  pin on `/tle:run` would cascade into every `inherit` agent. Whether a command's
  pin re-applies on each `/goal`-driven turn is **not** documented; that
  uncertainty is one reason the eco-runner idea is deferred rather than attempted.
- The organizing principle: agents are internal workers with no user choice at
  stake (pin them); user-invoked commands are the user's model choice (leave them
  open). tle strengthens the first half because the loop runs unattended — nobody
  is there to switch models mid-run.
- **Verifier on `sonnet` is the deliberate risk.** It is the one component nothing
  downstream checks, and a false `pass` ends the loop on an unfinished goal. It was
  accepted because the verifier's soft paths are all routed to `fail` or
  `cannot-verify` by design. The agreed escalation signals, to be captured for the
  user rather than automated: a `pass` whose evidence is not a command with an exit
  code or observed scenario steps, and a test weakened since the base commit that
  the integrity diff missed. Either one means raising the verifier to `opus`.
- Complexity is Small: four frontmatter lines plus documentation. The empirical
  verification, not the edit, is the bulk of the work.
