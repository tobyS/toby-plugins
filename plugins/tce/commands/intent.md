---
description: Agree with the agent what a ticket (or ticketless input) means in this codebase — scope, outcome, anchors, criteria, decisions — and write it as an intent in thoughts/shared/intents/. Never modifies the ticket.
argument-hint: "[ticket ID | intent path | thoughts/ document | description]"
allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh:*), Bash(${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh:*), Bash(git rev-parse:*)
---

# Agree an Intent

You are tasked with agreeing, together with the user, what a piece of work means
in this codebase, and recording that agreement as an **intent** — the
agent-facing specification of a ticket (or of ticketless input). You act as the
technical counterpart to the user (who represents the business/product
perspective), shaping the input into a well-defined agreement through an
interactive discussion.

The intent focuses on **WHAT** needs to be built and **WHY**, not **HOW**.
Technical implementation details are deferred to the tce research and planning
phases.

**The ticket is read, never modified.** The ticket belongs to the ticket system
and may be someone else's; every clarification, decision and criterion agreed
here lands in the intent file, never in the ticket body. Status transitions per
`tickets.md` are the only ticket writes anywhere in tce, and this command makes
none.

## Project context

This command ships in the **tce** workflow plugin and is stack- and
ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` for the project's stack,
  code map and commit convention, and `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md`
  for the ticket system: the canonical ID form, how to read a ticket, and the
  parent/epic rule. If either file is missing, tell the user to run `/tce:init`
  and stop.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md` (e.g.
  `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.
- **Reader.** Read the `## Reader` section of `profile.md`. If it is absent or
  says **Not described**, assume a reader fluent in the project's stack.
  Otherwise, write every question, draft and summary for the reader it
  describes: use terms within their fluency without explanation; the first time
  a term, tool, library, pattern or abbreviation outside it appears, name it and
  say in half a sentence what it does. This governs vocabulary and depth, not
  length — cover the substance, do not pad, and do not explain what the reader
  already knows.
- This is the **agreement step of the tce chain** (ticket → intent → research →
  plan → implement): the intent you write here is read right after the ticket
  by `/tce:research`, `/tce:plan`, `/tce:implement` and `/tce:review`. So
  codebase-specific and technical questions do NOT need to be answered now —
  capture WHAT and WHY; research and planning handle the "how".

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

## Input classification

**Autonomous mode first.** If `$ARGUMENTS` contains `--autonomous` (used by
`/tce:quickfix`), skip everything below and follow "Autonomous mode" at the
end of this file instead — no dialogue and no confirmation; its branch step
is in that section.

Read `tickets.md` first so you can classify the input, and normalize the
reference forms it describes (a bare number, `#123`, a URL) into the canonical
ID. Then classify `$ARGUMENTS`:

- **(a) It STARTS with a ticket reference** per `tickets.md`: normalize it and
  fetch the ticket via the read mechanism in `tickets.md`. Read it FULLY now —
  even if it already appeared earlier in this conversation (e.g. you just
  created it via `/tce:ticket` in the same session). If it has a parent per the
  "Parent / epic tickets" section, fetch the parent too, for context. Any text
  after the reference is extra input for the draft.
- **(b) It is a path into `thoughts/shared/intents/`**: that is the intent to
  update. Read it FULLY. If its `ticket:` is not `none`, fetch that ticket too,
  as in (a). If the file is not on the current checkout, it may live only on
  its branch: take the ticket from the filename when it carries a canonical
  ID, otherwise treat it as ticketless with the filename's slug, and read it
  after the branch step.
- **(c) It is any other existing `thoughts/` path** (e.g. a `/tce:discuss`
  document): a source. Read it FULLY and draft from its conclusion; record the
  path in the `source:` frontmatter field. If the user also names a ticket,
  treat it as (a) with that source.
- **(d) Anything else** is a free description: ticketless input.

**CRITICAL:** General descriptive text like "Add document tagging" is NOT a
ticket reference. Only strings matching the canonical ID pattern from
`tickets.md` (or a normalizable reference form it lists) are ticket references.

If no argument was provided, respond with:

```
I'll help you agree what to build — scope, outcome, anchors into the code,
acceptance criteria and decisions — and record it as an intent.

Which ticket, or what should be built?

Tip: `/tce:intent [PREFIX]-0042`, `/tce:intent thoughts/shared/discussions/<file>.md`,
or `/tce:intent Add document tagging`
```

## Put the branch in place

Branch-per-ticket projects only — for ticket intents and ticketless ones
alike. Read the `## Branch convention` section of
`${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`. If the section is absent or
says **Current branch**, skip this step entirely: stay on the current branch
and print nothing. If it says **Branch per ticket**, resolve the branch name:

- **Ticket intent** ((a), or (b) with a ticket): substitute the canonical
  ticket ID into the recorded pattern (for a `<slug>` element, a short
  kebab-case slug of the ticket title).
- **Ticketless intent** ((b) without a ticket, (c) without a ticket, (d)): the
  **ticketless branch name** — the recorded pattern with the intent's slug
  substituted for `<ticket-id>` and a `<slug>` element dropped together with
  one adjoining separator (`-`, `_` or `/`). For (c) and (d), choose the slug
  you will use **now**, before this step; for (b) it is the filename's slug
  (without the leading `YYYY-MM-DD-` and the `.md`).

For (b) ticketless, run `"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" switch
<branch>` instead: `switched`, `already` → continue (one line naming the
branch); `missing` with the intent file on the current checkout (an intent
written before tce 1.6.0) → run `create` below with `--trust-local` and print
one line: "Cut <branch> from the local <base>, which holds this intent
(written before tce 1.6.0)."; `missing` otherwise → report "No intent at
<path>" and stop; `dirty` → ask the user to commit or stash, then re-run;
`blocked` → report the `detail:` line and stop. Every other intent runs

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" create <branch> <base> <remote>
```

and act on its `result:` line — `created`, `switched`, `already`: continue
(mention the branch in one line); `fetch-failed` or `no-remote`: stop and ask
(dialog below), and only after the user confirms re-run the command with
`--trust-local`; `dirty`: ask the user to commit or stash, then re-run;
`invalid-name`, `missing-base`, `blocked`: report the `detail:` line and stop.
Never cut the branch from anything else. Do this **before** the existing-intent
lookup and before anything is written or committed: the intent is the ticket's
first artifact and lives on the ticket branch, which the step commands later
switch to.

Stop-and-ask dialog (AskUserQuestion, following the guidelines above; **use
this copy verbatim**, replacing the bracketed parts). Intro:

```
tce could not bring the base branch [base] up to date from [remote]
([detail line]). The ticket branch must be cut from a current base, so I
won't guess.
```

Question: "How should I proceed with the base branch?" — header: "Base
branch", options:

1. **Local tip is current** — You have updated [base] yourself (or know it is
   current); cut [branch] from the local [base] now.
2. **Stop here** — Nothing is created; the session stays on the current
   branch and you can update [base] first.

## Existing intent

There is at most one intent per ticket. Look for it before drafting:

- For (a), run `"${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh" [PREFIX]-XXXX` and read
  the `intent:` line (empty when none exists).
- For (b), the given path is the existing intent.
- For (c) and (d), check `thoughts/shared/intents/*-<slug>.md` for the slug you
  chose before the branch step (the lookup runs on that branch).

If an intent exists: read it FULLY and summarize it in three lines. Then ask
(AskUserQuestion, header "Intent"):

1. **Update it (Recommended)** — The discussion starts from the existing intent
   as the draft, and the same file is rewritten in place.
2. **Leave it** — Nothing changes; stop here.

Never create a second intent for a ticket.

## Sufficiency test (first step of the dialogue)

Before sizing, apply the three-part test to the input — the same test "What tce
needs from a ticket" in `tickets.md` describes. The intent is the canonical
place it is applied with the user:

1. **Scope is determinable** — what should change or be built, and roughly where the boundary is.
2. **Outcome is observable** — you can tell what "done" would look like, even informally.
3. **There's an anchor** — at least one concrete pointer into the system (feature, screen, command, error message, or code area) so research has somewhere to start.

Explicitly NOT required of the input: business justification, formal
acceptance criteria, technical detail, or any particular section structure
(tickets from other systems or non-technical authors may be free-form text).

Each missing part becomes a question in the **first round** of the discussion —
never a separate pre-round. Confirm candidate anchors with Grep/Glob (does the
command, file, screen or error message actually exist?); do not spawn research
agents — finding out *how* things work is research's job.

## Size assessment & track selection

Before the discussion, size the work and pick the interaction track. This is a
routing judgment, not a gated round — state it briefly and proceed; it costs no
extra confirmation on either track.

1. From the input (ticket, source document, argument or the user's first
   answer), form a first-pass understanding and propose a **size** — Small,
   Medium, Large, or Extra Large — with **one line of reasoning**. (This is the
   same estimate later recorded in the intent's `size:` field; here it also
   selects the track.)
2. **Route on the estimate:**
   - **Small or Medium →** run the **Compressed discussion** (below).
   - **Large or Extra Large →** run the **Full discussion** (the seven phases below).
3. **The user can override.** They may correct the size or ask for the full ceremony
   regardless of size — in plain language at any time, or as the offered choice in
   the first compressed round (below). A request for the full discussion always wins.
   An Extra Large estimate should still trigger the "break it into smaller tickets"
   conversation from Full-discussion Phase 5.
4. **Escalation.** If, once discussion starts, the work proves larger or more
   tangled than estimated (scope keeps growing, acceptance criteria won't settle, an
   unresolved design decision surfaces), say so and switch to the **Full discussion
   in place** — continue from the understanding already gathered into the remaining
   phases; do not discard it or restart.

## Compressed discussion (Small/Medium)

For Small/Medium work, collapse the seven phases into **at most two interaction
rounds** while filling *every* intent section at the same quality bar as the
full track. The three "do not proceed" gates become a single confirmation of the
whole draft — you are batching the questions, not lowering the bar.

**Round 1 — understanding + draft (one message).** In a single message, present:

- Your **restated understanding** of the scope and why it's needed.
- The proposed **size** and its one-line reasoning (from the size assessment) —
  explicitly inviting the user to override the size, or to expand to the full
  guided discussion instead.
- Any question the sufficiency test raised (a missing scope boundary, outcome or
  anchor).
- A **complete first-draft intent** filling every section of the intent
  template: Scope (In and Out), Observable outcome (concrete and checkable),
  Anchors (confirmed), Acceptance criteria (specific, testable — apply the
  Phase 4 standard), Decisions (each with its rejected alternative), Open
  questions, and Questions for research.

Ask the user to confirm or correct the draft. Do **not** silently skip substance:
acceptance criteria must still be testable and Out still explicit.

**Genuinely unresolved business questions are exempt from the two-round cap.** If a
real business/product ambiguity blocks drafting a section (not a technical question —
those go under Questions for research), ask it, following the AskUserQuestion
dialog guidelines (above). Prefer to batch it into Round 1's message.

**Round 2 — confirm & write.** Fold the user's corrections into the draft, then ask
the single final confirmation ("Ready for me to write this intent?") and write it
via "Writing the intent" below. If the corrections reveal the work is actually
Large/Extra Large, escalate to the Full discussion instead (per "Size assessment
& track selection").

## Full discussion (Large/XL)

Reached for Large/Extra Large work, whenever the user asks for the full ceremony,
or on escalation from the compressed track. A **collaborative dialogue** that refines
the input into a complete intent. Your role: ask probing questions, challenge
vague requirements, ensure acceptance criteria are testable, identify what's out of
scope, surface and resolve open questions, and stay on the business need rather than
the implementation.

### Phase 1: Agree the scope

Clarify the fundamental need before anything else:

- Restate your understanding of what should change or be built.
- Why is this needed — what's the business value? Who is it for? Is it a current
  pain point or new functionality? What happens if we don't do it?
- What triggered this? Are there workarounds in use? Did users ask for it?
- Draft the **In** list of the scope.

**Do not proceed until the user confirms your understanding.**

### Phase 2: Define the observable outcome

- Propose the end state ("when this is complete, what should be true?").
- Make it concrete and checkable. Bad: "better UX". Good: "users can tag items and
  filter the list by tag".
- Challenge vagueness: "make it better" → what specifically improves?

**Do not proceed until the outcome is concrete and checkable.**

### Phase 3: Find the anchors

- Identify the concrete pointers into the system: the feature, screen, command,
  error message, file or code area the work touches or starts from.
- Confirm each with Grep/Glob — an anchor is something that exists, not a guess.
  A new feature still has an anchor: the place it attaches to.

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
- Build the explicit **Out** list of the scope together ("it would be nice if…" /
  "maybe we could also…" → probably out of scope).
- Validate the size from the size assessment (Small / Medium / Large / Extra
  Large), adjusting it if the discussion changed the picture. If it feels XL,
  discuss breaking it into smaller tickets.

### Phase 6: Decisions and open questions

Separate questions into two buckets and process them:

1. **Business/Product** (resolve now, with the user): user behavior, business rules,
   priority/scope decisions — things the product owner can answer. Push to resolve;
   record each resolved one under **Decisions** together with the alternative it
   rejected. If truly unresolved, record them as blockers in **Open questions**.
2. **Codebase/Technical** (defer to research/planning): existing patterns, schemas,
   libraries, current implementations. List them, ask "want to clarify any now, or
   add anything?", record any input, and otherwise file them under **Questions
   for research**.

### Phase 7: Final review & confirmation

- Summarize: Scope / Outcome / Anchors / key Acceptance criteria / Decisions /
  Size / Out.
- Ask for explicit confirmation that it's ready.

## Writing the intent

Once the user confirms:

1. **Read `${CLAUDE_PLUGIN_ROOT}/references/intent-document-template.md` now** —
   in full, even if you read it earlier in this session — and structure the
   intent exactly as it specifies, populated from the discussion (exact scope,
   anchors, criteria, decisions with their rejected alternatives, open
   questions). Never write it with placeholder values.
2. **Path:**
   - With a ticket: `thoughts/shared/intents/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`
     (the canonical ID exactly — it is what links the intent to its ticket for
     the discovery scripts).
   - Ticketless: `thoughts/shared/intents/YYYY-MM-DD-<slug>.md`.
   - On an update, rewrite the existing file in place (same path).
   - Create `thoughts/shared/intents/` if it is missing.
3. **On an update:** keep `date`, set `last_updated` to today and
   `last_updated_note` to what changed.
4. **Commit:** use the `/tce:commit` command for a docs-only commit of the
   intent file, the message formatted per the project's commit convention —
   e.g. for Conventional Commits, `docs([PREFIX]-XXXX): agree intent for <brief
   description>`, with no ticket scope when ticketless. Never stage the ticket.

## Hand off

Report the intent's path, then:

- **With a ticket:**

  ```
  When ready, run: /tce:research [PREFIX]-XXXX   (or /tce:work [PREFIX]-XXXX)
  ```

- **Ticketless:** say the agreement is recorded at `<path>`. A ticket for it can
  be created with `/tce:ticket`; then re-run `/tce:intent <ID>` and choose
  **Update** to link it — or, simpler, start from the ticket next time.

## Important Guidelines

1. **Business need, not implementation.** Good: "what message should they see when a
   file is too large?" Bad: "validate on frontend or backend?" — that's for planning.
2. **Challenge vague requirements.** "Improve the upload experience" → faster? clearer
   errors? better progress? Be specific so success is checkable.
3. **Make acceptance criteria testable.** Each criterion is verifiable by a human or a
   test. Avoid "works well" / "handled appropriately".
4. **Use the Out list liberally.** It prevents scope creep and builds a follow-up
   backlog.
5. **Separate business from technical questions.** Resolve business questions now;
   defer technical ones to research/planning unless the user wants to weigh in.
6. **No empty sections without agreement.** Fill each, or explicitly agree to leave it
   empty.
7. **Every decision names its rejected alternative.** A decision without the option
   it beat is a preference, not an agreement.
8. **Anchors are confirmed, not guessed.** Check each with Grep/Glob before it goes
   into the intent.
9. **Never write into the ticket.** Clarifications, decisions and findings go into
   the intent; the ticket body stays exactly as its author left it.
10. **Match ceremony to size.** Small/Medium work runs the compressed two-round
    track; Large/Extra Large runs the full seven phases. Same intent, same quality on
    both — only the interaction density differs. Escalate to the full ceremony if
    "small" work grows, and honor any explicit request for the full ceremony.

## Autonomous mode

When the arguments contain `--autonomous` (by `/tce:quickfix`), write a
**ticketless** intent from a description without any dialogue. Ask nothing,
except the base-branch dialog of "Put the branch in place" when the base
cannot be fetched, and print no draft. Your **entire output** is exactly one
line — `intent: <path>` on success, `insufficient: …` when the description
does not suffice, `stopped: …` when the branch step ends the run — with no
text before or after it: no explanation, no summary, no heading. Nothing else
is written on failure. That line is your return value, not the end of the turn: when
`/tce:quickfix` invoked you, go straight back to its section "2. Intent"
after the line and follow the bullet the line matches, in the same turn.

1. **Input.** The rest of the arguments, taken as the description. If it is
   empty, starts with a ticket reference per `tickets.md`, or is a `thoughts/`
   path, return `insufficient: autonomous mode takes a description only` —
   ticket intents are always agreed in dialogue.
2. **Sufficiency.** Apply the three-part test from "Sufficiency test" above to
   the description. Read the code only to find and confirm anchors
   (Grep/Glob — no agents). If a part fails, return
   `insufficient: <scope | outcome | anchor> — <what is missing, one line>`,
   naming the first part that failed.
3. **Slug.** A short kebab-case slug from the description. Glob
   `thoughts/shared/**/*<slug>*`; if anything matches, lengthen the slug with
   a distinguishing word and glob again, until nothing matches. Ticketless
   documents are found by their slug, so it must be unused everywhere under
   `thoughts/shared/`. Under **Branch per ticket**, also resolve the
   ticketless branch name (see "Put the branch in place") and lengthen the
   slug while `git rev-parse --verify --quiet refs/heads/<branch>` or
   `git rev-parse --verify --quiet refs/remotes/<remote>/<branch>` succeeds —
   `branch.sh create` would silently resume an existing branch of that name.
4. **Branch.** Run "Put the branch in place" for this ticketless intent with
   `create` (it skips itself when the section is absent or says **Current
   branch**). `created`, `already` → continue, printing nothing; `fetch-failed`
   or `no-remote` → ask the verbatim dialog, then re-run with `--trust-local`
   on **Local tip is current**, or return
   `stopped: you chose to update <base> first` on **Stop here**; `switched` →
   return `stopped: branch <branch> already exists`; `dirty` → return
   `stopped: uncommitted changes — commit or stash them`; `invalid-name`,
   `missing-base`, `blocked` → return `stopped: <the detail: line>`.
5. **Write** `thoughts/shared/intents/YYYY-MM-DD-<slug>.md`: read
   `${CLAUDE_PLUGIN_ROOT}/references/intent-document-template.md` now — in
   full — and follow it with `ticket: none`, `ticket_ref: none`, no `source:`
   line, `size: Small` and `status: agreed`. `## Ticket`: "None — ticketless:
   from a `/tce:quickfix` description:", followed by the description verbatim
   as a quote. Scope (In and Out), Observable outcome, Anchors (the confirmed
   ones) and Acceptance criteria (specific and testable) come from the
   description and the anchors found — add nothing the description does not
   say. Decisions: `None.` Open questions: `None.` Questions for research: the
   codebase questions the fix raises, or `None.`
6. **Commit** with the `/tce:commit` command: a docs-only commit of the intent
   file, no ticket scope (e.g. `docs: agree intent for <brief description>`).
7. **Return** `intent: <path>`. No hand-off message — the caller drives the
   rest.
