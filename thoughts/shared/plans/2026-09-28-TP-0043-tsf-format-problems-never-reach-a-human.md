# TP-0043 — A format problem in a factory artifact must never reach a human: Implementation Plan

## Overview

Three compounding failures from the chat-sustainability GH-41 run, fixed in one release:
the plan parser is brittle where a reader would not be (**P1**), a plan that does not parse
escalates to a human who neither wrote it nor owns its format (**P2**), and park comments
diagnose instead of instructing while a human's reasonable recovery gesture is refused
(**P3**).

The four decisions taken at the planning checkpoint:

1. **P2 resume** — the parking step folds the reply. `tsf:implement` gains a narrow
   `format-fix` mode; `tsf:plan` needs nothing new (its `mode: resume` already folds a
   reply into `plan.md`, and a plan-time format park has not yet reached approval).
2. **Retry bound** — the plan-check path gets **two** re-dispatches of its own, both
   carrying the required shape, instead of the single one it shares with the other three
   invalidity detectors.
3. **P3 `tsf:answered`** — on a `tsf:needs-human` park it resumes exactly as `tsf:queued`
   does, with no reply required; a reply is folded when one exists and the derived step has
   a resume mode.
4. **P1 "trivial"** — mechanically "empty after trimming whitespace and markdown
   punctuation". No length floor, no stub heuristic.

## Current State Analysis

`plugins/tsf/scripts/plan.sh` (289 lines) runs one awk parser into a tab-separated stream,
then one `$PROBLEM` validation awk, and only then diverges by mode at `:240`. Two defects
live in the parser:

- **Shape** — `:181` / `:188` require a hyphen bullet (`/^[ \t]*- +\*\*Verification:?\*\*:?/`).
  A paragraph-form marker and a qualifier inside the bold span
  (`**Verification (restated in full):**`) are both rejected. Trailing text *after* the
  colon is already tolerated.
- **Truncation, silently** — `:196` flushes the field at the first blank line, and `:198`
  requires indentation for a continuation. `flush_field()` (`:108-114`) guards on
  `field_kind`, not on the text, so an empty or truncated field still emits a `FIELD`
  record; `:225` sets `has[]` on mere presence, so `check` says `ok` and `criteria` writes
  a gutted criterion.

Measured on the real GH-41 artifacts (research, Defect Mechanism): the addendum is
rejected on both shape counts, **and** the approved plan's increment 1 lost its
`npm run verify` command to the blank-line flush while `check` reported `ok`.

On the escalation side: `cycle.md:244-256` forwards `plan.sh`'s `detail:` line verbatim as
the whole retry note, calling it "the only thing the agent needs" — which the run
disproved. `result-block.md:176-179` is the fixed twin, naming both the template and the
agent's own `## Return` section. A twice-invalid return parks `tsf:needs-human`
(`result-block.md:180-183`) through `cycle-write-phase.md`'s Site B, whose comment states
the outcome line and links the journal but tells the human nothing to do. And
`cycle-dispatch.md:90-91` parks `tsf:answered` whenever the last journal `Label` is not one
of the two question labels — so the label the pickup workflow sets automatically is refused
on a `needs-human` park.

## Desired End State

- The GH-41 addendum **as the agent originally wrote it** parses, with all ten assertions
  and the run command in the criteria file.
- No plan can pass `check` while `criteria` would emit an empty criterion.
- A plan-format problem is repaired by the factory within two re-dispatches whose note
  shows the required shape; if it still fails, the ticket parks as a **question**
  (`tsf:needs-answer`) answerable on the issue, and the parking step folds the reply.
- Every park comment states what happened, what it means, what to do and which label to
  set; the diagnostic string stays in the journal wherever a journal exists.
- `tsf:answered` on a `tsf:needs-human` park resumes the ticket instead of re-parking it.
- `claude plugin validate ./plugins/tsf` passes; tsf is released as **1.3.0** with its tag.

### Key Discoveries

- `check` and `criteria` already share the `$PROBLEM` awk (`plan.sh:214-238`), so the
  substance test belongs there and the two agree by construction — not by duplicated logic
  (research, "Where the substance test belongs").
- The plan **template needs no change**: `templates/plan.md:65`, `:67`, `:95`, `:97` carry
  the one canonical form, and the 2026-09-28 decision keeps it that way.
- `implement` writes addenda in **all three** modes (`agents/implement.md:88` fresh, `:118`
  rework, `:133` fix), so a format park is reachable from any of them — which is why the
  park entry must record where the ticket was heading.
- `result-block.md:99` already has the row `implement | parked | tsf:needs-answer | implement`,
  and `:97`/`:98` already have both `continued` rows. The format park is
  **dispatcher-written**, so it needs no new outcome row at all.
- `cycle-dispatch.md:125-129` routes an `implement` park's reply through `tsf:plan` and a
  second approval gate. A format park must override that: the plan was already approved and
  only a markdown field is wrong.
- Three places describe the retry note (`cycle.md:252`, `result-block.md:176-179`,
  `cycle-dispatch.md:561-563`) and the third is a truncated copy of the second.

## What We're NOT Doing

- **No template change for P1.** The contract keeps showing one canonical field form; the
  tolerance is the parser's business (ticket decision, 2026-09-28).
- **No length floor or stub heuristic** in the substance test.
- **No new label.** `tsf:needs-answer` carries the format question; the vocabulary stays at
  fourteen.
- **No change to the comment-pickup workflow** (ticket, Out of Scope).
- **Not removing the plan check** — the dispatcher may not read artifact content, so
  something mechanical must gate the handoff.
