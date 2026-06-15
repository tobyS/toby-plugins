---
date: 2026-06-15
ticket: TP-0007
git_commit: f5f8261
branch: main
planner: Claude (tce:work)
topic: "Split ticket authoring (tce payload) from the ticket envelope (tmt)"
status: ready
tags: [tce, tmt, tickets, adapter, refactor, migrations]
---

# Implementation Plan: TP-0007 — Split ticket authoring (tce) from the ticket envelope (tmt)

## Overview

Introduce a backend **adapter** in tce's `tickets.md`, a new interactive
`/tce:ticket` command that owns ticket richness (with an autonomous mode), gut
tmt's `/tmt:create` to envelope-only, add `/tmt:update`, re-point `/tce:quickfix`
to invoke `/tce:ticket` as a skill, extend drift detection to the adapter, and
update docs/rules/versions. The seam: **tmt owns the envelope** (numbering, file
location, heading, status enum + validation hook); **tce owns the payload** (the
authoring discussion and the rich body), persisting through the adapter.

## Current state (from research, commit f5f8261)

- `/tmt:create` (`plugins/tmt/commands/create.md`) welds content authoring
  (`:1-289`, body sections `:323-370`, guidelines `:395-499`) to a small envelope
  block (`:291-313`, header `:316-321`).
- Status enum hardcoded at `validate-ticket-status.sh:75`; enforced by a
  path+pattern-gated `PostToolUse Edit|Write` hook (`hooks.json:13-21`) that any
  status writer passes through automatically. `lib.sh` has only `tmt_project_root`
  and `tmt_ticket_prefix`.
- `tickets.md` template encodes create/start/complete as prose (`:32-45`); **no
  reject moment, no title/body layout**. Section 7 (`:47-74`) is fenced "keep as-is".
- `/tce:init` discovery+dialog `:184-253`, fill `:300-321`, idempotency upgrade list
  `:415-418`, marker on `profile.md:1`. `/tce:refresh` is profile-only (`:26-27`
  anticipates tickets.md). Research drift triplet `research.md:218-225 / 324-329 /
  345-347`, mirrored in `quickfix.md` (`:185`, `:270-272`) and `work.md` (`:85`,
  `:144-147`, `:177-179`).
- `/tce:quickfix` inlines a tmt ticket template (`:112-162`) but already invokes
  `tce:plan`/`tce:implement` as skills (`:203`, `:225`).
- Commands auto-discovered (no manifest list). AskUserQuestion block = 7 identical
  copies. Versions: tce `3.0.1`, tmt `1.0.1` (plugin.json + marketplace.json).

## Desired end state

- `/tce:ticket` is the single home of ticket richness, interactive by default with
  an **autonomous mode**; persists via the adapter; works on any backend.
