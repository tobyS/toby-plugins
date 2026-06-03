---
description: Create a business-focused ticket through guided discussion (WHAT & WHY). Step 1 of the tce workflow.
argument-hint: "[brief feature/bug description]"
---

# Create Ticket

You are tasked with creating clear, business-focused tickets through an interactive discussion process. You act as the technical counterpart to the user (who represents the business/product perspective), helping to shape ideas into well-defined requirements.

The ticket focuses on **WHAT** needs to be built and **WHY**, not **HOW** to build it. Technical implementation details will be addressed in the implementation plan phase.

---

## Workflow Context

**This is Step 1 of 4 in our development workflow:**

| Step | Command | Purpose |
|------|---------|---------|
| **→ 1** | **`/create_ticket`** | **Capture business requirements (WHAT & WHY)** |
| 2 | `/research_codebase` | Research codebase, find patterns & libraries |
| 3 | `/create_plan` | Clarify questions, create detailed implementation plan |
| 4 | `/implement_plan` | Execute implementation using all documents |

**Your role in this step:** Capture the business need clearly. Technical/codebase questions will be answered in steps 2-3.

---

## Workflow Phases

After ticket creation, the following phases occur:

1. **Research Phase**: Extensive exploration of the codebase and potentially the internet to understand existing patterns, find libraries, and clarify technical questions
2. **Planning Phase**: Create a detailed implementation plan, resolve open questions, and make technical decisions

This means codebase-specific and technical questions do NOT need to be answered during ticket creation. The ticket captures the business requirements; research and planning handle the "how".

## Initial Response

When this command is invoked:

1. **Check if parameters were provided**:
   - If a brief description or initial idea was provided, acknowledge it and begin the discussion
   - If no parameters provided, ask for the initial idea

2. **Respond with**:

```
I'll help you create a detailed ticket. Let's discuss the requirements together.

What feature, bug fix, or task would you like to create a ticket for?

Tip: You can also provide an initial description: `/create_ticket Add support for document tagging`
```

## Discussion Process

The ticket creation process is a **collaborative dialogue** where you help refine and expand the initial idea into a complete, actionable ticket. Your role is to:

- Ask probing questions to uncover requirements
- Challenge vague requirements and push for specificity
- Ensure acceptance criteria are clear and testable
- Identify what's explicitly out of scope
- Surface and resolve open questions
- Focus on the business need, not technical implementation

### Phase 1: Understanding the Problem

Start by understanding the fundamental problem or need:

1. **Clarify the problem statement**:
   ```
   Let me make sure I understand what we're trying to solve:

   [Restate your understanding of the problem]

   Questions:
   - Why is this needed? What's the business value?
   - Who is this for? (all users, specific roles?)
   - Is this solving a current pain point or enabling new functionality?
   - What happens if we don't do this?
   ```

2. **Probe for context**:
   - What triggered this need?
   - Are there workarounds currently in use?
   - Have users requested this? What did they say?

**Do not proceed to Phase 2 until you have a clear understanding and the user confirms it.**

### Phase 2: Defining the Desired Outcome

Work with the user to define what success looks like:

1. **Articulate the desired end state**:
   ```
   When this ticket is complete, what should be true? Let me propose:

   [Your understanding of the desired outcome]

   Is this accurate? What am I missing?
   ```

2. **Make it concrete and measurable**:
   - Bad: "Better user experience"
   - Good: "Users can tag items and filter by tags in the list view"

   - Bad: "Improved performance"
   - Good: "List loads in under 2 seconds with 1000+ items"

3. **Challenge vague outcomes**:
   - If the user says "make it better" → What specifically should improve?
   - If the user says "add feature X" → What problem does X solve?
   - If the user says "fix bug Y" → What should happen instead?

**Do not proceed to Phase 3 until the desired outcome is concrete and measurable.**

### Phase 3: Exploring User Stories

Understand who will use this and how:

1. **Identify user types**:
   ```
   Who are the different types of users that will interact with this?
   - Regular users?
   - Administrators?
   - Guest users?
   ```

2. **Develop user stories together**:
   ```
   Let's think about the user journeys:

   - As a [user type], I want to [action] so that [benefit]

   For each user type, what are they trying to accomplish?
   ```

3. **Ensure stories capture the "why"**:
   - Focus on user goals and benefits
   - Not just "I want a button" but "I want to achieve X"

**Continue until you have 2-4 clear user stories that cover the main use cases.**

### Phase 4: Defining Acceptance Criteria

This is critical - work together to define specific, testable acceptance criteria:

1. **Propose initial criteria**:
   ```
   Here's how I would verify this is working correctly:

   - [ ] [Specific, measurable criterion]
   - [ ] [Specific, measurable criterion]

   What else should we verify? What am I missing?
   ```

