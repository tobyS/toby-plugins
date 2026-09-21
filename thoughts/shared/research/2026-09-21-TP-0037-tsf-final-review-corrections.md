---
date: 2026-09-21T06:53:34Z
git_commit: 1e08a1cbeb2bd2a9628da2610eaf9308a4c952fc
branch: main
repository: toby-plugins
topic: "TP-0037: tsf — corrections from the final pre-first-run review"
tags: [research, tsf, result-block, journal, cycle-dispatch, cycle-write-phase, dossier, pull-request]
status: complete
last_updated: 2026-09-21
---

# Research: TP-0037 — tsf corrections from the final pre-first-run review

**Date**: 2026-09-21T06:53:34Z
**Git Commit**: 1e08a1cbeb2bd2a9628da2610eaf9308a4c952fc
**Branch**: main
**Repository**: toby-plugins

## Research Question

Where exactly do the three contradictions the ticket names (C1: a `blocked`
return writes an out-of-vocabulary `Next step`; C2: the dispatcher composes pull
request and refusal-addendum text its invariant 3 forbids; C3: a failed manual
item has an unexecutable route) live, which other files state the same
contracts, and what else on the same seams contradicts invariant 3 or the
closed `Next step` vocabulary? Plus the ticket's "Questions for
Research/Planning".

## Summary

All three findings reproduce against the current tree (tsf 1.1.0). Research
also found that the seams they sit on carry **further instances of the same
defect classes**, which the ticket's acceptance criteria ("invariant 3 and the
rest of the dispatcher's instructions no longer contradict each other on any
path"; "every `blocked` row names a `next-step` from the closed vocabulary")
reach:

- **C1 — confirmed, and wider.** The wildcard row
  `any | blocked | tsf:needs-human | the step itself`
  (`result-block.md:90`) yields `verify-fix` / `manual-verify` for two agents.
  The same "the step itself" hole exists in the journal's twice-invalid-return
  shape (`journal-entry.md:204`). And `implement` in **rework** or **fix** mode
  blocking with `Next step: implement` resumes into fresh mode, where every
  increment is already built — an invalid return and a second park.
- **Adjacent landing hole.** A ticket parked during the landing and resumed is
  given a resume entry whose heading is `step: landing`
  (`journal-entry.md:139`), and row 12 treats *any* `step: landing` last entry
  as "decision recorded → merge cycle" (`cycle-dispatch.md:334-336`). The
  resumed ticket therefore skips the decision cycle (no sync, no integration
  gate, no approval-currency check) and goes straight to the merge cycle.
- **C2 — confirmed, and wider.** Besides the two places the ticket names
  (`cycle-write-phase.md:79-84`, `cycle-dispatch.md:361-362`), three more
  instructions put pull-request text through, or have it composed in, the
  dispatcher's context: row 9 passes the live body verbatim in the dossier
  payload (`cycle-dispatch.md:255-258, 479-480`); the dossier's correction path
  has the dispatcher compose "the corrected title" and a body file
  (`cycle-write-phase.md:140-150`); the merge passes `--message-file <the body
  with its closing keyword>` (`cycle-dispatch.md:395-397`), which the dispatcher
  would have to write. Invariant 3's "read only" list
  (`cycle.md:25-27`) names none of these.
