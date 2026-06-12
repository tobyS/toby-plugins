# Implementation Status: TP-0001 — Prescribed copy for AskUserQuestion dialogs

## Phase 1: Copy Drafting & Interactive Review Checkpoint
- **Status**: ✅ Complete
- **Started**: 2026-06-12 18:55
- **Completed**: 2026-06-12 19:10

### Steps Performed
1. Ticket marked In Progress (to be committed with Phase 2)
2. Copy deck drafted and presented: guidelines block, /tmt:init prefix dialog,
   /tce:init ticket-system + batched policy dialogs, /tce:work checkpoint framing
   template, one-line dynamic-site references
3. Review round 1: Toby requested — intro wording "start from a ticket" (③);
   transition-timing explanation added to the policy intro (no per-question
   description field exists, so it lives in the shared intro) (④); "Allowed
   (Recommended)" for ticket creation on ALL systems, not just tmt (⑤);
   compact context format for the work checkpoint intro (1-sentence bold
   summary + ≤4-sentence paragraph, anti-verbosity note in template) (⑥)
4. Revised deck approved in full ("Great.")

### Issues Encountered
- AskUserQuestion has no question-level description field → transition-timing
  context moved to the batched call's intro paragraph (approved)

### Verification
- ✅ Toby approved guidelines block, all four dialogs, framing template, and
  dynamic-site reference line (labels ≤5 words, headers ≤12 chars, no "Other")

### Commit
- (none — Phase 1 makes no file changes)

---

## Phase 2: Apply to tce (guidelines block + init copy + dynamic sites)
- **Status**: ✅ Complete
- **Started**: 2026-06-12 19:15
- **Completed**: 2026-06-12 19:30

### Steps Performed
1. Guidelines block (byte-identical, `### AskUserQuestion dialog guidelines`)
   inserted at the end of the preamble of init.md, research_codebase.md,
   create_plan.md, work.md, quickfix.md
2. init.md: verbatim copy for ticket-system dialog (intro + question + header
   "Tickets" + 4 options) and the batched policy dialog (intro with
   transition-timing explanation, "Status" + "Creation" questions, per-system
   ordering for Status, "Allowed (Recommended)" everywhere for Creation);
   ambiguity fallback now references the guidelines
3. research_codebase.md: sufficiency-check round presented per guidelines
4. create_plan.md: open-questions handling references guidelines; example
   interaction rewritten as intro + one AskUserQuestion call; Step 1.5 gains
   the presentation rule
5. work.md: sufficiency mirror updated; checkpoint replaced with approved
   intro template + dialog rules + verbatim design-exploration question
6. quickfix.md: clarity round and planning-phase ask-override reference the
   guidelines
7. Ticket TP-0001 set to In Progress (committed here)

### Issues Encountered
- (none)

### Verification
- ✅ `claude plugin validate .` and `./plugins/tce` pass
- ✅ Guidelines heading present in exactly the five intended tce commands

### Commit
- `31e7760` feat(TP-0001): prescribe AskUserQuestion dialog copy in tce commands

## Phase 3: Apply to tmt (guidelines block + prescribed prefix dialog)
- **Status**: ✅ Complete
- **Started**: 2026-06-12 19:32
- **Completed**: 2026-06-12 19:38

### Steps Performed
1. Guidelines block inserted into plugins/tmt/commands/init.md (same bytes and
   position convention as tce)
2. Phase 2 "Propose" rewritten: plain-text proposal block + ambiguity fallback
   replaced with the one prescribed AskUserQuestion (verbatim intro + question
   + header "Prefix" + recommended-first option with provenance description,
   ≥2-options rule with mechanical second derivation, automatic-Other note)
3. Idempotency section checked — does not reference the removed proposal
   block, left unchanged

### Issues Encountered
- (none)

### Verification
- ✅ `claude plugin validate ./plugins/tmt` passes

### Commit
- `1b2c2c8` feat(TP-0001): prescribe the /tmt:init prefix dialog copy

## Phase 4: CLAUDE.md sync rule + repo-wide verification
- **Status**: ✅ Complete
- **Started**: 2026-06-12 19:40
- **Completed**: 2026-06-12 19:48

### Steps Performed
1. Added the named sync rule to CLAUDE.md ("The AskUserQuestion guidelines
   block is duplicated — keep the copies identical"): six carrying files
   listed, same-commit rule, verbatim-copy-is-contract note
2. Block-identity check: extracted the 19-line block from all six files,
   diffed against the tce/init.md reference — all identical
3. `claude plugin validate` for marketplace, tce, tmt — all pass
4. Ticket TP-0001 set to Done, all five acceptance criteria ticked
5. Plan success-criteria checkboxes ticked (one exception: the scratch-project
   dogfood run is left open — needs an interactive scratch session; noted in
   the plan)
6. CLAUDE.md commit includes the pre-existing uncommitted dogfooding note in
   its intro (user-authored, related, whole-file staging)

### Issues Encountered
- (none)

### Verification
- ✅ Block byte-identical across all six command files
- ✅ All three plugin validations pass
- ⬚ Scratch-project dogfood of /tmt:init + /tce:init — deferred (manual)

### Commit
- (see below — docs commit closing the ticket)
