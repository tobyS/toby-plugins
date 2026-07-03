---
description: Research the codebase (and web) to document existing patterns, constraints, and options for a ticket or question. Step 2 of the tce workflow.
argument-hint: "[ticket-id | research question]"
---

# Research Codebase

You are tasked with conducting comprehensive research across the codebase to answer user questions by spawning parallel sub-agents and synthesizing their findings.

## Project context

This command ships in the **tce** workflow plugin and is stack- and ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack, conventions, and tooling, and let it guide which technologies and patterns you investigate. If it's missing, suggest the user run `/tce:init`.
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

**This is Step 2 of 4 in our development workflow:**

| Step | Command | Purpose |
|------|---------|---------|
| 1 | ticket creation | Capture business requirements (WHAT & WHY) in the project's ticket system (e.g. `/tce:ticket`) |
| **→ 2** | **`/tce:research`** | **Research codebase, find patterns & libraries** |
| 3 | `/tce:plan` | Clarify questions, create detailed implementation plan |
| 4 | `/tce:implement` | Execute implementation using all documents |

**Your role in this step:** Thoroughly research the codebase and internet to gather all relevant information. Find existing patterns, identify potential solutions and libraries, and document the options so the user can make informed choices during the planning phase.

**Input:** A ticket from the project's ticket system (see `tickets.md`)
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
- Your sub-agents are documentarians too — remind them in your prompts that they describe what exists, without evaluating or improving it

**One sanctioned exception:** while researching you may notice the project's tce
config (`profile.md` or the backend adapter in `tickets.md`) no longer matches
reality. You may surface a single, non-blocking advisory to run `/tce:refresh`
(detection criteria in step 4; surfaced in step 8). This is the only
recommendation allowed — and it concerns tce's own config, not the project's code.

## Ticket Document Discovery

When a ticket reference is provided:

1. **Resolve the canonical ticket ID** as `.claude/tce/tickets.md` describes (e.g. a bare number or `#123` → the canonical form used in filenames).
2. **Fetch the ticket's content** using the read mechanism from `tickets.md` (a file in `thoughts/shared/tickets/` for tmt, a CLI/MCP call for hosted systems). Read it FULLY now — even if it already appeared earlier in this conversation (e.g. you just authored it via `/tce:ticket` in the same session). Re-reading freshly anchors your attention on the requirements that drive this research; it does not discard the surrounding history.
3. **Find related thoughts documents** with the discovery script:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-0001
   ```

   This returns thoughts/ files with the ticket ID in their filename (research, plans, and — for tmt — the ticket itself). Note: This only finds documents that **directly reference the ticket in their filename**. For discovering documents that might be **contextually related** to the ticket's topic, use the `thoughts-locator` and `thoughts-analyzer` agents instead.

### Parent / Epic Context

**When the ticket has a parent or epic** — determine this per the "Parent / epic tickets" section of `tickets.md` (for tmt, a letter suffix like `[PREFIX]-0100a` marks a sub-ticket of `[PREFIX]-0100`) — you MUST also read the parent's documents for context:

1. **Fetch the parent ticket** via the mechanism in `tickets.md` — it provides the big-picture context for why this sub-ticket exists.
2. **Find the parent's thoughts documents**: Run `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" <parent-id>` to find the epic's research and plan.
3. **Read the parent's research and plan (if they exist)** — these are NOT mandatory to follow, but they provide valuable context:
   - The epic research may contain findings relevant to this sub-ticket
   - The epic plan may outline how this sub-ticket fits into the larger implementation
   - Use them as **inspiration and context**, not as binding instructions
   - The sub-ticket's own research should be the primary output — the epic context supplements it

## Ticket Sufficiency Check (before any research)

After reading the ticket (and its parent, if any) but **before spawning any
research agents**, assess whether the ticket is a sufficient research input.
"Sufficient" is deliberately scope-focused and style-agnostic — see also "What
tce needs from a ticket" in `tickets.md`:

1. **Scope is determinable** — what should change or be built, and roughly where the boundary is.
2. **Outcome is observable** — you can tell what "done" would look like, even informally.
3. **There's an anchor** — at least one concrete pointer into the system (feature, screen, command, error message) so research has somewhere to start.

Explicitly NOT required: business justification, formal acceptance criteria,
technical detail, or any particular section structure (tickets from other
systems or non-technical authors may be free-form text).

**If any of the three is missing**, ask the user focused clarifying questions —
one batched round, before researching in the wrong direction — presented per
the AskUserQuestion dialog guidelines (above), with concrete options where they
exist. Record the answers in the research document's context. If the ticket is
sufficient, proceed without bothering the user.

## Initial Setup:

When this command is invoked:

1. **Check if parameters were provided**:

   - If a ticket reference or research question was provided as a parameter,
     skip the default message and begin immediately: treat it as the research
     query — for a ticket reference, run Ticket Document Discovery and the
     Ticket Sufficiency Check (above) first, then proceed with the steps below

2. **If no parameters provided**, respond with:

```
I'm ready to research the codebase. Please provide your research question or area of interest, and I'll analyze it thoroughly by exploring relevant components and connections.

Tip: You can also invoke this command with a ticket ID or question directly: `/tce:research [PREFIX]-0001`
```

Then wait for the user's research query.

## Steps to follow once you have the research query (from the invocation parameter or the user's message):

1. **Read any directly mentioned files first:**

   - If the user mentions specific files (tickets, docs, JSON), read them FULLY — with the Read tool WITHOUT limit/offset parameters — yourself in the main context, before spawning any sub-tasks
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
   - Use the **codebase-analyzer** agent to understand HOW specific code works
   - Use the **codebase-pattern-finder** agent to find examples of existing patterns

   **For UI pattern research (when ticket involves frontend):**

   - Use the **codebase-pattern-finder** agent to explore UI component patterns
   - Document WHAT patterns exist, WHERE they are located, and each pattern's key characteristics — choosing between them happens in the planning phase

   **For thoughts directory:**

   - Use the **thoughts-locator** agent to discover what documents exist about the topic (explore all of thoughts/, not just the research subdirectory)
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
   - Keep the main context focused on synthesis — delegate deep file reading to the agents

4. **Wait for all sub-agents to complete and synthesize findings:**

   - Compile all sub-agent results (both codebase and thoughts findings)
   - Prioritize live codebase findings as the primary source of truth — always run fresh codebase research, never rely solely on existing research documents; thoughts/ findings supplement as historical context
   - Connect findings across different components
   - Include specific file paths and line numbers for reference
   - Verify all thoughts/ paths are correct and written exactly as they exist on disk, so references stay editable and navigable (with the tmt ticket system, tickets are in thoughts/shared/tickets/)
   - Highlight patterns, connections, and architectural decisions
   - Answer the user's specific questions with concrete evidence
   - **Check the tce config for drift (high-confidence only):** compare your live findings
     against `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and the backend adapter in
     `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md`. Note drift ONLY when it's concrete and
     observable — a stack present in manifests/lockfiles but missing from the profile (or
     vice versa), a test/typecheck/lint command the profile records that no longer exists, a
     code-map directory that's gone or moved, or a ticket system whose recorded
     access/create/status mechanism no longer matches the repo (e.g. `tickets.md` says tmt
     but `.claude/tmt/config` is gone). This is read-only — **never edit the config.** If
     such drift exists, record it for the "tce Config Drift" section (step 6) and the
     advisory (step 8). If nothing high-confidence stands out, skip this silently — do not
     flag cosmetic or low-confidence differences.

5. **Gather metadata for the research document:**

   - Gather metadata using git commands:
     - Current date/time: `date -u +"%Y-%m-%dT%H:%M:%SZ"`
     - Git commit: `git rev-parse HEAD`
     - Git branch: `git branch --show-current`
     - Repository name from: `git config --get remote.origin.url`
   - Filename: `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
     - Format: `YYYY-MM-DD-[PREFIX]-XXXX-description.md` where:
       - YYYY-MM-DD is today's date
       - [PREFIX]-XXXX is the canonical ticket ID per `tickets.md` (omit if no ticket)
       - description is a brief kebab-case description of the research topic
     - The canonical ID in the filename is what links the document to its ticket (the discovery script globs for it), so use it exactly
     - Examples:
       - With ticket: `2024-12-04-[PREFIX]-0001-multi-tenant-auth.md`
       - Without ticket: `2024-12-04-authentication-flow.md`

6. **Generate research document:**

   - Read `${CLAUDE_PLUGIN_ROOT}/references/research-document-template.md` now — in full, even if you read it earlier in this session — and structure the document exactly as its first template specifies (YAML frontmatter followed by the content sections, including the conditional ones where their conditions hold)
   - Fill in the metadata gathered in step 5 — NEVER write the research document with placeholder values
   - The document must be self-contained, with all necessary context

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
   - **If step 4 found config drift**, add a one-line, non-blocking advisory, e.g.
     "Note: tce config looks stale ([what drifted in profile.md or tickets.md]) —
     consider running `/tce:refresh`." Omit when there's no drift.
   - **Print the next command** for the user to run:
     ```
     Next command: `/tce:plan [PREFIX]-XXXX`
     ```
     (Replace [PREFIX]-XXXX with the actual ticket number from this research session)

9. **Commit the research document:**

   - After the research document is written and presented, use the `/tce:commit` command to commit it
   - This ensures the research is saved as a checkpoint before moving to the planning phase

10. **Handle follow-up questions:**
   - If the user has follow-up questions, append to the same research document
   - Update the frontmatter field `last_updated` to reflect the update
   - Add `last_updated_note: "Added follow-up research for [brief description]"` to frontmatter
   - Add a new section: `## Follow-up Research [timestamp]`
   - Spawn new sub-agents as needed for additional investigation
   - Continue updating the document
   - Once all follow-up questions are resolved, use the `/tce:commit` command to commit the updated research document

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

When the research topic involves code reuse/extension, add the **Impact
Analysis** section to the output. Its template is the second section of
`${CLAUDE_PLUGIN_ROOT}/references/research-document-template.md` — read it at
the moment you write the document, even if you read the file earlier in this
session.
