# TP-0045a: `/tce:intent`, the intent file, `## Reader` and `## Delivery` — Implementation Plan

## Overview

Add the **intent**, a new tce artifact in `thoughts/shared/intents/`. An
intent is the agent-facing agreement on what a ticket (or ticketless input)
means in this codebase.

The intent is authored by a new, unflagged `/tce:intent` command. That command
takes over the whole authoring dialogue from `/tce:ticket`. `/tce:ticket`
shrinks to plain human-ticket creation: it takes what you want written, creates
it in the tracker and points at `/tce:intent`.

Intents become discoverable to `stage.sh` and `/tce:list`, and the chain
commands read them right after the ticket.

The profile gains two hand-authored sections that follow the TP-0031
branch-convention pattern:

- `## Reader` — the reader's fluency;
- `## Delivery` — direct, or a pull request that the human merges before the
  next ticket starts.

The release is tce 1.3.0.

## Current State Analysis

From the research document
(`thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md`):

- **No intent infrastructure exists.**
  - `/tce:init` scaffolds `research plans reviews mockups discussions` only
    (`plugins/tce/commands/init.md:451-461`).
- **The dialogue is self-contained in `plugins/tce/commands/ticket.md`.**
  - Size assessment: `:96-118`.
  - Compressed track: `:120-151`.
  - Full track: `:153-225`.
  - Creation through the adapter: `:227-266`.
  - Body skeleton: `:268-321`.
  - Guidelines: `:323-343`.
  - Autonomous mode: `:345-360`, which `/tce:quickfix` Skill-invokes at
    `quickfix.md:100-123`.
- **Discovery.**
  - `ticket.sh` (`:33`, recursive substring `find`) already returns any file in
    `thoughts/shared/intents/` whose name carries the ID.
  - `stage.sh` searches only research and plans (`:61-62`).
    - It matches delimited IDs (`:93-95`).
    - It prints a five-line record (`:284-288`, documented `:12-27`).
  - `list.md` is that record's only consumer (`:98-104`, columns `:120-124`,
    cells `:135`, epic rule `:142-145`, example `:200-214`).
- **Writes into tickets.**
  - No command writes an existing ticket's body. The only writes after
    creation are status transitions (`implement.md:335-347`, `work.md:284`,
    `commit.md:53-58`).
  - One prose suggestion points at the ticket: `design_explore.md:348`, "If
    there's an active ticket, suggest updating it with the design decision".
  - Folding content into tickets is a session habit (commit `1da6644`).
- **The sufficiency test has three copies.**
  - Canonical: `templates/tce/tickets.md:85-111`; its closing line `:110-111`
    names `/tce:research` and `/tce:work`.
  - Operational: `research.md:151-170`.
  - Compressed: `work.md:102` (Phase 1a step **5**; CLAUDE.md wrongly says
    step 4).
- **The branch-convention pattern** is the one to copy:
  - template `templates/tce/profile.md:70-97`;
  - init gather item 10 (`:146-155`), dialogs (`:290-335`), refine list
    (`:343-346`), fill (`:395-400`) and Idempotency (`:519-564`);
  - refresh's four hand-authored sites (`:27-36`, `:90-93`, `:108-111`,
    `:136-137`);
  - README `:274-284`.
- **`branch.sh create` cuts a ticket branch from the *freshly fetched* remote
  base.** `research.md:94-130` calls it before writing the first artifact.
- **Version.** tce is at `1.2.0` (`plugins/tce/.claude-plugin/plugin.json:3`,
  `.claude-plugin/marketplace.json:15`).

## Desired End State

1. `/tce:intent <ticket ID | intent path | thoughts/ document path | free text>`:
   - applies the sufficiency test with the human;
   - runs the scale-adaptive dialogue;
   - writes or updates exactly one intent per ticket from
     `references/intent-document-template.md`;
   - commits it via `/tce:commit`;
   - never writes to the ticket.
2. `/tce:ticket` creates a human ticket from the user's own text after one
   confirmation. It points at `/tce:intent` and hands off to it.
   `--autonomous` is unchanged.
3. `stage.sh` prints a sixth record line, `intent:`, and `/tce:list` shows an
   Intent column.
4. `research`, `plan`, `implement`, `review`, `work` and `quickfix` read an
   existing intent right after the ticket. `research` and `work` skip the
   sufficiency check when an intent exists.
5. The profile template has `## Delivery` and `## Reader`.
   - `/tce:init` agrees them, fills them and upgrades older profiles
     (Idempotency 1.3.0).
   - `/tce:refresh` preserves them.
   - A profile without them behaves exactly as today.
6. The README files, CLAUDE.md, manifests and the dogfooded config are
   updated. tce is 1.3.0 and tagged `tce--v1.3.0`.

Verify: `claude plugin validate` on the marketplace and all four plugins; the
`stage.sh` corpus and fixture runs; the thirteen-copy AskUserQuestion diff; the
grep checks listed per phase; and a scratch-project run of `/tce:ticket` →
`/tce:intent` → `/tce:list`.

### Key Discoveries:

- `ticket.sh` needs no change. Every caller already reads "all discovered
  documents" (`research.md:131-149`, `plan.md:79-92`, `implement.md:59-81`,
  `review.md:131-143`, `work.md:100-101`).
- Appending `intent:` as a sixth line keeps the existing five lines
  byte-identical (research Backward Compatibility Options). `list.md` reads by
  label.
- **Under Branch per ticket, `branch.sh create` cuts from the fetched remote
  base.**
  - An intent committed locally on the base branch before research would
    therefore be missing from the ticket branch.
  - So `/tce:intent` must itself put the ticket branch in place (`create`),
    exactly as `/tce:research` does.
  - `/tce:research` then gets `already` or `switched`.
- Ticket creation stays on the base branch (TP-0031: numbering stays shared).
  The intent is the first per-ticket artifact.
- `${user_config.*}` and check-init wording must change together with
  plugin.json's `userConfig` description and the README (CLAUDE.md "Prompting
  `/tce:init`").

## Decisions (resolved with the user, 2026-10-11)

- **`/tce:ticket` becomes simple; the whole dialogue moves to `/tce:intent`**
  — over a shared reference file read by both, or a second copy in
  `intent.md`. The ticket is the human's text for the tracker; the agreement
  with the agent lives only in the intent.
