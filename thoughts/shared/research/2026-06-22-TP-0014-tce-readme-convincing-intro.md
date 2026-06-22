---
date: 2026-06-22
ticket: TP-0014
topic: "Rewrite the tce README intro to be hands-on first and convincingly motivated"
status: complete
last_updated: 2026-06-22
branch: main
commit: 1510f36f9ddfc75f186cefba1152ce09e85962e1
repo: git@github.com:tobyS/toby-plugins.git
---

# Research: TP-0014 — convincing, hands-on-first tce README intro

## Research question

How should the introduction of `plugins/tce/README.md` be rewritten so that a
skeptical-but-capable Claude Code user ("the AI already handles medium tasks fine
without a process") quickly sees where tce helps and what using it looks like —
leading with a hands-on worked example, naming the objection head-on, and making
three value props explicit (reliability via explicitation, team-wide quality
equalization, self-learning via repo-stored context) — without regressing the
structure TP-0011 already shipped?

## Summary

The change is well-scoped and low-risk: a single Markdown file, focused on its
opening sections, documentation-only. Research converges hard on a single answer:

1. **The diagnosis is already on record.** TP-0011's research explicitly found the
   tce README "leads with mechanics over value" — exactly TP-0014's complaint. TP-0011
   fixed overall structure (heading, command grouping, CONTRIBUTING extraction, the
   "Built by Toby" blurb) but did **not** rewrite the intro to *show* value first; it
   kept the conceptual `## Why context engineering?` section as the second thing the
   reader meets.

2. **External best practice says lead with a concrete, narrated worked example**
   ("show, don't tell"; Diátaxis tutorial posture; makeareadme "use examples
   liberally, show expected output"), keep the opening to ~one screen, and let the
   *artifacts* carry the team argument rather than adjectives.

3. **The author's own blog already supplies the skeptic-disarming framing** — the
   value is not "can the AI do one task" (it concedes that) but spending the *context
   budget* so success is **repeatable not lucky**, leaving a **trail teammates and the
   next session inherit**, and keeping the engineer as **decision-maker** (the
   "centaur"). These map one-to-one onto TP-0014's three value props.

4. **Hard constraints to preserve (from TP-0011, verified present in the current
   file):** the `# tce — Toby Context Engineering` heading, the "Built by Toby"
   blockquote sitting between tagline and install, the four grouped command tables,
   the Contents/TOC, every factual usage section, and the bottom `../../CONTRIBUTING.md`
   link. The worked example must add value-first material **above/around** these, not
   displace them.

No tce config drift found (profile.md and tickets.md both match the repo).

## Current state of the tce README

`plugins/tce/README.md` (current `main`, commit 1510f36). Section flow with line
anchors:

- **Heading + intro block (lines 1–24):** H1 `# tce — Toby Context Engineering`
  (line 1); a 4-line tagline paragraph framing tce as "a context-engineering
  development workflow … ticket → research → plan → implement" (lines 3–7); an "In a
  hurry?" paragraph on `/tce:work` and `/tce:quickfix` (lines 9–11); a
  ticket-agnostic paragraph (lines 13–19); the **"Built by Toby" blockquote** (lines
  21–24).
- **Contents / TOC (lines 26–37).**
- **`## Why context engineering?` (lines 38–57)** — the conceptual section: a 4-step
  numbered narrative (Tickets / Research / Plans / Implementation, lines 43–47), a
  persistence paragraph ("artifacts that persist across sessions … stays in Git",
  lines 49–51), and a paragraph noting it supersedes the claude-template + blog link
  (lines 53–57). **This is the first substantive thing the reader meets, and it is
  concept, not demonstration — the core problem TP-0014 targets.**
- **`## Requirements` (59–72), `## Install` (74–80), `## Set up a project` (82–130),
  `## Update` (132–138), `## Commands` (140–182), `## Agents` (184–195),
  `## How project parameterization works` (197–213), `## Contributing` (215–219).**
  The Contributing section links `../../CONTRIBUTING.md` at the very bottom.

What's missing per the ticket: there is **no worked example** anywhere in the intro;
the objection is **never named**; and the three value props are at best implicit
(the persistence paragraph hints at self-learning but doesn't argue it; reliability
and team-equalization are absent).

## Key findings

### Finding 1 — TP-0011 already diagnosed this exact problem and left the fix open

TP-0011's research (`thoughts/shared/research/2026-06-17-TP-0011-readme-rework-user-first.md`)
concluded the plugin READMEs "lead with mechanics over value" and classified
`## Why context engineering?` as **legitimate usage content that stays** in the
README. So TP-0014 should **reframe and precede** that section, not delete it: the
4-step narrative is load-bearing (TP-0011 even considered it the home for the
workflow step-ordering that was dropped from the command tables). The intro rewrite
adds a *demonstration* in front of the *explanation*.

### Finding 2 — best practice: narrated worked example, artifacts as proof, one screen

From the web research (makeareadme.com, Diátaxis, Tilburg Science Hub, Archbee):

- Lead with **what it does + why care**, then a **runnable example immediately** —
  "avoid describing languages/technologies/tools until after you've given a strong
  reason to engage" (Tilburg). makeareadme: **"use examples liberally, and show the
  expected output if you can."**
- Diátaxis tutorial posture: the reader is "on rails," no decisions required — the
  right stance for an intro that must prove value before buy-in.
- Keep the opening scannable (~one screen): one-liner → short why → worked example;
  "too long is better than too short" applies to the *demonstration*, trim prose not
  the example.
- **Let artifacts make the team argument**, not adjectives: "every step writes a
  Markdown file into the repo; your teammate (and the next Claude session) reads the
  same ticket/research/plan you did" — concrete mechanism, not benefit-claim. This is
  how to state team value without sounding like marketing.

### Finding 3 — the author's blog supplies the exact skeptic-disarming pivot

From `https://schlitt.info/blog/0793_context_engineering_claude_code.html`:

- **Concede capability, relocate the problem to context budget.** The model is
  capable; the issue is it burns its context window on research + clarification,
  leaving little for generation. tce *sequences* context-building so each step spends
  the budget well → success becomes **repeatable, not lucky**. (Maps to value-prop 1,
  reliability via explicitation.)
- **Persisted artifacts are the point** — each step deposits a Markdown file that both
  shrinks immediate context and builds an institutional record the next ticket/session
  and teammates inherit. (Maps to value-props 2 and 3, equalization + self-learning.)
- **Human stays the decision-maker** — the "centaur": engineer rides atop the LLM,
  controlling intent/scope, delegating execution; "being deliberate about where human
  judgment ends and machine execution begins."
- Phrases worth echoing **once, after the example has done the convincing**:
  "centaur"; "auto-complete on steroids" (once thinking is pre-formed, codegen is
  translation not ideation — reframes "the AI handles it fine" as "yes, and this makes
  it reliable instead of lucky"); "AI slop" (names the failure mode the skeptic knows
  from their own review queue).

### Finding 4 — a real, self-referential worked example already exists (dogfood option)

This repo dogfoods tce, so an authentic chain is on disk and could seed the example
(or inspire a representative illustrative one). TP-0011 itself produced the full set:

- ticket → `thoughts/shared/tickets/TP-0011-readme-rework-user-first.md`
- research → `thoughts/shared/research/2026-06-17-TP-0011-readme-rework-user-first.md`
- plan → `thoughts/shared/plans/2026-06-17-TP-0011-readme-rework-user-first.md`
- status → `thoughts/shared/plans/2026-06-17-TP-0011-readme-rework-user-first.status.md`

The artifact-naming and directory convention (`thoughts/shared/{tickets,research,plans}/`,
date + `TP-NNNN` + slug) is consistent across all 12 tickets in the repo, so the
worked example can show real, accurate paths. Whether to use a literal TP-NNNN from
this repo or a neutral illustrative task (e.g. "add document tagging") is a
planning-time copy decision — research has no strong preference; a neutral example
avoids dating the README, a real one is verifiably honest.

### Finding 5 — constraints to preserve (TP-0011 outcomes, verified in current file)

- Heading exactly `# tce — Toby Context Engineering` (line 1).
- "Built by Toby" blockquote between tagline and install (lines 21–24) — a hands-on
  intro must place the concrete capability/value **before** this callout so the promo
  doesn't bury the quick start (TP-0011 Open Question 3 flagged exactly this).
- Four grouped command tables (Core / Shortcuts / Helpers / Maintenance, lines 140–182).
- Contents/TOC (lines 26–37) — if new top sections are added, the TOC must gain
  matching entries.
- All factual usage sections intact; `## Contributing` → `../../CONTRIBUTING.md` stays
  last (lines 215–219).

## Code references

- `plugins/tce/README.md:1` — H1 heading (preserve)
- `plugins/tce/README.md:3-7` — current tagline paragraph
- `plugins/tce/README.md:21-24` — "Built by Toby" blockquote (placement constraint)
- `plugins/tce/README.md:26-37` — Contents/TOC (update if sections added)
- `plugins/tce/README.md:38-57` — `## Why context engineering?` (reframe + precede, don't delete)
- `plugins/tce/README.md:43-47` — the 4-step narrative (load-bearing per TP-0011)
- `plugins/tce/README.md:140-182` — grouped command tables (preserve)
- `plugins/tce/README.md:215-219` — Contributing link (preserve, stays last)
- `thoughts/shared/research/2026-06-17-TP-0011-readme-rework-user-first.md` — prior README best-practice research
- `thoughts/shared/tickets/TP-0011-readme-rework-user-first.md` — prior decisions to respect

## Answers to the ticket's "Questions for Research/Planning"

1. **Which sections to replace/absorb vs. precede?** Insert the worked example (and a
   short value framing) **before** `## Why context engineering?`; **keep** that
   section but reframe it as the "why this works" explanation that follows the
   demonstration. Do not delete the 4-step narrative or the persistence paragraph.
2. **What task for the worked example?** A short, single, representative task narrated
   through ticket → research → plan → implement, showing the four artifact paths under
   `thoughts/shared/`. Either a neutral illustrative task or a real repo TP-NNNN
   (dogfood) — a planning-time copy call; research leans neutral-but-accurate-paths to
   avoid dating the README.
3. **How long before it hurts scannability?** Target ~one screen for the new
   value+example block: a one-liner, 1–2 sentence "why", a compact narrated example
   (command → artifact it deposits, ideally a small fenced tree or list), then a
   2–4 line objection/value paragraph. Trim prose, not the demonstration.
4. **Phrasing the objection without sounding defensive?** Concede capability first
   ("Claude already handles a well-specified medium task fine"), then pivot to
   *repeatability across tasks and people* and *a reusable trail* — echo the blog's
   "repeatable, not lucky" and the "centaur"/"auto-complete on steroids" handles
   **once**, after the example. Place the objection paragraph right after the worked
   example, before or as the lead-in to the reframed `## Why context engineering?`.

## Open questions / decisions for planning

- **Worked-example subject:** neutral illustrative task vs. a real repo TP-NNNN.
  (Low-stakes copy decision; either satisfies the acceptance criteria.)
- **Exact placement of the objection paragraph:** end of the worked-example block, or
  woven into the reframed `## Why context engineering?` intro. (Both meet AC.)
- **Section headings:** whether the worked example gets its own `##` heading (e.g.
  `## See it work` / `## What using tce looks like`) — affects the TOC. Recommended:
  yes, a dedicated heading, with a matching TOC entry, for scannability.

These are copy/placement choices, not blockers — none require user judgment beyond
normal editorial taste, so planning can proceed and decide them.

## tce config drift

None. `profile.md` (tech stack = plugin-marketplace monorepo; test = `claude plugin
validate`; no typecheck/lint) and `tickets.md` (tmt backend, `TP-NNNN`) both match the
current repo. No `/tce:refresh` recommended.

## Sources

- README best practice: https://www.makeareadme.com/ ; https://www.diataxis.fr/tutorials-how-to/ ;
  https://www.tilburgsciencehub.com/topics/collaborate-share/share-your-work/content-creation/readme-best-practices/ ;
  https://www.archbee.com/blog/readme-document-characteristics ;
  https://www.markepear.dev/blog/value-proposition-developer-tools
- Author's motivation: https://schlitt.info/blog/0793_context_engineering_claude_code.html
- Prior work: TP-0011 research/plan/ticket (paths above)
