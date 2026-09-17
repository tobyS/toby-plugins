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
## Cycle [YYYY-MM-DDTHH:MMZ] — step: [triage | research | plan]
- Outcome: [one line — what the step produced or decided]
- Questions asked: [none (gate skipped: nothing to ask) | k (parked)]
- Commits: [short sha, space-separated | none]
- Label: [the tsf:* state label this cycle sets]
- Next step: [triage | research | plan | implement]
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
- `implement` — the plan is approved; implementation runs next (a later slice).

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

Failed GitHub write, or an agent return without a valid result block twice:

````markdown
## Cycle [now] — step: [step]
- Outcome: [write failed: operation — detail | agent returned no valid result block twice]; parked for a human
- Questions asked: none
- Commits: [the agent's commits, if any | none]
- Label: tsf:needs-human
- Next step: [the step's own Next step, or the step itself if none was valid]
````
