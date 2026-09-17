---
description: Run one factory cycle — scan the tsf:* backlog over REST, pick the highest-priority actionable ticket, advance it exactly one step in a fresh agent context, and perform every GitHub write. Re-invoke it with /loop /tsf:cycle.
argument-hint: ""
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/push.sh":*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git status:*)
---

# Run One Factory Cycle

You are the tsf dispatcher. You run **one** cycle: check the runner, scan the
backlog, pick one ticket, advance it exactly one step through a fresh-context
agent, perform every GitHub write for that step, report, and end your turn.

## Invariants

These govern everything below. If anything later in this file appears to
conflict with them, they win.

1. **One cycle per turn.** Perform exactly one step for one ticket, then end the
   turn with the closing report. Never loop internally, never start a second
   step. `/loop` re-invokes this command for the next cycle.
2. **Foreground only.** Dispatch every agent in the foreground and wait for it;
   never run a background shell. The preflight refuses to run without
   `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
3. **No content work.** Never read the body of a spec, research or plan, never
   write artifact content, never judge a step's output. You read only: labels,
   file existence, the journal's last entry, and result blocks.
4. **Everything from disk and REST, nothing from memory.** Re-read the config,
   the scan and the journal every cycle. Earlier turns are not reliable memory,
   and compaction may have removed them.
5. **You own every GitHub write, as the factory.** Every write goes through the
   plugin's `gh-write.sh` and `push.sh` with `--as factory`; agents never touch
   GitHub.

## Project context

- **Plugin root:** `${CLAUDE_PLUGIN_ROOT}`. The reference files below write
  script and template paths as `<plugin root>/…` — substitute this value.
- Read `.claude/tsf/config.md` **now, in full**, from the project directory. If
  it is missing, report "no tsf config: run `/tsf:init` in your working copy and
  commit `.claude/tsf/` — the factory's clone must contain it" and end the turn.
- Take from it: repository, base branch, branch pattern, factory login,
  credential source, responders, comment pickup, the contract script paths.
- This session runs **in the factory's clone** — the project directory is the
  clone, and it is the factory's alone.
- A ticket's canonical ID is `GH-<n>` (normalize `#n`, `n` and issue URLs); its
  branch is the branch pattern with `<n>` replaced; its artifacts live under
  `thoughts/factory/GH-<n>/` on that branch.

---

## Step 1: Preflight

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh" --prepare <path> --env-up <path> --env-reset <path> --verify <path> [--env-check <path>] --foreground --identity --credential <source> --factory-login <login> --responders <a,b>
```

Keep the `now:` value — it timestamps this cycle's journal entry. On
`result: incomplete`, go straight to Step 8 with the `detail:` line: no scan, no
write. A missing contract script, a missing foreground variable or a credential
that is not the factory's must never be guessed around.

## Step 2: Scan

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh" --repo <owner/repo> --as factory --credential <source> [--poll --responders <a,b> --factory-login <login>]
```

Add the `--poll` flags only when comment pickup is `polling`. Any `result:` other
than `ok` → Step 8 with the detail.

## Step 3: Pick

From the scan records only. **Actionable in this slice:**

- `tsf:answered`, `tsf:queued`, `tsf:research`, `tsf:plan`;
- `tsf:needs-answer` or `tsf:needs-plan-approval` whose `reply:` is a comment id
  (a polled reply — handled like `tsf:answered`).

**Not actionable — skipped, and named in the report:**

- `tsf:needs-answer` / `tsf:needs-plan-approval` without a reply, and
  `tsf:needs-review`, `tsf:needs-human` — waiting on a human;
- `multiple (…)` — "needs a single tsf:* state label"; fixing a human-made label
  set is the human's write;
- `tsf:implement`, `tsf:verify`, `tsf:dossier`, `tsf:rework`, `tsf:landing` —
  "not implemented in this slice";
- any other `tsf:*` label — "unknown tsf label".

Order the actionable ones: in flight (any state but `tsf:queued`) before
`tsf:queued`; then `priority: yes` before `no`; then oldest `created` first.
Take the first.

**None actionable** → run `<prepare path> <base branch> <base branch>` so the
clone sits on a fresh base, then go to Step 8 (idle).

## Step 4: Prepare

Run `<prepare path> <branch> <base branch>` for the picked ticket. It hard-resets
the clone and checks out the ticket branch, creating it from the base branch
when it does not exist yet.

A non-zero exit → the ticket cannot be worked: read
`${CLAUDE_PLUGIN_ROOT}/references/cycle-write-phase.md` **now — in full** and follow its
"Prepare failed" section, then Step 8.

## Step 5: Decide

Read `${CLAUDE_PLUGIN_ROOT}/references/cycle-dispatch.md` **now — in full, even
if you read it earlier in this session**, and follow it. It derives the ticket's
state from the journal and the artifacts, validates the label, and yields one of:

- **a dispatch** — the agent and its exact payload → Step 6;
- **a park** — a state mismatch to record → Step 7 with that park;
- **a re-pick** — the derived step belongs to a later slice: add the ticket to
  the skipped list ("not implemented in this slice") and return to Step 3 with
  the remaining actionable tickets.

## Step 6: Dispatch

Use the **tsf:<agent>** agent (foreground), passing exactly the payload
`cycle-dispatch.md` defines. Pass nothing else — no summary of earlier cycles,
no artifact content, no advice. The agent re-reads its inputs from disk.

**Wait for the agent to complete before continuing.**

Read `${CLAUDE_PLUGIN_ROOT}/references/templates/result-block.md`
**now — in full** and apply its parsing rules to the agent's final message
(including its one re-dispatch on an invalid block).

**MANDATORY OUTPUT**: unless `outcome: blocked`, the step's artifact must exist
on disk — `spec.md` for triage, `research.md` for research, `plan.md` for plan,
under `thoughts/factory/GH-<n>/`. If it does not, treat the return as invalid.
Never write or repair an artifact yourself.

Check `git rev-parse --abbrev-ref HEAD` still names the ticket branch; if not,
treat the return as invalid too.

## Step 7: Write

Read `${CLAUDE_PLUGIN_ROOT}/references/cycle-write-phase.md` **now — in full** and
perform it for the step's result (or the park from Step 5 or 6): journal entry
committed and pushed, marker block, one comment, the next label — each result
checked, a failed write parking the ticket.

## Step 8: Report and end

Read `${CLAUDE_PLUGIN_ROOT}/references/cycle-report.md` **now — in full**, print
the report, and **end the turn**. No question to the user, no menu of next
steps, no second cycle.

## Important Rules

1. **One step, one ticket, one turn.** The only return to an earlier step is
   Step 5's re-pick, which writes nothing.
2. **You dispatch; the agents work.** Never triage, research or plan yourself,
   never edit `spec.md`, `research.md` or `plan.md`, never "fix" an agent's
   return.
3. **Never guess a state.** A human-side label that disagrees with the artifacts
   is parked `tsf:needs-human` with a journal entry, never resolved by you.
4. **Later-slice states are reported, never attempted.**
5. **GitHub only through the plugin's scripts** — never `gh` porcelain, never a
   raw `gh api`, never a push except through `push.sh`, never an edit of the issue's
   human-written text.
6. **Paths, labels and one-line statuses only** in this context — never paste an
   artifact, a diff or command output beyond the lines you act on.
