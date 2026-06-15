---
description: Author a well-structured ticket through guided discussion (WHAT & WHY), then create it in the project's ticket system. Step 1 of the tce workflow.
argument-hint: "[brief feature/bug description]"
---

# Author a Ticket

You are tasked with creating clear, business-focused tickets through an interactive
discussion, then persisting them into whatever ticket system this project uses. You
act as the technical counterpart to the user (who represents the business/product
perspective), shaping ideas into well-defined requirements.

The ticket focuses on **WHAT** needs to be built and **WHY**, not **HOW**. Technical
implementation details are deferred to the tce research and planning phases.

This command owns ticket **content** (the payload). The ticket system owns the
**envelope** (numbering, location, status enum); how to create and lay out a ticket
in it comes from the project's adapter — you never hardcode it.

## Project context

This command ships in the **tce** workflow plugin and is stack- and
ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the ticket system: the
  canonical ID form, the "Creating a ticket" mechanism, the "Ticket title & body
  layout", and the status policy. The command persists through these verbatim. If
  the file is missing, tell the user to run `/tce:init` and stop.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md` (e.g.
  `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- This is **step 1 of the tce chain** (ticket → research → plan → implement): the
  ticket you create here is picked up by `/tce:research`, `/tce:plan`, and
  `/tce:implement`. So codebase-specific and technical questions do NOT need to be
  answered now — capture WHAT and WHY; research and planning handle the "how".

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

## Modes

- **Interactive (default):** run the guided discussion below, then create the ticket
  through the adapter and hand off to `/tce:research`.
- **Autonomous:** when the invocation arguments contain `--autonomous` (used by
  `/tce:quickfix`), skip the discussion entirely — see "Autonomous mode" at the end.

---

## Initial Response (interactive)

When this command is invoked without `--autonomous`:

1. **Read `tickets.md`.** Note the canonical ID form, the creation mechanism, and —
   critically — whether creation is **allowed**. If "Creating a ticket" says creation
   is **not allowed**, open with this warning before anything else:

   ```
   Heads up: your ticket system (per .claude/tce/tickets.md) doesn't permit me to
   create tickets directly, so I won't write anything to [system]. We'll shape the
   ticket together and I'll hand you copy/paste-ready content at the end — or you can
   let me create it just this once.
   ```

2. **Check the argument:** if a brief description was provided, acknowledge it and
   begin. Otherwise respond:

   ```
   I'll help you author a detailed ticket. Let's discuss the requirements together.

   What feature, bug fix, or task would you like to create a ticket for?

   Tip: you can also provide an initial description: `/tce:ticket Add document tagging`
   ```

## Discussion Process

A **collaborative dialogue** that refines the initial idea into a complete ticket.
Your role: ask probing questions, challenge vague requirements, ensure acceptance
criteria are testable, identify what's out of scope, surface and resolve open
questions, and stay on the business need rather than the implementation.

### Phase 1: Understand the problem

Clarify the fundamental need before anything else:

- Restate your understanding of the problem.
- Why is this needed — what's the business value? Who is it for? Is it a current
  pain point or new functionality? What happens if we don't do it?
- What triggered this? Are there workarounds in use? Did users ask for it?

**Do not proceed until the user confirms your understanding.**

### Phase 2: Define the desired outcome

- Propose the desired end state ("when this is complete, what should be true?").
- Make it concrete and measurable. Bad: "better UX". Good: "users can tag items and
  filter the list by tag".
- Challenge vagueness: "make it better" → what specifically improves?

**Do not proceed until the outcome is concrete and measurable.**

### Phase 3: Explore user stories

- Identify the user types (regular users, admins, guests …).
- Develop 2–4 stories: "As a [user type], I want to [action] so that [benefit]" —
  the "so that" must express real value, not "so that I can [restate the action]".

### Phase 4: Define acceptance criteria

This is critical — work out specific, testable criteria together:

- Propose initial criteria as a checklist.
- Make each verifiable. Bad: "upload works". Good: "user can upload a PDF up to 50 MB
  and see it in their list within 5 s"; "user sees 'File too large' over 50 MB".
- Probe edge cases: validation/errors, boundary conditions, unusual users.
- Cover the happy path, validation/errors, edge cases, and UX (response time,
  feedback, clarity).

**Do not proceed until acceptance criteria are specific, measurable, and complete.**

### Phase 5: Define boundaries