- **Not touching** plan quality, the challenge phase or verification depth (TP-0040/41/42),
  nor the `prek` hook problem (`plugins/tsf/TODO.md`).
- **No reply-folding for the six pull-request-dependent steps** on a `needs-human` resume —
  they get row 3's existing label correction unchanged.

## Implementation Approach

Six phases, ordered so each is independently verifiable and the riskiest mechanical change
(the parser) lands first with a real corpus behind it. P1 is pure script work. P2 splits
into the cheap fix (the note) and the structural one (the question park). P3 splits the same
way (comment shape, then the label semantics). Phase 6 carries the repo-level rules and the
release.

The fixture corpus for P1 lives in the scratchpad, extracted from `chat-sustainability`:

| Fixture | Source | Current | Required after Phase 1 |
|---|---|---|---|
| `plan-original.md` | `b81f440` — as the agent wrote it | `invalid` | `ok`, 10 assertions + run command in criteria |
| `plan-retry.md` | `353f939` — the agent's one retry | `invalid` | `ok` |
| `plan-humanfix.md` | `f116634` — the manual repair | `ok` | `ok`, unchanged |
| `plan-gh40.md` | GH-40's plan | `ok` | `ok`, unchanged |

Re-extract with:

```bash
SC=/private/tmp/claude-501/-Users-toby-code-work-toby-plugins/d839bf5f-6f73-40ff-8939-a01441ef0023/scratchpad/gh41
git -C /Users/toby/code/work/chat-sustainability show "b81f440:thoughts/factory/GH-41/plan.md" > "$SC/plan-original.md"
git -C /Users/toby/code/work/chat-sustainability show "353f939:thoughts/factory/GH-41/plan.md" > "$SC/plan-retry.md"
git -C /Users/toby/code/work/chat-sustainability show "f116634:thoughts/factory/GH-41/plan.md" > "$SC/plan-humanfix.md"
git -C /Users/toby/code/work/chat-sustainability show "f116634:thoughts/factory/GH-40/plan.md" > "$SC/plan-gh40.md"
```

---

## Phase 1: P1 — liberal in shape, strict in substance

### Overview

Make `plan.sh` recognize the field in any form a reader would, capture its whole text, and
refuse a field that states nothing — with `check` and `criteria` sharing one verdict.

### Changes Required

#### 1. Field recognition

**File**: `plugins/tsf/scripts/plan.sh`
**Changes**: replace the two field-opening rules (`:181-194`) so each matches the marker
**with or without** a leading bullet and **with or without** a trailing qualifier inside
the bold span. One shared pattern per kind, used for both the `match` and the `sub`.

The marker to accept, in awk ERE terms: optional indent, optionally `- ` / `* ` / `+ `,
then `**`, then the word, then optionally anything that is not `*` (the qualifier, e.g.
` (restated in full)`), then an optional `:`, then `**`, then an optional `:`.

```awk
    # Fields of the current increment or addendum. The marker is accepted with or
    # without a bullet and with or without a qualifier inside the bold span --
    # the template shows one canonical form, and this absorbs the drift a writing
    # agent produces anyway (TP-0043).
    if (match(line, /^[ \t]*([-*+] +)?\*\*Verification[^*]*\*\*:?/)) {
        flush_field()
        if (current == "") next
        t = line; sub(/^[ \t]*([-*+] +)?\*\*Verification[^*]*\*\*:? */, "", t)
        field_inc = current; field_kind = "verification"; field_text = t
        next
    }
```

and the same for `Manual`. Keep both rules' order and structure otherwise.

**Guard against over-matching**: `[^*]*` must not let `**Verification**` swallow a
following bold run. It cannot — `[^*]` excludes the asterisk — but a line such as
`- **Verification of the cache:**` now matches as the field. That is intended: it is the
qualifier case.

#### 2. Field capture

**File**: `plugins/tsf/scripts/plan.sh`
**Changes**: the field ends at the next **field marker**, the next **other bold bullet**,
or the next **heading / section** — no longer at a blank line, and no longer at a
non-indented continuation. Replace `:195-203`:

```awk
    # Any other bold bullet ends the field being collected -- an increment's
    # **Depends on:** or **Where:** is the next field, not this one's body.
    if (line ~ /^[ \t]*[-*+] +\*\*/) { flush_field(); next }
    # Everything else, blank lines and column-0 prose included, belongs to the
    # field being collected: a restatement is a list or several paragraphs as
    # often as it is one sentence, and stopping at the first blank line dropped
    # its body while still reporting ok (TP-0043).
    if (field_kind != "") {
        t = line; gsub(/^[ \t]+|[ \t]+$/, "", t)
        if (t != "") field_text = (field_text == "" ? t : field_text " " t)
        next
    }
```

A blank line is now absorbed (contributing nothing, since `t == ""`), so a field spans it;
the headings and section rules above already flush before changing `current`, and fenced
blocks stay invisible (`:120-129`) with the field open across them, as today.

**What must keep working** (verified against the corpus in research): `- **Depends on:**`
still terminates the Verification field in GH-41 increments 2 and 3, and the `## Addenda` /
`### Increment` rules still flush first.

#### 3. The substance test, in the shared validation

**File**: `plugins/tsf/scripts/plan.sh`
**Changes**: in the `$PROBLEM` awk (`:214-238`), stop treating a `FIELD` record as
evidence by presence. Record the text, and in `END` refuse a field whose text is empty
after trimming whitespace and markdown punctuation.

```awk
    $1 == "FIELD" {
        t = $4
        gsub(/[ \t`*_:;,.!?()\[\]-]/, "", t)
        if (t != "") {
            has[$2] = 1
            if ($2 in addcount && addcount[$2] > 0) addfields[$2] = 1
        } else {
            empty[$2 SUBSEP $3] = 1
        }
        next
    }
