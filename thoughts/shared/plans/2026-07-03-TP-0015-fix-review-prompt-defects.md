---
date: 2026-07-03
ticket: TP-0015
topic: "Fix the concrete command-prompt defects from the 2026-07 review"
research: thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md
git_commit: dd5a4ec
branch: main
repository: toby-plugins
status: draft
---

# Implementation Plan: TP-0015 — Fix the seven command-prompt defects from the 2026-07 review

## Overview

Fix the seven concrete defects the 2026-07-03 independent review found in the tce
command prompts: the `/tce:research` greet-and-wait bug, the dead HumanLayer-lineage
"thoughts sync"/`searchable/` machinery, `plan.md`'s numbering bugs, the wrong command
in `plan.md`'s example, the asserted-not-checked "Repository state guarantee", the
stray "plan mode" reference, and the unguarded `/simplify` dependency. Markdown-only,
surgical edits across six files in `plugins/tce/`; no scripts, manifests, or document
formats change.

## Current State Analysis

Per the research (`thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md`),
all seven defects are confirmed at HEAD `e27d4d1` (plugins unchanged since the review
commit, so all line numbers below are current):

- `research.md:123-131` greets and waits unconditionally, despite
  `argument-hint` frontmatter (`research.md:3`); `plan.md:176-202` has the
  parameter-check pattern to replicate.
- Dead machinery: `plan.md:565-569` ("Sync the thoughts directory" — no such
  mechanism exists); `thoughts-locator.md` describes `searchable/`, `global/`,
  `[username]/`, `prs/`, `decisions/`, `notes/` (lines 15-17, 24, 32, 38-52, 59,
  61-69, 79, 90-91, 94, 122, 133); `research.md:319` and `:458-464` carry
  `searchable/` path-correction rules. **Nothing in tce/tmt creates or relies on
  any of these** — the real tree is `thoughts/shared/{tickets,research,plans,
  reviews,mockups,discussions}` (created by `tmt/commands/init.md:138-139` and
  `tce/commands/init.md:373-383`).
- Numbering: `plan.md` Step 1's list has two item 5s (`:253`, `:260`); Step 5's
  list runs 1, 2, 2, 3, 4 (`:567/:571/:587/:594/:596`); cross-reference
  "proceed directly to step 5" (`:228`) is ambiguous.
- `plan.md:762` — Example Interaction Flow opens with `User: /tce:implement`.
- `implement.md:57` asserts the state guarantee; research frontmatter carries
  `git_commit`/`branch` (`research.md:256-258`) so a real check is possible.
  The adjacent re-read block (`implement.md:63`, from TP-0013) must survive.
- `plan.md:601` — sole "plan mode" mention.
- `quickfix.md:243` — sole `/simplify` reference in both plugins.

Composite blast radius (grep-verified): only defect 1 has live mirrors
(`work.md:69`, `quickfix.md:130-141` — both already override the greeting and
need no change); `work.md:189` anchors on plan.md's Step 3/Step 4 *names* (kept);
no composite mentions sync, the guarantee, plan mode, the example flow, or
`/simplify`.

## Desired End State

- `/tce:research TP-0042` (or a question argument) starts work immediately; the
  greeting appears only with no arguments — mirroring `plan.md`'s check.
- No tce file instructs a thoughts sync; `thoughts-locator.md` and `research.md`
  describe only the real `thoughts/shared/` tree (plus a note that projects may
  add their own subdirectories) — per the user's checkpoint decision.
- `plan.md` numbering is 1..6 in Step 1 and 1..4 in Step 5; all step
  cross-references resolve unambiguously; the example shows `/tce:plan`; no
  "plan mode" reference remains.
- `implement.md` instructs comparing the research frontmatter `git_commit`
  against HEAD, with spot-verification on mismatch and a same-session fast
  path; `work.md` Phase 4a carries a one-line mirror of the fast path — per
  the user's checkpoint decision.
- `quickfix.md` describes the cleanup intent with `/simplify` as an optional
  means, not a hard dependency.
- Verified by: `claude plugin validate` (marketplace + both plugins) passing,
  plus grep checks showing zero live occurrences of the dead concepts.

### Key Discoveries:

- Ticket-driven startup already lives *before* research.md's greeting
  ("Ticket Document Discovery" `research.md:76-100`, "Ticket Sufficiency
  Check" `:102-121`), so the with-argument branch only skips the greeting
  block; steps 1-10 (`:135-372`) are untouched.
- Removing plan.md's sync item simultaneously fixes half of defect 3 (Step 5's
  1,2,2,3,4 becomes 1,2,3,4 after renumbering).
