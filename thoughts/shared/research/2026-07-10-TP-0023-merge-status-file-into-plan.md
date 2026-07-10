---
date: 2026-07-10T08:56:29Z
git_commit: df5f5b198cdeee5e77ef835e054627fe07d5ee1f
branch: main
repository: toby-plugins
topic: "TP-0023: Merge implementation status tracking into the plan (drop .status.md)"
tags: [research, codebase, tce, implement, work, quickfix, status-file, plan-template]
status: complete
last_updated: 2026-07-10
---

# Research: TP-0023 — Merge implementation status tracking into the plan (drop `.status.md`)

**Date**: 2026-07-10T08:56:29Z
**Git Commit**: df5f5b198cdeee5e77ef835e054627fe07d5ee1f
**Branch**: main
**Repository**: toby-plugins

## Research Question

`/tce:implement` tracks progress in two places: checkboxes in the plan file and a
parallel `.status.md` file. TP-0023 wants the plan file to become the single record
of implementation progress, with a compact per-phase implementation log replacing
the separate status file. Research must map: every place the status-file convention
is defined or mirrored, the resume/completion/blocker mechanics that must be
preserved, what else (if anything) reads status files, the plan template structure
the log must fit into, and the backward-compatibility situation for existing
`.status.md` files.

## Summary

The status-file convention is defined in exactly one place —
`plugins/tce/commands/implement.md` (sections "Status File Tracking", "Getting
Started", "Verification Approach", "Committing Each Phase", "Plan-Compliance Gate",
"Resuming Work") — and mirrored in four others: `work.md` Phase 4 (inline
re-description), `quickfix.md` Phase 5 (one passing sentence), the tce README's
"See it work" tree (one line), and **`CLAUDE.md`'s TP-0020 gate section** (one
parenthetical the ticket's References list does not mention). No other command,
agent, reference file, or script reads or mentions status files — notably
`/tce:review`, `/tce:plan`, `/tce:research`, both reference templates, and the
`plan-compliance-checker` agent are all clean (the agent receives the diff as text;
it never reads the status file itself).

The mechanics that must survive the merge are: (1) the `**Base commit**` hash,
recorded at first-phase start and consumed by the Plan-Compliance Gate's diff
command (with an existing `git log --grep` fallback for files that lack it);
(2) resume logic, which today works **exclusively** from the status file's
per-phase `**Status**` fields — plan checkboxes are written during implementation
but never consulted at resume time; (3) per-phase records of steps, issues →
resolutions, verification results, and the phase's commit hash; (4) blocker
recording (rule: write the status file even when blocked, so the next session
knows). Dogfooded status files additionally record the gate verdict and the ticket
transition, beyond what the template prescribes.

The plan template (`plan-document-template.md`) has no frontmatter, uses H2 phases
with H3 `Overview`/`Changes Required:`/`Success Criteria:` subsections and H4
verification subsections; its only checkboxes are the Automated/Manual success
criteria. It contains no notion of post-planning updates today, so the in-plan log
is a new structural element the template's downstream-consumer header comment must
acknowledge.

Backward compatibility is currently moot inside this repo: all 20 existing
`.status.md` files belong to Done tickets, and none of the three open tickets
(TP-0010, TP-0023, TP-0024) has a plan yet. The general case (consuming projects
with in-flight implementations) is what planning must decide.

## Detailed Findings

### 1. `implement.md` — the authoritative status-file specification

All mechanics live in `plugins/tce/commands/implement.md` (359 lines):

**Naming & creation** (`## Status File Tracking`, lines 91–97; `### Status File
Rules` rule 4, lines 137–139):

- "Every implementation session is tracked in a status file that lives alongside
  the plan file. The status file has the same base name as the plan but ends in
  `.status.md`." (line 93)
- Created "when starting the first phase", recording `git rev-parse HEAD` as the
  `**Base commit**` — "the tip before any implementation commit — the
  Plan-Compliance Gate diffs from it" (lines 137–139). The frontmatter
  `allowed-tools` (line 4) pre-authorizes `Bash(git rev-parse:*)` for this.

