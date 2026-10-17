<!--
Runtime reference for the tce research workflow. Read at the moment of writing
a research document by the `researcher` agent (Process step 7), which every
step command that researches dispatches (/tce:research, /tce:work,
/tce:quickfix) — always in full, even if already read earlier in the session.
Never copied into consuming projects.

Changes to this file are command-contract changes: check the `researcher`
agent in the same commit. Step numbers below refer to the researcher's
numbered Process steps. Downstream consumers depend on the frontmatter: the
step loop (work-loop.md Step 7) reads `git_commit`, the planner reads
`last_updated`. Note that `git_commit` is
the commit the research was written at and is not guaranteed to stay reachable
— if the work lands through a squash or rebase merge, that commit is no longer
part of the main branch's history. work-loop.md handles this by resolving a
baseline (falling back to the commit that introduced this document); do not
treat `git_commit` as a stable anchor elsewhere.

Contents:
1. The research document template (YAML frontmatter + all body sections)
2. The Impact Analysis section template (conditional)
-->

# Research document template

Structure the research document with YAML frontmatter followed by content:

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

**Date**: [Current date and time with timezone from step 6]
**Git Commit**: [Current commit hash from step 6]
**Branch**: [Current branch name from step 6]
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

## Defect Mechanism (only for defect tickets)

[Include this section ONLY when the ticket describes a defect (existing
behavior that diverges from intended behavior). Trace the mechanism with
file:line evidence: the intended behavior (and where it's defined or implied),
the actual behavior, and the point(s) where they diverge, including how the
faulty state propagates to the observed symptom. Document the mechanism only —
no fix proposals and no code-quality critique; choosing the fix is the
planning phase's job. Omit the section entirely for non-defect tickets.]

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

## Related Research

[Links to other research documents in thoughts/shared/research/]

## Open Questions

[Any areas that need further investigation]

## tce Config Drift (only if found)

[Include this section ONLY if step 5 found high-confidence drift between the
codebase and `.claude/tce/profile.md` or the backend adapter in
`.claude/tce/tickets.md`. List each concrete mismatch, then recommend running
`/tce:refresh` to reconcile the config. Omit the section entirely when there is
no drift.]
```

# Impact Analysis section template

Include this section when the research topic involves code that will be reused
or extended for a new purpose (see "Researching Code for Reuse or Extension" in
/tce:research):

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
