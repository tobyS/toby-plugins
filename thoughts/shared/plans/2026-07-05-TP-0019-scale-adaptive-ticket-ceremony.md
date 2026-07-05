# Scale-adaptive ceremony in /tce:ticket — Implementation Plan

## Overview

Make `/tce:ticket` size its interaction ceremony to the ticket. Today the
interactive path always runs a fixed seven-phase discussion with three hard "do
not proceed" gates (`plugins/tce/commands/ticket.md:91-160`), regardless of
ticket size. This plan adds a **compressed interactive track** for Small/Medium
tickets — at most two batched rounds — while keeping the **full seven-phase
ceremony** for Large/Extra Large tickets, and leaves the existing **autonomous**
track (used by `/tce:quickfix`) untouched. Both interactive tracks feed the same
`## Creating the ticket` machinery and the same `## The ticket body` template, so
the resulting ticket is identical in structure and quality on both tracks; only
the interaction density differs.

The change is confined to a single markdown command file. It is a recombination
of idioms already present in the repo (a `## Modes`-style track selector, the
detect→recommend→override convention, batched AskUserQuestion rounds, and a
size-escalation bail-out), so it matches the existing altitude and wording.

## Current State Analysis

Per the research (`thoughts/shared/research/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md`):

- `plugins/tce/commands/ticket.md` (292 lines) already has **two tracks** chosen
  by `## Modes` (`ticket.md:56-61`): interactive (default) and autonomous
  (`--autonomous`). TP-0019 adds a **third, middle** track — compressed
  interactive — without disturbing either existing one.
- The interactive path is guarded solely by "When this command is invoked without
  `--autonomous`:" (`ticket.md:67`); all new branching lives between line 65 and
  line 201.
- Complexity is assessed today **only in Phase 5** (`ticket.md:142-143`) as a
  terminal judgment recorded in the body (`ticket.md:211`), not as a routing
  input. Making the flow scale-adaptive means introducing an **early** size
  assessment that routes the discussion.
- The three hard gates are at `ticket.md:107,116,135` (Phases 1, 2, 4).
- `## Creating the ticket` (`ticket.md:162-201`), `## The ticket body`
  (`ticket.md:203-256`), and `## Autonomous mode` (`ticket.md:276-291`) are
  shared/terminal machinery that must stay intact.
- `/tce:quickfix` delegates ticket creation to `tce:ticket --autonomous`
  (`quickfix.md:97-124`) and carries **no** copy of the discussion phases. It is
  affected only through the *autonomous contract*, which this change does not
  touch. `work.md` does not invoke `/tce:ticket` at all.
- The `### AskUserQuestion dialog guidelines` block (`ticket.md:36-54`) is one of
  nine byte-identical copies; AC7 forbids editing it unless all nine change
  together. This design **reuses** that block's existing "batch related questions
  into one call" rule and does **not** edit it.

### Key Discoveries:

- Early size-assessment presentation should follow `init.md:214-219,232-248` —
  detect/propose, put it first, give the one-line reasoning, let the user override
  (research finding, "Reusable patterns" #2).
- The compressed track's "≤2 rounds" is built from the batched-round idioms at
  `work.md:151-168` and `research.md:129-133` — no new dialog primitive needed.
- Escalation differs from quickfix's bail-out: quickfix *stops and hands back*
  (`quickfix.md:239`), whereas TP-0019 wants the command to *switch to the full
  ceremony in place and continue* (research "Reusable patterns" #4; ticket AC5).
- Resolved design decisions (question checkpoint + ticket):
  - **Threshold:** compressed for Small/Medium; full for Large/Extra Large.
  - **Assessment presentation:** folded into the first response with a one-line
    reason; user can override (ticket Q1).
  - **Escalation:** in-place switch to the full ceremony, continue (ticket AC5).
  - **Force-full-ceremony (AC6):** *round option + prose* — the size-assessment /
    first compressed round explicitly offers the full ceremony as a choice, and a
    plain-language request is honored at any time. **No new invocation flag.**
  - **Kiro/BMAD wording:** nothing to borrow (review rejects their notation).

## Desired End State

`plugins/tce/commands/ticket.md` runs one of three tracks:

1. **Compressed discussion (Small/Medium)** — new. Round 1 presents restated
   understanding + proposed complexity + a complete draft ticket; Round 2 is the
   single final confirmation before creation. Genuinely unresolved *business*
   questions may be asked on top (exempt from the round cap).
2. **Full discussion (Large/XL)** — the current seven phases and three gates,
   unchanged except for a renamed heading and a one-sentence lead-in that says
   when it is reached.
3. **Autonomous** (`--autonomous`) — byte-for-byte unchanged.

An early **Size assessment & track selection** step routes between (1) and (2),
lets the user override the size or force the full ceremony, and defines the
escalation rule. Both interactive tracks produce a ticket via the same
`## Creating the ticket` / `## The ticket body` sections.

Verification: `claude plugin validate ./plugins/tce` and `claude plugin validate .`
pass; `plugins/tce/commands/quickfix.md` and the nine AskUserQuestion copies are
unchanged in this commit; a read-through confirms all seven acceptance criteria.

## What We're NOT Doing

- **Not** changing `## The ticket body` template or "What tce needs from a ticket"
  (ticket Out of Scope).
- **Not** touching `## Autonomous mode` or the `--autonomous` contract, and
  therefore **not** editing `quickfix.md` (verify, don't edit).
- **Not** editing the `### AskUserQuestion dialog guidelines` block in any of the
  nine files.
- **Not** scale-adapting other commands (research/plan depth) — separate concern.
- **Not** adding a new invocation flag for the force-ceremony affordance (per the
  chosen "round option + prose" design).
- **Not** altering the seven phases' bodies or the three gate sentences.

## Implementation Approach

Option A from the research: add the compressed track *alongside* the existing
tracks (an explicit `## Modes`-style split), rather than parameterizing each phase
inline. This matches the repo's track-selection idiom, keeps the full ceremony
literally intact, and minimizes the risk of the model silently dropping substance
on the compressed path.

All edits are surgical insertions/retitles between `ticket.md:56` and the start of
`## Creating the ticket`, plus one Important-Guideline addition. Because the exact
wording of a command prompt *is* the deliverable, the replacement text is given in
full below so implementation is mechanical.

---

## Phase 1: Add the compressed track and size-based routing to `ticket.md`

### Overview

Rewrite the `## Modes` blurb, insert the size-assessment/routing section and the
compressed-discussion section, retitle the seven-phase section as the full track,
reconcile Phase 5's complexity line with the early estimate, and add one
Important Guideline. The seven phases, their three gates, `## Creating the
ticket`, `## The ticket body`, and `## Autonomous mode` are left intact.

### Changes Required:

#### 1. Rewrite the `## Modes` bullet list

**File**: `plugins/tce/commands/ticket.md` (lines 56-61)
**Changes**: Note that the interactive discussion is now scale-adaptive.

Replace:

```markdown
## Modes

- **Interactive (default):** run the guided discussion below, then create the ticket
  through the adapter and hand off to `/tce:research`.
- **Autonomous:** when the invocation arguments contain `--autonomous` (used by
  `/tce:quickfix`), skip the discussion entirely — see "Autonomous mode" at the end.
```

with:

```markdown
## Modes

- **Interactive (default):** run the guided discussion below, then create the ticket
  through the adapter and hand off to `/tce:research`. The discussion is
  **scale-adaptive** — after an early size assessment it runs either the
  **compressed** track (Small/Medium: at most two batched rounds) or the **full**
  seven-phase ceremony (Large/Extra Large). Both tracks produce the same ticket body
  at the same quality; only the interaction density differs. The user can force the
  full ceremony on any ticket.
- **Autonomous:** when the invocation arguments contain `--autonomous` (used by
  `/tce:quickfix`), skip the discussion entirely — see "Autonomous mode" at the end.
```

#### 2. Insert `## Size assessment & track selection`

**File**: `plugins/tce/commands/ticket.md`
**Changes**: New section between `## Initial Response (interactive)` (ends line
89) and `## Discussion Process` (line 91).

Insert:

```markdown
## Size assessment & track selection

Before the discussion, size the ticket and pick the interaction track. This is a
routing judgment, not a gated round — state it briefly and proceed; it costs no
extra confirmation on either track.

1. From the initial description (argument or the user's first answer), form a
   first-pass understanding and propose an **Estimated Complexity** — Small, Medium,
   Large, or Extra Large — with **one line of reasoning**. (This is the same estimate
   later recorded in the body; here it also selects the track.)
2. **Route on the estimate:**
   - **Small or Medium →** run the **Compressed discussion** (below).
   - **Large or Extra Large →** run the **Full discussion** (the seven phases below).
3. **The user can override.** They may correct the size or ask for the full ceremony
   regardless of size — in plain language at any time, or as the offered choice in
   the first compressed round (below). A request for the full discussion always wins.
   An Extra Large estimate should still trigger the "break it into smaller tickets"
   conversation from Full-discussion Phase 5.
4. **Escalation.** If, once discussion starts, the ticket proves larger or more
   tangled than estimated (scope keeps growing, acceptance criteria won't settle, an
   unresolved design decision surfaces), say so and switch to the **Full discussion
   in place** — continue from the understanding already gathered into the remaining
   phases; do not discard it or restart.
```

#### 3. Insert `## Compressed discussion (Small/Medium)`

**File**: `plugins/tce/commands/ticket.md`
**Changes**: New section immediately after the size-assessment section, before the
full-discussion section.

Insert:

```markdown
## Compressed discussion (Small/Medium)

For Small/Medium tickets, collapse the seven phases into **at most two interaction
rounds** while filling *every* body section at the same quality bar as the full
track. The three "do not proceed" gates become a single confirmation of the whole
draft — you are batching the questions, not lowering the bar.

**Round 1 — understanding + draft (one message).** In a single message, present:

- Your **restated understanding** of the problem and why it's needed.
- The proposed **Estimated Complexity** and its one-line reasoning (from the size
  assessment) — explicitly inviting the user to override the size, or to expand to
  the full guided discussion instead.
- A **complete first-draft ticket** filling every section of "The ticket body":
  Problem Statement, Desired Outcome (concrete and measurable), 2–4 User Stories
  (each with a genuine "so that" benefit), Acceptance Criteria (specific, testable —
  apply the Phase 4 standard), Out of Scope, Open Questions, and Questions for
  Research/Planning.

Ask the user to confirm or correct the draft. Do **not** silently skip substance:
acceptance criteria must still be testable and Out of Scope still explicit.

**Genuinely unresolved business questions are exempt from the two-round cap.** If a
real business/product ambiguity blocks drafting a section (not a technical question —
those go under Questions for Research/Planning), ask it, following the AskUserQuestion
dialog guidelines (above). Prefer to batch it into Round 1's message.

**Round 2 — confirm & create.** Fold the user's corrections into the draft, then ask
the single final confirmation ("Ready for me to create this in [system]?") and create
the ticket via "Creating the ticket" below. If the corrections reveal the ticket is
actually Large/Extra Large, escalate to the Full discussion instead (per "Size
assessment & track selection").
```

#### 4. Retitle the seven-phase section and add a lead-in

**File**: `plugins/tce/commands/ticket.md` (lines 91-96)
**Changes**: Rename `## Discussion Process` → `## Full discussion (Large/XL)` and
add one sentence saying when it is reached. The seven phases (Phase 1-7) and the
three gate sentences below are **not** modified.

Replace:

```markdown
## Discussion Process

A **collaborative dialogue** that refines the initial idea into a complete ticket.
Your role: ask probing questions, challenge vague requirements, ensure acceptance
criteria are testable, identify what's out of scope, surface and resolve open
questions, and stay on the business need rather than the implementation.
```

with:

```markdown
## Full discussion (Large/XL)

Reached for Large/Extra Large tickets, whenever the user asks for the full ceremony,
or on escalation from the compressed track. A **collaborative dialogue** that refines
the initial idea into a complete ticket. Your role: ask probing questions, challenge
vague requirements, ensure acceptance criteria are testable, identify what's out of
scope, surface and resolve open questions, and stay on the business need rather than
the implementation.
```

#### 5. Reconcile Phase 5's complexity line with the early estimate

**File**: `plugins/tce/commands/ticket.md` (lines 142-143)
**Changes**: Phrase the Phase 5 estimate as validating/adjusting the earlier one
rather than assessing from scratch.

Replace:

```markdown
- Validate a complexity estimate (Small / Medium / Large / Extra Large). If it feels
  XL, discuss breaking it into smaller tickets.
```

with:

```markdown
- Validate the complexity estimate from the size assessment (Small / Medium / Large /
  Extra Large), adjusting it if the discussion changed the picture. If it feels XL,
  discuss breaking it into smaller tickets.
```

#### 6. Add an Important Guideline for scale-adaptivity

**File**: `plugins/tce/commands/ticket.md` (after guideline 8, lines 273-274)
**Changes**: Add guideline 9.

Insert after the guideline-8 block:

```markdown
9. **Match ceremony to size.** Small/Medium tickets run the compressed two-round
   track; Large/Extra Large run the full seven phases. Same body, same quality on
   both — only the interaction density differs. Escalate to the full ceremony if a
   "small" ticket grows, and honor any explicit request for the full ceremony.
```

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes (run from repo root
      `/Users/toby/code/work/toby-plugins`).
- [x] `claude plugin validate .` passes.
- [x] The `### AskUserQuestion dialog guidelines` block in `ticket.md` is unchanged:
      `git diff plugins/tce/commands/ticket.md` shows no edits within lines that were
      36-54.
- [x] The `## Autonomous mode` section (old lines 276-291) is unchanged in the diff.

#### Manual Verification:

- [x] AC1: an early size assessment proposes a complexity with one-line reasoning and
      the user can override; two tracks are keyed on it.
- [x] AC2: the compressed track is at most two rounds before creation, with the
      business-question exemption stated.
- [x] AC3: the seven phases and three gates of the full track are byte-identical to
      before (only the heading + lead-in changed).
- [x] AC4: both tracks route into the same `## The ticket body` sections at the same
      quality bar (compressed round 1 enumerates every section; Phase 4 testability
      standard is referenced).
- [x] AC5: the in-place escalation rule is present in both the routing section and
      the compressed track.
- [x] AC6: the force-full-ceremony affordance (round option + plain-language) is
      present; no new flag was added.
- [x] Read-through: the compressed track never instructs dropping a section or
      lowering the acceptance-criteria bar.

---

## Phase 2: Verify composite-tracking and no collateral changes

### Overview

Confirm, per the CLAUDE.md composite-tracking and AskUserQuestion-duplication
rules, that this change did not require and did not make any edits outside
`ticket.md`.

### Changes Required:

#### 1. Confirm `quickfix.md` needs no change

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: None expected. The autonomous contract (`ticket.md:276-291`) is
untouched, and quickfix delegates to `tce:ticket --autonomous` without mirroring
the discussion phases. Re-read `quickfix.md:97-124` and `:239` against the final
`ticket.md` diff and confirm nothing it relies on changed. If (unexpectedly) the
autonomous contract had to change, mirror it here in the same commit.

#### 2. Confirm the nine AskUserQuestion copies are untouched

**Files**: `plugins/tce/commands/{init,research,plan,work,quickfix,refresh,ticket}.md`,
`plugins/tmt/commands/{init,update}.md`
**Changes**: None. Verify the block remains byte-identical across all nine.

#### 3. Confirm `work.md` is out of scope

**File**: `plugins/tce/commands/work.md`
**Changes**: None. `work.md` starts from an existing ticket and never invokes
`/tce:ticket`, so the ticket-authoring change does not reach it.

### Success Criteria:

#### Automated Verification:

- [x] `git diff --name-only` for this change lists only
      `plugins/tce/commands/ticket.md` (plus the thoughts/ docs), and **not**
      `quickfix.md`, `work.md`, or any other command file.
- [x] The nine AskUserQuestion blocks are still identical — extract the block
      (heading through its last bullet) from each of the nine files and confirm they
      match (verified: all nine share sha256 `5ad68554…c21cd71b3`).

#### Manual Verification:

- [x] `quickfix.md` Phase 2 still reads correctly against the unchanged autonomous
      contract; nothing it delegates to changed shape.

---

## Testing Strategy

This is a documentation/command-prompt change with no runtime code, so testing is
manifest validation plus a careful read-through against the acceptance criteria.

### Manual Testing Steps:

1. Run `claude plugin validate ./plugins/tce` and `claude plugin validate .` from
   the repo root; both must pass.
2. Read `ticket.md` end to end and walk a hypothetical Small ticket through the
   compressed track (two rounds, all sections filled) and a Large ticket through the
   full track (seven phases, three gates) to confirm both produce the same body.
3. Confirm the diff touches only `ticket.md` among command files.

## Migration Notes

None. No project config, version marker, or consuming-project artifact changes.
The plugin version bump/tag is a separate release step (per CLAUDE.md "Releasing")
and is not part of this ticket.

## References

- Original ticket: `TP-0019` —
  `thoughts/shared/tickets/TP-0019-scale-adaptive-ticket-ceremony.md`
- Related research:
  `thoughts/shared/research/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md`
- Motivating review:
  `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:192-200`
  (finding 7)
- Target file: `plugins/tce/commands/ticket.md`
- Governing rules: `CLAUDE.md` (composite-tracking, nine-copy AskUserQuestion,
  TP-0017 invocation control)
