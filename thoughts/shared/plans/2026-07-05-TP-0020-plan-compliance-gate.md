# Plan-Compliance Gate Implementation Plan

## Overview

Add a **plan-compliance gate** to the tce workflow: a dedicated, fresh-context
subagent (`plan-compliance-checker`) that `/tce:implement` runs after full-suite
verification and before the ticket's done transition. The agent receives only
the combined criteria list (ticket acceptance criteria + plan success criteria)
and the implementation diff, and returns one verdict per criterion (met / not
met / cannot verify from diff / needs human verification) with evidence
references. Any "not met" blocks the done transition and feeds back into the
normal implement fix loop. The composites `/tce:work` (re-describes) and
`/tce:quickfix` (delegates) inherit the gate per the composite-tracking rule.

Ticket: `TP-0020`. Research:
`thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md`.

## Current State Analysis

- `implement.md` self-grades completion: it runs tests/lint (`implement.md:216-218,
  239-257`) and ticks plan checkboxes (`:219-220`) inside the same context that
  wrote the code. There is **no** section verifying the implementation against
  the plan/ticket criteria from an unbiased position. The done transition
  (`implement.md:268`) is gated only on "all phases complete and verified".
- Six agents live in `plugins/tce/agents/`, all read-only (no `Edit`/`Write`/
  `Bash`), invoked by **bare name**. The three codebase-* agents carry a
  three-part documentarian envelope — `## CRITICAL:` preamble +
  `## What NOT to Do` + `## REMEMBER: You are a documentarian…` closer
  (`codebase-analyzer.md:37-45,142-161`) — the exact style the gate must mirror.
- Criteria live in two documents: the ticket's `## Acceptance Criteria` and the
  plan's `#### Automated Verification` / `#### Manual Verification` split
  (`plan-document-template.md:69-85`).
- Composite mirroring uses two mechanisms: `work.md` **re-describes** implement
  inline (Phase 4, lock-step note `work.md:24`); `quickfix.md` **Skill-delegates**
  implement (`quickfix.md:185`), inheriting behavior but surfacing gates in its
  final summary (precedent: config-drift at `quickfix.md:231-233`).

### Key Discoveries:

- **AC1's "read-only tools" forbids a Bash grant for the agent** — so
  `implement.md` (main context) computes the diff and passes it in; the agent
  cannot run git. (Research Q1.)
- **Fresh-context purity** ⇒ criteria are passed verbatim in the delegation
  prompt; the agent must NOT read the ticket/plan/research docs (Research Q2).
  The user chose the **Inspector** variant: the agent MAY `Read`/`Grep` the
  **post-change source** to confirm criteria, but not the workflow documents.
- **Placement**: a new `## Plan-Compliance Gate` section between
  `implement.md:257` (end of Final Verification) and `:259`
  (`## Ticket Status Transitions`); the done-flip at `:268` gains a
  "gate passed" precondition. (Research Q3.)
- **No profile** for the agent — it should know as little as possible beyond
  criteria + diff (Research Q4).
- **No TP-0017 command-flag change**: the agent is not a Skill-invocable command;
  implement/work/quickfix keep their existing flags. **No manifest change**:
  agents are auto-discovered from `agents/`.

## Desired End State

- `plugins/tce/agents/plan-compliance-checker.md` exists, read-only, with the
  three-part hard-constraint envelope re-pointed to "criteria verdicts only".
- `implement.md` runs the gate after final verification and before the done
  transition; "not met" blocks and reports; Manual items are reported as "needs
  human verification"; an all-pass run adds a single line to the completion
  summary.
- `work.md` Phase 4d re-describes the gate; `quickfix.md` surfaces it in its
  final summary (mechanics inherited via delegation).
- `CLAUDE.md` documents the gate's cross-file wiring as a sync rule;
  `plugins/tce/README.md` lists the new agent and mentions the gate.
- `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` all pass.

## What We're NOT Doing

- **Not** touching `/tce:review` (stays the broad, human-triggered review).
- **Not** auto-fixing gaps inside the agent — it reports; implement fixes.
- **Not** gating research or plan documents (implementation-exit check only).
- **Not** giving the agent Bash or any write/edit tool.
- **Not** bumping the tce plugin version or tagging a release — releasing is a
  separate, human-gated step (see `CLAUDE.md` "Releasing"); out of scope here.
