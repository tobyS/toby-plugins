---
description: End-to-end workflow for an existing ticket (research → clarify → plan → implement), autonomous except for a single open-questions checkpoint.
argument-hint: "[ticket-id]"
---

# Work on Ticket

End-to-end workflow: research → clarify questions → plan → implement. Runs autonomously with a single interaction checkpoint for open questions/decisions.

## Project context

This command ships in the **tce** workflow plugin and is stack-agnostic. It is a
**composite command** that chains the single-step workflow commands
(`/research_codebase` → `/create_plan` → `/implement_plan`, plus `/commit`) into one
session.

- `[PREFIX]` stands for the project's configured ticket prefix (in `.claude/tce/config`); the ticket scripts resolve it automatically — you never hardcode it.
- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack, conventions, and the exact test/lint/typecheck commands to run during verification and commits. If it's missing, suggest the user run `/tce:init`.
- When these instructions tell you to invoke another workflow command **via the Skill tool**, use its namespaced name (e.g., `tce:create_plan`). In prose, sibling commands are referenced by their bare name (e.g., `/research_codebase`).

**This command must stay in lock-step with the single-step commands it chains.** Phases 1, 3, and 4 mirror `/research_codebase`, `/create_plan`, and `/implement_plan` respectively. The quality and outputs of each phase must be identical to running those commands manually — the only difference is the removed intermediate review steps.

**Usage:** `/work [PREFIX]-XXXX` (ticket number required)

---

## Overview

This command chains the full development workflow (research, plan, implement) into a single session with minimal user interaction. The quality of research, planning, and implementation is identical to running `/research_codebase`, `/create_plan`, and `/implement_plan` separately — the difference is that intermediate review steps are removed.

**Interaction model:**

- Research and planning run autonomously (no user review)
- The ONLY interaction point is a question checkpoint between research and planning, where Claude asks the user to resolve open questions/decisions
- If there are no open questions, planning starts immediately after research
- Implementation starts immediately after planning

---

## Phase 1: Research (Autonomous)

Execute the full research workflow as defined in `/research_codebase`, with these modifications:

### 1a. Start immediately

Do NOT print "I'm ready to research" and wait. Instead:

1. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-XXXX` to find all ticket documents
2. Read the ticket file FULLY
3. If this is a sub-ticket (letter suffix, e.g. `[PREFIX]-0100a`), also find and read the parent epic documents (run the script with the parent number)
4. Begin research immediately

### 1b. Conduct research exactly as `/research_codebase` specifies

Follow all research steps from `/research_codebase`:

- Decompose the research question from the ticket
- Spawn parallel sub-agents (codebase-locator, codebase-analyzer, codebase-pattern-finder, thoughts-locator, thoughts-analyzer, web-search-researcher)
- Wait for ALL sub-agents to complete
- Synthesize findings
- Gather git metadata
- Write the research document to `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
- Generate GitHub permalinks if applicable
- Follow ALL quality guidelines from `/research_codebase` (impact analysis, code references, etc.)

**The research document must be just as thorough as if `/research_codebase` were run manually.**

### 1c. Commit research document

Use the `/commit` command to commit the research document. Since this is a docs-only commit, skip tests/typechecks.

**Do NOT present the research to the user. Do NOT ask for follow-up questions about the research.**

---

## Phase 2: Question Checkpoint (Interactive)

This is the ONLY interaction point before implementation begins.

### 2a. Identify all open questions

Review BOTH the ticket AND the research document for:

1. Questions explicitly marked in research ("Open Questions", "To Be Decided")
2. Questions in the ticket deferred to planning
3. Design decisions where research found multiple valid approaches
4. Ambiguities that research couldn't resolve through code analysis
5. Any decisions that require human judgment

### 2b. Design exploration check

If the ticket involves a non-trivial UX change (new UI patterns, significant flow changes, layout redesigns — NOT bug fixes, text changes, or simple CRUD following established patterns):

