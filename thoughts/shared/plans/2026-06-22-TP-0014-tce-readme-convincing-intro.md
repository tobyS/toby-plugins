---
date: 2026-06-22
ticket: TP-0014
topic: "Rewrite the tce README intro to be hands-on first and convincingly motivated"
status: ready
last_updated: 2026-06-22
research: thoughts/shared/research/2026-06-22-TP-0014-tce-readme-convincing-intro.md
---

# Plan: TP-0014 — convincing, hands-on-first tce README intro

## Overview

Rewrite the opening of `plugins/tce/README.md` so it leads with a concrete,
narrated worked example (a neutral illustrative task flowing ticket → research →
plan → implement, with accurate `thoughts/` artifact paths), names the "Claude
already handles medium tasks fine without a process" objection head-on, and makes
three value props explicit — reliability via explicitation, team-wide quality
equalization, self-learning via repo-stored context — speaking to both individual
and team readers. Documentation-only; everything below the intro region is
preserved. Builds on TP-0011's structure without regressing it.

Two confirmed copy decisions from the question checkpoint:
- **Worked-example subject:** a *neutral illustrative* task ("add document
  tagging") with accurate, real-form `thoughts/` paths — evergreen, not tied to
  repo history.
- **Voice:** echo the author's memorable handles — "centaur", "auto-complete on
  steroids", and name "AI slop" — **once**, after the example has done the
  convincing.

## Current state

Per research (`thoughts/shared/research/2026-06-22-TP-0014-tce-readme-convincing-intro.md`),
the current file flows: H1 (line 1) → tagline block + "Built by Toby" blurb (3–24)
→ Contents/TOC (26–37) → `## Why context engineering?` (38–57, conceptual, the first
substantive thing the reader meets) → Requirements/Install/Set up/Update/Commands/
Agents/Parameterization (59–213) → `## Contributing` → `../../CONTRIBUTING.md` (215–219).

There is no worked example, the objection is never named, and the three value props
are at best implicit. The problem is ordering and motivation, not missing facts.

## Desired end state

The reader meets, in order: a tagline that states category + concrete capability and
previews the payoff; the "Built by Toby" blurb; a TOC; then a **new worked-example
section** that *shows* one task moving through the chain and its deposited artifacts,
immediately followed by an objection-and-value paragraph; then the **reframed**
`## Why context engineering?` that explains *why the walkthrough works* and surfaces
the self-learning prop. All existing usage sections, the heading, the blurb, the
grouped command tables, and the bottom CONTRIBUTING link are unchanged.

## What we're NOT doing

- No changes to the marketplace root `README.md` or the tmt README.
- No changes to plugin behavior, commands, agents, scripts, hooks, manifests, templates.
- No version bumps or release tags.
- No new images/diagrams/badges; the example is text/Markdown.
- Not deleting `## Why context engineering?` or its 4-step narrative (load-bearing per
  TP-0011) — only reframing/repositioning it as the post-demonstration explanation.
- Not re-litigating TP-0011 decisions (heading, blurb wording, command grouping,
  CONTRIBUTING extraction).

## Implementation

### Phase 1 — Top-of-file value framing + the worked-example section

**File:** `plugins/tce/README.md`

1. **Tighten the opening tagline (around lines 3–7)** so the first line states
   category + concrete capability and previews the payoff for a skeptical reader.
   Keep the `ticket → research → plan → implement` naming and the mention of the
   review/discussion/design commands + research subagents. Add at most one sentence
   foreshadowing "make a good result repeatable instead of lucky." Keep the "In a
   hurry?" paragraph (`/tce:work`, `/tce:quickfix`) and the ticket-agnostic paragraph
   intact. Keep the "Built by Toby" blockquote in its current position (between the
   intro block and the TOC) — the new value/example content goes **after** the blurb
   as its own section, so the quick start/value is not buried by the promo.

2. **Add a TOC entry (lines 26–37)** for the new section as the **first** list item
   (before "Why context engineering?"). Use the exact heading text chosen in step 3
   and a matching anchor.

3. **Insert a new section** immediately after the TOC and **before**
   `## Why context engineering?`. Heading: `## See it work` (chosen for scannability;
   matches the TOC entry). Contents:
   - One or two setup sentences: a neutral illustrative task, e.g. "Say you want to
     add document tagging."
   - A compact **numbered walkthrough** of the four steps. Each item names the command
     and the artifact it deposits, with real-form paths:
     - `/tce:ticket` → `thoughts/shared/tickets/[PREFIX]-XXXX-document-tagging.md`
       (the WHAT/WHY, scope, acceptance criteria)
     - `/tce:research` → `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md`
       (existing patterns, constraints, the right library/API)
     - `/tce:plan` → `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md`
       (phased steps + success criteria, reviewed before any code)
     - `/tce:implement` → the code change, plus a `…-document-tagging.status.md`
       progress file; commits per phase.
     Use `[PREFIX]-XXXX` (the established placeholder) and `YYYY-MM-DD` so the example
     stays evergreen and consistent with the rest of the docs.
   - A small **fenced tree** showing the four deposited files under `thoughts/shared/`
     so the "shared context" claim is visible, not asserted.
   - A short **objection-and-value paragraph** right after the tree. Structure:
     concede capability ("Claude already handles a well-specified medium task fine —
     often first try"); pivot to where tce adds value: (a) **reliability** — the chain
     spends the context budget deliberately so a good result is *repeatable, not
     lucky* (once the thinking is pre-formed, codegen is "auto-complete on steroids");
     (b) **a trail your team inherits** — every step is a committed Markdown file your
     teammates and the next Claude session read, so output quality levels up across the
     team, not just in one head/session; (c) **you stay the decision-maker** — the
     "centaur" rides the model, owning intent and scope (no "AI slop" to review after
     the fact). Explicitly address **both** the individual ("what you get today") and
     the team/adopter ("why standardize this"). Echo each coined handle exactly once.

**Verification (Phase 1):**
- [ ] `claude plugin validate ./plugins/tce` passes (and `.`, `./plugins/tmt`).
- [ ] The new `## See it work` section exists before `## Why context engineering?`,
      contains the four-step walkthrough naming each command + its artifact path, and
      a fenced `thoughts/shared/` tree.
- [ ] The objection is named explicitly; "centaur", "auto-complete on steroids", and
      "AI slop" each appear exactly once; both individual and team readers are addressed.
- [ ] The TOC has a matching first entry whose anchor resolves to the new heading.
- [ ] Heading `# tce — Toby Context Engineering` and the "Built by Toby" blockquote
      are unchanged and in place.

### Phase 2 — Reframe `## Why context engineering?` as the post-demonstration "why"

**File:** `plugins/tce/README.md`

1. **Add a one-line lead-in** at the top of `## Why context engineering?` tying back
   to the walkthrough (e.g. "That walkthrough works because each step hands Claude
   exactly the context it needs, then writes it down."). Keep the existing 4-step
   numbered narrative (Tickets / Research / Plans / Implementation) verbatim or lightly
   edited — it is load-bearing.

2. **Surface the self-learning prop explicitly** in the persistence paragraph (current
   lines ~49–51): make clear the committed artifacts mean *the next ticket — and your
   teammates — start from this record, so the project gets easier to work on over time*
   (reliability + self-learning + equalization, stated as mechanism, not adjectives).
   Keep the existing "supersedes the claude-template" + blog-link paragraph intact.

**Verification (Phase 2):**
- [ ] `claude plugin validate ./plugins/tce` passes.
- [ ] `## Why context engineering?` now reads as the explanation that follows the
      demonstration (has the lead-in), retains its 4-step list, and the persistence
      paragraph explicitly states the self-learning/repeatability/equalization payoff.
- [ ] All three value props are present across the intro (reliability,
      team-equalization, self-learning) — verifiable by reading the new section + the
      reframed persistence paragraph.

## Success criteria (whole ticket — maps to acceptance criteria)

Automated:
- [ ] `claude plugin validate .`, `claude plugin validate ./plugins/tce`, and
      `claude plugin validate ./plugins/tmt` all pass.

Manual:
- [ ] Intro leads with a hands-on worked example (the chain + artifact paths under
      `thoughts/`) **before** any conceptual process explanation.
- [ ] The "Claude handles medium tasks fine without a process" objection is named and
      directly answered.
- [ ] All three value props are present and clearly articulated.
- [ ] Both individual-developer and team/adopter readers are addressed.
- [ ] No factual usage detail lost: Requirements, Install, Set up a project, Update,
      Commands, Agents, How project parameterization works, Contributing link all
      intact and accurate.
- [ ] TP-0011 outcomes not regressed: `tce — Toby Context Engineering` heading, the
      "Built by Toby" blurb placement, the four grouped command tables, the bottom
      `../../CONTRIBUTING.md` link all present.

## Testing strategy

The README is not schema-validated, so testing is (1) running the three
`claude plugin validate` commands to confirm nothing structural broke in the plugin
directory, and (2) a manual read-through against the success-criteria checklist,
including a grep for the preserved heading text, the "Built by Toby" string, and the
`../../CONTRIBUTING.md` link to confirm no regression.