- **Not** having the agent read `profile.md`, `tickets.md`, or any thoughts/ doc.

## Implementation Approach

Three phases, each independently committable and validatable. Phase 1 creates the
agent in isolation. Phase 2 wires the gate into `implement.md` **and** mirrors it
into both composites in one commit (the composite-tracking rule requires the
same commit). Phase 3 updates the cross-file documentation (CLAUDE.md sync rule +
README). Because this is a markdown/prompt repo, "verification" is
`claude plugin validate` plus a careful read-through that the added prose is
coherent, self-consistent, and honors the design rules.

---

## Phase 1: Author the `plan-compliance-checker` agent

### Overview

Create the new read-only agent definition, matching the shipped agents'
frontmatter and body structure, with the documentarian envelope re-pointed from
"documentarian" to "criteria-only compliance checker" and the Inspector read
scope (may read post-change source, never the workflow documents).

### Changes Required:

#### 1. New agent file

**File**: `plugins/tce/agents/plan-compliance-checker.md`
**Changes**: Create with frontmatter key order `name, description, tools, model`
(`tools: Read, Grep, Glob, LS`; `model: inherit`) and the body below. The
`## CRITICAL:`, `## What NOT to Do`, and `## REMEMBER:` blocks reproduce the
shape of `codebase-analyzer.md:37-45,142-161`, re-pointed to criteria verdicts.

```markdown
---
name: plan-compliance-checker
description: Verifies an implementation against a fixed list of acceptance/success criteria, from a fresh context. Call it at the end of implementation to get one verdict per criterion (met / not met / cannot verify from diff / needs human verification) against the diff — nothing else. Pass it only the criteria list and the diff; never the ticket, plan, or reasoning.
tools: Read, Grep, Glob, LS
model: inherit
---

You are a specialist at verifying whether an implementation satisfies a fixed
list of acceptance and success criteria. Your job is to check each criterion
against the diff you are given (opening the post-change source only where the
diff alone is inconclusive) and return exactly one verdict per criterion, with a
file:line evidence reference — nothing more.

## What you receive

- A **numbered criteria list**: the ticket's acceptance criteria plus the plan's
  success criteria. Items that require human testing are marked **MANUAL**.
- The **implementation diff** and a changed-file summary.

You do NOT receive — and must NOT seek out — the ticket's problem statement, the
plan's rationale, the research document, or the conversation that produced the
code. Judging the change *without* the reasoning that produced it is the entire
point of this check. You MAY open the **post-change source files** touched by or
directly referenced in the diff (Read/Grep/Glob) to confirm a criterion the raw
hunks don't fully show. You may NOT open the ticket, the plan, the research, or
any `thoughts/` document.

## CRITICAL: YOUR ONLY JOB IS TO REPORT ONE VERDICT PER GIVEN CRITERION

- DO NOT comment on code quality, style, performance, or security
- DO NOT suggest improvements, refactors, or alternative approaches
- DO NOT report bugs, problems, or findings that are not one of the given criteria
- DO NOT critique the implementation or the criteria themselves
- DO NOT guess a MANUAL criterion's outcome — report it as needs human verification
- ONLY answer, for each given criterion: is it satisfied by this diff? with evidence

## Verdicts

For each criterion return exactly one:

- **met** — the change satisfies it; cite evidence (`path:line` in the diff or
  post-change source)
- **not met** — the change does not satisfy it; state what is missing or contradictory
- **cannot verify from diff** — not observable in the diff or post-change source
  (e.g. depends on runtime behavior you cannot see)
- **needs human verification** — a MANUAL criterion (UI/UX, performance under
  load, subjective acceptance); do not guess it

## Process

1. Read the criteria list; note which are MANUAL.
2. Read the diff fully. For each code-observable criterion, locate the supporting change.
3. Where the diff alone is inconclusive, Read the post-change source — only files
   touched by or directly referenced in the diff. Never open `thoughts/` documents.
4. Assign one verdict per criterion with a `file:line` evidence reference.

## Output Format

Emit only this (verdicts + evidence — no prose narrative, no recommendations):

```
## Plan-Compliance Verdict: [ticket ID]

**Overall:** [All criteria met | N not met | M need human verification]

