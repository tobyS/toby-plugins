<!--
Runtime reference for the tsf software factory. Read at the point of use —
always in full, even if already read earlier in the session — by the tsf:gate
agents (plan-compliance, spec-coverage, security, integration) before they emit
a report, and by /tsf:cycle before it writes one to the branch. Never copied
into consuming projects.

Changes to this file are command-contract changes: the CLAUDE.md rule "tsf: the
gate report is a machine contract" applies — the leading machine lines are
parsed, so changing them requires updating plugins/tsf/agents/{plan-compliance,
spec-coverage,security,integration}.md and
plugins/tsf/references/cycle-dispatch.md in the same commit.

Contents:
1. Where the report lives and who writes it
2. The machine lines
3. The report skeleton
4. Verdicts and findings
-->

# Where the report lives and who writes it

A gate has `tools: Read, Grep, Glob` — no `Write` — so it **returns** the report
as its final message and the dispatcher writes it to the branch at
`thoughts/factory/GH-<n>/reports/<gate>-<episode>-<round>.md`, where `<gate>` is
`plan-compliance`, `spec-coverage` or `security`. Nothing is overwritten: a new
fix round writes new files, and the round counter is derived from the filenames
already there.

The three post-implement gates of one cycle share **one** episode and **one**
round: they judge the same head at the same moment.

**The integration gate is numbered differently**: its report is
`reports/integration-<attempt>.md`, where `<attempt>` is the **landing
attempt** (§9.3), not an episode-and-round pair. A landing that restarts keeps
the earlier reports, because the main head each one recorded is what tells the
next attempt whether the base branch has moved again (§16.46).

# The machine lines

The report begins with its machine lines, in this order, before anything else.
For the three post-implement gates there are exactly two:

```
head: <the logic head sha the gate judged>
verdict: pass | fail
```

For the **integration gate** there are three:

```
head: <the logic head sha the gate judged>
main-head: <the base branch head the gate judged against>
verdict: safe | risk
```

- `head:` is the **logic head** (`diff.sh logic-head`), never the plain pull
  request head — the commit that adds this very report moves the latter, so a
  report could never name it. A report whose `head:` differs from the branch's
  current logic head is **stale and counts as missing**: the gates re-run.
- `main-head:` (integration only) is the base branch head the gate judged
  against, from `diff.sh main-delta`. A restarted landing compares it with the
  base branch's current head to decide whether the gate must run again: the
  base branch moving is the gate's only trigger (§7 gate 4, §9.3 step 2).
- `verdict: fail` iff any criterion is **not met**, or any finding is
  **blocking**. Everything else — "cannot verify from diff", "needs human
  verification", advisory findings — is `pass` with the items carried into the
  dossier's open items. The dispatcher reads this line and nothing else to
  decide whether to route the ticket into fix mode.
- `verdict: risk` (integration only) is **not** the same as `fail`: it never
  routes into fix mode. It sends the ticket to `tsf:needs-review` with a
  dossier addendum, because the judgement it carries is the human's to make.

The dispatcher fills `head:` — and, for the integration gate, `main-head:` —
from its own `diff.sh` calls when it writes the file, so a gate that cannot
know either sha writes `unknown` and the dispatcher replaces it.

# The report skeleton

````markdown
head: [logic head sha]
verdict: [pass | fail]

# [Gate name]: GH-[n]

**Overall:** [one line — the roll-up a human reads first]

| # | [Criterion | Finding] | Verdict | Evidence |
|---|---|---|---|---|
| 1 | [text, verbatim from the input] | [verdict] | `path/to/file.ext:NN` — [what confirms it] |

## Notes

[Only what a verdict cannot carry: a criterion whose wording is ambiguous, a
file the diff references but does not contain. Omit the section when there is
nothing.]
````

The **integration** gate's skeleton differs only in its machine lines and in
what the table's rows are — one row per interaction found, not per criterion:

````markdown
head: [logic head sha]
main-head: [base branch head sha]
verdict: [safe | risk]

# Integration: GH-[n]

**Overall:** [one line — the roll-up a human reads first]

| # | Interaction | Verdict | Evidence |
|---|---|---|---|
| 1 | [what in the base branch's delta meets what in this pull request] | risk | `path/to/file.ext:NN` — [what breaks between them] |

## Notes

[Omit when there is nothing.]
````

# Verdicts and findings

**plan-compliance and spec-coverage** return exactly one verdict per given
criterion:

- **met** — the change satisfies it; cite `path:line` in the diff or the
  post-change source.
- **not met** — it does not; state what is missing or contradictory.
- **cannot verify from diff** — not observable in the diff or the post-change
  source (runtime behaviour you cannot see).
- **needs human verification** — inherently manual (visual judgment, subjective
  acceptance). Never guessed, never silently passed: it reaches the dossier.

Tie-break: **when in doubt between met and not met, use cannot verify from
diff.**

**security** returns one row per finding, classified:

- **blocking** — a concrete, evidenced defect the implementation must fix.
  Routes exactly like a "not met".
- **advisory** — a judgment call for the human; it reaches the dossier's open
  items and never blocks.

**integration** returns one row per interaction it can name between this pull
request and what the base branch gained since the approval:

- **risk** — a concrete interaction: what in the delta, what in the pull
  request, and what breaks between them. One is enough to make the report's
  `verdict: risk`.
- **safe** — the verdict when no such interaction can be named.

Tie-break: **when you cannot name the two specific places that interact and
what goes wrong between them, the verdict is safe.** A risk costs the human a
review round, so it is earned, not guessed — but a missed interaction is the
one thing this gate exists to catch, so do not talk yourself out of one you
can actually point at.

No findings is a complete answer: `verdict: pass` (or `safe`) with an
`**Overall:**` line saying so and an empty table.