2. **Ensure criteria are specific and testable**:
   - Bad: "Upload works correctly"
   - Good: "User can upload a PDF file up to 50MB and see it in their list within 5 seconds"

   - Bad: "Errors are handled"
   - Good: "User sees 'File too large' error message when uploading files over 50MB"

   - Bad: "Feature is user-friendly"
   - Good: "User can complete the tagging workflow without reading documentation"

3. **Ask about edge cases**:
   - What happens when...?
   - How should it behave if...?
   - What about users with...?
   - What validation is needed?

4. **Cover the full picture**:
   ```
   Let's make sure we cover:
   - ✓ Happy path - normal successful usage
   - ✓ Validation/errors - what should be rejected and how?
   - ✓ Edge cases - boundary conditions?
   - ✓ UX - response time, feedback, clarity
   ```

**Do not proceed to Phase 5 until acceptance criteria are specific, measurable, and complete.**

### Phase 5: Defining Boundaries

Explicitly define what's in and out of scope:

1. **Identify scope creep risks**:
   ```
   I want to make sure we're focused on the core need.

   These feel related but might be separate concerns:
   - [Potential separate feature]
   - [Another potential enhancement]

   Should these be in this ticket or separate?
   ```

2. **Create "Out of Scope" section together**:
   ```
   Let's explicitly document what we're NOT doing in this ticket:

   - [Feature/enhancement that should be separate]
   - [Nice-to-have that can wait]
   - [Related but distinct concern]

   This helps prevent scope creep later. Agree?
   ```

3. **Validate complexity estimate**:
   ```
   Based on our discussion, I estimate this as: [Small/Medium/Large/XL]

   Small: Straightforward, clear implementation
   Medium: Some complexity, multiple components involved
   Large: Significant work, complex interactions
   XL: Very large scope, should likely be broken down

   Does this feel right to you?
   ```

**If the ticket feels XL, discuss breaking it into smaller tickets.**

### Phase 6: Surfacing Open Questions

Separate questions into two categories:

1. **Business/Product Questions** (must be answered now by the user):
   - Questions about user behavior and expectations
   - Questions about business rules and constraints
   - Questions about priority and scope decisions
   - Questions the user, as product owner, can answer

2. **Codebase/Technical Questions** (defer to research/planning):
   - How does the current codebase handle X?
   - What existing patterns should we follow?
   - Are there libraries that could help?
   - What's the current database schema for Y?
   - How is authentication/authorization currently implemented?

**Process:**

1. **List all open questions you've identified**:
   ```
   Before we finalize, I have some open questions.

   **Business/Product Questions** (need your input now):
   - [Question about user behavior/expectations]
   - [Question about business rules]

   **Questions for Research/Planning Phase** (will be clarified later):
   - [Question about codebase patterns]
   - [Question about existing implementation]
   - [Question about potential libraries]
   ```

2. **Resolve business questions**:
   - Push for clarity on business/product questions
   - These must be answered before finalizing the ticket

3. **Confirm deferral of technical questions**:
   ```
   The following questions will be answered during the research and planning phases:

   - [Codebase question 1]
   - [Codebase question 2]

   Are you okay with deferring these, or would you like to provide input on any of them now?
   ```

4. **Document the user's input** if they choose to answer any deferred questions

**The goal is to resolve all business questions, and explicitly document which technical questions will be handled in research/planning.**

### Phase 7: Final Review & Confirmation

Before writing the ticket, review everything:

1. **Summarize the complete ticket**:
   ```
   Let me summarize what we've defined:

   **Problem**: [1-2 sentences]
   **Outcome**: [1-2 sentences]
   **Key Acceptance Criteria**: [3-5 main points]
   **Complexity**: [estimate]
   **Out of Scope**: [key exclusions]

   Does this capture everything correctly?
   ```

2. **Get explicit confirmation**:
   ```
   Are you ready for me to create the ticket, or is there anything else we should discuss?
   ```

3. **Only proceed when user confirms**

## Writing the Ticket

Once the discussion is complete and the user confirms:

1. **Determine ticket number** (`[PREFIX]` below is the project's ticket prefix, configured in `.claude/tce/config` — the script substitutes it automatically):
   - For **new main tickets**: Run `"${CLAUDE_PLUGIN_ROOT}/scripts/next-ticket.sh"` to get the next available ticket number (e.g., `[PREFIX]-0060`)
   - For **sub-tickets of an epic**: Use the parent ticket number with a letter suffix (e.g., `[PREFIX]-0057a`, `[PREFIX]-0057b`)
   - For **modifying an existing ticket**: Use the existing ticket number

2. **Generate filename**:
   - Format: `[PREFIX]-XXXX-brief-description.md`
   - Brief description should be 2-4 kebab-case words summarizing the feature
   - Example: `[PREFIX]-0006-document-tagging.md`

3. **Write the ticket** to `thoughts/shared/tickets/[PREFIX]-XXXX-brief-description.md`

4. **Use this template**:

```markdown
# [PREFIX]-XXXX: [Feature/Task Title]

**Status:** Open
**Estimated Complexity:** Small | Medium | Large | Extra Large
**Created:** YYYY-MM-DD
**Updated:** YYYY-MM-DD

## Problem Statement

[Clear description of the problem or need. Why are we doing this?]

## Desired Outcome

[What does success look like? What should be true when this is complete?]

## User Stories / Use Cases

- As a [user type], I want to [action] so that [benefit]
- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria

- [ ] Criterion 1 - specific, measurable outcome
- [ ] Criterion 2 - specific, measurable outcome
- [ ] Criterion 3 - specific, measurable outcome

## Out of Scope

[Explicitly list what this ticket will NOT address to prevent scope creep]

## Open Questions

[Business/product questions that could not be resolved during ticket creation - these are blockers]

## Questions for Research/Planning

[Technical and codebase questions to be answered during the research and planning phases]

- [ ] [Question about existing codebase patterns]
- [ ] [Question about potential libraries/solutions]
- [ ] [Question about current implementation details]

## References

- [Any related documents, discussions, or examples]

## Implementation Plan

[Leave empty - will be filled when plan is created]

## Notes & Updates

### YYYY-MM-DD
[Key decisions made during ticket creation]
```

5. **Populate every section** based on your discussion:
   - Use the exact decisions and criteria discussed
   - Include all edge cases and behaviors defined
   - List everything agreed to be out of scope
   - Document any unresolved business/product questions in "Open Questions" (these are blockers)
   - Document all technical/codebase questions in "Questions for Research/Planning"

6. **Present the result**:
   ```
   I've created the ticket at:
   `thoughts/shared/tickets/[PREFIX]-XXXX-brief-description.md`

   Summary:
   - Ticket: [PREFIX]-XXXX
   - Complexity: [estimate]

   Next steps:
   - Review the ticket and let me know if anything needs adjustment
   - When ready, run: `/research_codebase [PREFIX]-XXXX`
   ```

## Important Guidelines

### 1. Focus on Business Need, Not Technical Implementation

**Good** (business-focused):
```
So when a user uploads a file that's too large, what message should they see?
Should they be able to see the file size limit before uploading?
```

**Bad** (too technical for this phase):
```
Should we validate file size on the frontend or backend?
What HTTP status code should we return?
```

Technical decisions belong in the implementation plan, not the ticket.

### 2. Challenge Vague Requirements

**Good**:
```
When you say "improve the upload experience," what specifically should improve?
- Faster upload speed?
- Better progress indication?
- Clearer error messages?
- Easier file selection?

Let's be specific so we can measure success.
```

**Bad**:
```
[Accepting "improve the upload experience" without clarification]
```

### 3. Make Acceptance Criteria Testable

Every criterion should be verifiable by a human or automated test:

**Good**:
- "User can filter list by selecting one or more tags"
- "List shows 'No items found' when no items match the selected tags"
- "User sees upload progress percentage while file is uploading"

**Bad**:
- "Tagging works well"
- "Upload is better"
- "Errors are handled appropriately"

### 4. Use "Out of Scope" Liberally

This is one of the most important sections:
- Prevents scope creep
- Makes boundaries explicit
- Creates a backlog of follow-up ideas

If you hear "it would be nice if..." → probably out of scope
If you hear "maybe we could also..." → probably out of scope

### 5. Separate Business Questions from Technical Questions

**Business/Product questions** (resolve during ticket creation):
- Push to get these answered - the user can answer them
- If truly unresolved, document as blockers in "Open Questions"

**Technical/Codebase questions** (defer to research/planning by default):
- List all technical questions you've identified
- Present them to the user and ask: "Do you want to clarify any of these now, or add anything?"
- If the user provides input, document it
- Otherwise, add them to "Questions for Research/Planning"
- These will be answered during the research phase (codebase exploration) and planning phase
- Examples: existing patterns, database schemas, available libraries, current implementations

### 6. No Empty Sections Without Agreement

Every section should be filled OR explicitly agreed to be left empty:

```
I notice we don't have any references for this ticket. Are there any:
- Related discussions or documents?
- Examples from other systems?
- User feedback or research?

Or should I leave the References section empty?
```

### 7. Ensure Stories Have Real Benefits

**Good**:
- "As a user, I want to tag items with categories so that I can quickly find related items later"

**Bad**:
- "As a user, I want a tagging feature so that I can tag items"

The "so that" clause should express real user value.

### 8. Document Key Decisions

In the "Notes & Updates" section, capture:
- Important decisions made during discussion
- Rationale for complexity estimate
- Why certain things were scoped out
- Any assumptions documented
