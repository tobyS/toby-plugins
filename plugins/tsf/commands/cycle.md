---
description: Run one factory cycle — scan the tsf:* backlog over REST, pick the highest-priority actionable ticket, advance it exactly one step in a fresh agent context, and perform every GitHub write. Re-invoke it with /loop /tsf:cycle.
argument-hint: ""
allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/diff.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/gh-write.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/push.sh":*), Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git ls-files:*), Bash(git rev-parse:*), Bash(git status:*)
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
3. **No content work.** Never read the body of a spec, research, plan or diff,
   never write artifact content, never judge a step's output. You read only:
   labels, file existence, the journal's last entry, result blocks and a gate
   report's two machine lines. The diff reaches the gates **as a path**.
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
"${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh" --prepare <path> --env-up <path> --env-reset <path> --verify <path> [--env-check <path>] --foreground --bash-timeout --identity --credential <source> --factory-login <login> --responders <a,b>
```

Keep the `now:` value — it timestamps this cycle's journal entry. On
`result: incomplete`, go straight to Step 8 — which still reads its reference and
prints the report in the prescribed shape — carrying the `detail:` line: no scan,
no write. A missing contract script, a missing foreground or timeout variable, or
a credential that is not the factory's must never be guessed around.

## Step 2: Scan

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh" --repo <owner/repo> --as factory --credential <source> [--poll --responders <a,b> --factory-login <login>] --pr-probe --branch-pattern <pattern> --factory-login <login> (--required-check "<name>" … | --no-ci)
```

Add the `--poll` flags only when comment pickup is `polling`; `--pr-probe`
always. Pass **one `--required-check` per name** in the config's `Required
checks`, quoted — never a comma-separated list, because a check's display name
routinely contains commas — or `--no-ci` when the config says `none`. Any
`result:` other than `ok` → Step 8 (read its reference, report) with the detail.

## Step 3: Pick

From the scan records only. **Actionable:**

- `tsf:answered`, `tsf:queued`, `tsf:research`, `tsf:plan`, `tsf:implement`,
  `tsf:dossier`, `tsf:rework`;
- `tsf:verify` **unless** its `ci:` is `pending` — a ticket waiting on CI is not
  actionable, and its `pr_head:` is named in the report so `/loop` paces short.
  `ci: no-ci` is not waiting: this project runs no pull-request CI, so the
  ticket is actionable and the gates will run on local evidence alone. A
  `pending` ticket whose `checks:` is `0` gets **one probe** before it is
  skipped — see "A head no check has reached" below;
- `tsf:needs-review` whose `review:` is `approved` or `changes-requested`;
- `tsf:needs-answer` or `tsf:needs-plan-approval` whose `reply:` is a comment id
  (a polled reply — handled like `tsf:answered`);
- **at most one `tsf:landing` ticket** — see "One landing in flight" below.

**Not actionable — skipped, and named in the report:**

- `tsf:needs-answer` / `tsf:needs-plan-approval` without a reply,
  `tsf:needs-review` with `review: none`, and `tsf:needs-human` — waiting on a
  human;
- `tsf:verify` with `ci: pending` — "ci pending on `<pr_head>`" (including a
  `checks: 0` ticket the probe below found neither conflicted nor overdue);
- `multiple (…)` — "needs a single tsf:* state label"; fixing a human-made label
  set is the human's write;
- every `tsf:landing` ticket the rule below excludes;
- any other `tsf:*` label — "unknown tsf label".

**A head no check has reached.** `ci: pending` with `checks: 0` means no required
check run exists for this head at all — not that one is running. Two things
cause it and neither resolves by waiting, so probe once:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/gh-read.sh" pr-state --repo <owner/repo> --as factory --credential <source> --pr <n>
```

Keep its `mergeable:` and `head_at:`; row 7 acts on them, so this is one read
per affected ticket per cycle, not two.

- `mergeable: false` → the pull request conflicts with the base branch. GitHub
  runs **no** `pull_request` workflow while a merge conflict is open, so CI will
  never start here. **Actionable**, reason "conflicted".
- otherwise, when `head_at:` is more than `ci_pending_bound` minutes before the
  preflight's `now:` → **actionable**, reason "ci pending too long".
- otherwise → skip as usual.

`mergeable: unknown` (GitHub is still computing it) is not conflicted; fall
through to the age test. `head_at: -` means the commit read was refused — skip,
and let the next cycle try again rather than parking on a missing timestamp.

This is the one REST read the pick performs. It needs no branch, so the "decided
from the scan alone" constraint the landing rule below relies on is untouched.

**One landing in flight** (§5.2, §9.3). A landing spans two cycles, and every
landing makes the other approved pull requests out of date — so a second one
started now would only waste a CI run and void the first decision. Decided from
the scan alone, since no branch is checked out yet:

- Order the `tsf:landing` tickets by `review_at:`, **oldest approval first**.
  The first of them is the landing in flight; it stays first across both of its
  cycles, because its approval does not move while it lands.
- That one is actionable **unless** its `ci:` is `pending` — then skip it as
  "ci pending on `<pr_head>` (landing)" and let the cycle work something else.
  This is the wait between the decision cycle and the merge cycle: after the
  decision is pushed, CI runs on it, and the scan's `ci:` is read on exactly
  that head.
- Every other `tsf:landing` ticket is skipped as "another landing is in flight".

Order the actionable ones: **the landing first**; then in flight (any state but
`tsf:queued`) before `tsf:queued`; then `priority: yes` before `no`; then
oldest `created` first. Take the first.

**None actionable** → run `<prepare path> <base branch> <base branch>` so the
clone sits on a fresh base, then go to Step 8 (idle).

## Step 4: Prepare

