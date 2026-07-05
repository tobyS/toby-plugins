# TP-0018: Defect-Ticket Exception to the Documentarian Rules — Implementation Plan

## Overview

Carve an explicit, bounded exception into `/tce:research`'s documentarian rules:
when the ticket describes a defect, tracing and documenting the **mechanism of
the faulty behavior** (where actual behavior diverges from intended behavior,
with file:line evidence) is in scope as documentation. The boundary stays firm —
no fix proposals, no code-quality critique, no refactoring suggestions; choosing
the fix remains planning's job. Feature-ticket research behavior is unchanged.

Origin: independent plugin review 2026-07-03, Section 2 finding 6 ("for a bug
ticket, and every `/tce:quickfix`, locating the cause *is* the research
deliverable"; reframe: "tracing the mechanism of the faulty behavior is
documentation, not critique").

## Current State Analysis

- The canonical documentarian rules live in the CRITICAL block at
  `plugins/tce/commands/research.md:59-74`; `research.md:62` is the root-cause
  ban ("DO NOT perform root cause analysis unless the user explicitly asks for
  them"). `research.md:68` instructs the orchestrator to remind every sub-agent
  to describe "without evaluating or improving it". `research.md:70-74` is the
  TP-0004 config-drift carve-out, worded exclusively ("**One sanctioned
  exception:** … This is the only recommendation allowed") — a second exception
  requires reworking that paragraph, not appending to it.
- The composites carry no documentarian text; they inherit by deference
  (`work.md:67,81,91`; `quickfix.md:131`). They restate only operational
  anchors — relevantly, the template write-step lines with the Impact Analysis
  include-condition (`work.md:89`, `quickfix.md:144`).
- `plugins/tce/references/research-document-template.md` has two established
  conditional-section styles; the strong form is "## tce Config Drift (only if
  found)" with a bracketed "[Include this section ONLY if … Omit the section
  entirely when …]" instruction (`:96-102`).
- Agent-side (ticket acceptance criterion 3, resolved by research + checkpoint):
  `codebase-analyzer` is the only agent whose own rules can refuse a
  defect-tracing request — its CRITICAL-block bans are conditional ("unless the
  user explicitly asks", `codebase-analyzer.md:39-41`) but its Step-3 bullets
  (`:90-91`) and "What NOT to Do" list (`:149`, `:153`) restate them
  unconditionally. `codebase-locator` needs no change (it never reads file
  contents, `codebase-locator.md:123,133-134`); `codebase-pattern-finder` needs
  no change (its root-cause ban targets pattern provenance,
  `codebase-pattern-finder.md:40`).

## Desired End State

- `research.md`'s CRITICAL block contains a defect-ticket exception stating:
  (a) the trigger — the ticket describes a defect (existing behavior diverging
  from intended behavior); (b) the permission — tracing/documenting the
  mechanism with file:line evidence is documentation; (c) the boundary — no
  fix proposals, no code-quality critique, no refactoring suggestions; (d) that
  feature tickets are unaffected. Stated once (TP-0016 discipline).
- The research document template has a conditional "## Defect Mechanism (only
  for defect tickets)" section; `work.md` and `quickfix.md` restate the
  include-condition at their write-step lines (same commit as the template
  edit, per the CLAUDE.md composite-tracking rule).
- `codebase-analyzer.md`'s unconditional restatements carry the same "unless
  the user explicitly asks" escape as its CRITICAL block, so a caller's
  explicit defect-tracing prompt is never refused by the agent's own rules.
- Verify: `claude plugin validate` passes for the marketplace and both plugins;
  a coherence read of each edited block; grep confirms the "Defect Mechanism"
  condition appears in the template and both composites.

### Key Discoveries:

- The TP-0004 carve-out pattern is the model: bold-labelled paragraph directly
  under the strict block, self-limiting scope, cross-references to operational
  steps, inner prohibition preserving the parent rule
  (`research.md:70-74`; `thoughts/shared/plans/2026-06-14-TP-0004-profile-drift-refresh.md`).
- TP-0016 (Done) allows each rule exactly one statement site; the exception
  must live once in the CRITICAL block, with only mechanics elsewhere.
- The composites' mirror duty for this change is confined to the template
  write-step lines (`work.md:89`, `quickfix.md:144`) — they inherit the
  CRITICAL block itself by deference.
- Defect classification has no machine signal (tmt envelope has no type field);
  it is a stated judgment from ticket content, keyed exactly as the ticket
  pre-decided: "the ticket describes a defect, not research mood".

## What We're NOT Doing

- No relaxation of the no-recommendations rule for feature tickets.
- No changes to `/tce:review` (allowed to critique by design).
- No command restructuring or length work (TP-0016 is done; TP-0021+ own the rest).
- No changes to `codebase-locator.md`, `codebase-pattern-finder.md`, or the
  three thoughts/web agents (research established their rules don't block
  defect tracing).
- No new step-level detection/surfacing machinery in `research.md` (unlike the
  TP-0004 drift exception, this one needs no detection step — the template's
  include-condition carries the mechanics).
- No solution-hiding logic (review Section 3 item 2 rejected it).
- No ticket-type field in the tmt envelope.
- No plugin version bump/release (releases are separate).

## Implementation Approach

Two phases, each a self-contained commit. Phase 1 changes the command contract
(research.md + template + both composites — the lock-step set that must land in
one commit). Phase 2 aligns `codebase-analyzer.md`'s restatements. Wording
follows the TP-0004 bold-labelled-paragraph pattern; the exclusivity phrasing
of the existing carve-out is reworked into a two-item "sanctioned exceptions"
form so both exceptions coexist coherently.

## Phase 1: The exception in research.md, the template section, and the composite mirrors

### Overview

Add the defect-ticket exception to the CRITICAL block (reworking the TP-0004
paragraph's exclusivity), touch the sub-agent propagation line, add the
conditional template section, and mirror the include-condition into both
composites' write steps. Set the ticket to `In Progress` in the same commit.

### Changes Required:

#### 1. `plugins/tce/commands/research.md` — CRITICAL block

**File**: `plugins/tce/commands/research.md`
**Changes**: Replace the exception paragraph (`:70-74`) with a two-exception
form; extend the sub-agent propagation line (`:68`). The DO-NOT bullets
(`:61-66`) stay untouched.

Replace lines 70-74:

```markdown
**Two sanctioned exceptions:**

1. **Defect tickets — the mechanism is documentation.** When the ticket
   describes a defect (existing behavior that diverges from intended behavior —
   a bug report, regression, or error), tracing and documenting the mechanism
   of the faulty behavior — where actual behavior diverges from intended, with
   file:line evidence — is documentation, not critique, and is in scope
   (recorded in the research document's "Defect Mechanism" section, step 6).
   The boundary stays firm: no fix proposals, no code-quality critique, no
   refactoring suggestions — choosing the fix is the planning phase's job.
   Feature tickets are unaffected.
2. **tce config drift.** While researching you may notice the project's tce
   config (`profile.md` or the backend adapter in `tickets.md`) no longer
   matches reality. You may surface a single, non-blocking advisory to run
   `/tce:refresh` (detection criteria in step 4; surfaced in step 8). This is
   the only recommendation allowed — and it concerns tce's own config, not the
   project's code.
```

Amend line 68 (the propagation line) from:

```markdown
- Your sub-agents are documentarians too — remind them in your prompts that they describe what exists, without evaluating or improving it
```

to:

```markdown
- Your sub-agents are documentarians too — remind them in your prompts that they describe what exists, without evaluating or improving it (under exception 1 you may explicitly ask them to trace where the faulty behavior arises — but never for fixes)
```

#### 2. `plugins/tce/references/research-document-template.md` — conditional section

**File**: `plugins/tce/references/research-document-template.md`
**Changes**: Insert a conditional "Defect Mechanism" section into the main
template between "## Detailed Findings" (`:49-59`) and "## Code References"
(`:61`), using the strong-form include/omit style of the drift section:

```markdown
## Defect Mechanism (only for defect tickets)

[Include this section ONLY when the ticket describes a defect (existing
behavior that diverges from intended behavior). Trace the mechanism with
file:line evidence: the intended behavior (and where it's defined or implied),
the actual behavior, and the point(s) where they diverge, including how the
faulty state propagates to the observed symptom. Document the mechanism only —
no fix proposals and no code-quality critique; choosing the fix is the
planning phase's job. Omit the section entirely for non-defect tickets.]
```

#### 3. `plugins/tce/commands/work.md` — write-step mirror

**File**: `plugins/tce/commands/work.md`
**Changes**: Extend the research-document write bullet (`:89`), whose
parenthetical currently ends "(including the conditional Impact Analysis
section when the ticket reuses/extends shared code)", to:

```markdown
(including the conditional Impact Analysis section when the ticket reuses/extends shared code, and the conditional Defect Mechanism section when the ticket describes a defect)
```

#### 4. `plugins/tce/commands/quickfix.md` — write-step mirror

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: Extend the write step (`:144`), which currently ends "Include the
**Impact Analysis** section (templated in the same file) if the fix
reuses/extends shared code.", by appending:

```markdown
Include the **Defect Mechanism** section when the ticket describes a defect — for a quickfix that is usually the case.
```

#### 5. `thoughts/shared/tickets/TP-0018-research-root-cause-for-defects.md` — status

**File**: `thoughts/shared/tickets/TP-0018-research-root-cause-for-defects.md`
**Changes**: `**Status:** Open` → `**Status:** In Progress`; update the
`**Updated:**` line to 2026-07-05.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes (repo root)
- [x] `claude plugin validate ./plugins/tce` passes
- [x] `claude plugin validate ./plugins/tmt` passes
- [x] `grep -c "Defect Mechanism" plugins/tce/references/research-document-template.md plugins/tce/commands/research.md plugins/tce/commands/work.md plugins/tce/commands/quickfix.md` shows at least one hit per file

#### Manual Verification:

- [x] The CRITICAL block reads coherently with both exceptions (the TP-0004
      verification precedent): the DO-NOT bullets stay absolute, each exception
      is bounded, and the drift exception's "only recommendation allowed"
      scoping still holds (the defect exception permits documentation, not a
      recommendation)
- [x] The exception is keyed on the ticket describing a defect (not on research
      mood) and states the classification plainly
- [x] The exception is stated exactly once (no echoes elsewhere in research.md —
      TP-0016 discipline)
- [x] Feature-ticket behavior is textually unchanged (no DO-NOT bullet weakened)
- [x] Template section sits in the main template block and follows the
      strong-form include/omit style; both composites restate the condition at
      their write steps

---

## Phase 2: Align codebase-analyzer's unconditional restatements

### Overview

Give the analyzer's Step-3 bullets and "What NOT to Do" list the same "unless
the user explicitly asks" escape its CRITICAL block already has, so a caller's
explicit defect-tracing prompt is never refused by the agent's own rules. Set
the ticket to `Done` in the same commit (all phases complete).

### Changes Required:

#### 1. `plugins/tce/agents/codebase-analyzer.md` — conditionalize the restatements

**File**: `plugins/tce/agents/codebase-analyzer.md`
**Changes**: Three surgical line edits (current wording per research; re-read
the file before editing). The CRITICAL block (`:37-45`) and REMEMBER closer
(`:157-161`) stay untouched.

Line 91 (Step 3), from:

```markdown
- DO NOT identify potential bugs or issues
```

to:

```markdown
- DO NOT identify potential bugs or issues unless the user explicitly asks you to trace a defect's mechanism
```

Line 149 ("What NOT to Do"), from:

```markdown
- Don't identify bugs, issues, or potential problems
```

to:

```markdown
- Don't identify bugs, issues, or potential problems (unless the user explicitly asks you to trace a defect's mechanism)
```

Line 153 ("What NOT to Do"), from:

```markdown
- Don't perform root cause analysis of any issues
```

to:

```markdown
- Don't perform root cause analysis of any issues (unless the user explicitly asks for it)
```

Line 90 ("DO NOT evaluate if the logic is correct or optimal") stays unchanged:
evaluating quality remains banned even for defect tracing — divergence from
intended behavior is described, not judged.

#### 2. `thoughts/shared/tickets/TP-0018-research-root-cause-for-defects.md` — status + notes

**File**: `thoughts/shared/tickets/TP-0018-research-root-cause-for-defects.md`
**Changes**: `**Status:** In Progress` → `**Status:** Done`; update
`**Updated:**`; add a dated entry under "Notes & Updates" recording the
checkpoint decisions (dedicated template section; minimal analyzer alignment;
locator/pattern-finder unchanged per research).

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -n "unless the user explicitly asks" plugins/tce/agents/codebase-analyzer.md` shows the escape on the CRITICAL-block bullets AND the three amended lines

#### Manual Verification:

- [x] The analyzer file no longer contains any unconditional ban that would
      refuse an explicit defect-tracing request (`:90` stays unconditional by
      design — it bans quality judgment, not mechanism tracing)
- [x] `codebase-locator.md` and `codebase-pattern-finder.md` are untouched
- [x] Ticket acceptance criteria all check out (exception with boundary in
      research.md; composites mirrored same-commit; agent outcome applied
      consistently; non-defect behavior unchanged)

---

## Testing Strategy

### Unit Tests:

- None — the change set is markdown command prose; the repo's automated check
  is `claude plugin validate` (manifest/structure validation), run per phase.

### Integration Tests:

- Not run for this change: an end-to-end exercise would require installing the
  plugins in a scratch project and researching a real defect ticket. The
  repo's dogfooding covers this — the next defect-shaped ticket researched
  here exercises the exception live.

### Manual Testing Steps:

1. Read `research.md:59-90` top to bottom: the block must read as one coherent
   rule set — absolute bullets, then two bounded exceptions.
2. Read the template's new section in context (`references/research-document-template.md`)
   and confirm the include/omit instruction mirrors the drift section's style.
3. Diff-review `work.md` / `quickfix.md`: only the write-step lines changed.
4. Confirm `codebase-analyzer.md`'s three amended lines carry the escape and
   nothing else in the file changed.

## Performance Considerations

Prompt-length impact only: the CRITICAL block grows by ~10 lines but sits early
in `research.md` (the region that survives auto-compaction); the review's
length pressure (Section 2 item 1) is respected by adding no step-level
machinery and no repetition.

## Migration Notes

None — no consuming-project config changes, no version-marker changes, no
init/refresh impact. The reference-file edit reaches consumers on their next
plugin update automatically.

## References

- Original ticket: `thoughts/shared/tickets/TP-0018-research-root-cause-for-defects.md`
- Related research: `thoughts/shared/research/2026-07-05-TP-0018-root-cause-analysis-for-defect-tickets.md`
- Review origin: `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` (Section 2, finding 6)
- Exception-pattern precedent: `thoughts/shared/plans/2026-06-14-TP-0004-profile-drift-refresh.md` (Phase 2)
- Single-statement discipline: `thoughts/shared/plans/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md`
