<!--
Runtime reference for the commands that run work-loop.md. Read at the point
of use — always in full, even if already read earlier in the session — by the
`planner` agent before it returns questions, a brief or a delta, and by the
running command (work-loop.md Step 6) before it asks the planner's questions or
renders a brief. Never copied into consuming projects.

Changes to this file are command-contract changes under the CLAUDE.md rule
"tce: the step commands are orchestrators" (the brief/question-layout span): a change
to the question layout, the brief's sections or the delta markers updates this
file, plugins/tce/agents/planner.md and work-loop.md in the same commit.

Contents:
1. Terminal constraints (why the layout looks like this)
2. Questions
3. The brief
4. The push-back delta
5. Phrasing for the reader
-->

# Terminal constraints

The brief and the questions are read in the Claude Code terminal, not as
files. Claude Code collapses a markdown table whose cells carry prose into
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

- At most 4 options per question (AskUserQuestion's limit); 2-3 is normal.
- The recommendation is the planner's, with its reasoning in the option's
  description. Never present a question without one.
- The orchestrator copies each item into one AskUserQuestion question — up to
  four per call — with the `Understood:` / `Approach:` lines word for word at
  the top of the first question's text, and never without them; a
  header over 12 characters is shortened for the dialog, and `answers:`
  carries the shortened one, under the AskUserQuestion dialog guidelines.

A plan with no open questions returns `Understood:` and `Approach:` and the
line `0 questions`.

# The brief

The planner's return after writing the plan. The orchestrator prints it as-is
and then asks for approval.

```
APPROVE?  [n] decisions need you · [m] made on your behalf · [k] risks

Understood: [2 lines]
Approach:   [2 lines] — rejected: [alternative, one line why]

## Decisions for you
1. [question] — (a) [recommended, why] (b) [alternative] — if (b): [what changes]

## Decided for you (push back on any)
- [choice] — over [alternative]: [why]

## Phases
Phases: [n] · tests in [x]/[n] · files touched [f] · manual checks [c]
1. [scope] — [files] — [tests]

Risk: [one line]
Full plan: [path]
```

- **`Decisions for you`** is usually empty after the questions-first round —
  write `None.` then. Anything that appears there is asked through
  AskUserQuestion before approval, so keep each item self-contained.
- **`Decided for you`** lists every `*(decided for you)*` line of the plan's
  `## Decisions`, nothing more and nothing less — the plan challenger checks
  the two against each other.
- **`Phases`** counts are counted from the plan: phases, phases whose
  Automated criteria include a test, distinct files named under "Changes
  Required", Manual Verification items.
- **`Risk`** is the riskiest assumption, or `none`.
- `n`, `m` and `k` in the takeaway line are the counts of the three lists.

# The push-back delta

After a push-back or challenger findings, the planner returns only what
changed:

```
CHANGED:  [n] decisions need you · [m] made on your behalf · [k] risks

## Decided for you (push back on any)
+ [new choice] — over [alternative]: [why]
~ [changed choice] — over [alternative]: [why]

## Phases
~ 2. [scope] — [files] — [tests]
```

- `CHANGED:` repeats the takeaway line with the new counts.
- Only the sections that changed appear; every line in them is marked `+`
  (new) or `~` (changed). A removed line is shown as `- [line] (removed)`.
- `Full plan: [path]` closes the delta, as it closes the brief.

# Phrasing for the reader

Every question, brief and delta is phrased for the `## Reader` section of the
project's `profile.md`. Terms within the reader's fluency are used without
explanation; the first time a tool, library, pattern or abbreviation outside
it appears, name it and explain it in half a sentence. This governs
vocabulary and depth, not length — the bounds in `agent-returns.md` still
apply. Without a `## Reader` section (or with **Not described**), write for a
developer fluent in the project's stack.