1. **Note the branch you are on** — `git rev-parse --abbrev-ref HEAD` — *before*
   preparing. It is the only signal of a ticket switch.
2. Run `<prepare path> <branch> <base branch>` for the picked ticket. It
   hard-resets the clone and checks out the ticket branch, creating it from the
   base branch when it does not exist yet.
3. **Implementation-flavored states only** (`tsf:implement`, `tsf:verify`,
   `tsf:rework`, `tsf:dossier`): run `<env_up path>`; then `<env_reset path>`
   when the branch noted in 1 differs from this ticket's branch — the switch is
   what makes a reset necessary, and a warm environment is why it is skipped
   otherwise; then `<env_check path>` when one is registered.

**Run every contract script with the Bash tool's maximum timeout**, and the same
wherever you run the project's `verify` (Step 5's row 6). These are the project's
own suites and setup commands, not shell one-liners; a command cut short by the
default timeout is not a verdict. The preflight has already confirmed the
session's floor.

A non-zero exit from `prepare` → the ticket cannot be worked: read
`${CLAUDE_PLUGIN_ROOT}/references/cycle-write-phase.md` **now — in full** and follow its
"Prepare failed" section, then Step 8. A non-zero exit from `env_up`,
`env_reset` or `env_check` → the same section's "Environment failed" handling.

## Step 5: Decide

Read `${CLAUDE_PLUGIN_ROOT}/references/cycle-dispatch.md` **now — in full, even
if you read it earlier in this session**, and follow it. It derives the ticket's
state from the journal and the artifacts, validates the label, and yields one of:

- **a dispatch** — one agent and its exact payload, or the **gate cycle** (all
  three post-implement gates at once) → Step 6;
- **a park** — a state mismatch to record → Step 7 with that park;
- **a re-pick** — the ticket cannot be advanced after all, with nothing wrong
  with it: add it to the skipped list with the row's reason and return to
  Step 3 with the remaining actionable tickets;
- **a decision without an agent** — the review read of row 10, or a landing
  cycle that dispatched nothing → Step 7 directly;
- **a write-free merge** — the landing's merge cycle, which performs its GitHub
  writes inside row 12 and goes straight to Step 8.

## Step 6: Dispatch

Use the **tsf:<agent>** agent (foreground), passing exactly the payload
`cycle-dispatch.md` defines. Pass nothing else — no summary of earlier cycles,
no artifact content, no advice. The agent re-reads its inputs from disk.

**The gate cycle** dispatches **tsf:plan-compliance**, **tsf:spec-coverage** and
**tsf:security** together, in one message, all foreground, and waits for all
three before anything is written. Each gets the diff **as a path**, never as
content: run
`"${CLAUDE_PLUGIN_ROOT}/scripts/diff.sh" pr-diff --base <base branch>` once and
pass its `file:` value to all three. You never read that file.

**tsf:integration** is dispatched alone, at landing time, by row 12. It is a
gate like the other three — report content back, foreground, its diffs as
paths — but it never runs with them: they judge the pull request, it judges the
combination.

**Wait for the agent to complete before continuing** — for the gate cycle, for
all three.

Read `${CLAUDE_PLUGIN_ROOT}/references/templates/result-block.md`
**now — in full** and apply its parsing rules to the agent's final message
(including its one re-dispatch on an invalid block). The gates return **report
content** instead, whose contract is `references/templates/report.md`: the
machine lines first, `verdict:` the only thing you route on.

**MANDATORY OUTPUT**: unless `outcome: blocked`, the step's artifact must exist
on disk under `thoughts/factory/GH-<n>/` — `spec.md` for triage, `research.md`
for research, `plan.md` for plan, at least one new commit for implement,
verify-fix, rework and merge-resolver, `reports/dossier.md` for dossier; and a
non-empty report beginning `head:`/`verdict:` from each gate. If it does not,
treat the return as invalid. Never write or repair an artifact yourself.

Check `git rev-parse --abbrev-ref HEAD` still names the ticket branch; if not,
treat the return as invalid too.

## Step 7: Write

Read `${CLAUDE_PLUGIN_ROOT}/references/cycle-write-phase.md` **now — in full** and
perform it for the step's result (or the park from Step 5 or 6): journal entry
committed and pushed, marker block, one comment, the next label — each result
checked, a failed write parking the ticket.

## Step 8: Report and end

Read `${CLAUDE_PLUGIN_ROOT}/references/cycle-report.md` **now — in full** and
print the report exactly in the shape it prescribes, then **end the turn**. No
question to the user, no menu of next steps, no second cycle.

**Every cycle ends here and reads this file first** — including one that stopped
at the preflight or the scan, and one that wrote nothing. Never improvise a
report of your own: its shape, and especially its suggested wait, are what the
`/loop` runner reads to pace the next cycle.

## Important Rules

1. **One step, one ticket, one turn.** The only return to an earlier step is
   Step 5's re-pick, which writes nothing. The landing is not an exception: its
   decision cycle and its merge cycle are two cycles, never one turn.
2. **You dispatch; the agents work.** Never triage, research or plan yourself,
   never edit `spec.md`, `research.md` or `plan.md`, never "fix" an agent's
   return.
3. **Never guess a state.** A human-side label that disagrees with the artifacts
   is parked `tsf:needs-human` with a journal entry, never resolved by you.
4. **The merge cycle writes nothing to the repository** — no journal entry, no
   commit, no push, no comment. Any push there moves the pull request head past
   the commit CI checked, and the server refuses the merge.
5. **GitHub only through the plugin's scripts** — never `gh` porcelain, never a
   raw `gh api`, never a push except through `push.sh`, never an edit of the issue's
   human-written text.
6. **Paths, labels and one-line statuses only** in this context — never paste an
   artifact, a diff or command output beyond the lines you act on.
