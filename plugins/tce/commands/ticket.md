---
description: Create a ticket in the project's ticket system from your own text, after one confirmation. To agree with the agent what to build, use /tce:intent.
argument-hint: "[brief feature/bug description]"
---

# Create a Ticket

You are tasked with writing a ticket for humans into whatever ticket system this
project uses. The content is the **user's own words**: you tidy the formatting,
derive a title and fill the meta lines the ticket system needs — you do not
interview the user or add requirements.

The ticket system owns the **envelope** (numbering, location, status enum); how to
create and lay out a ticket in it comes from the project's adapter — you never
hardcode it.

The agreement with the agent on what the ticket means in this codebase — scope,
anchors, acceptance criteria, decisions — is not this command's job: it is
`/tce:intent`'s, and it lives in an intent file, never in the ticket.

## Project context

This command ships in the **tce** workflow plugin and is stack- and
ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the ticket system: the
  canonical ID form, the "Creating a ticket" mechanism, the "Ticket title & body
  layout", and the status policy. The command persists through these verbatim. If
  the file is missing, tell the user to run `/tce:init` and stop.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md` (e.g.
  `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- The tce chain starts with a ticket and its intent: the ticket you create here
  is the human's text for the tracker; `/tce:intent` then agrees with the user
  what it means, and `/tce:research`, `/tce:plan` and `/tce:implement` follow.

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

- **Interactive (default):** the short flow below — take the user's text, assemble
  the ticket, confirm once, create it through the adapter and hand off to
  `/tce:intent`.
- **Autonomous:** when the invocation arguments contain `--autonomous` (used by
  `/tce:quickfix`), skip the interaction entirely — see "Autonomous mode" at the end.

---

## Creating a ticket (interactive)

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

2. **Print the pointer, once** — the `/tce:intent` line first, because users who
   know the old `/tce:ticket` interview are looking for it:

   ```
   To agree with the agent what to build — scope, anchors, criteria, decisions — use /tce:intent (on a ticket, or on its own for work without a ticket).

   /tce:ticket now only writes a ticket for humans into [system], in your words.
   ```

3. **Take the text.** Use the argument; if none was provided, ask "What should the
   ticket say?". Do not interview and do not add requirements. Tidy the formatting
   only, keeping the user's wording and substance. If the user wants to discuss the
   requirements, suggest `/tce:intent` instead.

4. **Assemble.** Derive a concise **title** and, for systems that number tickets,
   the canonical ID from the adapter's "Creating a ticket" mechanism. Fill the meta
   lines the adapter's "Ticket title & body layout" requires; where it needs an
   Estimated Complexity, propose one word with a half-line reason. Show the title
   and body once.

5. **Honor the creation policy, and always ask final permission before any write:**

   - **Creation allowed:** confirm once ("Ready for me to create this in [system]?"),
     then create via the "Creating a ticket" mechanism, assembling title + body per
     "Ticket title & body layout" (for a file backend: write the file; for an issue
     tracker: run the create command). For file-based systems (e.g. tmt), commit the
     new ticket file with a docs-only commit, the message formatted per the project's
     commit convention (see `.claude/tce/profile.md`) — e.g. for Conventional Commits,
     `docs([PREFIX]-XXXX): create ticket for <brief description>`.
   - **Creation not allowed:** you already warned up front. Once the text is
     assembled, offer the one-time override with AskUserQuestion (intro first, per
     the dialog guidelines):

     Question: "How should I hand over the ticket?" — header: "Deliver", options:
     1. **Give me copy/paste (Recommended)** — I print the finished ticket; you paste
        it into [system] yourself, as your policy intends.
     2. **Create it this once** — I create it in [system] for this ticket only; the
        durable "not allowed" policy in tickets.md is unchanged.

     - If copy/paste: print the assembled title and body in a single fenced block
       with a one-line instruction to paste it into [system]. Do not write anything.
     - If override: ask final permission, then create via the mechanism as above.

6. **Hand off:** report what was created (canonical ID + location/URL) and suggest:

   ```
   When ready, run: /tce:intent [PREFIX]-XXXX
   ```

   (Or, on the copy/paste path: "once you've created it, run `/tce:intent <ID>`".)

## The ticket body (autonomous mode only)

Used only by "Autonomous mode" below — the interactive flow writes the user's own
text. Populate every section. The **title** is separate (it becomes the
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

1. **The user's words are the content.** Tidy formatting, derive a title, fill the
   meta lines — never add requirements, criteria or scope of your own.
2. **One confirmation, never an interview.** Show the assembled ticket once and ask
   once before writing.
3. **Discussion belongs in `/tce:intent`.** When the user wants to work out what to
   build, point them there; the agreement lives in the intent, not in the ticket.

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
