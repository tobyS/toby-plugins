---
date: 2026-07-05T12:12:28+0200
git_commit: 01b2b2d4f093b2329792b5e5586b851399239b4c
branch: main
repository: toby-plugins
topic: "Scale-adaptive interaction ceremony in /tce:ticket (TP-0019)"
tags: [research, codebase, tce, ticket, quickfix, ceremony, composite-tracking]
status: complete
last_updated: 2026-07-05
---

# Research: Scale-adaptive interaction ceremony in /tce:ticket (TP-0019)

**Date**: 2026-07-05T12:12:28+0200
**Git Commit**: 01b2b2d4f093b2329792b5e5586b851399239b4c
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0019 wants `/tce:ticket` to size its interaction process to the ticket:
Small/Medium tickets collapse the seven-phase discussion into at most two
batched interaction rounds; Large/XL tickets keep the current full phase gates.
Both tracks must produce the same ticket body at the same quality. This research
documents how `ticket.md` is currently structured, where size/complexity is
handled today, how the autonomous track and the composites relate to it, and
which shared/duplicated artifacts a change must respect — so planning can design
the two-track split surgically.

## Summary

`/tce:ticket` (`plugins/tce/commands/ticket.md`, 292 lines) already has **two
tracks** selected by a `## Modes` section: interactive (the seven-phase guided
discussion) and autonomous (`--autonomous`, used by `/tce:quickfix`, zero
interaction). TP-0019 asks for a **third, middle track** — a compressed
interactive path for Small/Medium tickets — without disturbing either existing
one.

Key facts that shape the change:

1. **The full ceremony is seven phases (`ticket.md:98-160`) with exactly three
   hard "do not proceed" gates** (lines 107, 116, 135, in Phases 1, 2, 4). These
   gates are the natural thing to relax on the compressed track.

2. **Complexity is assessed today only in Phase 5 (`ticket.md:142-143`), as a
   terminal judgment, not an early routing input.** It is a recorded field
   (`**Estimated Complexity:** Small | Medium | Large | Extra Large`,
   `ticket.md:211`), not a flow-control input. Making it scale-adaptive means
   introducing an **early** size assessment (before the phases) that routes the
   flow — the ticket and the review both frame it this way.

3. **The autonomous track (`ticket.md:276-291`) must stay untouched**, and it is
   a delegation target: `/tce:quickfix` invokes `tce:ticket --autonomous`
   (`quickfix.md:97-124`). Per the composite-tracking rule, the compressed track
   must not change the autonomous contract; quickfix is otherwise unaffected
   (open question #4 in the ticket — confirmed: quickfix delegates, it does not
   mirror the discussion phases).

4. **The ticket body template is identical for all tracks** and lives inline in
   `## The ticket body` (`ticket.md:203-256`). AC4 ("same body structure") is
   satisfied as long as both interactive tracks route into the same
   `## Creating the ticket` / `## The ticket body` machinery — which they already
   would, since only the *discussion* differs.

5. **The AskUserQuestion guidelines block is duplicated byte-identically across
   nine files** (`ticket.md:36-54` is one copy). AC7 requires either leaving it
   untouched or changing all nine in the same commit. The natural design (batched
   rounds) *reuses* the existing "batch related questions into one call" rule
   (`ticket.md:48-49`) rather than editing the block — so no nine-file change is
   expected.

6. **The repo already has all the building-block patterns** for this change:
   a `## Modes` branch, a detect-and-recommend-first override convention, batched
   AskUserQuestion rounds, and a size-escalation bail-out. The change is largely a
   recombination of existing idioms, matching altitude.

The review that motivated the ticket
(`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:192-200`,
finding 7) proposes exactly one mechanic — "compress phases 1-5 into one
confirmation round for Small/Medium tickets" — and provides **no** detail on how
to present the size assessment, no escalation rule, and no user-forced-ceremony
mechanic. Those three (AC1's early assessment presentation, AC5 escalation, AC6
force-full-ceremony) are design additions beyond the review and are the real
planning work.

## Detailed Findings

### `/tce:ticket` command structure (`plugins/tce/commands/ticket.md`)

Top-level section order (292 lines):

- `# Author a Ticket` (line 6) — framing: ticket is WHAT & WHY, not HOW.
- `## Project context` (line 20), containing `### AskUserQuestion dialog
  guidelines` (lines 36-54).
- `## Modes` (lines 56-61) — the existing two-track selector (interactive vs
  autonomous).