- **The intent carries its own agent-facing Acceptance criteria** — over
  outcome-only. Ticketless intents need criteria, and 45b's gate can read
  them.
- **`## Delivery` reuses `## Branch convention`'s base branch and remote; the
  Pull request option requires Branch per ticket** — over recording a second
  base and remote that could disagree.
- **`/tce:research` (and `/tce:work`) skip the sufficiency check when an
  intent exists** — over always re-running it. An intent exists only if the
  test was applied.

Decided while planning (surfaced for veto in the review summary):

- `/tce:intent` runs `branch.sh create` for ticket intents (see Key
  Discoveries). Ticketless intents never branch.
- `stage.sh` appends `intent:` as the sixth line. `/tce:list`'s Intent column
  sits before Research, in chain order.
- Ticketless intents are named `YYYY-MM-DD-<slug>.md` and addressed by path.
  No other command consumes them until 45c.
- `/tce:intent` may Grep/Glob the codebase to confirm that anchors exist, but
  spawns no research agents.
- This repo's own profile gets `## Delivery: Direct` and a `## Reader`
  section with the user's own description (user decision at plan review).
- `/tce:init` asks for the reader description directly, in prose, and writes
  it. Only an explicit skip leaves it **Not described** (user decision at plan
  review) — this replaces an earlier draft that recommended skipping.

## What We're NOT Doing

- Any change to how research, plan or implement *run* (TP-0045b/c). Those
  commands get only the one-line intent read, the skip of the sufficiency
  check, and the step-1 cell of their workflow tables.
- `/tce:ticket --autonomous` and quickfix's ticket creation (45c moves quickfix
  to ticketless intents).
- Any command that *acts* on `## Delivery` (push, pull request — 45b). In
  1.3.0 the section is recorded only.
