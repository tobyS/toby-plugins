---
description: End-to-end workflow for an existing ticket (research → clarify → plan → implement), autonomous except for a single open-questions checkpoint.
argument-hint: "[ticket-id]"
---

# Work on Ticket

End-to-end workflow: research → clarify questions → plan → implement. Runs autonomously with a single interaction checkpoint for open questions/decisions.

## Project context

This command ships in the **tce** workflow plugin and is stack-agnostic. It is a
**composite command** that chains the single-step workflow commands
(`/tce:research` → `/tce:plan` → `/tce:implement`, plus `/tce:commit`) into one
session.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack, conventions, and the exact test/lint/typecheck commands to run during verification and commits. If it's missing, suggest the user run `/tce:init`.
- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the project's ticket system: how to normalize a ticket reference into its canonical ID, how to fetch the ticket's content, how to find parent/epic tickets, and the status/completion policy. If it's missing, suggest `/tce:init`.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md` (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- When these instructions tell you to invoke another workflow command **via the Skill tool**, use its namespaced name (e.g., `tce:plan`). In prose, sibling commands are referenced by their installed, prefixed name (e.g., `/tce:research`).

**This command must stay in lock-step with the single-step commands it chains.** Phases 1, 3, and 4 mirror `/tce:research`, `/tce:plan`, and `/tce:implement` respectively. The quality and outputs of each phase must be identical to running those commands manually — the only difference is the removed intermediate review steps.

**Usage:** `/tce:work [PREFIX]-XXXX` (ticket number required)

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

## Overview

This command chains the full development workflow (research, plan, implement) into a single session with minimal user interaction. The quality of research, planning, and implementation is identical to running `/tce:research`, `/tce:plan`, and `/tce:implement` separately — the difference is that intermediate review steps are removed.

**Interaction model:**

- Research and planning run autonomously (no user review)
- There are at most TWO interaction points:
  1. An upfront **ticket sufficiency check** — only if the ticket is too thin to research safely (see Phase 1)
  2. The **question checkpoint** between research and planning, where Claude asks the user to resolve open questions/decisions
- If the ticket is sufficient and there are no open questions, the whole flow runs without interaction until implementation
- Implementation starts immediately after planning

---

## Phase 1: Research (Autonomous)

Execute the full research workflow as defined in `/tce:research`, with these modifications:

### 1a. Start immediately

Do NOT print "I'm ready to research" and wait. Instead:

1. Resolve the canonical ticket ID and fetch the ticket's content via the read mechanism in `tickets.md`; read it FULLY
2. Run `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" [PREFIX]-XXXX` to find related thoughts documents
3. If the ticket has a parent/epic (per the "Parent / epic tickets" section of `tickets.md`; for tmt a letter suffix like `[PREFIX]-0100a`), also fetch the parent ticket and its thoughts documents
4. **Run the ticket sufficiency check** from `/tce:research`: scope determinable, outcome observable, at least one concrete anchor into the system. If any is missing, ask the user focused clarifying questions now (one batched round, presented per the AskUserQuestion dialog guidelines above) — this is the only case where Phase 1 interacts. If the ticket is sufficient, do not interact.
5. Begin research immediately

### 1b. Conduct research exactly as `/tce:research` specifies

Follow all research steps from `/tce:research`:

- Decompose the research question from the ticket
- Spawn parallel sub-agents (codebase-locator, codebase-analyzer, codebase-pattern-finder, thoughts-locator, thoughts-analyzer, web-search-researcher)
- Wait for ALL sub-agents to complete
- Synthesize findings
- Check `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` and the backend adapter in `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for high-confidence drift (a stack the profile omits, a vanished test/typecheck/lint command, a moved or removed code-map directory, or a ticket system whose recorded access/create/status mechanism no longer matches) and, if found, include the "tce Config Drift" section in the research document recommending `/tce:refresh` — read-only, **never edit the config**
- Gather git metadata
- Write the research document to `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md`: read `${CLAUDE_PLUGIN_ROOT}/references/research-document-template.md` now — in full, even if you read it earlier in this session — and follow it exactly (including the conditional Impact Analysis section when the ticket reuses/extends shared code)
- Generate GitHub permalinks if applicable
- Follow ALL quality guidelines from `/tce:research` (impact analysis, code references, etc.)

**The research document must be just as thorough as if `/tce:research` were run manually.**

### 1c. Commit research document

Use the `/tce:commit` command to commit the research document. Since this is a docs-only commit, skip tests/typechecks.

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

Print the intro message, then present them with `AskUserQuestion`, following
the AskUserQuestion dialog guidelines (above). Intro template:

```
I've completed research for [PREFIX]-XXXX and committed the research document.

**[One sentence summarizing the ticket and where research landed.]**

