---
date: 2026-11-02
ticket: TP-0045h
ticket_ref: thoughts/shared/tickets/TP-0045h-design-exploration-in-intent.md
size: Medium
status: agreed
last_updated: 2026-11-02
---

# Intent: decide design exploration in the intent, not in the planner

## Ticket

TP-0045h (`thoughts/shared/tickets/TP-0045h-design-exploration-in-intent.md`),
a sub-ticket of the TP-0045 epic. The ticket is the human's; this file is the
agreement on what it means here.

## Scope

**In:**
- `/tce:intent` applies the design-exploration check — the planner's current
  test, moved: a non-trivial UX change (new UI patterns, a significantly
  altered user flow, a layout redesign; not bug fixes, text changes, style
  tweaks, a field on an existing form, or simple CRUD screens following
  established patterns). It asks the human only when the test triggers. The
  check is a separate step after the three-part sufficiency test, not a fourth
  criterion of it.
- The intent records the outcome in one fixed, greppable form with three
  values: the `DECISION.md` path; `plan directly — <reason>` (including "not a
  UX change"); or `pending` (explore first).
- On `pending`, `/tce:intent` writes and commits the intent, then tells the
  human to run `/tce:design_explore <ID>`. When the exploration finishes in the
  same session, `/tce:intent` continues: it finds the committed `DECISION.md`,
  writes its path into the record, and commits again — no second full
  dialogue. A later `/tce:intent <ID>` → Update does the same.
- The step loop (`work-loop.md`) stops before any agent is dispatched when the
  intent's record is `pending`, naming `/tce:design_explore <ID>`.
- The planner follows the record (reads the `DECISION.md`, or plans directly)
  and asks its existing design-exploration question only when the intent has
  no record (intents written before this change).
- `/tce:design_explore` names its mockup folder
  `thoughts/shared/mockups/<YYYY-MM-DD>-<ID>-<slug>/` (`<ID>` = the canonical
  ticket ID, or the intent's slug when ticketless) and commits the whole folder
  (mockup HTML, `index.html`, `DECISION.md`) through `/tce:commit`. Its
  hand-off keeps suggesting `/tce:intent <ID>` → Update for the case where the
  session did not continue.
- `/tce:intent --autonomous` (quickfix) applies the UX test too: when it
  triggers, it returns `insufficient: design — non-trivial UX change, agree an
  intent with /tce:intent` and writes nothing; otherwise it records
  `plan directly — quickfix (autonomous)`.
- tce version bump; the human creates the tag outside the sandbox.

**Out:**
- What a design exploration produces beyond the folder name and the commit.
- The form of the planner's questions (TP-0047).
- Migrating existing intents or renaming existing mockup folders — older
  intents keep working through the planner's fallback.
- Recording the design decision in the ticket — the ticket is never written.
- Changing the three-part sufficiency test or its two copies (TP-0022 rule).

## Observable outcome

A `/tce:work` run on a UX ticket whose intent carries a record asks no
design-exploration question during planning; an intent recorded `pending`
stops the run before any agent starts, with the `/tce:design_explore`
instruction. After `/tce:design_explore TP-NNNN`, `ticket.sh TP-NNNN` lists the
folder's `DECISION.md` and `git status` shows the folder committed. A quickfix
description that is a non-trivial UX change is refused with
`insufficient: design — …`.

## Anchors

- `plugins/tce/agents/planner.md:99-109` — the design exploration check (to
  become the fallback)
- `plugins/tce/references/work-loop.md:178-180` — Step 3's note on design
  exploration
- `plugins/tce/references/work-loop.md:222-224` — Step 6's stop for design
  exploration
- `plugins/tce/commands/intent.md` — the dialogue, the sufficiency test, the
  Autonomous mode
- `plugins/tce/references/intent-document-template.md` — where the record goes
- `plugins/tce/commands/design_explore.md:158` — the mockup folder name;
  `:290-348` — Phase 5, `DECISION.md` and the hand-off
- `plugins/tce/scripts/ticket.sh` — the recursive substring lookup that must
  find the folder

## Acceptance criteria

- [ ] `intent.md` contains the UX test and the design-exploration question,
      as a step after the sufficiency test; the intent template defines the
      record and its three values (`DECISION.md` path, `plan directly —
      <reason>`, `pending`).
- [ ] When `/tce:design_explore` finishes in the same session, `intent.md`
      instructs updating a `pending` record to the `DECISION.md` path and
      committing; a later `/tce:intent <ID>` → Update does the same.
- [ ] The planner's design exploration check reads the intent's record first
      and asks only when the record is absent; the old question survives only
      in that fallback.
- [ ] `work-loop.md` stops on a `pending` record before any agent dispatch,
      naming `/tce:design_explore <ID>`; Step 6's design-exploration stop
      remains only for the fallback.
- [ ] `design_explore.md` creates
      `thoughts/shared/mockups/<YYYY-MM-DD>-<ID>-<slug>/` and its Phase 5
      commits the whole folder via `/tce:commit`.
- [ ] `intent.md`'s Autonomous mode records `plan directly — quickfix
      (autonomous)`, and returns `insufficient: design — …` for a description
      that meets the UX test; `/tce:quickfix` handles that return.
- [ ] In a scratch project, `ticket.sh <ID>` finds a `DECISION.md` in a folder
      named by the new rule, for a ticket ID and for a ticketless slug.
- [ ] `claude plugin validate` passes for the marketplace and all plugins;
      tce version bumped, tag handed to the human.

## Decisions

- **The design-exploration check moves to `/tce:intent`** — over keeping it
  as the planner's first question: in GH-37 a "stop" answer wasted a 112k-token
  planner run and dropped its 7 other questions (human decision in the GH-37
  findings).
- **A `pending` record stops every step command before research** — over
  `/tce:intent` writing no intent until the exploration is done: the
  exploration needs the agreed scope, and nothing is dispatched in vain.
- **Only `/tce:intent` writes the `DECISION.md` path into the intent;
  in-session it continues after the exploration, otherwise the human re-runs
  it** — over `/tce:design_explore` writing into the intent: one writer of
  intents; the human usually explores in the same session, so the intent
  command is still there to continue.
- **`/tce:design_explore` commits the whole mockup folder** — over
  `DECISION.md` only: the decision points at its mockup file, which a later
  reader needs.
- **Autonomous intents record `plan directly — quickfix (autonomous)` and
  refuse UX work with `insufficient: design — …`** — over leaving no record
  (the planner would ask, breaking quickfix's no-question run): work that needs
  a design exploration is not a quick fix.
- **The design check is a step after the sufficiency test** — over a fourth
  sufficiency criterion: keeps the TP-0022 two-copy test (and `tickets.md`'s
  canonical copy) untouched.
- **The planner keeps a fallback for intents without a record** — over
  requiring a `/tce:intent` re-run for older intents: existing intents keep
  working unchanged.
- **The UX test is the planner's current wording, moved** — over redesigning
  it: the ticket is about where the check runs, not what it tests.

## Open questions

None.

## Questions for research

- [ ] Where does the record sit — a frontmatter line or an
      `## Design exploration` section — and does `stage.sh` or `list.md` need
      it (CLAUDE.md intent span)?
- [ ] Does `ticket.sh`'s substring match find the new folder name for both a
      ticket ID and a ticketless slug, without an epic claiming its
      sub-tickets' folders?
- [ ] How does `/tce:quickfix` handle an `insufficient:` return today, and
      does a fourth reason (`design`) need a change there?
- [ ] Which CLAUDE.md same-commit spans are touched (intent span, loop span,
      ticketless naming span, the delegation graph for the in-session
      `/tce:intent` → `/tce:design_explore` continuation, given `design_explore`
      carries `disable-model-invocation`)?
- [ ] Do `README.md`, `quickfix.md` or `check-init.sh` mention the planner's
      design question or the mockup folder name?

## Notes

Size Medium: about six tce files across two same-commit spans (intent, loop),
no new mechanism. Sources: the GH-37 findings
(`thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md`,
finding 1) and TP-0045d's research ("Items H to L").
