---
description: Research the codebase (and web) to document existing patterns, constraints, and options for a ticket or question. Step 2 of the tce workflow.
argument-hint: "[ticket-id | research question]"
---

# Research Codebase

You are tasked with conducting comprehensive research across the codebase to answer user questions by spawning parallel sub-agents and synthesizing their findings.

## Project context

This command ships in the **tce** workflow plugin and is stack-agnostic.

- `[PREFIX]` in examples stands for the project's configured ticket prefix (in `.claude/tce/config`); the ticket scripts resolve it automatically — you never hardcode it.
- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack, conventions, and tooling, and let it guide which technologies and patterns you investigate. If it's missing, suggest the user run `/tce:init`.

---

## Workflow Context

**This is Step 2 of 4 in our development workflow:**

| Step | Command | Purpose |
|------|---------|---------|
| 1 | `/create_ticket` | Capture business requirements (WHAT & WHY) |
| **→ 2** | **`/research_codebase`** | **Research codebase, find patterns & libraries** |
| 3 | `/create_plan` | Clarify questions, create detailed implementation plan |
| 4 | `/implement_plan` | Execute implementation using all documents |

**Your role in this step:** Thoroughly research the codebase and internet to gather all relevant information. Find existing patterns, identify potential solutions and libraries. Document what you find WITHOUT making decisions — present the options so the user can make informed choices during the planning phase.

**Input:** Ticket from step 1 (with "Questions for Research/Planning" section)
**Output:** Research document in `thoughts/shared/research/` with findings and potential solutions

---

## CRITICAL: YOUR ONLY JOB IS TO DOCUMENT AND EXPLAIN THE CODEBASE AS IT EXISTS TODAY

- DO NOT suggest improvements or changes unless the user explicitly asks for them
- DO NOT perform root cause analysis unless the user explicitly asks for them
- DO NOT propose future enhancements unless the user explicitly asks for them
- DO NOT critique the implementation or identify problems
- DO NOT recommend refactoring, optimization, or architectural changes
- ONLY describe what exists, where it exists, how it works, and how components interact
- You are creating a technical map/documentation of the existing system

## Ticket Document Discovery

When a ticket number is provided (e.g., `[PREFIX]-0001`), use the ticket discovery script to find all documents directly related to that ticket:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0001
```

This returns files with the ticket number in their filename (tickets, research, plans). Note: This only finds documents that **directly reference the ticket in their filename**. For discovering documents that might be **contextually related** to the ticket's topic, use the `thoughts-locator` and `thoughts-analyzer` agents instead.

### Epic Context for Sub-tickets

**When the ticket is a sub-ticket of an epic** (indicated by a letter suffix, e.g., `[PREFIX]-0100a`), you MUST also read the parent epic's documents for context:

1. **Detect sub-ticket**: If the ticket number ends with a letter (e.g., `[PREFIX]-0100a`), the parent epic is the number without the letter suffix (e.g., `[PREFIX]-0100`).
2. **Find parent epic documents**: Run `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0100` (the parent number) to find the epic ticket, research, and plan.
3. **Read the parent epic's ticket** — it provides the big-picture context for why this sub-ticket exists.
4. **Read the parent epic's research and plan (if they exist)** — these are NOT mandatory to follow, but they provide valuable context:
   - The epic research may contain findings relevant to this sub-ticket
   - The epic plan may outline how this sub-ticket fits into the larger implementation
   - Use them as **inspiration and context**, not as binding instructions
   - The sub-ticket's own research should be the primary output — the epic context supplements it

**Example**: When researching `[PREFIX]-0100b`:
```bash
# Find sub-ticket documents
"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0100b