- `## Initial Response (interactive)` (lines 65-89) — guarded by "When this
  command is invoked without `--autonomous`:" (line 67). This clause is the
  **sole guard** on the whole interactive path, so any new scale-adaptive
  branching lives between line 65 and line 201.
- `## Discussion Process` (lines 91-160) — the seven phases (see below).
- `## Creating the ticket` (lines 162-201) — the persistence procedure (build
  body, honor creation policy, ask final permission, hand off).
- `## The ticket body` (lines 203-256) — the inline body template.
- `## Important Guidelines` (lines 258-274).
- `## Autonomous mode` (lines 276-291) — the full spec of the `--autonomous`
  track.

### The seven-phase Discussion Process and its three gates (`ticket.md:98-160`)

- **Phase 1: Understand the problem** (98-107) — restate understanding, business
  value, trigger. **Gate (line 107):** `**Do not proceed until the user confirms
  your understanding.**`
- **Phase 2: Define the desired outcome** (109-116) — concrete/measurable end
  state. **Gate (line 116):** `**Do not proceed until the outcome is concrete and
  measurable.**`
- **Phase 3: Explore user stories** (118-122) — 2-4 "As a… I want… so that…"
  stories. No gate.
- **Phase 4: Define acceptance criteria** (124-135) — testable checklist, edge
  cases. **Gate (line 135):** `**Do not proceed until acceptance criteria are
  specific, measurable, and complete.**`
- **Phase 5: Define boundaries** (137-143) — Out-of-Scope list **plus the
  complexity-estimate validation** (see next). No gate.
- **Phase 6: Surface open questions** (145-155) — business (resolve now) vs
  codebase/technical (defer to research/planning). No gate.
- **Phase 7: Final review & confirmation** (157-160) — summarize Problem /
  Outcome / key AC / Complexity / Out of Scope, ask for explicit confirmation.
  Phrased as a step, not a bolded gate.

The review's "compress phases 1-5 into one confirmation round" (finding 7) maps
onto collapsing Phases 1-5 and their three gates into a single restate-plus-draft
round, then a single confirmation round (mirroring Phase 7).

### Where size/complexity lives today (terminal, not routing)

- **Assessed** only in Phase 5 (`ticket.md:142-143`): "Validate a complexity
  estimate (Small / Medium / Large / Extra Large). If it feels XL, discuss
  breaking it into smaller tickets." Framed as *validate*, and it is the only
  place that mentions splitting XL tickets.
- **Summarized** in Phase 7 (`ticket.md:159`).
- **Recorded** in the body (`ticket.md:211`).
- **Rationale documented** per Important Guideline #8 (`ticket.md:273-274`).
- **Hardcoded** to `Small` in the autonomous path (`ticket.md:283`).

There is no size assessment earlier than Phase 5 and nothing that branches the
*flow* on size. TP-0019's AC1 requires introducing that early assessment (the
command proposes a complexity estimate with one-line reasoning; user can
override) as a routing input.

### Autonomous mode — the existing zero-interaction track (`ticket.md:276-291`)

Declared in `## Modes` (lines 60-61) and guarded on the interactive path by the
line 67 clause. Full spec (lines 278-291): do **not** run the discussion or ask
anything (line 282); take the argument description as the understanding; build the
body with **Estimated Complexity: Small**, "Open Questions: None — well-understood
quickfix", and a Questions-for-Research/Planning list (lines 283-285); create via
the adapter and return the canonical ID with no handoff message (lines 286-291).
This track skips all seven phases, all three gates, the final-permission ask
(line 172) and the handoff (lines 195-201).

**Constraint for TP-0019:** AC7 says autonomous mode is unaffected. The compressed
interactive track is a *third* path; it must not alter the autonomous contract
(which `quickfix.md` mirrors).

### The shared ticket body template (`ticket.md:203-256`)

The body is an inline fenced `markdown` block. Sections in order: meta lines
(Estimated Complexity / Created / Updated), Problem Statement, Desired Outcome,
User Stories / Use Cases, Acceptance Criteria, Out of Scope, Open Questions,
Questions for Research/Planning, References, Implementation Plan (left empty),
Notes & Updates. The **title** and the `**Status:**`/meta prepending come from the
`tickets.md` adapter, not this file (`ticket.md:205-208`).