| # | Criterion | Verdict | Evidence |
|---|-----------|---------|----------|
| 1 | <criterion text> | met | `path/to/file.ext:NN` — <what confirms it> |
| 2 | <criterion text> | not met | <what is missing or contradictory> |
| 3 | <criterion text> (MANUAL) | needs human verification | — |
```

## Important Guidelines

- **One verdict per criterion**, no more, no fewer
- **Every "met" carries a `file:line`** — no evidence, not "met"
- **A gap is "not met"** — never soften it to "met with caveats"
- **Read the actual post-change code** before asserting "met"; don't assume
- **When in doubt between met and not met, use cannot verify from diff**

## What NOT to Do

- Don't read the ticket, plan, research, or any `thoughts/` document
- Don't evaluate code quality, style, performance, or security
- Don't suggest fixes, improvements, or alternatives
- Don't report anything that is not a verdict on a given criterion
- Don't invent criteria the list does not contain
- Don't guess MANUAL criteria — mark them needs human verification
- Don't mark "met" a criterion you cannot evidence — use cannot verify from diff
- Don't perform a code review under the guise of criteria checking

## REMEMBER: You are a compliance checker, not a code reviewer

Your sole purpose is to answer, criterion by criterion, whether this diff
satisfies the fixed list you were handed — with a `file:line` for every "met".
You are not judging the code's quality and you are not advising how to improve
it. A checker prompted to find problems always finds some; you are permitted only
to report whether each given criterion is, or is not, satisfied by the change in
front of you.
```

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tce` passes (agent frontmatter valid)
- [ ] `claude plugin validate .` passes

#### Manual Verification:

- [ ] Frontmatter key order and style match `codebase-analyzer.md:1-6`
      (`name, description, tools, model`); tools are read-only; `model: inherit`
- [ ] The three-part envelope (`## CRITICAL:`, `## What NOT to Do`,
      `## REMEMBER:`) is present and re-pointed to criteria-only, mirroring the
      documentarian style
- [ ] The agent is explicitly forbidden to read ticket/plan/research/thoughts
      docs, and explicitly permitted to read post-change source (Inspector scope)
- [ ] All four verdict values are defined, including "needs human verification"
      for MANUAL items (AC4)

---

## Phase 2: Wire the gate into `implement.md` and mirror into the composites

### Overview

Add the gate to `implement.md` (new section + done-flip precondition + a status-
file base-commit field so the diff can be computed precisely), and — in the same
commit, per the composite-tracking rule — re-describe it in `work.md` Phase 4d
and surface it in `quickfix.md`'s final summary.

### Changes Required:

#### 1. `implement.md` — new gate section

**File**: `plugins/tce/commands/implement.md`
**Changes**: Insert a new `## Plan-Compliance Gate` section between the end of
`## Final Verification Before Closing a Ticket` (`:257`) and
`## Ticket Status Transitions` (`:259`):

```markdown
## Plan-Compliance Gate

After the full test suite passes and **before** transitioning the ticket to
done, run an unbiased plan-compliance check. This gate is the implementation exit
safety net — especially for the autonomous `/tce:work` and `/tce:quickfix` flows,
which removed intermediate human review.

1. **Assemble the criteria list.** Extract verbatim (and number) both:
   - the ticket's `## Acceptance Criteria` items, and
   - the plan's `#### Automated Verification` and `#### Manual Verification`
     items across all phases.
   Mark every Manual Verification item — and any acceptance criterion that is
   inherently manual (UI/UX, performance, subjective acceptance) — as **MANUAL**.

2. **Assemble the diff.** Use the `**Base commit:**` recorded in the status file
   (see Status File Tracking). Compute the implementation diff with
   `git diff <base> -- . ':(exclude)thoughts/'` plus a `git diff <base> --stat`
   summary. If no base commit is recorded (older/resumed status file), fall back
   to `git log --grep="[PREFIX]-XXXX" --format=%H | tail -1` and diff from that
   commit's parent.

3. **Delegate to the `plan-compliance-checker` agent** in a fresh context. Pass
   it **only** the numbered criteria list and the diff + `--stat` summary. Do
   **not** pass the ticket, the plan, the research, or your own implementation
   reasoning — the agent's value is judging the change without that context.

