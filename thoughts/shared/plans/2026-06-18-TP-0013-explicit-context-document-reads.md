---
date: 2026-06-18
ticket: TP-0013
topic: "Commands must explicitly re-read their input context documents"
research: thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md
git_commit: 668d48f
branch: main
repository: toby-plugins
status: done
---

# Implementation Plan: TP-0013 — Explicit re-reading of input context documents

## Overview

Make every consuming tce command explicitly and **unconditionally** re-read its input
context documents (ticket, research, plan) **in chain order** (ticket → research →
plan) on every invocation — even when those documents already appear earlier in the
conversation or were produced by an earlier step in the same session. Add a durable
`CLAUDE.md` rule so future command edits preserve this. Markdown-only; no scripts or
manifests change.

## Current state

Per the research (`thoughts/shared/research/2026-06-18-TP-0013-...md`):

- Discovery (`ticket.sh` + globs) already exists in every command. Only the **read
  framing** needs tightening — instructions presuppose a fresh invocation and never say
  "re-read even if already in this conversation."
- `work.md:221` says *"Read the plan document (you already have it in context, but
  verify)"*; `work.md` Phase 3 gives no read instruction for ticket/research and Phase
  4 never re-touches them.
- `implement.md:62-64` reads in reverse chain order (plan → research → ticket).
- `plan.md`/`implement.md` carry intentional "DO NOT re-read **source files**"
  guidance that must be **preserved** — TP-0013 concerns the context **documents**.

## Desired end state

- Every consuming command (`research`, `plan`, `implement`, `review`, `work`,
  `quickfix`) carries an explicit, unconditional instruction to read its input context
  document(s) in full at the relevant phase, in chain order, with wording that forbids
  "skip if already read / already in context."
- `implement.md` reads ticket → research → plan (chain order, per checkpoint decision).
- The source-file "DO NOT re-read" guidance is untouched and clearly distinguished.
- `CLAUDE.md` has a new RULE section codifying the behavior.
- `claude plugin validate ./plugins/tce` passes.

## The standard clause (wording to reuse, tailored per command)

A short imperative placed at each command's input-read step. Substance to convey
(exact phrasing adapted to each command's document set and house voice):

> Read these input documents now, fully (Read tool, no limit/offset) and in this order
> — **even if they already appear earlier in this conversation or were produced by an
> earlier step in this same session.** Re-reading freshly anchors your attention on the
> inputs that matter to this step without discarding the surrounding history. (This
> applies to these context documents only; it does **not** change the guidance below
> about not re-reading source files the research already covers.)

The "order" named per command: research → just the ticket; plan → ticket then research;
implement → ticket then research then plan; review → ticket then research then plan
(then implementation diff); work/quickfix → per phase as below.

---

## Phase 1: Add the CLAUDE.md rule

**File:** `CLAUDE.md` — insert a new `##` section between "Composite commands must track
the single-step commands" (ends ~line 188) and "`/tce:refresh` re-analysis must track
`/tce:init`'s analysis" (starts ~line 190).

Match house style: `##` heading stating the invariant; one setup paragraph naming the
artifacts (ticket/research/plan context documents) and the drift/skip risk; one
`**RULE: …**` paragraph with the bold span covering the whole directive through "in the
same commit," then unbolded scope. Cross-reference the Composite-commands section (the
rule holds inside `work`/`quickfix` too) and the Core design rule (commands load context
from files at runtime, not from fading conversation state). Tag `(TP-0013)`.

Content the section must establish:
- Consuming commands (`research`, `plan`, `implement`, `review`, `work`, `quickfix`)
  must explicitly re-read their input context documents in chain order
  (ticket → research → plan) on every invocation, even when those documents already
  appear earlier in the conversation or were produced by an earlier step in the same
  session.
- This is distinct from — and must not weaken — the "don't re-read **source files** the
  research already covers" guidance in `plan.md`/`implement.md`.
- RULE: when you add/edit a consuming command or change which documents it consumes,
  keep its explicit ordered re-read instruction intact (and mirror into the composites
  per the composite-tracking rule), in the same commit.

### Success criteria
- [ ] New `##` section present between the two named sections, in house style with a
      `**RULE:**` paragraph and the `(TP-0013)` tag.
- [ ] Cross-references the Composite-commands section and the Core design rule.

