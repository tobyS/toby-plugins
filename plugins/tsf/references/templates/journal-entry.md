<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by /tsf:cycle's
write phase before it appends to `thoughts/factory/GH-<n>/journal.md`, and by
the worker agents before they compose the `tsf-journal` block of their result.
Never copied into consuming projects.

Changes to this file are command-contract changes: the last entry's `Next step`
line is the ticket's derived state (DESIGN.md §3.3), so the CLAUDE.md rule
"tsf: the journal's Next step is the derived state" applies — change the entry
shape or the vocabulary and update plugins/tsf/references/cycle-dispatch.md,
plugins/tsf/references/templates/result-block.md and the three agents in the
same commit.

Contents:
1. The journal file and the entry shape
2. The Next step vocabulary
3. Entries the dispatcher writes on its own
-->

# The journal file and the entry shape

`thoughts/factory/GH-<n>/journal.md` is append-only. It starts with one H1 line,
`# Journal: GH-<n>`, and gets one entry per cycle that touches the ticket. Never
edit or reorder an earlier entry.

The dispatcher writes the heading; the body is the agent's `tsf-journal` block,
verbatim:

````markdown
## Cycle [YYYY-MM-DDTHH:MMZ] — step: [triage | research | plan | implement | verify-fix | manual-verify | gates | dossier | review]
- Outcome: [one line — what the step produced or decided]
- Questions asked: [none (gate skipped: nothing to ask) | k (parked)]
- Commits: [short sha, space-separated | none]
- Label: [the tsf:* state label this cycle sets]
- Episode: [n]   (only on an entry that moves the ticket into tsf:verify)
- Next step: [triage | research | plan | implement | verify | gates | dossier | review | landing]
````

The timestamp is the `now:` value of the cycle's preflight. `step:` names the
agent that ran. At the plan gate, `Questions asked:` counts the summary's
numbered questions (the plan gate is never skipped, so it is never "gate
skipped").

# The Next step vocabulary

`Next step` names the step the dispatcher runs next for this ticket. The
vocabulary is closed — the dispatcher rejects anything else — and grows only
with a slice:

- `triage` — the spec is still insufficient; triage runs again.
- `research` — research runs next.
- `plan` — the plan step runs next.
- `implement` — the plan is approved; implementation runs next.
- `verify` — the pull request is open; verification runs next (local suite,
  attempted manual items, CI read at pickup).
- `gates` — verification is green; the three post-implement gates run next.
- `dossier` — the gates are green; the dossier is written next.
- `review` — the dossier is posted; the human's review decides what follows.
- `landing` — the review approved the change; landing runs next (a later slice).

## The episode line

A **verification episode** starts each time the ticket enters `tsf:verify` —
from implement, or from rework — and bounds the verify-fix attempts and the gate
fix rounds that follow (`verify_fix_bound`, `gate_fix_bound`). Report filenames
alone cannot tell "episode 1, attempt 3" from "episode 2, attempt 1", so the
entry that performs the transition carries `- Episode: [n]`, and the dispatcher
reads the **last** such line to know the current episode. The first episode of a
ticket is 1; a fix-mode return to `tsf:verify` stays inside the current episode
and writes no new episode line.

**A parked ticket names the parking step itself**: when triage parks with
questions, `Next step: triage`; when research parks, `Next step: research`; when
the plan gate waits for approval, `Next step: plan`. The step that parked is the
step that resumes with the reply.

# Entries the dispatcher writes on its own

When no agent result exists, the dispatcher writes the whole entry. `step:` and
`Next step` then repeat the ticket's derived state unchanged, so a later resume
starts exactly where the ticket stood.

State mismatch (a human-side label disagrees with the artifacts):

````markdown
## Cycle [now] — step: [derived step]
- Outcome: state mismatch: label [label] but [what the artifacts show]; parked for a human
- Questions asked: none
- Commits: none
- Label: tsf:needs-human
- Next step: [derived step]
````

The gate cycle (the three gates return report content, not result blocks, so the
dispatcher writes the whole entry):

````markdown
## Cycle [now] — step: gates
- Outcome: plan-compliance [pass|fail] · spec-coverage [pass|fail] · security [pass|fail, k blocking]; [all green, dossier next | routing to fix round k of the bound]
- Questions asked: none
- Commits: [the report commit]
- Label: [tsf:dossier | tsf:verify]
- Next step: [dossier | verify]
````

The review read (row 10 dispatches no agent at all):

````markdown
## Cycle [now] — step: review
- Outcome: [approving review at the logic head, landing next | approval is behind the logic head and stale, still parked | changes requested, rework next]
- Questions asked: none
- Commits: none
- Label: [tsf:landing | tsf:rework | tsf:needs-review]
- Next step: [landing | implement | review]
````

Failed GitHub write, or an agent return without a valid result block twice:

````markdown
## Cycle [now] — step: [step]
- Outcome: [write failed: operation — detail | agent returned no valid result block twice]; parked for a human
- Questions asked: none
- Commits: [the agent's commits, if any | none]
- Label: tsf:needs-human
- Next step: [the step's own Next step, or the step itself if none was valid]
````
