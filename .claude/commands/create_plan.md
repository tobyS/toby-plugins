# Implementation Plan

You are tasked with creating detailed implementation plans through an interactive, iterative process. You should be skeptical, thorough, and work collaboratively with the user to produce high-quality technical specifications.

---

## Workflow Context

**This is Step 3 of 4 in our development workflow:**

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `/create_ticket` | Capture business requirements (WHAT & WHY) |
| 2 | `/research_codebase` | Research codebase, find patterns & libraries |
| **→ 3** | **`/create_plan`** | **Clarify questions, create detailed implementation plan** |
| 3b | `/design_explore` | *(Optional)* Explore and select a visual design for UX changes |
| 4 | `/implement_plan` | Execute implementation using all documents |

**Your role in this step:** Using the ticket and research document, resolve any remaining open questions with the user and create a detailed, actionable implementation plan with specific phases, code changes, and success criteria.

**Input:** Ticket from step 1 + Research document from step 2
**Output:** Implementation plan in `thoughts/shared/plans/`

---

## Ticket Document Discovery

When a ticket number is provided (e.g., `[PREFIX]-0001`), use the ticket discovery script to find all documents directly related to that ticket:

```bash
./scripts/ticket.sh [PREFIX]-0001
```

This returns files with the ticket number in their filename (tickets, research, plans). Note: This only finds documents that **directly reference the ticket in their filename**. For discovering documents that might be **contextually related** to the ticket's topic, use the `thoughts-locator` and `thoughts-analyzer` agents instead.

### Epic Context for Sub-tickets

**When the ticket is a sub-ticket of an epic** (indicated by a letter suffix, e.g., `[PREFIX]-0100a`), you MUST also read the parent epic's documents for context:

1. **Detect sub-ticket**: If the ticket number ends with a letter (e.g., `[PREFIX]-0100a`), the parent epic is the number without the letter suffix (e.g., `[PREFIX]-0100`).
2. **Find parent epic documents**: Run `./scripts/ticket.sh [PREFIX]-0100` (the parent number) to find the epic ticket, research, and plan.
3. **Read the parent epic's ticket** — it provides the big-picture context for why this sub-ticket exists.
4. **Read the parent epic's research and plan (if they exist)** — these are NOT mandatory to follow, but they provide valuable context:
   - The epic research may contain findings relevant to this sub-ticket
   - The epic plan may outline how this sub-ticket fits into the larger implementation
   - Use them as **inspiration and context**, not as binding instructions
   - The sub-ticket's own research/plan takes precedence over the epic's
   - Decisions already made in the epic plan can inform this plan, but should be re-evaluated in the sub-ticket's specific context

**Example**: When planning `[PREFIX]-0100b`:
```bash
# Find sub-ticket documents
./scripts/ticket.sh [PREFIX]-0100b

# Also find parent epic documents
./scripts/ticket.sh [PREFIX]-0100
```
Then read the parent epic ticket and any research/plan before proceeding with this sub-ticket's planning.

## Research Document Integration

**When a research document is provided alongside the ticket (e.g., `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-*.md`):**

- The research phase has **already been completed** by `/research_codebase`
- Read the research document FULLY - it contains all codebase findings, file references, and analysis
- **DO NOT spawn** codebase-locator, codebase-analyzer, thoughts-locator, or web-search agents
- **DO NOT duplicate research** - trust the research document as the source of truth
- **DO NOT re-read files that are already analyzed in the research document** - use the research as your context
- Only ask clarifying questions about **requirements and design decisions**, not about codebase structure
- Proceed directly to **Step 3 (Plan Structure Development)** after reading the ticket and research

**The research document IS your codebase context:**

- If the research document contains file contents, code snippets, or analysis of specific files → DO NOT read those files again
- If you need information about a file that the research already covers → use the research document's analysis
- Only read a source file directly if the research document doesn't cover it AND you have a specific question about it
- The goal is to BUILD ON the research, not repeat it

**Only conduct fresh research or file reads if:**

