---
date: 2026-07-03T14:10:19Z
git_commit: e27d4d17270df38398e6c6c22d698d00571a4136
branch: main
repository: toby-plugins
topic: "TP-0015: Fix the concrete command-prompt defects from the 2026-07 review"
tags: [research, codebase, tce-commands, research-md, plan-md, implement-md, quickfix-md, work-md, thoughts-locator]
status: complete
last_updated: 2026-07-03
---

# Research: TP-0015 — Fix the concrete command-prompt defects from the 2026-07 review

**Date**: 2026-07-03T14:10:19Z
**Git Commit**: e27d4d17270df38398e6c6c22d698d00571a4136 (e27d4d1)
**Branch**: main
**Repository**: toby-plugins

## Research Question

Verify the seven concrete defects from the 2026-07-03 independent review
(`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`,
Section 1) against current HEAD, confirm nothing in tce/tmt still creates or
relies on `thoughts/searchable/`, `thoughts/global/`, `thoughts/[username]/`,
or `prs/`, and enumerate the exact edit sites for each defect including every
composite mirror (`work.md`, `quickfix.md`).

## Summary

All seven defects are **confirmed at current HEAD** with exact line evidence.
`git diff 5c622ef..HEAD -- plugins/` is empty — no plugin file changed since
the review commit, so the review's line numbers are still accurate.

Answers to the ticket's three research questions:

1. **Nothing in tce or tmt creates or relies on the dead directories.** The
   only scaffolding that touches `thoughts/` is `/tce:init`
   (`plugins/tce/commands/init.md:373-383` — creates
   `thoughts/shared/{research,plans,reviews,mockups,discussions}`) and
   `/tmt:init` (`plugins/tmt/commands/init.md:138-139` — creates
   `thoughts/shared/tickets`). `searchable/`, `global/`, `[username]/`,
   `prs/`, `decisions/`, and `notes/` appear **only** as descriptions in
   `thoughts-locator.md` and `research.md` — no script, hook, or template
   creates them. The references can be deleted and the locator's tree
   replaced with the real canonical tree (see Detailed Findings, defect 2).
2. **Exact edit sites enumerated** per defect below, with composite mirrors.
   Only defect 1 (research greeting) has a live composite mirror that needs
   text awareness (`work.md:69`, `quickfix.md:130-141` already override the
   greeting — they need no change, but must not be contradicted). Defects
   2–7 have **no** mirror in the composites (confirmed by grep): no sync,
   no state-guarantee restatement, no plan-mode, no example-flow, and no
   `/simplify` outside `quickfix.md:243`.