1. Check if a design decision already exists:

   ```bash
   grep -rl "[PREFIX]-XXXX" thoughts/shared/mockups/*/DECISION.md 2>/dev/null
   ```

2. If a DECISION.md exists: incorporate it and continue
3. If no design decision exists: add this to the questions for the user

### 2c. Ask questions or proceed

**If there ARE open questions:**

Use `AskUserQuestion` to present them. Structure the interaction as:

```
I've completed research for [PREFIX]-XXXX and committed the research document.

**Context summary:** [2-3 sentences summarizing what the ticket is about and key findings]

**Questions that need your input before I create the plan:**

1. [Concrete question with options if applicable]
   - Context: [Why this matters, what the research found]

2. [Another question]
   - Context: [Brief relevant context]

[If UX ticket without design decision:]
3. This ticket involves a non-trivial UX change but has no design decision yet.
   Should I proceed without `/design_explore`, or do you want to run that first?
```

Wait for the user's answers. If the user's answers raise follow-up questions, ask those too. Continue until all questions are resolved.

**If there are NO open questions:**

Print a brief status line and proceed directly to Phase 3:

```
Research complete and committed. No open questions — proceeding to planning.
```

---

## Phase 3: Planning (Autonomous)

Create the implementation plan using the ticket, research document, and user's answers to questions.

### 3a. Create the plan

Follow the plan creation process from `/create_plan` Step 3 (Plan Structure Development) and Step 4 (Detailed Plan Writing):

- Use the research document as the codebase context (DO NOT re-read source files it already covers)
- Incorporate all answers from the question checkpoint
- Write the plan to `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
- Use the full plan template (overview, current state, desired end state, phases, success criteria, testing strategy, etc.)
- Include both automated and manual verification in success criteria. Derive the automated checks from the test/lint/typecheck commands in `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`.

**The plan must be just as detailed as if `/create_plan` were run manually.**

**Key difference from `/create_plan`:** Do NOT present the plan outline for user approval. Do NOT ask for feedback on plan structure. Write the complete plan directly.

### 3b. Commit the plan

Use the `/commit` command to commit the plan document. Since this is a docs-only commit, skip tests/typechecks.

### 3c. Announce and proceed

Print a brief status line:

```
Plan created and committed. Starting implementation.
```

---

## Phase 4: Implementation

Execute the implementation plan exactly as `/implement_plan` specifies.

### 4a. Set up implementation

1. Read the plan document (you already have it in context, but verify)
2. Check for existing status file (same base name, `.status.md` extension)
3. If status file exists with completed phases, resume from where it left off
4. If no status file, create one when starting the first phase
5. Create a todo list to track progress

### 4b. Implement phase by phase

Follow ALL `/implement_plan` guidelines:

- Implement each phase fully before moving to the next
- Run success criteria checks after each phase
- Fix any issues before proceeding
- Commit after each verified phase (using `/commit` with full pre-commit checklist for code commits)
- Update the status file after every phase
- Update checkboxes in the plan file

### 4c. Handle mismatches

If the plan doesn't match reality:

- STOP and think deeply about why
- Present the issue clearly to the user
- Wait for guidance before proceeding

### 4d. Final verification

Before marking the ticket as done:

- Run ALL test suites that could be affected by the changes, using the commands from `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` (when in doubt, run everything)
- Verify all success criteria are met
- Update ticket state

---

## Important Rules

1. **Research and plan quality are non-negotiable.** The automation removes user review, not thoroughness.
2. **The question checkpoint is the safety valve.** Never assume answers to questions that require human judgment.
3. **Commits happen at the same points** as in the manual workflow (after research, after plan, after each implementation phase), all via the `/commit` workflow.
4. **If something goes seriously wrong** (research finds the ticket is fundamentally flawed, plan reveals the approach won't work), stop and talk to the user instead of plowing ahead.
5. **The existing commands still work independently.** This command doesn't modify `/research_codebase`, `/create_plan`, or `/implement_plan`.
</content>
