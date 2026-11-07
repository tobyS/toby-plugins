<!--
Runtime reference for the commands that run work-loop.md and for
/tce:intent. Read at the point of use — always in full, even if already read
earlier in the session — by the `planner` agent before it returns questions
(sections 1-3 and 7 are its contract), by the `presenter` agent before it
composes any presentation (sections 1 and 3-8 are its contract), and by the
running command (work-loop.md Step 6) before it asks the planner's questions.
Never copied into consuming projects.

Changes to this file are command-contract changes under the CLAUDE.md rule
"tce: the step commands are orchestrators" (the brief/question-layout span): a change
to the question layout, the presentation's blocks or skeletons, the budget
rule or the delta markers updates this file, plugins/tce/agents/planner.md,
plugins/tce/agents/presenter.md and work-loop.md in the same commit. Section 8
mirrors the **Full** bullet of plugins/tce/templates/tce/profile.md's
`## Presentation` section; change one and you change the other.

Contents:
1. Terminal constraints (why the layout looks like this)
2. Questions
3. What a decision is
4. The presentation
5. Budget and overflow
6. The push-back delta
7. Phrasing for the reader
8. Full's values (no `## Presentation` section)
-->

# Terminal constraints

The questions and the presentations are read in the Claude Code terminal,
not as files. Claude Code collapses a markdown table whose cells carry prose into
stacked key/value cards, which destroys skimmability. So:

- **No tables with prose cells.** Headings, short bullets and lines with
  counted values only.
- **One takeaway line first**, with counts.
- **Counted facts, never confidence numbers.** "tests in 3/4 phases" is real;
  "90% confident" is decoration.
- **The full artifact is linked by path, never shown.**

# Questions

The planner returns its questions as a numbered list, one decision per item,
recommended option first. Each item is **self-contained**: the human decides
from the item alone, without having read the intent, the research or the plan.
Never write "see research.md".

```
Understood: [2 lines — what the ticket means in this codebase]
Approach:   [2 lines] — rejected: [alternative, one line why]

1. Question: [the decision, as a question ending in "?"]
   Header: [max 12 characters]
   Options:
   - [label, 1-5 words] (Recommended) — [one line: why this is recommended]
   - [label] — [one line: what it means]
   If not recommended: [what changes in the plan with the other option]
2. ...
```

- At most 4 options per question; 2-3 is normal.
- The recommendation is the planner's, with its reasoning in the option's
  description. Never present a question without one (the practices item
  below is the one exception).
- `Header:` is the short label the human's answer is filed under in
  `answers:`; it is not shown as a dialog header.
- The orchestrator asks the items in prose, as `work-loop.md`'s "Asking in
  prose" says — the `Understood:` / `Approach:` lines word for word first,
  never without them, then every item with its options as returned.

**The practices item.** When the research lists practice candidates, the
planner closes the list with one more item of a different shape — the
candidates numbered in place of `Options:`, each with its count as the
research states it, and no recommendation (the human picks any subset):

```
3. Question: Seen repeatedly — record these as standing rules? Reply with the numbers you accept.
   Header: Practices
   1. [proposed rule, one line] — [k] tickets: [IDs]
   2. ...
```

The orchestrator writes the accepted ones into the project's CLAUDE.md and
the declined ones into the profile (`work-loop.md` Step 6).

A plan with no open questions returns `Understood:` and `Approach:` and the
line `0 questions`.

# What a decision is

A **decision** is a point where a reasonable colleague might have chosen
differently. Following an existing pattern of the codebase, CLAUDE.md or the
profile is not one, and neither is the only option the code leaves open.

- The planner records as `*(decided for you)*` only decisions in this sense,
  and asks the ones the human should make (section 2).
- The presenter shows **every** line the artifact marks as made on the
  human's behalf — the plan's and the dossier's `*(decided for you)*` lines,
  the intent's `## Decisions` — and adds none of its own. The plan challenger
  checks the plan brief and delta against the plan (its `mode: brief`).

# The presentation

What the human reads instead of the artifact. It is composed by the
`presenter` from the touchpoint's items in the profile's `## Presentation`
section (`Plan shows` for `brief` and `delta`, `Intent shows`, `Dossier
shows`), in that list's order, after two fixed lines:

1. **The takeaway line**, with counts — never cut.
2. **The path** — `Plan:`, `Intent:` or `Dossier:` followed by the artifact's
   path — never cut, and the `path` item is satisfied by it.

Then one block per item:

- **understanding and approach** — `Understood:` and `Approach:`, two lines
  each, from the plan's Overview and Implementation Approach; the approach
  ends with `— rejected: <alternative, one line why>`.
- **decisions made for you** — `## Decided for you (push back on any)`, one
  bullet per `*(decided for you)*` line: `- <choice> — over <alternative>:
  <why>`.
- **decisions** (intent) — `## Decisions`, one bullet per decision, same
  shape.
- **phases** — `## Phases`, the line `Phases: <n> · tests in <x>/<n> · files
  touched <f> · manual checks <c>`, then `<k>. <scope> — <files> — <tests>`
  per phase.