# Also find parent epic documents
"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0100
```
Then read the parent epic ticket and any research/plan before starting your own research.

## Initial Setup:

When this command is invoked, respond with:

```
I'm ready to research the codebase. Please provide your research question or area of interest, and I'll analyze it thoroughly by exploring relevant components and connections.
```

Then wait for the user's research query.

## Steps to follow after receiving the research query:

1. **Read any directly mentioned files first:**

   - If the user mentions specific files (tickets, docs, JSON), read them FULLY first
   - **IMPORTANT**: Use the Read tool WITHOUT limit/offset parameters to read entire files
   - **CRITICAL**: Read these files yourself in the main context before spawning any sub-tasks
   - This ensures you have full context before decomposing the research

2. **Analyze and decompose the research question:**

   - Break down the user's query into composable research areas
   - Take time to ultrathink about the underlying patterns, connections, and architectural implications the user might be seeking
   - **If the ticket/research involves UI/frontend work:**
     - Identify what types of UI components will be needed
     - Plan to research available UI patterns
   - Identify specific components, patterns, or concepts to investigate
   - Create a research plan using TodoWrite to track all subtasks
   - Consider which directories, files, or architectural patterns are relevant

3. **Spawn parallel sub-agent tasks for comprehensive research:**

   - Create multiple Task agents to research different aspects concurrently
   - We now have specialized agents that know how to do specific research tasks:

   **For codebase research:**

   - Use the **codebase-locator** agent to find WHERE files and components live
   - Use the **codebase-analyzer** agent to understand HOW specific code works (without critiquing it)
   - Use the **codebase-pattern-finder** agent to find examples of existing patterns (without evaluating them)

   **IMPORTANT**: All agents are documentarians, not critics. They will describe what exists without suggesting improvements or identifying issues.

   **For UI pattern research (when ticket involves frontend):**

   - Use the **codebase-pattern-finder** agent to explore UI component patterns
   - Document WHAT patterns exist and WHERE they are located
   - Do NOT choose which pattern to use (that's for planning phase)
   - Include brief descriptions of each pattern's characteristics

   **For thoughts directory:**

   - Use the **thoughts-locator** agent to discover what documents exist about the topic
   - Use the **thoughts-analyzer** agent to extract key insights from specific documents (only the most relevant ones)

   **For web research (REQUIRED when third-party code is involved):**

   **Automatic web research is required when the ticket/research involves third-party tools, libraries, or external code.** This includes:
   - Cloud providers (AWS, GCP, Azure, etc.)
   - Infrastructure tools (Terraform, Ansible, Docker)
   - Frameworks and their plugins
   - External packages and libraries (dependencies)
   - APIs and external services

   **For these cases, spawn web-search-researcher agents in parallel with codebase research to find:**
   - GitHub issues in the relevant repository
   - Similar problems others have encountered
   - Community best practices and recommended patterns
   - Official documentation for the specific use case
   - Known workarounds or fixes

   **Do NOT wait for the user to ask for web research when third-party code is involved.**

   - Use the **web-search-researcher** agent for external documentation and resources
   - Instruct web-research agents to return LINKS with their findings
   - INCLUDE those links in the "External Sources" section of your final report

   The key is to use these agents intelligently:

   - Start with locator agents to find what exists
   - Then use analyzer agents on the most promising findings to document how they work
   - Run multiple agents in parallel when they're searching for different things
   - Each agent knows its job - just tell it what you're looking for
   - Don't write detailed prompts about HOW to search - the agents already know
   - Remind agents they are documenting, not evaluating or improving

4. **Wait for all sub-agents to complete and synthesize findings:**

   - IMPORTANT: Wait for ALL sub-agent tasks to complete before proceeding
   - Compile all sub-agent results (both codebase and thoughts findings)
   - Prioritize live codebase findings as primary source of truth
   - Use thoughts/ findings as supplementary historical context
   - Connect findings across different components
   - Include specific file paths and line numbers for reference
   - Verify all thoughts/ paths are correct (tickets are always in thoughts/shared/tickets/)
   - Highlight patterns, connections, and architectural decisions
   - Answer the user's specific questions with concrete evidence

5. **Gather metadata for the research document:**

   - Gather metadata using git commands:
     - Current date/time: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
     - Git commit: `git rev-parse HEAD`
     - Git branch: `git branch --show-current`
     - Repository name from: `git config --get remote.origin.url`
   - Filename: `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
     - Format: `YYYY-MM-DD-[PREFIX]-XXXX-description.md` where:
       - YYYY-MM-DD is today's date
       - [PREFIX]-XXXX is the ticket number (omit if no ticket)
       - description is a brief kebab-case description of the research topic
     - Ticket naming convention: `[PREFIX]-XXXX-name.md` with increasing numbers (e.g., [PREFIX]-0001, [PREFIX]-0002)
     - Examples:
       - With ticket: `2024-12-04-[PREFIX]-0001-multi-tenant-auth.md`
       - Without ticket: `2024-12-04-authentication-flow.md`