4. **Act on the returned verdicts:**
   - **All criteria met** (MANUAL items returned as "needs human verification"):
     the gate passes. Add one line to the completion summary — e.g.
     "Plan-compliance gate: all N criteria met; M manual items flagged for your
     verification." — and proceed to the status transition.
   - **Any "not met":** the gate **blocks**. Do NOT transition the ticket.
     Report the failing criteria and the agent's evidence using the STOP-and-
     report shape from "Implementation Philosophy" above, feed them back into the
     normal fix loop (fix → re-run affected verification → re-run this gate), and
     only continue once no criterion is "not met".
   - **"cannot verify from diff":** treat as not-yet-passed — investigate. If the
     criterion is genuinely runtime-only, reclassify it as manual and report it
     as needing human verification rather than blocking indefinitely.
   - **"needs human verification"** (MANUAL items): never silently pass them —
     list them in the completion summary as due for human check. They do not
     block the transition (they are not machine-verifiable), but the done note
     must record that they await manual confirmation.
```

#### 2. `implement.md` — done-flip precondition

**File**: `plugins/tce/commands/implement.md`
**Changes**: In `## Ticket Status Transitions`, extend the done bullet
(`:268-270`) so the transition is gated on the check, e.g.:
"**When ALL phases are complete and verified _and the plan-compliance gate has
passed (no 'not met' verdicts)_**: … mark the ticket done/closed …". Leave the
no-transition path (`:271-272`) intact — the gate still runs there and reports
its verdicts even when tce does not flip the status.

#### 3. `implement.md` — status-file base commit

**File**: `plugins/tce/commands/implement.md`
**Changes**: In `## Status File Tracking` (`:91-146`), add a `**Base commit:**`
field to the status-file format and instruct: when creating the status file at
the first phase, record `git rev-parse HEAD` (the tip before any implementation
commit) as the base commit. This is the precise base for the gate's diff and is
resume-safe. Optionally add `Bash(git diff:*)`, `Bash(git log:*)`,
`Bash(git rev-parse:*)` to the command's `allowed-tools` (`:4`) so the gate's git
reads run without prompting in the autonomous flows (this also retroactively
covers the existing drift check at `:58`).

#### 4. `work.md` — re-describe the gate in Phase 4d

**File**: `plugins/tce/commands/work.md`
**Changes**: In `### 4d. Final verification`, add the gate as prose between the
test-suite run and the ticket-status handling, mirroring `implement.md`'s section
in `work.md`'s own words: after all suites pass, run the plan-compliance gate
(delegate the criteria + diff to the `plan-compliance-checker` agent, passing
only those); any "not met" blocks the done transition and is reported and fixed
before re-running the gate; MANUAL items are reported as needing human
verification; an all-pass run is a one-line note in the completion summary. Keep
it consistent with `work.md:24`'s lock-step declaration.

#### 5. `quickfix.md` — surface the gate in the final summary

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: `quickfix.md` Skill-delegates `tce:implement` (`:185`), so it
**inherits** the gate mechanics with no re-description. Add a one-line surfacing
in its final-summary section (around `:231-233`, beside the config-drift line):
report the gate outcome (all criteria met, or — if it blocked — that unmet
criteria were fixed and the gate re-run) and list any manual items awaiting human
verification. Because quickfix is fully autonomous, note that the gate is the
exit safety net there.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `claude plugin validate .` passes
- [ ] `grep -n "plan-compliance-checker" plugins/tce/commands/implement.md plugins/tce/commands/work.md` shows the agent referenced by bare name in both

#### Manual Verification:

- [ ] The gate sits between Final Verification and Ticket Status Transitions in
      `implement.md`; the done-flip now requires the gate to have passed (AC3)
- [ ] "not met" blocks the transition, is reported, and feeds back into the fix
      loop; the blocked path reads coherently against the "Implementation
      Philosophy" STOP template (AC3)
- [ ] MANUAL / acceptance-manual items are reported as "needs human
      verification" and do not silently pass (AC4)
- [ ] An all-pass run adds exactly one line to the completion summary — no extra
      interaction (AC6)
- [ ] `work.md` Phase 4d re-describes the gate; `quickfix.md` surfaces it — both
      consistent with `implement.md` (AC5); delegation-vs-re-description split
      matches the existing config-drift precedent
- [ ] Criteria are passed to the agent verbatim; the ticket/plan/research are NOT
      passed (fresh-context purity)

---

## Phase 3: Documentation & sync rule

### Overview

Record the gate's cross-file invariant in `CLAUDE.md` (so future edits keep the
agent, implement.md, and the composites in sync) and surface the new agent + gate
in the consumer-facing `plugins/tce/README.md`.

