---
date: 2026-09-28T16:50:46+0200
git_commit: 9fa2bbb74111cc4b846cf50ebe117241f2d26788
branch: main
repository: toby-plugins
topic: "tsf — a format problem in a factory artifact must never reach a human (TP-0043)"
tags: [research, codebase, tsf, plan-sh, parking, result-block, cycle-dispatch]
status: complete
last_updated: 2026-09-28
---

# Research: tsf — a format problem in a factory artifact must never reach a human (TP-0043)

**Date**: 2026-09-28T16:50:46+0200
**Git Commit**: 9fa2bbb74111cc4b846cf50ebe117241f2d26788
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0043 raises three compounding failures from the chat-sustainability GH-41 run:
**P1** `plugins/tsf/scripts/plan.sh` is brittle where a reader would not be (bullet-only
field recognition, silent truncation at the first blank line); **P2** a plan that does not
parse escalates to a human who did not write it and does not own the format; **P3** park
comments are diagnostics rather than instructions, and a human's reasonable recovery
attempt (`tsf:answered` on a `tsf:needs-human` park) is refused.

The research question: what exactly is the current mechanism in each of the three areas,
where are the seams a fix must respect, and what are the concrete options for the three
decisions the ticket defers to planning?

## Summary

All three findings are confirmed against the code, and **P1 is worse than the ticket
states**. The ticket reports the truncation defect as reproduced on a *synthetic* plan; it
is in fact present in the **real approved plan of the GH-41 run**, on an increment rather
than only on the addendum. Increment 1's `- **Verification:**` field contains an indented
numbered list, a blank line, and then an indented `Run cd backend … npm run verify`
paragraph. The blank line flushes the field, so the criterion the plan-compliance gate
judged increment 1 against **silently lost the command that verifies it** — while
`check` reported `ok`. Measured, not inferred (see Defect Mechanism).

The structural facts that shape a fix:

- **`check` and `criteria` already share one code path** for everything except two
  mode-local tests. Both run the same awk parser into `$STREAM`, then the same `$PROBLEM`
  validation awk. So P1's "`check` and `criteria` must agree" does not need a new shared
  layer — it needs the substance test added to the `$PROBLEM` awk, which both modes
  already consult. This answers the ticket's first Question-for-Planning.
- **The plan template needs no change** (`plan.md` lines 65, 67, 95, 97 carry the one
  canonical `- **Verification:** …` bullet form), consistent with the ticket's 2026-09-28
  decision. P1 is entirely a `plan.sh` change.
- **P2's retry note has a documented twin to copy.** `result-block.md:176-179` already
  names *two* places an agent can find the required shape (the template and the agent's
  own `## Return` section); `cycle.md:252` forwards only `plan.sh`'s complaint.
- **P2's question park hits a hard obstacle at implement time**: `tsf:implement` has
  **no `resume` mode** (`agents/implement.md:40` — `fresh`, `rework`, `fix` only), and
  `cycle-dispatch.md:125-129` deliberately routes an `implement` park's reply through
  `tsf:plan` and a second approval gate. An addendum format park is written by implement,
  so "the reply is folded by the parking step" is not currently expressible for the
  case that actually occurred. This is the sharpest open design decision.
- **P3's inventory is five park sites**, all in `cycle-write-phase.md`, and the label
  vocabulary confirms the trap: `tsf:answered` is described in the README as "You
  replied; the step that asked picks it up", the pickup workflow sets it automatically,
  and `cycle-dispatch.md:90-91` parks any `tsf:answered` whose last journal `Label` is
  not one of the two question labels — which is exactly what happened at 05:12Z.

## Detailed Findings

### P1 — `plugins/tsf/scripts/plan.sh` (289 lines)

One awk parser (`:107-206`) normalizes the plan to a tab-separated stream; both modes then
run the same `$PROBLEM` validation awk (`:214-238`); they diverge only at `case "$MODE"`
(`:240`).