- **risk** — `Risk: <the riskiest assumption, one line, or none>`.
- **Scope In and Out** (intent) — `## In` and `## Out`, one bullet each.
- **Out list** (intent) — `## Out`, one bullet each.
- **outcome** (intent) — `Outcome: <one or two lines>`.
- **acceptance criteria** (intent) — `## Acceptance criteria`, one bullet
  each.
- **counted facts** (dossier) — the dossier's counted-facts line, verbatim.
- **what was built** (dossier) — `## Built`, one bullet per change.
- **items for you to check** (dossier) — `## For you to check`, one bullet
  per pending item, with what to run or look at; `None.` when there are none.
- **concerns** (dossier) — `## Concerns`, one bullet each, or `None.`
- **exceptions** — `## Exceptions`: what deviates from the project's CLAUDE.md,
  the profile's `## Conventions` or recorded practice, or what the reader
  would not expect from the ticket or intent. Routine work never goes here.
  None → the single line `Exceptions: none.`
- **sample** — `## Likely push-backs`: the three statements a careful
  reviewer would most likely push back on — an inconsistency, a claim without
  evidence, a choice against the reader's likely expectation — numbered, one
  sentence each. Omitted when the `Sample:` sub-field says off.

Every line is **self-contained**: it names its subject and makes sense
alone. Never "see phase 2", a line number, "as above" or a pronoun whose
antecedent is in another line. The `Formatting:` sub-field governs the
markup.

Takeaway lines per kind:

```
brief:    APPROVE?  [m] decided for you · [e] exceptions · [k] risks
delta:    CHANGED:  [m] decided for you · [e] exceptions · [k] risks
intent:   INTENT:   [i] in · [o] out · [c] criteria · [d] decisions · [e] exceptions
dossier:  DONE:     [c] for you to check · [e] exceptions · [n] concerns
```

The Full skeleton for `kind: brief` — every `Plan shows` item:

```
APPROVE?  [m] decided for you · [e] exceptions · [k] risks
Plan: [path]

Understood: [2 lines]
Approach:   [2 lines] — rejected: [alternative, one line why]

## Decided for you (push back on any)
- [choice] — over [alternative]: [why]

## Phases
Phases: [n] · tests in [x]/[n] · files touched [f] · manual checks [c]
1. [scope] — [files] — [tests]

Risk: [one line]

## Exceptions
- [what deviates, and from what]

## Likely push-backs
1. [one sentence]
2. [one sentence]
3. [one sentence]
```

The Full skeletons for `kind: intent` and `kind: dossier` follow the same
pattern with their items: takeaway, path, then the blocks in the order
section 8 lists them. A Compact or Custom presentation is the same skeleton
with only the blocks its `shows` line names.

# Budget and overflow

The `Line budget:` sub-field bounds every **non-empty** printed line — the
takeaway, the path, headings and the overflow line included.

- Never cut: the takeaway, the path, every decision made on the human's
  behalf, the exceptions and the sample.
- When the rest does not fit, drop whole lines from the end of the longest
  remaining block first, and repeat. A block reduced to its heading is
  dropped entirely.
- What was dropped is offered once, as the last line:
  `More on request: <topic> (<n> lines), <topic> (<n> lines)` — each topic
  named by its subject (`phases 4-7`, `acceptance criteria`, `what was built
  in the export module`), never a bare count.
- When the never-cut lines alone exceed the budget, print them anyway and
  say so in the return's `summary:` — a hidden decision costs more than a
  long brief.

# The push-back delta

After a push-back, the presenter shows only what changed, from the
planner's change lines (`changes:` — one per change, `+` added, `~` changed,
`-` removed, each naming its subject: a decision, a phase, the risk, a
criterion) and the plan:

```
CHANGED:  [m] decided for you · [e] exceptions · [k] risks
Plan: [path]

## Decided for you (push back on any)
+ [new choice] — over [alternative]: [why]
~ [changed choice] — over [alternative]: [why]

## Phases
~ 2. [scope] — [files] — [tests]
```

- `CHANGED:` carries the new counts.
- Only the blocks that changed appear; every line in them is marked `+`
  (new) or `~` (changed). A removed line is shown as `- [line] (removed)`.
- `## Exceptions` and `## Likely push-backs` appear only when the change
  altered them; the budget rule applies unchanged.

# Phrasing for the reader

Every question, presentation and delta is phrased for the `## Reader` section
of the project's `profile.md`. Terms within the reader's fluency are used
without explanation; the first time a tool, library, pattern or abbreviation
outside it appears, name it and explain it in half a sentence. This governs
vocabulary and depth, not length — the line budget and the bounds in
`agent-returns.md` still apply. Without a `## Reader` section (or with **Not
described**), write for a developer fluent in the project's stack.

# Full's values

Used when the profile has no `## Presentation` section, and for any
sub-field a Custom section leaves out. They mirror the template's **Full**
bullet:

- **Questions:** prose; two lines of context per question; recommended answer marked.
- **Line budget:** 60
- **Intent shows:** path, Scope In and Out, outcome, acceptance criteria, decisions, exceptions, sample
- **Plan shows:** path, understanding and approach, decisions made for you, phases, risk, exceptions, sample
- **Dossier shows:** path, counted facts, what was built, decisions made for you, items for you to check, concerns, exceptions
- **Sample:** the three statements a careful reviewer would most likely push back on
- **Formatting:** headings and short bullets
