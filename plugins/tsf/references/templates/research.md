<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by the
tsf:research agent before it writes or revises
`thoughts/factory/GH-<n>/research.md`. Never copied into consuming projects.

Changes to this file are command-contract changes: tsf:plan reads the sections
below, so renaming one requires updating plugins/tsf/agents/{research,plan}.md
in the same commit.

Contents:
1. Register
2. The research skeleton
3. Re-validation after answers
-->

# Register

Research is a **documentarian's** job: describe what exists — the patterns, the
files and mechanisms the change touches, the constraints — with file:line
evidence. It does not design the change and does not recommend. Where a choice
is genuinely open, list the options neutrally under `## Options`; deciding
between them is the plan's job, or the human's when it changes what is built.

Questions that decide *what* is built are decisions about the change: they go
into the spec's `## Open questions` (and are asked on the issue), never answered
here by assumption.

# The research skeleton

Write `thoughts/factory/GH-<n>/research.md` with this structure. Fill in every
bracketed placeholder.

````markdown
# Research: GH-[n]

## Summary

[Three to six sentences: what the change touches and the facts the plan most
needs.]

## Findings

### [Area or mechanism]

[What exists and how it works, with evidence: `path/to/file.ext:12-40`. One
subsection per area the change touches.]

## Constraints

- [A fact the plan must respect — a convention, an invariant, a dependency,
  a test harness behaviour — with evidence]

## Impact

- [Every existing usage, caller or consumer the change can affect, with
  evidence — or "none found" with where you looked]

## Options

[Only where a technical choice is genuinely open: each option, neutrally, with
its evidence. "None — the approach follows from the findings." otherwise.]

## Open questions

[Numbered questions that materially affect planning, each self-contained — the
same text asked on the issue and recorded in the spec. "None." when there are
none.]

## Revisions

[Dated record of what answers changed in this document. "None." initially.]

- YYYY-MM-DD: [which findings or options the answers changed, and how]
````

# Re-validation after answers

When the ticket resumes after a responder answered research's questions, the
answers are first folded into the spec (they are decisions). Then re-read this
document against the updated spec: amend every finding, constraint, impact or
option the answers change — researching further where an answer opened new
ground — clear the answered questions here, and record what changed under
`## Revisions`.
