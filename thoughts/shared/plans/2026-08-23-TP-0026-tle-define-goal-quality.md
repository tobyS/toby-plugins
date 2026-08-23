# TP-0026 — /tle:define Goal Quality Implementation Plan

## Overview

Turn `/tle:define` from an accepting scribe into a demanding editor. The first
real tle run (TP-0025) showed the architecture holds but the goal file was the
weak point: the command accepted an **infeasible** item (reproducible outputs
from an LLM) instead of challenging it, and generally took the user's first
decomposition at face value. Because the goal file is the loop's only oracle —
immutable once the loop starts — a gap or an impossible item in it is invisible
to the loop forever, and the platform's `/goal` evaluator has an `Impossible`
verdict that kills a loop outright.

This plan adds four scepticism mechanisms in-command (a goal-level challenge, an
omission-category sweep, a goal-anchored set-level completeness check, and a
per-item feasibility + verification-validity + wording pass), each closed by a
hard "Do not proceed until …" gate, plus a **fresh-context critic agent**
(`loop-goal-critic`) that reviews the assembled draft immediately before it is
written. Ops facts stay conversationally confirmed (user decision — no
execution). The goal-file machine contract (item-ID scheme, condition string,
immutability, no pass-state field) is untouched.

## Current State Analysis

From the research (`thoughts/shared/research/2026-08-23-TP-0026-tle-define-goal-quality.md`):

- `/tle:define` (`plugins/tle/commands/define.md`, 175 lines, 11,864 bytes) has
  nine linear steps with **zero blocking gates** — every step's exit is
  "present and iterate until the user is satisfied".
- Its **only omission hunt** is one sentence at the end of Step 3
  (`define.md:115`).
- It has **no feasibility check** anywhere: nothing stops an item that no agent
  could ever make true from entering the file.
- It has **no completeness pass over its own draft** — no second look, no
  category sweep, no critic.
- The repo already contains every needed pattern: hard gates
  (`plugins/tce/commands/ticket.md:171,180,199`), an omission-category sweep
  (`plugins/tce/commands/review.md:167-225`), a sufficiency test with a
  negative list (`plugins/tce/commands/research.md:114-133`), and a
  fresh-context criteria checker
  (`plugins/tce/agents/plan-compliance-checker.md`).
- tle's agent skeleton (used by all three existing agents): `disallowedTools`
  frontmatter, a `## What you receive` section with a negative clause, a
  conservative tie-break, and a three-part `## CRITICAL:` / `## What NOT to
  Do` / `## REMEMBER:` envelope.

## Desired End State

`/tle:define` reliably refuses to produce a goal file it can tell is
incomplete or infeasible. Concretely, after this plan:

- The goal itself is challenged before decomposition: achievable by an
  autonomous agent, well-enough defined to decompose, and loop-sized.
- Every checklist item is challenged for feasibility and for whether its
  `Verify by` actually proves its `Done when`, and its wording is swept for
  vague/subjective terms.
