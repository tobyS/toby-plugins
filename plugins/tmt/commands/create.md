---
description: Create a ticket file in this repo (envelope only — numbering, status, location). You own the content; for guided authoring use /tce:ticket.
argument-hint: "[ticket title or brief description]"
---

# Create Ticket

You are tasked with creating a new tmt ticket **file** — the envelope: the next
sequential number, the filename, the heading, the status line, and the location.
tmt does **not** prescribe what goes in the ticket body; **the content is the
user's** to write however they like.

tmt is a standalone markdown ticket tracker: tickets live as plain files in
`thoughts/shared/tickets/` and this command is how they are born.

## If this project also uses tce

When `.claude/tce/` exists, tce provides **`/tce:ticket`** — a guided discussion
that authors a well-structured ticket (problem, outcome, acceptance criteria,
scope) and creates it for you. Mention this once, as a nudge — not a redirect:

```
Tip: this project uses tce, so `/tce:ticket` can guide you through authoring a
well-structured ticket. Want me to create a plain ticket here instead, or would
you rather use /tce:ticket? (I'll proceed here unless you say otherwise.)
```

Proceed with this command if the user wants a plain ticket; otherwise point them
to `/tce:ticket`.

## Initial Response

1. **If a title/description was provided**, use it. **Otherwise** ask:

   ```
   What's the ticket about? Give me a short title (and any details you want in the
   body — you own the content; I'll set up the file).
   ```

2. **Gentle guidance (offer, don't impose).** A useful ticket usually states the
   problem or goal, what "done" looks like, and what's out of scope — enough that
   someone (or the tce workflow) can pick it up later. Offer to capture those if the
   user hasn't, but respect that the content is theirs; write whatever they provide,
   including a one-line stub.

## Writing the Ticket

1. **Determine the ticket number** (`[PREFIX]` is the project's ticket prefix,
   configured in `.claude/tmt/config` — the script substitutes it):
   - **New main ticket:** run `"${CLAUDE_PLUGIN_ROOT}/scripts/next-ticket.sh"` for
     the next number (e.g. `[PREFIX]-0060`).
   - **Sub-ticket of an epic:** parent number + letter suffix (`[PREFIX]-0057a`).
   - **Modifying an existing ticket:** use the existing number.

2. **Generate the filename:** `[PREFIX]-XXXX-brief-description.md` (2–4 kebab-case
   words), in `thoughts/shared/tickets/`.

3. **Check downstream consumer expectations (if tce is present):** if
   `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` has a "What tce needs from a
   ticket" section, read it and make sure the content the user gave covers what it
   asks for (clear scope, an observable outcome, an anchor). If it doesn't, *mention*
   the gap and offer to flesh it out — but don't block; the user owns the content.

4. **Write the ticket** to `thoughts/shared/tickets/[PREFIX]-XXXX-brief-description.md`
   with the envelope and whatever body the user provided:

   ```markdown
   # [PREFIX]-XXXX: [Title]

   **Status:** Open
   **Created:** YYYY-MM-DD
   **Updated:** YYYY-MM-DD

   [The user's content — free-form. Leave a brief stub if they gave only a title.]
   ```

   `Status` must be one of the valid tmt statuses (a tmt hook validates the
   `**Status:**` line on write); a new ticket starts at **Open**.

5. **Present the result:**

   ```
   Created: thoughts/shared/tickets/[PREFIX]-XXXX-brief-description.md (Status: Open)
   ```

   If tce is present, add: `When ready, run: /tce:research [PREFIX]-XXXX` (or use
   `/tce:ticket` next time for guided authoring).

   Do **not** commit automatically — leave that to the user.