- Readers of `## Reader` other than `/tce:intent` (45b's briefs).
- A `/tce:discuss` → `/tce:intent` automation beyond a hand-off line.
- Writing the new profile sections without asking.
- Backfilling the missing `tce--v1.1.0` tag.
- The `implement_eco` gap in CLAUDE.md's TP-0017 lists.

## Implementation Approach

The work runs in six phases, in dependency order. In each phase, every file
that a CLAUDE.md same-commit rule ties together is edited **in the same
phase**. All phases land as **one** commit at the end. There are two reasons:

- the TP-0022 and TP-0031 spans cross phases (`work.md` and `quickfix.md` are
  touched in Phases 4 and 1);
- the version bump must ship with everything.

Keep edits surgical: the commands are long prompts.

---

## Phase 1: The intent template and `/tce:intent`

### Overview

Create the reference template and the command. The dialogue text comes over
from `ticket.md:96-225` and `:323-343`, adapted from ticket sections to intent
sections.

### Changes Required:

#### 1. Intent document template

**File**: `plugins/tce/references/intent-document-template.md` (new)

**Header comment.** Use the HTML header comment shape of
`references/research-document-template.md:1-21`. It states:

- it is read by `/tce:intent` at the moment of writing, in full, and never
  copied into projects;
- changes to it are command-contract changes;
- the consumers are `stage.sh` (filename), the chain commands (read after the
  ticket) and, later, 45b's orchestrator;
- the frontmatter fields `ticket` and `last_updated` are read downstream.

**Skeleton:**

```markdown
---
date: YYYY-MM-DD
ticket: [PREFIX]-XXXX        # or: none
ticket_ref: <path or URL per tickets.md>   # or: none
source: <thoughts/ document path the intent was drafted from>   # omit if none
size: Small | Medium | Large | Extra Large
status: agreed | open-questions
last_updated: YYYY-MM-DD
last_updated_note: "<what changed>"   # only after an update
---

# Intent: [title]

## Ticket

[Pointer to the ticket ([PREFIX]-XXXX, path or URL). The ticket is the human's;
this file is the agreement on what it means here. "None — ticketless: <one line
on where the input came from>" when there is no ticket.]

## Scope

**In:**
- [what changes or gets built]

**Out:**
- [explicitly excluded]

## Observable outcome

[What is true when this is done — concrete enough to check.]

## Anchors

- [concrete pointer into the system: feature, screen, command, error message,
  file or code area — each confirmed to exist]

## Acceptance criteria

- [ ] [specific, testable criterion]

## Decisions

- **[decision]** — over [rejected alternative]: [one-line why]

## Open questions

[Business/product questions still unresolved — blockers. "None." when empty.]

## Questions for research

- [ ] [codebase/technical questions deferred to research and planning]

## Notes

[Size reasoning, sources, anything agreed that fits nowhere above.]
```

Rules stated under the skeleton:

- `status: open-questions` iff `## Open questions` is not "None.".
- The Decisions line shape is fixed (45b's plan `## Decisions` mirrors it).
- No section is left empty without agreement.

#### 2. The command

**File**: `plugins/tce/commands/intent.md` (new)

**Frontmatter:**

```yaml
---
description: Agree with the agent what a ticket (or ticketless input) means in this codebase — scope, outcome, anchors, criteria, decisions — and write it as an intent in thoughts/shared/intents/. Never modifies the ticket.
argument-hint: "[ticket ID | intent path | thoughts/ document | description]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)
---
```

No `disable-model-invocation`: the command is a delegation target (TP-0017).

**Body sections, in order:**

1. **Intro.**
   - What an intent is, and that the ticket is **read, never modified**:
     clarifications land in the intent, never in the ticket body.
   - Status transitions per `tickets.md` are the only ticket writes in tce,
     and this command makes none.
2. **Project context.**
   - Read `profile.md` and `tickets.md`; the `[PREFIX]-XXXX` placeholder rule.
   - **Reader** paragraph: read `## Reader` from `profile.md`.
     - If it is absent or says *Not described*, assume a reader fluent in the
       project's stack.
     - Otherwise, write every question, draft and summary for that reader:
       > use terms within their fluency without explanation; the first time a
       > term, tool, library, pattern or abbreviation outside it appears, name
       > it and say in half a sentence what it does. This governs vocabulary
       > and depth, not length — cover the substance, do not pad, and do not
       > explain what the reader already knows.
3. **`### AskUserQuestion dialog guidelines`.** A byte-identical copy of the
   block (copy from `ticket.md:36-54`).
4. **Input classification.** Modelled on `review.md:63-107`:
   - (a) **Starts with a ticket reference** per `tickets.md`: normalize it and
     fetch the ticket FULLY. If it has a parent per "Parent / epic tickets",
     fetch the parent too, for context.
   - (b) **A path into `thoughts/shared/intents/`**: the intent to update.
     Read it FULLY. If its `ticket:` is not `none`, fetch that ticket too.
   - (c) **Any other existing `thoughts/` path** (e.g. a `/tce:discuss`
     document): a source. Read it FULLY and draft from its conclusion. If the
     user also names a ticket, treat it as (a) with that source.
   - (d) **Anything else**: free description, i.e. ticketless input. With no
     argument, ask "Which ticket, or what should be built?"
5. **Branch step, ticket intents only.**
   - Verbatim the `/tce:research` "Put the ticket's branch in place" step
     (`research.md:94-130`): absent-section guard, `create`, `result:`
     handling, and the stop-and-ask dialog copy.
   - It runs **before** the existing-intent lookup, because the intent lives
     on the ticket branch.
   - Ticketless intents skip it silently.
6. **Existing intent.**
   - For (a), run `"${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh" <ID>` and read the
     `intent:` line.
   - For (b), the path is the existing intent.
   - For (d), check `thoughts/shared/intents/*-<slug>.md` for the slug you
     would use.
   - If an intent exists: read it FULLY and summarize it in three lines. Ask
     (AskUserQuestion, header "Intent") **Update it (Recommended)** — the
     dialogue starts from it as the draft and rewrites that file in place — or
     **Leave it** (stop).
   - Never create a second intent for a ticket.
7. **Sufficiency test (first step of the dialogue).**
   - The three-part test (scope determinable, outcome observable, at least one
     concrete anchor), stated as in `research.md:156-164`, with the same
     not-required list.
   - Apply it to the input. Each missing part becomes a question in the first
     round, never a separate pre-round.
   - Confirm candidate anchors with Grep/Glob; do not spawn research agents.
8. **Size assessment & track selection.** Moved from `ticket.md:96-118`, with
   "ticket" read as "intent" and the size recorded in `size:`.
9. **Compressed discussion.** Moved from `ticket.md:120-151`. Round 1's draft
   fills every intent section:
   - Scope In/Out, Observable outcome, Anchors, Acceptance criteria,
     Decisions, Open questions, Questions for research;
   - user stories are dropped;
   - Round 2 asks "Ready for me to write this intent?".
10. **Full discussion.** Moved from `ticket.md:153-225`, phases re-cut:
    1. scope (gate);
    2. outcome (gate);
    3. anchors;
    4. acceptance criteria (gate; the testability standard from old Phase 4);
    5. boundaries (Out, size check, XL split);
    6. decisions and open questions: business questions are resolved now and
       recorded as Decisions **with the rejected alternative**; technical ones
       go to Questions for research;
    7. final confirmation.
11. **Writing the intent.**
    - Read `${CLAUDE_PLUGIN_ROOT}/references/intent-document-template.md` now
      — in full, even if read earlier — and follow it exactly.
    - Path: `thoughts/shared/intents/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`, or
      `YYYY-MM-DD-<slug>.md` when ticketless. Create the directory if it is
      missing.
    - On update: keep `date`, set `last_updated` and `last_updated_note`.
    - Then use the `/tce:commit` command for a docs-only commit, e.g.
      `docs([PREFIX]-XXXX): agree intent for <brief>`, with no ticket scope
      when ticketless.
12. **Hand off.**
    - Report the path.
    - With a ticket: "When ready, run: `/tce:research [PREFIX]-XXXX` (or
      `/tce:work [PREFIX]-XXXX`)".
    - Ticketless: say it is recorded at `<path>`. A ticket for it can be
      created with `/tce:ticket`; then re-run `/tce:intent <ID>` and choose
      **Update** to link it — or, simpler, start from the ticket.
13. **Important Guidelines.** `ticket.md:323-343`, adapted:
    - drop "stories have real benefits";
    - add "every decision names its rejected alternative";
    - add "anchors are confirmed, not guessed";
    - add "never write into the ticket".

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -c "disable-model-invocation" plugins/tce/commands/intent.md` prints `0`
- [x] `intent.md`'s AskUserQuestion block is byte-identical to `ticket.md`'s
      (extract heading → last bullet from both, `diff` prints nothing)
- [x] `intent.md` contains the point-of-use read of
      `references/intent-document-template.md` and the `stage.sh` and
      `branch.sh` grants
- [x] `intent.md`'s branch stop-and-ask dialog copy is identical to
      `research.md`'s (extract and `diff`)

#### Manual Verification:

- [ ] Reading `intent.md` top to bottom: every ticket-section reference from
      the moved dialogue now names an intent section, and no user-story phase
      remains

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `007b274227dd1683116b000c420063a62cf72968`
- **Commit**: (single commit for all phases, see Phase 6)
- **Did**: new `references/intent-document-template.md` and `commands/intent.md`
  (dialogue moved from ticket.md, re-cut to intent sections; branch step from research.md)
- **Issues**: none
- **Verification**: ✅ validate tce, ✅ AskUserQuestion diff, ✅ dialog-copy diff, ✅ grants

---

## Phase 2: Slim `/tce:ticket`; route every "into the ticket" path to the intent

### Overview

`/tce:ticket` becomes human-ticket creation from the user's own text. Every
remaining hint that writes or suggests writing into a ticket body points at
the intent instead.

### Changes Required:

#### 1. `/tce:ticket`

**File**: `plugins/tce/commands/ticket.md`

- **Frontmatter `description`:** "Create a ticket in the project's ticket
  system from your own text, after one confirmation. To agree with the agent
  what to build, use /tce:intent." Keep `argument-hint`.
- **Intro (`:6-18`), rewritten in place.**
  - This command writes a human ticket; the content is the user's own words.
  - The ticket system owns the envelope.
  - The agreement with the agent is `/tce:intent`'s job.
- **Project context (`:20-34`).** Keep the `tickets.md` and `[PREFIX]` bullets.
  Replace the "step 1 of the tce chain" bullet: the chain starts with a ticket
  and its intent (`/tce:intent`), then research, plan and implement.
- **Keep the AskUserQuestion block (`:36-54`) unchanged.** The Deliver dialog
  still uses it.
- **Modes (`:56-66`).** Interactive = the short flow below. Autonomous is
  unchanged.
- **Replace `:70-266` (Initial Response through Creating the ticket)** with:
  1. **Read `tickets.md`.** Keep the not-allowed "Heads up" block from
     `:74-83` verbatim.
  2. **Pointer, printed once:**

     ```
     This writes a ticket for humans into [system], in your words. To agree with
     the agent what to build — scope, anchors, criteria, decisions — use
     /tce:intent (on the new ticket, or on its own for work without a ticket).
     ```

  3. **Take the text.**
     - The argument, or ask "What should the ticket say?".
     - Do not interview and do not add requirements.
     - Tidy formatting only, keeping the user's wording and substance.
     - If the user wants to discuss the requirements, suggest `/tce:intent`.
  4. **Assemble.**
     - Derive a concise title.
     - Fill the meta lines the adapter's "Ticket title & body layout"
       requires. Where it needs an Estimated Complexity, propose one word with
       a half-line reason.
     - Show title and body once.
  5. **Create**, keeping today's creation-policy text from `:237-258`:
     - the allowed path with its one confirmation and the docs-only commit for
       file backends;
     - the not-allowed Deliver dialog and its two paths.
  6. **Hand off:** "When ready, run: `/tce:intent [PREFIX]-XXXX`". On the
     copy/paste path: "once you've created it, run `/tce:intent <ID>`".
- **"The ticket body" (`:268-321`).** Rename to "Autonomous ticket body" and
  say it is used only by autonomous mode. Keep its skeleton unchanged
  (quickfix depends on it).
- **Important Guidelines (`:323-343`).** Replace with three:
  - the user's words are the content;
  - one confirmation, never an interview;
  - discussion belongs in `/tce:intent`.
- **Autonomous mode (`:345-360`):** unchanged.

#### 2. `tickets.md` template and this repo's copy

**Files**: `plugins/tce/templates/tce/tickets.md`, `.claude/tce/tickets.md`

- **`:34-40` (template).** `/tce:ticket` "still runs the authoring discussion
  but offers the result as copy/paste-able content" → "still assembles the
  ticket with you but offers it as copy/paste-able content".
- **`:44-49` (template).** "The author-facing body *structure* itself is owned
  by `/tce:ticket`" → "The body is the author's own text; tce's structured
  agreement lives in the intent (`/tce:intent`), not in the ticket."
- **`:87-88` comment.** "also what /tce:ticket and human ticket authors should
  aim for" → "also what /tce:intent applies and human ticket authors should
  aim for".
- **`:110-111`.** Replace with:
  > `/tce:intent` applies this test with you as its first step. Without an
  > intent, `/tce:research` (and `/tce:work`) apply it before researching.
- **This repo's copy:** apply the same `## What tce needs from a ticket` text.
  The backend sections stay as written.

#### 3. Hand-off and suggestion sites

- **`plugins/tce/commands/discuss.md`.**
  - `:16`: "This is NOT: ticket creation (e.g. `/tce:ticket`)" → "This is NOT:
    agreeing a piece of work (`/tce:intent`), …".
  - After step 4 of "Writing the Document", add step 5: "If the conclusion is
    something to build, suggest `/tce:intent <this document's path>` (add a
    ticket ID if one exists)."
- **`plugins/tce/commands/design_explore.md:348`:** "If there's an active
  ticket, suggest updating it with the design decision" → "If there's an
  active ticket with an intent, suggest re-running `/tce:intent <ID>` to
  record the design decision there — never in the ticket."
- **`plugins/tce/commands/init.md:513-514`:** "start the workflow from a
  ticket: [/tce:ticket guides authoring … — then /tce:research <ID> or
  /tce:work <ID>]" → "[create a ticket in your system (or with /tce:ticket),
  agree its intent with /tce:intent <ID> — then /tce:research <ID> or
  /tce:work <ID>]".
- **`plugins/tce/commands/quickfix.md:286`:** "create a properly discussed
  ticket instead (e.g. via `/tce:ticket`, or in their ticket system)" →
  "create a ticket (via `/tce:ticket` or in their ticket system), agree its
  intent with `/tce:intent`, and run the normal workflow".
- **Workflow tables, step-1 row:** `research.md:47`, `plan.md:47`,
  `implement.md:27`, `review.md:33`.
  - Change the row to `| 1 | ticket + intent | Capture the ticket in the
    project's ticket system (e.g. `/tce:ticket`) and agree its intent
    (`/tce:intent`) |`.
  - It is one line each; the four tables stay identical to one another.
- **`research.md:93`.** The parenthetical "(e.g. you just authored it via
  `/tce:ticket` in the same session)" → "(e.g. you just created it via
  `/tce:ticket` in the same session)".

