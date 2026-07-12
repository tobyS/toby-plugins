# Opt-in eco wrapper command to run /tce:implement on Sonnet — Implementation Plan

## Overview

Add `plugins/tce/commands/implement_eco.md`, a thin opt-in wrapper that carries
`model: sonnet` and `disable-model-invocation: true` in its frontmatter and does
nothing but Skill-invoke `tce:implement` with the caller's arguments passed through
verbatim. Document the new command in `plugins/tce/README.md` (a "Cost tuning"
section) and reflect the new delegation edge in `CLAUDE.md`'s TP-0017 invocation-
control classification. `/tce:implement` itself is untouched.

## Current State Analysis

- No command in this repo has ever set a `model:` frontmatter field — it's used only
  on the seven agent files (`haiku` for the two locators, `inherit` elsewhere). The
  wrapper is the first command-level use.
- No pure delegation-only wrapper command exists to copy structurally; the two
  composites (`work.md`, `quickfix.md`) are long, prose-heavy orchestrators, not thin
  wrappers.
- The `disable-model-invocation: true` + "flagged command outbound-delegates to an
  unflagged delegation target" shape is already proven safe: `quickfix.md` is exactly
  this shape (flagged, zero inbound edges, three outbound Skill-tool invocations to
  `tce:ticket`/`tce:plan`/`tce:implement`), and TP-0017's Phase 6 end-to-end test
  confirmed no delegation regression from it.
- Official docs confirm `model:` frontmatter "applies for the rest of the current
  turn... the session model resumes on your next prompt" — the switch-and-revert half
  of the design is documented, not assumed.
- What is **not** documented anywhere (checked: skills docs, sub-agents docs,
  model-config docs, changelog, GitHub issues) is whether that override propagates
  into a command Skill-invoked from inside the wrapper's turn — i.e., whether
  `tce:implement` (no `model:` field of its own) actually executes on Sonnet when
  called from `implement_eco`. This is the ticket's central risk and can only be
  resolved by a live empirical test, not further research.

### Key Discoveries:

- `plugins/tce/commands/quickfix.md:108-109,160-161,184-185` — the exact, reusable
  phrasing convention for Skill-tool delegation: a `**CRITICAL: You MUST run the full
  `/tce:X` process.**` guard line followed by `**Invoke the `tce:X` skill** (via the
  Skill tool) with <args> as args`.
- `plugins/tce/commands/review.md:63,69` — the repo's only precedent for the literal
  `$ARGUMENTS` token; every other command paraphrases "the user's input" in prose. The
  wrapper needs the literal token so pass-through is drift-free by construction (no
  paraphrase to drift from what the caller actually typed).
- `CLAUDE.md:244-249` — the "Delegation targets" bullet already names each command
  that Skill-invokes into `implement` (quickfix, work); it needs a clause for the new
  `implement_eco` edge.
- `CLAUDE.md:250-253` — the "User-only" bullet lists the seven currently-flagged
  commands by name; `implement_eco` belongs in this list (zero inbound delegation
  edges — nothing in the repo will ever Skill-invoke `implement_eco`).
- `plugins/tce/README.md:216-223` — the "Helpers" command table is where a supporting,
  non-core-chain command like this belongs (alongside `/tce:review`, `/tce:commit`).
- `plugins/tce/README.md:27-38` — the Contents TOC needs a new entry if a new
  top-level `## Cost tuning` section is added.

## What We're NOT Doing

- Eco variants of `/tce:work` or `/tce:quickfix` (ticket: explicit follow-up once this
  mechanism is proven).
- Hardcoding `model:` into `implement.md` (ticket: rejected, removes user choice).
- Any subagent/per-phase orchestration approach to implementation (ticket: rejected —
  token multiplier, lossy handoff, no `AskUserQuestion` in subagents). This only
  becomes relevant as a fallback if Phase 1's empirical verification fails.
- Making the wrapper's model configurable (haiku, full model IDs, per-project config).
- Changes to `work.md` or `quickfix.md` — `implement_eco` has no inbound delegation
  edges, so the composite-tracking rule (CLAUDE.md) doesn't apply here, and `implement.md`
  itself is not edited, so its "Delegation targets" status is unaffected.

## Implementation Approach

Three phases, in dependency order. Phase 1 builds the wrapper and is the load-bearing
verification gate — the ticket's own instructions require stopping and returning for
re-scoping if the core mechanism doesn't hold, so Phases 2 and 3 (which document a
mechanism that must first be proven to work) are sequenced after a human confirms
Phase 1's manual verification. Phases 2 and 3 are independent of each other and both
docs-only.

## Phase 1: Create and verify the wrapper command

### Overview

Create `plugins/tce/commands/implement_eco.md` with the required frontmatter and a
minimal delegating body, then empirically verify — in a real Claude Code session, not
assumed from docs — that it actually does what its frontmatter claims.

### Changes Required:

#### 1. New wrapper command file

