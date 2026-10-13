<!--
Runtime reference for the orchestrated /tce:work. Read at the point of use —
always in full, even if already read earlier in the session — by /tce:work when
it derives its position (Step 4) and before each dispatch. Never copied into
consuming projects.

Changes to this file are command-contract changes under the CLAUDE.md rule
"tce: /tce:work is an orchestrator": the payloads are the agents' "What you
receive" sections seen from the other side (return-shape span: agent-returns.md,
the five agents, work.md, this file), and the bounds are the fix-loop span
(plan-document-template.md, implementer.md, verifier.md, this file). Change one
side and you change the other in the same commit.

Contents:
1. The position table
2. Payloads, per agent and mode
3. Bounds
4. Resume and re-dispatch
5. Rendering what reaches the human
-->

# The position table

The position is always derived from disk, never from the conversation. Read
the signals, then take the **first** row that matches.

Signals:

- `stage.sh <ID>` — `research:`, `plan:`, `progress:` (`k/N`, `?/N` or empty)
  and `source:` (`log | sidecar | unknown | no-plan`).
- `ticket.sh <ID>` — a path under `thoughts/shared/dossiers/` means a dossier
  exists.
- In the plan, `grep -n` for: `^## Verification`, the verifier's `suites:`
  line and its `— not met —` lines; `^## Implementation Closeout` and its
  `**Manual verification**` line; `\*\*Base commit\*\*`; `Final fix rounds`.
- In the research document, `grep -n` for its `git_commit:` line.

Reading these lines is how the orchestrator reads the documents — never their
body.

| # | When | Next step |
|---|---|---|
| 1 | Closeout's Manual verification says `verified by agent` or `confirmed by user` | report done, stop |
| 2 | Closeout's Manual verification says `pending:` | Step 12 (items for you to check) |
| 3 | Closeout's Manual verification says `failed:` | report the failure as `needs decision`, stop |
| 4 | a dossier exists | delivery, then closeout |
| 5 | `k/N` with `k = N`, `## Verification` exists, no `— not met —` line, no ❌ on its `suites:` line | dossier |
| 6 | `k/N` with `k = N` | verify |
| 7 | `k/N` with `k < N`, or `source: sidecar` | implement (sidecar: `phase: first-incomplete`) |
| 8 | plan exists, `source: unknown` | brief, then approval |
| 9 | research exists, no plan | plan questions |
| 10 | no research | research |

A phase logged `❌ Blocked` or `⚠️ Partial` is not done, so row 7 sends
the implementer back to it; the implementer reads its log and continues. On
`source: sidecar` the first implementer dispatch transcribes the legacy
sidecar's progress into the plan's logs, after which `stage.sh` reports
`source: log`.

# Payloads

Dispatch with "Use the tce:<agent> agent" and a prompt of exactly these
`key: value` lines — paths relative to the project root, never contents. Every
payload starts with the common block:

```
ticket: [PREFIX]-XXXX
ticket-file: <path, or none for a hosted ticket system>
intent: <path>
references: <the plugin's references directory>
profile: .claude/tce/profile.md
tickets: .claude/tce/tickets.md
```

Then, per agent and mode:

- **researcher** — `parent: <ticket, research, plan paths of the parent, or
  none>`, `branch: <current branch>`.
- **planner, `mode: questions`** — `research: <path>`, `parent: …`,
  `mode: questions`.
- **planner, `mode: write`** — `research:`, `parent:`, `mode: write`,
  `answers:` followed by each question's header and the human's answer,
  verbatim, one per line (`answers: none` when there were no questions).
- **planner, `mode: revise`** — `research:`, `parent:`, `plan: <path>`,
  `mode: revise`, `push-back:` followed by the human's text, verbatim.
- **planner, `mode: challenge-fix`** — `research:`, `parent:`, `plan:`,
  `mode: challenge-fix`, `findings:` followed by the challenger's `fail`
  lines, verbatim.
- **planner, `mode: brief`** — `research:`, `parent:`, `plan:`,
  `mode: brief`.
- **plan-challenger** — `plan:`, `research:`, and `brief:` followed by the
  planner's last brief (or delta), verbatim. (It takes `intent:`, `profile:`
  and `references:` from the common block and ignores the rest.)
- **implementer, `mode: phase`** — `research:`, `plan:`,
  `research-baseline: <sha or none>` (Step 7 point 1), `mode: phase`,
  `phase: <k+1>` (or `first-incomplete` on `source: sidecar`), `phases: <N>`,
  and — only while the plan has no `**Base commit**` — `base-commit: <sha>`,
  the output of `git rev-parse HEAD` taken right before this dispatch.
- **implementer, `mode: fix`** — `research:`, `plan:`, `research-baseline:`,
  `mode: fix`,
  `findings:` followed by the verifier's lines before its block, verbatim.
- **verifier** — `research:`, `plan:`, `baseline: <sha>`,
  `baseline-source: recorded | introducing`, `mode: verify | dossier`; in
  `dossier` mode also `concerns:` followed by every `concerns:` bullet the
  run's agents returned, verbatim (`concerns: none` when there were none).

A retry after an unreadable return adds `note:` with the retry note from
`agent-returns.md`, verbatim.

# Bounds

| Loop | Bound | Where the count lives |
|---|---|---|
| challenger → planner `challenge-fix` | 3 rounds | in the run (a crash restarts it at round 1) |
| a phase's own fix loop | 3 rounds | the phase's log, `Fix rounds: n/3` — the implementer's |
| verifier → implementer `fix` | 3 rounds | the last phase's log, `Final fix rounds: n/3` |

When a bound is exhausted, the step is `needs decision`: show the last round's
evidence and stop. Both on-disk counts survive a re-run: a dispatch that finds
its counter at 3/3 returns `needs decision` again without changing anything. A
human who wants three more rounds fixes what they can, sets that line to `0/3`,
and re-runs — say so in the stop message.

# Resume and re-dispatch

- **Resume** the planner with `SendMessage` to its agent ID, carrying the new
  `mode:` line and its field (`answers:`, `push-back:` or `findings:`), so it
  keeps what it already read.
- **Re-dispatch fresh** when the agent ID is lost (a new session, a compacted
  conversation without it) or a resumed agent's result does not arrive within
  this turn: a fresh dispatch with the same mode and the same verbatim
  answers, push-back or findings. Every agent re-reads its documents from
  disk, so a fresh dispatch loses nothing that matters.
- Every other step is a fresh dispatch.

# Rendering what reaches the human

Only `needs decision` and `blocked` stop the run. Render either as:

```
<STOPPED: needs decision | STOPPED: blocked> — <one takeaway line: which step, what happened>

Needed: <what the human has to decide or do, one or two lines>
Run:    <the exact command, file or steps, when there is one>
Then:   /tce:work [PREFIX]-XXXX
```

- Take the content from the return's `summary:`, `blocked-on:` and the lines
  before the block — never invent evidence.
- Phrase it for the profile's `## Reader`: name and explain in half a sentence
  any tool, library, pattern or abbreviation outside the reader's fluency.
- `done with concerns` never stops the run: keep its `concerns:` bullets for
  the verifier's dossier dispatch, and repeat none of them before then.
