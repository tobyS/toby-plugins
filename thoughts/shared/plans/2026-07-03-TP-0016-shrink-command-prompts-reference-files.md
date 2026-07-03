# TP-0016: Shrink Command Prompts — Implementation Plan

## Overview

Extract the stable reference blocks (document templates, format guidance) from
`plugins/tce/commands/plan.md` and `research.md` into a new
`plugins/tce/references/` directory that the commands Read at the moment of
use, deduplicate every instruction to a single well-placed statement, and
respec plan.md's Step 5 presentation as a decision-oriented summary. Behavior,
the chain, checkpoints, and document structures are unchanged — this is an
internal restructuring that makes the two most important commands survive
auto-compaction (only the first 5,000 tokens per invoked skill are re-attached,
within a 25,000-token combined budget) and makes each rule editable in one
place.

## Current State Analysis

Per the research (`thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md`):

- `plan.md` is 769 lines, 43% (~330 lines) of which are fixed template/reference
  blocks; `research.md` is 475 lines, 27% (~130 lines) fixed blocks. Official
  guidance: keep skill bodies under 500 lines, detail in reference files.
- The tails of both files (plan.md's Success Criteria Guidelines, Common
  Patterns, Sub-task Spawning, Example Interaction Flow; research.md's
  Important notes) fall past the 5,000-token compaction cliff in exactly the
  sessions that compact (`/tce:work` on Large tickets).
- The same instruction appears 3–11 times per file ("read FULLY" ×10 in
  plan.md, "documentarian" ×11 in research.md, etc.). Git archaeology shows
  only two repeated blocks are deliberate (TP-0013 re-read clauses, the
  nine-copy AskUserQuestion block); all others date to the initial template
  import (`fb68d34`) — pure lineage.
- There are currently **zero** runtime Reads of plugin-internal markdown;
  `${CLAUDE_PLUGIN_ROOT}` is used in command bodies only to execute
  `scripts/ticket.sh` — which proves the substitution works in flat
  `commands/*.md` (dogfooded daily in this repo).
- `plan.md` Step 5 currently presents only the draft-plan location plus four
  generic review prompts; the summary content is unspecified.

## Desired End State

- `plan.md` ≤ 450 lines, `research.md` ≤ 400 lines, both with no loss of
  behavior. Verify: `wc -l`, plugin validations pass, and an end-to-end smoke
  run of `/tce:research` + `/tce:plan` in a scratch project produces documents
  with the same structure as before.