3. **The state-guarantee replacement needs no repeated check in the
   composites**, but `work.md` Phase 4a is the natural place for a one-line
   same-session fast path ("research/plan were produced in this session at
   the current HEAD — skip the drift check"), since `implement.md:63`
   already names the composites in the adjacent re-read block. Details in
   defect 5.

## Detailed Findings

### Defect 1 — `research.md` greets-and-waits even with a ticket argument

- `plugins/tce/commands/research.md:123-131` — "Initial Setup:" says
  unconditionally: respond "I'm ready to research the codebase…" then "wait
  for the user's research query". No argument branch exists, although the
  frontmatter declares `argument-hint: "[ticket-id | research question]"`
  (`research.md:3`).
- The process steps are framed around a user message, not an argument:
  `research.md:133` "Steps to follow after receiving the research query".
- **The pattern to replicate** is `plan.md:176-202` ("Initial Response"):
  step 1 "Check if parameters were provided" (skip default message, read
  provided files fully, begin), step 2 "If no parameters provided, respond
  with: …" then wait. Note `plan.md:198-199` also shows a "Tip:" advertising
  direct-invocation forms in the no-args message — research.md's no-args
  greeting could do the same.
- Structural note: the ticket-driven startup already lives *before* the
  greeting — "Ticket Document Discovery" (`research.md:76-100`) and "Ticket
  Sufficiency Check" (`research.md:102-121`, sequenced "after reading the
  ticket … before spawning any research agents" at `research.md:104`). The
  with-argument path skips only the greeting block (123-131); steps 1-10
  (`research.md:135-372`) stay as-is.
- **Composite mirrors**: `work.md:69` ("Do NOT print 'I'm ready to research'
  and wait") and `quickfix.md:130-141` (inline re-description, "no user
  interaction") already override the greeting. They stay correct once
  research.md branches on arguments; no edit strictly required, though the
  work.md override becomes partially redundant (harmless — it also
  suppresses the greeting semantics for the composite's own flow).

### Defect 2 — Dead "thoughts sync" and `searchable/` machinery

**The sync step** (sole occurrence, no mechanism exists anywhere in either
plugin — no script, no hook):

- `plugins/tce/commands/plan.md:565-569` — "### Step 5: Sync and Review" /
  "1. **Sync the thoughts directory**:" / "- This ensures the plan is
  properly indexed and available". Removing item 1 also fixes half of the
  Step 5 numbering bug (defect 3) and suggests renaming the heading (e.g.
  "Step 5: Review" or "Present and Commit").

**Dead directory references** (complete list; nothing else in the repo's
live files references them):

- `plugins/tce/agents/thoughts-locator.md`:
  - `:15-17` — "Check thoughts/[username]/ … thoughts/global/ … Handle
    thoughts/searchable/"
  - `:24` — "PR descriptions (in prs/)"
  - `:32` — "Correct searchable/ paths to actual paths"
  - `:38-52` — the Directory Structure diagram (shared/{research,plans,
    tickets,prs}, [username]/{tickets,notes}, global/, searchable/)
  - `:59` — "Search in searchable/ but report corrected paths"
  - `:61-69` — Path Correction block with three searchable→actual examples
  - `:79`, `:90-91`, `:94` — output-format examples using
    `thoughts/[username]/…`, `thoughts/shared/decisions/…` (a `decisions/`
    dir no init creates), `thoughts/shared/prs/…`
  - `:122` — "Fix searchable/ paths"
  - `:133` — "Don't change directory structure beyond removing 'searchable/'"
- `plugins/tce/commands/research.md`:
  - `:319` — template note "Paths exclude 'searchable/' even if found there"
  - `:458-464` — the "Path handling" bullet block (hard links,
    searchable-stripping rules, `prs/` example)

**The real canonical tree** (what the descriptions should be replaced with):

```
thoughts/shared/
├── tickets/       (/tmt:init; tmt scripts/hooks, tce ticket/research/plan)
├── research/      (/tce:init; research, plan, review, composites)
├── plans/         (/tce:init; plan, implement, review, composites)
├── reviews/       (/tce:init; review.md)
├── mockups/       (/tce:init; design_explore, plan, work, implement)
└── discussions/   (/tce:init; discuss.md)
```

Creation sites: `plugins/tce/commands/init.md:373-383` and
`plugins/tmt/commands/init.md:138-139`. Confirming docs:
`plugins/tce/README.md:166,169`. `plugins/tce/scripts/ticket.sh:3-29` globs
the whole `thoughts/` tree by ticket ID — path-agnostic, unaffected.
`thoughts-locator.md` should stay generic where reasonable (consuming
projects may add their own subdirectories), but must not instruct searching
directories that don't exist or "correcting" paths.

**Do not clean**: hits in `thoughts/shared/tickets/TP-0015-*.md` and
`thoughts/shared/reviews/2026-07-03-*.md` are historical records of these
very defects.

### Defect 3 — `plan.md` numbering bugs

- Step 1's internal list runs 1 (`:208`), 2 (`:218`), 3 (`:234`), 4 (`:247`),
  **5 (`:253` "Analyze and verify understanding")**, **5 (`:260` "Present
  informed understanding and focused questions")**.
- Step 5's list runs **1 (`:567` sync), 2 (`:571` present), 2 (`:587`
  iterate), 3 (`:594` continue refining), 4 (`:596` commit)**. Removing the
  sync item (defect 2) plus renumbering yields a clean 1-2-3-4.
- **Cross-references that must resolve after renumbering** (all inside
  plan.md; the "step N" references at `:225/:228/:232` refer to Step 1's
  *internal list items*, not the `###` step headings):
  - `:96` — "Proceed directly to **Step 3 (Plan Structure Development)**"
  - `:225` — "**SKIP steps 3-4 below** (spawning research agents)"
  - `:228` — "Proceed directly to step 5 (present understanding and
    questions)" — currently ambiguous between the two item-5s; the
    parenthetical identifies the second (`:260`)
  - `:232` — "Proceed with steps 3-4 below to gather context"
  - `:324` — "Skip this entire step and proceed to Step 3"
- **Composite anchor**: `work.md:189` references plan.md by step-heading
  name — "Follow the plan creation process from `/tce:plan` Step 3 (Plan
  Structure Development) and Step 4 (Detailed Plan Writing)". Renumbering
  the *internal lists* doesn't disturb this; renaming the Step 5 heading
  doesn't either (work.md never references Step 5 by name).

### Defect 4 — Wrong command in `plan.md`'s example

- `plugins/tce/commands/plan.md:759-773` — "## Example Interaction Flow"
  opens with `User: /tce:implement` (`:762`) while the assistant answers
  with the plan command's greeting. One-word fix: `/tce:plan`. No composite
  references this example (grep-confirmed).

### Defect 5 — "Repository state guarantee" asserted, not checked

- `plugins/tce/commands/implement.md:57` — asserts "The research and plan
  were executed on the exact same state of the repository … No other
  processes modified files between steps 2, 3, and 4", framing verification
  as optional ("you can verify … if needed, but under normal circumstances
  …"). False in general: plans get implemented in later sessions after
  intervening commits.
- The research frontmatter **does** carry what a check needs:
  `git_commit` and `branch` (`research.md:256-258`, gathered via
  `git rev-parse HEAD` at `research.md:236`). The **plan template has no
  frontmatter at all** (`plan.md:461-563`) — so the comparison anchor is
  the research document only. (Adding plan frontmatter is out of scope —
  "any change to the document formats" is excluded by the ticket.)
- Ticket-mandated replacement shape: compare research `git_commit` against
  current HEAD; if they differ, spot-verify research claims about files
  changed since (e.g. `git diff --stat <research_commit>..HEAD` limited to
  files the research/plan reference) — while keeping a fast path for
  same-session composite runs.
- **Same-session fast path**: neither composite restates the guarantee
  (grep-confirmed). `implement.md:63` (the adjacent re-read block) already
  names `/tce:work` and `/tce:quickfix` for the re-read rule, so the
  natural fast-path wording lives in implement.md itself ("when research
  and plan were produced earlier in this same session and HEAD hasn't
  moved, the check is trivially satisfied — skip the spot-verification").
  `work.md` Phase 4a (`:221-226`) is the mirror site if the composite
  should say it too; `quickfix.md:184-185` inherits via Skill delegation
  and needs nothing beyond what implement.md says.
- History note: TP-0013's plan (Phase 2, item 3) already "reconciled" this
  paragraph so it wouldn't read as license to skip document re-reads —
  the re-read rule at `implement.md:63` must survive the rewrite intact.

### Defect 6 — Stray "plan mode" reference

- `plugins/tce/commands/plan.md:601` — "**CRITICAL: Your job ends here.**
  Do NOT start implementing the plan. Do NOT leave plan mode to begin
  coding. …" — the *only* "plan mode" occurrence in the file
  (grep-confirmed). The surrounding stop-rule is correct and should stay;
  only the "plan mode" phrase imports a foreign concept. The composites
  deliberately chain past this rule (`work.md:59,211`; quickfix proceeds
  unconditionally) without citing it — no mirror impact.

### Defect 7 — `quickfix.md` depends on `/simplify`

- `plugins/tce/commands/quickfix.md:243` — Important Rules item 6: "**Run
  `/simplify` before the final implementation commit** if you iterated
  through multiple approaches during implementation." Sole occurrence of
  "simplify" in both plugins (grep-confirmed); `/simplify` is a harness
  built-in, not guaranteed present. Ticket allows either a guard ("if a
  simplify skill is available…") or describing the intent (remove leftover
  iteration artifacts / dead code from abandoned approaches). `work.md` has
  no counterpart and needs none.

## Code References

- `plugins/tce/commands/research.md:3` — `argument-hint` frontmatter
- `plugins/tce/commands/research.md:76-121` — ticket discovery + sufficiency check (pre-greeting)
- `plugins/tce/commands/research.md:123-131` — unconditional greeting (defect 1)
- `plugins/tce/commands/research.md:319` — "searchable/" template note (defect 2)
- `plugins/tce/commands/research.md:453-457` — "Critical ordering" references steps by number
- `plugins/tce/commands/research.md:458-464` — searchable/ path-handling block (defect 2)
- `plugins/tce/commands/plan.md:176-202` — parameter-check pattern to replicate
- `plugins/tce/commands/plan.md:208-260` — Step 1 list with duplicate item 5 (defect 3)
- `plugins/tce/commands/plan.md:96,225,228,232,324` — step cross-references (defect 3)
- `plugins/tce/commands/plan.md:565-599` — Step 5 "Sync and Review", list 1,2,2,3,4 (defects 2+3)
- `plugins/tce/commands/plan.md:601` — "plan mode" (defect 6)
- `plugins/tce/commands/plan.md:759-773` — example flow with `/tce:implement` (defect 4)
- `plugins/tce/commands/implement.md:53-57` — Repository state guarantee (defect 5)
- `plugins/tce/commands/implement.md:63` — composite-aware re-read block (must survive)
- `plugins/tce/commands/quickfix.md:243` — `/simplify` (defect 7)
- `plugins/tce/commands/work.md:67-91` — Phase 1a/1b research overrides (defect 1 mirror)
- `plugins/tce/commands/work.md:189-212` — Phase 3 planning mirror (anchors on Step 3/4 names)
- `plugins/tce/commands/work.md:221-226` — Phase 4a setup (defect 5 fast-path site)
- `plugins/tce/agents/thoughts-locator.md:15-17,24,32,38-52,59,61-69,79,90-94,122,133` — dead directory machinery (defect 2)
- `plugins/tce/commands/init.md:373-383` — real thoughts/ scaffolding (tce)
- `plugins/tmt/commands/init.md:138-139` — real thoughts/ scaffolding (tmt)

## Architecture Documentation

- **Composite-tracking rule** (CLAUDE.md): changes to single-step commands
  must be checked against `work.md`/`quickfix.md` in the same commit. For
  this ticket the grep-verified blast radius is small: only defect 1 has
  live mirrors, and they already implement the desired behavior; defect 5's
  fast path optionally touches `work.md:222-226`.
- **quickfix delegates, work re-describes**: `quickfix.md` invokes the
  `tce:plan`/`tce:implement` skills (`quickfix.md:160,184`) so it inherits
  plan/implement changes automatically, but re-describes *research* inline
  (`quickfix.md:126-153`). `work.md` re-describes all phases inline.
- **Document formats are frozen for this ticket** (Out of Scope): the fix
  for defect 5 must use the existing research frontmatter, not add plan
  frontmatter.
- **research.md's step numbering is itself referenced** at
  `research.md:453-457` ("Follow the numbered steps exactly", naming steps
  1/4/5/6) — deleting the `:458-464` path-handling bullet doesn't renumber
  the steps, but any restructuring of the numbered list would need to touch
  those references too.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` —
  Section 1: the seven defects with original file:line evidence (review ran
  at 5c622ef; plugins unchanged since).
- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md`
  — documents the state-guarantee wording's location and rationale.
- `thoughts/shared/plans/2026-06-18-TP-0013-explicit-context-document-reads.md`
  — Phase 2 reconciled `implement.md:55-66` for the re-read rule; the
  defect-5 rewrite must not undo that reconciliation.

## Related Research

- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md`

## Open Questions

None with material impact; two small drafting decisions are safely
resolvable at planning time from the ticket's acceptance criteria:

1. Whether `thoughts-locator.md` describes the concrete canonical tree or a
   generalized "whatever exists under thoughts/" (the ticket allows either;
   the locator serves consuming projects, which may add their own
   subdirectories — a hybrid "canonical tree + note that projects may add
   more" fits both).
2. Whether the defect-5 same-session fast path is stated only in
   `implement.md` or also mirrored as a sentence in `work.md` Phase 4a
   (the ticket's research question 3; implement.md-only is sufficient since
   work.md delegates the guarantee semantics, but a one-line mirror is
   cheap and consistent with how Phase 4a already restates re-reads).
