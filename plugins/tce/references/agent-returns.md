<!--
Runtime reference for the orchestrated /tce:work. Read at the point of use —
always in full, even if already read earlier in the session — by every agent
/tce:work dispatches (`researcher`, `planner`, `plan-challenger`, `implementer`,
`verifier`) before it composes its return, and by /tce:work when a return is
unreadable. Never copied into consuming projects.

Changes to this file are command-contract changes under the CLAUDE.md rule
"tce: /tce:work is an orchestrator" (the return-shape span): a change to the
status vocabulary, the block's fence name, a field, the field order or the
retry note updates this file, the five agents' `## Return` sections, work.md
and work-dispatch.md in the same commit.

Contents:
1. The status vocabulary
2. The return block
3. The planner's extra body
4. Length bounds
5. The parsing rule and the retry note
-->

# The status vocabulary

Every return carries exactly one of four statuses:

- **`done`** — the step finished and its artifact is on disk and committed.
- **`done with concerns`** — the step finished, but something the human should
  know about remains. The concerns travel to the dossier; they do **not**
  interrupt the run.
- **`needs decision`** — the step needs the human: the planner's questions, the
  challenger's or verifier's failures, or an exhausted fix loop (with the
  evidence of the last round).
- **`blocked`** — a situation the agent can neither resolve nor defer: a
  mismatch between plan and reality, a missing tool or credential, a commit
  that would ask. Never use it for something the agent could resolve itself
  or could record as a concern.

Only `needs decision` and `blocked` reach the human. The research and implement
steps never return `needs decision` except for an exhausted fix loop; questions
are the planner's alone.

# The return block

Your final message ends with exactly one fenced block tagged `tce-return`. No
angle brackets anywhere inside it and no nested fences — it travels back to the
orchestrator as text and must survive that. The fields, in this order:

```tce-return
status: done
step: research
artifact: thoughts/shared/research/2026-10-11-MYAPP-0042-export-csv.md
summary: Export lives in src/export/; CSV writer reused from reports.
  Two open questions recorded for planning (date format, encoding).
  No tce config drift.
concerns: none
```

- **`status:`** — one value of the vocabulary above.
- **`step:`** — one of `research | plan-questions | plan | brief | challenge |
  implement | fix | verify | dossier`.
- **`artifact:`** — the path of the document the step wrote or changed,
  relative to the project root, or `none` (`plan-questions` and `challenge`
  write nothing).
- **`summary:`** — at most 3 lines; continuation lines are indented two spaces.
  Counted facts, never confidence numbers.
- **`concerns:`** — `none`, or one `- ` bullet per concern on the following
  lines, indented two spaces.
- **`blocked-on:`** — only with `status: blocked`: what is in the way and the
  exact command, file or decision the human needs. Leave the field out
  otherwise.

# The planner's extra body

The planner's return carries more than the block. **Before** the block it
writes:

- on `step: plan-questions`, the understanding, the approach and the questions,
  in `work-brief.md`'s question layout;
- on `step: plan` or `step: brief`, the brief in `work-brief.md`'s brief layout
  — or, after a push-back or challenger findings, the delta layout.

No other agent writes anything outside the block except the challenger's and
verifier's one-line-per-item findings, which also go before the block.

# Length bounds

- The block: at most 25 lines.
- A brief, a delta or a question batch: at most 60 lines.
- Findings before the block: one line per item, at most 30 lines; the full
  evidence goes into the artifact.
- The full artifact is always named by path and never inlined.

# The parsing rule and the retry note

The orchestrator reads the block as text. **No script parses it**, and no
script parses any agent-authored document; the only mechanical check is that
the named artifact exists, is non-empty and is committed.

A return without a readable `tce-return` block — missing, malformed, or with a
status outside the vocabulary — gets **one** retry. The orchestrator resumes the
agent with this note, verbatim:

```
Your return did not contain a readable tce-return block. End your reply with
exactly the block shown in your own ## Return section, fields in that order.
```

A second unreadable return is treated as `blocked`, naming the agent and the
step.