```

and, in `END`, before the existing per-increment loop's verdict, name the empty field
explicitly so the message is honest rather than claiming the field is absent:

```awk
        for (i = 1; i <= count; i++) {
            n = order[i]
            if ((n SUBSEP "verification") in empty || (n SUBSEP "manual") in empty) {
                if (!(n in has)) {
                    print "increment " n " (" name[n] ") states a **Verification:** or **Manual:** field with no content"
                    exit
                }
            }
            if (!(n in has)) { print "increment " n " (" name[n] ") has neither a **Verification:** nor a **Manual:** field"; exit }
        }
```

The ordering matters: an increment that has one good field and one empty one is **not** an
error (the good field yields the criterion); an increment whose only field is empty is.

**Why here**: both modes run this awk before `case "$MODE"` (`:240`), and `criteria`
refuses on a non-empty `$PROBLEM` (`:250-254`). So `check` validates exactly the text the
extraction will produce — the ticket's "`check` and `criteria` must agree" holds by
construction, not by a second implementation.

#### 4. `criteria` must not emit an empty criterion either

**File**: `plugins/tsf/scripts/plan.sh`
**Changes**: in the `criteria` awk (`:257-281`), skip a `(inc, kind)` whose text is empty
after the same trim, so a belt-and-braces path cannot write `N. Increment 1 (x): `. With
Phase 1.3 in place this is unreachable; leave it as the guard that keeps the two honest if
the validation ever loosens.

#### 5. Header documentation

**File**: `plugins/tsf/scripts/plan.sh`
**Changes**: extend the header block (`:19-47`) — the script's documentation is its own
header, there is no second copy. State: the marker is accepted with or without a bullet and
with or without a qualifier, while the template shows one canonical form; a field's text
runs to the next field, bold bullet, heading or section; a field that states nothing is
`invalid` in **both** modes.

### Success Criteria

#### Automated Verification

- [x] `plugins/tsf/scripts/plan.sh check --plan "$SC/plan-original.md"` → `result: ok`
- [x] `plugins/tsf/scripts/plan.sh check --plan "$SC/plan-retry.md"` → `result: ok`
- [x] `plugins/tsf/scripts/plan.sh check --plan "$SC/plan-humanfix.md"` → `result: ok`
- [x] `plugins/tsf/scripts/plan.sh check --plan "$SC/plan-gh40.md"` → `result: ok` with
      `increments: 2`, `addenda: 0` (unchanged)
- [x] `criteria` on `plan-original.md` writes 3 criteria whose criterion 1 contains **all
      ten** assertion markers and the `npm run verify` run command
- [x] `criteria` on `plan-original.md` shows increment 1's own field is no longer truncated:
      `grep -c 'npm run verify'` over the criteria file is **3**, not 2
- [x] A synthetic plan whose only increment has `- **Verification:**` and nothing after it
      → `check` reports `invalid` with the "states a … field with no content" detail, and
      `criteria` reports the same detail with `criteria: 0`
- [x] A synthetic plan with a paragraph-form `**Manual:**` spanning a blank line → `ok`,
      and the manual item's full text reaches `--manual-out`
- [x] A synthetic plan whose increment has an empty `**Verification:**` **and** a filled
      `**Manual:**` → `ok` with one criterion (the manual one)
- [x] `- **Depends on:**` still terminates a field: criterion 2 of `plan-original.md`
      contains no "Depends on" text
- [x] An in-fence `### Increment 9: fake` heading is still invisible (`increments:`
      unchanged)
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification

- [x] Reading the new header block, the tolerance is understandable without reading the awk

### Implementation log

**Status**: complete
**Base commit**: `77bfc170e6b60ece77bfae7a079ac4197aed9198`
**Phase commit**: this commit

