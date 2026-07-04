---
description: Turn a ticket + research into a detailed, phased implementation plan, resolving open questions first. Step 3 of the tce workflow.
argument-hint: "[ticket-id | path to ticket/plan file]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)
---

# Implementation Plan

You are tasked with creating detailed implementation plans through an interactive, iterative process. Be skeptical: question vague requirements, verify assumptions against the code rather than assuming, and surface potential issues early. Work collaboratively with the user to produce high-quality technical specifications.

## Project context

This command ships in the **tce** workflow plugin and is stack- and ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack, conventions, and the exact test/lint/typecheck commands. Use those when writing the plan's automated success criteria instead of assuming a stack. If it's missing, suggest the user run `/tce:init`.
- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the project's ticket system: how to normalize a ticket reference into its canonical ID, how to fetch the ticket's content, and how to find parent/epic tickets. If it's missing, suggest `/tce:init`.
- `[PREFIX]-XXXX` in examples stands for a canonical ticket ID as defined in `tickets.md` (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.

### AskUserQuestion dialog guidelines

When asking the user something, follow these rules:

- Use the AskUserQuestion tool when a small set of concrete options exists
  (2–4); ask in plain prose only when the answer is genuinely free-form.
- Print a short intro paragraph (1–3 plain sentences) as a normal message
  before invoking the tool — it carries all context. The question text contains
  only the question itself: no background, no nested parentheticals.
- Put the recommended or detected option first, append " (Recommended)" to its
  label, and give the reasoning (e.g. how it was detected) in that option's
  description.
- At most 4 questions per call — batch related questions into one call. Never
  offer an "Other" or "custom" option: the tool adds one automatically.
- Headers ≤12 characters; labels 1–5 words; descriptions 1–2 plain sentences on
  what choosing the option means. Plain text only — markdown is not rendered
  inside the dialog.
- Use multiSelect only when choices are not mutually exclusive, and phrase the
  question accordingly.

---

## Workflow Context

**This is Step 3 of 4 in our development workflow:**

| Step | Command | Purpose |
|------|---------|---------|
| 1 | ticket creation | Capture business requirements (WHAT & WHY) in the project's ticket system (e.g. `/tce:ticket`) |
| 2 | `/tce:research` | Research codebase, find patterns & libraries |
| **→ 3** | **`/tce:plan`** | **Clarify questions, create detailed implementation plan** |
| 3b | `/tce:design_explore` | *(Optional)* Explore and select a visual design for UX changes |
| 4 | `/tce:implement` | Execute implementation using all documents |

**Your role in this step:** Using the ticket and research document, resolve any remaining open questions with the user and create a detailed, actionable implementation plan with specific phases, code changes, and success criteria.

**Input:** A ticket from the project's ticket system + Research document from step 2
**Output:** Implementation plan in `thoughts/shared/plans/`

---

## Ticket Document Discovery

When a ticket reference is provided:

1. **Resolve the canonical ticket ID** as `.claude/tce/tickets.md` describes (e.g. a bare number or `#123` → the canonical form used in filenames).
2. **Fetch the ticket's content** using the read mechanism from `tickets.md` (a file in `thoughts/shared/tickets/` for tmt, a CLI/MCP call for hosted systems). Read it FULLY now — even if it already appeared earlier in this conversation. Read the ticket and the research document (next section) freshly and in chain order (ticket → research) on every invocation; re-reading anchors your attention on these inputs without discarding the surrounding history. (This applies to the workflow **documents** only — it does not change the guidance below about not re-reading **source files** the research already covers.)
3. **Find related thoughts documents** with the discovery script:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0001
   ```

   This returns thoughts/ files with the ticket ID in their filename (research, plans, and — for tmt — the ticket itself). Note: This only finds documents that **directly reference the ticket in their filename**. For discovering documents that might be **contextually related** to the ticket's topic, use the `thoughts-locator` and `thoughts-analyzer` agents instead.

### Parent / Epic Context

**When the ticket has a parent or epic** — determine this per the "Parent / epic tickets" section of `tickets.md` (for tmt, a letter suffix like `[PREFIX]-0100a` marks a sub-ticket of `[PREFIX]-0100`) — you MUST also read the parent's documents for context:

1. **Fetch the parent ticket** via the mechanism in `tickets.md` — it provides the big-picture context for why this sub-ticket exists.
2. **Find the parent's thoughts documents**: run the discovery script (above) with `<parent-id>` to find the epic's research and plan.
3. **Read the parent's research and plan (if they exist)** — these are NOT mandatory to follow, but they provide valuable context:
   - The epic research may contain findings relevant to this sub-ticket
   - The epic plan may outline how this sub-ticket fits into the larger implementation
   - Use them as **inspiration and context**, not as binding instructions
   - The sub-ticket's own research/plan takes precedence over the epic's
   - Decisions already made in the epic plan can inform this plan, but should be re-evaluated in the sub-ticket's specific context

## Research Document Integration

**When a research document is provided alongside the ticket (e.g., `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-*.md`):**

- The research phase has **already been completed** by `/tce:research`
- Read the research document FULLY now - it contains all codebase findings, file references, and analysis. Do this even if the research was produced earlier in this same conversation (e.g. by `/tce:work`) - re-read it fresh rather than relying on what is still in context
- **The research document IS your codebase context.** Do NOT spawn research agents (codebase-locator, codebase-analyzer, thoughts-locator, web-search) and do NOT re-read source files the research already analyzed — if the research covers a file, use its analysis. The goal is to BUILD ON the research, not repeat it. (Exceptions below.)
- Only ask clarifying questions about **requirements and design decisions**, not about codebase structure
- Proceed directly to **Step 3 (Plan Structure Development)** after reading the ticket and research

**Only conduct fresh research or source-file reads if:**

- No research document exists for the ticket
- The user explicitly requests fresh research
- The research document is outdated (check `last_updated` in frontmatter vs recent code changes)
- A **specific implementation detail is missing** that the research didn't cover (spawn one targeted sub-task only for that detail)
- You have a specific question about a file that the research doesn't address (read just that file)

**How to detect if research exists:** run the discovery script (above) and look
for files matching `thoughts/shared/research/*[PREFIX]-XXXX*.md`. If found,
that is your primary codebase reference.

## Handling Open Questions from Research and Tickets

**CRITICAL: Open questions must be DISCUSSED, not assumed.**

Research documents and tickets often contain open questions that are intended to be resolved during planning. These questions require input from the human.

**Types of open questions to look for:**

1. **Questions explicitly marked in research** (e.g., "Open Questions", "To Be Decided", "Needs Clarification")
2. **Questions in the ticket** that were deferred to planning
3. **Design decisions** where research identified multiple valid approaches
4. **Ambiguities** that research couldn't resolve through code analysis alone

**How to handle open questions:**

1. **Identify all open questions** when reading the research document and ticket
2. **Present them to the user** before proceeding with the plan structure,
   following the AskUserQuestion dialog guidelines (above): intro context
   first, then one AskUserQuestion call with concrete options where they exist
3. **WAIT for the user's answer** — never pick an option yourself, assume the
   "obvious" choice, or skip questions marked "to be decided during planning"
4. **Only proceed** once every question is resolved through discussion. If new
   open questions surface later while writing the plan, STOP and resolve them
   the same way — the final plan must be complete and actionable, with every
   decision made and no unresolved questions left for the user to catch

**When a question IS fully answered by research:**

If the research document definitively answers a question (not just presents options), you can incorporate that answer directly. But if there's any ambiguity or multiple valid choices, discuss with the user first.

## Initial Response

When this command is invoked:

1. **Check if parameters were provided**:

   - If a file path or ticket reference was provided as a parameter, skip the
     default message and begin the process (Step 1 reads all inputs)

2. **If no parameters provided**, respond with:

```
I'll help you create a detailed implementation plan. Let me start by understanding what we're building.

Please provide:
1. The task/ticket description (or reference to a ticket file)
2. Any relevant context, constraints, or specific requirements
3. Links to related research or previous implementations

I'll analyze this information and work with you to create a comprehensive plan.

Tip: You can also invoke this command with a ticket ID directly: `/tce:plan [PREFIX]-0001`
For deeper analysis, try: `/tce:plan think deeply about [PREFIX]-0001`
```

Then wait for the user's input.

## Process Steps

### Step 1: Context Gathering & Initial Analysis

1. **Read all mentioned files immediately and FULLY**:

   - The ticket (fetched via the read mechanism in `tickets.md`), research
     documents, related implementation plans, any JSON/data files mentioned
   - Use the Read tool WITHOUT limit/offset parameters — NEVER read a
     mentioned file partially — and read them yourself in the main context
     BEFORE spawning any sub-tasks

2. **Check for existing research documents**:

   - Run the discovery script (see Ticket Document Discovery) to find all documents for this ticket
   - Look for research documents in the results (files in `thoughts/shared/research/`)

   **If a research document EXISTS:**
   - Apply the Research Document Integration rules (above): read it fully, then build on it instead of re-researching
   - **SKIP steps 3-4 below** (spawning research agents)
   - **Identify any open questions** in the research that need resolution (see "Handling Open Questions" section)
   - Proceed directly to step 6 (present understanding and questions)

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

   - After research tasks complete, read ALL files they identified as relevant into the main context
   - This ensures you have complete understanding before proceeding

5. **Analyze and verify understanding**:

   - Cross-reference the ticket requirements with actual code
   - Identify any discrepancies or misunderstandings
   - Note assumptions that need verification
   - Determine true scope based on codebase reality

6. **Present informed understanding and focused questions**:

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

   The understanding and key findings form the intro message; present and
   resolve the questions per "Handling Open Questions" (above) before moving
   on to plan structure.

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

3. **If no design decision exists**, suggest running `/tce:design_explore` first:

   > This ticket involves a non-trivial UX change ([brief description of what makes it non-trivial]). I don't see an existing design decision for it.
   >
   > Would you like to run `/tce:design_explore` first to explore and select a design direction before I create the implementation plan? This helps ensure we align on the visual approach before committing to a technical plan.
   >
   > If you'd prefer to skip design exploration and plan directly, I'll proceed with the plan now.

4. **If the user wants design exploration**: Stop here. The user will run `/tce:design_explore`, and then return to `/tce:plan` afterward.

5. **If the user wants to skip**: Continue with planning. Note in the plan that no formal design exploration was done.

### Step 2: Research & Discovery (SKIP if research document exists)

**If a research document was provided:** Skip this entire step and proceed to Step 3 (see Research Document Integration).

**If NO research document exists**, proceed with the following:

After getting initial clarifications:

1. **If the user corrects any misunderstanding**:

   - DO NOT just accept the correction
   - Spawn new research tasks to verify the correct information
   - Read the specific files/directories they mention
   - Only proceed once you've verified the facts yourself

2. **Create a research todo list** using TodoWrite to track exploration tasks

3. **Spawn parallel sub-tasks for comprehensive research**:

   - Create multiple Task agents to research different aspects concurrently, using the right agent for each type of research:

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

   **When writing sub-task prompts:** keep each task focused on one specific
   area; say exactly what to search for, which directories to focus on (full
   path context), what information to extract, and the expected output format;
   specify read-only tools; and request specific file:line references in
   responses.

4. **Wait for ALL sub-tasks to complete** before proceeding, then **verify
   their results**: if a sub-task returns unexpected results, spawn follow-up
   tasks and cross-check findings against the actual codebase — don't accept
   results that seem incorrect

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

1. **Read the plan template**: Read `${CLAUDE_PLUGIN_ROOT}/references/plan-document-template.md` now — in full — before proposing the phase structure. It contains the plan document template, the success-criteria guidelines, and structuring patterns for common change types; use them to shape the phases.

2. **Create initial plan outline**:

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

   Aim for incremental, testable phases; consider migration, rollback, and
   edge cases while shaping them.

3. **Get feedback on structure** before writing details

4. **Make UI/UX decisions (for frontend features)**:

   If the plan involves UI work:

   - **Review UI research findings** from earlier sub-tasks
   - **Select specific components** that fit the requirements
   - **Document the user experience** narrative (what users see and do)
   - **Make autonomous UI decisions** with clear rationale
   - Write them up using the "UI/UX Approach" section template from the
     reference file (read in point 1)

   Get feedback on the UI approach before proceeding to detailed implementation steps.

### Step 4: Detailed Plan Writing

After structure approval:

1. **Write the plan** to `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
   - Format: `YYYY-MM-DD-[PREFIX]-XXXX-description.md` where:
     - YYYY-MM-DD is today's date
     - [PREFIX]-XXXX is the canonical ticket ID per `tickets.md` (omit if no ticket)
     - description is a brief kebab-case description
   - The canonical ID in the filename is what links the document to its ticket (the discovery script globs for it), so use it exactly
   - Examples:
     - With ticket: `2024-12-04-[PREFIX]-0001-multi-tenant-auth.md`
     - Without ticket: `2024-12-04-improve-error-handling.md`
2. **Follow the plan document template**: Read `${CLAUDE_PLUGIN_ROOT}/references/plan-document-template.md` again now — in full, even if you read it in Step 3 — and structure the document exactly as its template specifies, separating each phase's success criteria into Automated and Manual verification per its guidelines. Include specific file paths, line numbers, and code changes throughout.

### Step 5: Review and Commit

1. **Present a decision-oriented summary** — the human review surface:

   The plan on disk is the agent's context for implementation; this summary is
   what the human actually reviews. It must surface everything the human might
   want to veto — the choices made on their behalf — not digest the plan's
   contents:

   ```
   I've created the implementation plan at:
   `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`

   **Decisions made:**
   - [Decision] — over [rejected alternative]: [one-line why]
   - [Another decision] — over [alternative]: [why]

   **Riskiest assumptions:**
   - [Assumption that, if wrong, invalidates part of the plan]

   **Explicitly out of scope:**
   - [Out-of-scope item the user might expect to be included]

   **Phases:**
   1. [Phase name] — [one line]
   2. [Phase name] — [one line]

   Next command: `/tce:implement [PREFIX]-XXXX`
   ```
   (Replace [PREFIX]-XXXX with the actual ticket number)

2. **Iterate based on feedback** - be ready to:

   - Add missing phases
   - Adjust technical approach
   - Clarify success criteria
   - Add/remove scope items

3. **Continue refining** until the user is satisfied

4. **Commit the plan document:**

   - Once the user is satisfied with the plan, use the `/tce:commit` command to commit it
   - This ensures the plan is saved as a checkpoint before moving to the implementation phase

**CRITICAL: Your job ends here.** Do NOT start implementing the plan. The user will start the implementation themselves by running `/tce:implement`. Your only output after committing is the "Next command" hint shown above.