- No research document exists for the ticket
- The user explicitly requests fresh research
- The research document is outdated (check `last_updated` in frontmatter vs recent code changes)
- A **specific implementation detail is missing** that the research didn't cover (spawn targeted sub-task only for that detail)
- You have a specific question about a file that the research doesn't address

**How to detect if research exists:**

1. Run `./scripts/ticket.sh [PREFIX]-XXXX` to find all ticket-related documents
2. Look for files matching `thoughts/shared/research/*[PREFIX]-XXXX*.md`
3. If found, this is your primary codebase reference - read it fully before proceeding

## Handling Open Questions from Research and Tickets

**CRITICAL: Open questions must be DISCUSSED, not assumed.**

Research documents and tickets often contain open questions that are intended to be resolved during planning. These questions require your input from the human - do NOT assume answers.

**Types of open questions to look for:**

1. **Questions explicitly marked in research** (e.g., "Open Questions", "To Be Decided", "Needs Clarification")
2. **Questions in the ticket** that were deferred to planning
3. **Design decisions** where research identified multiple valid approaches
4. **Ambiguities** that research couldn't resolve through code analysis alone

**How to handle open questions:**

1. **Identify all open questions** when reading the research document and ticket
2. **Present them to the user** before proceeding with the plan structure
3. **WAIT for the user's answer** - do not assume or pick an option yourself
4. **Only proceed** once the question is resolved through discussion

**What NOT to do:**

- Pick an answer yourself and add it to the plan
- Assume the "obvious" or "best" choice without asking
- Skip over questions marked as "to be decided during planning"
- Write the plan with unresolved questions and hope the user catches them

**Example interaction:**

```
I've read the research document and found these open questions that need your input:

**From Research:**
1. Should we use a soft delete or hard delete approach for cleanup?
   - Research found both patterns exist in the codebase

2. The research identified two caching strategies - which do you prefer?
   - Option A: Redis with 5-minute TTL
   - Option B: In-memory cache with manual invalidation

**From Ticket:**
3. What should happen when a user tries to upload a duplicate file?

Please help me resolve these before I create the implementation plan.
```

**When a question IS fully answered by research:**

If the research document definitively answers a question (not just presents options), you can incorporate that answer directly. But if there's any ambiguity or multiple valid choices, discuss with the user first.

## Initial Response

When this command is invoked:

1. **Check if parameters were provided**:

   - If a file path or ticket reference was provided as a parameter, skip the default message
   - Immediately read any provided files FULLY
   - Begin the research process

2. **If no parameters provided**, respond with:

```
I'll help you create a detailed implementation plan. Let me start by understanding what we're building.

Please provide:
1. The task/ticket description (or reference to a ticket file)
2. Any relevant context, constraints, or specific requirements
3. Links to related research or previous implementations

I'll analyze this information and work with you to create a comprehensive plan.

Tip: You can also invoke this command with a ticket file directly: `/create_plan thoughts/shared/tickets/[PREFIX]-0001-feature-name.md`
For deeper analysis, try: `/create_plan think deeply about thoughts/shared/tickets/[PREFIX]-0001-feature-name.md`
```

Then wait for the user's input.

## Process Steps

### Step 1: Context Gathering & Initial Analysis

1. **Read all mentioned files immediately and FULLY**:

   - Ticket files (e.g., `thoughts/shared/tickets/[PREFIX]-0001-feature-name.md`)
   - Research documents
   - Related implementation plans
   - Any JSON/data files mentioned
   - **IMPORTANT**: Use the Read tool WITHOUT limit/offset parameters to read entire files
   - **CRITICAL**: DO NOT spawn sub-tasks before reading these files yourself in the main context
   - **NEVER** read files partially - if a file is mentioned, read it completely