[Short paragraph — 2–4 sentences max: the key findings behind the questions
below and why they need your input. Don't restate the research document.]
```

[If research recorded a "tce Config Drift" section:] add one line to the intro —
"Note: research found tce config looks stale ([what drifted in profile.md or
tickets.md]) — consider running `/tce:refresh` after this." It is advisory only, not
one of the questions below.

Then one `AskUserQuestion` call (a second call only if there are more than 4
questions — most important first): each question text is the concrete question
only; the header is a short topic chip; the options are the concrete
alternatives the research found, recommended-first with the research's
reasoning in the description (no "(Recommended)" marker when research suggests
no preference).

[If UX ticket without design decision:] the intro gains one line — "The ticket
involves a non-trivial UX change without a design decision yet." — and the
call gains this question, copy verbatim:

Question: "Run /tce:design_explore before planning?" — header: "Design", options:

1. **Explore design first** — I stop here; you run /tce:design_explore to pick a
   direction, then the workflow resumes with planning.
2. **Plan directly** — I create the implementation plan now; it will note that
   no formal design exploration was done.

Wait for the user's answers. If the user's answers raise follow-up questions, ask those too. Continue until all questions are resolved.

**If there are NO open questions:**

Print a brief status line and proceed directly to Phase 3:

```
Research complete and committed. No open questions — proceeding to planning.
```

If research recorded a "tce Config Drift" section, append the same one-line advisory
to that status line ("Note: tce config looks stale (…) — consider `/tce:refresh`.") so
it isn't missed when there are no questions.

---

## Phase 3: Planning (Autonomous)

Create the implementation plan using the ticket, research document, and user's answers to questions.

### 3a. Create the plan

Follow the plan creation process from `/tce:plan` Step 3 (Plan Structure Development) and Step 4 (Detailed Plan Writing):

- **Re-read the inputs first, in chain order (ticket → research document), fully** — even though they were just read/written in Phases 1–2 of this same session. Re-reading them fresh anchors planning on these inputs and does not discard the surrounding history. (This applies to the workflow **documents**; the next bullet still holds for **source files**.)
- Use the research document as the codebase context (DO NOT re-read source files it already covers)
- Incorporate all answers from the question checkpoint
- Write the plan to `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
- Read `${CLAUDE_PLUGIN_ROOT}/references/plan-document-template.md` now — in full, even if you read it earlier in this session — and follow its template and success-criteria guidelines exactly
- Include both automated and manual verification in success criteria. Derive the automated checks from the test/lint/typecheck commands in `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`.

**The plan must be just as detailed as if `/tce:plan` were run manually.**

**Key difference from `/tce:plan`:** Do NOT present the plan outline for user approval. Do NOT ask for feedback on plan structure. Write the complete plan directly.

### 3b. Commit the plan

Use the `/tce:commit` command to commit the plan document. Since this is a docs-only commit, skip tests/typechecks.

### 3c. Announce and proceed

Print a brief status line:

```
Plan created and committed. Starting implementation.
```

---

## Phase 4: Implementation

Execute the implementation plan exactly as `/tce:implement` specifies.

### 4a. Set up implementation

1. Re-read the input documents fully, **in chain order (ticket → research → plan)**, before implementing — even though they were produced earlier in this same session. Re-reading them fresh anchors implementation on these inputs and does not discard the surrounding history (just as `/tce:implement` requires when run standalone).
2. The repository state check from `/tce:implement` is trivially satisfied here — research and plan were produced earlier in this same session; skip the spot-verification
3. Check for existing status file (same base name, `.status.md` extension)
4. If status file exists with completed phases, resume from where it left off
5. If no status file, create one when starting the first phase
6. Create a todo list to track progress

### 4b. Implement phase by phase

Follow ALL `/tce:implement` guidelines:

- Implement each phase fully before moving to the next
- Run success criteria checks after each phase
- Fix any issues before proceeding
- Commit after each verified phase (using `/tce:commit` with full pre-commit checklist for code commits)
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
- Handle ticket status per the "Status / completion" policy in `tickets.md`: transition it via the documented mechanism if allowed (for tmt, set `**Status:** Done`), otherwise remind the user that the transition is due

---

## Important Rules

1. **Research and plan quality are non-negotiable.** The automation removes user review, not thoroughness.
2. **The question checkpoint is the safety valve.** Never assume answers to questions that require human judgment.
3. **Commits happen at the same points** as in the manual workflow (after research, after plan, after each implementation phase), all via the `/tce:commit` workflow.
4. **If something goes seriously wrong** (research finds the ticket is fundamentally flawed, plan reveals the approach won't work), stop and talk to the user instead of plowing ahead.
5. **The existing commands still work independently.** This command doesn't modify `/tce:research`, `/tce:plan`, or `/tce:implement`.
