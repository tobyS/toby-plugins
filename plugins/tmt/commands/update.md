---
description: Change a tmt ticket's status (Open / In Progress / Done / Rejected), by name or lifecycle moment (start / done / reject).
argument-hint: "[ticket-id] [status | start|done|reject]"
---

# Update Ticket Status

You are tasked with changing a tmt ticket's **Status** line. This is a standalone
convenience for manual use. (When the tce workflow is driving, it performs its own
status transitions per `.claude/tce/tickets.md`; this command is not invoked by tce.)

tmt owns the status enum and validates it: any write to a `**Status:**` line in a
`thoughts/shared/tickets/<PREFIX>-*.md` file passes through tmt's validation hook, so
an invalid status is caught automatically.

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

## Steps

1. **Resolve the prefix.** Read `TICKET_PREFIX` from
   `${CLAUDE_PROJECT_DIR}/.claude/tmt/config`. If it's absent, tell the user tmt
   isn't set up here and to run `/tmt:init`, then stop.

2. **Resolve the ticket reference** (first argument) to its canonical ID. Normalize a
   bare number (`42` → `<PREFIX>-0042`), a lowercase form, or an unpadded one to
   `<PREFIX>-NNNN`. If no ticket reference was given, ask which ticket.

3. **Locate the file:** glob `thoughts/shared/tickets/<canonical-id>-*.md` (under
   `${CLAUDE_PROJECT_DIR}`). If nothing matches, say so and stop. If more than one
   matches (e.g. sub-tickets), ask which one.

4. **Read the current status** from the file's `**Status:**` line and show it.

5. **Determine the target status:**
   - If the second argument is a **lifecycle moment**, map it: `start` → `In
     Progress`, `done` → `Done`, `reject` → `Rejected`.
   - If it's a **status name**, use it as-is.
   - If it's missing or ambiguous, get the valid statuses by running
     `"${CLAUDE_PLUGIN_ROOT}/scripts/valid-statuses.sh"` and ask with
     AskUserQuestion (per the dialog guidelines above), putting the natural next
     status first (Open → In Progress → Done) and noting the current status.

6. **Write the change:** Edit the `**Status:**` line to the target value (and bump an
   `**Updated:**` line if the ticket has one). The validation hook checks the value on
   write; if it reports the status is invalid, surface that and stop.

7. **Confirm and remind:**

   ```
   <PREFIX>-NNNN: [old status] → [new status]
   ```

   Remind the user to commit the change (tmt's `git add` hook will also nudge about
   due transitions). Do **not** commit automatically.