2. **Check for existing research documents**:

   - Run `./scripts/ticket.sh [PREFIX]-XXXX` to find all documents for this ticket
   - Look for research documents in the results (files in `thoughts/shared/research/`)

   **If a research document EXISTS:**
   - Read it FULLY - it contains comprehensive codebase analysis
   - **SKIP steps 3-4 below** (spawning research agents)
   - The research document IS your codebase understanding - **DO NOT re-read source files it already covers**
   - **Identify any open questions** in the research that need resolution (see "Handling Open Questions" section)
   - Proceed directly to step 5 (present understanding and questions)
   - Only spawn a targeted sub-task if a specific detail is missing from the research

   **If NO research document exists:**
   - Proceed with steps 3-4 below to gather context

3. **Spawn initial research tasks (ONLY if no research document exists)**:
   Before asking the user any questions, use specialized agents to research in parallel:

   - Use the **codebase-locator** agent to find all files related to the ticket/task
   - Use the **codebase-analyzer** agent to understand how the current implementation works
   - If relevant, use the **thoughts-locator** agent to find any existing thoughts documents about this feature

   These agents will:

   - Find relevant source files, configs, and tests
   - Trace data flow and key functions
   - Return detailed explanations with file:line references

4. **Read all files identified by research tasks (ONLY if no research document exists)**:

   - After research tasks complete, read ALL files they identified as relevant
   - Read them FULLY into the main context
   - This ensures you have complete understanding before proceeding

5. **Analyze and verify understanding**:

   - Cross-reference the ticket requirements with actual code
   - Identify any discrepancies or misunderstandings
   - Note assumptions that need verification
   - Determine true scope based on codebase reality

5. **Present informed understanding and focused questions**:

   ```
   Based on the ticket and research document, I understand we need to [accurate summary].

   Key findings from research:
   - [Current implementation detail with file:line reference]
   - [Relevant pattern or constraint discovered]
   - [Potential complexity or edge case identified]

   **Open questions that need your input:**

   From the research document:
   - [Question marked as "to be decided" in research]
   - [Design choice where research found multiple valid options]

   From the ticket:
   - [Question deferred to planning phase]

   Additional clarifications needed:
   - [Specific technical question that requires human judgment]
   - [Business logic clarification]
   ```

   **IMPORTANT**: Do NOT proceed to plan structure until all open questions are resolved.
   Wait for user input on each question before continuing.

### Design Exploration Check (for tickets involving UX changes)

**After understanding the ticket and resolving open questions, assess whether the ticket involves a non-trivial UX change.** A non-trivial UX change is one that introduces new UI patterns, significantly alters existing user flows, or involves design decisions with multiple valid approaches (e.g., new interaction patterns, layout changes, new component types, redesigns).

Trivial UX changes that do NOT require design exploration: bug fixes, text changes, style tweaks, adding a field to an existing form, simple CRUD screens following established patterns.

**If the ticket involves a non-trivial UX change:**

1. Check if a design decision already exists:
   ```bash
   # Look for mockup directories referencing this ticket
   ls thoughts/shared/mockups/*/ 2>/dev/null
   # Check for DECISION.md files that reference the ticket number
   grep -rl "[PREFIX]-XXXX" thoughts/shared/mockups/*/DECISION.md 2>/dev/null
   ```

2. **If a DECISION.md exists** that references this ticket: Read it, incorporate the chosen design into the plan, and continue.

3. **If no design decision exists**, suggest running `/design_explore` first:

   > This ticket involves a non-trivial UX change ([brief description of what makes it non-trivial]). I don't see an existing design decision for it.
   >
   > Would you like to run `/design_explore` first to explore and select a design direction before I create the implementation plan? This helps ensure we align on the visual approach before committing to a technical plan.
   >
   > If you'd prefer to skip design exploration and plan directly, I'll proceed with the plan now.

4. **If the user wants design exploration**: Stop here. The user will run `/design_explore`, and then return to `/create_plan` afterward.

5. **If the user wants to skip**: Continue with planning. Note in the plan that no formal design exploration was done.

### Step 2: Research & Discovery (SKIP if research document exists)

**If a research document was provided:** Skip this entire step and proceed to Step 3. The research document already contains the codebase analysis you need.