### Success Criteria:

#### Automated Verification:

- [x] `grep -n "tce:research" plugins/tce/commands/ticket.md` prints no
      hand-off line (the only hits are, at most, the chain description)
- [x] `grep -n "Compressed discussion\|Full discussion\|Phase 4: Define acceptance" plugins/tce/commands/ticket.md` prints nothing
- [x] `ticket.md`'s Autonomous mode section is byte-identical to before
      (`git diff` shows no change inside `## Autonomous mode`)
- [x] `grep -rn "suggest updating it with the design decision" plugins/tce` prints nothing
- [x] The four workflow-table step-1 rows are identical (`grep -h "^| 1 |"` on
      the four files and `sort -u` gives one line)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] `ticket.md` reads as a short command: no interview, pointer printed
      first, the Deliver dialog intact

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (single commit for all phases, see Phase 6)
- **Did**: ticket.md slimmed (AskUserQuestion block, body skeleton, Autonomous mode unchanged);
  tickets.md template + repo copy; discuss, design_explore, init, quickfix hand-offs; 4 workflow tables
- **Issues**: body heading named `The ticket body (autonomous mode only)`, not `Autonomous ticket body`
  — Autonomous mode (kept byte-identical) refers to it by its old name
- **Verification**: ✅ greps, ✅ Autonomous mode unchanged, ✅ one step-1 row, ✅ validate tce

---

## Phase 3: Discovery — `stage.sh` and `/tce:list`

### Overview

`stage.sh` reports the intent; `/tce:list` shows it. Per the TP-0033 rule,
both change together.

### Changes Required:

#### 1. `stage.sh`

**File**: `plugins/tce/scripts/stage.sh`

