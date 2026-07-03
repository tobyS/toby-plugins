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
- `1ae2712` refactor(TP-0016): extract research.md templates into a reference file

---

## Phase 2: plan.md restructure
- **Status**: ✅ Complete
- **Started**: 2026-07-03
- **Completed**: 2026-07-03

### Steps Performed
1. Created `plugins/tce/references/plan-document-template.md` (218 lines): runtime-read header + 4-item TOC, plan document template verbatim, Success Criteria Guidelines verbatim, Common Patterns as "Structuring patterns", plus the UI/UX Approach section skeleton (moved from Step 3 — see Issues).
2. Rewrote `plugins/tce/commands/plan.md` 769 → 443 lines: template + tail sections extracted/folded/deleted per plan (Sub-task Spawning folded into Step 2 points 3–4; Example Interaction Flow and Important Guidelines deleted after fold-audit — skeptical framing → intro, incremental/rollback/edge-cases → Step 3.2, file-paths-in-plan → Step 4.2, no-open-questions-in-final-plan → Handling item 4); dedup (read-fully 10→1 in Step 1.1 + the two protected TP-0013 clauses; no-re-read/no-respawn consolidated to one full-strength statement in Research Document Integration with pointers elsewhere; ticket.sh 4→1 canonical in Ticket Document Discovery; success-criteria split → Step 4.2 mention + reference file; TodoWrite 2→1).
3. Rewrote Step 5 as the decision-oriented summary spec (decisions + rejected alternatives with one-line why, riskiest assumptions, explicit out-of-scope, path + one-line-per-phase list), keeping iterate loop, /tce:commit, next-command hint, and "your job ends here" unchanged in meaning.
4. Composite syncs: work.md 3a plan-template bullet now reads the reference file; work.md:189 Step 3/4 coupling verified unchanged (no edit); work.md 2c checkpoint intro left as-is (it is the open-questions surface, not plan review — plan predicted "small touch or none"); quickfix.md autonomy overrides verified to still name existing plan.md behavior (structure review = Step 3.3, open-questions handling, design-exploration check) — no edit.

### Issues Encountered
- The plan's enumerated extractions left plan.md at ~498 lines. Three additional cuts, all within the ticket's dedup/extraction logic, reached 443: (a) the Handling-Open-Questions example interaction deleted — it duplicated Step 1.6's presentation skeleton plus the AskUserQuestion guidelines (within-file duplication, no unique behavior); (b) Step 1.6's trailing presentation paragraph reduced to a pointer (restated Handling item 2); (c) the UI/UX Approach skeleton moved to the reference file as a fourth section — it is plan-*document* template material (deviation: not in the plan's reference-file content list, but squarely under AC 1 "document templates live in reference files").
- The plan's "Fix Step 1's duplicate point numbering (two '5.' items)" found nothing to fix — TP-0015 (`6dc55a2`) had already corrected the numbering; anchors verified instead.

### Verification
- ✅ `claude plugin validate .` and `./plugins/tce` pass
- ✅ `wc -l plan.md` = 443 (≤ 450)
- ✅ reference-file grep: plan.md ×2 (Step 3 + Step 4), work.md ×1
- ✅ Important Guidelines / Common Patterns / Example Interaction Flow / Sub-task Spawning headings absent
- ✅ `work.md:189` still matches plan.md's Step 3/4 headings
- ✅ AskUserQuestion block md5-identical across all nine files
- ✅ Diff audit: deletions classified extracted / restated / folded (mapping above); TP-0013 clauses at Ticket Document Discovery §2 and Research Document Integration byte-preserved; Design Exploration Check byte-preserved
- ⚠️ Scratch-project smoke run deferred to Phase 3's end-to-end run

### Commit
- `f23efb6` refactor(TP-0016): extract plan.md templates, respec Step 5 summary

---

## Phase 3: Documentation, sibling-ticket note, validation
- **Status**: ✅ Complete
- **Started**: 2026-07-03
- **Completed**: 2026-07-03

### Steps Performed
1. `CLAUDE.md`: added `references/` to the layout tree; added a core-design-rule bullet (reference files are part of the command contract, point-of-use reads, composite/TP-0013 rules apply, never copied into projects); extended the composite-tracking trigger list to name `plugins/tce/references/`; replaced the stale AskUserQuestion rationale ("commands don't read plugin-internal markdown") with the still-true reasons (cross-plugin forbidden; guidelines govern whole-body dialog sites, not one moment of use). The `/tce:refresh` section's "commands don't read each other's markdown" left as-is (still accurate).
2. `.claude/tce/profile.md`: added the code-map row for `plugins/tce/references/`.
3. `plugins/tce/README.md`: added a "Document templates" bullet to "How project parameterization works". `CONTRIBUTING.md` (found during implementation — also carries a layout tree): added the `references/` line.
4. `TP-0022` ticket: dated note that its Out-of-Scope rationale is outdated per TP-0016's research; scope decision unaffected.
5. Ticket TP-0016 set to Done.

### Issues Encountered
- The plan's end-to-end scratch-project smoke run was **not** executed live: installing/updating the plugins to run it would modify the user's user-scoped plugin installs, and a headless `/tce:plan` run requires interactive feedback. Substituted a mechanical fidelity proof: all six extracted blocks (research template, Impact Analysis, plan template, Success Criteria Guidelines, Common Patterns, UI/UX skeleton) diffed byte-identical against the pre-change command text from git history (modulo the documented list-indentation dedent). Since the templates fully define the produced documents' structure, structural identity of output follows; the one thing still unverified is a live session performing the `${CLAUDE_PLUGIN_ROOT}/references/` Read mid-command — flagged to the maintainer for the next real `/tce:research`/`/tce:plan` run after a plugin update.

### Verification
- ✅ `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` all pass
- ✅ `grep -c "don't read plugin-internal markdown" CLAUDE.md` = 0
- ✅ `references/` documented in CLAUDE.md (5), profile.md (1), tce README (2), CONTRIBUTING.md (1)
- ✅ Template fidelity diffs: all six blocks identical to pre-change text
- ✅ CLAUDE.md rules read coherently (core design rule ↔ composite rule ↔ new reference-file bullet; no contradiction)
- ⚠️ Live runtime-read smoke deferred to the maintainer (see Issues)

### Commit
- (this commit)
