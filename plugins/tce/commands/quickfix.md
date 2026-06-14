---
description: Rapidly fix a small, well-understood issue by chaining the full workflow (ticket → research → plan → implement) autonomously, with minimal interruption.
argument-hint: "[bug or correction to fix]"
---

# Quickfix

You are tasked with rapidly fixing a small, well-understood issue through an autonomous workflow that chains together the standard development process commands — but without unnecessary user interaction. The goal is speed: clarify what's needed, then execute the full pipeline (ticket, research, plan, implement) with minimal interruption.

## Project context

This command ships in the **tce** workflow plugin and is stack- and ticket-system-agnostic. It is a
**composite command** that chains ticket creation with the single-step workflow
commands (`/tce:research` → `/tce:plan` → `/tce:implement`, plus
`/tce:commit`) and runs them autonomously.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack, conventions, and the exact test/lint/typecheck commands to run during verification and commits. If it's missing, suggest the user run `/tce:init`.
- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the project's ticket system — quickfix uses its "Creating a ticket" section. **Precondition:** if that section says ticket creation is not allowed, STOP immediately: tell the user to create the ticket in their ticket system themselves and run `/tce:work <ticket-id>` instead.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md` (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- When these instructions tell you to invoke another workflow command **via the Skill tool**, use its namespaced name (e.g., `tce:plan`). In prose, sibling commands are referenced by their installed, prefixed name (e.g., `/tce:plan`).

**This command must stay in lock-step with the single-step commands it chains.** Each phase below delegates to (or mirrors) `/tce:research`, `/tce:plan`, `/tce:implement`, and `/tce:commit` (ticket creation mirrors the project's ticket system conventions, e.g. tmt's `/tmt:create` template). The quality and outputs of each phase must be identical to running those commands manually — the only difference is the reduced user interaction.

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

## Workflow Overview

The quickfix command orchestrates the full development workflow autonomously:

| Step | What Happens | User Interaction |
|------|-------------|------------------|
| 1 | Understand the issue | **Yes** — clarify until the fix is fully understood |
| 2 | Create ticket (in the configured ticket system) | **No** — auto-filled from understanding, size is always "Small" |
| 3 | Commit ticket (only if the ticket is a file in the repo) | **No** — automatic |
| 4 | Research codebase | **No** — automatic, results are NOT reviewed by user |
| 5 | Commit research | **No** — automatic |
| 6 | Create plan | **Only if** there are open questions or design decisions |
| 7 | Commit plan | **No** — automatic |
| 8 | Implement plan | **Only if** there are blockers or ambiguities |
| 9 | Final summary | **Yes** — present what was done |

**Guiding principle:** User interaction is absolutely permitted when something is unclear or a decision must be taken. But if everything is clear, the command works autonomously through all steps without pausing for review or confirmation.

---

## Phase 1: Understand the Issue

When this command is invoked:

1. **Check if a description was provided as argument:**
   - If yes, analyze it and assess whether you fully understand what needs to be fixed
   - If no, ask: "What issue would you like me to quickfix?"

2. **Assess clarity** — you must understand ALL of the following before proceeding:
   - What is broken or needs changing?
   - What should the correct behavior be?
   - Where in the application/codebase does this occur? (consult `profile.md` for the project's components/structure)

3. **If anything is unclear, ask focused questions.** Be direct and specific,
   following the AskUserQuestion dialog guidelines (above): concrete options
   where they exist, plain prose only for genuinely free-form answers:
   ```
   I want to make sure I understand the fix correctly:

   - [Specific clarification question]
   - [Another question if needed]
   ```

4. **Once everything is clear, confirm your understanding in one brief statement and proceed immediately.** Do NOT ask for permission to proceed — just do it:
   ```
   Understood: [one-sentence summary of the fix]. Starting quickfix pipeline...
   ```

---

## Phase 2: Create Ticket (Autonomous)

Create the ticket automatically — no user interaction needed — **via the
"Creating a ticket" mechanism in `tickets.md`** (if it says creation is not
allowed, you should have stopped in Phase 1; do so now).

- **For hosted systems** (GitHub Issues, Jira, Linear, …): run the documented
  create mechanism with a concise title and a body carrying the same content as
  the template below (problem, desired outcome, acceptance criteria, out of
  scope). Note the new ticket's canonical ID; skip the commit step 4 (there is
  no file to commit).