**Shape (the ticket's first defect).** The two field-opening rules require a hyphen
bullet:

- `:181` — `if (match(line, /^[ \t]*- +\*\*Verification:?\*\*:?/))`
- `:188` — `if (match(line, /^[ \t]*- +\*\*Manual:?\*\*:?/))`

Precisely: optional indent, a literal `-`, one or more spaces, then the bold marker. What
this *does* tolerate is broader than the ticket assumes — both colons are independently
optional (`- **Verification**:`, `- **Verification**` all match), and because `match` is
unanchored at the right, **arbitrary trailing text after the colon is already tolerated
and becomes the field's text**. What it rejects is (a) a paragraph-form marker with no
bullet, (b) `*`/`+` bullets, (c) a trailing qualifier *before* the colon —
`**Verification (restated in full):**` — because the `:?\*\*` sequence cannot span
` (restated in full)`.

So the GH-41 addendum failed on exactly two counts: no bullet, and the parenthetical
inside the bold span.

**Truncation (the ticket's second defect).** `:195-196`:

```awk
    # Any other bullet or a blank line ends the field being collected.
    if (line ~ /^[ \t]*- +\*\*/ || line ~ /^[ \t]*$/) { flush_field(); next }
```

A blank line — including a whitespace-only line — flushes. Continuation requires both an
open field and indentation (`:198`, `/^[ \t]+[^ \t]/`); anything else at column 0 reaches
`:203` and flushes. So a field survives an indented wrapped list but **not a blank line
inside it**, and not a column-0 continuation.

**Why the truncation is silent.** `flush_field()` (`:108-114`) guards on `field_kind`, not
on `field_text`, so a marker with nothing after it still emits a `FIELD` record with empty
`$4`. The validation awk then sets `has[$2] = 1` (`:225`) on mere record presence, so
`check` reports `ok`; and in `criteria` the `(inc SUBSEP "verification") in text` test
(`:268`) is true because the assignment created the key, so an empty criterion is written.

**Where the substance test belongs.** The `$PROBLEM` awk (`:214-238`) is already run by
both modes before they diverge, and it already reads the same `FIELD` records `criteria`
extracts. Adding an emptiness test there makes `check` and `criteria` agree *by
construction* rather than by duplicated logic — `criteria` refuses on a non-empty
`$PROBLEM` at `:250-254`. The alternative (suppressing the `FIELD` record in
`flush_field()` when the text is empty) also unifies the paths but degrades the message:
the existing `:232` error would then claim the increment "has neither a `**Verification:**`
nor a `**Manual:**` field" when it visibly has one.

**What must keep working.** Two boundaries are load-bearing if capture is extended past
blank lines:

- `- **Depends on:**` and every other bold bullet must still terminate a field (`:196`'s
  first clause). Verified against the corpus: GH-41 increments 2 and 3 end their
  Verification field exactly there (`plan-original.md:166`, `:187`).
- Fenced blocks are skipped *without* flushing (`:120-129`), so a field already stays open
  across a fence today. The TP-0033 stripping rationale is at `:44-47`.

### The plan template (`references/templates/plan.md`)

The canonical field form appears at `:65` / `:67` (increments) and `:95` / `:97`
(addenda), always as `- **Verification:** …` / `- **Manual:** …`. The structural contract
is restated in prose at `:35`. Per the ticket's 2026-09-28 decision the template is not to
advertise tolerated variants, so **no template change is implied by P1** — the parser
absorbs drift, the contract keeps showing one shape.

### P2 — the two invalid-return retry paths

`cycle.md` Step 6 (`:208-259`) has **four** independent invalidity detectors: a malformed
result block (delegated to `result-block.md` at `:229-233`), a missing artifact
(`MANDATORY OUTPUT`, `:235-242`), an unparseable plan (`:244-256`), and a wrong branch
(`:258-259`). All four converge on one behaviour — one re-dispatch, then a park — but only
two of them carry a tailored note.

The **fixed twin** (`result-block.md:176-179`):

```
5. Invalid or missing → dispatch the same agent once more with the same payload
   plus the line `note: your previous return had no valid result block — the
   format is in ${CLAUDE_PLUGIN_ROOT}/references/templates/result-block.md and
   in your own ## Return section; read it and return the blocks exactly`.
```

TP-0039 C1's insight is recorded in that file's own header (`:14-18`): the `## Return`
pointer is load-bearing precisely because an agent that skipped the point-of-use Read
still has the format in front of it.

The **unfixed path** (`cycle.md:251-254`):

```
`result: invalid` is an **invalid return**, handled exactly as a malformed
result block is: one re-dispatch carrying `note: <the detail line>`, then a
park. The `detail:` line names the increment or addendum at fault — pass it on
verbatim, it is the only thing the agent needs to fix it.
```

The final clause is the defect in one sentence: the `detail:` line names the field but
never its shape, and the run proved "the only thing the agent needs" false — commit
`353f939` read the message correctly, dropped the parenthetical, and still failed because
the message says nothing about the bullet.

A third description exists at `cycle-dispatch.md:561-563` ("The spawn payload"), which
carries a **truncated** copy of the canonical string plus the plan-parse alternative — a
fourth place any wording change must reach.

**The park that follows** is `result-block.md:180-183`: journal entry, `tsf:needs-human`,
and "a one-line comment of the dispatcher's own saying the step's agent failed twice and
linking the journal".

**The obstacle for a question park.** `agents/implement.md:40` declares `mode:` as
`fresh`, `rework` or `fix` — there is no `resume`. And `cycle-dispatch.md:125-129` makes
the implement case an explicit exception:

```
   **`implement` is the exception**: an implementation question is a plan-gate
   question (§6.3), so its reply goes into `plan.md` and **tsf:plan** resumes —
   not the parking step. It folds the answer in, re-summarizes, and the ticket
   parks at `tsf:needs-plan-approval` again, so the human approves the changed
   plan before implementation continues.
```

A plan-format park after a `tsf:implement` return (the GH-41 case — implement writes
addenda) therefore cannot today "resume with the parking step". Either it accepts the
plan-gate detour (a second human gate for a markdown field, on an already-approved plan),
or the implement agent gains a new mode and the result-block outcome table gains a row.
Options in Open Questions below.

### P3 — the park sites, the comments, and the `tsf:answered` trap

**Five park sites, all `tsf:needs-human`, all in `cycle-write-phase.md` (263 lines).** No
site in that file ever sets `tsf:needs-answer`: a question park is an ordinary successful
step result flowing through the normal six-step write sequence, whose step 6 (`:59-60`)
sets the label from the agent's `next-label`.

| Site | Lines | Trigger | Comment posted | Tells the human what to do |
|------|-------|---------|----------------|----------------------------|
| A — failed write | 210-222 | a write in steps 4-6 returns `rejected`/`denied`/`failed`/`mismatch`/`no-credential` | **none** | no |
| B — parks without an agent result | 224-236 | state mismatch, or twice-invalid return — and in practice every `park` decision `cycle-dispatch.md` hands to Step 7 | one line: `**tsf · GH-<n>** — parked for a human: <the outcome line>. Details in the [journal](<link>).` | no |
| C — environment failed | 238-245 | `env_up`/`env_reset`/`env_check` non-zero | Site B's shape, outcome `environment failed: <script> — <its last output line>` | no |
| D — `prepare` failed | 246-259 | no branch, so no journal | `**tsf · GH-<n>** — parked for a human: the project's prepare script failed for branch <branch>: <its last output line>.` | no |
| E — push failed | 261-263 | a push in step 3 fails | Site D's shape with the push's `detail:` line | no |

There is **no template file for a park comment** — the strings live inline at the sites
above plus `result-block.md:181-183`. The licence to author them is `cycle.md:33-37`
(invariant 3: status comments are built "from result fields, outcome lines and scripts'
`detail:` lines, never from an artifact"). The journal side *is* templated, in
`journal-entry.md:130-231`.

The asymmetry the ticket is really about: an **agent's** `blocked` comment is required to
be actionable (`result-block.md:154-158` — "Its comment says what is wrong and what would
fix it"), while **no dispatcher-written park comment carries any such obligation**.

**The `tsf:answered` trap.** `README.md:335` describes the label as "You replied; the step
that asked picks it up"; `templates/github/tsf-comment-pickup.yml:44,51` sets it
automatically whenever a responder comments on a `tsf:needs-answer` /
`tsf:needs-plan-approval` ticket (which is how, per the ticket, the system taught it twice
in the same issue). But `cycle-dispatch.md:90-91` parks it:

```
  - `tsf:answered` (or a polled reply) but no journal, or the last entry's
    `Label` is neither `tsf:needs-answer` nor `tsf:needs-plan-approval`;
```

So a `tsf:needs-human` park plus `tsf:answered` is a state mismatch by construction.
`tsf:answered` is also absent from the step-to-label map (`cycle-dispatch.md:51-61`,
by design — "the label names no step of its own", `:67-70`) and from the `next-label`
vocabulary (`result-block.md:38`), so no agent can ever set it.

**The resume path that already exists** is row 3 (`cycle-dispatch.md:144-158`):
`tsf:queued` with a journal is the post-`needs-human` resume; steps that work from
artifacts alone dispatch immediately, while `implement`/`verify`/`gates`/`dossier`/
`review`/`landing` get a pure label correction plus a resume journal entry
(`journal-entry.md:147-166`) and the cycle ends, because a `tsf:queued` scan record carries
no pull-request data. A resume into `tsf:verify` opens a new episode (`:160-163`). Any P3
mapping of `tsf:answered` onto this path inherits all of that unchanged.

## Defect Mechanism

The ticket describes a defect; here is the mechanism, measured on the real artifacts
(extracted from `chat-sustainability` commits `b81f440` → `353f939` → `f116634` and run
against the shipped `plan.sh`).

**Intended behaviour.** `plan.sh`'s own header (`:29-32`): "An increment that yields no
criterion is an error, not an empty line: a gate given nothing to judge would pass
silently." And `:19-24`: `check` validates that every increment "carries a
`**Verification:**` or a `**Manual:**` field".

**Divergence 1 — the addendum is rejected.** The agent wrote, at `plan-original.md:223`,
a column-0 `**Verification (restated in full):**` followed by a blank line and a column-0
numbered list. `:181`'s regex matches neither the missing bullet nor the parenthetical, so
no `FIELD` record is emitted for the addendum; `addfields[1]` stays 0 (`:222`) and `:235`
fires. Measured:

```
plan-original : result: invalid — the addendum dated 2026-09-27 for increment 1
                restates no **Verification:** or **Manual:** field
plan-retry    : result: invalid — (identical)
plan-humanfix : result: ok
```

The retry (`353f939`) removed the parenthetical — a correct reading of the message — and
still failed on the missing bullet, confirming the ticket's central claim that the message
made the fix unguessable.

**Divergence 2 — the approved plan's increment was silently truncated.** This is the part
the ticket only reproduced synthetically. Increment 1's field at `plan-original.md:107`
is a proper bullet, its numbered list is indented (`:111-128`), then **`:129` is blank**
and `:130-132` continue the field with the run command. `:196` flushes at `:129`. Measured
on the plan with the addendum removed (so `criteria` would run at all):

```
criteria: 3, manual: 0, result: ok
criterion 1 ends: "...10. Re-saving the current address leaves an existing
                   invitation token and reset token in place."
grep -c 'npm run verify' → 2   (increments 2 and 3 only)
```

So the plan-compliance gate judged increment 1 against a criterion **missing its
verification command**, and `check` reported `ok`. The propagation path to the symptom:
`flush_field()` guards on `field_kind` not `field_text` (`:109`) → the truncated record is
still a record → `has[]` set on presence (`:225`) → `check` ok (`:246`) → `criteria`
writes the short criterion (`:270`) → the gate reports the criterion met on partial
evidence.

**Divergence 3 — the recovery attempt was refused.** At 05:12Z the human set
`tsf:answered` on a ticket whose last journal `Label` was `tsf:needs-human`.
`cycle-dispatch.md:90-91` classifies that as a human-side state mismatch, which
`:88` resolves as "park, never guess" → Site B → re-park. The label the pickup workflow
itself sets twice per question round is the one the dispatcher refuses here.

## Code References

- `plugins/tsf/scripts/plan.sh:181`, `:188` — the bullet-only field regexes
- `plugins/tsf/scripts/plan.sh:196` — the blank-line / other-bullet flush
- `plugins/tsf/scripts/plan.sh:198-202` — the indented-continuation join
- `plugins/tsf/scripts/plan.sh:108-114` — `flush_field()`, guarded on `field_kind` not text
- `plugins/tsf/scripts/plan.sh:214-238` — the `$PROBLEM` awk both modes share
- `plugins/tsf/scripts/plan.sh:225`, `:232`, `:235` — presence-only field tests and their messages
- `plugins/tsf/scripts/plan.sh:240`, `:250-254`, `:268-276`, `:286` — the mode divergence and criteria emission
- `plugins/tsf/references/templates/plan.md:65`, `:67`, `:95`, `:97` — the one canonical field form
- `plugins/tsf/commands/cycle.md:244-256` — the plan-check retry path (`note: <the detail line>`)
- `plugins/tsf/commands/cycle.md:229-233`, `:235-242`, `:258-259` — the other three invalidity detectors
- `plugins/tsf/commands/cycle.md:33-37` — invariant 3's licence for dispatcher status comments
- `plugins/tsf/references/templates/result-block.md:176-179` — the fixed twin's note
- `plugins/tsf/references/templates/result-block.md:14-18` — why the `## Return` pointer is load-bearing
- `plugins/tsf/references/templates/result-block.md:154-158` — `blocked` comments must say what would fix it
- `plugins/tsf/references/templates/result-block.md:180-183` — the twice-invalid park
- `plugins/tsf/references/cycle-dispatch.md:561-563` — the third (truncated) copy of the retry note
- `plugins/tsf/references/cycle-dispatch.md:88-100` — "park, never guess" and its six cases
- `plugins/tsf/references/cycle-dispatch.md:116-136` — row 1, and the implement exception at `:125-129`
- `plugins/tsf/references/cycle-dispatch.md:144-164` — row 3, the `tsf:queued` resume path
- `plugins/tsf/references/cycle-write-phase.md:210-222`, `:224-236`, `:238-245`, `:246-259`, `:261-263` — the five park sites
- `plugins/tsf/references/templates/journal-entry.md:136-145`, `:147-166`, `:215-230` — the park, resume and failed-write entry shapes
- `plugins/tsf/references/templates/journal-entry.md:125-128` — a parked ticket names the parking step
- `plugins/tsf/agents/implement.md:40` — `mode:` is `fresh`, `rework`, `fix` (no `resume`)
- `plugins/tsf/agents/plan.md:39` — `mode:` is `fresh` or `resume`
- `plugins/tsf/README.md:323-340` — the Labels table
- `plugins/tsf/templates/github/tsf-comment-pickup.yml:44`, `:51` — the workflow that sets `tsf:answered`
- `plugins/tsf/scripts/scan.sh:170-185` — the `--poll` fallback, restricted to the two question labels

## Impact Analysis

P1 changes a script three other contracts read from, so the ripple matters.

### Existing Usages Found

- `plugins/tsf/commands/cycle.md:248` — `plan.sh check` after a `tsf:plan` or
  `tsf:implement` return; `result: invalid` is an invalid return
- `plugins/tsf/references/cycle-dispatch.md` row 6 — `plan.sh criteria` before
  `tsf:manual-verify`
- `plugins/tsf/references/cycle-dispatch.md` row 8 — the criteria file is the **only**
  plan-derived input `tsf:plan-compliance` receives
- `plugins/tsf/agents/plan-compliance.md`, `agents/manual-verify.md` — consume the two
  output files by path

### Current Contract

- Input: a plan path. Output: four stdout lines (`increments:`/`addenda:` or
  `criteria:`/`manual:`, then `result:` and `detail:`), two written files, exit 0 for every
  reported outcome.
- Assumption held by consumers: a `check`-ok plan yields at least one criterion per
  increment — currently true only in the weak sense that a record exists, not that it has
  content.

### Adaptation Requirements

- No caller signature changes: the fix is internal to the parser plus one new
  `$PROBLEM` message class.
- Criteria text becomes **longer and more complete** for existing plans (increment 1 of
  GH-41 gains its run command). Nothing caps criterion length, and the gates receive the
  file by path, so no payload limit is crossed.
- A new failure class ("an increment's field states nothing") turns some previously
  `check`-ok plans invalid. Since `check` runs on the factory's own fresh output, the
  blast radius is a plan the factory is about to hand over, not stored history — and P2's
  retry-with-shape is the intended handler.

### Backward Compatibility Options

- Option A: apply the substance test in `$PROBLEM` for both modes (the ticket's "`check`
  and `criteria` never disagree"). Cost: a formerly-passing malformed plan now parks
  instead of silently mis-verifying — which is the point.
- Option B: enforce it only in `criteria`. Rejected by the ticket's acceptance criteria:
  it reinstates the disagreement.

## Architecture Documentation

- **A script is the only parser.** CLAUDE.md's "the plan is parsed by a script, never by
  the dispatcher" (TP-0036) exists because `cycle.md` invariant 3 forbids the dispatcher
  reading a plan's body. The gates get **paths**. Any P1 change therefore stays inside
  `plan.sh`; no tolerance may migrate into prose.
- **Fenced blocks are stripped before any heading is matched** — the TP-0033 lesson,
  established against this repository's own corpus, restated in `plan.sh:44-47`.
- **Contract errors must show the shape, not name the field** is the generalization the
  ticket asks to record in CLAUDE.md; `result-block.md:176-179` is the existing instance
  and `cycle.md:252` the counter-instance.
- **Labels are a cache; the journal's `Next step` is the state** (CLAUDE.md, TP-0034a).
  Every P3 option must keep the resumed state derivable from the journal on disk, not
  from the label alone.
- **Same-commit spans this ticket touches**: the plan contract
  (`plan.sh` + `templates/plan.md` + `agents/{plan,implement,plan-compliance,manual-verify}.md`),
  the result block (nine files), the park sequences
  (`cycle.md` + `cycle-dispatch.md` + `cycle-write-phase.md` + `journal-entry.md`), and —
  if the label vocabulary shifts — `README.md` and `commands/init.md:309-324`.

## Historical Context (from thoughts/)

- `thoughts/shared/plans/2026-09-20-TP-0036-tsf-review-corrections.md` — Phase 8 introduced
  `plan.sh`, the increment/addendum contract and the "fenced blocks stripped first" rule.
  The bullet-only regex and the blank-line flush date from there.
- `thoughts/shared/research/2026-09-27-TP-0039-tsf-first-run-corrections.md` and its plan —
  C1 fixed the *result-block* retry note by pointing at both the template and the agent's
  own `## Return` section. TP-0043 P2 is the same correction applied to the second path;
  TP-0039 never touched `plan.sh`, which is why tsf 1.2.0 would have failed identically.
- `thoughts/shared/tickets/TP-0037-tsf-final-review-corrections.md` — established that
  every worker's `## Return` carries a filled-in skeleton, and that the closed `Next step`
  vocabulary has no wildcard row (the defect class P2's new park must not reintroduce).
- `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md` — the original
  parking mechanics and label states.
- `thoughts/shared/tickets/TP-0040/0041/0042` — the sibling tickets from the same run,
  scoped out here (plan quality, challenge phase, verification depth).

## Related Research

- `thoughts/shared/research/2026-09-27-TP-0039-tsf-first-run-corrections.md`
- `thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md`
- `thoughts/shared/research/2026-09-21-TP-0037-tsf-final-review-corrections.md`

## Open Questions

Three decisions need a human, matching the ticket's own deferrals.

1. **P2 — how a plan-format question park resumes** (the ticket's Question-for-Planning 2).
   The obstacle is factual: implement has no `resume` mode and row 1 deliberately routes an
   implement park's reply through `tsf:plan` plus a second approval gate.
   - *Option A — `Next step: plan` in both cases.* The plan agent owns `plan.md` and
     already has `mode: resume`. No new mode, no new outcome row. Cost: an implement-time
     addendum park drags an already-approved plan back through
     `tsf:needs-plan-approval` — one extra human gesture for a markdown field.
   - *Option B — `Next step` = the parking step + a distinct journal outcome row 1 keys
     on + a narrow `resume` mode on the implement agent.* No extra gate; matches the
     ticket's "the reply is folded by the parking step". Cost: a new mode, a new
     `result-block.md` outcome row, and a row-1 exception to the existing exception.
   - Either way, a second question worth settling: should the plan-format retry get its
     own small bound (say two attempts, both carrying the shape) so the question park
     becomes rare, rather than the single re-dispatch it shares with the other three
     detectors?
2. **P3 — whether `tsf:answered` on a `tsf:needs-human` park requires a reply**
   (the ticket's stated Open Question). A `needs-human` park is usually cleared by an
   *action*, not an answer, so requiring a responder comment would re-park the honest
   case; but `cycle-dispatch.md:94-95` currently parks a reply-less `tsf:answered` on
   purpose. Options: treat it exactly like `tsf:queued` (row 3, reply optional, folded
   when present), or require a reply and keep `tsf:queued` as the action-only signal.
3. **P1 — what "trivial" means** in "`check` fails a plan whose increment would extract
   to an empty or trivial criterion". A mechanical empty-after-trim test (whitespace and
   punctuation only) is safe and explainable; any word-count or "looks like a stub"
   heuristic risks rejecting a legitimately terse criterion such as ``npm test`` passes`.
   Note that with the capture fix the observed failure mode (`the suite asserts:` with the
   body dropped) stops arising, so the test is a backstop rather than the primary fix.
