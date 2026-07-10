---
date: 2026-07-10T09:05:00+0200
git_commit: 89628e7898046128bbf53f2e22037ca15733d1c1
branch: main
repository: toby-plugins
topic: "TP-0022 — Sync rule for the ticket-sufficiency criteria (three copies)"
tags: [research, codebase, claude-md, sync-rules, ticket-sufficiency, tce]
status: complete
last_updated: 2026-07-10
---

# Research: TP-0022 — Sync rule for the ticket-sufficiency criteria (three copies)

**Date**: 2026-07-10T09:05:00+0200
**Git Commit**: 89628e7898046128bbf53f2e22037ca15733d1c1
**Branch**: main
**Repository**: toby-plugins

## Research Question

The three-part ticket-sufficiency definition (scope determinable, outcome
observable, at least one concrete anchor) lives in three files without a
same-commit sync rule in `CLAUDE.md`. TP-0022 asks to add such a rule (in the
style of the existing duplication rules), designate a canonical copy, and
reconcile any drift the three copies have already accumulated. Research needs to
establish: (a) the exact current text of the three copies and where/how they
have drifted; (b) the structural pattern the existing `CLAUDE.md` sync rules
share, so the new rule matches; (c) where the new rule slots in; and (d) what
"reconcile drift" concretely means here given the copies are intentionally in
different registers.

## Summary

All three copies express the **same three-part test with the same intent** —
none adds a fourth criterion or drops one of the three. But they are **not
byte-identical, and were never meant to be**: they sit in three different
registers by design.

- `research.md` — an operational **check** the command runs, with a numbered
  list and example anchors.
- `work.md` — a deliberate **one-line compression** (per the composite-tracking
  rule, `work.md` re-describes `research` inline), with no descriptive
  sub-clauses.