---

## Phase 2: Tighten the single-step consuming commands

Apply the standard clause, tailored, at each command's input-read step. **Preserve all
existing source-file "DO NOT re-read" language.**

1. **`plugins/tce/commands/research.md`** — at the ticket read (`:81`): add the
   unconditional re-read clause to "Read it FULLY" (chain order = ticket only).

2. **`plugins/tce/commands/plan.md`** — at the ordered ticket (`:64`) + research
   (`:90`/`:224`) reads: frame them as unconditional ordered re-reads (ticket →
   research). Explicitly scope the new clause to the context documents so it does not
   contradict `:92,94,100,226,322-324,649` (source files — keep verbatim).

3. **`plugins/tce/commands/implement.md`** —
   - Reorder the read block `:62-64` to **ticket → research → plan** (chain order).
     Renumber the steps accordingly; keep each "Read … fully/completely" verb.
   - Add the unconditional re-read clause covering all three documents in that order.
   - Reconcile `:55`, `:57` ("Repository state guarantee"), and `:66` ("These three
     documents ARE your context") so they no longer read as license to skip a fresh
     read of the **documents**, while keeping their point that you needn't re-read
     **source files**. Keep `:68-71` (source-file guidance) intact.

4. **`plugins/tce/commands/review.md`** — at `:119` "Read all discovered documents
   FULLY" (already chain order ticket → research → plan): add the unconditional
   "even if already in this conversation" clause.

### Success criteria
- [ ] Each of the four commands has an explicit, unconditional re-read clause at its
      input-read step, naming chain order where >1 document.
- [ ] `implement.md` read order is ticket → research → plan, steps renumbered cleanly.
- [ ] No existing source-file "DO NOT re-read" clause is removed or weakened; the new
      clause is explicitly scoped to context documents.
- [ ] `claude plugin validate ./plugins/tce` passes.

---

## Phase 3: Tighten the composite commands

Per the composite-tracking rule, mirror Phase 2 into the composites.

1. **`plugins/tce/commands/work.md`** —
   - **Phase 3 (Planning, `:183-211`):** add an explicit step to re-read, in order, the
     **ticket then research document** before planning. Keep `:191`'s source-file
     clause ("DO NOT re-read source files it already covers") unchanged.
   - **Phase 4 (Implementation, `:215-253`):** replace `:221` ("Read the plan document
     (you already have it in context, but verify)") with an explicit re-read, in chain
     order, of **ticket → research → plan** — with the unconditional clause. This both
     removes the offending "already in context" phrasing and restores the ticket/
     research reads Phase 4 currently omits.

2. **`plugins/tce/commands/quickfix.md`** —
   - **Phase 3 (`:132`):** "Read the ticket" → "Read the ticket FULLY" + unconditional
     clause.
   - Phases 4/5 delegate to `tce:plan` / `tce:implement` and inherit their (now fixed)
     read behavior — no change needed beyond confirming `:161`/`:185` descriptions
     still read correctly.

### Success criteria
- [ ] `work.md` Phase 3 re-reads ticket → research; Phase 4 re-reads ticket → research
      → plan; the "already in context, but verify" phrasing is gone; `:191` source-file
      clause preserved.
- [ ] `quickfix.md` Phase 3 reads the ticket FULLY with the unconditional clause.
- [ ] Composite reads are consistent with the single-step commands (composite-tracking
      rule satisfied in the same commit).
- [ ] `claude plugin validate ./plugins/tce` passes.

---

## Verification (whole change)

- [ ] `claude plugin validate .`
- [ ] `claude plugin validate ./plugins/tce`
- [ ] `claude plugin validate ./plugins/tmt`
- [ ] Manual read-through: every consuming command names its inputs, in chain order,
      with an unconditional re-read clause; no source-file guidance was weakened.

## Testing strategy

Markdown command prompts have no runtime tests; verification is manifest validation
(`claude plugin validate`) plus a manual diff read-through confirming the four
constraints above. No scripts or JSON manifests are modified.

## Notes

- Single-step + composite edits ship together (one or grouped commits) to satisfy the
  composite-tracking rule.
- Out of scope (per ticket): chain restructuring, changing what commands write, read
  deduplication, and any change to the source-file "DO NOT re-read" guidance.
