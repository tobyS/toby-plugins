# Ticket-Sufficiency Criteria Sync Rule (TP-0022) Implementation Plan

## Overview

Add a stated same-commit sync rule to the repo's `CLAUDE.md` governing the
three copies of the three-part ticket-sufficiency test, and reconcile the one
substantive drift the copies have already accumulated. This is a
documentation/repo-instructions change plus a one-line reconciliation in a tce
command; it introduces no new plugin behavior beyond that reconciliation.

## Current State Analysis

The three-part sufficiency test (scope determinable, outcome observable, at
least one concrete anchor) lives in three places, each in a different register
**by design**:

- `plugins/tce/templates/tce/tickets.md:64-90` — "What tce needs from a ticket",
  the consumer-facing contract (richest copy; anchor examples include "code
  area").
- `plugins/tce/commands/research.md:114-133` — the operational "Ticket
  Sufficiency Check" (numbered criteria; anchor examples **omit** "code area").
- `plugins/tce/commands/work.md:76` — a one-line compression (Phase 1 step 4;
  no examples, per the composite-tracking rule).

`CLAUDE.md` has a contiguous sync-rule cluster (lines 171–322) but **no rule
covers this trio**, so the copies can drift silently. They already have: the
only *substantive* drift is that `research.md`'s anchor examples omit "code
area", which the canonical `tickets.md` copy lists. Remaining differences
(criterion labels, a "from the ticket" qualifier, boundary/free-form
parentheticals, exclusion-list header) are register/prose and are intentionally
tolerated.

### Key Discoveries:

- The copies are **not byte-identical and were never meant to be** — `work.md`
  compresses to one clause; `tickets.md` is descriptive prose
  (research doc `Summary`, `Architecture Documentation`). So the new rule is a
  **semantic-mirror** rule (TP-0013/composite family), **not** a byte-identical
  rule like the AskUserQuestion block (`CLAUDE.md:305-322`).
- The `CLAUDE.md` sync-rule pattern to match: a `##` heading (ticket-suffixed),
  setup paragraph(s) naming the artifacts and why they drift, a bold `**RULE:`
  sentence containing the exact phrase "in the same commit", backticked
  filenames, optional verification method, cross-references to related rules
  (research doc `## The existing CLAUDE.md sync-rule pattern`).
- Insertion point: a standalone `##` section immediately after the
  AskUserQuestion rule (ends `CLAUDE.md:322`) and before `## Testing changes`
  (`CLAUDE.md:324`) — keeps it in the sync-rule cluster (research doc
  `Placement`).
- Canonical copy confirmed at the checkpoint: `tickets.md`'s "What tce needs
  from a ticket". Reconciliation scope confirmed: **substantive drift only**
  (add "code area" to `research.md`; leave register differences). Placement
  confirmed: **standalone section**.

## Desired End State

1. `plugins/tce/commands/research.md`'s anchor examples include "code area", so
   all three copies agree in *substance* on the anchor category set.
2. `CLAUDE.md` contains a new standalone `## … (TP-0022)` sync-rule section, in
   the cluster after the AskUserQuestion rule, that: names all three copies,
   designates `tickets.md` as canonical, requires same-commit updates of the
   three-part substance, and explicitly frames itself as a semantic-mirror
   (register-tolerant) rule distinct from the byte-identical AskUserQuestion
   rule.
3. No other behavioral change to the commands; `work.md` is untouched (its
   register legitimately carries no examples).

Verify by: `claude plugin validate` passing for the marketplace and both
plugins; reading the three passages and confirming their criteria + anchor
example sets agree in substance; confirming the new rule reads consistently
with the neighboring sync rules.

## What We're NOT Doing

- **Not** changing the sufficiency criteria themselves (ticket Out of Scope).
- **Not** normalizing register wording (labels, "from the ticket", boundary/
  free-form parentheticals, exclusion header) — the checkpoint chose
  "substantive drift only".
- **Not** editing `work.md`'s compressed copy — it intentionally carries no
  example anchors, and the rule permits that register.
- **Not** de-duplicating the copies into a shared reference file — forbidden by
  the core design rule for these cross-context copies (ticket Out of Scope;
  research doc `Historical Context`).
- **Not** folding other duplicated fragments into the rule — research found none
  belonging to this trio (checkpoint: keep scope tight).

## Implementation Approach

A single phase: reconcile the substantive drift first (so all three copies
agree before the rule is stated), then add the sync rule to `CLAUDE.md`. Both
edits are small and tightly coupled to one ticket, so they land in one commit.
This is a docs/instructions change with a one-line command reconciliation — no
code, no tests to add; verification is the plugin-validate suite plus a manual
read-through of the reconciled copies and the new rule.

## Phase 1: Reconcile the drift and add the sync rule

### Overview

Add the "code area" anchor example to `research.md`, then insert the standalone
sync-rule section into `CLAUDE.md` after the AskUserQuestion rule.

### Changes Required:

#### 1. Reconcile the substantive drift in research.md

**File**: `plugins/tce/commands/research.md`
**Changes**: On line 123, add "code area" to the anchor example list so it
matches the canonical `tickets.md` set. Keep `research.md`'s existing terse
register (no "a feature" prefix); the minimal grammatical addition is the
trailing "or code area".

Current (line 123):

```markdown
3. **There's an anchor** — at least one concrete pointer into the system (feature, screen, command, error message) so research has somewhere to start.
```

New:

```markdown
3. **There's an anchor** — at least one concrete pointer into the system (feature, screen, command, error message, or code area) so research has somewhere to start.
```

(`work.md` is intentionally left unchanged — its one-line compression carries no
example anchors, which the new rule explicitly permits.)

#### 2. Add the sync-rule section to CLAUDE.md

**File**: `CLAUDE.md`
**Changes**: Insert a new `##` section between the end of the AskUserQuestion
rule (line 322) and `## Testing changes` (line 324). Insert exactly this block
(a blank line before and after, matching the surrounding spacing):

```markdown
## The ticket-sufficiency criteria are triplicated — keep the three-part test in sync (TP-0022)

The three-part ticket-sufficiency test — **scope determinable, outcome
observable, at least one concrete anchor into the system** — appears in three
places, each in a different register by design:

- `plugins/tce/templates/tce/tickets.md` ("What tce needs from a ticket") — the
  **canonical** copy: the consumer-facing contract, the fullest statement, and
  the one `research.md` cross-references. Conflicts resolve toward it.
- `plugins/tce/commands/research.md` ("Ticket Sufficiency Check") — the
  operational check `/tce:research` runs; states the three criteria with example
  anchors.
- `plugins/tce/commands/work.md` (Phase 1 step 4) — a deliberate one-line
  compression (`work.md` re-describes `research` inline, per the
  composite-tracking rule), with no sub-clauses.

Unlike the AskUserQuestion block above, these copies are **not byte-identical**:
`work.md` compresses the test to a clause and `tickets.md` is descriptive prose,
so demanding identity would fight the composite-tracking rule. What must stay in
sync is the **substance** — the three criteria, their meaning, and any
category-level example (an anchor *kind*, a "not required" item). Per-copy
wording and register may differ.

**RULE: When you change the three-part sufficiency test — add, remove, or
redefine a criterion, or change a category-level example (an anchor kind, a "not
required" item) — update all three copies in the same commit, reconciling the
substance toward the canonical `tickets.md` copy; `work.md` need only carry
whatever its one-line compression admits.** Purely stylistic or register wording
(criterion labels, qualifiers, punctuation) is exempt. This is a semantic-mirror
rule (like the TP-0013 re-read rule), not the byte-identical AskUserQuestion rule
above. Verify by reading the three passages and confirming their criteria and
example sets agree in substance.
```

### Success Criteria:

#### Automated Verification:

- [ ] Marketplace manifest validates: `claude plugin validate .` (run in repo root)
- [ ] tce plugin validates: `claude plugin validate ./plugins/tce` (run in repo root)
- [ ] tmt plugin validates: `claude plugin validate ./plugins/tmt` (run in repo root)
- [ ] `research.md` line 123 anchor list contains "code area" (`grep -n "code area" plugins/tce/commands/research.md`)
- [ ] `CLAUDE.md` contains the new rule heading (`grep -n "keep the three-part test in sync (TP-0022)" CLAUDE.md`)

#### Manual Verification:

- [ ] The three copies (`tickets.md:64-90`, `research.md:114-133`, `work.md:76`)
      now agree in substance: same three criteria, and the anchor example set of
      the two full copies matches (feature, screen, command, error message, code
      area); `work.md` still carries no examples by design.
- [ ] The new `CLAUDE.md` section reads consistently with the neighboring sync
      rules (heading style, bold `**RULE:` sentence, "in the same commit" phrase,
      backticked filenames, cross-references), and correctly names `tickets.md`
      as canonical.
- [ ] No unintended behavioral change: the sufficiency criteria themselves are
      unchanged, `work.md` is untouched, and no register wording was normalized.
- [ ] Ticket acceptance criteria all satisfied (rule names three locations +
      requires same-commit; designates canonical copy; drift diffed and
      reconciled; no behavioral change beyond the "code area" reconciliation).

---

## Testing Strategy

### Unit Tests:

None — no executable code changes. The repo has no test suite beyond manifest
validation.

### Integration Tests:

None applicable.

### Manual Testing Steps:

1. Run `claude plugin validate .`, `claude plugin validate ./plugins/tce`, and
   `claude plugin validate ./plugins/tmt` from the repo root; all pass.
2. Read `plugins/tce/commands/research.md:114-133`,
   `plugins/tce/templates/tce/tickets.md:64-90`, and
   `plugins/tce/commands/work.md:76` side by side; confirm the three-part
   substance and (for the two full copies) the anchor example set now agree.
3. Read the new `CLAUDE.md` section in place after the AskUserQuestion rule;
   confirm style/altitude match and the canonical designation is correct.

## Performance Considerations

None — documentation and instruction-file edits only.

## Migration Notes

None — `CLAUDE.md` is a repo-internal instructions file; `research.md` and
`tickets.md` are plugin source. No consuming-project migration; the `tickets.md`
template change only affects *future* `/tce:init` runs (existing consumers keep
their copied file until they re-init), and it merely adds an example already
implied by the criteria.

## References

- Original ticket: `TP-0022` — `thoughts/shared/tickets/TP-0022-sufficiency-criteria-sync-rule.md`
- Related research: `thoughts/shared/research/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.md`
- Canonical copy: `plugins/tce/templates/tce/tickets.md:64-90`
- Reconciliation site: `plugins/tce/commands/research.md:123`
- Insertion point / pattern to match: `CLAUDE.md:305-324` (AskUserQuestion rule + boundary)
