---
date: 2026-06-18
ticket: TP-0013
topic: "Commands must explicitly re-read their input context documents"
git_commit: eec724bdd27837ee1610ebe71c4498d030cf215a
branch: main
repository: toby-plugins
status: complete
---

# Research: TP-0013 — Explicit re-reading of input context documents

## Research question

Each consuming tce command must explicitly and **unconditionally** re-read its input
context documents (ticket, research doc, plan doc) **in chain order** on every
invocation, instead of relying on conversation history when a prior step ran in the
same context. Where do the commands currently fall short, what are the exact edit
sites, and where should a durable CLAUDE.md rule live?

## Summary

The discovery/lookup machinery is **already present in every consuming command**
(`${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh` plus `thoughts/shared/{research,plans}/*`
glob fallbacks). The gap is purely in the **framing of the reads**: instructions are
phrased around documents being "provided", "mentioned", or "discovered", which
silently presupposes a fresh invocation. None of the commands contain an explicit
"re-read these inputs fully even if they already appear earlier in this conversation"
clause. Two composite phrasings actively encourage skipping a fresh read:

- `work.md:221` — *"Read the plan document (you already have it in context, but
  verify)"* — the clearest offender.
- `work.md` Phase 3 (planning) gives **no read instruction at all** for the ticket or
  research doc, and Phase 4 (implementation) reads only the plan, never re-touching
  the ticket or research.

A second, smaller issue surfaced: `implement.md` deliberately reads in **reverse**
chain order (plan → research → ticket, `implement.md:62-64`), which conflicts with the
ticket's "read in chain order" requirement (ticket → research → plan). This is the one
genuine decision for the checkpoint.

The fix is markdown-only: tighten read framing in the consuming commands, fix the two
work.md phrasings, optionally reorder implement.md, and add one `CLAUDE.md` RULE
section. **Critical constraint:** the existing "DO NOT re-read **source files** the
research already covers" guidance (plan.md, implement.md) must be *preserved* — the new
rule is about the context **documents**, not the underlying source files.

## Key distinction the fix must hold

There are two different "re-read" concerns in these commands, and they point opposite
ways. The fix must not blur them:

1. **Context documents (ticket, research, plan)** — must **always** be re-read fully,
   in chain order, on every invocation. This is what TP-0013 adds.
2. **Source files the research already analyzed** — should **NOT** be re-read; the
   research doc is the codebase context. This is existing, intentional guidance
   (`plan.md:94,100,226,649`; `implement.md:55,57,70-71`) and must stay intact.

## Detailed findings

### Discovery mechanism (shared)

`plugins/tce/scripts/ticket.sh` globs `thoughts/` for filenames containing the ticket
ID and lists paths (it does not read them). Every consuming command already calls it
and/or globs `thoughts/shared/research/*[PREFIX]-XXXX*.md` and
`thoughts/shared/plans/*[PREFIX]-XXXX*.md`. So for every command, **discovery exists —
only the read framing needs tightening**, with two small exceptions noted below.

### `plugins/tce/commands/research.md` (produces research; consumes ticket)

- Inputs/order: ticket first (`:81` "Read it FULLY"), then optional parent ticket +
  parent research/plan (`:94-96`, gated `(if they exist)`).
- Ticket read is already unconditional; no "already in context" / "DO NOT re-read"
  escape hatch for it. `:438` even reinforces fresh codebase research.
- **Gap:** no explicit "re-read even if it already appeared earlier in this
  conversation" clause on the ticket read.

### `plugins/tce/commands/plan.md` (consumes ticket → research)

- Inputs/order: ticket (`:64` "Read it FULLY") → research doc (`:90` "Read the research
  document FULLY"; `:224`). Discovery via `ticket.sh` (`:67,115,220`) + glob (`:116`).
- Research-doc read is unconditional **once detected**, but gated on existence
  detection (`:88,113,223/231`).
- Heaviest "DO NOT re-read" language in the codebase (`:92,94,100,226,322-324,649`) —
  **all scoped to source files the research analyzed**, not the context docs. Keep.
- **Gap:** ticket/research reads framed around being "provided"/"mentioned"/detected;
  no "re-read fresh on every invocation regardless of conversation history" clause.

### `plugins/tce/commands/implement.md` (consumes plan → research → ticket today)

- **Explicit chain order, but reversed** relative to the ticket's requirement:
  `:62-64` reads (1) plan, (2) research, (3) ticket. The ticket asks for chain order =
  ticket → research → plan.
- Reads themselves are unconditional ("Read the plan completely", etc., `:62-64,147`).
- Load-bearing framing that justifies relying on already-loaded context:
  - `:55` "The ticket, research, and plan documents were specifically created in steps
    1-3 to provide you with all the context you need."
  - `:57` "Repository state guarantee: The research and plan were executed on the exact
    same state of the repository … the context documents accurately reflect the current
    codebase."
  - `:66` "These three documents ARE your context."
  - `:68-71` "DO NOT re-read source files …" — **source files only; keep.**
- **Gaps:** (a) read order is reverse of chain order; (b) no "re-read fully even if
  already in this conversation" clause; (c) `:55/:57/:66` should be reconciled so they
  don't read as license to skip a fresh read of the *documents* (while keeping the
  source-file guidance).

### `plugins/tce/commands/review.md` (consumes ticket → research → plan → implementation)