- `research.md:453-457` ("Critical ordering") references process steps by
  number — deleting the `:458-464` bullet block doesn't renumber those steps,
  so no knock-on edits there.
- The plan template has no frontmatter, so the state check anchors on the
  research document's `git_commit` only (document formats are frozen for this
  ticket).

## What We're NOT Doing

- No shortening/restructuring of command bodies or moving templates to
  reference files (TP-0016).
- No frontmatter/machinery adoption — `disable-model-invocation`,
  `allowed-tools`, agent models (TP-0017).
- No changes to the "documentarian, not critic" rules (TP-0018).
- No changes to the workflow chain, document formats (no plan frontmatter),
  or ticket structure.
- No edits to historical records in `thoughts/` that mention the dead
  concepts (ticket TP-0015, the review) — they document the defects.

## Implementation Approach

Five phases grouped by file/theme so each phase is one coherent, conventional
commit; each phase runs `claude plugin validate` plus targeted grep checks.
Composite mirrors are updated in the same phase (commit) as the single-step
command they mirror, per the CLAUDE.md composite rule. Surgical edits only —
preserve each command's structure and altitude.

## Phase 1: research.md argument branch (defect 1)

### Overview

Make `/tce:research` begin immediately when invoked with a ticket reference or
question, mirroring `plan.md:176-202`.

### Changes Required:

#### 1. research.md — Initial Setup becomes a parameter check

**File**: `plugins/tce/commands/research.md`
**Changes**: Replace the "Initial Setup:" block (lines 123-131) with a
plan.md-style branch:

````markdown
## Initial Setup:

When this command is invoked:

1. **Check if parameters were provided**:

   - If a ticket reference or research question was provided as a parameter,
     skip the default message and begin immediately: treat it as the research
     query — for a ticket reference, run Ticket Document Discovery and the
     Ticket Sufficiency Check (above) first, then proceed with the steps below
   - Immediately read any files the query mentions FULLY

2. **If no parameters provided**, respond with:

```
I'm ready to research the codebase. Please provide your research question or area of interest, and I'll analyze it thoroughly by exploring relevant components and connections.

Tip: You can also invoke this command with a ticket ID or question directly: `/tce:research [PREFIX]-0001`
```

Then wait for the user's research query.
````