- `tickets.md` template — a descriptive, **consumer-facing contract** ("What tce
  needs from a ticket") in prose bullets, richer than the other two.

This is the crucial design fact for the ticket: **the new rule cannot be a
"keep the copies byte-identical" rule** like the AskUserQuestion block (which
governs nine literally-identical copies). It must require the **three-part
substance** (the three criteria and their meaning) to stay in sync while
allowing the three registers to differ — structurally this is the
**composite-tracking / TP-0013 family** of *semantic-mirror* rules, not the
AskUserQuestion *byte-identical* rule.

The only **substantive** drift found is in the anchor examples: `tickets.md`
lists "code area" as a fifth anchor example that `research.md` omits. The
remaining differences (criterion labels, a "from the ticket" qualifier, a
boundary parenthetical, the exclusion-list header) are register/prose
differences that do not change the substance.

The `CLAUDE.md` sync-rule pattern is well established (six dedicated rules
forming a contiguous cluster) and gives a precise template to match, including
where to place the new rule.

## Detailed Findings

### The three copies and their exact drift

**Copy 1 — `plugins/tce/commands/research.md`, `## Ticket Sufficiency Check
(before any research)` (lines 114–133).** The operational check. Three criteria
as a numbered list (lines 121–123):

1. **Scope is determinable** — "what should change or be built, and roughly
   where the boundary is."
2. **Outcome is observable** — "you can tell what 'done' would look like, even
   informally."
3. **There's an anchor** — "at least one concrete pointer into the system
   (feature, screen, command, error message) so research has somewhere to
   start." — **four** example anchors.

Also carries an "Explicitly NOT required" exclusion clause (lines 125–127) with
a free-form-text parenthetical, and it cross-references the template: "see also
'What tce needs from a ticket' in `tickets.md`" (lines 118–119).

**Copy 2 — `plugins/tce/commands/work.md`, Phase 1 step 4 (line 76).** A single
inline sentence, comma-compressed: "scope determinable, outcome observable, at
least one concrete anchor into the system." No numbered list, no example
anchors, no exclusion clause. Cross-references `/tce:research` ("from
`/tce:research`"). This compression is intentional per the composite-tracking
rule.

**Copy 3 — `plugins/tce/templates/tce/tickets.md`, `## What tce needs from a
ticket` (lines 64–90).** The consumer-facing contract, richest of the three.
Three criteria as prose bullets (lines 71–77):

1. **Clear scope** — "what should change or be built, and roughly where the
   boundary is (what is explicitly not part of it, if anything)."
2. **Observable outcome** — "you can tell from the ticket what 'done' would look
   like, even informally."
3. **An anchor** — "at least one concrete pointer into the system (a feature,
   screen, command, error message, or code area) so research has somewhere to
   start." — **five** example anchors, adds "or code area."

Carries a "Not required" exclusion clause (lines 79–80, no free-form
parenthetical), an "if additionally present, exploited" block for Open
Questions / Questions for Research/Planning / Acceptance Criteria, and
cross-references both consumers ("`/tce:research` (and `/tce:work`)").

**Drift table (criterion labels):**

| # | research.md | work.md | tickets.md |
|---|-------------|---------|------------|
| 1 | Scope is determinable | scope determinable | Clear scope |
| 2 | Outcome is observable | outcome observable | Observable outcome |
| 3 | There's an anchor | at least one concrete anchor into the system | An anchor |

**Concrete drifts, ranked by materiality:**

1. **Anchor examples (substantive).** `tickets.md` lists five including "code
   area"; `research.md` lists four *without* "code area"; `work.md` lists none.
   "code area" is a genuine category of anchor missing from the operational
   check — the one drift that changes what an author/command would treat as a
   valid anchor.
2. **Criterion labels (register).** Every label is worded differently between at
   least two copies ("Scope is determinable" vs "Clear scope"; "Outcome is
   observable" vs "Observable outcome"). Stylistic, not substantive.
3. **Descriptive qualifiers (register).** `tickets.md` alone adds "(what is
   explicitly not part of it, if anything)" to scope and "from the ticket" to
   outcome; `research.md` alone adds a free-form-text parenthetical to the
   exclusion list.
4. **Exclusion-list header (register).** "Explicitly NOT required" (research.md)
   vs "Not required" (tickets.md); absent in work.md.

### The existing `CLAUDE.md` sync-rule pattern

Six dedicated sync/tracking rules form a **contiguous cluster, lines 171–322**,
between "Migrations & version markers" (ends 169) and "Testing changes" (starts
324):

1. `## Composite commands must track the single-step commands` (171–199) — no
   ticket suffix; single-step commands are **canonical**, `work.md`/`quickfix.md`
   named "derived artifacts"; RULE sentence + "in the same commit"; verification
   "re-read both composite commands."
2. `## The plan-compliance gate must stay wired … (TP-0020)` (201–236) —
   explicit "four files that must move together" list before the RULE.
3. `## Invocation control: disable-model-invocation … (TP-0017)` (238–260) — a
   re-derivation rule (bold imperative, no `RULE:`/"same commit").
4. `## Consuming commands must re-read their input context documents (TP-0013)`
   (262–286) — RULE + "in the same commit," chain-order designation.
5. `` ## `/tce:refresh` re-analysis must track `/tce:init`'s analysis `` (288–303)
   — bidirectional ("and vice versa").
6. `## The AskUserQuestion guidelines block is duplicated — keep the copies
   identical` (305–322) — **byte-identical**, "nine copies," verification
   "extracting each block … and diffing."

**Shared structure to match:**
- **Heading (`##`):** a declarative invariant ("X must track Y" / "The Z is
  duplicated — keep the copies identical"). Recent rules append the ticket ID —
  `(TP-0022)` matches convention.
- **Body before the RULE:** one or two setup paragraphs naming the artifacts and
  why they drift; rules 2 and 6 add an explicit enumerated file list first.
- **The RULE sentence:** a **bold** sentence in its own paragraph, literal
  `**RULE:` prefix in five of six, containing the exact phrase **"in the same
  commit"**; filenames backticked; counts ("nine copies", "four files")
  load-bearing.
- **Verification (optional but valued):** AskUserQuestion and Composite give an
  explicit method.
- **Cross-referencing:** recent rules point back to related rules ("this is the
  composite-tracking rule applied to …", "per the composite-tracking rule
  above").

**Placement:** natural insertion is **immediately after the AskUserQuestion rule**
(new `##` at line 323, before `## Testing changes` at 324), keeping it in the
sync-rule cluster and adjacent to the other duplication rule — or immediately
before AskUserQuestion. Both keep it inside 171–322.

### Origin and framing (from the review)

The source is `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`
Section 4, item 5 (lines 261–263), filed under "Smaller usability notes"
(low-severity). It only diagnoses the missing rule and points to the
AskUserQuestion block as the precedent; it **deliberately leaves open** which
copy is canonical and how the rule is framed — those are this ticket's design
decisions, not inherited constraints. (Note: the same review's Section 2 argues
against over-duplication in general, but the core design rule forbids
cross-plugin/runtime de-duplication here, so "duplicate + sync rule" is the
sanctioned approach — the ticket's Out-of-Scope confirms this.)

## Code References

- `plugins/tce/commands/research.md:114-133` — Copy 1, the operational "Ticket
  Sufficiency Check"; anchor examples at :123 (four, no "code area").
- `plugins/tce/commands/work.md:76` — Copy 2, the one-line compressed mirror
  (Phase 1 step 4).
- `plugins/tce/templates/tce/tickets.md:64-90` — Copy 3, "What tce needs from a
  ticket"; anchor examples at :75-77 (five, includes "code area").
- `CLAUDE.md:171-322` — the sync-rule cluster the new rule joins.
- `CLAUDE.md:305-322` — the AskUserQuestion rule (byte-identical precedent, the
  natural neighbor).
- `CLAUDE.md:323-324` — the boundary with "## Testing changes" (insertion point).
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md:261-263` —
  the review item that spawned TP-0022.

## Architecture Documentation

- **Deliberate duplication + sync rule** is an established `CLAUDE.md` idiom:
  the core design rule forbids cross-plugin references and runtime reads of one
  command's markdown by another, so content that must appear in several command
  bodies is duplicated and governed by a stated same-commit rule. The sufficiency
  trio is a textbook instance (two of the three copies are tce command bodies,
  the third is a consumer template — none can read the others at runtime).
- **Two flavors of sync rule already coexist:** *byte-identical* (AskUserQuestion,
  nine peers, verified by diffing) vs *semantic-mirror* (composite-tracking,
  TP-0013 — the derived copy re-describes the canonical one in its own register
  and must stay faithful in substance). The sufficiency trio belongs to the
  **semantic-mirror** flavor: `work.md` compresses to one line and `tickets.md`
  is descriptive prose, so demanding byte-identity would be wrong and would fight
  the composite-tracking rule that intentionally compresses `work.md`.
- **Canonical-copy candidates.** `tickets.md`'s "What tce needs from a ticket" is
  the consumer-facing contract, the richest copy, the one the template README
  layer treats as the source of truth for ticket expectations, and the one
  `research.md` already cross-references as the reference ("see also 'What tce
  needs from a ticket' in `tickets.md`"). That makes it the natural canonical
  copy — the ticket's own "Questions for Research/Planning" flags it as the
  candidate to confirm.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section
  4 item 5 is the origin; Section 2 items 1–2 give the (countervailing but
  overridden) general preference for less duplication.
- The ticket's own Notes (2026-07-03, TP-0016) already corrected an outdated
  Out-of-Scope rationale: runtime reads of plugin files are now sanctioned
  (`plugins/tce/references/`), but the scope decision stands — the trio stays as
  synced copies because the criteria govern prose in three different contexts,
  not one moment of use. So a point-of-use reference file (the TP-0013/TP-0016
  pattern) is **not** the right tool here; a sync rule is.

## Related Research

None specific to this ticket; the closest prior art is the set of existing
sync-rule sections in `CLAUDE.md` themselves (enumerated above) and the TP-0016
reference-file pattern (which this ticket deliberately does *not* adopt).

## Open Questions

These map to the ticket's "Questions for Research/Planning" and are the items for
the Phase 2 checkpoint:

1. **Canonical copy.** Research strongly points to `tickets.md`'s "What tce needs
   from a ticket" (consumer contract, richest copy, already cross-referenced as
   the reference by research.md). Confirm before writing the rule, since the rule
   names it as the conflict-resolution source.
2. **Reconciliation scope.** The one substantive drift is the missing "code area"
   anchor example in `research.md` — reconcile by adding it there (toward the
   canonical copy). The register differences (labels, "from the ticket" qualifier,
   boundary/free-form parentheticals, exclusion header) do **not** change the
   three-part substance and can reasonably be left as-is (they reflect the three
   registers the sync rule explicitly permits). Decision needed: reconcile only
   the substantive drift ("code area"), or also normalize register wording?
3. **Placement.** Standalone `##` section immediately after the AskUserQuestion
   rule (tail of the sync-rule cluster, before "Testing changes") is the natural
   fit and matches the pattern; folding into the AskUserQuestion section would
   conflate byte-identical with semantic-mirror semantics. Confirm standalone.
4. **Scope tightness.** The ticket's third planning question invites folding other
   small duplicated fragments into the rule "only if trivially found." Research
   found none that belong to *this* trio; recommend keeping scope to the three
   sufficiency copies.

## tce Config Drift (only if found)

None. `.claude/tce/profile.md` (marketplace monorepo, no runtime/typecheck/lint,
test = `claude plugin validate`) and the `tickets.md` backend adapter (tmt,
`TP-NNNN`, files in `thoughts/shared/tickets/`, Status enum) both match the repo
as it stands. No `/tce:refresh` recommendation.
