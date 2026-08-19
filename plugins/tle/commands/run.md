---
description: Run one iteration of a tle convergence loop — verify, derive the next small step, implement and commit it — then end the turn so the /goal evaluator decides whether to continue.
argument-hint: "<goal-file>"
---

# Run Loop Iteration

You are tasked with running **one** iteration of a tle convergence loop: prove what is currently true, derive the single next step, land it, log it, and end your turn so Claude Code's `/goal` evaluator can decide whether another turn starts.

## CRITICAL: THE FOUR LOOP INVARIANTS

These govern everything below. If anything later in this file appears to conflict with them, they win.

1. **This command performs exactly ONE iteration. Never start a second iteration in the same turn.** Ending the turn is what lets `/goal`'s evaluator run — it evaluates only at turn end, so a turn containing many iterations is a turn with zero supervision.
2. **Never carry document contents, diffs, or test output in this context.** Agents write files and return one line; you pass paths and repeat one-line statuses. Nothing else enters your context.
3. **Dispatch every agent in the foreground, one at a time.** If a subagent or background shell is still running when the turn ends, Claude Code **skips that turn's goal evaluation** and the loop silently loses its driver.
4. **Read all loop state from disk on every invocation.** Iteration number, verdict vectors, escalation rung — all of it comes from files. Previous turns are not reliable memory, and compaction may have removed them entirely.

## Project context

This command ships in the **tle** (Toby Loop Engineering) plugin and is stack-agnostic. It hardcodes no framework, test runner, or directory layout — every such fact comes from the goal file's `## Ops facts` section.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` **if it exists**, as optional enrichment only. tle works fine without tce installed: if it is absent, say nothing about it and take every fact from the goal file.
- `<goal-slug>` is a placeholder for the loop's slug, `NNN` for a zero-padded three-digit iteration number, and `item-NN` for a checklist item ID — never literals.

---

## Workflow Context

**This is Step 3 of 3 in the tle loop workflow:**

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `/tle:define` | Agree a granular, machine-checkable goal; write `goal.md` |
| 2 | paste `/goal <condition>` | Pin the condition so Claude Code keeps taking turns until it is met |
| **→ 3** | **`/tle:run <goal-file>`** | **Run one iteration: verify → spec → implement → log** |

**Your role in this step:** Be the loop's orchestrator, not its worker. You dispatch, you record, you surface one line into the transcript, and you stop. You do not verify, plan, or implement anything yourself — that would put the very context in your window that the file-only handoff exists to keep out.

**Input:** A goal file path
**Output:** One `NNN-verify.md`, one `NNN-plan.md`, one commit, and one appended `loop-log.md` row

---

## Initial Setup

When this command is invoked:

1. **Check if a parameter was provided**:

   - If a goal-file path was provided as a parameter, skip the default message
     and begin immediately at Step 1 below.

2. **If no parameter was provided**, respond with:

```
I need the goal file for the loop you want to advance.

Usage: `/tle:run thoughts/shared/loops/<goal-slug>/goal.md`

If you haven't defined a goal yet, run `/tle:define` first.
```

Then wait for the user's answer. Do not guess a goal file, and do not run the loop against one you found by globbing.

## Steps

### 1. Re-read the goal file

**Read the goal file fully from disk now** — unconditionally, even if it already appears earlier in this conversation and even if you wrote it yourself in this session. Across turn boundaries and compaction there is no reliable memory of it, and every fact below comes from it.

Extract and hold: the slug, the ops facts (boot command, test command, base commit, test file locations), the max-iterations budget, the checklist item IDs, and the `## /goal condition` string.

The loop directory is the goal file's own directory: `thoughts/shared/loops/<goal-slug>/`.

### 2. Goal-condition check

An active `/goal` is **not programmatically detectable**. No hook field, environment variable, status-line field, CLI flag, or `stream-json` event reports it, and there is no state file to read. Do not attempt to parse `transcript_path` — that is a version-fragile hack, not a check.

So this check is prompt-level: look at your own session context for a goal directive (the condition arrives as a directive when the user sets it, and each "not yet met" reason comes back as system-reminder guidance).

- **If no goal directive is visible**: print the `## /goal condition` string from the goal file in a fenced block, tell the user to paste it as `/goal <condition>` and then re-run this command, and **stop**. Do not iterate — an iteration without the condition set has nothing to start the next turn, and the loop dies after one step.
- **If a goal directive is visible**: continue.

### 3. Determine the iteration number

Glob `thoughts/shared/loops/<goal-slug>/*-verify.md`, take the highest number, and add 1. Zero-pad to three digits. The first iteration of a loop is `001`.

### 4. Baseline check

Run the **boot command** from the ops facts and note whether it succeeds. Keep the result to one line for the log — do not paste its output into this context.

A red baseline does **not** skip the iteration: a project that will not boot is a gap the loop should close like any other, and the verifier will report it as `cannot-verify` across the affected items.

### 5. Dispatch the verifier

Use the **loop-verifier** agent (foreground), passing exactly:

- the goal file path,
- the output path `thoughts/shared/loops/<goal-slug>/NNN-verify.md`,
- the base commit from the ops facts,
- the iteration number.