**Format** (`### Status File Format`, lines 99–130) — a fenced template:

- Title: `# Implementation Status: [PREFIX]-XXXX — Short Title` (line 102)
- `**Base commit**` field with inline purpose note (lines 104–105)
- Per phase (`## Phase N: Phase Title`, lines 107–124):
  - `- **Status**: ✅ Complete | ⚠️ Partial | ❌ Blocked`
  - `- **Started**` / `- **Completed**` timestamps
  - `### Steps Performed` (numbered list)
  - `### Issues Encountered` (`- Issue description → Resolution applied`)
  - `### Verification` (checkmark lines)
  - `### Commit` (`` `abc1234` <commit subject> ``)
- Phases separated by `---` (line 126).

**Update points**:

- Rule 5 (line 140): write after every phase (steps, issues, resolutions,
  verification results, commit hash).
- Rule 6 (line 141): "**Write to the status file when encountering blockers** —
  record the issue even if you can't resolve it, so the next session knows what
  happened."
- `### Writing Status Updates` (lines 143–150): the include-list, with status
  values ✅ Complete / ⚠️ Partial / ❌ Blocked.
- `## Verification Approach` bullet (line 226): "Update the status file with the
  phase results".
- `## Committing Each Phase` (line 240): "Record the resulting commit hash in the
  status file's `### Commit` slot for the phase."

**Resume & completion detection** (`### Status File Rules` 1–3, lines 134–136;
`## Getting Started`, lines 152–167; `## Resuming Work`, lines 336–359):

- Check for the status file before any work (rule 1; Getting Started line 157).
- All phases ✅ Complete → stop, tell the user the plan is fully implemented, list
  what was done (rule 2). **Completion is detected from the status file's phase
  `**Status**` fields, not from plan checkboxes.**
- Incomplete phases → print done-vs-remaining summary, continue from the first
  incomplete phase (rule 3; verbatim summary example at lines 343–352 using
  ✅ / ⚠️ / ⬚ symbols).
- Line 338: "**The status file is the authoritative record of implementation
  progress.**" ⚠️ Partial → read details of what was done/remains (line 354);
  ❌ Blocked → reassess the blocker (line 355); "Trust completed phases — only
  re-verify if something seems off" (line 356).
- Plan checkboxes play **no role** in resume; they are only written during
  implementation.

**Plan-checkbox writes** (the other half of the double bookkeeping):

- `## Implementation Philosophy` (line 199): "Update checkboxes in the plan as you
  complete sections".
- `## Verification Approach` (lines 224–225): "Update your progress in both the
  plan and your todos" / "Check off completed items in the plan file itself using
  Edit".

**Plan-Compliance Gate dependency** (`## Plan-Compliance Gate`, lines 264–308;
step 2 at lines 279–284, verbatim):

> **Assemble the diff.** Use the `**Base commit**` recorded in the status file.
> Compute the implementation diff with
> `git diff <base> -- . ':(exclude)thoughts/'` plus a `git diff <base> --stat`
> summary. If no base commit is recorded (older or resumed status file), fall
> back to `git log --grep="[PREFIX]-XXXX" --format=%H | tail -1` and diff from
> that commit's parent.

The `':(exclude)thoughts/'` pathspec already excludes the status file (and plan/
research/ticket) from the diff the checker sees, so moving the log into the plan
does not change what the gate's agent receives. The existing fallback is the one
place the spec already acknowledges a status file without a `**Base commit**`.

**Blocker/mismatch presentation** (`## Implementation Philosophy`, lines 203–215):
the STOP-and-report fenced template (`Issue in Phase [N]: / Expected: / Found: /
Why this matters: / How should I proceed?`); the gate's "not met" branch reuses it
(lines 297–301). `## If You Get Stuck` (lines 326–334) does not mention the status
file.

**Commit interaction**: no instruction stages or excludes the status file
explicitly; staging is described as "the files changed in this group (plus the
ticket file if its status changed)" (line 237). In practice the status files are
committed (all 20 are tracked in git).