- **C3 — confirmed.** Row 6's routing sentence (`cycle-dispatch.md:207-208`)
  and `manual-verify.md:100-102` ("the dispatcher routes it like any other red
  verification") both claim a route that nothing can take; `agents/dossier.md:69-72`
  omits failed manual items that the template lists (`templates/dossier.md:97-101`).

## Detailed Findings

### C1 — `blocked` returns and the closed `Next step` vocabulary

- The closed vocabulary: `journal-entry.md:39, 66-83` —
  `triage | research | plan | implement | verify | gates | dossier | review | landing`.
  The dispatcher treats anything else as unreadable and parks it as a mismatch
  whose `Next step` repeats the derived (unreadable) step
  (`cycle-dispatch.md:34-37, 96-100`) — so the ticket re-parks on every resume.
- The result block's `step:` field has a **different, wider** vocabulary
  (`result-block.md:28`: adds `verify-fix`, `manual-verify`, `merge-resolver`,
  and has no `gates`/`review`/`landing`). The journal heading's `step:`
  vocabulary (`journal-entry.md:31`) is a third list: it has `verify-fix` and
  `manual-verify` but not `merge-resolver`.
- The wildcard row: `result-block.md:90`. Validity only checks the row exists
  (`result-block.md:128-131`), so `next-step: verify-fix` passes parsing.
- Agent `## Return` sections:
  - `verify-fix.md:87-88` — blocked names `next-label` only, no `next-step`.
    Blocking is a designed path (`verify-fix.md:63-68`: CI red with local
    green; a test the spec does not ask for).
  - `manual-verify.md:100-103` — blocked has neither label nor step.
  - `merge-resolver.md:113-114` — blocked names `next-step: landing` already.
  - `implement.md:149-150` — blocked names no `next-step`. Its fresh-mode
    blocked returns (unsatisfiable dependency, red increment,
    `implement.md:72-77, 83-84`) map naturally to `implement`.
  - triage/research/plan/dossier: "the step itself" is already in the
    vocabulary for these.
- **Resume path for a blocked verify-fix / manual-verify with `Next step:
  verify`** (the ticket's "done when"): row 3 maps `verify` to a pure label
  correction to `tsf:verify` with a resume entry that opens a **new episode**
  (`cycle-dispatch.md:152-163`, `journal-entry.md:132-147`). Next cycle row 6
  re-runs local verification (verify-fix attempt counter restarts in the new
  episode, `cycle-dispatch.md:428-430`), and a manual report for the new
  episode does not exist yet, so manual-verify runs again
  (`cycle-dispatch.md:205-206`). The path works end to end.
- **The twice-invalid entry** (`journal-entry.md:196-205`): "`Next step`: the
  step's own Next step, or the step itself if none was valid". For
  verify-fix / manual-verify / merge-resolver "the step itself" is out of
  vocabulary — the same hole. The section's own preamble
  (`journal-entry.md:117-119`) already says a dispatcher-written entry repeats
  the ticket's **derived state**; the derived step when those agents are
  dispatched is `verify` (rows 6/7) or `landing` (row 12's sync). The
  failed-write shape is fine: it keeps the validated result's `Next step`
  (`cycle-write-phase.md:194-197`).
- **Implement in rework / fix mode** (observed, not in the ticket):
  - Fix mode is dispatched from `tsf:verify` (row 8, `cycle-dispatch.md:249-253`);
    rework from `tsf:rework` (row 11). Both "always return `tsf:verify`/`verify`"
    when they succeed (`result-block.md:92-98`).
  - Blocked with `Next step: implement` → resume sets `tsf:implement`
    (step-to-label table, `cycle-dispatch.md:51-61`) → row 5 fresh mode. The
    built set is the union since the ticket last entered `tsf:implement`
    (`journal-entry.md:49-55`); all increments are built, so the agent has
    nothing to build, returns without a commit and fails MANDATORY OUTPUT
    (`cycle.md:223-228`) or the no-progress guard (`cycle-dispatch.md:177-182`)
    → park again. The rework's review and the fix's failing reports are never
    worked from.
  - Mapping observations: fix blocked → `verify` resumes into a new episode;
    row 8 finds the failing reports still at the current logic head and
    re-enters fix mode with a fresh `gate_fix_bound` — the same logic the
    episode-on-resume rule already applies (`cycle-dispatch.md:160-163`).
    Rework blocked → `review` resumes to `tsf:needs-review`; row 10 reads
    `review: changes-requested` from the scan, which stays current as long as
    no factory pull-request comment is newer (`CLAUDE.md` "the scan record is a
    machine contract"; the blocked comment goes to the **issue**,
    `cycle-write-phase.md:50-53`) → `tsf:rework` → rework again. Rework blocked
    → `verify` would instead run the gates, whose one-liners are pull-request
    comments (`cycle-write-phase.md:122-126`) and would stale the review.
  - The table can carry several `implement | blocked` rows; the mode-to-row
    rule would live in prose, exactly like the existing "only fresh mode may
    use the second `continued` row" (`result-block.md:92`).

### Adjacent: a resumed landing skips its decision cycle

- Row 12 decides which landing cycle runs from the last entry alone: "a
  `step: landing` entry means the decision is already recorded, so this is the
  merge cycle" (`cycle-dispatch.md:333-336`).
- Row 3's resume entry heading is `step: [derived step]`
  (`journal-entry.md:138-147`) — `step: landing` for a ticket parked in
  landing (merge-resolver blocked, attempt bound exhausted, a non-converging
  `mergeable_state`, a twice-invalid resolver return).
- The merge cycle then runs `diff.sh decision-head`, which only compares the
  newest journal commit with the branch head (`diff.sh:345-367`) — the resume
  commit is the head, so `unchanged: yes`. If a human resolved the conflict by
  pushing to the branch before re-queueing, CI turns green on the resume commit
  and `pr-state` reads `clean`, the merge proceeds (`cycle-dispatch.md:375-401`)
  with no sync, no integration gate and no approval-currency check — a
  human-pushed resolution merged under an approval that predates it.
- The landing decision entry is the only entry shape that carries an
  `- Attempt:` line (`journal-entry.md:38, 177-185`); resume and mismatch
  entries never do.
- Attempt counting has the same flavour of problem: attempts are the
  `step: landing` entries since the newest `step: review` entry with
  `Label: tsf:landing` (`cycle-dispatch.md:434-441`). A resume adds a
  `step: landing` entry and no review entry, so a ticket parked by an exhausted
  `landing_attempt_bound` re-parks at once — the case the episode-on-resume rule
  solved for verification.

### C2 — dispatcher-composed or dispatcher-read artifact text

- Invariant 3 (`cycle.md:24-29`): never read the body of a spec, research, plan
  or diff; never write artifact content; "You read only: labels, file
  existence, the journal's last entry, result blocks and a gate report's two
  machine lines." Reinforced by Important Rule 6 (`cycle.md:281-282`: "Paths,
  labels and one-line statuses only").
- **Opening the pull request** (`cycle-write-phase.md:70-90`): dispatcher reads
  `pr-body.md`, composes the title from the spec title and the body from the
  spec's desired outcome and the plan's decisions (`pr-body.md:34-54`), writes
  it to a scratchpad file, calls `gh-write.sh pr-create … --title <title>
  --body-file <file>`. `pr-body.md:3-5` names `/tsf:cycle` as the reader;
  `pr-body.md:66-67` justifies "no angle brackets" with "the body travels
  through the dispatcher as text". `DESIGN.md:556-562` (§6.6) says "the
  dispatcher then pushes and opens the PR … from the PR template". README
  `:154-157` describes the timing only.
- **`gh-write.sh pr-create`** (`gh-write.sh:50-58, 220, 373-401`): title from
  `--title T` (argument), body from `--body-file F`; idempotent on a 422
  (`exists`). `pr-edit` (`:60-68, 221-223, 403-433`) takes either or both, with
  read-back. No script reads a title from a file today.
- **Row 9's dossier payload** (`cycle-dispatch.md:255-258, 479-480`): title and
  body from `gh-read.sh pr --branch` (body verbatim after `body:`,
  `gh-read.sh:40-53`) and passed as `pr-title:` / `pr-body:` — the body passes
  through the dispatcher's context. `gh-read.sh pr` has no `--out`; the
  pattern exists in `review-brief --out FILE` ("The content goes to FILE and
  never to stdout", `gh-read.sh:121-133`), matching the CLAUDE.md rule "A
  script writes its own output files".
- **Dossier correction path** (`cycle-write-phase.md:140-150`,
  `agents/dossier.md:79-82`): the agent reports a mismatch, the dispatcher
  composes `--title <the corrected title>` / `--body-file <file>` for
  `pr-edit`. The corrected text is authored by the dispatcher.
- **The merge** (`cycle-dispatch.md:395-397`): `gh-write.sh merge … --title <the
  pull request's title> --message-file <the body with its closing keyword>`.
  The squash message file has to be produced by someone; no script writes it.
  `gh-read.sh pr-state` already returns `title:` on one line
  (`gh-read.sh:69`).
- **Landing refusal** (`cycle-dispatch.md:352-365`): "Not decided → a dossier
  addendum naming the cause (dossier.md, 'The landing refusal') and the label
  `tsf:needs-review`". Row 12 does not say who writes it; the only author of
  addenda is the dossier agent (`agents/dossier.md:76-78`), which has no
  `mode:` and no cause input (`agents/dossier.md:29-37`) and never mentions a
  refusal. The template's refusal section lists three causes
  (`templates/dossier.md:150-165`). `cycle-write-phase.md:152-171` covers only
  the decided path. DESIGN §9.3 step 4 (`DESIGN.md:877-879`): "Otherwise it
  posts a dossier addendum … labels `tsf:needs-review`".
  - The refusal cycle is a **decision cycle**, which writes (journal, report,
    push) — only the merge cycle is write-free (`cycle-write-phase.md:152-186`,
    CLAUDE.md "the landing is a decision cycle plus a write-free merge cycle").
    So one cycle can dispatch the dossier agent and post its addendum; the
    one-step-per-cycle invariant is about agent steps and the landing's
    decision cycle already dispatches up to two agents (merge-resolver,
    integration).
  - The three causes are facts the dispatcher already holds as one-liners:
    the resolver's trailer class, the integration verdict/report path, the
    `diff.sh ancestor` answer. A `cause:` payload line plus report path is
    enough for the agent to write the addendum from the branch.
  - The logic-resolution case does not go to review but to `tsf:verify` as a
    new episode (`cycle-dispatch.md:362-365`); the addendum for it comes later
    from the normal dossier step after re-gating.
- **The dispatcher's own one-liners** (park comments, the landing decision line,
  gate one-liners, prepare/push failure comments —
  `cycle-write-phase.md:122-126, 166-168, 209-211, 221-241`,
  `result-block.md:137-139`) are status lines built from result fields,
  outcome lines and script `detail:` lines; they never quote an artifact. The
  current invariant wording ("never write artifact content") does not name
  them either way.

### C3 — failed manual items

- Row 6 (`cycle-dispatch.md:205-210`): "a `failed` item routes exactly like a
  red verification (row 6's verify-fix, `failure: local`)", while the same
  paragraph says "Do not open either file — the counts are all you need".
- The result block's `manual:` field carries attempted and need-a-human counts
  only (`result-block.md:33`, `manual-verify.md:82-83`); manual-verify's only
  allowed row is `continued | tsf:verify | gates` (`result-block.md:87`).
- `manual-verify.md:100-102` repeats the claim: "report it, and the dispatcher
  routes it like any other red verification".
- Dossier agent open items (`agents/dossier.md:69-72`): gate verdicts,
  advisory findings, addenda, "manual items reported as needing a human" — no
  failed items. The template (`templates/dossier.md:97-101`) lists attempted
  items that "failed or were inconclusive — with the evidence". The agent
  already reads every file under `reports/` (`agents/dossier.md:44-47`), which
  includes `reports/manual-<episode>.md` with per-item evidence
  (`cycle-write-phase.md:94-106`).
- README `:158-163` and DESIGN `:778-779` (§9.1) do not claim the route.

### Version and migration

- tsf is at `1.1.0` in `plugins/tsf/.claude-plugin/plugin.json:3` and
  `.claude-plugin/marketplace.json:33`. None of the corrections change what
  `.claude/tsf/config.md` must contain; `/tsf:init`'s Idempotency list
  (`commands/init.md:462-494`) has a precedent for "nothing to migrate"
  entries (`0.1.0`, `0.2.0`).
- The DESIGN decision log (§16) runs to entry 60 (`DESIGN.md:1772`); TP-0036
  recorded its corrections there (entries 55–60).

## Defect Mechanism

- **C1:** `result-block.md:90` (wildcard) → an agent following it returns
  `next-step: verify-fix` → validity check accepts (`result-block.md:128-131`)
  → the journal records it (`cycle-write-phase.md:35-39`) → next cycle's
  derivation calls it unreadable (`cycle-dispatch.md:34-37`) → mismatch park
  whose `Next step` repeats the unreadable value (`cycle-dispatch.md:98-100`)
  → loop on every re-queue.
- **Landing resume:** park during landing → resume entry `step: landing`
  (`journal-entry.md:139`) → row 12 reads "decision recorded"
  (`cycle-dispatch.md:334-336`) → merge cycle with `decision-head` trivially
  unchanged (`diff.sh:355-362`) → merge without decision-cycle checks.
- **C2:** invariant 3 (`cycle.md:24-29`) vs. five instructions that make the
  dispatcher author or carry pull-request / addendum text
  (`cycle-write-phase.md:79-84, 140-150`; `cycle-dispatch.md:255-258, 361-362,
  395-397`).
- **C3:** `cycle-dispatch.md:207-208` names a route whose trigger (a failed
  count) is absent from the result block (`result-block.md:33`) and whose
  target (verify-fix after a green suite) has nothing to fix.

## Code References

- `plugins/tsf/references/templates/result-block.md:28-34, 75-117, 119-139` — fields, table, parsing
- `plugins/tsf/references/templates/journal-entry.md:31-39, 66-113, 115-205` — entry shape, vocabulary, dispatcher entries
- `plugins/tsf/references/cycle-dispatch.md:22-70, 140-163, 188-210, 249-258, 333-417, 425-441, 453-500` — derivation, row 3, row 6, rows 8/9, row 12, counters, payload
- `plugins/tsf/references/cycle-write-phase.md:70-90, 92-106, 130-150, 152-171, 188-214` — PR open, reports, dossier writes, landing writes, parks
- `plugins/tsf/commands/cycle.md:24-29, 223-228, 281-282` — invariant 3, mandatory output, rule 6
- `plugins/tsf/agents/verify-fix.md:84-88`, `manual-verify.md:82-103`, `merge-resolver.md:109-114`, `implement.md:131-161`, `dossier.md:29-37, 69-82, 92-103`
- `plugins/tsf/references/templates/pr-body.md:1-67`, `templates/dossier.md:92-101, 114-165`
- `plugins/tsf/scripts/gh-write.sh:50-68, 220-223, 373-433` — pr-create / pr-edit
- `plugins/tsf/scripts/gh-read.sh:40-53, 69, 121-133` — pr, pr-state title, review-brief --out
- `plugins/tsf/scripts/diff.sh:345-367` — decision-head
- `plugins/tsf/DESIGN.md:556-562, 870-879, 1750-1772` — §6.6, §9.3 step 4, decision log
- `plugins/tsf/commands/init.md:462-494` — Idempotency list

## Architecture Documentation

- **Paths-only handover** is the established pattern for content the
  dispatcher must pass on: `diff.sh pr-diff`, `plan.sh criteria --out
  --manual-out`, `gh-read.sh review-brief --out` (CLAUDE.md "A script writes
  its own output files"; "the plan is parsed by a script").
- **Result-block content is accepted in the dispatcher's context** (the
  dossier's `tsf-comment` *is* the dossier and is posted verbatim,
  `agents/dossier.md:100-101`); what invariant 3 forbids is reading artifact
  bodies from disk and composing artifact text.
- **Untracked vs committed:** `.tsf-tmp/` files live one cycle and are deleted
  by `prepare`'s `git clean -fd` (`diff.sh:20-24`, `prepare.sh:30-31`);
  committed files under `thoughts/factory/GH-<n>/` are never in the PR diff
  (`':(exclude)thoughts/'`) and survive across cycles. A committed file gives
  the dossier agent something it can correct itself and the dispatcher a path
  to pass to `pr-edit`, and it survives a cycle that dies between push and
  `pr-create` (today that leaves a `tsf:verify` ticket with no pull request and
  no text to open one from).
- **Same-commit spans** touched (root CLAUDE.md): result block
  (`result-block.md`, each agent's `## Return`, `cycle.md` Step 6,
  `cycle-write-phase.md`); journal `Next step` (`journal-entry.md`,
  `cycle-dispatch.md`, agents' `tsf-journal`); dispatcher-owns-writes
  (`gh-write.sh`/`push.sh` flags → `cycle.md`, `cycle-write-phase.md`,
  `spec.md`, `init.md`); batched implementation (`agents/implement.md`,
  `journal-entry.md`, `result-block.md`, `cycle-dispatch.md` row 5,
  `cycle-write-phase.md`); landing (`cycle.md`, `cycle-dispatch.md` row 12,
  `cycle-write-phase.md`, `cycle-report.md`, `journal-entry.md`).

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0036-tsf-review-corrections.md` and its plan
  `thoughts/shared/plans/2026-09-20-TP-0036-tsf-review-corrections.md` — the
  previous corrections round; introduced batching (last batch opens the PR),
  `plan.sh`, and the resume-opens-an-episode rule this research reuses.
- `thoughts/shared/plans/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`
  — origin of `pr-body.md`, the allowed-outcomes table and the four closed
  vocabularies.
- `thoughts/shared/plans/2026-09-19-TP-0034c-tsf-landing-release.md` — the
  landing's two-cycle design and the merge-resolver's `landing` blocked value.

## Related Research

- `thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md`
- `thoughts/shared/research/2026-09-18-TP-0034c-tsf-landing-release.md`
- `thoughts/shared/research/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`

## Open Questions

1. **C2 file location and title transport** (ticket questions 1–2): committed
   `thoughts/factory/GH-<n>/pr-body.md` vs. untracked `.tsf-tmp/`; title as
   the file's first line (read by `gh-write.sh`, a new flag) vs. a result-block
   field.
2. **Scope of the extra invariant-3 contradictions**: row 9's verbatim body,
   the dossier correction path, the merge's message file — include them (the
   acceptance criterion "on any path" reaches them) or record them in TODO.md?
3. **Blocked implement in rework / fix mode**: extra table rows
   (`review` for rework, `verify` for fix) or keep `implement`?
4. **Resumed landing skipping the decision cycle**: fix here (row 12 keys on
   the decision entry's `- Attempt:` line; attempt count restarts on resume)
   or defer to TODO.md?
5. Resolved by research, no user input needed: the twice-invalid journal shape
   (use the derived step), the refusal dispatch (dossier agent in the decision
   cycle with a `cause:` line; the decision cycle writes, so it posts), the
   invariant-3 wording for the dispatcher's own one-liners (state them as
   allowed status lines), and the version (1.1.1, an Idempotency entry saying
   nothing to migrate).