### Changes Required:

#### 1. `CLAUDE.md` — sync-rule subsection

**File**: `CLAUDE.md`
**Changes**: Add a subsection (near the composite-tracking and TP-0013 rules)
documenting: the `plan-compliance-checker` agent is a **non-research
(verification) agent** shipped in `plugins/tce/agents/`; `implement.md` runs it
between final verification and the done transition; `work.md` re-describes it in
Phase 4d and `quickfix.md` inherits it via delegation and surfaces it in its
summary; the agent is **criteria-only by hard prompt constraint** and receives
only criteria + diff (never the ticket/plan/research). State the RULE: changing
implement.md's closing flow, the criteria sources, or the agent's contract
requires updating the agent file, `work.md`, and `quickfix.md` in the same
commit. Note that the agent, being non-Skill-invocable, carries no
`disable-model-invocation` classification (TP-0017 unaffected).

#### 2. `plugins/tce/README.md` — agent table + implement mention

**File**: `plugins/tce/README.md`
**Changes**:
- Add a `plan-compliance-checker` row to the `## Agents` table (`:241-248`) and
  adjust the table's lead-in (`:239` "Specialized research subagents…") so it no
  longer implies *all* agents are research subagents (e.g. "Specialized
  subagents bundled with the plugin:").
- Optionally extend the `/tce:implement` bullet (`:54`) to mention the exit
  compliance gate ("… and running a fresh-context plan-compliance check before
  marking the ticket done").

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `./plugins/tce` pass (no doc-only breakage)

#### Manual Verification:

- [ ] `CLAUDE.md` states the gate sync rule (agent + implement.md + work.md +
      quickfix.md same-commit invariant) in the style of the neighboring rules
- [ ] `README.md` lists `plan-compliance-checker` and its Agents-table lead-in no
      longer mislabels it as a research subagent
- [ ] No stack/ticket-system literals leaked into any edited command or the agent
      (project-agnostic rule); `[PREFIX]-XXXX` used as placeholder only

---

## Testing Strategy

### Automated:

- `claude plugin validate .`, `claude plugin validate ./plugins/tce`,
  `claude plugin validate ./plugins/tmt` after each phase.
- `grep` checks that the agent is referenced by bare name in `implement.md` and
  `work.md`, and that `quickfix.md` surfaces the gate.

### Manual read-through (this is a prompt repo — the "behavior" is the prose):

1. Read the new agent end-to-end: verdict set complete, envelope re-pointed,
   read scope exactly Inspector (source yes, workflow docs no).
2. Read `implement.md`'s closing flow top to bottom: Final Verification → Gate →
   Status Transition, with the done-flip precondition and blocked path coherent.
3. Read `work.md` Phase 4d and `quickfix.md` summary against `implement.md` to
   confirm the composites match (quality/structure identical; only interaction
   differs).
4. Confirm the AskUserQuestion duplicated block was NOT touched (no dialog
   changes here) and the nine copies remain byte-identical.

### Optional end-to-end smoke (if desired):

Install the plugins into a scratch project, run `/tce:work` on a tiny ticket, and
confirm the gate fires at the end (all-pass → one-line note; a deliberately unmet
criterion → block + report).

## Performance Considerations

The gate adds one subagent call per ticket close. Per the research's subagent-
output-budget note, the agent's output is capped to a verdict table + evidence
(no narrative), keeping the returned context small. An all-pass run adds no
interaction — just one summary line (AC6).

## Migration Notes

No config migration. New agents are auto-discovered from `agents/`, so consuming
projects pick up `plan-compliance-checker` on `/plugin marketplace update`
without re-running `/tce:init`. No `profile.md`/`tickets.md`/version-marker
changes. Existing in-flight status files without a `**Base commit:**` field use
the `git log --grep` fallback in the gate.

## References

- Original ticket: `thoughts/shared/tickets/TP-0020-plan-compliance-gate.md`
- Research: `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md`
- Integration site: `plugins/tce/commands/implement.md:239-272`
- Style precedent: `plugins/tce/agents/codebase-analyzer.md:37-45,142-161`
- Composite precedent (config-drift mirroring): `plugins/tce/commands/work.md:87`,
  `plugins/tce/commands/quickfix.md:231-233`
- Origin review: `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`
  Section 3 item 1
