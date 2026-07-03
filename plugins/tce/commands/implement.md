---
description: Execute an approved implementation plan phase by phase, with verification and status tracking. Step 4 of the tce workflow.
argument-hint: "[ticket-id | plan path]"
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

## Status File Tracking

**Every implementation session is tracked in a status file** that lives alongside the plan file. The status file has the same base name as the plan but ends in `.status.md`.

**Example:**
- Plan: `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
- Status: `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.status.md`

### Status File Format

```markdown
# Implementation Status: [PREFIX]-XXXX — Short Title

## Phase 1: Phase Title
- **Status**: ✅ Complete | ⚠️ Partial | ❌ Blocked
- **Started**: YYYY-MM-DD HH:MM
- **Completed**: YYYY-MM-DD HH:MM

### Steps Performed
1. Description of what was done
2. Another step

### Issues Encountered
- Issue description → Resolution applied

### Verification
- ✅ Backend tests pass
- ✅ Frontend typecheck passes

### Commit
- `abc1234` <commit subject per the project's commit convention>

---

## Phase 2: Phase Title
...
```

### Status File Rules

1. **Check for existing status file** before starting any implementation work.
2. **If the status file exists and all phases are marked ✅ Complete**: Stop and tell the user that the plan is already fully implemented. List what was done.
3. **If the status file exists with incomplete phases**: Print a summary showing which phases are done and which remain, then continue from the first incomplete phase.
4. **If no status file exists**: Create one when starting the first phase.
5. **Write to the status file after every phase** — record what was done, any issues encountered, how they were resolved, verification results, and the commit hash.
6. **Write to the status file when encountering blockers** — record the issue even if you can't resolve it, so the next session knows what happened.

### Writing Status Updates

After completing (or attempting) each phase, update the status file using the Edit or Write tool. Include:
- What steps were performed (concise but specific — mention files changed, tests added)
- Any issues encountered and how they were mitigated
- Verification results (which test suites ran, pass/fail)
- The commit hash for the phase's commit (see "Committing Each Phase")
- The phase status (✅ Complete, ⚠️ Partial if not everything in the phase was done, ❌ Blocked if you hit a blocker)

## Getting Started

When given a plan path or ticket number:

- Read the plan, research, and ticket documents (see above)
- **Check for a status file** next to the plan (same base name, `.status.md` extension) — if one exists, read it fully
- **If status file shows all phases complete**: Stop and inform the user. List the completed phases.
- **If status file shows partial progress**: Print an overview of completed vs remaining phases, then continue from where it left off.
- **If no status file exists**: Proceed with fresh implementation.
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
- Check off completed items in the plan file itself using Edit
- **Update the status file** with the phase results (see "Status File Tracking" above)
- **Commit the verified work** (see "Committing Each Phase" below)

Don't let verification interrupt your flow - batch it at natural stopping points. A verified phase *is* a natural stopping point — commit it before moving on.

## Committing Each Phase

Commit your work in **logical groups as you go** — do not leave a multi-phase implementation as one uncommitted (or single-commit) working tree. The default unit is one commit per verified phase; split finer when a phase contains independent units of work that each stand on their own.

For each commit, use the `/tce:commit` workflow:

- Stage the files changed in this group (plus the ticket file if its status changed — see "Ticket Status Transitions" below).
- Since these are **code commits**, `/tce:commit` runs the project's full pre-commit checklist (the test/typecheck/lint commands from `profile.md`) and only commits once they pass — so a phase is committed only when its checks are green. Fix failures before committing; never commit a known-broken state.
- `/tce:commit` formats the message per the project's commit convention (from `profile.md`) — e.g. for Conventional Commits, `feat([PREFIX]-XXXX): <what the phase did>`.
- Record the resulting commit hash in the status file's `### Commit` slot for the phase.

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

## Ticket Status Transitions

The "Status / completion" section of `.claude/tce/tickets.md` defines whether tce
transitions ticket status itself or only reminds the user. Follow it exactly:

- **When starting the first phase**: if the policy says tce updates status, mark
  the ticket as in progress via the documented mechanism (for tmt: edit the
  `**Status:**` line to `In Progress` and include the ticket file in the next
  commit).
- **When ALL phases are complete and verified**: if the policy says tce updates
  status, mark the ticket done/closed via the documented mechanism (for tmt: set
  `**Status:** Done`; for e.g. GitHub: `gh issue close <n>` if configured).
- **If the policy says "do not transition"**: never touch the ticket's status —
  instead, remind the user at the end which transition is now due.

## If You Get Stuck

When something isn't working as expected:

- First, make sure you've read and understood all the relevant code
- Consider if the codebase has evolved since the plan was written
- Present the mismatch clearly and ask for guidance

Use sub-tasks sparingly - mainly for targeted debugging or exploring unfamiliar territory.

## Resuming Work

**The status file is the authoritative record of implementation progress.** When resuming:

1. Read the status file to understand what has been completed
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

3. If a phase is marked ⚠️ Partial, read the status details to understand what was done and what remains
4. If a phase is marked ❌ Blocked, read the blocker description and assess whether it's still relevant
5. Trust completed phases — only re-verify if something seems off
6. Pick up from the first incomplete phase

Remember: You're implementing a solution, not just checking boxes. Keep the end goal in mind and maintain forward momentum.