**File**: `plugins/tce/commands/implement_eco.md` (new)
**Changes**: Create the file with frontmatter (`description`, `argument-hint`,
`model: sonnet`, `disable-model-invocation: true`) and a body that states its purpose
in one short paragraph, then delegates using the repo's established phrasing
convention (`quickfix.md:108-109` pattern) with `$ARGUMENTS` (the `review.md:63,69`
pattern) as the pass-through mechanism — no workflow content of its own.

```markdown
---
description: Run /tce:implement on a Sonnet-class model to cut cost/quota use — same workflow, opt-in. Cost-tuned variant of step 4 in the tce workflow.
argument-hint: "[ticket-id | plan path]"
model: sonnet
disable-model-invocation: true
---

# Implement (Eco)

Runs `/tce:implement` on a Sonnet-class model instead of your session's active model
— the "big model plans, Sonnet implements" cost pattern (see the tce README's "Cost
tuning" section for when to reach for this over plain `/tce:implement`). The session
reverts to your model on your next prompt. This command has no workflow content of
its own.

**CRITICAL: You MUST run the full `/tce:implement` process.**

Invoke the `tce:implement` skill (via the Skill tool) with `$ARGUMENTS` as args.
```

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` passes (repo root)
- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `plugins/tce/commands/implement_eco.md` frontmatter contains `model: sonnet` and
      `disable-model-invocation: true` (`grep -n` both lines)
- [ ] `plugins/tce/commands/implement.md` has no diff against its state before this
      phase (confirms the acceptance criterion that plain `/tce:implement` is
      unchanged)

#### Manual Verification:

- [ ] MANUAL: Starting a real Claude Code session on a non-Sonnet model (e.g.
      `/model opus`), invoke `/tce:implement_eco [PREFIX]-XXXX` (a real or scratch
      ticket) in a project with this plugin installed, and confirm the wrapper's own
      turn **and** the delegated `tce:implement` execution inside it actually run on
      a Sonnet-class model (e.g. ask what model is currently active partway through
      the turn, or check Claude Code's own model indicator/status line).
- [ ] MANUAL: Confirm the session model reverts to the original (e.g. `opus`) on the
      next prompt after the eco-implement turn completes.
- [ ] MANUAL: Confirm the ticket ID / plan path passed to `/tce:implement_eco` arrives
      intact at the delegated `tce:implement` execution (it operates on the correct
      ticket/plan, not empty or malformed arguments).

**Decision gate — do not start Phase 2 until a human has performed and confirmed all
three Manual Verification items above.** If the second item fails — the `model:`
override does not propagate into the Skill-invoked `tce:implement` — this ticket's
core design assumption has failed. Stop, report this back for re-scoping rather than
implementing Phases 2/3 on top of a broken mechanism; the ticket's own fallback
candidates are hardcoding `model:` on `implement.md` or a per-phase implementer agent
with documented model semantics.

---

## Phase 2: Update the invocation-control classification (CLAUDE.md)

### Overview

Reflect the new command and its one outbound delegation edge in the TP-0017
classification CLAUDE.md maintains, per that section's own re-derivation rule.

### Changes Required:

#### 1. Delegation-targets bullet — note the new inbound edge into `implement`

**File**: `CLAUDE.md:244-249`
**Changes**: Add a clause noting `implement_eco` Skill-invokes `tce:implement`,
alongside the existing quickfix/work mentions.

```markdown
- **Delegation targets — must NEVER carry the flag**: `ticket`, `research`, `plan`,
  `implement`, `commit`. `/tce:quickfix` Skill-invokes `tce:ticket`/`tce:plan`/
  `tce:implement` explicitly; `/tce:implement_eco` Skill-invokes `tce:implement`
  explicitly; every workflow command prose-invokes `/tce:commit`
  ("use the `/tce:commit` command" resolves to a Skill-tool call at runtime); and
  `/tce:work` defers to the full specs of `research`/`plan`/`implement`, which the
  model loads via the Skill tool.
```

#### 2. User-only bullet — add `implement_eco`

**File**: `CLAUDE.md:250-253`
**Changes**: Add `implement_eco` to the named list (zero inbound delegation edges —
nothing in the repo Skill-invokes it).

```markdown
- **User-only — carry the flag deliberately** (side-effectful or top-level, no
  inbound delegation): `init`, `refresh`, `work`, `quickfix`, `review`, `discuss`,
  `design_explore`, `implement_eco`. Benefits: the model can't fire them
  spontaneously, and their descriptions leave the always-on skill listing in every
  consuming project.