**If NO research document exists**, proceed with the following:

After getting initial clarifications:

1. **If the user corrects any misunderstanding**:

   - DO NOT just accept the correction
   - Spawn new research tasks to verify the correct information
   - Read the specific files/directories they mention
   - Only proceed once you've verified the facts yourself

2. **Create a research todo list** using TodoWrite to track exploration tasks

3. **Spawn parallel sub-tasks for comprehensive research**:

   - Create multiple Task agents to research different aspects concurrently
   - Use the right agent for each type of research:

   **For deeper investigation:**

   - **codebase-locator** - To find more specific files (e.g., "find all files that handle [specific component]")
   - **codebase-analyzer** - To understand implementation details (e.g., "analyze how [system] works")
   - **codebase-pattern-finder** - To find similar features we can model after

   **For UI pattern research (when ticket involves frontend):**

   - **codebase-pattern-finder** - To explore UI component patterns
   - Research what UI components are available that fit the feature requirements
   - This enables autonomous UI decisions during planning

   **For historical context:**

   - **thoughts-locator** - To find any research, plans, or decisions about this area
   - **thoughts-analyzer** - To extract key insights from the most relevant documents

   Each agent knows how to:

   - Find the right files and code patterns
   - Identify conventions and patterns to follow
   - Look for integration points and dependencies
   - Return specific file:line references
   - Find tests and examples

4. **Wait for ALL sub-tasks to complete** before proceeding

5. **Present findings and design options**:

   ```
   Based on my research, here's what I found:

   **Current State:**
   - [Key discovery about existing code]
   - [Pattern or convention to follow]

   **Design Options:**
   1. [Option A] - [pros/cons]
   2. [Option B] - [pros/cons]

   **Open Questions:**
   - [Technical uncertainty]
   - [Design decision needed]

   Which approach aligns best with your vision?
   ```

### Step 3: Plan Structure Development

Once aligned on approach:

1. **Create initial plan outline**:

   ```
   Here's my proposed plan structure:

   ## Overview
   [1-2 sentence summary]

   ## Implementation Phases:
   1. [Phase name] - [what it accomplishes]
   2. [Phase name] - [what it accomplishes]
   3. [Phase name] - [what it accomplishes]

   Does this phasing make sense? Should I adjust the order or granularity?
   ```

2. **Get feedback on structure** before writing details

3. **Make UI/UX decisions (for frontend features)**:

   If the plan involves UI work:

   - **Review UI research findings** from earlier sub-tasks
   - **Select specific components** that fit the requirements
   - **Document the user experience** narrative (what users see and do)
   - **Make autonomous UI decisions** with clear rationale

   ```
   ## UI/UX Approach

   **Selected Pattern**: [Specific component pattern]
   **Location**: [Reference to example]

   **Rationale**:
   - [Why this pattern fits the requirements]
   - [How it supports the user flow]
   - [Accessibility/responsive considerations]

   **User Experience Flow**:
   1. [Step 1 - what user sees/does]
   2. [Step 2 - interaction/feedback]
   3. [Step 3 - outcome]

   **Visual Elements**:
   - Layout: [describe layout approach]
   - States: [loading, error, success, empty states]
   - Mobile: [responsive behavior]
   ```

   Get feedback on the UI approach before proceeding to detailed implementation steps.

### Step 4: Detailed Plan Writing

After structure approval:

1. **Write the plan** to `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
   - Format: `YYYY-MM-DD-[PREFIX]-XXXX-description.md` where:
     - YYYY-MM-DD is today's date
     - [PREFIX]-XXXX is the ticket number (omit if no ticket)
     - description is a brief kebab-case description
   - Ticket naming convention: `[PREFIX]-XXXX-name.md` with increasing numbers (e.g., [PREFIX]-0001, [PREFIX]-0002)
   - Examples:
     - With ticket: `2024-12-04-[PREFIX]-0001-multi-tenant-auth.md`
     - Without ticket: `2024-12-04-improve-error-handling.md`
2. **Use this template structure**:

````markdown
# [Feature/Task Name] Implementation Plan

## Overview

[Brief description of what we're implementing and why]

## Current State Analysis

[What exists now, what's missing, key constraints discovered]

## Desired End State

[A Specification of the desired end state after this plan is complete, and how to verify it]

### Key Discoveries:

- [Important finding with file:line reference]
- [Pattern to follow]
- [Constraint to work within]

## What We're NOT Doing

[Explicitly list out-of-scope items to prevent scope creep]

## Implementation Approach

[High-level strategy and reasoning]

## Phase 1: [Descriptive Name]

### Overview

[What this phase accomplishes]

### Changes Required:

#### 1. [Component/File Group]

**File**: `path/to/file.ext`
**Changes**: [Summary of changes]

```[language]
// Specific code to add/modify
```

### Success Criteria:

#### Automated Verification:

- [ ] Backend: Migration applies cleanly
- [ ] Backend: Unit tests pass
- [ ] Backend: Linting passes
- [ ] Frontend: Type checking passes
- [ ] Frontend: Linting passes
- [ ] Frontend: Tests pass

#### Manual Verification:

- [ ] Feature works as expected when tested via UI
- [ ] Performance is acceptable under load
- [ ] Edge case handling verified manually
- [ ] No regressions in related features

---

## Phase 2: [Descriptive Name]

[Similar structure with both automated and manual success criteria...]

---

## Testing Strategy

### Unit Tests:

- [What to test]
- [Key edge cases]

### Integration Tests:

- [End-to-end scenarios]

### Manual Testing Steps:

1. [Specific step to verify feature]
2. [Another verification step]
3. [Edge case to test manually]

## Performance Considerations

[Any performance implications or optimizations needed]

## Migration Notes

[If applicable, how to handle existing data/systems]

## References

- Original ticket: `thoughts/shared/tickets/[PREFIX]-XXXX-description.md`
- Related research: `thoughts/shared/research/[relevant].md`
- Similar implementation: `[file:line]`
````

### Step 5: Sync and Review

1. **Sync the thoughts directory**:

   - This ensures the plan is properly indexed and available

2. **Present the draft plan location**:

   ```
   I've created the initial implementation plan at:
   `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`

   Please review it and let me know:
   - Are the phases properly scoped?
   - Are the success criteria specific enough?
   - Any technical details that need adjustment?
   - Missing edge cases or considerations?

   Next command: `/implement_plan [PREFIX]-XXXX`
   ```
   (Replace [PREFIX]-XXXX with the actual ticket number)

2. **Iterate based on feedback** - be ready to:

   - Add missing phases
   - Adjust technical approach
   - Clarify success criteria (both automated and manual)
   - Add/remove scope items

3. **Continue refining** until the user is satisfied

4. **Commit the plan document:**

   - Once the user is satisfied with the plan, use the `/commit` command to commit it
   - This ensures the plan is saved as a checkpoint before moving to the implementation phase

**CRITICAL: Your job ends here.** Do NOT start implementing the plan. Do NOT leave plan mode to begin coding. The user will start the implementation themselves by running `/implement_plan`. Your only output after committing is the "Next command" hint shown above.

## Important Guidelines

1. **Be Skeptical**:

   - Question vague requirements
   - Identify potential issues early
   - Ask "why" and "what about"
   - Don't assume - verify with code

2. **Be Interactive**:

   - Don't write the full plan in one shot
   - Get buy-in at each major step
   - Allow course corrections
   - Work collaboratively

3. **Be Thorough**:

   - Read all context files COMPLETELY before planning
   - Research actual code patterns using parallel sub-tasks
   - Include specific file paths and line numbers
   - Write measurable success criteria with clear automated vs manual distinction

4. **Be Practical**:

   - Focus on incremental, testable changes
   - Consider migration and rollback
   - Think about edge cases
   - Include "what we're NOT doing"

5. **Track Progress**:

   - Use TodoWrite to track planning tasks
   - Update todos as you complete research
   - Mark planning tasks complete when done

6. **No Open Questions in Final Plan**:
   - If you encounter open questions during planning, STOP
   - Research or ask for clarification immediately
   - Do NOT write the plan with unresolved questions
   - The implementation plan must be complete and actionable
   - Every decision must be made before finalizing the plan

7. **Respect Existing Research**:
   - If a research document exists for the ticket, it IS your codebase knowledge
   - DO NOT spawn redundant research agents when research already exists
   - **DO NOT re-read files that the research already analyzed** - use the research as context
   - Trust the research document's file references and analysis
   - Only spawn targeted sub-tasks for specific missing details
   - Only read source files directly if the research doesn't cover them AND you have a specific question
   - This prevents duplicate work and saves time/resources

8. **Discuss Open Questions from Research**:
   - Research documents often contain questions marked for planning resolution
   - Tickets may have questions deferred to the planning phase
   - **DO NOT assume answers** to these questions - discuss them with the user first
   - Present all open questions before creating the plan structure
   - Wait for user input before proceeding
   - Only incorporate answers that are definitively resolved in research (not options)

## Success Criteria Guidelines

**Always separate success criteria into two categories:**

1. **Automated Verification** (can be run by execution agents):

   - Backend commands: test runners, migrations, linters
   - Frontend commands: test runners, type checkers, linters
   - Specific files that should exist
   - Code compilation/type checking
   - Automated test suites

2. **Manual Verification** (requires human testing):
   - UI/UX functionality
   - Performance under real conditions
   - Edge cases that are hard to automate
   - User acceptance criteria

**Format example:**

```markdown
### Success Criteria:

#### Automated Verification:

- [ ] Backend: Database migration runs successfully
- [ ] Backend: All unit tests pass
- [ ] Frontend: Type checking passes
- [ ] API endpoint returns expected response

#### Manual Verification:

- [ ] New feature appears correctly in the UI
- [ ] Performance is acceptable with 1000+ items
- [ ] Error messages are user-friendly
- [ ] Feature works correctly on mobile devices
```

## Common Patterns

### For Database Changes:

- Start with schema/migration
- Add store methods
- Update business logic
- Expose via API
- Update clients

### For New Features:

- Research existing patterns first
- Start with data model
- Build backend logic
- Add API endpoints
- Implement UI last

### For Refactoring:

- Document current behavior
- Plan incremental changes
- Maintain backwards compatibility
- Include migration strategy

## Sub-task Spawning Best Practices

When spawning research sub-tasks:

1. **Spawn multiple tasks in parallel** for efficiency
2. **Each task should be focused** on a specific area
3. **Provide detailed instructions** including:
   - Exactly what to search for
   - Which directories to focus on
   - What information to extract
   - Expected output format
4. **Be EXTREMELY specific about directories**:
   - Include the full path context in your prompts
5. **Specify read-only tools** to use
6. **Request specific file:line references** in responses
7. **Wait for all tasks to complete** before synthesizing
8. **Verify sub-task results**:
   - If a sub-task returns unexpected results, spawn follow-up tasks
   - Cross-check findings against the actual codebase
   - Don't accept results that seem incorrect

Example of spawning multiple tasks:

```python
# Spawn these tasks concurrently:
tasks = [
    Task("Research database schema", db_research_prompt),
    Task("Find API patterns", api_research_prompt),
    Task("Investigate UI components", ui_research_prompt),
    Task("Check test patterns", test_research_prompt)
]
```

## Example Interaction Flow

```
User: /implementation_plan
Assistant: I'll help you create a detailed implementation plan...

User: We need to add tagging support. See thoughts/shared/tickets/[PREFIX]-0005-tagging.md
Assistant: Let me read that ticket file completely first...

[Reads file fully]

Based on the ticket, I understand we need to implement tagging functionality. Before I start planning, I have some questions...

[Interactive process continues...]
```
