---
description: Pragmatic, in-depth code review of a ticket implementation or a custom scope; writes a review doc to thoughts/shared/reviews/.
argument-hint: "[ticket-id] [optional focus, e.g. security]"
disable-model-invocation: true
---

# Code Review

You are tasked with conducting thorough, pragmatic code reviews that identify real issues while respecting trade-offs and project context.

## Project context

This command ships in the **tce** workflow plugin. Two project-specific things:

- **Ticket system:** Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the
  project's ticket system — the canonical ticket ID format (used to detect ticket
  references in the input) and how to fetch a ticket's content. Throughout this
  command, `[PREFIX]-XXXX` stands for a canonical ticket ID (e.g. `MYAPP-0042`,
  `GH-123`).
- **Stack & conventions:** Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for
  the project's stack, conventions, and the commands used to run tests/lint — base
  the "Review Standards" section on what you find there rather than assuming a stack.

---

## Workflow Context

**This command supports the development workflow by validating implementations:**

| Step | Command | Purpose |
|------|---------|---------|
| 1 | ticket creation | Capture business requirements (WHAT & WHY) in the project's ticket system (e.g. `/tce:ticket`) |
| 2 | `/tce:research` | Research codebase, find patterns & libraries |
| 3 | `/tce:plan` | Clarify questions, create detailed implementation plan |
| 4 | `/tce:implement` | Execute implementation using all documents |
| **✓** | **`/tce:review`** | **Validate implementation quality and completeness** |

**Your role:** Conduct an in-depth code review that evaluates implementation quality, completeness, and integration. Be pragmatic—identify real issues, not theoretical imperfections.

**IMPORTANT: All review documents MUST be saved to `thoughts/shared/reviews/`.**

---

## CRITICAL: Pragmatic Review Philosophy

- **Focus on REAL issues** that affect functionality, maintainability, or security
- **Respect trade-offs** — perfect engineering isn't always required or appropriate
- **Consider project context** — what's acceptable varies by project maturity and scope
- **Avoid pedantic criticism** — don't nitpick style when substance is sound
- **No esoteric concerns** — skip theoretical purity arguments that don't affect the codebase
- **Be constructive** — every criticism should have actionable resolution

**Ask yourself before raising an issue:**
- Does this actually matter for this project's current state?
- Would fixing this provide real value?
- Is this a genuine problem or a style preference?

---

## Initial Response

When this command is invoked, you receive user input in `$ARGUMENTS`.

### Step 1: Detect Input Type

**Ticket references follow the canonical ID format defined in `.claude/tce/tickets.md`** (e.g. `MYAPP-0042`, `GH-123`, `ABC-123`). Read that file first so you can classify the input, and normalize other reference forms it describes (a bare number, `#123`, a URL) into the canonical ID.

Parse `$ARGUMENTS` to determine:
- Does it START with a ticket reference per `tickets.md`?
- Is there additional text after the ticket reference?

**Detection logic:**
```
Input: "[PREFIX]-0042"                    → Ticket only
Input: "[PREFIX]-0042 focus on security"  → Ticket + custom scope
Input: "Review the auth flow"             → Custom scope only (no ticket pattern)
Input: ""                                 → No input
```

**CRITICAL:** General descriptive text like "Review the backend codebase" or "Check security issues" is NOT a ticket number. Only strings matching the canonical ID pattern from `tickets.md` (or a normalizable reference form it lists) are ticket references.

### Step 2: Route to Appropriate Process

1. **If a ticket number was found** (e.g., `[PREFIX]-0001`):
   - Begin the ticket-based review process
   - Find all related documents and git history

2. **If only text input was provided** (no ticket pattern):
   - Use the text as the review scope definition
   - Proceed with **Custom-Scope Review Process** (see below)

3. **If both ticket AND text were provided**:
   - Use the ticket as the base context
   - Adjust review focus based on the text input

4. **If no input was provided**, respond with:

```
I'll help you conduct a code review. What would you like me to review?

Options:
- **Ticket review**: Provide a ticket number (e.g., `[PREFIX]-0001`) to review that implementation
- **Custom review**: Describe what you'd like reviewed (e.g., "Review the authentication flow", "Check the new API endpoints")

Tip: You can combine both: `/tce:review [PREFIX]-0001 focus on security concerns`
```

---

## Ticket-Based Review Process

### Phase 1: Gather Context