6. **Generate research document:**

   - Use the metadata gathered in step 5
   - Structure the document with YAML frontmatter followed by content:

     ```markdown
     ---
     date: [Current date and time with timezone in ISO format]
     git_commit: [Current commit hash]
     branch: [Current branch name]
     repository: [Repository name]
     topic: "[User's Question/Topic]"
     tags: [research, codebase, relevant-component-names]
     status: complete
     last_updated: [Current date in YYYY-MM-DD format]
     ---

     # Research: [User's Question/Topic]

     **Date**: [Current date and time with timezone from step 5]
     **Git Commit**: [Current commit hash from step 5]
     **Branch**: [Current branch name from step 5]
     **Repository**: [Repository name]

     ## Research Question

     [Original user query]

     ## Summary

     [High-level documentation of what was found, answering the user's question by describing what exists]

     ## Detailed Findings

     ### [Component/Area 1]

     - Description of what exists ([file.ext:line](link))
     - How it connects to other components
     - Current implementation details (without evaluation)

     ### [Component/Area 2]

     ...

     ## Code References

     - `path/to/file.py:123` - Description of what's there
     - `another/file.ts:45-67` - Description of the code block

     ## Architecture Documentation

     [Current patterns, conventions, and design implementations found in the codebase]

     ## UI Patterns Available (if applicable)

     [UI components that could be used for this feature - only include if research involves frontend]

     ### [Pattern Type]
     - **Location**: `path/to/component.<ext>`
     - **Description**: What this pattern provides
     - **Characteristics**: Key visual/interaction features
     - **Use case fit**: How it relates to the research topic

     (Document available options without making recommendations)

     ## Historical Context (from thoughts/)

     [Relevant insights from thoughts/ directory with references]

     - `thoughts/shared/something.md` - Historical decision about X
       Note: Paths exclude "searchable/" even if found there

     ## Related Research

     [Links to other research documents in thoughts/shared/research/]

     ## Open Questions

     [Any areas that need further investigation]
     ```

7. **Add GitHub permalinks (if applicable):**

   - Check if on main branch or if commit is pushed: `git branch --show-current` and `git status`
   - If on main/master or pushed, generate GitHub permalinks:
     - Get repo info: `gh repo view --json owner,name`
     - Create permalinks: `https://github.com/{owner}/{repo}/blob/{commit}/{file}#L{line}`
   - Replace local file references with permalinks in the document

8. **Present findings:**

   - Present a concise summary of findings to the user
   - Include key file references for easy navigation
   - Ask if they have follow-up questions or need clarification
   - **Print the next command** for the user to run:
     ```
     Next command: `/create_plan [PREFIX]-XXXX`
     ```
     (Replace [PREFIX]-XXXX with the actual ticket number from this research session)

9. **Commit the research document:**

   - After the research document is written and presented, use the `/commit` command to commit it
   - This ensures the research is saved as a checkpoint before moving to the planning phase

10. **Handle follow-up questions:**
   - If the user has follow-up questions, append to the same research document
   - Update the frontmatter field `last_updated` to reflect the update
   - Add `last_updated_note: "Added follow-up research for [brief description]"` to frontmatter
   - Add a new section: `## Follow-up Research [timestamp]`
   - Spawn new sub-agents as needed for additional investigation
   - Continue updating the document
   - Once all follow-up questions are resolved, use the `/commit` command to commit the updated research document

## CRITICAL: Researching Code for Reuse or Extension

**When research involves code that will be reused or extended for a new purpose, you MUST include impact analysis.**

This is especially important for code that crosses component boundaries (APIs, shared models, database schema, etc.).