Because both interactive tracks feed the same `## Creating the ticket` procedure
and this same body template, AC4 ("same body structure and quality on both
tracks") is structurally satisfied by construction — the compressed track just has
to *fill* the same sections. TP-0019's "Out of Scope" explicitly excludes changing
this template.

### The composite relationship — quickfix delegates, does not mirror (`quickfix.md`)

`/tce:quickfix` Phase 2 (`quickfix.md:97-124`) invokes the `tce:ticket` skill with
`--autonomous` and the Phase-1 understanding as the argument; `/tce:ticket` builds
a Small-complexity ticket and returns the canonical ID. Quickfix carries **no**
copy of the discussion phases (it stopped inlining a template — `quickfix.md:23,
102-104`). Its Important Rule #1 (`quickfix.md:239`) is the size-escalation
bail-out ("Size is always 'Small' — if … the fix is actually medium or larger …
STOP and tell the user").

**Confirms ticket open question #4:** `work.md`/`quickfix.md` do **not** mirror
ticket.md's discussion phases. The composite-tracking rule still applies because
`ticket.md` is a delegation target — but the trigger is the *autonomous contract*,
not the discussion phases. Since the compressed track leaves autonomous mode
alone, quickfix needs no change. (This should be verified again at plan time
against the exact edits.) `work.md` does not touch `/tce:ticket` at all (it starts
from an existing ticket), so it is out of scope entirely.

### Reusable patterns already in the repo (match these idioms)

1. **`## Modes` branch on an argument/flag** (`ticket.md:56-61`) and the fuller
   two-branch "if X / if NO X" shape (`plan.md:182-191`, `work.md:132-177`). The
   compressed track slots in as a size-keyed branch of the interactive path.

2. **Detect → recommend-first → user can override** — the canonical convention
   from the guidelines block itself (`ticket.md:45-47`) and applied concretely in
   `init.md:214-219` (move detected option to position 1, "(Recommended)", give
   the detection reasoning) and `init.md:232-248` (reverse the recommendation
   based on a detected condition). This is exactly the shape AC1's "propose a
   complexity estimate with one-line reasoning; the user can override" wants.

3. **Batched interaction rounds** — the "batch related questions into one call"
   rule (`ticket.md:48-49`), the "one batched round" sufficiency clarification
   (`research.md:129-133`, `work.md:76`), and the "one AskUserQuestion call, a
   second only if >4 questions" pattern with an absorbed extra question
   (`work.md:151-168`). The compressed track's "at most two interaction rounds"
   (AC2) is built from these — no new dialog primitive needed.

4. **Size-escalation bail-out** — `quickfix.md:239` ("if … actually medium or
   larger … STOP and tell the user") and the softer "stop and talk" rules
   (`work.md:265`, `work.md:242-249`). AC5's escalation rule ("if discussion
   reveals larger scope … switch to the full ceremony") should be phrased in this
   established idiom, but note the difference: quickfix *stops and hands back to
   the user*, whereas TP-0019 wants the command to *switch tracks and continue*
   (escalate to full ceremony in-place). That is a new variant of the idiom.

5. **The closest existing "lightweight up-front classification that decides
   whether to interact"** is the Ticket Sufficiency Check
   (`research.md:114-133`) — a three-criteria gate that triggers one batched
   clarification round only if criteria are missing. The early size assessment is
   analogous: a cheap up-front judgment that selects the interaction density.

### The AskUserQuestion guidelines block (duplicated ×9)

`ticket.md:36-54` is one of nine byte-identical copies (the others:
`plugins/tce/commands/{init,research,plan,work,quickfix,refresh}.md` and
`plugins/tmt/commands/{init,update}.md`). AC7 requires leaving it untouched or
changing all nine together. The intended design reuses the block's existing
batching rule rather than editing it, so **no nine-file change is anticipated** —
but the plan must state this explicitly and the change must respect it if any
wording is touched.

## Code References

- `plugins/tce/commands/ticket.md:56-61` - `## Modes` — existing interactive vs
  autonomous track selector (the extension point for a third track).
- `plugins/tce/commands/ticket.md:65-89` - `## Initial Response (interactive)`;
  line 67 is the sole `--autonomous` guard on the interactive path.
- `plugins/tce/commands/ticket.md:91-160` - `## Discussion Process`, the seven
  phases (the "full ceremony").
- `plugins/tce/commands/ticket.md:107,116,135` - the three hard "do not proceed"
  gates (Phases 1, 2, 4).
- `plugins/tce/commands/ticket.md:142-143` - Phase 5 complexity-estimate
  validation (today's only, terminal, size judgment).
- `plugins/tce/commands/ticket.md:162-201` - `## Creating the ticket` (shared by
  all tracks).
- `plugins/tce/commands/ticket.md:203-256` - `## The ticket body` (shared inline
  template — AC4's "same body structure").
- `plugins/tce/commands/ticket.md:276-291` - `## Autonomous mode` (must stay
  untouched; quickfix's delegation target).
- `plugins/tce/commands/ticket.md:36-54` - AskUserQuestion guidelines block (1 of
  9 byte-identical copies).
- `plugins/tce/commands/quickfix.md:97-124` - Phase 2 delegates ticket creation to
  `tce:ticket --autonomous`.
- `plugins/tce/commands/quickfix.md:239` - Important Rule #1, the size-escalation
  bail-out idiom.
- `plugins/tce/commands/init.md:214-219,232-248` - detect → recommend-first →
  override convention (model for AC1's assessment presentation).
- `plugins/tce/commands/research.md:114-133` - Ticket Sufficiency Check (closest
  "up-front classification that decides interaction" precedent).
- `plugins/tce/commands/work.md:151-168` - "one AskUserQuestion call, second only
  if >4" with an absorbed extra question (model for batched rounds).

## Architecture Documentation

- **Two-plugin, project-agnostic marketplace.** Commands are long markdown
  prompts; no per-project literals. This change is markdown-only, inside
  `plugins/tce/commands/ticket.md`.
- **Track selection via a `## Modes` section** is the established idiom for
  branching a command's interaction level; the compressed track extends it.
- **Complexity as a recorded field** (Small/Medium/Large/Extra Large) already
  exists end-to-end; TP-0019 promotes it from a terminal record to an early
  routing input while keeping the same enum.
- **Ownership seam (TP-0007):** tce owns ticket *content/authoring*; tmt owns the
  *envelope*. This change is entirely on tce's authoring side and does not touch
  the envelope, statuses, or the adapter.
- **Duplication governance:** the AskUserQuestion block (×9) and the
  composite-tracking rule (ticket.md ↔ quickfix.md via the autonomous contract)
  are the two constraints a plan must honor.

## Impact Analysis

### Existing Usages Found
- `plugins/tce/commands/quickfix.md:97-124` - Invokes `tce:ticket --autonomous`;
  depends on the autonomous contract (Small complexity, no interaction, returns
  canonical ID, no handoff).
- `plugins/tce/commands/quickfix.md:239` - Encodes the "quickfix = always Small"
  assumption and the escalate-by-stopping behavior; conceptually adjacent to the
  new escalation rule.
- `.claude/tce/tickets.md` (consuming-project adapter) - `## Creating a ticket` /
  `## Ticket title & body layout` are invoked by `## Creating the ticket`; both
  interactive tracks must still route through them unchanged.

### Current Contract
- **Input:** `ticket.md` is invoked either bare/with a description (interactive)
  or with `--autonomous <description>` (autonomous). Track is chosen by the
  presence of `--autonomous`.
- **Output:** a persisted ticket whose body follows `## The ticket body`, created
  via the adapter, plus (interactive only) a `/tce:research` handoff message.
- **Assumptions by consumers:** `/tce:quickfix` assumes autonomous mode is
  silent, Small-complexity, and returns the canonical ID with no handoff.

### Adaptation Requirements
- `plugins/tce/commands/ticket.md` - Introduce (a) an early size assessment after
  the initial understanding; (b) a size-keyed branch selecting compressed vs full
  interactive track; (c) the compressed track (Phases 1-5 collapsed into ≤2
  batched rounds, feeding the same `## Creating the ticket` machinery); (d) an
  escalation rule (compressed → full when scope grows); (e) a user override to
  force full ceremony. Keep Phases (full track), `## Creating the ticket`,
  `## The ticket body`, and `## Autonomous mode` intact.
- `plugins/tce/commands/quickfix.md` - Expected **no change** (autonomous contract
  untouched). Verify at plan time per the composite-tracking rule.
- The nine AskUserQuestion copies - Expected **no change**; verify none is edited,
  else all nine change together.

### Backward Compatibility Options
- **Option A — new middle track alongside the existing two (recommended shape per
  the ticket/review):** add a compressed interactive track keyed on an early size
  assessment; Large/XL fall through to the unchanged seven phases; autonomous
  unchanged. Pros: matches AC1-AC7 literally, minimal blast radius, reuses
  existing idioms. Cons: adds branching prose to an already long command
  (mitigated by surgical placement between lines 65 and 201).
- **Option B — parameterize each phase with "compressed vs full" inline
  behavior:** keep one linear phase list, annotating each phase with how it
  shrinks when Small/Medium. Pros: no duplicated phase text. Cons: harder to read,
  risks the model skipping substance on the compressed path (AC "same quality"
  risk), diverges from the repo's `## Modes`-style explicit-track idiom.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:192-200` -
  Finding 7, the origin of TP-0019: "compress phases 1-5 into one confirmation
  round for Small/Medium tickets." Cites Kiro Quick Plan / BMAD Quick Flow / Spec
  Kit only as directional evidence that scale-adaptive planning is the
  industry-convergent answer; explicitly rejects borrowing their notations
  (EARS, persona theater) at `:234`. Ranks TP-0019 as an "opportunistic" /
  lower-urgency polish item (`:278-279`). Provides **no** size-assessment
  presentation, **no** escalation rule, **no** force-ceremony mechanic — those are
  unconstrained by the source and are the design work.
- `thoughts/shared/tickets/TP-0007-tce-ticket-authoring-tmt-envelope-split.md` +
  its research/plan (`2026-06-15-TP-0007-*`) - Established the current
  authoring-vs-envelope split and the seven-phase interactive discussion this
  change adapts.
- `thoughts/shared/tickets/TP-0018-research-root-cause-for-defects.md` + its
  research/plan (`2026-07-05-TP-0018-*`) - Precedent for **ticket-type-conditional
  behavior** in the workflow (a carve-out that changes behavior based on a
  classification) — the closest structural analog to a size-conditional track.
- `thoughts/shared/tickets/TP-0001-askuserquestion-copy.md` - Origin of the
  nine-copy duplicated guidelines block (AC7 constraint).
- `thoughts/shared/tickets/TP-0013-explicit-context-document-reads.md` - Origin of
  the composite-tracking / context-reread discipline governing this change.
- `thoughts/shared/discussions/2026-06-15-tce-ticket-authoring-vs-tmt-envelope.md`
  - The trade-off discussion behind the current interaction model.

## Related Research

- `thoughts/shared/research/2026-06-15-TP-0007-tce-ticket-authoring-tmt-envelope-split.md`
  - How `/tce:ticket` came to own the guided discussion.
- `thoughts/shared/research/2026-07-05-TP-0018-root-cause-analysis-for-defect-tickets.md`
  - The most recent precedent for a conditional behavior carve-out in a tce
  command.

## Open Questions

These are the design decisions the review does **not** settle — for the question
checkpoint / planning:

1. **Where the size threshold sits.** The review says compress for "Small/Medium",
   full for Large/XL. Confirm the boundary is Medium|Large (compressed ≤ Medium)
   and that it keys on the same Estimated Complexity enum.
2. **How the early assessment is presented (AC1 + ticket Q1).** Fold the proposed
   complexity + one-line reasoning into the *first* response alongside the
   restated understanding (so it costs no extra round), with the user able to
   override — modeled on `init.md`'s detect/recommend/override convention. Confirm
   this is the intended shape.
3. **Escalation semantics (AC5 + ticket Q2).** When compressed discussion reveals
   larger scope: does the command switch to full ceremony **in place and
   continue** (ticket's wording), versus quickfix's "stop and hand back"? Confirm
   in-place escalation and phrase it so the model still fills every body section
   at full quality.
4. **Force-full-ceremony affordance (AC6).** How the user requests full ceremony
   regardless of size — a flag (e.g. `--full`), a natural-language request, or an
   option surfaced in the size-assessment round. The review is silent; pick the
   idiom that fits the command.
5. **Whether Kiro/BMAD wording is worth borrowing (ticket Q3).** Research finding:
   the review deliberately does **not** recommend borrowing their notation — only
   the scale-adaptive *concept*. Expected answer: no wording to borrow.

## tce Config Drift

None found. `profile.md` (stack = markdown/bash/JSON plugin monorepo; test =
`claude plugin validate`; no typecheck/lint; code map) and `tickets.md` (tmt, `TP`
prefix, file backend under `thoughts/shared/tickets/`) both match the current
repository state. No `/tce:refresh` recommended.