- The checklist as a set is checked against the goal statement ("if every item
  passes, is the goal genuinely achieved?") and against a fixed omission
  taxonomy.
- A fresh-context critic agent reviews the assembled draft before writing;
  its findings are adjudicated with the user, never auto-applied; an
  unresolved blocking finding stops the write.
- All of this verified by: the three gates greppable in `define.md`, the new
  agent file validating, and a scratch-project walkthrough in which a
  deliberately infeasible item is challenged and renegotiated.

### Key Discoveries:

- `define.md:115` — the single existing omission question; replaced by the
  sweep + set-level check in Phase 1.
- `define.md:117-124` (Step 4) — the oracle hierarchy is the natural home of
  the per-item feasibility/validity/wording pass.
- `define.md:168-175` — `## Important Rules` already carries hard "Never …"
  rules including "Never accept a subjectively-judged item"; the refuse-to-
  write rule extends this list.
- `plugins/tle/agents/loop-verifier.md` — the skeleton and register for the
  new critic agent (`disallowedTools`, verdict conservatism, envelope).
- Subagents can **never** call `AskUserQuestion` (platform fact, TP-0025
  research) — the critic returns findings; `define.md` adjudicates them.
- Compaction keeps only the first ~5,000 tokens of an invoked skill;
  `define.md` is ~3,000 tokens, leaving roughly 8 KB of growth headroom, and
  truncation keeps the **start** of the file. Additions must stay tight; total
  file size should stay under ~18 KB.
- The `**Other:**` ops-fact bullet has no consumer; the four consumed facts
  are boot command, test command, base commit, test file locations. Ops-fact
  handling is otherwise unchanged by this plan (user declined execution).

## What We're NOT Doing

- **No ops-fact execution.** Boot/test commands stay conversationally
  confirmed (explicit user decision during planning). AC 3 is addressed by the
  existing Step 5 mechanics plus the critic's ops-fact plausibility lens.
- **No changes to `/tle:run`, the three loop agents, or the engine model** —
  ticket Out of Scope. The critic is a *define-time* agent, not a loop agent.
- **No goal-file contract changes**: the skeleton, `item-NN` ID scheme,
  condition-string template, immutability rule, and absence of a pass-state
  field are untouched (AC 5). Template changes are additive authoring
  guidance only, so the verdict-vector and condition-string sync rules do not
  fire beyond the doc updates in Phase 3 (AC 6).
- **No mid-run goal revision** — immutability stands.
- **No edit to the AskUserQuestion guidelines block** (byte-identical across
  ten files; verified untouched in Phase 1 criteria).
- **No release/tag/version bump** — the user triggers releases separately.
- **Not fixing** the `**Other:**` dead bullet, the `.claude/tce/profile.md`
  code-map drift (run `/tce:refresh` separately), or the three unverified tle
  failure modes from TP-0025.

## Implementation Approach

All changes are prompt-file (markdown) changes in the tle plugin plus doc
sync. House style applies: surgical edits preserving each command's existing
structure and altitude; the new agent follows tle's existing agent skeleton;
dispatch uses the house idiom (bold agent name in prose, foreground, payload
enumerated). Phase 1 is self-contained and shippable alone (in-command
scepticism); Phase 2 adds the independent critic; Phase 3 syncs docs and
validates. Wording below gives the substance and register of each addition —
the implementer writes final prose matching the file's existing voice, keeping
Phase 1 + 2 additions to `define.md` within ~5 KB combined.

## Phase 1: In-command scepticism in `define.md` + per-item standards in the template

### Overview

Add the goal-level challenge, the omission sweep + set-level check, the
per-item feasibility/validity/wording pass, three blocking gates, and the
refuse-to-write rule. Mirror the per-item standards into the template's
authoring guidance so they survive for later readers of the artifact contract.

### Changes Required:

#### 1. Goal-level challenge in Step 1

**File**: `plugins/tle/commands/define.md`
**Changes**: In "Step 1: Converge on the goal" (`:87-96`), after the
restate-and-boundary paragraph (`:89`) and **before** the slug paragraph,
insert a challenge block + gate:

- Challenge the goal on three axes, pushing back in discussion rather than
  accepting the first statement:
  - **Achievable** — can an autonomous agent with code, tests, and a browser
    actually reach this outcome? Name the canonical infeasibility classes:
    demanding determinism from a nondeterministic system (e.g. byte-identical
    LLM outputs), outcomes depending on external-world events outside the
    repo, unbounded claims ("no bugs", "handles any input"). Note plainly
    that `/goal`'s evaluator has an `Impossible` verdict that clears the goal
    and ends the loop — one impossible expectation can kill the run outright.
  - **Defined** — is the goal concrete enough that "done" can be decomposed
    into observable outcomes? If not, say so plainly ("this is not well
    defined enough yet") and work it out together.
  - **Loop-sized** — is this achievable within one loop's budget? If it is
    too big, say so ("this is too big for one loop") and propose narrowing
    the boundary or splitting into successive loops (later loops get their
    own `/tle:define`).
- Close with: **Do not proceed until the goal is achievable, well-defined,
  and loop-sized — renegotiated with the user where it is not.**

#### 2. Omission sweep + set-level check in Step 3

**File**: `plugins/tle/commands/define.md`
**Changes**: In "Step 3: Decompose into granular checklist items"
(`:106-115`), replace the final sentence ("Explicitly ask whether anything
they consider part of 'done' is missing — a goal with a hole in it is a loop
that stops early.", `:115`) with:

- **Omission-category sweep** — after drafting the checklist, sweep these
  categories and mark each *covered*, *missing*, or *agreed out of scope*:
  1. Core user flows — every distinct flow the goal statement implies
  2. Data & persistence — state survives reload/restart where the goal
     implies it
  3. Error & edge handling — invalid input, empty states, failure paths a
     user would actually hit
  4. Boot & build health — the app starts cleanly; build/typecheck passes
  5. Test-suite health — the whole suite runs green, not only per-item tests
  Present the sweep result; every *missing* category becomes proposed items
  or an explicit boundary exclusion the user agrees to.
- **Goal-anchored completeness check** — ask, and answer honestly: *if every
  item on this checklist passed, would the Step 1 goal genuinely be
  achieved?* Judge the set against the goal statement, not items against
  each other. Any daylight between the two is a missing item — propose it.
  (Keep the existing rationale register: a goal with a hole in it is a loop
  that converges on an unfinished job.)
- Close with: **Do not proceed until the user confirms the checklist covers
  everything they mean by "done" — each gap either an item or an agreed
  boundary exclusion.**

#### 3. Per-item feasibility, verification validity, and wording in Step 4

**File**: `plugins/tle/commands/define.md`
**Changes**: In "Step 4: Push every item down the oracle hierarchy"
(`:117-124`), after the two-rung hierarchy and before/around the existing
browser-scenario reporting sentence (`:124`), add a per-item challenge:

- **Feasibility** — for each item: could a competent agent ever make this
  true? Reject or renegotiate items in the infeasibility classes from Step 1
  (nondeterminism-as-determinism, external-world dependencies, unbounded
  claims). Offer the same escape hatch the subjective-item rule already
  uses: leave it out of the loop and verify it by hand afterwards.
- **Verification validity** — for each item, test the pairing: imagine the
  `Done when` is false — would this `Verify by`, run exactly as stated,
  fail? If a passing `Verify by` is compatible with an unmet `Done when`, it
  is a proxy, not a proof: fix the `Verify by` or split the item.
- **Wording sweep** — scan each `Done when` for vague or subjective terms
  ("fast", "properly", "reasonable", "acceptable", "user-friendly",
  "robust", "clean", "as needed", "appropriate", comparatives with no
  baseline). Each occurrence is replaced with an observable formulation or
  the item is renegotiated. (This operationalises the existing "Never accept
  a subjectively-judged item" rule with a concrete lexical pass.)
- Close with: **Do not proceed until every item is feasible and its
  `Verify by` can actually prove its `Done when`.**

#### 4. Refuse-to-write rule in `## Important Rules`

**File**: `plugins/tle/commands/define.md`
**Changes**: Add one bullet to `## Important Rules` (`:168-175`), after the
"Never accept a subjectively-judged item" bullet:

- **Never write a goal file you can tell is incomplete or infeasible.** When
  a gap or an impossible item survives discussion unresolved, surface it and
  stop — an unwritten goal costs a conversation; a bad goal costs a whole
  loop. (This is AC 4's enforcement point; the Phase 2 critic's blocking
  findings hook into the same rule.)

#### 5. Matching authoring guidance in the template

**File**: `plugins/tle/references/goal-file-template.md`
**Changes**: Additive only — the skeleton (lines 21-71) is untouched. In the
"# Authoring guidance" half, add two sections after "## Granularity":

- **`## Feasibility`** — every item must be achievable by an autonomous
  agent; name the three infeasibility classes; note that `/goal`'s
  `Impossible` verdict means one infeasible item can end the loop, so an
  infeasible expectation is excluded from the loop and verified by hand
  afterwards, never written into the checklist.
- **`## Verify by must prove Done when`** — the falsity test (a `Verify by`
  that can pass while its `Done when` is unmet is a proxy); fix the check or
  split the item.

Update the template's header comment (lines 1-19) contents list to mention
the new guidance sections.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes (repo root)
- [x] `claude plugin validate ./plugins/tle` passes
- [x] `grep -c "Do not proceed until" plugins/tle/commands/define.md` returns 3
- [x] The AskUserQuestion guidelines block in `define.md` is byte-identical to
      the copy in `plugins/tce/commands/plan.md` (extract heading through last
      bullet, diff)
- [x] `git diff` on `plugins/tle/references/goal-file-template.md` touches only
      the header comment and the authoring-guidance half — the skeleton block
      (`# Loop Goal:` through the closing fence) is unchanged
- [x] `plugins/tle/commands/define.md` is under 18,000 bytes

#### Manual Verification:

- [ ] Read-through: the three gates sit at their steps' exits, and the new
      text matches the command's existing register and altitude
- [ ] The infeasibility classes appear in both Step 1 and Step 4 without
      contradicting each other (Step 4 may reference Step 1's list)

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `9f37890` (HEAD before any implementation commit)
- **Commit**: `pending`
- **Did**: `define.md` — goal-level challenge + gate in Step 1, omission sweep +
  goal-anchored check + gate in Step 3 (replacing the one-sentence hunt), per-item
  feasibility/validity/wording pass + gate in Step 4, refuse-to-write rule in
  `## Important Rules`. `goal-file-template.md` — additive `## Feasibility` and
  `` ## `Verify by` must prove `Done when` `` guidance + header contents list.
- **Issues**: none
- **Verification**: ✅ both `claude plugin validate` runs, ✅ 3 gates, ✅ AskUserQuestion
  block byte-identical to `plan.md`'s (1080 B), ✅ template skeleton untouched,
  ✅ define.md 16,000 B (< 18,000)

---

## Phase 2: The fresh-context critic agent

### Overview

Add `loop-goal-critic` — a read-only agent that critiques the assembled draft
goal from a fresh context — and a new Step 8 in `define.md` that dispatches it
and adjudicates its findings with the user before the file is written.

### Changes Required:

#### 1. The agent

**File**: `plugins/tle/agents/loop-goal-critic.md` (new)
**Changes**: Follow tle's agent skeleton (model: `plugins/tle/agents/loop-verifier.md`):

- **Frontmatter**: `name: loop-goal-critic`; a description saying it
  critiques a draft tle goal from a fresh context before `/tle:define`
  writes it, and returns categorized findings;
  `disallowedTools: Task, AskUserQuestion, Edit, Write, NotebookEdit, Bash`
  (read-only by denial: Read/Grep/Glob/LS remain); `model: inherit`.
- **`## What you receive`**: the draft goal inline in the dispatch prompt —
  goal statement + boundary, the checklist (item IDs, `Done when`,
  `Verify by`), ops facts, budgets. Negative clause: you do NOT receive —
  and must not seek out — the discussion that produced the draft, any
  `thoughts/` document, or the user's rationale; judging the draft *without*
  the reasoning that produced it is the entire point. You MAY read the
  project's files to ground repo claims.
- **`## What you check`** — six lenses, mirroring Phase 1's standards as an
  independent second pass:
  1. **Feasibility** — items no agent could ever make true (the three
     infeasibility classes)
  2. **Verification validity** — a `Verify by` that can pass while its
     `Done when` is unmet
  3. **Wording** — vague/subjective terms in `Done when`; selectors, DOM
     ids, CSS classes, or component names in browser scenarios
  4. **Set-level completeness** — if every item passed, would the stated
     goal be achieved? Gaps the checklist never mentions
  5. **Ops-fact plausibility** — facts contradicted by the repo (a test-file
     glob matching nothing, a boot command absent from the manifest, a
     missing base commit); grounded in files read, never executed
  6. **Budget sanity** — max iterations wildly out of scale with the item
     count (the ~2–3 per item heuristic)
- **`## Findings format`** (the return): either exactly `No findings.` or a
  list, one finding per line:
  `- [blocking|advisory] <lens>: <one- or two-sentence finding>` — naming
  the `item-NN` it concerns (or `set-level` / `ops` / `budget`), with a
  `file:line` reference for every repo claim. *Blocking* = would let the
  loop converge on an unfinished or impossible goal; *advisory* = would
  improve it. Conservative rule: when in doubt whether a gap is real,
  report it as **advisory** rather than staying silent — the user
  adjudicates; use *blocking* sparingly. (This agent deliberately returns a
  findings list, not the loop agents' one-line status — that rule protects
  the runner's context, and this agent reports to the interactive
  `/tle:define` session.)
- **Envelope** (three parts, re-pointed to the critic role):
  - `## CRITICAL: YOUR ONLY JOB IS TO CRITIQUE THE DRAFT GOAL` — do not
    rewrite items or produce a corrected goal (a finding may carry a
    one-clause suggested direction, no more); do not review the project's
    code quality; do not widen the goal beyond its stated boundary; do not
    demand mechanisms the workflow rejected (e.g. executing ops facts).
  - `## What NOT to Do` — don'ts including: never invent a repo fact (every
    repo claim carries a reference), never assume the user's intent beyond
    the goal statement, never mark a finding blocking to be safe.
  - `## REMEMBER: You are a critic, not the author` — findings go to the
    user for adjudication, never straight into the file; "a critic prompted
    to find problems always finds some" — hence the advisory default.

#### 2. The dispatch step in `define.md`

**File**: `plugins/tle/commands/define.md`
**Changes**:

- **Adjust Step 7** (`:144-146`): change the "these IDs are permanent" line
  to say IDs become permanent **when the goal file is written** — the
  critique step may still add or remove items, after which items are
  renumbered once and the final IDs restated.
- **Insert a new "Step 8: Independent critique"** between Step 7 and the
  current Step 8, with this substance:
  - Assemble the full draft (goal statement + boundary, checklist with IDs,
    ops facts, budgets) and dispatch it with the **loop-goal-critic** agent
    (foreground). Pass it **only** the draft — never the discussion that
    produced it, and never instructions about what to conclude.
  - On return, present the findings to the user and adjudicate **every**
    finding with them (AskUserQuestion where the resolutions are concrete
    options): accept (amend the draft), narrow the boundary (an agreed
    exclusion), or reject the finding (critics sometimes hallucinate — the
    user's judgement wins). Never apply a finding silently.
  - **Blocking findings must be resolved before writing** — fixed, added,
    or explicitly excluded with the user's consent. If a blocking finding
    cannot be resolved, do not write the goal file: per the Important Rules,
    surface what is missing and stop.
  - If adjudication changed the item set, renumber per Step 7 and restate
    the final IDs.
  - `No findings.` → say so in one line and continue.
- **Renumber** current Steps 8-9 to 9-10 and fix internal cross-references:
  the heading anchors, Step 9's "Steps 1–7" → "Steps 1–8", and any other
  step-number mentions (`grep -n "Step [0-9]" plugins/tle/commands/define.md`
  after editing).

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tle` pass
- [ ] `plugins/tle/agents/loop-goal-critic.md` exists; its frontmatter
      `disallowedTools` includes `Task` and `AskUserQuestion`
- [ ] `grep -n "Step 9: Write the goal file" plugins/tle/commands/define.md`
      and `grep -n "Step 10: Hand off"` each match once; no stale "Steps 1–7"
      reference remains
- [ ] `plugins/tle/commands/define.md` is still under 18,000 bytes

#### Manual Verification:

- [ ] Read-through: the critic's envelope matches tle's agent register
      (compare `loop-verifier.md`); the dispatch uses the house idiom
- [ ] Scratch-project walkthrough (see Testing Strategy): the critic is
      dispatched foreground before writing, findings are adjudicated via
      discussion, and a blocking finding demonstrably prevents the write
      until resolved

---

## Phase 3: Docs sync + validation

### Overview

Bring the README and CLAUDE.md in line with the new step and the fourth
agent, then validate everything.

### Changes Required:

#### 1. tle README

**File**: `plugins/tle/README.md`
**Changes**:

- "What you get" bullet 1 (`:22-26`): extend the `/tle:define` description —
  the discussion now challenges the goal and every item (feasibility,
  verifiability, completeness) behind hard gates, and a fresh-context critic
  reviews the draft before it is written.
- "What you get" bullet 3 (`:30-34`): "**Three agents** with hard boundaries"
  → **Four agents**; add a clause for the goal critic: it reviews the draft
  goal from a fresh context before the file is written, so gaps surface
  while a human can still fix them (the loop agents' boundaries are
  unchanged).

#### 2. Repository CLAUDE.md

**File**: `CLAUDE.md`
**Changes**:

- Layout block: `├── agents/*.md  # loop-verifier, loop-spec-planner,
  loop-implementer` → append `loop-goal-critic (define-time)`.
- TP-0017 section, closing paragraph: "tle's three agents" → "tle's four
  agents"; append a clause noting `loop-goal-critic` is dispatched only by
  `/tle:define` (define-time, not part of the loop engine).

#### 3. Validation

- Run `claude plugin validate .` and `claude plugin validate ./plugins/tle`
  from the repo root (per `.claude/tce/profile.md` Commands).

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` passes
- [ ] `claude plugin validate ./plugins/tle` passes
- [ ] `grep -c "loop-goal-critic" CLAUDE.md` ≥ 2 (layout + TP-0017 section)
- [ ] `grep -c "loop-goal-critic" plugins/tle/README.md` ≥ 1

#### Manual Verification:

- [ ] README's "What you get" reads coherently with four agents and the
      hardened define flow
- [ ] No CLAUDE.md sync rule fires unnoticed: `run.md` untouched, the
      condition-string template untouched, the `item-NN` scheme untouched,
      the AskUserQuestion block untouched (spot-check `git diff --stat`)

---

## Testing Strategy

### Unit Tests:

Not applicable — no runtime code. The manifest validation commands above are
the automated layer.

### Integration Tests:

None (markdown plugin monorepo).

### Manual Testing Steps:

End-to-end in a **scratch greenfield app project** (per CLAUDE.md "Testing
changes" — never this repo): `/plugin marketplace add .`,
`/plugin install tle@toby-plugins`, then:

1. Run `/tle:define` with a goal that deliberately contains an infeasible
   expectation (e.g. "the LLM-backed summarizer returns identical output for
   identical input") — confirm Step 1/Step 4 challenges it, explains the
   `Impossible`-verdict consequence, and offers the out-of-loop escape hatch.
2. Give a deliberately thin decomposition — confirm the omission sweep and
   the goal-anchored check surface the gaps and the Step 3 gate holds until
   each is an item or an agreed exclusion.
3. Let the session reach the critique step — confirm **loop-goal-critic** is
   dispatched foreground, findings come back categorized, and each is put to
   the user rather than auto-applied.
4. Leave one blocking finding unresolved and ask the command to write anyway
   — confirm it refuses and surfaces the gap (AC 4).
5. Resolve everything, let it write — confirm the goal file matches the
   unchanged skeleton (IDs, condition string) and the loop starts normally
   with `/goal` + `/tle:run`.

## Performance Considerations

Context, not runtime: `define.md` must stay comfortably inside the ~5,000-token
compaction re-attach cap's useful range. Budget: Phases 1+2 add at most ~5 KB
to the current 11,864 bytes (hard criterion: < 18,000 bytes). Truncation keeps
the start of the file, so nothing engine-critical is added at the very end —
the new gates live inside their steps, and the refuse-to-write rule joins the
existing `## Important Rules` block.

## Migration Notes

None. Existing goal files (from loops already run) remain valid — the
skeleton is unchanged and the new machinery is entirely define-time. No
consuming-project config changes; tle still writes no per-project config.

## References

- Original ticket: `thoughts/shared/tickets/TP-0026-tle-define-goal-quality.md`
- Related research: `thoughts/shared/research/2026-08-23-TP-0026-tle-define-goal-quality.md`
- Command under change: `plugins/tle/commands/define.md`
- Template under change: `plugins/tle/references/goal-file-template.md`
- Agent skeleton model: `plugins/tle/agents/loop-verifier.md`
- Gate pattern: `plugins/tce/commands/ticket.md:171,180,199`
- Omission-sweep pattern: `plugins/tce/commands/review.md:167-225`
- Fresh-context checker pattern: `plugins/tce/agents/plan-compliance-checker.md`
- Predecessor plan (where the gap originated):
  `thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:385-434`
