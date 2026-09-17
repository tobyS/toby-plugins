<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by /tsf:spec
before it drafts a spec, and by the tsf:triage and tsf:research agents before
they write or fold answers into `thoughts/factory/GH-<n>/spec.md`. Never copied
into consuming projects.

Changes to this file are command-contract changes: the section names below are
what the agents pair questions and answers by (`## Open questions`,
`## Decisions`), so renaming one requires updating plugins/tsf/commands/spec.md
and plugins/tsf/agents/{triage,research}.md in the same commit.

Contents:
1. The sufficiency minimum
2. The spec skeleton
3. Folding answers
-->

# The sufficiency minimum

A spec is sufficient for the factory when it gives, at minimum:

- **Scope you can draw a line around** — what should change or be built, and
  what is explicitly not part of it where that is not obvious.
- **An outcome someone could observe** — how a person would tell, from the
  outside, that the work is done. Informal is fine; vague is not.
- **At least one anchor into the system** — a concrete pointer research can
  start from: a feature, screen, command, endpoint, error message, file or
  module.

Not required: business justification, formal acceptance criteria, technical
design, or any particular prose style. A spec missing any of the three is
insufficient, and the questions that would close the gap are asked — all at
once, numbered — before any research starts.

# The spec skeleton

Write `thoughts/factory/GH-<n>/spec.md` with this structure. Fill in every
bracketed placeholder; drop a bracketed hint once it is answered.

````markdown
# GH-[n]: [title]

## Problem

[What is wrong or missing today, and for whom. A few sentences.]

## Desired outcome

[What is observably true once this is done — phrased so a person could check it.]

## Scope

- **In:** [what changes]
- **Out:** [what explicitly does not, where not obvious — or "nothing notable"]

## Anchors

- [Concrete pointer into the system: a feature, screen, command, endpoint,
  error message, file or module — at least one]

## Open questions

[Numbered questions whose answers the factory needs, each self-contained. Written
by the step that parks the ticket, exactly as asked on the issue. "None." when
there are none.]

1. [Question in full]

## Decisions

[Dated record of answers folded into this spec. "None yet." initially.]

- YYYY-MM-DD: Q[k] "[question, shortened]" → [the answer as decided]
````

# Folding answers

When a responder's reply answers open questions:

1. Pair each answer with its numbered question in `## Open questions`. A reply
   may answer by number ("2. yes") or in prose; match by content when numbers
   are absent.
2. Fold each answer into the body where it belongs (Problem, Desired outcome,
   Scope, Anchors) so the spec reads as one coherent statement, not a Q&A log.
3. Record it under `## Decisions` with today's date.
4. Remove answered questions from `## Open questions`; keep unanswered ones in
   full (they are asked again). Write "None." when the list is empty.
5. Never invent an answer the reply does not give.