- Surface scope-creep risks ("these feel related but might be separate").
- Build an explicit "Out of Scope" list together ("it would be nice if…" / "maybe we
  could also…" → probably out of scope).
- Validate a complexity estimate (Small / Medium / Large / Extra Large). If it feels
  XL, discuss breaking it into smaller tickets.

### Phase 6: Surface open questions

Separate questions into two buckets and process them:

1. **Business/Product** (resolve now, with the user): user behavior, business rules,
   priority/scope decisions — things the product owner can answer. Push to resolve;
   if truly unresolved, record them as blockers in "Open Questions".
2. **Codebase/Technical** (defer to research/planning): existing patterns, schemas,
   libraries, current implementations. List them, ask "want to clarify any now, or
   add anything?", record any input, and otherwise file them under "Questions for
   Research/Planning".

### Phase 7: Final review & confirmation

- Summarize: Problem / Outcome / key Acceptance Criteria / Complexity / Out of Scope.
- Ask for explicit confirmation that it's ready.

## Creating the ticket

Once the user confirms (interactive), assemble and persist the ticket **through the
adapter in `tickets.md`** — never with hardcoded backend specifics.

1. **Build the content body** using the layout in "The ticket body" below, populated
   from the discussion (exact decisions, criteria, out-of-scope, open questions).
   Derive a concise **title** and, for systems that number tickets, the canonical ID
   from the adapter's "Creating a ticket" mechanism.

2. **Honor the creation policy, and always ask final permission before any write:**

   - **Creation allowed:** confirm once ("Ready for me to create this in [system]?"),
     then create via the "Creating a ticket" mechanism, assembling title + body per
     "Ticket title & body layout" (for a file backend: write the file; for an issue
     tracker: run the create command). For file-based systems (e.g. tmt), commit the
     new ticket file with a docs-only commit, the message formatted per the project's
     commit convention (see `.claude/tce/profile.md`) — e.g. for Conventional Commits,
     `docs([PREFIX]-XXXX): create ticket for <brief description>`.
   - **Creation not allowed:** you already warned up front. After the discussion,
     offer the one-time override with AskUserQuestion (intro first, per the dialog
     guidelines):

     Question: "How should I hand over the ticket?" — header: "Deliver", options:
     1. **Give me copy/paste (Recommended)** — I print the finished ticket; you paste
        it into [system] yourself, as your policy intends.
     2. **Create it this once** — I create it in [system] for this ticket only; the
        durable "not allowed" policy in tickets.md is unchanged.

     - If copy/paste: print the assembled title and body in a single fenced block
       with a one-line instruction to paste it into [system]. Do not write anything.
     - If override: ask final permission, then create via the mechanism as above.

3. **Hand off:** report what was created (canonical ID + location/URL) and suggest:

   ```
   When ready, run: /tce:research [PREFIX]-XXXX
   ```

   (Or, on the copy/paste path: "once you've created it, run `/tce:research <ID>`".)

## The ticket body

Populate every section from the discussion. The **title** is separate (it becomes the
file heading or the issue title per the adapter); the sections below are the body. For
a file backend the adapter also prepends a `**Status:**` line at the initial status
and the meta lines — follow "Ticket title & body layout" in `tickets.md`.

```markdown
**Estimated Complexity:** Small | Medium | Large | Extra Large
**Created:** YYYY-MM-DD
**Updated:** YYYY-MM-DD

## Problem Statement

[The problem or need. Why are we doing this?]

## Desired Outcome

[What success looks like — what should be true when this is complete.]

## User Stories / Use Cases

- As a [user type], I want to [action] so that [benefit]

## Acceptance Criteria

- [ ] Criterion 1 — specific, measurable outcome
- [ ] Criterion 2 — specific, measurable outcome

## Out of Scope

[Explicitly list what this ticket will NOT address, to prevent scope creep.]

## Open Questions

[Business/product questions that couldn't be resolved — these are blockers.]

## Questions for Research/Planning

- [ ] [Codebase/technical questions for the research and planning phases]

## References

- [Related documents, discussions, or examples]

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### YYYY-MM-DD
[Key decisions made during ticket creation.]
```

## Important Guidelines

1. **Business need, not implementation.** Good: "what message should they see when a
   file is too large?" Bad: "validate on frontend or backend?" — that's for planning.
2. **Challenge vague requirements.** "Improve the upload experience" → faster? clearer
   errors? better progress? Be specific so success is measurable.
3. **Make acceptance criteria testable.** Each criterion is verifiable by a human or a
   test. Avoid "works well" / "handled appropriately".
4. **Use "Out of Scope" liberally.** It prevents scope creep and builds a follow-up
   backlog.
5. **Separate business from technical questions.** Resolve business questions now;
   defer technical ones to research/planning unless the user wants to weigh in.
6. **No empty sections without agreement.** Fill each, or explicitly agree to leave it
   empty.
7. **Stories have real benefits.** The "so that" expresses genuine user value.
8. **Document key decisions** in "Notes & Updates": important choices, the complexity
   rationale, why things were scoped out, assumptions.

## Autonomous mode

When invoked with `--autonomous` (by `/tce:quickfix`), the calling command has already
clarified the fix and confirmed creation is allowed (it stops itself otherwise). So:

- Do **not** run the discussion or ask anything. Take the description from the
  arguments as the understanding.
- Build the body from "The ticket body" with **Estimated Complexity: Small**, "Open
  Questions: None — well-understood quickfix", and a "Questions for Research/Planning"
  list of any codebase questions needed for the fix.
- Determine the canonical ID and create the ticket via the adapter's "Creating a
  ticket" mechanism, assembling title + body per "Ticket title & body layout". For a
  file backend, write the file (the caller handles the commit). For an issue tracker,
  run the create command and note the canonical ID.
- Return the canonical ID (and file path or URL) to the caller. No interaction, no
  handoff message — `/tce:quickfix` drives the rest of the pipeline.