Pass nothing else — no previous report, no plan, no summary of what happened before. Its blindness to those is what makes its verdicts worth having.

**Wait for the agent to complete before continuing.**

**MANDATORY OUTPUT**: `thoughts/shared/loops/<goal-slug>/NNN-verify.md` MUST exist on disk after this step. If it does not, the step failed — report that plainly to the user and stop. Never proceed to planning on a missing report, and never reconstruct one yourself.

### 6. Surface the verdict into the transcript

Restate the verifier's one-line result as **plain assistant text**, in wording that mirrors the goal condition. For example:

> The tle verifier reported 4/7 checklist items in `<goal-slug>` passing.

This is not a formality. The `/goal` evaluator does not call tools and judges only what has been surfaced in the conversation, so this sentence is what it reads. Keep it to the counts and the slug — no report body, no evidence, no diff.

### 7. Convergence check

Read the `<!-- verdict-vector -->` block from the new report. **If every item is `pass`**:

1. Announce convergence in plain text mirroring the condition — e.g. "The tle verifier reported every checklist item in `<goal-slug>` passing."
2. Append the final `loop-log.md` row (Step 11 format).
3. **Stop.** Do not plan, do not implement, do not dispatch anything further.

Otherwise continue.

### 8. Stall check

Read the `<!-- verdict-vector -->` block from the new report and from the previous iteration's report (`(NNN-1)-verify.md`). If there is no previous report, there is no stall — skip to Step 9.

Compare the two vectors item by item. **If they are identical**, the previous iteration moved nothing, and you escalate one rung. Determine the current rung by reading the escalation notes recorded in `loop-log.md` — not from conversation memory:

1. **Rung 1** — dispatch the spec+planner (Step 9) with an added instruction: the previous step moved no item, so it must choose a **different** item or a **materially smaller** slice of the same one.
2. **Rung 2** — dispatch the spec+planner with an added instruction to attack the same item by a **different strategy**, naming the approach that has not worked.
3. **Rung 3** — **stop the loop.** Report to the user: the stalled vector, the rungs already tried, and the path to the latest verify report. Append the log row recording the stop. Do not dispatch anything further.

Record the rung you used in this iteration's log row, so the next invocation can read it back.

### 9. Dispatch the spec+planner

Use the **loop-spec-planner** agent (foreground), passing exactly:

- the goal file path,
- the new verify report path (`NNN-verify.md`),
- the output path `thoughts/shared/loops/<goal-slug>/NNN-plan.md`,
- the escalation instruction, if Step 8 produced one.

**Wait for the agent to complete before continuing.**

**MANDATORY OUTPUT**: `thoughts/shared/loops/<goal-slug>/NNN-plan.md` MUST exist on disk after this step. If it does not, the step failed — report and stop.

### 10. Dispatch the implementer

Use the **loop-implementer** agent (foreground), passing exactly:

- the plan file path (`NNN-plan.md`),
- the goal file path.

**Wait for the agent to complete before continuing.** Keep only its one-line return — a commit sha and what changed, or `no commit — <blocker>`.

### 11. Append the loop-log row

Append one row to `thoughts/shared/loops/<goal-slug>/loop-log.md`. If the file does not exist yet, create it with the title and the table header first:

```markdown
# Loop log — <goal-slug>

| # | When | Verdict | Commit | Note |
|---|------|---------|--------|------|
```

Then one row per iteration:

```markdown
| NNN | YYYY-MM-DDTHH:MM:SSZ | X/Y pass | <commit sha or "none"> | <one-line gap or escalation note> |
```

Terse, one line, never prose journaling — this file is read in full by every later invocation, so it must not grow into a narrative. Get the timestamp from `date -u +"%Y-%m-%dT%H:%M:%SZ"`.

### 12. Budget check

If the iteration number has reached the goal file's **max iterations**, say so plainly in the transcript — e.g. "Iteration NNN reached the loop's max-iterations budget of N; stopping." — and stop. Report the latest verify report path so the user can see where it got to.

### 13. End the turn

Stop here. Do **not** begin another iteration, do not "just check one more thing", and do not ask the user whether to continue. Ending the turn is the mechanism: `/goal`'s evaluator runs now, and if the condition is not yet met it starts the next turn, which re-invokes this command.

## Important Rules

1. **One iteration per invocation.** This is the engine, not a style preference. Invariant 1 above overrides any impulse to keep going.
2. **You orchestrate; the agents work.** Never verify an item yourself, never write the plan yourself, never implement or commit yourself, and never "quickly fix" something an agent reported. Doing any of it pulls the content into your context that the file-only handoff exists to keep out.
3. **Foreground dispatch only.** Never dispatch an agent in the background and never run two at once.
4. **Never edit the goal file** — not its checklist, not its item IDs, not its ops facts, not even a typo. Goal files are immutable once a loop starts.
5. **Never edit a verify report or a plan file.** You read the verdict vector; you do not adjust it.
6. **Paths and one-line statuses only.** If you are about to paste a report body, a diff, or test output into your response, you have broken invariant 2.
7. **A missing MANDATORY OUTPUT stops the iteration.** Never fabricate, reconstruct, or work around a missing artifact.