- **Before editing**, capture the baseline:
  `plugins/tce/scripts/stage.sh $(ls thoughts/shared/tickets | grep -o '^TP-[0-9]*[a-z]*' | sort -u) > <scratchpad>/stage-before.txt`
- **Header (`:2-3`, `:12-17`):** "its intent, its research document, its plan
  document, …". Document the appended line as the sixth line:

  ```
  #   source:   log | sidecar | unknown | no-plan
  #   intent:   <path relative to the project root, empty when none>
  ```

  Add one sentence: `intent:` is appended last so that the first five lines
  keep their position.
- **`:61-62`:** add `INTENTS_DIR="$THOUGHTS_DIR/shared/intents"`.
- **`:252-253`:** add `INTENT="$(find_doc "$INTENTS_DIR" "$TICKET" "")"`.
- **After `:288`:** add
  `printf 'intent:   %s\n' "${INTENT:+${INTENT#"$ROOT"/}}"`.
- **`find_doc`:** unchanged. The delimited match already keeps an epic off its
  sub-tickets' intents.

#### 2. `branch.sh` header comment

**File**: `plugins/tce/scripts/branch.sh:11`

`create -- for /tce:research:` → `create -- for /tce:research and
/tce:intent:`. Comment only.

#### 3. `/tce:list`

**File**: `plugins/tce/commands/list.md`

- **`description` (`:2`):** "… their tce workflow stage — intent, research
  document, plan document, and implementation progress."
- **`:8-10` intro:** add "does it have an intent".
- **`:96-104`:** "one six-line record"; add `intent:   <path, empty when none>`
  as the last record line.
- **Columns (`:120-124`):** `Ticket` | `Title` | `Priority` | `Status` |
  `Intent` | `Research` | `Plan` | `Implementation` | `Complexity`.
- **Cell rule (`:135`):** `**Intent** / **Research** / **Plan** — ✓ when the
  script reported a path, – otherwise.`
- **Epic rule (`:142-145`):** "The epic's **Intent**, **Research** and
  **Plan** cells reflect only documents the epic itself has."
- **Example table (`:200-214`):** add the Intent column, with plausible ✓ and –
  values.

### Success Criteria:

#### Automated Verification:

- [x] **First five lines unchanged.** Re-run the baseline command into
      `stage-after.txt`, strip the `intent:` lines, and `diff` against
      `stage-before.txt` (records separated by blank lines). The diff prints
      nothing.
- [x] **Fixture.**
  - Set up a scratch project with `thoughts/shared/{intents,research,plans}`
    and the intents `2026-10-11-X-0100-epic.md` and
    `2026-10-11-X-0100a-sub.md`.
  - Run `CLAUDE_PROJECT_DIR=<scratch> plugins/tce/scripts/stage.sh X-0100 X-0100a X-0101`.
  - Expected: the three intent paths come out as their own path, their own
    path, and empty. The epic must not get the sub-ticket's intent.
- [x] **Ticketless.** A slug-only intent `2026-10-11-some-slug.md` in the
      fixture is reported for no ID.
- [x] `grep -n "five-line" plugins/tce/commands/list.md` prints nothing
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] `/tce:list` in a scratch project with one intent renders a table that
      does not collapse into cards at a 120-column terminal

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (single commit for all phases, see Phase 6)
- **Did**: stage.sh appends `intent:` (6th line, INTENTS_DIR + lookup); branch.sh header comment;
  list.md description, record, Intent column, cell + epic rules, example table
- **Issues**: none
- **Verification**: ✅ corpus diff (53 records, first five lines identical), ✅ X-0100/X-0100a/X-0101/slug fixture, ✅ no "five-line", ✅ validate tce

---

## Phase 4: Chain reads and the sufficiency skip

### Overview

Wherever a command reads the ticket in chain order, it reads an existing
intent right after it. Research and work skip the sufficiency check when an
intent exists. These are minimal, one-line edits.

### Changes Required:

#### 1. Ordered re-read sites (TP-0013)

- **`plugins/tce/commands/research.md:93` (Discovery step 2).** Append: "If
  the discovery script (step 4) returns an intent
  (`thoughts/shared/intents/`), read it FULLY right after the ticket — it is
  the agreed meaning of the ticket and takes precedence over the ticket's
  wording."
- **`plugins/tce/commands/plan.md:65`.** "in chain order (ticket → research)"
  → "in chain order (ticket → intent, if one exists → research)".
- **`plugins/tce/commands/implement.md:79`.** After item 2, add item "2b. Read
  the **intent**, if the discovery script found one — the agreed scope,
  criteria and decisions". Keep the existing numbering of 3 and 4 by using
  "2b".
- **`plugins/tce/commands/review.md:140`.** Insert the bullet "Intent
  (`thoughts/shared/intents/*[PREFIX]-XXXX*.md`), if one exists" after the
  ticket bullet.
- **`plugins/tce/commands/work.md`:**
  - `:73` (Phase 1a.1): append the same sentence as research.
  - `:219`: "(ticket → research document)" → "(ticket → intent, if one exists
    → research document)".
  - `:251`: "(ticket → research → plan)" → "(ticket → intent, if one exists →
    research → plan)".
- **`plugins/tce/commands/quickfix.md:134` (Phase 3.1).** Append "and its
  intent, if one exists". This is for composite parity; quickfix creates no
  intents yet.

#### 2. Sufficiency skip (TP-0022 span)

- **`research.md:151-170`.** Before "After reading the ticket …", insert:

  > **If an intent exists for the ticket, skip this check** — `/tce:intent`
  > applied it with the user. Otherwise apply it as below; when it fails,
  > mention that `/tce:intent` is the place to agree these points durably.

  Leave the three criteria untouched.
- **`work.md:102` (Phase 1a step 5).** Prefix: "If an intent exists, skip this
  step (`/tce:intent` applied the test); otherwise run the ticket sufficiency
  check …".

### Success Criteria:

#### Automated Verification:

- [x] `grep -c "intent" ` on `research.md`, `plan.md`, `implement.md`,
      `review.md`, `work.md` and `quickfix.md` gives ≥1 for each