- Document templates live in `plugins/tce/references/` and are read via
  `${CLAUDE_PLUGIN_ROOT}/references/...` at the point of use, unconditionally
  ("even if read earlier in this session" — the TP-0013 doctrine extended to
  the commands' own material).
- Within each edited command, every instruction is stated exactly once, except
  the justified survivals recorded in the table below.
- `plan.md` Step 5 specifies the decision-oriented summary (decisions +
  rejected alternatives, riskiest assumptions, out-of-scope) as the human
  review surface.
- CLAUDE.md, profile.md, and the tce README document the new `references/`
  convention; the stale "commands don't read plugin-internal markdown at
  runtime" rationale in CLAUDE.md is corrected.

### Key Discoveries

- Compaction limits doc-confirmed: first 5,000 tokens per invoked skill,
  25,000-token combined budget, most-recent-first (skills docs, "Skill content
  lifecycle"). Reference files survive because they are re-read from disk.
- Commands are officially skills; supporting files read on demand are the
  sanctioned mechanism ("no context penalty for large files … until actually
  read").
- A reference file is only re-read if the surviving body still instructs the
  read at the moment of use — read instructions must sit inside the numbered
  steps, not in a tail section.
- Hard couplings that must survive: `work.md:189` names plan.md's "Step 3
  (Plan Structure Development)" and "Step 4 (Detailed Plan Writing)" verbatim;
  research.md's internal refs pin its step numbers; implement.md consumes the
  research frontmatter fields `git_commit`/`branch` and the plan template's
  phase/checkbox/success-criteria structure.

## What We're NOT Doing

- No behavior, chain, checkpoint, or document-format changes.
- No `skills/<name>/SKILL.md` conversion — commands stay flat (decided in
  planning: smallest diff, all documented paths stay valid, substitution
  already proven).
- No frontmatter machinery (TP-0017), no status-file changes (TP-0023 owns
  that; TP-0016 does not touch implement.md's status-file text — no conflict),
  no sufficiency-trio dedup (TP-0022 owns their sync rule).
- No restructuring of `init.md`, `review.md`, `design_explore.md` — the
  "opportunistic wins" option was explicitly declined in planning; they follow
  in a later ticket once the pattern is proven.
- Cross-file near-duplicates (canonical-ID-in-filename rule in both commands;
  composite mirrors) are **in scope only as required syncs**, not as a dedup
  target: "each rule stated once" applies within each file. Cross-file copies
  stay governed by the composite rule and TP-0022.
- No changes to the nine AskUserQuestion copies or the TP-0013 re-read clauses
  (byte-preserved).

## Implementation Approach

Three phases, one commit each, riskiest edits isolated per file so each is
independently reviewable and revertable (the ticket's sanctioned exception to
"surgical edits over rewrites" — staged one command at a time). research.md
goes first (smaller, proves the pattern), plan.md second, docs/validation
last. Top-level step titles and numbers in both commands are **preserved
unchanged** to keep internal anchors and the `work.md:189` coupling intact;
extraction happens inside steps.

### Justified surviving repetitions (Acceptance Criterion 2 record)

| Repetition kept | Justification |
|---|---|
| TP-0013 chain-order re-read clause (one per command) | Failure-motivated (commit `062edd9`); CLAUDE.md rule forbids removing it; deliberately per-command (TP-0013 research rejected a shared block) |
| AskUserQuestion guidelines block (nine cross-file copies, incl. one each in plan.md/research.md) | TP-0001 (commit `31e7760`); CLAUDE.md byte-identity rule |
| Source-file no-re-read rule: one canonical full statement + short pointer phrases ("per Research Document Integration above") at other former sites | CLAUDE.md TP-0013 rule says this guidance must not be weakened; pointers are references, not restatements |
| Reference-file read instructions appear at *each* point of use (e.g. plan template read in both Step 3 and Step 4) | Compaction only preserves what the surviving body instructs at the moment of use — doc-confirmed lifecycle; an earlier read's tool output is not restored |

---

## Phase 1: research.md restructure

### Overview

Extract the research-document template into a reference file, deduplicate
research.md to single statements, delete the Important-notes digest after
folding its unique content upward, and sync the composite mirrors.

### Changes Required

#### 1. New file: `plugins/tce/references/research-document-template.md`

Content, in order:

- A short header (HTML comment or intro paragraph): read at runtime by
  `/tce:research` (and the composites' research phases) at the moment of
  writing the document; never copied into consuming projects; changes here are
  command-contract changes — the CLAUDE.md composite-tracking rule applies.
- The research document template **verbatim** from `research.md:266-347`
  (frontmatter spec incl. `git_commit`/`branch`/`last_updated` — implement.md
  and plan.md consume these — all body sections, and the conditional "tce
  Config Drift" section), kept inside its existing code fence.
- The Impact Analysis section template **verbatim** from `research.md:420-440`
  as a second fenced block with a one-line "include when the ticket changes
  existing behavior" note (mirror the condition research.md states today).

#### 2. `plugins/tce/commands/research.md`

- **Template extraction**: replace `research.md:266-347` and `:420-440` with
  point-of-use instructions: "Read
  `${CLAUDE_PLUGIN_ROOT}/references/research-document-template.md` now — in
  full, even if you read it earlier in this session — and produce the document
  following it exactly." (Impact Analysis: same file, its second section.)
- **Deduplication** (sites from research §4; keep the listed canonical site,
  delete the rest):
  - "Read FULLY / no limit/offset" 5→1 — canonical in the initial-setup step.
  - "Read mentioned files before spawning sub-tasks" 3→1 — at the spawn step.
  - "Wait for ALL sub-agents" 3→1 — at the spawn/collect step.
  - Documentarian identity ("not critic, what IS not SHOULD BE") 11→1 — the
    existing CRITICAL section (`research.md:58-74`) stays as the single
    statement; delete all echoes in steps and notes.
  - Metadata-before-writing / "NEVER placeholder values" 4→1 — fold into the
    document-writing step (the placeholder-values sentence exists in full only
    in the digest — it must be folded, not dropped).
  - Config-drift mechanism 4→2: keep the detection step (the behavior — the
    CLAUDE.md refresh-tracking rule protects it) and the template's conditional
    section (now in the reference file); delete the other two echoes.
- **Delete `## Important notes`** (`research.md:446-475`) after auditing every
  bullet: fold any nuance stated nowhere else into the step where it applies;
  pure restatements (including the "Critical ordering" step-number recap —
  the numbered steps already order themselves) are deleted.
- **Preserve byte-for-byte**: the AskUserQuestion block (`:18-36`), the
  TP-0013 re-read clause (`:81`), all top-level step numbers/titles (1–10),
  the sufficiency-check section (`:102-121`, TP-0022's canonical copy), the
  Workflow Context table.

#### 3. Composite syncs (same commit)

- `work.md` (research phase, `:82-88`): point its document-writing instruction
  at the reference file (same read-at-use wording) instead of "the standard
  /tce:research template" prose; verify the agent roster, drift taxonomy, and
  metadata/filename mirrors still match research.md's surviving text.
- `quickfix.md` (`:126-153`): same — its "standard /tce:research template +
  Impact Analysis" reference becomes a read of the reference file.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass
- [ ] `wc -l plugins/tce/commands/research.md` ≤ 400
- [ ] `grep -c 'references/research-document-template.md' plugins/tce/commands/research.md` ≥ 1; same grep hits in `work.md` and `quickfix.md`
- [ ] `grep -c '## Important notes' plugins/tce/commands/research.md` = 0; the template's section headings (e.g. "## Detailed Findings") no longer appear in the command body
- [ ] AskUserQuestion block still byte-identical across all nine files (extract heading→last bullet, diff)

#### Manual Verification

- [ ] Side-by-side review of the diff: every deleted line is either extracted verbatim, a restatement of a surviving line, or a folded-up nuance — no behavioral sentence lost
- [ ] TP-0013 re-read clause and drift-detection step intact and unweakened
- [ ] Scratch-project smoke run of `/tce:research` produces a document with the same structure/frontmatter as before

---

## Phase 2: plan.md restructure

### Overview

Extract the plan template and format guidance into a reference file, fold or
delete the four tail sections, deduplicate, rewrite Step 5 as the
decision-oriented summary, and sync the composites.

### Changes Required

#### 1. New file: `plugins/tce/references/plan-document-template.md`

Content, in order (file will exceed 100 lines → put a 3-line table of contents
after the header, per skills best practice):

- Same runtime-read header as the research reference file (read by `/tce:plan`
  Steps 3–4 and `work.md`'s planning phase).
- The plan document template **verbatim** from `plan.md:461-563` (all
  sections; phases with the Automated/Manual success-criteria split that
  implement.md consumes), in its existing fence.
- Success Criteria Guidelines **verbatim** from `plan.md:659-695` (the
  automated/manual taxonomy + format example) — this is format guidance for a
  template section, so it lives with the template.
- Common Patterns from `plan.md:697-720` (DB changes / new features /
  refactoring phase-ordering checklists) as a "structuring patterns" section —
  guidance for Step 3.

#### 2. `plugins/tce/commands/plan.md`

- **Template extraction**: Step 3 (structure development) gains: "Read
  `${CLAUDE_PLUGIN_ROOT}/references/plan-document-template.md` now — in full —
  before proposing the phase structure; use its structuring patterns." Step 4
  (writing) gains the same read instruction ("even if you read it in Step 3")
  in place of the inline template. Delete the three extracted tail sections.
- **Fold Sub-task Spawning Best Practices** (`plan.md:722-753`) into the step
  that spawns research sub-tasks (Step 2 / the no-research-document path): its
  ~8 behavioral bullets (parallel, focused, detailed instructions, specific
  directories, read-only tools, file:line refs, wait for all, verify results)
  stated once at the point of use; delete the section and its illustrative
  python block.
- **Delete Example Interaction Flow** (`plan.md:755-769`) outright.
  Justification: pure illustration, zero behavioral content, and it
  illustrates an outdated invocation (`/tce:implement` as the plan entry).
- **Delete `## Important Guidelines`** (`plan.md:599-657`) after the same
  fold-audit as research.md's digest (e.g. the "be skeptical / question vague
  requirements" framing, if judged unique, folds into the intro or Step 1).
- **Deduplication** (sites from research §4):
  - "Read FULLY / WITHOUT limit/offset / NEVER partially" 10→1 — canonical in
    Step 1 point 1.
  - "Don't re-read source files the research covers / research IS your
    context" 9→1 full statement — canonical in the Research Document
    Integration section, kept at full strength (CLAUDE.md-protected); other
    sites become short pointers or are deleted.
  - "Don't spawn redundant research agents" 7→1 — same section.
  - Open-questions handling 7→1 — canonical in the Handling Open Questions
    section (including "no open questions in final plan", folded there from
    the guidelines digest); steps point to it.
  - Success-criteria split 4→1 body mention + the reference file.
  - `ticket.sh` invocation 4→1 — canonical in Ticket Document Discovery;
    later steps say "via the discovery script (above)".
  - TodoWrite 2→1.
- **Fix Step 1's duplicate point numbering** (two "5." items today) and then
  verify every internal anchor ("Proceed directly to Step 3", "SKIP steps 3-4
  below", "proceed directly to step 6", the Step-5 self-reference) against the
  edited text.
- **Rewrite Step 5** (`plan.md:565-597`) — keep the title "Step 5" and the
  sync/commit/"your job ends here" mechanics, replace the presentation spec:

  Present a **decision-oriented summary** as the human review surface — the
  plan on disk is the agent's context; this summary is what the human actually
  reviews. It must surface everything the human might want to veto, not digest
  the plan's contents:
  - the decisions made and the alternatives rejected, each with a one-line why
  - the riskiest assumptions (what, if wrong, invalidates the plan)
  - the explicit out-of-scope items
  - the plan's location and a one-line-per-phase list
  Then the existing iterate-until-satisfied loop, `/tce:commit`, and the
  "Next command: `/tce:implement [PREFIX]-XXXX`" hint, unchanged in meaning.
- **Preserve byte-for-byte**: AskUserQuestion block (`:18-36`), TP-0013
  re-read clause (`:64,91`), top-level Step 1–5 titles and numbers, the
  Workflow Context table, the Design Exploration Check section.

#### 3. Composite syncs (same commit)

- `work.md:189`: verify unchanged (Step 3/4 titles preserved → expected no
  edit).
- `work.md:195-196`: point the plan-template and success-criteria references
  at the reference file (read at use).
- `work.md:128-179` (checkpoint intro): check against the new Step 5 spirit;
  minimal alignment only — work.md's checkpoint is the *open-questions*
  surface, not plan review (work.md deliberately skips plan approval,
  `work.md:200`), so expected outcome is a small wording touch or none.
- `quickfix.md:160-167`: inherits plan.md via Skill delegation — verify its
  autonomy overrides ("skip structure review", resolve-open-questions,
  design-exploration flag) still name existing plan.md behavior; also verify
  its override language interacts sanely with the new Step 5 (quickfix
  presents its own final summary; expected no edit, but confirm).

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass
- [ ] `wc -l plugins/tce/commands/plan.md` ≤ 450
- [ ] `grep -c 'references/plan-document-template.md' plugins/tce/commands/plan.md` ≥ 2 (Step 3 + Step 4); ≥ 1 in `work.md`
- [ ] `grep -c '## Important Guidelines\|## Common Patterns\|## Example Interaction Flow\|## Sub-task Spawning' plugins/tce/commands/plan.md` = 0
- [ ] `grep -n 'Step 3 (Plan Structure Development)\|Step 4 (Detailed Plan Writing)' plugins/tce/commands/work.md` still matches plan.md's headings
- [ ] AskUserQuestion nine-copy byte-identity check passes

#### Manual Verification

- [ ] Diff audit: no behavioral sentence lost (same standard as Phase 1)
- [ ] All internal step anchors in plan.md resolve to existing steps/numbers
- [ ] Step 5's new summary spec matches the ticket's acceptance criterion (decisions + rejected alternatives, riskiest assumptions, out-of-scope)
- [ ] Scratch-project smoke run of `/tce:plan` produces a plan document with the same structure as before, and the presented summary is decision-oriented

---

## Phase 3: Documentation, sibling-ticket note, validation

### Overview

Record the new convention where the repo documents itself, fix the rationale
that TP-0016 makes stale, and run the full validation pass.

### Changes Required

#### 1. `CLAUDE.md`

- **Layout tree**: add `references/` under `plugins/tce/` — "runtime reference
  files (document templates) commands Read at point of use; never copied into
  projects".
- **Convention note** (in or beside the core design rule): reference files are
  part of the command contract — editing one is editing the command, so the
  composite-tracking and TP-0013 rules apply to them; reads go through
  `${CLAUDE_PLUGIN_ROOT}/references/...` and must be instructed at the point
  of use (compaction does not restore earlier reads). Extend the
  composite-tracking rule's trigger list to name the reference files
  explicitly ("the research/plan templates — now in `plugins/tce/references/`").
- **AskUserQuestion rule rationale**: the parenthetical "because commands
  don't read plugin-internal markdown at runtime" is now false. Replace with
  the still-true reasons: cross-plugin references are forbidden (two of the
  nine copies are tmt's), and the guidelines govern every dialog site
  throughout a command body — they are not point-of-use material, which is
  what reference files are for. The nine-copy rule itself is unchanged.
  (The `/tce:refresh` section's "commands don't read each other's markdown"
  stays accurate — commands still never read other *commands'* files — leave
  it.)

#### 2. `.claude/tce/profile.md`

- Code-map row: `Runtime reference files (command templates) |
  plugins/tce/references/`.

#### 3. `plugins/tce/README.md`

- Update the plugin layout tree / feature description if it enumerates plugin
  directories (verify during implementation; add `references/` where the other
  dirs are listed).

#### 4. `thoughts/shared/tickets/TP-0022-sufficiency-criteria-sync-rule.md`

- Append a dated note: its Out-of-Scope assertion "commands can't read
  plugin-internal markdown at runtime" is outdated per TP-0016's research
  (docs sanction it; TP-0016 introduced the pattern). Its scope decision
  (keep the trio as synced copies) is unaffected.

#### 5. Full validation

- All three `claude plugin validate` runs.
- End-to-end smoke test per CLAUDE.md: `/plugin marketplace add .` + install
  both plugins in a scratch project, run `/tce:research` and `/tce:plan` on a
  small fake ticket, compare produced document structures against a pre-change
  document.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .`, `claude plugin validate ./plugins/tce`, `claude plugin validate ./plugins/tmt` all pass
- [ ] `grep -c "don't read plugin-internal markdown" CLAUDE.md` = 0 in the AskUserQuestion section (rationale replaced)
- [ ] `grep -c 'references/' CLAUDE.md .claude/tce/profile.md` ≥ 1 each

#### Manual Verification

- [ ] Scratch-project end-to-end run: research + plan documents structurally identical to pre-change output
- [ ] CLAUDE.md sync rules read coherently with the new convention (no contradiction between the core design rule, composite rule, and the new reference-file note)

---

## Testing Strategy

- **Manifest validation** after every phase (`claude plugin validate`).
- **Diff audits** are the primary behavioral test: for each deleted line,
  classify as extracted / restatement / folded — the classification standard
  in each phase's manual criteria.
- **End-to-end**: one scratch-project run after Phase 1 (research only) and a
  full research+plan run after Phase 3, comparing document structure to
  pre-change output.
- **Compaction behavior** cannot be practically forced in a smoke test; the
  mitigation is structural (point-of-use read instructions inside surviving
  steps), verified by inspection.

## Performance Considerations

None — reference files consume no context until read; reading them at 1–2
points of use adds one small Read each per invocation.

## Migration Notes

None — no consuming-project files change; `references/` is plugin-internal.
No version bump / release in this ticket's scope (release when the maintainer
next tags tce).

## References

- Ticket: `thoughts/shared/tickets/TP-0016-shrink-command-prompts-reference-files.md`
- Research: `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md`
- Origin review: `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` (Section 2, findings 1–2)
- Sync rules: `CLAUDE.md:177-188` (composite), `:201-214` (TP-0013), `:229-231` (refresh), `:244-246` (AskUserQuestion)
- Skills docs: https://code.claude.com/docs/en/skills (Skill content lifecycle; supporting files)