**What was done**: all five changes as planned, with one improvement over the plan's
sketch. Instead of re-deriving emptiness in each reader, the parser now stamps every
`FIELD` record with a **substance flag** (`substantive()` in the parser awk, declaring its
temporary local so it cannot collide with the main program's `t`), and both the validation
awk and the criteria awk key on that one flag. The record became
`FIELD <n> <kind> <flag> <text>` with the text still **last**, so a tab inside the text
cannot shift the flag. That is a stronger form of "check and criteria never disagree" than
the plan described: there is now one implementation of "empty", not two agreeing ones.

**Verification results**: every automated criterion passed.

- The four real fixtures all report `ok` (`plan-original` and `plan-retry` were `invalid`
  before this phase).
- `criteria` on `plan-original.md` writes 3 criteria; criterion 1 carries all **10**
  assertion markers and ends with the `npm run verify` run command.
- `grep -c 'npm run verify'` over the criteria file is **3** (was 2): increment 1's own
  field is no longer truncated either, which is the defect the research measured on the
  approved plan.
- `syn-empty` reports `invalid` in **both** modes with the identical detail line
  ("states a **Verification:** or **Manual:** field with no content").
- `syn-paragraph` (paragraph-form `**Manual (restated in full):**` spanning a blank line)
  is `ok` and its full text, list and closing sentence included, reaches `--manual-out`.
- `syn-mixed` (empty Verification beside a filled Manual) is `ok` with one criterion.
- `syn-fence` keeps `increments: 2` — the in-fence `### Increment 9: fake` stays invisible —
  and accepts the `*` bullet.
- `Depends on` does not leak into criterion 2 of `plan-original.md`.
- `claude plugin validate ./plugins/tsf` and `claude plugin validate .` pass.

**Issue worth recording**: capturing to the next field/bullet/heading means trailing prose
*after* an increment's last field is appended to that field — visible in `syn-fence`, whose
criterion 1 reads ``bun test` passes The plan quotes the format:`. This is the trade-off
the ticket chose deliberately ("capture its text until the next field, heading or section
rather than the first blank line"), and it does not arise in the real corpus, where every
increment ends with a bold bullet (`- **Depends on:**`) or the next heading. Recorded rather
than worked around: a narrower rule would reinstate the truncation this phase exists to fix.

---

## Phase 2: P2a — the retry note carries the shape, and gets two attempts

### Overview

Make the plan-check retry note show the required shape instead of only naming the field,
and give that path its own bound of two re-dispatches.

### Changes Required

#### 1. The plan-check path in the dispatcher

**File**: `plugins/tsf/commands/cycle.md` (Step 6, `:244-256`)
**Changes**: replace the "pass it on verbatim, it is the only thing the agent needs to fix
it" instruction. The note keeps the `detail:` line **and** adds the canonical field
skeleton, quoted in the command's own prose (plugin text, not artifact content — invariant
3 is untouched). Give this detector **two** re-dispatches, each with the same note, then
the question park of Phase 3.

The note's required content, as `cycle.md` must state it:

```
note: plan.sh check rejected the plan — <the detail line>. Restate the field in
the canonical form the plan template shows: a bullet whose bold span is exactly
`**Verification:**` or `**Manual:**` with no other text inside it, the field's
text starting on the same line. The shape is in
${CLAUDE_PLUGIN_ROOT}/references/templates/plan.md and in your own ## Return
section; read it and restate the field exactly.
```

Note the asymmetry and state it in one clause: the **parser** tolerates variants (Phase 1),
the **note** names one shape. A note that listed the tolerated forms would invite a choice.

#### 2. The truncated third copy

**File**: `plugins/tsf/references/cycle-dispatch.md` (`:561-563`, "The spawn payload")
**Changes**: the plan-parse alternative it mentions now points at the shape-carrying note
and its two attempts, rather than at "that check's `detail:` line".

#### 3. Keep the other three detectors on one re-dispatch

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: make explicit that the two-attempt bound is the plan-check path's alone —
a malformed result block, a missing artifact and a wrong branch keep the single
re-dispatch `result-block.md:176-183` defines. One sentence, so a later reader does not
"tidy" the four into one bound.

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `grep -n 'the only thing the agent needs' plugins/tsf/` returns nothing
- [x] The canonical skeleton appears in `cycle.md`'s note and the file still says the
      template shows one form

#### Manual Verification

- [x] Reading Step 6 alone, it is unambiguous how many re-dispatches each of the four
      invalidity detectors gets
- [x] The note, read as an agent would, is sufficient to fix the GH-41 addendum without
      guessing — it names the bullet *and* forbids text inside the bold span, which is
      exactly what commit `353f939` got wrong

### Implementation log

**Status**: complete
**Phase commit**: this commit

**What was done**: `cycle.md` Step 6's plan-check paragraph rewritten — the note now
carries the `detail:` line **and** the canonical field skeleton, the two-re-dispatch bound
is stated, and the asymmetry (parser liberal, note single-form) is written down with the
reason, so a later reader does not reconcile the two. The `result-block.md` pointer at the
top of Step 6 now says the single re-dispatch has one exception rather than implying it
covers all four detectors. `cycle-dispatch.md`'s truncated third copy points at Step 6's
note instead of at the bare `detail:` line and records the two-attempt difference.

**Verification results**: all three automated criteria pass;
`grep -rn 'the only thing the agent needs' plugins/tsf/` is empty. Both manual items hold:
the note names the bullet *and* forbids text inside the bold span, which are precisely the
two things commit `353f939` could not guess from the old message.

**Deviation from the plan**: the plan's Change 3 anticipated a separate sentence scoping the
single re-dispatch to the other three detectors. It landed as a parenthetical in the
existing `result-block.md` pointer plus the explicit paragraph in the note — same effect,
one fewer place to drift. The park wording still reads "parks the ticket"; Phase 3 turns it
into the question park.

---

## Phase 3: P2b — a plan that will not parse becomes a question, not an escalation

### Overview

After two failed re-dispatches, park the ticket `tsf:needs-answer` with the offending text
and the required shape, and let the parking step fold the human's reply. `tsf:plan` needs
nothing new; `tsf:implement` gains a narrow `format-fix` mode.

### Changes Required

#### 1. The format-park journal entry

**File**: `plugins/tsf/references/templates/journal-entry.md`
**Changes**: add a sixth dispatcher-only entry shape under "Entries the dispatcher writes
on its own", and document its one conditional line.

```markdown
## Cycle [now] — step: [plan | implement]
- Outcome: the plan does not parse after two corrections: [the detail line]; parked as a question
- Questions asked: 1 (parked)
- Commits: [the agent's commits, if any | none]
- Label: tsf:needs-answer
- Resume at: [verify | implement | plan]   (only on a plan-format park entry)
- Next step: [plan | implement]
```

`Next step` is the **parking step**, as every park entry's is
(`journal-entry.md:125-128`). `- Resume at:` is the rejected return's own `next-step` — the
step the ticket was heading for before the check refused it. It is load-bearing in exactly
the way `- Attempt:` is (TP-0037): `implement` writes addenda in fresh, rework **and** fix
mode (`agents/implement.md:88`, `:118`, `:133`), so without it a resumed format park cannot
tell a mid-batch fresh return from a fix return, and would restart fresh mode on a plan
whose increments are all built.

For a **plan-time** park, `- Resume at:` is `implement` (what a `tsf:plan` return intends)
and is recorded for symmetry; the plan agent's own resume re-derives it anyway.

#### 2. Row 1 learns the format park

**File**: `plugins/tsf/references/cycle-dispatch.md` (row 1, `:116-136`)
**Changes**: add a clause **before** the existing implement exception:

- When the last entry carries `- Resume at:` (a plan-format park), the parking step resumes
  **directly**: `plan` → **tsf:plan** `mode: resume`; `implement` → **tsf:implement**
  `mode: format-fix`, with `reply:` and `resume-to:` set to the `- Resume at:` value. The
  implement exception at `:125-129` **does not apply** — a format park is not an
  implementation question, the plan is already approved, and routing a markdown repair
  through `tsf:needs-plan-approval` would spend a second human gesture on a field.

Also extend the validation section (`:88-96`): a `tsf:answered` whose last entry `Label` is
`tsf:needs-answer` is already legal, so the format park needs no exemption there — state
that explicitly so the entry is not mistaken for a mismatch.

#### 3. The park sequence

**File**: `plugins/tsf/references/cycle-write-phase.md`
**Changes**: add a park sequence for the format question, beside the five existing sites.
It is **not** a `tsf:needs-human` park: journal entry (the shape above), commit, push,
marker, then a comment the dispatcher composes from the `detail:` line plus the canonical
skeleton and the reply instruction, then `--set tsf:needs-answer`.

The comment must carry, per P3's rule and the ticket's "answerable from the issue": what
happened in plain language, that the code is built and pushed and only a field in the plan
document is malformed, the offending text as the `detail:` line names it, the shape it must
take, and the instruction to reply on the issue (naming the responders, as
`question-comment.md:48` does).

#### 4. `tsf:implement` gains `format-fix` mode

**File**: `plugins/tsf/agents/implement.md`
**Changes**:

- `## What you receive` (`:40`): `mode:` becomes `fresh`, `rework`, `fix` or `format-fix`;
  add `reply:` (the responder's guidance, `format-fix` only) and `resume-to:`
  (`verify` or `implement`, `format-fix` only).
- `## Process`: a fourth subsection, deliberately narrow:

  1. Re-read `plan.md`. The field the check rejected is one you wrote; the `note:` and the
     human's `reply:` say what is wrong and what shape it must take.
  2. Restate **that field only**, in the canonical form the plan template shows. Change no
     increment, no code, no other field, and build nothing — the increments this ticket
     needed are already built and pushed.
  3. Commit `plan.md` alone (`docs(GH-<n>): restate the increment <n> addendum field`).
  4. Return `continued` with `next-step:` = `resume-to:` and the matching label.

- `## Return`: extend the filled-in skeleton's mode guidance — `format-fix` returns the
  `continued` row that `resume-to:` names, carries no `- Increments:` line, and blocks to
  `resume-to:` as well if the field cannot be repaired.

#### 5. The result block's mode prose

**File**: `plugins/tsf/references/templates/result-block.md`
**Changes**: no new row — the format park is dispatcher-written, and `:97`/`:98` already
carry both `continued` rows. Update the prose only:

- `:133-139` currently says "only fresh mode may use the second one" of implement's two
  `continued` rows. `format-fix` may use **either**, as `resume-to:` dictates.
- `:125-131` enumerates implement's blocked rows "one per mode": add `format-fix` →
  whichever of `implement` / `verify` `resume-to:` named.

Per the file's own header (`:7-18`) this is a result-block change, so the same-commit span
covers `agents/implement.md`, `commands/cycle.md` and `references/cycle-write-phase.md` —
all already in this phase.

#### 6. The dispatcher's MANDATORY OUTPUT

**File**: `plugins/tsf/commands/cycle.md` (`:235-242`)
**Changes**: the "at least one new commit for implement" requirement is satisfied by the
plan-repair commit; state that a `format-fix` return is **not** subject to the fresh-mode
`pr-body.md` requirement (the earlier cycle already committed it).

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `grep -rn 'format-fix' plugins/tsf/` shows it in `agents/implement.md`,
      `commands/cycle.md`, `references/cycle-dispatch.md`,
      `references/cycle-write-phase.md`, `references/templates/result-block.md` and
      `references/templates/journal-entry.md` — the whole span, no file missing
- [x] `grep -rn 'Resume at:' plugins/tsf/` shows it in `journal-entry.md` and
      `cycle-dispatch.md` (writer and reader)
- [x] No new label: `grep -c 'tsf:' plugins/tsf/README.md` label table still lists 14

#### Manual Verification

- [x] Walk the GH-41 scenario on paper against the edited files: implement returns, check
      fails twice, the park entry records `Resume at: verify`, the human replies, row 1
      dispatches `format-fix`, the agent repairs the field and returns `verify` — with no
      second approval gate and no branch checkout by a human
- [x] Walk a fresh mid-batch format park: `Resume at: implement`, and the next cycle
      continues the plan rather than opening a pull request
- [x] Confirm `tsf:plan`'s existing `mode: resume` needs no edit for a plan-time park

### Implementation log

**Status**: complete
**Phase commit**: this commit

**What was done**: all six changes as planned — the format-park entry shape with its
`- Resume at:` line, row 1's override of the implement exception, the format-question park
sequence, `format-fix` mode on the implement agent, the result-block mode prose, and the
MANDATORY OUTPUT clause. Two additions beyond the plan, both found by the paper
walkthroughs.

**The gap the first walkthrough caught**: "Opening the pull request" triggered on
`mode: fresh` **and** `next-step: verify`. A format park on the last batch happens at
Step 6, *before* the write phase reaches the pull-request step — so the pull request was
never opened, and the resumed `format-fix` return, not being fresh mode, would not have
opened it either. The ticket would have reached `tsf:verify` with `pr: none` and stalled at
row 6. Fixed by extending the trigger to a format-fix return whose `resume-to:` was
`verify`, with the reason stated; `pr-create` already tolerates `exists`, which is what
makes the step safe to reach twice. Note the invariant that keeps `pr-body.md` present
there: MANDATORY OUTPUT is checked **before** the plan check, so a fresh last batch missing
that file is already invalid on the earlier ground and never reaches a format park.

**The second addition**: a `format-fix` return folds a human's reply into `plan.md`, which
is exactly the case `question-comment.md`'s **resume confirmation line** exists for, so the
agent's comment now opens with it instead of being a plain outcome comment.

**Verification results**: `claude plugin validate ./plugins/tsf` passes; `format-fix`
appears in all six files of the span and `- Resume at:` in both its writer and its readers;
the label table is still fourteen rows. The three paper walkthroughs hold:

- *GH-41 (last batch)* — park records `Resume at: verify`, `Next step: implement`,
  `Label: tsf:needs-answer`; reply → row 1 reads `- Resume at:` → `tsf:implement`
  `mode: format-fix` → field restated, plan commit, `next-step: verify` → the pull request
  opens in that cycle. No second approval, no checkout.
- *Fresh mid-batch* — `Resume at: implement`, no pull request opened, the next cycle
  continues the plan. The comment is posted rather than skipped, because the skip rule is
  fresh mode's and a human who just replied deserves the confirmation.
- *Plan-time park* — `tsf:plan` `mode: resume` folds the reply and re-parks at
  `tsf:needs-plan-approval`, which is correct rather than wasteful: a plan-time park has
  not reached approval yet, so no gesture is spent twice. The plan agent needed no edit, as
  the plan predicted.

---

## Phase 4: P3a — park comments are instructions

### Overview

Give every park comment one shape that states what happened, what it means, what to do and
which label to set, and keep the diagnostic in the journal wherever a journal exists.

### Changes Required

#### 1. A park-comment template

**File**: `plugins/tsf/references/templates/park-comment.md` (new)
**Changes**: a point-of-use reference, in the style of `question-comment.md`, defining one
shape for a dispatcher-written park comment:

```markdown
**tsf · GH-[n] · parked**

[What happened, one or two plain sentences. No script names, no label names, no
result-block or journal vocabulary.]

[What it means for the ticket: what is done and pushed, what is not, and what the
factory will do when it resumes.]

**What to do**
1. [The concrete action, if any — or "nothing to fix; the ticket only needs releasing".]
2. Set the label `[tsf:queued | tsf:answered]` on this issue to hand it back to the
   factory.

[Details in the [journal](<link>). — omitted when no journal reached GitHub, in which
case the diagnostic goes inline above.]
```

Plus the rules: plain markdown, no angle brackets (the `question-comment.md:24-25`
constraint), the diagnostic string belongs in the journal — inline **only** when no journal
reached GitHub (`prepare` and push failures), and the comment never names a script, a
`result:` value or a label the human is not being asked to set.

#### 2. The five park sites adopt it

**File**: `plugins/tsf/references/cycle-write-phase.md`
**Changes**: each site reads the template at the point of use and composes its comment
from it, replacing the current inline strings:

- **Site A (failed write, `:210-222`)** — currently posts **no comment at all**. It now
  posts one: a failed GitHub write is precisely the case a human must act on, and silence
  leaves the ticket parked with no trace on the issue. Keep "best effort" — a comment that
  fails for the same reason the write did is reported, not retried.
- **Site B (parks without an agent result, `:224-236`)** — the one-line
  `parked for a human: <the outcome line>` becomes the template's shape. The outcome line
  stays in the journal.
- **Site C (environment failed, `:238-245`)** — same, with the failing script named in
  plain language ("the project's environment scripts could not bring the stack up").
- **Site D (`prepare` failed, `:246-259`)** — the template with the diagnostic inline and
  no journal link, as today.
- **Site E (push failed, `:261-263`)** — the template with the push's `detail:` inline.

#### 3. The twice-invalid park comment

**File**: `plugins/tsf/references/templates/result-block.md` (`:180-183`)
**Changes**: its "one-line comment of the dispatcher's own saying the step's agent failed
twice and linking the journal" now points at `park-comment.md` instead of specifying its
own one-liner.

#### 4. The CLAUDE.md layout listing

**File**: `CLAUDE.md`
**Changes**: `references/templates/*.md` in the tsf layout block lists the templates by
name; add `park-comment`.

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `plugins/tsf/references/templates/park-comment.md` exists and is referenced from
      `cycle-write-phase.md` (all five sites) and `result-block.md`
- [x] No park comment in `cycle-write-phase.md` still reads
      `parked for a human: <the outcome line>`
- [x] `park-comment` appears in `CLAUDE.md`'s tsf templates listing
- [x] The template contains no angle brackets in its comment body shape

#### Manual Verification

- [x] Read each of the five resulting comments as a person who has never heard of tsf:
      each says what happened, what it means, what to do and which label — and none names
      `plan.sh`, a `result:` value or the result block
- [x] The GH-41 first park comment, rewritten to this shape, would have told the human to
      reply on the issue rather than leaving them to find the branch

### Implementation log

**Status**: complete
**Phase commit**: this commit

**What was done**: the new `references/templates/park-comment.md` defines two shapes — the
park comment (a person must act, ending in the label to set) and the question variant (the
factory needs a reply, no label asked for) — over five rules: plain language with no script,
step, mode or result-block vocabulary; one label and only the one being asked for; the
diagnostic in the journal rather than the comment; say what is already pushed, so nobody
goes looking for lost work; and the existing no-angle-brackets, no-fences constraint. All
**six** park sites in `cycle-write-phase.md` now compose from it (the five from the research
inventory plus Phase 3's format-question park), and `result-block.md`'s twice-invalid park
points at it instead of specifying its own one-liner. `CLAUDE.md`'s tsf templates listing
gained `park-comment`.

**Change of substance beyond wording**: Site A (a failed GitHub write) posted **no comment
at all**. It now posts one, best effort, because a failed write is precisely the case a
person has to act on and silence left the ticket parked with nothing on the issue. Its
numbering shifted from three steps to four.

**Verification results**: all five automated criteria pass; `park-comment.md` contains no
angle brackets anywhere (the first draft quoted the old one-liner *with* brackets in its own
header — a file whose rules forbid them — and that was fixed), and the old
`parked for a human: <the outcome line>` string is gone from `cycle-write-phase.md`. Both
manual items hold: read cold, each shape states what happened, what it means, what to do and
which label, and the question variant would have told the GH-41 human to reply on the issue
— the thing the original comment never said.

**Note on the label asked for**: the template asks for `tsf:queued` rather than
`tsf:answered` even though Phase 5 makes both work. `tsf:queued` says "I have acted" without
implying there is something to read; the template says so, and says the other is accepted,
so a person reaching for the familiar label is not punished for it.

---

## Phase 5: P3b — `tsf:answered` resumes a `needs-human` park

### Overview

Map the one unambiguous "I have acted" signal onto the other, so the label the pickup
workflow teaches is not refused on a `needs-human` park.

### Changes Required

#### 1. The validation stops calling it a mismatch

**File**: `plugins/tsf/references/cycle-dispatch.md` (`:88-96`)
**Changes**: narrow the first case. `tsf:answered` with no journal stays a mismatch; so does
a last-entry `Label` that is some *other* factory-side label. But a last-entry `Label` of
**`tsf:needs-human`** is no longer a mismatch — it is the re-queue path. State the reason
in one clause: "Never guess a state" stops the dispatcher inventing *workflow* state;
mapping an unambiguous human "I have acted" signal onto another is not guessing, and the
pickup workflow teaches that very label.

Also narrow the fourth case (`:94-95`): `tsf:answered` with no responder comment is a
mismatch **only** when the last entry's `Label` is one of the two question labels. On a
`needs-human` park a reply is not required — such a park is usually cleared by an action.

#### 2. Row 3 accepts the label

**File**: `plugins/tsf/references/cycle-dispatch.md` (row 3, `:140-164`)
**Changes**: its trigger becomes "`tsf:queued` with `spec.md`, **or `tsf:answered` whose
last journal entry `Label` is `tsf:needs-human`**, or `tsf:research`". Everything else in
the row is unchanged — including the two shapes, the pure label correction for the six
pull-request-dependent steps, and the new `- Episode:` on a resume into `tsf:verify`.

When a reply **is** present on such a resume and the derived step has a resume mode
(`triage`, `plan`), dispatch it with `mode: resume` and the reply instead of the row's
default; otherwise ignore the reply and resume as `tsf:queued` does. Nothing is dropped
silently: the park comment (Phase 4) says a reply is read only when the park asked a
question.

#### 3. Step 3's actionability

**File**: `plugins/tsf/commands/cycle.md` (`:90-115`)
**Changes**: `tsf:answered` is already actionable (`:92`), so no change is needed —
verify and leave it. Note in the plan's log if it turns out otherwise.

#### 4. The label's documented meaning

**File**: `plugins/tsf/README.md` (`:335`)
**Changes**: `tsf:answered` is described as "You replied; the step that asked picks it up".
Widen it to cover the re-queue use: "You replied, or you cleared a block; the ticket
resumes where it stood." Keep the table at fourteen labels.

**File**: `plugins/tsf/commands/init.md` (`:319`)
**Changes**: the same description is the label's creation text — keep the two in step.

**File**: `plugins/tsf/README.md` (the parked/re-queue prose, around `:342-349`)
**Changes**: say that either `tsf:queued` or `tsf:answered` hands a parked ticket back.

### Success Criteria

#### Automated Verification

- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `cycle-dispatch.md` row 3's trigger names `tsf:answered`, and the validation section
      no longer parks a `needs-human`-park `tsf:answered`
- [x] `README.md:335` and `init.md:319` carry the same widened description

#### Manual Verification

- [x] Replay the 05:12Z gesture on paper: `tsf:answered` on the GH-41 park now derives
      `implement` from the journal, corrects the label and writes the resume entry, instead
      of re-parking
- [x] A `tsf:answered` with no journal at all still parks — the guard that matters is intact

### Implementation log

**Status**: complete
**Phase commit**: this commit

**What was done**: the validation's first case now admits `tsf:needs-human` as a legal
previous `Label`, and its reply-presence case is scoped to **question** parks only, with the
reasoning written down (mapping one human "I have acted" signal onto another is not guessing;
the pickup workflow teaches that very label). Row 1 gained an explicit exclusion, since rows
are evaluated in order and it would otherwise claim the ticket. Row 3's trigger and its
resume bullet now name both labels. `README.md:335` and `init.md:319` carry the same widened
description, and the README's re-queue paragraph says either label works and that no reply
is needed.

`cycle.md` Step 3 needed no change: `tsf:answered` was already first in the actionable list,
as the plan predicted.

**Reply handling**: row 3 passes a reply to `triage` and `plan` (the two steps with a resume
mode) when one happens to be there, and ignores it otherwise — the plan's scope, kept.

**One usability fix beyond the plan**: the park comment said "Set the label `tsf:queued`",
which is ambiguous about the old label. Two `tsf:*` state labels at once is the one label set
the factory deliberately refuses to resolve for a human (`cycle.md` Step 3 reports
"needs a single tsf:* state label" and waits), so a comment that asks for a label now says
which one comes off — `park-comment.md` requires "replace", not "add", and says why. Without
that, this phase would have fixed one way of getting stuck and left a neighbouring one.

**Verification results**: all three automated criteria pass. Both walkthroughs hold:

- *The 05:12Z gesture* — scan reports `state: tsf:answered`; Step 3 finds it actionable; row
  1 declines it (last entry `Label: tsf:needs-human`); row 3 takes it, reads `Next step:
  implement`, sets `tsf:implement`, writes the resume entry and ends the cycle. The next
  cycle works the ticket normally. No re-park, and the human spent one gesture.
- *`tsf:answered` with no journal* — still the first validation case, still a park. The guard
  that stops the dispatcher inventing workflow state is untouched.

---

## Phase 6: The repo-level rule, and the release

### Overview

Record the generalization the ticket asks for, and ship tsf 1.3.0 with its tag.

### Changes Required

#### 1. The "show the shape" rule

**File**: `CLAUDE.md`
**Changes**: a new rule in the tsf section, beside "the result block is a machine
contract":

> **tsf: a machine contract's error must show the shape, not only name the field
> (TP-0043).** There are two invalid-return retry paths — `result-block.md`'s (a
> malformed result block) and `cycle.md`'s (a plan `plan.sh check` rejected) — and
> both must hand the agent the **required form**, not just the complaint. Naming the
> field cost the GH-41 run its one re-dispatch: the agent read the message correctly,
> dropped the offending qualifier and still failed, because nothing told it the marker
> had to be a bullet. Each note therefore points at the reference template **and** at
> the agent's own `## Return` (or the plan template's field skeleton), since an agent
> that skipped the point-of-use Read still has that copy in front of it (TP-0039 C1).
> The asymmetry is deliberate: the **parser** is liberal in shape, the **note** names
> one canonical form — a note that listed the tolerated variants would invite a choice.
> **RULE: when you add a mechanical gate on an agent's output, its rejection message
> must carry the shape, and a new gate joins this rule rather than inventing its own
> retry text.**

Also extend the existing plan-contract rule to record that the parser's tolerance and the
template's single form are deliberately different, so neither is "tidied" toward the other.

#### 2. The consumer README

**File**: `plugins/tsf/README.md`
**Changes**: the plan-format failure is now a question a human answers on the issue, not a
branch checkout. Say so where the README describes parks and the plan gate.

#### 3. Version and tag

**Files**: `plugins/tsf/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Changes**: `1.2.0` → `1.3.0` in both, then `claude plugin tag ./plugins/tsf` and confirm
with `git tag --list 'tsf--v*'`. Tagging is part of the release, not an afterthought
(CLAUDE.md) — tsf has already shipped two untagged versions that had to be backfilled.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] `plugin.json` and the marketplace entry both read `1.3.0`
- [ ] `git tag --list 'tsf--v*'` includes `tsf--v1.3.0`
- [ ] `CLAUDE.md` carries the "show the shape" rule naming **both** retry paths

#### Manual Verification

- [ ] The new CLAUDE.md rule is stated so a future contract author applies it without
      re-reading this ticket

---

## Testing Strategy

There is no test runner in this repo; verification is `claude plugin validate` plus
fixture-driven script runs (CLAUDE.md, "Testing changes").

### Script tests (Phase 1)

The four real GH-41/GH-40 fixtures above, plus synthetic fixtures written to the scratchpad
for: an empty field; a paragraph-form field spanning a blank line; an empty Verification
beside a filled Manual; an in-fence `### Increment` heading; a `*`-bulleted marker; a
qualifier inside the bold span; a field followed by `- **Depends on:**`.

Each fixture is run through **both** `check` and `criteria`, because the point of Phase 1.3
is that the two never disagree — a fixture that passes one and fails the other is a
regression regardless of which verdict is "right".

### Prose walkthroughs (Phases 2–5)

The changed dispatcher paths cannot be executed without a GitHub repository and a second
account, so each is verified by walking the recorded GH-41 timeline against the edited
files, as the Manual Verification items state. A full end-to-end run belongs to the next
factory session on a scratch project (CLAUDE.md, "tsf end to end"), not to this ticket.

## Migration Notes

No project config changes, so no `/tsf:init` Idempotency entry is needed: `config.md`'s
required content is unchanged. Projects on 1.2.0 pick this up with
`/plugin marketplace update toby-plugins`; nothing on a branch needs rewriting, and a plan
that parsed before still parses (the tolerance only widens, and the substance test refuses
what was already being silently mis-verified).

## References

- Original ticket: `thoughts/shared/tickets/TP-0043-tsf-format-problems-never-reach-a-human.md`
- Research: `thoughts/shared/research/2026-09-28-TP-0043-tsf-format-problems-never-reach-a-human.md`
- The run: `chat-sustainability` `b81f440` → `353f939` → `f116634` on `gh-41`
- The fixed twin: `plugins/tsf/references/templates/result-block.md:176-179` (TP-0039 C1)
- The counter-instance: `plugins/tsf/commands/cycle.md:244-256`