- [x] `git diff --stat` for `research.md`, `plan.md`, `implement.md`,
      `review.md` and `quickfix.md` shows only small hunks (no section
      rewrites: each file ≤ ~10 changed lines across Phases 2 and 4)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] The sufficiency criteria in `templates/tce/tickets.md`, `research.md`,
      `work.md` and `intent.md` agree in substance (TP-0022 check)

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (single commit for all phases, see Phase 6)
- **Did**: intent read after the ticket in research, plan, implement (2b), review, work (3 sites), quickfix;
  sufficiency skip in research.md and work.md step 5
- **Issues**: a perl `$12b` capture typo dropped implement.md item 2 — restored
- **Verification**: ✅ intent count ≥1 in all six, ✅ small hunks (≤8 lines/file), ✅ validate tce

---

## Phase 5: `## Delivery` and `## Reader` — template, init, refresh

### Overview

Two new agreed sections with the branch-convention lifecycle. Neither section
present means the default.

### Changes Required:

#### 1. Profile template

**File**: `plugins/tce/templates/tce/profile.md`

Insert after `## Branch convention` (after `:97`) and before
`## Preferred research sources`:

```markdown
## Delivery

How a ticket's finished work reaches your main line. `/tce:init` agrees this with
you; the orchestrating `/tce:work` reads it to know whether its job ends with a
pull request (until a tce release acts on it, it is a recorded agreement only).
tce never merges.

[Filled by `/tce:init` with one of:

- **Direct** — no pull request: the work stays on the branch the branch
  convention put it on, and you take it from there. (The default — identical to
  leaving this section out.)
- **Pull request** — requires **Branch per ticket** above and uses its base
  branch and remote:
  - tce pushes the ticket branch and opens a pull request against the base branch;
  - **you** review and merge it — tce never merges;
  - the next ticket starts only after the previous ticket's pull request is
    merged.]

## Reader

Who reads tce's questions, drafts and summaries. Commands that address you —
`/tce:intent` today — write for this reader: terms within their fluency are used
without explanation; the first time a tool, library, pattern or abbreviation
outside it appears, it is named and explained in half a sentence. This governs
vocabulary and depth, not length.

[Filled by `/tce:init` with one of:

- **Not described** — tce assumes a reader fluent in this project's stack. (The
  default — identical to leaving this section out.)
- **Described:** <two or three lines on the reader's fluency, e.g. "Fluent in PHP
  and Laravel; new to the TypeScript ecosystem — name a library or pattern the
  first time it appears and say in half a sentence what it does.">]
```

#### 2. `/tce:init`

**File**: `plugins/tce/commands/init.md`

- **`:40-46` overview tree:** add `intents` to `thoughts/shared/{…}`.
- **Phase 1, new gather item 11** after `:155`, "Delivery & reader":
  - Delivery suggests **Pull request** only when item 10 suggested Branch per
    ticket *and* found merge commits; otherwise **Direct**.
  - Reader has nothing to detect.
  - Both are only suggestions.
- **Phase 2:** after the branch dialogs (`:335`), add two verbatim dialogs.
  - **Delivery**: asked only when the branch answer is **Branch per ticket**.
    With **Current branch**, fill **Direct** without asking.

    ```
    How should a ticket's finished work be delivered? By default tce leaves it on
    the ticket branch and you take it from there. With a pull request, tce opens
    one against the base branch when /tce:work finishes, you review and merge it,
    and the next ticket starts only once it is merged. It's recorded in
    .claude/tce/profile.md and you can change it there anytime.
    ```

    Question: "How should finished ticket work be delivered?" — header:
    "Delivery". Options (suggestion first, with " (Recommended)" and a
    "Detected: …" prefix):
    1. **Direct** — no pull request; the work stays on the ticket branch for
       you to take further.
    2. **Pull request** — tce opens a pull request against the base branch;
       you merge it before the next ticket starts.
  - **Reader**:

    ```
    tce can phrase its questions and summaries for you. If you are fluent in some
    of this project's stack and new to other parts, describe that in two or three
    lines and tce will explain only the unfamiliar parts. It's recorded in
    .claude/tce/profile.md — tighten it there as you learn.
    ```

    The answer is free-form, so ask **in prose**, not with AskUserQuestion
    (per the dialog guidelines). After the intro, ask: "Describe yourself as
    the reader in two or three lines — which parts of this stack you know
    well, and which are new to you." Offer one example line, built from the
    detected Tech stack, e.g. "Fluent in <stack A>; new to <tool B> — name it
    and say in half a sentence what it does the first time it appears."
    - Write what the user gives as the **Described** bullet, lightly tidied
      but in their words.
    - Only an explicit "skip" or "none" fills **Not described**. Silence is
      not a skip: re-ask.
- **Phase 3 refine list (`:343-346`):** "… commit convention, branch
  convention, delivery, reader, preferred research sources, …".
- **Phase 4 step 1 fill sentence (`:379-381`):** add "Delivery, Reader" to the
  section list. After the branch-convention fill paragraph (`:395-400`), add:
  - "For **`## Delivery`** and **`## Reader`**, replace the bracketed guidance
    with just the chosen bullet, keeping the intro paragraph above it."
  - "For **Described**, write the user's lines in place of the
    `<…>` placeholder, lightly tidied but in their words."
- **Phase 4 step 4 scaffold (`:457`):**
  `for d in research plans reviews mockups discussions intents; do`.
- **Idempotency (`:534-553`):** add a bullet after the 1.2.0 one:

  > A `profile.md` without `## Delivery` and `## Reader` sections (added in tce
  > 1.3.0) needs them inserted, in that order, directly after `## Branch
  > convention`. Run the Delivery dialog (only under Branch per ticket — else
  > fill **Direct**) and the Reader prompt from Phase 2, and fill from the
  > answers. **Direct** is what the project effectively had so far, so it is
  > the safe answer; for Reader, write what the user describes, and only an
  > explicit skip fills **Not described**. The user may decline the upgrade;
  > an absent section behaves exactly like its default. Also create
  > `thoughts/shared/intents/` with a `.gitkeep` if it is missing.

#### 3. `/tce:refresh`

**File**: `plugins/tce/commands/refresh.md`

Name `## Delivery` and `## Reader` beside `## Branch convention` at all four
hand-authored sites:

- **`:31-33` Scope.** "So are `profile.md`'s `## Branch convention`,
  `## Delivery` and `## Reader` — a branch model, a delivery rule and a reader
  description are team or personal policy, not something re-analysis can
  verify; `/tce:init` adds them when a profile predates them."