**Ticket transitions** (lines 310–324): the done transition requires "ALL phases
are complete and verified _and the Plan-Compliance Gate has passed_" — indirectly
coupled to the status file via the gate's base commit.

### 2. Composite mirrors — `work.md` re-describes, `quickfix.md` mentions

`plugins/tce/commands/work.md` (Phase 4):

- Line 226: "Check for existing status file (same base name, `.status.md`
  extension)" — the only place outside implement.md naming the extension.
- Line 227: resume "from where it left off"; line 228: "If no status file, create
  one when starting the first phase".
- Line 239: "Update the status file after every phase"; line 240: "Update
  checkboxes in the plan file".
- Line 256 (Phase 4d): the gate description sourcing the diff "from the status
  file's `**Base commit**`", quoting the exact
  `git diff <base> -- . ':(exclude)thoughts/'` command.
- Phase 4c (lines 242–248) covers mismatches (STOP, present, wait) but does not
  instruct recording blockers in the status file — that instruction exists only in
  implement.md.

`plugins/tce/commands/quickfix.md` (Phase 5):

- Line 185: delegates via the `tce:implement` Skill invocation.
- Line 186 (the file's single status-file passage): "The implement process will
  run the full procedure: reading the ticket/research/plan, creating a status file
  alongside the plan, implementing phase by phase, running verification, updating
  the status file, and committing after each phase."
- Lines 218 and 233–239: the Final Summary's "Plan-compliance gate" line and its
  explanation mention "the diff" generically — no base-commit or status-file
  mechanics (inherited via delegation).
- quickfix.md never mentions plan checkboxes.

### 3. Everything else that mentions the convention

- `plugins/tce/README.md:65` — the "See it work" tree contains
  `YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.status.md` as an artifact entry.
- `CLAUDE.md:224` (project instructions, "The plan-compliance gate must stay wired
  across implement and the composites (TP-0020)" section) — "the status file
  records a `**Base commit**` so the diff is precise". **This site is not in the
  ticket's References list** but sits inside a RULE block that names the gate's
  four lock-step files; changing implement.md's diff mechanics obliges updating
  this sentence in the same commit per that rule's own terms.
- Confirmed clean (no status-file mentions): `plugins/tce/commands/review.md`,
  `plan.md`, `research.md`, `plugins/tce/references/plan-document-template.md`,
  `references/research-document-template.md`,
  `plugins/tce/agents/plan-compliance-checker.md`, root `README.md`, all scripts
  and hooks, `.claude/tce/` and `.claude/tmt/` config. This answers the ticket's
  question 4: **no other command reads status files today** — `/tce:review` builds
  its checklist from ticket/plan criteria, and the compliance-checker agent
  receives the diff as prompt text.
- `tce_factory_review.md` (untracked scratch file in the repo root, lines 160,
  208, 251) mentions status files as data substrate — not a shipped artifact, no
  update obligation.

### 4. The plan template the log must fit into

`plugins/tce/references/plan-document-template.md` (runtime reference, read in
full by `/tce:plan` at Steps 3 and 4, and by the composites):

- **No YAML frontmatter** — the document starts at the H1 title.
- Section order: Overview → Current State Analysis → Desired End State (with
  `### Key Discoveries:`) → What We're NOT Doing → Implementation Approach →
  `## Phase N: [Descriptive Name]` … → Testing Strategy → Performance
  Considerations → Migration Notes → References. Conditional `## UI/UX Approach`.
- Per-phase structure (lines 52–91): phase = H2; `### Overview`,
  `### Changes Required:` (H4 `#### 1. [Component/File Group]` groups),
  `### Success Criteria:` with H4 `#### Automated Verification:` and
  `#### Manual Verification:`; phases separated by `---`.
- **The only checkboxes in a plan are the success-criteria lines** (all authored
  unchecked). Who checks them and when is specified nowhere in the template or
  `plan.md` — the sole downstream note is the header comment (lines 10–12):
  "Downstream consumers depend on the template's structure: /tce:implement
  executes the phases and their Automated/Manual success-criteria checkboxes."
- No mention of status files, logs, resume, or post-planning edits; no
  length/terseness guidance for the document body.
- `plan.md:444`: "**CRITICAL: Your job ends here.**" — the plan command never
  describes what implementation later does to the file.

An in-plan per-phase log (e.g. `### Implementation log` as a fourth H3 under each
phase H2, or after the `---` separator) would be a new structural element; the
template's header comment and downstream-consumer note are the natural places to
declare it, and the composite-tracking rule applies to the reference file (per its
own header, lines 7–9).

### 5. Real-world status-file practice (dogfooding evidence)

`thoughts/shared/plans/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.status.md`
(the most recent, 46 lines for a one-phase plan) follows the template's per-phase
fields and **adds two sections the template does not define**:

- `## Plan-Compliance Gate` — verdict (`PASS — 0 not met`), counts of met /
  cannot-verify / MANUAL criteria with one-line dispositions.
- `## Ticket` — the transition performed (`TP-0022 status → Done`).

So in practice the status file also records the gate outcome and the ticket
transition. A merged in-plan log needs a stated home for these (or an explicit
decision that they are not persisted), otherwise the merge silently drops recorded
information relative to current behavior.

Volume evidence for the terseness requirement: 20 status files exist, one per
implemented ticket TP-0001–TP-0022 (TP-0006 and TP-0010 have none — never
implemented), all committed to git. Typical size is a few dozen lines; each
resume/re-read of a merged plan would carry the log in addition to the spec.

### 6. Backward-compatibility ground truth

- Open tickets: TP-0010 (Open, no plan), TP-0023 (this one), TP-0024 (Open, no
  plan). **None has a plan or status file**, so no in-flight implementation in
  this repo depends on reading a `.status.md` at resume.
- All 20 existing `.status.md` files belong to Done tickets; the ticket's Out of
  Scope already excludes migrating them.
- The convention ships in the plugin, so consuming projects may have in-flight
  `.status.md` files at the moment they upgrade tce — the general case the
  ticket's question 3 ("exact backward-compatibility path") is about. The gate's
  existing fallback (implement.md lines 282–284, `git log --grep`) shows the
  precedent for tolerating missing fields.

### 7. History of the convention

- The review (`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`,
  lines 256–259, Section 4 item 4) flagged the double bookkeeping but called it
  "Defensible (plan = spec state, status = session journal)" and asked only that
  the intent be stated in implement.md. The ticket's Notes record that the user
  chose the stronger resolution (one document) based on dogfooding showing no
  observable benefit from the separate file. The same review elsewhere endorses
  the status file for resumability (lines 106–110) and suggested moving the
  status-file *format* into reference files (lines 130–137; that became TP-0016,
  which left the format inline in implement.md — see
  `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md:164,178`,
  which already notes TP-0023 would eliminate it).
- TP-0009 added per-phase commit-hash recording to the status file
  (`thoughts/shared/plans/2026-06-16-TP-0009-implement-intermediate-commits.md`).
- TP-0020 added the `**Base commit**` field and the gate's consumption of it
  (`thoughts/shared/plans/2026-07-05-TP-0020-plan-compliance-gate.md:268-272,312-313`).

## Impact Analysis

### Existing Usages Found

- `plugins/tce/commands/implement.md:91-150,152-167,226,231-242,264-308,336-359` —
  owner of the convention: format, rules, resume, gate diff, commit-hash slot.
- `plugins/tce/commands/work.md:226-228,239-240,256` — inline mirror (composite
  rule).
- `plugins/tce/commands/quickfix.md:186` — one-sentence description of the
  delegated procedure.
- `plugins/tce/README.md:65` — artifact tree entry.
- `CLAUDE.md:224` — gate-section parenthetical ("the status file records a
  `**Base commit**` so the diff is precise").
- 20 historical `.status.md` files under `thoughts/shared/plans/` (all Done
  tickets; migration explicitly out of scope).

### Current Contract

- Input side: created at first-phase start with `git rev-parse HEAD` as
  `**Base commit**`; appended per phase (status, timestamps, steps, issues →
  resolutions, verification, commit hash); written on blockers.
- Output side (consumers): resume logic (all-complete detection, first-incomplete
  selection, partial/blocked detail) reads only this file; the Plan-Compliance
  Gate reads only its `**Base commit**` field (with a `git log --grep` fallback);
  humans read it as the session journal. Plan checkboxes are write-only from
  implement's perspective.
- Implicit assumptions: same-basename pairing next to the plan; the file is
  committed with the work; the gate's diff excludes it via `':(exclude)thoughts/'`.

### Adaptation Requirements

- `implement.md` — replace "Status File Tracking"/"Status File Format"/"Status
  File Rules"/"Writing Status Updates" with the in-plan log format + terseness
  guidance; rewrite "Getting Started" step and "Resuming Work" against the plan
  alone; re-point the gate's diff step at wherever `**Base commit**` now lives;
  update the frontmatter `description` ("status tracking") if wording changes;
  keep the commit-hash recording and blocker-recording duties.
- `work.md:226-228,239-240,256` — mirror every one of those changes (composite
  rule, same commit).
- `quickfix.md:186` — reword the delegated-procedure sentence (same commit).
- `plugins/tce/README.md:65` — drop/replace the `.status.md` tree entry.
- `CLAUDE.md:224` — reword the gate section's base-commit parenthetical (the
  TP-0020 lock-step rule itself demands this happen in the same commit).
- `plugins/tce/references/plan-document-template.md` — the log block is part of
  the plan-document contract; the template (or at least its downstream-consumers
  header note) must define/acknowledge it so `/tce:plan` and `/tce:implement`
  agree on structure. Editing it triggers the composite-tracking rule per its own
  header.

### Backward Compatibility Options

- Option A: at resume, if no in-plan log exists but a same-basename `.status.md`
  does, read it (legacy) and continue logging into the plan; never create a new
  `.status.md`. Pros: in-flight consuming-project tickets resume seamlessly; one
  documented sentence. Cons: keeps the pairing convention alive in prose for one
  more release.
- Option B: legacy `.status.md` keeps being used for tickets that already have
  one (finish old-style); only new implementations use in-plan logs. Pros: no
  mixed-mode documents. Cons: two live conventions in the command text for an
  extended period — heavier prose than A.
- The gate already tolerates a missing `**Base commit**` via the `git log --grep`
  fallback (implement.md:282-284), which cushions either option.

## Code References

- `plugins/tce/commands/implement.md:91-150` — Status File Tracking: naming, full format (incl. `**Base commit**`, lines 104–105), rules 1–6
- `plugins/tce/commands/implement.md:152-167` — Getting Started: detection/resume/create steps
- `plugins/tce/commands/implement.md:199,224-226` — plan-checkbox updates + status-file update bullet
- `plugins/tce/commands/implement.md:231-242` — Committing Each Phase: commit hash into `### Commit` slot
- `plugins/tce/commands/implement.md:264-308` — Plan-Compliance Gate; diff from the status file's base commit at 279–284, fallback included
- `plugins/tce/commands/implement.md:336-359` — Resuming Work: "authoritative record", summary format, partial/blocked handling
- `plugins/tce/commands/work.md:226-228,239-240,256` — composite mirror sites
- `plugins/tce/commands/quickfix.md:186` — delegated-procedure sentence; `:218,233-239` — gate summary (generic, likely unchanged)
- `plugins/tce/README.md:65` — `.status.md` entry in the "See it work" tree
- `CLAUDE.md:224` — base-commit parenthetical in the TP-0020 gate section
- `plugins/tce/references/plan-document-template.md:23-125` — plan skeleton; per-phase structure 52–91; downstream-consumers note 10–12
- `plugins/tce/commands/plan.md:444` — "Your job ends here" (plan command never describes implementation-time edits)

## Architecture Documentation

- **Reference files are command contract**: `plan-document-template.md` is read at
  point of use by `plan`/`work`/`quickfix`; editing it invokes the
  composite-tracking rule (its header, lines 7–9, says so explicitly).
- **The gate isolation model**: the `plan-compliance-checker` agent receives only
  criteria + diff text; it never opens files under `thoughts/`, so relocating the
  log cannot leak into the checker's context. The `':(exclude)thoughts/'`
  pathspec keeps plan-file log edits out of the compliance diff either way.
- **Lock-step rules touched by this ticket**: composite tracking
  (implement → work/quickfix), the TP-0020 four-file gate rule
  (agent/implement/work/quickfix + the CLAUDE.md sentence itself), and TP-0013
  re-reads (the plan is re-read fully by implement and the composites — the
  stated reason the ticket demands terse logs).
- **Status enum symmetry**: the status file's ✅ Complete / ⚠️ Partial /
  ❌ Blocked phase enum is the progress vocabulary the resume summary and
  blocker handling are written against; any in-plan log format inherits or
  replaces this vocabulary.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:256-259` —
  the double-bookkeeping flag (Section 4 item 4); called it defensible, proposed
  documenting the intent split; the ticket supersedes that with full merge.
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:106-110` —
  the same review endorses the status file's resumability role (what the in-plan
  log must preserve).
- `thoughts/shared/plans/2026-07-05-TP-0020-plan-compliance-gate.md:268-272` —
  introduced `**Base commit**` into the status-file format.
- `thoughts/shared/plans/2026-06-16-TP-0009-implement-intermediate-commits.md` —
  introduced per-phase commit-hash recording.
- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md:164,178`
  — mapped the status-file format's location and noted TP-0023 would eliminate it
  (which is why TP-0016 left the format inline in implement.md).
- `thoughts/shared/plans/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.status.md`
  — freshest real example; shows the extra `## Plan-Compliance Gate` and
  `## Ticket` sections dogfooding added beyond the template.

## Related Research

- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` — base-commit/diff mechanics this ticket must re-home.
- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md` — prompt-size context: implement.md's status sections are inline (not a reference file) precisely pending TP-0023.
- `thoughts/shared/research/2026-06-16-TP-0009-implement-intermediate-commits.md` — origin of the commit-hash slot.

## Open Questions

Carried from the ticket's "Questions for Research/Planning", with what research
established; the remaining decisions are for the planning checkpoint:

1. **Log placement** — per-phase `### Implementation log` blocks (log sits under
   its phase H2; matches how resume reads phase-by-phase; ticket leans this way)
   vs one appended `## Implementation Log` section (spec part stays pristine;
   matches how the status file reads today as one journal). Research note: the
   plan's per-phase structure ends with the success-criteria H3 followed by `---`,
   so a per-phase H3 log block fits without disturbing the checkbox sections the
   gate/README/plan.md reference.
2. **Completion signal** — today "all phases ✅ Complete in the status file" is
   the single signal; checkboxes are write-only. The merged format needs one
   defined signal: per-phase log status lines (direct successor of today's
   mechanism) vs all success-criteria checkboxes ticked (double-duty for the
   Manual items, which today can stay unticked pending human verification even on
   Done tickets — evidence: TP-0022's gate recorded 4 MANUAL items while the
   ticket went Done).
3. **Backward compatibility** — Options A/B under Impact Analysis; repo-local
   ground truth says no in-flight status files exist here, so the decision is
   about consuming projects mid-upgrade.
4. **Other readers** — resolved: none. `/tce:review` and all other commands/agents
   do not read status files.
5. **Where `**Base commit**` lives in the plan** — the log format needs a slot
   recorded at first-phase start (e.g. a log header line); the gate's diff step in
   implement.md/work.md must point at it verbatim.
6. **Gate verdict + ticket transition records** — dogfooded status files record
   both (beyond the template); decide whether the in-plan log persists them (e.g.
   in the final phase's log or a closing log line) or they remain
   conversation-only.
