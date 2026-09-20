<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by the tsf:plan
agent before it writes or revises `thoughts/factory/GH-<n>/plan.md`. Never
copied into consuming projects.

Changes to this file are command-contract changes: the increment fields below
are **parsed** by `plugins/tsf/scripts/plan.sh`, which validates a plan when the
plan and implement steps return and extracts the criteria the gates judge
against. Renaming a field, or changing the increment or addendum heading shape,
means changing that script and every tsf agent that reads plans in the same
commit.

Contents:
1. Format rules
2. The plan skeleton
3. Folding plan-gate feedback
-->

# Format rules

- The plan is a set of **independently verifiable increments**, not an ordered
  walkthrough. Each increment carries its own verification, so the implementing
  agent can check it the moment it is built.
- Ordering is the implementer's choice unless a real dependency forces it. Then
  the dependency is stated on the increment (`**Depends on**`), never as a
  global sequence.
- Every increment states **what changes**, **where** (anchored in research
  evidence), and **how it is verified automatically** — commands the project
  already has, or tests the increment adds. Verification that can only be done
  by a person is flagged `**Manual**` explicitly; it surfaces in the review
  dossier later.
- **Two rules are checked mechanically**, and a plan that breaks either is
  rejected and re-written before anyone sees it: every increment carries a
  `**Verification:**` or a `**Manual:**` field, and **increment numbers are
  unique**. The fields are what the plan-compliance gate judges the change
  against, so an increment with neither would be built and never checked.
- Decisions are made here, from the spec and research. A decision that changes
  *what* is built and is not settled by the spec is a question for the human,
  not an assumption.

# The plan skeleton

Write `thoughts/factory/GH-<n>/plan.md` with this structure. Fill in every
bracketed placeholder.

````markdown
# Plan: GH-[n]

## Understanding

[What will be built and why, in a few sentences — the spec as the plan reads it.]

## Decisions

- **[Decision]** — [why]. Rejected: [the alternative, one line].

## Increments

### Increment 1: [name]

- **What changes:** [the behaviour or structure this increment adds or alters]
- **Where:** [files and mechanisms, anchored in research evidence, e.g.
  `path/to/file.ext:12`]
- **Verification:** [automated command(s) and the tests they run; what passing
  proves]
- **Manual:** [only if some verification cannot be automated — what a person
  must check; omit the line otherwise]
- **Depends on:** [Increment k, and why — omit the line when independent]

### Increment 2: [name]

[...]

## Open questions

[Numbered questions the human must answer before implementation, each
self-contained — the same text asked in the plan summary. "None." when there
are none.]

## Feedback

[Dated record of plan-gate replies folded into this plan. "None yet." initially.]

- YYYY-MM-DD: [what the reply asked for] → [what changed in the plan]

## Addenda

[Deviations recorded during implementation, each restating the affected
increment's verification. Empty until implementation.]

### YYYY-MM-DD — Increment [n]: [the increment's name, repeated]

- **Why:** [what reality forced — one or two sentences]
- **Verification:** [the increment's verification as it now stands, restated in
  full]
- **Manual:** [restated in full when the increment has one; omit the line
  otherwise]
````

An addendum **restates, it does not amend**: the newest addendum for an
increment replaces that increment's fields entirely, so the criteria the gate
judges are always one self-contained statement and never a diff to apply. Its
heading repeats the increment's number and name so the two can be paired
mechanically; naming an increment the plan does not have is an error.

# Folding plan-gate feedback

When a responder's reply to the plan summary is not an approval:

1. Record it under `## Feedback` with today's date: what was asked, and what
   the plan does about it.
2. Revise the affected sections — `## Decisions`, the increments, their
   verification — so the plan reads as one coherent document again.
3. Clear questions the reply answered from `## Open questions`; keep the rest.
4. Never silently drop an increment or a verification: a removal is a
   decision, recorded under `## Decisions` with its reason.
