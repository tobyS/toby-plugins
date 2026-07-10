---
description: Execute an approved implementation plan phase by phase, with verification and in-plan progress tracking. Step 4 of the tce workflow.
argument-hint: "[ticket-id | plan path]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*)
---

# Implement Plan

You are tasked with implementing an approved technical plan from `thoughts/shared/plans/`. These plans contain phases with specific changes and success criteria.

## Project context

This command ships in the **tce** workflow plugin and is stack- and ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack, conventions, and the exact test/lint/typecheck commands to run during verification. If it's missing, suggest the user run `/tce:init`.
- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the project's ticket system: how to resolve and fetch the ticket, and the status/completion policy (whether tce transitions ticket status itself). If it's missing, suggest `/tce:init`.
- `[PREFIX]-XXXX` in examples stands for a canonical ticket ID as defined in `tickets.md` (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.

---

## Workflow Context

**This is Step 4 of 4 in our development workflow:**

| Step | Command | Purpose |
|------|---------|---------|
| 1 | ticket creation | Capture business requirements (WHAT & WHY) in the project's ticket system (e.g. `/tce:ticket`) |
| 2 | `/tce:research` | Research codebase, find patterns & libraries |
| 3 | `/tce:plan` | Clarify questions, create detailed implementation plan |
| 3b | `/tce:design_explore` | *(Optional)* Explore and select a visual design for UX changes |
| **→ 4** | **`/tce:implement`** | **Execute implementation using all documents** |

**Your role in this step:** Execute the approved implementation plan phase by phase. You have access to the ticket (requirements), research (codebase context), and plan (detailed steps). Follow the plan while adapting to reality.

**Input:** All three documents from steps 1-3
**Output:** Working implementation with passing tests

---

## Ticket Document Discovery

When a ticket reference is provided:

1. **Resolve the canonical ticket ID** as `.claude/tce/tickets.md` describes.
2. **Fetch the ticket's content** using the read mechanism from `tickets.md` (a file in `thoughts/shared/tickets/` for tmt, a CLI/MCP call for hosted systems).
3. **Find related thoughts documents** with the discovery script:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0001
   ```

   This returns thoughts/ files with the ticket ID in their filename (research, plans, and — for tmt — the ticket itself). Note: This only finds documents that **directly reference the ticket in their filename**. For discovering documents that might be **contextually related** to the ticket's topic, use the `thoughts-locator` and `thoughts-analyzer` agents instead.

## Context Documents: Your Primary Knowledge Source

**The ticket, research, and plan documents were specifically created in steps 1-3 to provide you with all the context you need.** They exist precisely so that you do NOT need to read large numbers of source files before starting implementation.

**Repository state check:** The research document records the commit it was written at (`git_commit` and `branch` in its frontmatter). Compare that against the current HEAD (`git rev-parse HEAD`). If they match, the context documents reflect the current codebase. If they differ, the repository has moved on since research: run `git diff --stat <research_commit>..HEAD` to see which files changed, and spot-verify what the research and plan claim about any of those files before relying on it. Fast path: when the research and plan were produced earlier in this same session (e.g. by `/tce:work` or `/tce:quickfix`) and HEAD has only advanced by this session's own commits, the check is trivially satisfied — skip the spot-verification.

When you receive a ticket number or plan path:

1. Use `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-XXXX` to find the related thoughts documents (research, plan), and fetch the ticket itself via the read mechanism in `tickets.md`

Now read all three documents fully, **in chain order**, before doing anything else — **even if one or more of them already appears earlier in this conversation or was produced by an earlier step in this same session** (e.g. when `/tce:work` or `/tce:quickfix` runs research → plan → implement back-to-back). Re-reading them fresh, in order, anchors your attention on the inputs that matter to implementation; it does not discard the surrounding history:

2. Read the **ticket** — it contains the business requirements and acceptance criteria
3. Read the **research document** — it contains codebase analysis, file contents, code snippets, architectural context, and pattern references
4. Read the **plan** completely — it contains the implementation steps, file paths, code changes, and success criteria

**These three documents ARE your context.** They were carefully assembled by `/tce:research` and `/tce:plan` specifically to give you everything you need — which is exactly why you read them fresh here rather than trusting a fading memory of them from earlier in the session.

### What NOT to re-read

- **DO NOT re-read source files that the research document already analyzed** — the research contains the relevant code snippets, file references, and analysis
- **DO NOT re-read source files referenced in the plan** just to "understand" them — the plan already extracted and documented the relevant parts

### When you MAY read additional source files

You are not forbidden from reading files — but check your context documents first:

- **Before editing a file**: You may read the file you are about to change if you believe the context from the research/plan may not be sufficient to perform the edit correctly (e.g., you need exact indentation, or the research only summarized part of the file)
- **When the plan references a file the research doesn't cover**: Read it if you need to understand it for implementation
- **When you encounter something unexpected**: If the code doesn't match what the plan/research describe, read the actual file to understand the current state

### When you MAY spawn research agents

If during implementation you discover that the context documents are insufficient for a specific aspect — e.g., a dependency you didn't expect, a pattern you need to understand, or a file interaction not covered by the research — you may spawn codebase-locator, codebase-analyzer, or similar agents for **targeted** research. This should be the exception, not the starting point.

**The rule is simple:** Use the context documents as your first source. Only read source files or spawn research agents when you have a specific, immediate need that the documents don't satisfy.

## Implementation Log Tracking

**The plan document is the single record of implementation progress.** Every implementation session logs into the plan file itself: each phase gets a terse `### Implementation log` block appended as the phase's last subsection (after `### Success Criteria:`, before the `---` separator). There is no separate status file.

### Implementation Log Format

```markdown
### Implementation log

- **Status**: ✅ Complete | ⚠️ Partial | ❌ Blocked
- **Base commit**: `<hash>` (first phase's log only — HEAD before any
  implementation commit; the Plan-Compliance Gate diffs from it)
- **Commit**: `abc1234` <commit subject per the project's commit convention>
- **Did**: [1–2 lines — files changed, tests added]
- **Issues**: [none | issue description → resolution applied]
- **Verification**: [compact ✅/❌ list, e.g. "✅ backend tests, ✅ typecheck"]
```

**Keep each block terse** — a few lines (target ≤ 8), never prose journaling. The plan is re-read fully by this command, the composite commands, and every resume, so the log must not bloat the document. (The old status file's timestamps are deliberately gone; git history carries timing.)

When the ticket is closed, one compact closing section is appended at the very end of the plan:

```markdown
## Implementation Closeout

- **Plan-compliance gate**: [PASS — N met, … one-line summary of the gate run]
- **Manual verification**: [confirmed by user YYYY-MM-DD | pending: <items>]
- **Ticket**: [PREFIX]-XXXX → Done
```

### Implementation Log Rules

1. **Read the plan's log state** before starting any implementation work — the `### Implementation log` blocks are part of the plan you just read.
2. **The plan is fully implemented** when every phase's log has `**Status**: ✅ Complete` AND every success-criteria checkbox (Automated **and** Manual) is ticked — the two signals must agree. If so: stop and tell the user that the plan is already fully implemented. List what was done.
3. **If log blocks exist with incomplete phases**: Print a summary showing which phases are done and which remain, then continue from the first incomplete phase.
4. **Legacy status files**: if the plan has no log blocks but a file with the same base name and a `.status.md` extension exists next to it (written by older tce versions), read it to recover progress — including a recorded `**Base commit**` — then log into the plan from this point on. Never create a new `.status.md` and never write to an existing one.
5. **If no log state exists anywhere**: fresh implementation. When starting the first phase, append its log block and record `git rev-parse HEAD` as the `**Base commit**` (the tip before any implementation commit) — the Plan-Compliance Gate diffs from it.
6. **Update the phase's log block after every phase** — the status (✅ Complete, ⚠️ Partial if not everything was done, ❌ Blocked), what was done (concise but specific — files changed, tests added), any issues and how they were resolved, verification results (which suites ran, pass/fail), and the commit hash (see "Committing Each Phase").
7. **Write the log when encountering blockers** — set `**Status**: ❌ Blocked` and record the issue even if you can't resolve it, so the next session knows what happened.
8. **Manual Verification checkboxes are ticked only on explicit human confirmation** — never tick them yourself (see "Plan-Compliance Gate" and "Ticket Status Transitions").

## Getting Started

When given a plan path or ticket number:

- Read the plan, research, and ticket documents (see above)
- **Check the plan's `### Implementation log` blocks** — they are part of the plan you just read; if the plan has none, check for a legacy `.status.md` next to it (same base name — read-only, see Implementation Log Rules)
- **If the log state shows the plan fully implemented** (every phase ✅ Complete and every checkbox ticked): Stop and inform the user. List the completed phases.
- **If the log state shows partial progress**: Print an overview of completed vs remaining phases, then continue from where it left off.
- **If there is no log state**: Proceed with fresh implementation.
- **Read these documents fully** — never use limit/offset parameters
- Think deeply about how the pieces fit together
- **Check for design decisions** (see below)
- Create a todo list to track your progress (starting from the first incomplete phase)
- Start implementing if you understand what needs to be done

If no plan path or ticket number is provided, ask for one.

### Design Exploration Check

**After reading all documents, assess whether the ticket involves a non-trivial UX change** (new UI patterns, significant flow changes, layout redesigns — NOT bug fixes, text changes, or simple CRUD following established patterns).

**If the ticket involves a non-trivial UX change:**

1. Check if the plan references a design decision, or search for one:
   ```bash
   grep -rl "[PREFIX]-XXXX" thoughts/shared/mockups/*/DECISION.md 2>/dev/null
   ```

2. **If a DECISION.md exists**: Read it and use the chosen design to guide implementation.

3. **If no design decision exists and the plan doesn't document a UI approach**, flag this before starting:

   > This ticket involves a non-trivial UX change, but I don't see a design decision (`DECISION.md`) for it, and the plan doesn't detail the UI approach.
   >
   > Would you like to run `/tce:design_explore` first to align on the visual design before implementing? Or should I proceed with the plan as-is?

4. **If the user wants design exploration**: Stop. The user will run `/tce:design_explore`, potentially update the plan, and then return.

5. **If the user wants to proceed**: Continue with implementation using the plan's guidance.

## Implementation Philosophy

Plans are carefully designed, but reality can be messy. Your job is to:

- Follow the plan's intent while adapting to what you find
- Implement each phase fully before moving to the next
- Verify your work makes sense in the broader codebase context
- Update checkboxes in the plan as you complete sections

When things don't match the plan exactly, think about why and communicate clearly. The plan is your guide, but your judgment matters too.

If you encounter a mismatch:

- STOP and think deeply about why the plan can't be followed
- Present the issue clearly:

  ```
  Issue in Phase [N]:
  Expected: [what the plan says]
  Found: [actual situation]
  Why this matters: [explanation]

  How should I proceed?
  ```

## Verification Approach

After implementing a phase:

- Run the success criteria checks for backend and frontend
- Run code style checks and fix any issues
- Fix any issues before proceeding
- Update your progress in both the plan and your todos
- Check off completed Automated Verification items in the plan file using Edit (Manual Verification items only on explicit user confirmation — see Implementation Log Rules)
- **Update the phase's `### Implementation log` block** with the results (see "Implementation Log Tracking" above)
- **Commit the verified work** (see "Committing Each Phase" below)

Don't let verification interrupt your flow - batch it at natural stopping points. A verified phase *is* a natural stopping point — commit it before moving on.

## Committing Each Phase

Commit your work in **logical groups as you go** — do not leave a multi-phase implementation as one uncommitted (or single-commit) working tree. The default unit is one commit per verified phase; split finer when a phase contains independent units of work that each stand on their own.

For each commit, use the `/tce:commit` workflow:

- Stage the files changed in this group (plus the ticket file if its status changed — see "Ticket Status Transitions" below).
- Since these are **code commits**, `/tce:commit` runs the project's full pre-commit checklist (the test/typecheck/lint commands from `profile.md`) and only commits once they pass — so a phase is committed only when its checks are green. Fix failures before committing; never commit a known-broken state.
- `/tce:commit` formats the message per the project's commit convention (from `profile.md`) — e.g. for Conventional Commits, `feat([PREFIX]-XXXX): <what the phase did>`.
- Record the resulting commit hash on the `**Commit**` line of the phase's `### Implementation log` block in the plan.

The "Final Verification Before Closing a Ticket" full-suite run below still applies — it complements these per-phase checks, it does not replace them.

## Final Verification Before Closing a Ticket

**CRITICAL: Before marking a ticket as done, run ALL test suites that could even remotely be affected by the changes.**

Changes often have indirect effects across component boundaries. Running only the "obvious" test suite is not enough.

**Determine which test suites to run based on what was changed:**

| Changed component                         | Test suites to run            |
| ----------------------------------------- | ----------------------------- |
| Shared packages                           | All dependent component tests |
| Backend                                   | Backend tests                 |
| Frontend (components, hooks)              | Frontend unit tests           |
| Frontend (config, build)                  | Frontend unit tests           |
| Cross-cutting (migrations, shared models) | ALL test suites               |

**When in doubt about which tests to run, run everything.**

A ticket is only done when all potentially affected tests pass.

## Plan-Compliance Gate

After the full test suite passes and **before** transitioning the ticket to done,
run an unbiased plan-compliance check. This gate is the implementation exit safety
net — especially for the autonomous `/tce:work` and `/tce:quickfix` flows, which
removed intermediate human review. It is a criteria-coverage check only, not a
code review.

1. **Assemble the criteria list.** Extract verbatim (and number) both:
   - the ticket's acceptance criteria, and
   - the plan's `#### Automated Verification` and `#### Manual Verification` items
     across all phases.
   Mark every Manual Verification item — and any acceptance criterion that is
   inherently manual (UI/UX, performance, subjective acceptance) — as **MANUAL**.

2. **Assemble the diff.** Use the `**Base commit**` recorded in the first
   phase's `### Implementation log` block in the plan. Compute the
   implementation diff with
   `git diff <base> -- . ':(exclude)thoughts/'` plus a `git diff <base> --stat`
   summary. If the plan's log records no base commit, check a legacy
   `.status.md` next to the plan for one; failing that, fall back to
   `git log --grep="[PREFIX]-XXXX" --format=%H | tail -1` and diff from that
   commit's parent.

3. **Delegate to the `plan-compliance-checker` agent** in a fresh context. Pass it
   **only** the numbered criteria list and the diff + `--stat` summary. Do **not**
   pass the ticket, the plan, the research, or your own implementation reasoning —
   the agent's value is judging the change *without* the context that produced it.

4. **Act on the returned verdicts:**
   - **All criteria met** (MANUAL items returned as "needs human verification"):
     the gate passes. Add one line to the completion summary — e.g.
     "Plan-compliance gate: all N criteria met; M manual items flagged for your
     verification." — and proceed to manual confirmation (last bullet below) and
     the status transition. When there are no MANUAL items, this line is the
     only output on a clean pass; add no further interaction.
   - **Any "not met"**: the gate **blocks** — do NOT transition the ticket. Report
     the failing criteria and the agent's evidence using the STOP-and-report shape
     from "Implementation Philosophy" above, feed them back into the normal fix
     loop (fix → re-run the affected verification → re-run this gate), and only
     continue once no criterion is "not met".
   - **"cannot verify from diff"**: treat as not-yet-passed — investigate. If the
     criterion is genuinely runtime-only, reclassify it as manual and report it as
     needing human verification rather than blocking indefinitely.
   - **"needs human verification"** (MANUAL items): never silently pass them — list
     them in the completion summary and ask the user, in plain prose, to verify
     and confirm them. On explicit confirmation, tick the corresponding Manual
     Verification checkboxes in the plan. Until confirmed, the plan is not fully
     implemented (Implementation Log Rules, rule 2) and the done transition
     waits (see "Ticket Status Transitions"); if the user defers, write the
     `## Implementation Closeout` with `Manual verification: pending: <items>`
     and remind them that the done transition is due after confirmation.

## Ticket Status Transitions

The "Status / completion" section of `.claude/tce/tickets.md` defines whether tce
transitions ticket status itself or only reminds the user. Follow it exactly:

- **When starting the first phase**: if the policy says tce updates status, mark
  the ticket as in progress via the documented mechanism (for tmt: edit the
  `**Status:**` line to `In Progress` and include the ticket file in the next
  commit).
- **When ALL phases are complete and verified, the Plan-Compliance Gate has
  passed** (no "not met" verdicts), **and every Manual Verification item is
  user-confirmed (or none exist)**: append the `## Implementation Closeout`
  section to the plan (see "Implementation Log Tracking"), then, if the policy
  says tce updates status, mark the ticket done/closed via the documented
  mechanism (for tmt: set `**Status:** Done`; for e.g. GitHub:
  `gh issue close <n>` if configured).
- **If the policy says "do not transition"**: never touch the ticket's status —
  instead, remind the user at the end which transition is now due.

## If You Get Stuck

When something isn't working as expected:

- First, make sure you've read and understood all the relevant code
- Consider if the codebase has evolved since the plan was written
- Present the mismatch clearly and ask for guidance

Use sub-tasks sparingly - mainly for targeted debugging or exploring unfamiliar territory.

## Resuming Work

**The plan document is the authoritative — and only — record of implementation progress.** When resuming:

1. Read the plan's `### Implementation log` blocks to understand what has been completed (if the plan has none, check for a legacy `.status.md` next to it — read-only, see Implementation Log Rules)
2. Print a summary for the user:

   ```
   Implementation Progress for [PREFIX]-XXXX:
   ✅ Phase 1: Phase Title — completed
   ✅ Phase 2: Phase Title — completed
   ⚠️ Phase 3: Phase Title — partial (describe what's missing)
   ⬚ Phase 4: Phase Title — not started
   ⬚ Phase 5: Phase Title — not started

   Continuing from Phase 3...
   ```

3. If a phase is marked ⚠️ Partial, read its log details to understand what was done and what remains
4. If a phase is marked ❌ Blocked, read the recorded issue and assess whether it's still relevant
5. Trust completed phases — only re-verify if something seems off
6. Pick up from the first incomplete phase

Remember: You're implementing a solution, not just checking boxes. Keep the end goal in mind and maintain forward momentum.
