<!--
Runtime reference for the tce planning workflow. Read at the moment of use by
/tce:plan (in Step 3 before proposing the phase structure, and again in Step 4
when writing the plan document) and by /tce:work's planning phase — always in
full, even if already read earlier in the session. Never copied into consuming
projects.

Changes to this file are command-contract changes: the CLAUDE.md
composite-tracking rule applies (check work.md and quickfix.md in the same
commit). Downstream consumers depend on the template's structure:
/tce:implement executes the phases and their Automated/Manual success-criteria
checkboxes, and during implementation appends a terse `### Implementation log`
block to each phase plus an `## Implementation Closeout` section at the end
(formats owned by implement.md). Plans are authored WITHOUT those blocks.

Contents:
1. The plan document template (all sections; phases with success criteria)
2. Success criteria guidelines (automated/manual taxonomy + format example)
3. Note on implementation-time additions (log blocks — not authored in plans)
4. Structuring patterns (phase-ordering checklists for common change types)
5. UI/UX Approach section template (conditional, for plans involving UI work)
-->

# Plan document template

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

- Original ticket: `[PREFIX]-XXXX` (path or URL per the project's ticket system)
- Related research: `thoughts/shared/research/[relevant].md`
- Similar implementation: `[file:line]`
````

# Success criteria guidelines

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

# Implementation-time additions (do not author these)

During implementation, /tce:implement appends a terse `### Implementation log`
block as the last subsection of each phase (status, base/phase commit hashes,
what was done, issues, verification results) and an `## Implementation
Closeout` section at the very end of the document. Their formats are owned by
implement.md. **A plan is always authored without them** — never include log
blocks, a closeout section, or pre-ticked success-criteria checkboxes when
writing a plan.

# Structuring patterns

Phase-ordering checklists for common change types — use them when shaping the
plan's phase structure:

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

# UI/UX Approach section template

Include this section in the plan when it involves UI work (UI/UX decisions are
made in /tce:plan Step 3):

```markdown
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