### Additional Research Steps for Code Reuse/Extension:

1. **Search for ALL existing usages** of the code being considered:
   - Use **codebase-locator** to find all files that import/use the target code
   - Use **codebase-analyzer** to understand HOW each consumer uses the code
   - Search across ALL components (frontend, backend, etc.)
   - Include test files - they reveal expected contracts and edge cases

2. **Document the current contract:**
   - What parameters/arguments does it accept?
   - What does it return? What's the response structure?
   - What are the implicit assumptions consumers make?
   - What validation or error handling exists?

3. **Assess adaptation requirements:**
   - For each usage found, document: "Would this break if [proposed change]?"
   - List specific files and line numbers that would need updates
   - Note any tests that verify current behavior

4. **Research backward compatibility options:**
   - Can the new behavior be added WITHOUT changing existing behavior?
   - Can optional parameters preserve old signatures?
   - Can response structures be extended rather than modified?
   - Is a deprecation/migration path feasible?

### Include in Research Document:

When the research topic involves code reuse/extension, add this section to the output:

```markdown
## Impact Analysis

### Existing Usages Found
- `path/to/consumer1.ts:45` - Uses [function/API] for [purpose]
- `path/to/consumer2.php:123` - Depends on [specific behavior]
- `tests/path/to/test.ts:67` - Verifies [expected contract]

### Current Contract
- Input: [parameters, types, optional/required]
- Output: [return type, structure]
- Assumptions: [implicit expectations by consumers]

### Adaptation Requirements
- `file1.ts:XX` - Would need [specific change] because [reason]
- `file2.php:YY` - Would need [specific change] because [reason]

### Backward Compatibility Options
- Option A: [approach] - Pros: [...] Cons: [...]
- Option B: [approach] - Pros: [...] Cons: [...]
```

**Remember:** This analysis is DOCUMENTATION, not recommendation. Present the findings so the planning phase can make informed decisions.

---

## Important notes:

- Always use parallel Task agents to maximize efficiency and minimize context usage
- Always run fresh codebase research - never rely solely on existing research documents
- The thoughts/ directory provides historical context to supplement live findings
- Focus on finding concrete file paths and line numbers for developer reference
- Research documents should be self-contained with all necessary context
- Each sub-agent prompt should be specific and focused on read-only documentation operations
- Document cross-component connections and how systems interact
- Include temporal context (when the research was conducted)
- Link to GitHub when possible for permanent references
- Keep the main agent focused on synthesis, not deep file reading
- Have sub-agents document examples and usage patterns as they exist
- Explore all of thoughts/ directory, not just research subdirectory
- **CRITICAL**: You and all sub-agents are documentarians, not evaluators
- **REMEMBER**: Document what IS, not what SHOULD BE
- **NO RECOMMENDATIONS**: Only describe the current state of the codebase
- **File reading**: Always read mentioned files FULLY (no limit/offset) before spawning sub-tasks
- **Critical ordering**: Follow the numbered steps exactly
  - ALWAYS read mentioned files first before spawning sub-tasks (step 1)
  - ALWAYS wait for all sub-agents to complete before synthesizing (step 4)
  - ALWAYS gather metadata using git commands before writing the document (step 5 before step 6)
  - NEVER write the research document with placeholder values
- **Path handling**: The thoughts/searchable/ directory contains hard links for searching
  - Always document paths by removing ONLY "searchable/" - preserve all other subdirectories
  - Examples of correct transformations:
    - `thoughts/searchable/shared/prs/123.md` → `thoughts/shared/prs/123.md`
    - `thoughts/searchable/shared/tickets/[PREFIX]-0001-feature.md` → `thoughts/shared/tickets/[PREFIX]-0001-feature.md`
  - Preserve the exact directory structure
  - This ensures paths are correct for editing and navigation
- **Frontmatter consistency**:
  - Always include frontmatter at the beginning of research documents
  - Keep frontmatter fields consistent across all research documents
  - Update frontmatter when adding follow-up research
  - Use snake_case for multi-word field names (e.g., `last_updated`, `git_commit`)
  - Tags should be relevant to the research topic and components studied
