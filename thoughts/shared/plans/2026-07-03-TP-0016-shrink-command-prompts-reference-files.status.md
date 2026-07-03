# Implementation Status: TP-0016 — Shrink Command Prompts (reference files, dedup)

## Phase 1: research.md restructure
- **Status**: ✅ Complete
- **Started**: 2026-07-03
- **Completed**: 2026-07-03

### Steps Performed
1. Created `plugins/tce/references/research-document-template.md` (131 lines): runtime-read header (composite-tracking note, step-number scope, downstream frontmatter consumers), the research document template verbatim (dedented from list indentation), the Impact Analysis template verbatim with its inclusion condition.
2. Rewrote `plugins/tce/commands/research.md` 475 → 330 lines: both templates replaced by point-of-use read instructions ("in full, even if read earlier this session"); `## Important notes` digest deleted after fold-audit; dedup per plan (read-fully 5→1 in step 1; wait-for-all → step 4 title; documentarian 11→1 in the CRITICAL section, which gained the sub-agent-reminder line; placeholders folded into step 6; self-contained → step 6; synthesis-focus + all-of-thoughts → step 3; fresh-research + exact-disk-paths → step 4).
3. Synced composites: `work.md` 1b and `quickfix.md` Phase 3 step 5 now instruct the reference-file read (same read-at-use wording) instead of describing/naming the inline template.

### Issues Encountered
- Plan said config-drift "4→2: delete the other two echoes" (the CRITICAL-section exception paragraph and the step-8 advisory). Deleting them outright would contradict the CRITICAL section's no-recommendations rule and drop the presentation behavior, so instead: the exception paragraph was shortened to an authorization + pointer ("detection criteria in step 4; surfaced in step 8") and step 8's one-line advisory kept. The drift *mechanism* is now described only in step 4 + the template — the plan's intent.
- Canonical placement judgment: read-fully lives in step 1 (not Initial Setup) because step 1 is its point of use and step titles must be preserved; Initial Setup's restatement bullet deleted.

### Verification
- ✅ `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` all pass
- ✅ `wc -l research.md` = 330 (≤ 400)
- ✅ reference-file grep: research.md ×2, work.md ×1, quickfix.md ×1
- ✅ `## Important notes` and template headings absent from command body
- ✅ AskUserQuestion block md5-identical across all nine files
- ✅ Diff audit: every deleted line extracted / restated / folded (details above)
- ⚠️ Scratch-project smoke run of `/tce:research` deferred to the Phase 3 end-to-end run (needs interactive plugin install; single setup serves both)

### Commit
- (pending)

---

## Phase 2: plan.md restructure
- **Status**: ⬚ Not started

---

## Phase 3: Documentation, sibling-ticket note, validation
- **Status**: ⬚ Not started
