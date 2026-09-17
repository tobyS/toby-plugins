<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by every tsf
worker agent before it returns, and by /tsf:cycle before it parses a return.
Never copied into consuming projects.

Changes to this file are command-contract changes: the CLAUDE.md rule "tsf: the
result block is a machine contract" applies — change a fence name, a field or a
vocabulary and update plugins/tsf/agents/{triage,research,plan}.md,
plugins/tsf/commands/cycle.md and plugins/tsf/references/cycle-write-phase.md in
the same commit.

Contents:
1. The result block (what a worker returns)
2. Allowed outcomes per step
3. Parsing rules (what the dispatcher does)
-->

# The result block

A worker's final message ends with exactly these three fenced blocks, in this
order, and nothing after them. Everything the dispatcher needs is inside them;
nothing inside them uses angle brackets or nested code fences.

````markdown
```tsf-result
step: [triage | research | plan]
outcome: [continued | parked | blocked]
next-step: [triage | research | plan | implement]
next-label: [tsf:research | tsf:plan | tsf:implement | tsf:needs-answer | tsf:needs-plan-approval | tsf:needs-human]
commits: [short sha, space-separated | none]
summary: [one line for the cycle's closing report]
```

```tsf-comment
[The step's single issue comment, markdown, composed from question-comment.md:
the question comment, the plan summary, or the outcome comment.]
```

```tsf-journal
- Outcome: [one line]
- Questions asked: [none (gate skipped: nothing to ask) | k (parked)]
- Commits: [short sha, space-separated | none]
- Label: [same as next-label]
- Next step: [same as next-step]
```
````

# Allowed outcomes per step

| step | outcome | next-label | next-step |
|---|---|---|---|
| triage | continued | tsf:research | research |
| triage | parked | tsf:needs-answer | triage |
| research | continued | tsf:plan | plan |
| research | parked | tsf:needs-answer | research |
| plan | continued | tsf:implement | implement |
| plan | parked | tsf:needs-plan-approval | plan |
| any | blocked | tsf:needs-human | the step itself |

`blocked` is for what a human must fix before any step can succeed — the
branch is not in the expected state, an input artifact is missing or
unreadable, a project command the step depends on fails. Its comment says what
is wrong and what would fix it. Questions about *what* to build are never
`blocked`; they are `parked`.

# Parsing rules

The dispatcher, never the agent, applies these:

1. Ignore everything outside the three fences — including a leading
   `[harness: …]` line the platform may prepend to a subagent's output.
2. Take the **last** fence of each info string (`tsf-result`, `tsf-comment`,
   `tsf-journal`).
3. Inside `tsf-comment`, undo harness escaping: replace every `<\` with `<`.
4. Valid only when: all three fences are present; `step` equals the agent that
   was dispatched; the (`step`, `outcome`, `next-label`, `next-step`) row is in
   the table above; the journal's `Label` and `Next step` lines equal
   `next-label` and `next-step`; `tsf-comment` is not empty.
5. Invalid or missing → dispatch the same agent once more with the same payload
   plus the line `note: your previous return had no valid result block`. Invalid
   again → park: journal entry naming the malformed return (journal-entry.md,
   "Entries the dispatcher writes on its own"), label `tsf:needs-human`, and a
   one-line comment of the dispatcher's own saying the step's agent failed
   twice and linking the journal.