- **`:91-93` Phase 1 parenthetical.** Extend it to all three sections.
- **`:108-109` Phase 2 preserved list.** Add both sections.
- **`:136-137` Phase 3 "only offer to touch" list.** Add both sections.

#### 4. This repo's profile

**File**: `.claude/tce/profile.md`

- Insert `## Delivery` with the **Direct** bullet after `## Branch
  convention`.
- Insert `## Reader` after it with the **Described** bullet holding the
  user's text (supplied at plan review):

  ```markdown
  - **Described:** Fluent in bash, git, and Claude Code skills and agents. Not
    so fluent in Claude Code hooks and mods — name a hook event, hook field or
    mod mechanism the first time it appears and say in half a sentence what it
    does.
  ```
- Set the marker to `1.3.0`.

### Success Criteria:

#### Automated Verification:

- [x] **Section order.** `grep -n "^## " plugins/tce/templates/tce/profile.md`
      shows Branch convention → Delivery → Reader → Preferred research
      sources
- [x] **Delivery dialog.** `grep -n "How should finished ticket work be delivered" plugins/tce/commands/init.md` hits once
- [x] **Reader prompt.** `grep -n "Describe yourself as the reader" plugins/tce/commands/init.md` hits once
- [x] **refresh.md.** `grep -c "## Delivery" plugins/tce/commands/refresh.md`
      ≥ 4, and the same for `## Reader`
- [x] **Scaffold.** `grep -n "discussions intents" plugins/tce/commands/init.md` hits the scaffold loop
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] `/tce:init` in a scratch project:
  - choosing Current branch fills Delivery: Direct without asking;
  - choosing Branch per ticket asks the Delivery dialog;
  - the Reader prompt asks for prose, and the answer lands verbatim-ish in
    `## Reader`.
- [ ] `/tce:init` re-run against a 1.2.0 profile offers the 1.3.0 upgrade and
      inserts both sections after Branch convention

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (single commit for all phases, see Phase 6)
- **Did**: profile template Delivery + Reader; init.md gather 11, two dialogs, refine/fill, intents scaffold,
  1.3.0 Idempotency bullet; refresh.md four sites; repo profile (Direct, Described, marker 1.3.0)
- **Issues**: none
- **Verification**: ✅ section order, ✅ dialog + prompt hit once, ✅ refresh 4/4, ✅ scaffold, ✅ validate tce

---

## Phase 6: Docs, governance, release

### Overview

READMEs, manifests, check-init wording, CLAUDE.md rules, version bump and tag.

### Changes Required:

#### 1. tce README

**File**: `plugins/tce/README.md`

- **`:4`.** The chain → "**ticket → intent → research → plan → implement**".
- **"See it work" (`:45-47`).** Split into:
  - `/tce:ticket` — your words into the tracker;
  - `/tce:intent` — you and tce agree scope, anchors, criteria and decisions
    in `thoughts/shared/intents/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md`,
    and the ticket stays untouched.
  - Renumber the following steps, and add `intents/` to the tree below it.
- **`:156-160` init description.** Add "the **delivery** rule (direct or pull
  request) and an optional **reader** description".
- **`:166` tree comment.** "commit + branch convention, delivery, reader".
- **`:169`.** `thoughts/shared/{intents,research,plans,reviews,mockups,discussions}/`.
- **`:199`.** The chain wording.
- **Core workflow table (`:203-208`).**
  - `/tce:ticket` → "Create a ticket in your ticket system from your own text
    (any backend)".
  - New row: `/tce:intent` — "Agree with tce what the ticket means here
    (scope, anchors, criteria, decisions); never edits the ticket".
  - "the four-step context chain" → "the context chain".
- **`:237-239` refresh line.** "leaving your hand-written Conventions, branch,
  delivery and reader sections and research sources untouched".
- **Parameterization (after `:284`).** Two bullets:
  - **Delivery**: Direct = default = absent. Pull request requires Branch per
    ticket and reuses its base and remote; you merge; next ticket after merge.
    Recorded now, acted on by `/tce:work` in a later release.
  - **Reader**: absent = fluent reader. Read by `/tce:intent`; governs
    vocabulary and depth, not length.
- **Document templates bullet.** Mention the intent template next to the
  research and plan templates.

#### 2. Manifests, catalog, check-init (keep in sync per CLAUDE.md)

- **`plugins/tce/.claude-plugin/plugin.json`:**
  - `version` → `1.3.0`;
  - `description` and the `userConfig.show_setup_reminders.description` chain
    → "ticket → intent → research → plan → implement".
- **`.claude-plugin/marketplace.json:14-15`:**
  - `version` → `1.3.0`;
  - description "Authors tickets (/tce:ticket)" → "Agrees intents
    (/tce:intent)"; chain wording.
- **`plugins/tce/scripts/check-init.sh:91`:** the chain wording.
- **`README.md:23` (root catalog):** the chain wording.

#### 3. CLAUDE.md

**File**: `CLAUDE.md`

- **Layout tree, `plugins/tce/references/*.md` line.** Unchanged; the comment
  is generic.
- **Core design rule, the "tmt owns the ticket envelope" bullet.**
  - Replace "`/tce:ticket` authors ticket content to meet them" with
    "`/tce:intent` records the agreed meaning in an intent;
    `/tce:ticket` writes the human's own text".
  - Add: "**No tce command writes into an existing ticket's body** —
    clarifications, research findings and decisions go into the intent (or
    the research/plan); status transitions per `tickets.md` are the only
    ticket writes. That applies to sessions in this repo too: do not fold
    findings into tickets."
- **New section "The intent spans a template, a command and the discovery
  (TP-0045a)".** State:
  - what an intent is;
  - the naming;
  - that `ticket.sh` finds it unchanged.
  - **RULE:** when you change the intent's sections, frontmatter or naming,
    update `references/intent-document-template.md`, `commands/intent.md`,
    `scripts/stage.sh` (if naming/location) and `commands/list.md` in the
    same commit.
  - `/tce:intent` runs `branch.sh create` like research. This is why it joins
    the TP-0031 span.
- **TP-0031 section.**
  - Add `plugins/tce/commands/intent.md` to the bullet list: `create`, before
    the existing-intent lookup, with the duplicated stop-and-ask dialog.
  - Add `intent.md` to the RULE's file list ("update `research.md`,
    `intent.md`, …") and to "the research step or its dialog copy … update
    `work.md`, `quickfix.md` and `intent.md`".
  - Ticket creation still never branches.