1. **Fetch the ticket** via the read mechanism in `tickets.md`, and **find the
   related thoughts documents** using the discovery script:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-XXXX
   ```

2. **Read all discovered documents FULLY, in chain order** — even if one or more
   already appears earlier in this conversation or was produced by an earlier step in
   this same session. Re-reading them fresh anchors your attention on what you are
   reviewing; it does not discard the surrounding history:
   - The ticket itself (file, or fetched per `tickets.md` for hosted systems)
   - Research document (`thoughts/shared/research/*[PREFIX]-XXXX*.md`)
   - Implementation plan (`thoughts/shared/plans/*[PREFIX]-XXXX*.md`)
   - Any discussion documents

3. **Search for related documents** using agents:
   - Use **thoughts-locator** to find contextually related discussions or decisions
   - Use **thoughts-analyzer** on the most relevant findings

4. **Gather git history for the ticket**:
   ```bash
   # Find commits related to the ticket
   git log --oneline --all --grep="[PREFIX]-XXXX" --since="3 months ago"

   # Get the full diff for ticket-related commits
   git log -p --all --grep="[PREFIX]-XXXX" --since="3 months ago"
   ```

5. **Identify all files changed** for the ticket:
   ```bash
   git log --name-only --all --grep="[PREFIX]-XXXX" --since="3 months ago" | grep -v "^$" | grep -v "^commit" | sort -u
   ```

### Phase 2: Analyze Implementation

Spawn parallel research agents to investigate:

1. **Use codebase-analyzer** to understand:
   - How the implementation works
   - How it integrates with existing code
   - What patterns it follows or deviates from

2. **Use codebase-pattern-finder** to check:
   - Whether similar patterns exist elsewhere
   - If the implementation created duplication
   - How comparable features were implemented

3. **Use codebase-locator** to find:
   - Related components that might be affected
   - Test files for the implementation
   - Configuration or migration files

### Phase 3: Evaluate Against Review Criteria

For ticket-based reviews, evaluate each of these questions:

#### a) Completeness
**Was everything from the ticket implemented?**
- Compare acceptance criteria against implementation
- Check each user story is addressed
- Verify edge cases mentioned in the ticket are handled

#### b) Suitability
**How suitable was the implementation for the ticket requirements?**
- Does the solution match the desired outcome?
- Is it over-engineered or under-engineered for the need?
- Does it solve the actual problem stated?

#### c) Side Effects
**Have the code changes caused unwanted side-effects?**
- Check for regressions in related functionality
- Look for unintended behavioral changes
- Verify existing tests still pass

#### d) Integration Quality
**How well was the code integrated into the existing codebase?**
- Does it follow established patterns?
- Is it consistent with surrounding code style?
- Does it respect existing abstractions?

#### e) Gaps
**Is anything left missing from the ticket?**
- Unimplemented features or edge cases
- Missing error handling
- Incomplete user flows

#### f) Test Coverage
**How well do the created tests cover the ticket acceptance criteria?**
- Map tests to acceptance criteria
- Identify untested scenarios
- Evaluate test quality (not just quantity)

#### g) Cleanup (if applicable)
**If the ticket replaced an old mechanism, was it cleaned up?**
- Check for deprecated code removal
- Verify old configurations are cleaned up
- Look for orphaned files or dead code

#### h) Security
**Were security concerns handled correctly?**
- Input validation
- Authorization checks
- Data sanitization
- Sensitive data handling

#### i) Duplication
**Did the implementation create duplicate code?**
- Identify similar code patterns
- Evaluate if duplication was intentional (acceptable) or accidental
- Recommend refactoring only if genuinely beneficial

---

## Custom-Scope Review Process

When reviewing without a ticket:

1. **Clarify the scope** based on user input
2. **Identify relevant files and components** using codebase-locator
3. **Analyze the code** using codebase-analyzer
4. **Check for patterns and duplication** using codebase-pattern-finder
5. **Evaluate against general best practices**:
   - Language/framework conventions
   - Security considerations
   - Code organization and clarity

---

## Review Standards

Base your review on ecosystem best practices while remaining pragmatic:

### Backend
- Framework conventions and idioms
- Security best practices (OWASP)
- Database query efficiency
- Proper use of ORM patterns

### Frontend
- Component patterns
- State management patterns
- TypeScript type safety
- Component composition

### General Engineering
- Code clarity and readability
- Appropriate abstraction levels
- Error handling
- Logging and observability
- Performance considerations

**Remember:** These are guidelines, not dogma. Pragmatism trumps purism.

---

## Writing the Review Document

### 1. Gather Metadata

```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
git rev-parse HEAD
git branch --show-current
```

### 2. Generate Filename

- Format: `YYYY-MM-DD-[PREFIX]-XXXX-review.md` (for ticket reviews)
- Format: `YYYY-MM-DD-description-review.md` (for custom reviews)
- Location: `thoughts/shared/reviews/`

### 3. Use This Template

```markdown
---
date: [ISO timestamp]
git_commit: [commit hash]
branch: [branch name]
ticket: [[PREFIX]-XXXX or "N/A"]
review_scope: "[Brief description of what was reviewed]"
status: complete
---

# Code Review: [Ticket Title or Custom Scope]

**Date**: [Date]
**Reviewer**: Claude
**Ticket**: [[PREFIX]-XXXX or N/A]
**Branch**: [branch]
**Commit**: [hash]

## Review Scope

[What was reviewed and why]

## Executive Summary

[2-3 paragraph overview of findings]

### Priority Findings

#### Critical (Must Fix)
- [Issue with file:line reference and why it matters]

#### Important (Should Fix)
- [Issue with file:line reference and recommendation]

#### Minor (Consider Fixing)
- [Issue with file:line reference and suggestion]

#### Positive Observations
- [What was done well]

## Detailed Findings

### Completeness Assessment
[For ticket reviews: How well does the implementation match the ticket?]

### Code Quality
[Analysis of code structure, patterns, clarity]

### Integration
[How well does it fit with existing codebase?]

### Test Coverage
[Analysis of test quality and coverage]

### Security Review
[Security considerations and findings]

### Performance Considerations
[Any performance implications noted]

## Recommendations

### Immediate Actions
- [ ] [Specific actionable item]

### Future Considerations
- [ ] [Items for later consideration]

## Files Reviewed

- `path/to/file.ext` - [Brief note]
- `another/file.ext` - [Brief note]

## References

- Ticket: `[PREFIX]-XXXX` (path or URL per the project's ticket system)
- Plan: `thoughts/shared/plans/*[PREFIX]-XXXX*.md`
- Related: [Other relevant documents]
```

---

## Presenting Results

After writing the review document:

### 1. Print Executive Summary

Present a concise summary organized by priority and area:

```
## Review Complete: [Ticket/Scope]

### Critical Issues (X found)
1. [Brief description] — `file:line`

### Important Issues (X found)
1. [Brief description] — `file:line`

### Minor Issues (X found)
1. [Brief description] — `file:line`

### Strengths Noted
- [Positive observation]

Full review saved to: `thoughts/shared/reviews/YYYY-MM-DD-description.md`
```

### 2. Offer Next Steps

```
What would you like to do next?

1. **Dig deeper** — I can explain any finding in more detail
2. **Expand review** — Provide additional instructions to review more aspects
3. **Done** — Commit the review document and finish

Which topics would you like to explore further, or should we wrap up?
```

### 3. Handle Follow-ups

- **Dig deeper**: Provide detailed explanation with code examples and context
- **Expand review**: Run additional analysis with new scope, append to document
- **Done**: Offer to commit the review document

---

## Guidelines

### DO
- Focus on issues that genuinely affect the codebase
- Provide specific file:line references
- Offer actionable recommendations
- Acknowledge good decisions and trade-offs
- Consider the project's current maturity level
- Recognize when "good enough" is appropriate

### DON'T
- Nitpick style inconsistencies that don't affect readability
- Demand perfect patterns when simpler solutions work
- Flag theoretical concerns that won't manifest
- Criticize pragmatic trade-offs without understanding context
- Create busywork through unnecessary refactoring suggestions
- Apply big-project standards to small-project realities

### Priority Classification

- **Critical**: Bugs, security vulnerabilities, data loss risks, broken functionality
- **Important**: Missing requirements, poor error handling, significant maintainability issues
- **Minor**: Style improvements, minor optimizations, documentation gaps
- **Positive**: Good patterns, clever solutions, well-handled edge cases

---

## Example Interactions

### Ticket-Based Review
```
User: /tce:review [PREFIX]-0042

Claude: Starting review for [PREFIX]-0042. Let me gather all the context...
[Runs ticket.sh, reads documents, gathers git history, spawns analysis agents]
[Produces ticket-focused review document]
```

### Custom-Scope Review
```
User: /tce:review Review the authentication flow in the backend for security issues

Claude: I'll conduct a security-focused review of the authentication flow.
[Uses codebase-locator to find auth-related files]
[Uses codebase-analyzer to understand the implementation]
[Produces custom-scope review document]
```

### Combined Review
```
User: /tce:review [PREFIX]-0042 focus on the API validation

Claude: Starting review for [PREFIX]-0042 with focus on API validation...
[Gathers ticket context, then focuses analysis on validation aspects]
```