- **For tmt**: determine the next ticket number as `tickets.md` describes, generate
  a brief kebab-case description (2-4 words), and write the ticket to
  `thoughts/shared/tickets/[PREFIX]-XXXX-description.md` using the standard tmt
  template (mirrors `/tmt:create`):

```markdown
# [PREFIX]-XXXX: [Fix Title]

**Status:** Open
**Estimated Complexity:** Small
**Created:** YYYY-MM-DD
**Updated:** YYYY-MM-DD

## Problem Statement

[What is broken/wrong — from your understanding]

## Desired Outcome

[What should happen after the fix]

## User Stories / Use Cases

- As a [user type], I want [correct behavior] so that [benefit]

## Acceptance Criteria

- [ ] [Specific, testable criterion]
- [ ] [Another criterion if needed]
- [ ] Existing tests continue to pass

## Out of Scope

- [Anything related but not part of this fix]

## Open Questions

None — this is a well-understood quickfix.

## Questions for Research/Planning

- [ ] [Any codebase questions needed to implement the fix]

## References

- Quickfix initiated via `/tce:quickfix` command

## Implementation Plan

[Leave empty — will be filled when plan is created]

## Notes & Updates

### YYYY-MM-DD
- Quickfix ticket auto-created from `/tce:quickfix` command
```

4. **Immediately commit the ticket** (tmt / file-based tickets only) using the `/tce:commit` workflow:
   - Stage only the ticket file
   - Commit message: `docs([PREFIX]-XXXX): create quickfix ticket for [brief description]`
   - This is a docs-only commit — skip tests/typecheck/lint

---

## Phase 3: Research Codebase (Autonomous)

**CRITICAL: This phase MUST produce a research document written to disk.** Do NOT skip research, do NOT keep findings only in your head, and do NOT move to planning without a written research file.

Follow the `/tce:research` process autonomously — no user interaction:

1. **Read the ticket** created in Phase 2
2. **Decompose research questions** from the ticket's "Questions for Research/Planning" section
3. **Spawn parallel sub-agents** to research the codebase (the same agents `/tce:research` uses):
   - Use **codebase-locator** to find relevant files and components
   - Use **codebase-analyzer** to understand how the affected code works
   - Use **codebase-pattern-finder** to find similar patterns to follow
   - Use **thoughts-locator** / **thoughts-analyzer** when prior thoughts may be relevant
   - Use **web-search-researcher** if the fix touches third-party tools/libraries
   - After the agents return, compare findings against `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for high-confidence drift (a stack the profile omits, a vanished test/typecheck/lint command, a moved or removed code-map directory); if found, include the "Profile Drift" section in the research document recommending `/tce:refresh` — read-only, **never edit the profile**
   - Do NOT present findings to the user. Do NOT ask follow-up questions. Do NOT wait for user feedback.
4. **Gather metadata** using git commands (date, `git rev-parse HEAD`, `git branch --show-current`, repo URL)
5. **Write the research document** to `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md` using the standard `/tce:research` template (YAML frontmatter + findings + code references). Include the **Impact Analysis** section if the fix reuses/extends shared code.

**MANDATORY OUTPUT**: A research document file MUST exist at `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-*.md` after this phase. If it doesn't exist on disk, the phase failed — go back and write it.

6. **Immediately commit the research** using the `/tce:commit` workflow:
   - Stage only the research file
   - Commit message: `docs([PREFIX]-XXXX): research codebase for quickfix`
   - This is a docs-only commit — skip tests/typecheck/lint

---

## Phase 4: Create Plan (Minimal Interaction)

**CRITICAL: You MUST run the full `/tce:plan` process.** Do NOT skip this step or do it "inline" — the full planning process must run and produce a plan document on disk.

1. **Invoke the `tce:plan` skill** (via the Skill tool) with the ticket number from Phase 2 as args (e.g., `[PREFIX]-XXXX`)
2. **The plan process will run the full procedure**: reading the ticket and research document, resolving open questions, and writing the plan to `thoughts/shared/plans/`
3. **Autonomy overrides for quickfix context**:
   - Skip the interactive structure review — for a small fix, write the plan directly without asking for approval of the outline
   - Resolve open questions from research yourself if the answers are clear from codebase findings
   - **Only ask the user if there are genuine ambiguities or design decisions** that cannot be resolved from the available information (present them per the AskUserQuestion dialog guidelines above)
   - Keep the plan concise — a quickfix plan should typically have 1-2 phases
   - If the design-exploration check in `/tce:plan` flags a non-trivial UX change, that is a signal the fix is bigger than a quickfix — see "Important Rules" #1

**MANDATORY OUTPUT**: A plan document MUST exist at `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-*.md` after this phase. If it doesn't, the phase failed.

4. **Immediately commit the plan** using the `/tce:commit` workflow:
   - Stage only the plan file
   - Commit message: `docs([PREFIX]-XXXX): create implementation plan for quickfix`
   - This is a docs-only commit — skip tests/typecheck/lint

---

## Phase 5: Implement Plan (Autonomous with Safety Nets)

**CRITICAL: You MUST run the full `/tce:implement` process.** Do NOT skip this step or implement "from scratch" — the full implementation process must run using the plan document created in Phase 4.

1. **Invoke the `tce:implement` skill** (via the Skill tool) with the ticket number as args (e.g., `[PREFIX]-XXXX`)
2. **The implement process will run the full procedure**: reading the ticket/research/plan, creating a status file alongside the plan, implementing phase by phase, running verification, updating the status file, and committing after each phase.

3. **Only pause for user input if:**
   - A test fails and you can't determine the fix
   - The code doesn't match what the plan/research described
   - You encounter an unexpected blocker

4. **Run the verification suite** as specified by `/tce:implement`:
   - Use the test/typecheck/lint commands from `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`
   - Run ALL test suites that could be affected by the changes (when in doubt, run everything)
   - Fix any issues autonomously if possible

---

## Phase 6: Final Summary

After implementation is complete, present a concise summary:

```
Quickfix complete: [PREFIX]-XXXX — [Title]

**What was fixed:** [1-2 sentence description]

**Changes made:**
- [File changed]: [what changed]
- [Another file]: [what changed]

**Verification:** (commands from profile.md)
- [x] [Test suite] passes
- [x] [Typecheck] passes (if applicable)
- [x] [Lint] passes (if applicable)

**Commits:**
- `abc1234` docs([PREFIX]-XXXX): create quickfix ticket
- `def5678` docs([PREFIX]-XXXX): research codebase for quickfix
- `ghi9012` docs([PREFIX]-XXXX): create implementation plan
- `jkl3456` feat/fix([PREFIX]-XXXX): [implementation commit message]

**Documents created:**
- Ticket: [PREFIX]-XXXX (file path or URL per the ticket system)
- Research: `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
- Plan: `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
```

[If research recorded a "Profile Drift" section:] add one line to the summary —
"Note: `.claude/tce/profile.md` looks stale ([what drifted]) — consider running
`/tce:refresh`." This is the autonomous flow's one chance to surface it, so don't omit it.

---

## Important Rules

1. **Size is always "Small"** — if during research/planning you discover the fix is actually medium or larger (or `/tce:plan` flags a non-trivial UX change needing `/tce:design_explore`), STOP and tell the user. They should create a properly discussed ticket instead (e.g. via `/tmt:create`, or in their ticket system) and run the normal workflow.
2. **Never skip verification** — quickfix does not mean untested. All standard verification (per `profile.md`) applies.
3. **Never push** — as always, the human decides when to push.
4. **Commits follow standard format** — conventional commits with ticket ID, via the `/tce:commit` workflow.
5. **Ask when genuinely uncertain** — autonomy does not mean guessing. If you're unsure about the correct behavior, ask.
6. **Run `/simplify` before the final implementation commit** if you iterated through multiple approaches during implementation.