- **New section "Agreed profile sections: Delivery and Reader follow the
  branch-convention lifecycle (TP-0045a)".**
  - **RULE:** when you change either section's options or sub-fields, update
    the template, `init.md`'s dialogs + fill + Idempotency bullet,
    `refresh.md`'s four hand-authored sites and `plugins/tce/README.md`
    together.
  - The absent-section guard must never be weakened.
  - Readers in 1.3.0: Reader → `intent.md`; Delivery → none yet.
- **TP-0017 section.** Add `intent` to the delegation targets with the
  reason: unflagged by decision; interactive sessions, `/tce:discuss` and
  later `/tce:quickfix` hand off to it. Note that `/tce:ticket` stays a
  delegation target for quickfix's `--autonomous`.
- **AskUserQuestion section.**
  - "twelve" → "thirteen".
  - Add `intent` to the tce file list `{init,intent,research,plan,work,quickfix,refresh,ticket}`.
  - "five of the twelve copies" → "five of the thirteen".
- **TP-0022 section.**
  - "triplicated" → four copies.
  - Add `plugins/tce/commands/intent.md` as the place the test is **applied
    with the human** (operational, first step of the dialogue).
  - Note that research/work skip it when an intent exists.
  - Fix "Phase 1 step 4" → "Phase 1a step 5".
- **TP-0033 section.**
  - "five-line record" → "six-line record (the `intent:` line appended
    last)".
  - "maps IDs onto `thoughts/` documents" stays.
- **TP-0013 section.** Chain becomes ticket → intent → research → plan, with
  `/tce:intent` as a consumer too (it re-reads the ticket and any existing
  intent).

#### 4. Release

- Bump as above. Commit everything (all phases) with `/tce:commit`:
  `feat(TP-0045a): add /tce:intent and the reader and delivery profile sections`.
- Then run `claude plugin tag ./plugins/tce` and confirm with
  `git tag --list 'tce--v*'`.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce`,
      `./plugins/tmt`, `./plugins/tle`, `./plugins/tsf` all pass
- [x] All thirteen AskUserQuestion blocks are byte-identical (extract each
      from `### AskUserQuestion dialog guidelines` to its last bullet and
      diff pairwise against `plugins/tce/commands/ticket.md`'s)
- [ ] `grep -rn "ticket → research → plan" plugins/tce README.md .claude-plugin`
      prints nothing
- [x] `jq -r .version plugins/tce/.claude-plugin/plugin.json` and the tce
      entry in `.claude-plugin/marketplace.json` both print `1.3.0`
- [ ] `git tag --list 'tce--v1.3.0'` prints the tag
- [x] `bash -n plugins/tce/scripts/check-init.sh plugins/tce/scripts/stage.sh plugins/tce/scripts/branch.sh` passes

#### Manual Verification:

- [ ] **End to end in a scratch tmt project** after
      `/plugin marketplace update toby-plugins`:
  - `/tce:ticket` creates a ticket from your own text after one confirmation
    and hands off to `/tce:intent`;
  - `/tce:intent <ID>` runs the sufficiency-first dialogue and writes
    `thoughts/shared/intents/…-<ID>-….md`, while the ticket file is unchanged
    (`git diff` on it is empty);
  - a re-run offers Update and rewrites the same file;
  - `/tce:list` shows ✓ under Intent.
- [ ] `/tce:intent <free text>` writes a slug-named intent with
      `ticket: none`

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (see Implementation Closeout)
- **Did**: tce README; plugin.json + marketplace.json 1.3.0 and chain wording; check-init.sh; root README;
  CLAUDE.md (no-body-writes rule, intent + profile-section spans, TP-0031/0017/0013/0022/0033, 13 copies)
- **Issues**: `quickfix.md` description keeps `ticket → research → plan → implement` — accurate, quickfix
  creates no intent until TP-0045c; the chain grep is otherwise clean
- **Verification**: ✅ validate (marketplace + 4 plugins), ✅ 13 AskUserQuestion copies identical, ✅ 1.3.0 in both, ✅ bash -n

---

## Testing Strategy

### Unit Tests:

There is no test suite. Script behaviour is verified by:

- the `stage.sh` baseline diff, which shows the first five lines unchanged;
- the X-0100 / X-0100a / slug fixture, which checks epic isolation and
  ticketless invisibility.

### Integration Tests:

- `claude plugin validate` on the marketplace and all plugins.
- The thirteen-copy AskUserQuestion diff.
- The dialog-copy diff between `research.md` and `intent.md`.

### Manual Testing Steps:

1. In a scratch tmt project with the updated marketplace, run `/tce:ticket Add
   tagging to documents`. Confirm there is no interview, a single
   confirmation, and the `/tce:intent` hand-off.
2. Run `/tce:intent <ID>`. Check that missing anchors are asked about in round
   1, and that the intent file has every template section with Decisions
   naming their rejected alternatives.
3. Re-run `/tce:intent <ID>`. Check that it offers Update and that no second
   file appears.
4. Run `/tce:research <ID>`. Check that it reads the intent after the ticket
   and asks no sufficiency questions.
5. Run `/tce:init` in a fresh scratch project with Branch per ticket. Check
   that the Delivery dialog and the Reader prompt appear and the profile
   sections are filled.

## Performance Considerations

None. The only extra cost is one more directory scan per `stage.sh` ID.

## Migration Notes

- Un-upgraded profiles (no Delivery or Reader) behave identically: every
  reader treats an absent section as its default, and in 1.3.0 only
  `/tce:intent` reads Reader.
- Existing projects get `thoughts/shared/intents/` from the 1.3.0 Idempotency
  step, or on the first `/tce:intent` write.
- Existing tickets and research documents are untouched. Tickets without an
  intent keep working: research applies the sufficiency check as before.

## References

- Original ticket: `thoughts/shared/tickets/TP-0045a-intent-reader-delivery.md`
- Epic: `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md`
- Related research: `thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md`
- Design discussion: `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md`
- Pattern followed: `thoughts/shared/plans/2026-09-05-TP-0031-declarable-branch-convention.md`
- `stage.sh` verification pattern: `thoughts/shared/plans/2026-09-09-TP-0033-tce-list-workflow-stage.md:262-293`
