<!--
Runtime reference for the tsf software factory. Read by /tsf:cycle at Step 8
(Report and end) — always in full, even if already read earlier in the session.
Never copied into consuming projects.

Changes to this file are command-contract changes: the report is what the
self-paced /loop reads to choose its next wake-up, so keep the suggested-wait
line when editing, and keep "not implemented in this slice" in step with
plugins/tsf/commands/cycle.md.

Contents:
1. The report
2. The suggested wait
-->

# The report

Print exactly this, filling each line from what this cycle observed and did.
Omit a line only where it says so. Nothing is printed after the report, and the
turn ends.

```markdown
## tsf cycle — <now>

- **Ticket:** GH-<n> — <step> (<previous label> → <new label>): <summary line from tsf-result>
- **Writes:** journal <short sha> pushed · PR #<n> opened · marker updated · comment <id> · label <label>
- **Gates:** plan-compliance pass · spec-coverage pass · security pass — dossier next
- **Skipped:** GH-<a> (tsf:needs-answer, no reply) · GH-<b> (ci pending on abc1234) · GH-<c> (landing not implemented in this slice)
- **Preflight:** ok
- **Suggested wait:** <delay> — <reason>
```

- **Ticket** — for an idle cycle: `idle — nothing actionable`. For a park without
  an agent result: `GH-<n> — parked for a human: <outcome line>`. When the
  preflight or scan failed: `none — <which step failed>`.
- **Writes** — the writes that succeeded, in order; a failed one is named with
  its `detail:` line (e.g. `comment FAILED — denied: …`). `none` for an idle
  cycle or a failed preflight or scan.
- **Gates** — only on a gate cycle: `plan-compliance <verdict> · spec-coverage
  <verdict> · security <verdict, k blocking>`, then what it routed to
  (`dossier next` or `fix round k of m`). Omit the line otherwise.
- **Skipped** — every ticket Step 3 or a re-pick skipped, with its reason:
  `no reply`, `waiting on review`, `waiting on a human`, `ci pending on <sha>`,
  `needs a single tsf:* state label`, `landing not implemented in this slice`,
  `unknown tsf label`. Omit the line when nothing was skipped.
- **Preflight** — `ok`, or the preflight's `detail:` line.

# The suggested wait

`/loop` without an interval picks its own delay after each iteration from what
it observed; this line is that observation, stated plainly. Choose the first
that applies:

| Situation | Suggested wait |
|---|---|
| A step ran, and a ticket is still actionable (the advanced ticket continued, or another one was waiting) | 1 minute |
| A ticket is waiting on a CI run and nothing else is actionable | 5 minutes — name the pending head |
| A step ran or a ticket was parked, and nothing else is actionable | 5 minutes |
| Idle, and tickets are parked waiting for a reply | 15 minutes |
| Idle, nothing parked | 30 minutes |
| Preflight or scan failed | 30 minutes — and say that the runner needs a human: the cycle writes nothing until the cause is fixed |
