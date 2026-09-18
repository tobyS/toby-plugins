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
step: [triage | research | plan | implement | verify-fix | manual-verify | dossier]
outcome: [continued | parked | blocked]
next-step: [triage | research | plan | implement | verify | gates | dossier | review]
next-label: [tsf:research | tsf:plan | tsf:implement | tsf:verify | tsf:dossier | tsf:needs-answer | tsf:needs-plan-approval | tsf:needs-review | tsf:needs-human]
commits: [short sha, space-separated | none]
manual: [k attempted, m need a human]   (manual-verify only; omit otherwise)
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

The dispatcher adds the `- Episode:` line itself on an entry that moves the
ticket into `tsf:verify` (journal-entry.md); an agent never writes it.

## The fourth fence: a step that leaves a report

`tsf:verify-fix` and `tsf:manual-verify` produce a record the **next** cycle
reads — the attempt counter and the manual results are derived from files on the
branch, never from memory. They add a fourth fence, after the other three:

````markdown
```tsf-report
[the report body, markdown: what was red and what was tried (verify-fix), or one
line per manual item with its evidence (manual-verify)]
```
````

The dispatcher writes it to the path its step dictates —
`reports/verify-fix-<episode>-<attempt>.md` or `reports/manual-<episode>.md` —
commits it with the journal entry, and pushes. An agent that omits this fence
when its step requires one has returned an invalid block: without the file, the
bound it feeds can never be reached.
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
| implement | continued | tsf:verify | verify |
| implement | parked | tsf:needs-answer | implement |
| verify-fix | continued | tsf:verify | verify |
| manual-verify | continued | tsf:verify | gates |
| dossier | continued | tsf:needs-review | review |
| any | blocked | tsf:needs-human | the step itself |

`implement` uses the same two rows in all three of its modes (fresh, rework,
fix): the mode changes what it works from, never where the ticket goes next.
`manual-verify` never parks — an item it cannot attempt is reported as needing a
human and travels to the dossier, which is not a park.

The three gates return **report content**, not a result block
(`report.md`); the dispatcher writes their reports and reads their
`verdict:` lines.

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
   `next-label` and `next-step`; `tsf-comment` is not empty; and, for
   `verify-fix` and `manual-verify`, the `tsf-report` fence is present and not
   empty.
5. Invalid or missing → dispatch the same agent once more with the same payload
   plus the line `note: your previous return had no valid result block`. Invalid
   again → park: journal entry naming the malformed return (journal-entry.md,
   "Entries the dispatcher writes on its own"), label `tsf:needs-human`, and a
   one-line comment of the dispatcher's own saying the step's agent failed
   twice and linking the journal.