```

### Success Criteria:

#### Automated Verification:

- [ ] `grep -n "implement_eco" CLAUDE.md` shows both edits present

#### Manual Verification:

- [ ] MANUAL: Read the updated section in context and confirm it still reads as one
      coherent passage (no dangling clause, list stays parseable).

---

## Phase 3: Document the cost-tuning pattern (README)

### Overview

Add the wrapper to the command catalog and a dedicated "Cost tuning" section
explaining the pattern, why tce's plan/research documents make Sonnet execution
safe, and when to use `implement_eco` vs. plain `/tce:implement`.

### Changes Required:

#### 1. Command catalog — add `implement_eco` to the Helpers table

**File**: `plugins/tce/README.md:216-223`
**Changes**: Add one row to the existing "Helpers" table.

```markdown
| Command               | Purpose                                                             |
| --------------------- | ------------------------------------------------------------------ |
| `/tce:discuss`        | Technical discussion / sparring partner                            |
| `/tce:review`         | Review an implementation (ticket-based or custom scope)            |
| `/tce:commit`         | Commit with pre-commit checks and the profile's commit convention  |
| `/tce:design_explore` | _(Optional)_ Explore and select a visual design for non-trivial UX |
| `/tce:implement_eco`  | _(Optional)_ Run `/tce:implement` on a Sonnet-class model to cut cost/quota use |
```

#### 2. New "Cost tuning" section

**File**: `plugins/tce/README.md` (new `## Cost tuning` section, inserted after the
"Commands" section ends at line 237 and before `## Agents` at line 239)
**Changes**: Explain the "big model plans, Sonnet implements" pattern (citing the
`opusplan` alias and Anthropic's cost guidance, per the ticket's Problem Statement),
why tce's plan documents specifically make Sonnet-class execution safe (self-contained
context — "a plan written for a gifted engineer with bad judgment"), and when to
reach for `/tce:implement_eco` vs. plain `/tce:implement`.

```markdown
## Cost tuning

Execution — `/tce:implement` — consumes most of a workflow session's tokens, so it's
where model choice matters most for cost. Anthropic's own guidance ("Sonnet handles
most coding tasks well... reserve Opus for complex architectural decisions") and the
built-in `opusplan` alias both endorse "big model plans, Sonnet implements" as a
rational default: small SWE-bench deltas at roughly 5x the price.

tce is unusually well-suited to this pattern because the research and plan documents
that precede implementation are exactly the detailed, self-contained context that
makes Sonnet-class execution safe — a plan written for a gifted engineer with bad
judgment. By the time `/tce:implement` runs, the thinking is already done; execution
is closer to translating a formed plan than improvising one.

Run `/tce:implement_eco [PREFIX]-XXXX` instead of `/tce:implement` to execute on a
Sonnet-class model — same workflow, same plan, same verification. It's opt-in: your
session's chosen model reverts on your next prompt, and plain `/tce:implement` stays
model-agnostic (`inherit` behavior) so doing nothing keeps you on whatever model you
picked.

**Use `/tce:implement_eco` when**: you're cost-conscious on API billing, or you're on
a subscription plan and want implementation runs to draw on Sonnet quota so your
Opus/Fable limits last longer across the week.

**Use plain `/tce:implement` when**: you want every phase on your chosen model with
no exceptions, or the plan itself is thin/unusual enough that you want your primary
model's judgment during execution, not just during planning.
```

#### 3. Contents TOC — add the new section

**File**: `plugins/tce/README.md:27-38`
**Changes**: Insert `- [Cost tuning](#cost-tuning)` after the `- [Commands](#commands)`
entry.

```markdown
- [Commands](#commands)
- [Cost tuning](#cost-tuning)
- [Agents](#agents)
```

### Success Criteria:

#### Automated Verification:

- [ ] `grep -n "implement_eco" plugins/tce/README.md` shows the table row and section
      references
- [ ] `grep -n "^## Cost tuning$" plugins/tce/README.md` matches

#### Manual Verification:

- [ ] MANUAL: Read the rendered "Cost tuning" section top to bottom and confirm it
      reads clearly to someone who hasn't seen the ticket/research/plan — the
      why-it's-safe reasoning and the when-to-use-which guidance should stand alone.

---

## Testing Strategy

### Manual Testing Steps:

1. Phase 1's three Manual Verification items (the empirical model-switching,
   reversion, and argument pass-through tests) are the only real "tests" this ticket
   has — there is no automated test suite for Claude Code's own model-resolution
   behavior. Perform them in a scratch or real project with the plugin installed, as
   described in Phase 1.
2. After Phase 3, skim the rendered README (e.g. via GitHub's preview or a local
   markdown viewer) to confirm the new TOC entry links to the right section and the
   Helpers table still renders as a clean table.

## Performance Considerations

None — this is a documentation/command-authoring change with no runtime code path
beyond Claude Code's own (undocumented, externally-owned) model-resolution mechanism.

## Migration Notes

None — purely additive (one new command file, two docs updates); no existing command,
config, or data format changes.

## References

- Original ticket: `thoughts/shared/tickets/TP-0024-eco-implement-wrapper-sonnet.md`
- Related research: `thoughts/shared/research/2026-07-12-TP-0024-eco-implement-wrapper-sonnet.md`
- Precedent for the flagged/outbound-delegation shape:
  `plugins/tce/commands/quickfix.md:1-5,108-109,160-161,184-185`
- Precedent for `$ARGUMENTS` pass-through: `plugins/tce/commands/review.md:63,69`
- TP-0017 classification this extends: `CLAUDE.md:238-260`,
  `thoughts/shared/plans/2026-07-04-TP-0017-adopt-frontmatter-machinery.md:441-449`
  and its `.status.md:169-181` (Phase 6 end-to-end verification precedent)