- The adapter in `tickets.md` defines a **lifecycle→action mapping**
  (create/start/complete/**reject**) + a **title/body assembly** rule (how the
  backend wraps a title + a body blob). `/tce:init` and `/tce:refresh` discover and
  reconcile it; the research drift check covers it.
- `/tmt:create` is envelope-only + a gentle content-agnostic nudge; `/tmt:update`
  changes status via the lifecycle vocabulary, validated by the existing hook.
- `/tce:quickfix` invokes `/tce:ticket` (autonomous) — no inlined template.
- Docs/rules updated; both plugins version-bumped (tce `3.1.0`, tmt `1.1.0`).
  Release **tags left for the user**.

## What we're NOT doing

- Not making the tmt status enum **project-configurable** (no `TMT_STATES` in
  `.claude/tmt/config`) — per the discussion's lean. We only centralize it into a
  plugin-internal `lib.sh` helper to avoid a 4th hardcoded copy.
- Not building concrete Jira/Linear adapters (mechanism stays generic; verified for
  tmt + GitHub by description).
- Not having tce **delegate** transitions to tmt at runtime (rejected in discussion).
- Not running `claude plugin tag` / publishing a release.

## Key design notes

- **Title/body split:** the adapter's "title/body assembly" is an *envelope*
  concern (for tmt: `# {id}: {title}` heading + `**Status:**` lines + body blob in a
  file; for GitHub: issue title + issue body). The **rich body structure** (Problem
  / Desired Outcome / User Stories / Acceptance Criteria / Out of Scope / Open
  Questions / Questions for Research-Planning / References / Notes) is *payload*,
  inlined once in `/tce:ticket` and reused by its autonomous mode (so quickfix
  inherits it for free).
- **`/tce:ticket` modes:** interactive (full discussion + creation flow:
  warn-if-forbidden, one-time override, copy/paste fallback, always ask final
  permission before any backend write, then hand off to `/tce:research`);
  autonomous (invoked with a description + an autonomous directive: no discussion,
  size Small, auto-fill body, create via adapter, return the canonical ID, no
  interaction). Quickfix keeps its own "creation not allowed → STOP" precondition
  and only invokes `/tce:ticket` autonomously when creation is allowed.
- **Dogfooding:** this repo's own `.claude/tce/tickets.md` (tmt backend) is updated
  to the new adapter shape and its `profile.md:1` marker bumped to `3.1.0`, since the
  tce config requirements changed. tmt's `.claude/tmt/config` is unchanged (no new
  key) so its marker stays.

---

## Phase 1: `tickets.md` adapter + init/refresh discovery + migration

**Files:** `plugins/tce/templates/tce/tickets.md`, `plugins/tce/commands/init.md`,
`plugins/tce/commands/refresh.md`, `.claude/tce/tickets.md` (dogfood),
`.claude/tce/profile.md` (marker).

1. **`templates/tce/tickets.md`:** extend the backend-filled region with the adapter
   without disturbing section 7. Reframe "Creating a ticket" and "Status /
   completion" so the four lifecycle moments are explicit, add the **reject** moment,
   and add a new **"## Ticket title & body layout"** section describing how the
   backend wraps a title + a body blob (placeholder guidance for tmt / hosted). Keep
   the `[bracketed]` placeholder style and the "commands run this verbatim" tone.
2. **`init.md`:** in the per-system fill guidance (`:300-321`) add the reject action
   and the title/body assembly for tmt, GitHub, Jira/Linear/custom. Add the adapter
   to what the dialog covers if needed (no new question if it can be derived per
   system; otherwise extend the status-policy dialog copy — keep dialog copy verbatim
   and mirror across the AskUserQuestion-block contract if touched). Add an
   **Idempotency upgrade-list entry** at `:415-418` ("v3.1.0 adds the lifecycle
   adapter + title/body layout to `tickets.md` — add them if missing") and ensure the
   marker bump path covers it.
3. **`refresh.md`:** bring the `tickets.md` adapter into scope (it is currently
   excluded at `:26-27`). Add a Phase-1 re-derivation target + Phase-2 classification
   for the adapter (factual, backend-derived), kept in lock-step with init. Update the
   "Scope" note to reflect tickets.md is now covered.
4. **Dogfood:** update `.claude/tce/tickets.md` to the new adapter shape (tmt
   backend) and bump `.claude/tce/profile.md:1` marker to `3.1.0`.

**Automated success criteria:**
- [ ] `claude plugin validate .` and `./plugins/tce` and `./plugins/tmt` pass.

**Manual success criteria:**
- [ ] `templates/tce/tickets.md` shows all four lifecycle moments (create/start/
      complete/reject) and a title/body layout section; section 7 byte-unchanged.
- [ ] `init.md` fill guidance covers the new fields for tmt + GitHub; idempotency
      upgrade list has a v3.1.0 entry.
- [ ] `refresh.md` Phase 1/2 includes the adapter and the Scope note no longer
      excludes tickets.md; stays consistent with init's targets.
- [ ] Dogfooded `.claude/tce/tickets.md` matches the new shape; `profile.md:1` =
      `3.1.0`.

---

## Phase 2: New `/tce:ticket` command (interactive + autonomous)

**Files:** `plugins/tce/commands/ticket.md` (new).

1. Create `ticket.md` with frontmatter (description + argument-hint) and the moved
   authoring discussion (the 7-phase WHAT & WHY content from `create.md:57-289` +
   the 8 guideline rules `:395-499`), adapted to be backend-agnostic (read
   `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md`; no tmt literals).
2. Inline the **rich body layout** once (the section set) and persist via the
   adapter's create action. Title comes from the discussion; body is the rich blob;
   assembly per the adapter.
3. **Creation flow** (interactive): read the adapter's "Creating a ticket". If
   creation is allowed → run discussion → **ask final permission** → create → suggest
   `/tce:research <ID>`. If not allowed → **warn upfront** that nothing is written →
   run the full discussion → offer a **one-time override** → on no override present a
   **copy/paste-able body** + instructions; on override **ask final permission** then
   create. Always ask final permission before any backend write.
4. **Autonomous mode:** when invoked with a description + an autonomous directive
   (used by quickfix), skip the discussion, set size Small, auto-fill the body from
   the description, create via the adapter, return the canonical ID, no interaction.
5. Add the **AskUserQuestion dialog guidelines block** (byte-identical copy from an
   existing command, e.g. `quickfix.md:24-42`).

**Automated success criteria:**
- [ ] `claude plugin validate ./plugins/tce` and `.` pass; `/tce:ticket` is
      discovered (command file present).

**Manual success criteria:**
- [ ] Interactive + autonomous modes both specified; creation-flow covers allowed /
      forbidden / override / copy-paste / always-final-permission.
- [ ] The rich body layout is inlined once and reused by autonomous mode.
- [ ] AskUserQuestion block is byte-identical to the other copies (diff check).
- [ ] No stack or ticket-system literals (reads the adapter).

---

## Phase 3: Gut `/tmt:create` + add `/tmt:update` + centralize the enum

**Files:** `plugins/tmt/commands/create.md`, `plugins/tmt/commands/update.md`
(new), `plugins/tmt/scripts/lib.sh`, `plugins/tmt/scripts/validate-ticket-status.sh`.

1. **`create.md`:** reduce to envelope-only — determine number, filename, write the
   heading + `**Status:** Open` + meta lines + an (optional) free-form body the user
   provides. Replace the 7-phase discussion with a **gentle, content-agnostic nudge**
   (a short "a good ticket usually states the problem, the desired outcome, and what's
   out of scope; you own the content") and, **when tce is present**, a one-line
   reminder that `/tce:ticket` provides guided authoring (a nudge, not a redirect).
   Keep the "check downstream consumer expectations" reference and the sub-ticket
   convention.
2. **`lib.sh`:** add `tmt_valid_statuses` printing the canonical enum
   (`Open|In Progress|Done|Rejected`) as the single internal source.
3. **`validate-ticket-status.sh`:** source the helper instead of the inline literal
   at `:75` (behaviour unchanged).
4. **`update.md` (new `/tmt:update`):** take a ticket reference + target status (or
   lifecycle verb). Resolve prefix (`tmt_ticket_prefix`), locate the file (the find
   glob), read current status, Edit the `**Status:**` line (validated by the hook).
   Offer status options via AskUserQuestion sourced from `tmt_valid_statuses`. Include
   the AskUserQuestion block. Not invoked by tce.

**Automated success criteria:**
- [ ] `claude plugin validate ./plugins/tmt` and `.` pass.
- [ ] Script smoke tests against a throwaway project
      (`CLAUDE_PROJECT_DIR=/tmp/tp0007`, `.claude/tmt/config` with `TICKET_PREFIX=FAKE`,
      `thoughts/shared/tickets/`): `next-ticket.sh` still returns `FAKE-0001`;
      `tmt_valid_statuses` prints the four statuses; piping a valid and an invalid
      `**Status:**` Edit JSON into `validate-ticket-status.sh` accepts the valid and
      advises on the invalid (unchanged behaviour).

**Manual success criteria:**
- [ ] `create.md` no longer contains the 7-phase discussion or prescribed body
      sections; it has the nudge + tce reminder + envelope steps.
- [ ] `update.md` exists with the AskUserQuestion block (byte-identical) and reuses
      existing helpers; status write goes through the validation hook.
- [ ] The enum literal exists in exactly one place (`lib.sh`); policy subsets in
      `open_tickets.sh` / `check-ticket-status.sh` left as-is.

---

## Phase 4: Re-point `/tce:quickfix` + extend drift detection to the adapter

**Files:** `plugins/tce/commands/quickfix.md`, `plugins/tce/commands/research.md`,
`plugins/tce/commands/work.md`.

1. **quickfix Phase 2:** replace the inlined template (`:112-162`) and the tmt/hosted
   branch with: keep the "creation not allowed → STOP" precondition; when allowed,
   **invoke the `tce:ticket` skill** (autonomous mode) with the understanding from
   Phase 1, receive the canonical ID, then continue. Update the lock-step note
   (`:22`) and rule #1 (`:278`) to reference `/tce:ticket` instead of the tmt
   template.
2. **Drift extension:** extend the research drift **triplet** to also reconcile the
   `tickets.md` adapter (detection step alongside `:218-225`; a "Ticket-system Drift"
   doc-section alongside `:324-329`; advisory alongside `:345-347`), recommending
   `/tce:refresh`. **Mirror** the same extension into `quickfix.md` (`:185`,
   `:270-272`) and `work.md` (`:85`, `:144-147`, `:177-179`) per the composite rule.

**Automated success criteria:**
- [ ] `claude plugin validate ./plugins/tce` and `.` pass.

**Manual success criteria:**
- [ ] quickfix invokes `tce:ticket` (autonomous) and no longer carries an inlined
      template; precondition preserved.
- [ ] Drift detection covers the adapter in `research.md` and is mirrored in
      `quickfix.md` and `work.md`.
- [ ] AskUserQuestion blocks still byte-identical across all copies.

---

## Phase 5: Docs, rules, and version bumps

**Files:** `CLAUDE.md`, `README.md`, `plugins/tce/README.md`,
`plugins/tmt/README.md`, the `/tmt:create`-reference command files, manifests.

1. **Reword `/tmt:create` references** (now envelope-only) and **workflow-chain
   framings** ("step 1 = ticket creation") to reflect `/tce:ticket` as the tce
   authoring entry: `tce` commands `quickfix.md` (already in Phase 4), `research.md:46`,
   `plan.md:46`, `implement.md:26`, `review.md:31`, `discuss.md:15`, `init.md:397`;
   `tmt/create.md:43`, `tmt/init.md:212`; `README.md:10`, `marketplace.json:14`,
   `tce/plugin.json:4`, `tmt/plugin.json:4`, `check-init.sh:85`, `tmt/README.md:11-19,
   73-79,108-115`, `tce/README.md:33,128-145`, root `README.md:69`. **Leave the frozen
   `create_ticket.md` migration names** (`tmt/init.md:83,156`, `tmt/README.md:70`,
   `CLAUDE.md:144`) **unchanged** per `CLAUDE.md:150-157`.
2. **READMEs:** add a `/tce:ticket` row to `tce/README.md` Commands table and a
   `/tmt:update` row to `tmt/README.md` Commands table; reword tmt "What you get".
3. **CLAUDE.md rules:** update "tmt owns the ticket envelope" (`:58-66`) for the
   payload/envelope split + `/tce:ticket`; Migrations/version markers (note the v3.1.0
   tce upgrade-list entry); Composite-commands sync (`:182-183` now: quickfix invokes
   `/tce:ticket`); refresh↔init (`:189-203`) — nuance that refresh now also covers the
   `tickets.md` adapter (so it *does* track an init config requirement here);
   AskUserQuestion duplication (`:204-219`) — update the count to **nine** and add
   `tce/ticket.md` + `tmt/update.md` to the file list; Layout comment (`:33` add
   `/tmt:update`; tce commands wildcard already covers ticket).
4. **Version bumps:** tce `3.0.1 → 3.1.0` (`plugin.json:3` + `marketplace.json:15`);
   tmt `1.0.1 → 1.1.0` (`plugin.json:3` + `marketplace.json:21`). **No tagging.**

**Automated success criteria:**
- [ ] `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` pass.
- [ ] `grep -rn "/tmt:create" plugins/ CLAUDE.md README.md` shows only intended
      remaining references (the frozen `create_ticket.md` migration names and the
      gutted `create.md`'s own usage line).

**Manual success criteria:**
- [ ] All workflow-chain framings and `/tmt:create` references reflect the split.
- [ ] CLAUDE.md AskUserQuestion rule says nine copies and lists the two new files;
      the byte-identical block check passes across all nine.
- [ ] Both READMEs list the new commands; manifests show `3.1.0` / `1.1.0` in both
      plugin.json and marketplace.json.

---

## Testing strategy

- **Per phase:** `claude plugin validate .` + `./plugins/tce` + `./plugins/tmt`.
- **Scripts (Phase 3):** throwaway project smoke tests (next-ticket, tmt_valid_statuses,
  validate-ticket-status accept/advise).
- **Invariants (final):** extract the `### AskUserQuestion dialog guidelines` block
  from all nine command files and diff them pairwise — must be byte-identical.
- **Reference sweep (final):** `grep -rn "/tmt:create"` and the workflow-chain strings
  to confirm only intended references remain.

## Migration notes

- Existing tce projects: re-running `/tce:init` walks them through adding the adapter
  to `tickets.md` (new idempotency entry) and bumps the marker; `/tce:refresh` also
  reconciles it. This repo's dogfooded config is updated in Phase 1.
- Existing tmt projects: no `.claude/tmt/config` change; `/tmt:create` keeps working
  (envelope-only), `/tmt:update` is additive.

## References

- Ticket: `thoughts/shared/tickets/TP-0007-tce-ticket-authoring-tmt-envelope-split.md`
- Research: `thoughts/shared/research/2026-06-15-TP-0007-tce-ticket-authoring-tmt-envelope-split.md`
- Discussion: `thoughts/shared/discussions/2026-06-15-tce-ticket-authoring-vs-tmt-envelope.md`