Adjust the following heading (line 133) from "Steps to follow after receiving
the research query:" to "Steps to follow once you have the research query
(from the invocation parameter or the user's message):" so the steps read
correctly for both paths.

#### 2. Composite check (no edit expected)

**Files**: `plugins/tce/commands/work.md`, `plugins/tce/commands/quickfix.md`
**Changes**: None — `work.md:69` ("Do NOT print 'I'm ready to research'") and
`quickfix.md:130-141` already override the greeting and are consistent with
the new branch. Re-read both passages after editing to confirm no
contradiction was introduced.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes (repo root)
- [x] `grep -n "Check if parameters were provided" plugins/tce/commands/research.md` — one hit

#### Manual Verification:

- [x] research.md's with-argument path reaches the sufficiency check and the
      numbered steps without any wait instruction
- [x] The no-argument greeting is byte-identical in intent to before (plus the
      Tip line); `work.md`/`quickfix.md` passages read consistently

---

## Phase 2: Remove dead thoughts machinery from thoughts-locator.md and research.md (defect 2, part 1)

### Overview

Replace the fictional directory taxonomy with the real canonical tree +
extensibility note (user's checkpoint decision); delete `searchable/`
path-correction rules.

### Changes Required:

#### 1. thoughts-locator.md — real tree, no path correction

**File**: `plugins/tce/agents/thoughts-locator.md`
**Changes**:

- Lines 15-17: replace the `[username]`/`global`/`searchable` bullets with
  checks of the real subdirectories (e.g. "Check thoughts/shared/ for
  research, plans, tickets, reviews, mockups, and discussions").
- Line 24: "PR descriptions (in prs/)" — remove or replace with a real
  category (e.g. reviews).
- Line 32: drop "Correct searchable/ paths to actual paths".
- Lines 38-52: replace the Directory Structure diagram with:

```
thoughts/
└── shared/           # Team-shared documents
    ├── tickets/      # Ticket documents
    ├── research/     # Research documents
    ├── plans/        # Implementation plans
    ├── reviews/      # Code review documents
    ├── mockups/      # Design explorations (+ DECISION.md)
    └── discussions/  # Discussion & trade-off documents
```

  followed by one note line: consuming projects may add their own
  subdirectories under `thoughts/` — search whatever exists.
- Lines 59, 61-69: delete the "Search in searchable/…" bullet and the whole
  Path Correction block (no path rewriting is needed anymore).
- Lines 79, 90-91, 94: rewrite output-format examples to use real paths
  (`thoughts/shared/research/…`, `thoughts/shared/discussions/…`,
  `thoughts/shared/reviews/…`); drop the `decisions/`/`notes/` examples.
- Line 122: drop "Fix searchable/ paths…".
- Line 133: drop "beyond removing 'searchable/'" (keep "Don't change
  directory structure" if the sentence still carries meaning, else remove).

#### 2. research.md — drop searchable/ rules

**File**: `plugins/tce/commands/research.md`
**Changes**:

- Line 319 (template note "Paths exclude 'searchable/' even if found there"):
  remove the note line.
- Lines 458-464 (the "Path handling" bullet block): replace with a single
  bullet: "**Path handling**: Document `thoughts/` paths exactly as they
  exist on disk so references are editable and navigable."

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -rn "searchable" plugins/` — zero hits
- [x] `grep -rn "thoughts/global\|\[username\]/\|shared/prs\|shared/decisions" plugins/` — zero hits

#### Manual Verification:

- [x] thoughts-locator.md's tree matches what `tce/init.md:373-383` +
      `tmt/init.md:138-139` actually scaffold, plus the extensibility note
- [x] No remaining instruction tells any agent to rewrite or "correct" paths

---

## Phase 3: plan.md cleanup — sync step, numbering, example, plan mode (defects 2 part 2, 3, 4, 6)

### Overview

All plan.md-local fixes in one commit: remove the sync step, fix both
numbering sequences and the ambiguous cross-reference, correct the example
command, drop the plan-mode phrase.

### Changes Required:

#### 1. plan.md — Step 5: remove sync, renumber

**File**: `plugins/tce/commands/plan.md`
**Changes**:

- Rename heading `### Step 5: Sync and Review` (line 565) to
  `### Step 5: Review and Commit` (no composite references Step 5 by name;
  `work.md:189` anchors only on Step 3/Step 4 names, which are unchanged).
- Delete item "1. **Sync the thoughts directory**:" and its bullet (lines
  567-569).
- Renumber the remaining list 2,2,3,4 → 1 (present draft location),
  2 (iterate), 3 (continue refining), 4 (commit) — the commit item keeps
  number 4 by coincidence of the two removals/duplicates; verify the final
  sequence reads 1,2,3,4.

#### 2. plan.md — Step 1: fix duplicate item 5

**File**: `plugins/tce/commands/plan.md`
**Changes**:

- Renumber the second item 5 ("Present informed understanding and focused
  questions", line 260) to 6.
- Update the cross-reference at line 228 to "Proceed directly to step 6
  (present understanding and questions)".
- Leave "SKIP steps 3-4 below" (`:225`) and "Proceed with steps 3-4 below"
  (`:232`) untouched — they already resolve unambiguously.

#### 3. plan.md — example command and plan mode

**File**: `plugins/tce/commands/plan.md`
**Changes**:

- Line 762: `User: /tce:implement` → `User: /tce:plan`.
- Line 601: delete the sentence "Do NOT leave plan mode to begin coding."
  (the surrounding stop-rule — "Your job ends here… Do NOT start
  implementing the plan… The user will start the implementation themselves"
  — stays verbatim).

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -n "plan mode" plugins/tce/commands/plan.md` — zero hits
- [x] `grep -n "Sync the thoughts\|Sync and Review" plugins/tce/commands/plan.md` — zero hits
- [x] `grep -rn "tce:implement" plugins/tce/commands/plan.md` — no hit inside the Example Interaction Flow block (hits elsewhere, e.g. the "Next command" hint, are correct)

#### Manual Verification:

- [x] Step 1's list reads 1,2,3,4,5,6; Step 5's list reads 1,2,3,4
- [x] Every "step N" cross-reference in plan.md (`:96,225,228,232,324`)
      resolves to exactly one target
- [x] `work.md:189`'s "Step 3 (Plan Structure Development) and Step 4
      (Detailed Plan Writing)" anchors still match plan.md's headings

---

## Phase 4: implement.md repository state check + work.md fast-path mirror (defect 5)

### Overview

Invert the asserted guarantee into an actual check with a same-session fast
path; add the one-line mirror in `work.md` Phase 4a (user's checkpoint
decision). Same commit for both files (composite rule).

### Changes Required:

#### 1. implement.md — replace the guarantee with a check

**File**: `plugins/tce/commands/implement.md`
**Changes**: Replace the "**Repository state guarantee:** …" paragraph
(line 57) with:

```markdown
**Repository state check:** The research document records the commit it was
written at (`git_commit` and `branch` in its frontmatter). Compare that
against the current HEAD (`git rev-parse HEAD`). If they match, the context
documents reflect the current codebase. If they differ, the repository has
moved on since research: run `git diff --stat <research_commit>..HEAD` to see
which files changed, and spot-verify what the research and plan claim about
any of those files before relying on it. Fast path: when the research and
plan were produced earlier in this same session (e.g. by `/tce:work` or
`/tce:quickfix`) and HEAD has only advanced by this session's own commits,
the check is trivially satisfied — skip the spot-verification.
```

Keep the entire re-read block (line 63, TP-0013) and the source-file
guidance below it verbatim.

#### 2. work.md — Phase 4a fast-path line

**File**: `plugins/tce/commands/work.md`
**Changes**: In Phase 4a (lines 221-226), insert after step 1 (the re-read
step):

```markdown
2. The repository state check from `/tce:implement` is trivially satisfied
   here — research and plan were produced earlier in this same session; skip
   the spot-verification
```

and renumber the following steps (status file check → 3, resume → 4, create →
5, todo list → 6).

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -n "Repository state guarantee" plugins/tce/commands/*.md` — zero hits
- [x] `grep -n "Repository state check" plugins/tce/commands/implement.md` — one hit

#### Manual Verification:

- [x] implement.md's re-read block (TP-0013) is unchanged; source-file "do
      not re-read" guidance intact
- [x] work.md Phase 4a numbering is sequential after the insertion

---

## Phase 5: quickfix.md — unguard /simplify (defect 7)

### Overview

Describe the cleanup intent; make the skill optional.

### Changes Required:

#### 1. quickfix.md — Important Rules item 6

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: Replace line 243 with:

```markdown
6. **Clean up before the final implementation commit** if you iterated through
   multiple approaches: remove leftover artifacts of abandoned attempts (dead
   code, unused helpers, stale comments). If a simplify/cleanup skill is
   available in your environment, you may use it; otherwise review the diff
   yourself.
```

`work.md` has no counterpart (grep-verified) and gets no edit.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `grep -rn "/simplify" plugins/` — zero hits

#### Manual Verification:

- [ ] The rule still fires at the same moment (before the final
      implementation commit) with the same trigger (multiple approaches)

---

## Testing Strategy

### Automated:

- After every phase: `claude plugin validate .`,
  `claude plugin validate ./plugins/tce`, `claude plugin validate ./plugins/tmt`
  (profile.md test commands; tmt validate is cheap insurance even though no
  tmt file changes).
- Final sweep (after Phase 5), expecting zero live hits:
  `grep -rn "searchable\|thoughts/global\|\[username\]/\|shared/prs\|Sync the thoughts\|plan mode\|/simplify" plugins/`

### Manual Testing Steps:

1. Read the rewritten research.md Initial Setup top-to-bottom simulating
   `/tce:research TP-0042` — confirm no path waits for input.
2. Read plan.md Steps 1 and 5 confirming clean numbering and that each
   cross-reference (`:96,225,228,232,324` pre-edit positions) points to
   exactly one target.
3. Read implement.md's Context Documents section confirming check + fast
   path + intact TP-0013 re-read block.
4. Re-read `work.md` Phases 1a/3a/4a and `quickfix.md` Phases 3-5 end-to-end
   against the edited single-step commands (composite lock-step rule).

## Performance Considerations

None — markdown-only prompt edits; net token count of the prompts decreases
(dead machinery removed).

## Migration Notes

None — no project config, document format, or scaffolding changes; nothing
for init/refresh idempotency lists.

## References

- Original ticket: `thoughts/shared/tickets/TP-0015-fix-review-prompt-defects.md`
- Related research: `thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md`
- Source review: `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` (Section 1)
- Composite rule: `CLAUDE.md` — "Composite commands must track the single-step commands"
- Re-read rule precedent: `thoughts/shared/plans/2026-06-18-TP-0013-explicit-context-document-reads.md`