- `:119-123` "Read all discovered documents FULLY": ticket → research → plan →
  discussion docs. **Already unconditional and already in chain order.** No "DO
  NOT re-read" / "already in context" escape hatch anywhere.
- **Gap:** only the explicit "even if already in this conversation" clause is missing.

### `plugins/tce/commands/work.md` (composite; re-describes research/plan/implement inline)

- Phase 1 (`:71`) reads ticket FULLY. Good.
- Phase 3 Planning (`:183-211`): lists ticket + research as inputs (`:185`) and says
  `:191` "Use the research document as the codebase context (DO NOT re-read source
  files it already covers)" — **source-file guidance, fine** — but gives **no
  instruction to (re-)read the ticket or research doc**. Assumes they're in context.
- Phase 4 Implementation (`:221`) "Read the plan document (you already have it in
  context, but verify)" — **the clearest offender**; and it **never re-touches the
  ticket or research** in Phase 4.
- **Gaps:** add explicit ordered re-reads in Phase 3 (ticket → research) and Phase 4
  (ticket → research → plan); fix the `:221` "already in context" phrasing; preserve
  `:191`'s source-file clause.

### `plugins/tce/commands/quickfix.md` (composite; delegates plan/implement to skills)

- Phase 3 (`:132`) "Read the ticket created in Phase 2" — present but **does not say
  FULLY**.
- Phases 4/5 **delegate** to the `tce:plan` (`:160`) and `tce:implement` (`:184`)
  skills, passing only the ticket ID. The actual reads happen inside those commands —
  so **fixing plan.md and implement.md automatically fixes quickfix's planning and
  implementation reads**. `:161/:185` only *describe* the delegated procedure.
- **Gap:** Phase 3 ticket read should say FULLY + carry the unconditional clause; no
  other quickfix-specific change needed (inherited via delegation).

### `CLAUDE.md` — where the rule goes

Existing command-contract RULE sections and their house style:

- "Composite commands must track the single-step commands" (`:161-188`)
- "`/tce:refresh` re-analysis must track `/tce:init`'s analysis" (`:190-205`)
- "The AskUserQuestion guidelines block is duplicated …" (`:207-223`)

**House template** for a sync/invariant rule: `##` heading phrased as the invariant; a
short setup paragraph naming the artifacts and the drift risk ("can silently drift");
then a single `**RULE: …in the same commit**` paragraph where the **bold span covers the
whole directive** (trigger → action → "in the same commit"), then unbolds for scope;
trailing cross-references by quoted section name, often with a TP tag.

**Recommended placement:** a new `##` section inserted **between** "Composite commands
must track the single-step commands" (ends `:188`) and "`/tce:refresh` re-analysis …"
(starts `:190`) — it joins the cluster of command-contract rules and sits next to the
only other section that spells out the research → plan → implement chain. It should
cross-reference the Composite-commands section (the rule must hold inside the
composites too) and the Core design rule (commands load their context from
files/docs at runtime, not from each other's markdown or fading conversation state).

## Edit-site catalog (for planning)

| File | Edit |
|------|------|
| `research.md` | Add unconditional "re-read even if already in context" clause to the ticket read (`:81`). |
| `plan.md` | Frame ticket (`:64`) + research (`:90/:224`) reads as unconditional ordered re-reads (ticket → research); keep all source-file "DO NOT re-read" clauses. |
| `implement.md` | Reorder reads to ticket → research → plan (`:62-64`) [pending checkpoint]; add unconditional re-read clause; reconcile `:55/:57/:66` so they don't license skipping a fresh **document** read; keep `:70-71` source-file guidance. |
| `review.md` | Add the unconditional "even if already in this conversation" clause to `:119`. |
| `work.md` | Phase 3: add ordered re-read of ticket → research before planning; Phase 4: re-read ticket → research → plan; rewrite `:221`; keep `:191` source-file clause. |
| `quickfix.md` | Phase 3 (`:132`): read ticket FULLY + unconditional clause. (Planning/impl reads inherited from plan.md/implement.md via skill delegation.) |
| `CLAUDE.md` | New RULE section between `:188` and `:190`. |

## Open questions

1. **implement.md read order.** It currently reads **plan → research → ticket**
   deliberately (most-actionable-first). The ticket asks for **chain order =
   ticket → research → plan**. Reorder implement.md to chain order (recommended, per
   the ticket's explicit instruction), or keep its existing plan-first order? This is
   the one decision needing confirmation. (review.md and the composites already match
   chain order; only implement.md conflicts.)

## Questions resolved by research (no user input needed)

- *Does discovery exist or is a read step missing?* Discovery exists everywhere; only
  framing needs tightening (the lone genuinely-missing reads are work.md Phase 3
  ticket/research and Phase 4 ticket/research).
- *Should a shared, byte-identical re-read block be used (like the AskUserQuestion
  block)?* No — each command's input set differs (research: ticket; plan:
  ticket+research; implement/review: all three; composites: per-phase), so the
  instruction is necessarily per-command, not a duplicated block.
- *Composite handling.* `work.md` needs explicit inline re-reads (it re-describes the
  steps); `quickfix.md` inherits planning/impl reads via skill delegation, so only its
  Phase 3 ticket read needs the clause.

## Related

- `CLAUDE.md` "Composite commands must track the single-step commands" — any edit to
  research/plan/implement framing must be mirrored into work.md/quickfix.md in the
  same commit.
- Ticket: `thoughts/shared/tickets/TP-0013-explicit-context-document-reads.md`.
