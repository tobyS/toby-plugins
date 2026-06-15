---
date: 2026-06-15
ticket: TP-0007
git_commit: 72856ca
branch: main
researcher: Claude (tce:work)
topic: "Splitting ticket authoring (tce payload) from the ticket envelope (tmt)"
status: complete
tags: [tce, tmt, tickets, adapter, refactor, migrations]
---

# Research: TP-0007 — Split ticket authoring (tce payload) from the ticket envelope (tmt)

## Summary

The work is well-supported by the existing architecture; nothing here requires new
infrastructure, only re-arrangement plus one new command per plugin. Key findings:

- **`/tmt:create` cleanly separates** into envelope (a small "Writing the Ticket"
  block, ~25 lines) and content authoring (the 7-phase discussion + the markdown
  body template + 8 guideline rules, ~470 lines). The content is what moves to a
  new `/tce:ticket`; the envelope stays in tmt.
- **The status enum is hardcoded in three scripts** (authoritative copy at
  `validate-ticket-status.sh:75`), enforced by a `PostToolUse Edit|Write` hook that
  is **path+pattern gated**, so *any* writer (tce writing a status line, or a new
  `/tmt:update`) passes through the same validation automatically — no registration.
  This is the "enforcement boundary" the discussion relied on.
- **`tickets.md` already encodes fragments of the lifecycle→action mapping** in the
  "Creating a ticket" and "Status / completion" sections, but as per-moment prose,
  with **no "reject" moment and no title/body layout**. The adapter slots into the
  backend-filled region (between sections 1–6 and the backend-independent section 7).
- **`/tce:refresh` is profile-only today** and explicitly anticipates covering
  `tickets.md` later (`refresh.md:26-27`) — extending it is in scope.
- **The research drift check is a profile-only triplet** (detect / doc-section /
  advisory) mirrored into `quickfix.md` and `work.md`; extending it to the adapter
  means adding a parallel "tickets drift" path in all three.
- **Commands are auto-discovered** — adding `commands/ticket.md` (tce) and
  `commands/update.md` (tmt) needs no manifest edit (only version bumps).
- **`/tce:quickfix` already invokes `tce:plan` and `tce:implement` as skills** but
  *inlines* ticket creation. This opens a cleaner option than the discussion
  assumed (see Decisions, Q1).

## Research questions (from the ticket) and answers

1. **Where does the adapter slot into `tickets.md`, and what already encodes it?**
   Sections "Creating a ticket" (`templates/tce/tickets.md:32-37`) and "Status /
   completion" (`:39-45`) already carry the create/start/complete moments as prose.
   Missing: a **reject** moment and a **title/body layout**. The adapter belongs in
   the backend-filled region (sections 1–6), which `/tce:init` Phase 4 populates
   (`init.md:300-321`); section 7 ("What tce needs from a ticket", `:47-74`) is
   fenced "keep as-is" and must stay untouched.
2. **How does `/tce:init` discover the backend and what does it write?** Detection
   at `init.md:102-115`; the ticket-system + status-policy + creation-policy dialog
   at `:184-253` (verbatim copy); per-system fill guidance at `:300-321`. It asks
   *which system / status-update policy / creation policy* — not title/body layout
   or a reject moment today. `/tce:refresh` does **not** re-derive any of this yet.
3. **Where does authoring content live so quickfix can mirror it?** There is **no
   runtime shared-file mechanism** (commands can't read each other's or templates'
   markdown at runtime; only project config + shipped scripts are shared). So
   `/tce:ticket` and `quickfix.md` each inline the body layout — unless quickfix
   instead invokes `/tce:ticket` as a skill (Q1).
4. **tmt enum — hardcoded or declared data?** Hardcoded: validity list at
   `validate-ticket-status.sh:75` (`Open|In Progress|Done|Rejected`), plus policy
   subsets in `open_tickets.sh:47` (which count as "open") and
   `check-ticket-status.sh:90-94` (reminder transitions). No config/declared copy.
5. **`/tmt:update` feasibility?** All primitives exist. `lib.sh` has exactly two
   helpers — `tmt_project_root` (`:12-14`) and `tmt_ticket_prefix` (`:22-35`); the
   find-by-ID glob and the `grep '^**Status:**'` read idiom are inlined per-script.
   A status write passes through `validate-ticket-status.sh` automatically.
6. **Versioning?** Current: tce `3.0.1`, tmt `1.0.1` (in both `plugin.json` and the
   matching `marketplace.json` entry). See Decisions / Impact.
7. **Migration specifics?** tce: the Idempotency upgrade list is the parenthetical
   at `init.md:415-418` ("adding the missing comment line is the only one today");
   the `tce-config-version` marker lives on `profile.md:1`. tmt: the upgrade list is
   `init.md:235`; the marker is `TMT_CONFIG_VERSION` in `.claude/tmt/config`.

## Detailed findings

### A. tmt — envelope vs. content in `/tmt:create`

`plugins/tmt/commands/create.md` (499 lines).

- **Content to extract → `/tce:ticket`:** frontmatter/intro `:1-55`; Phases 1–7
  `:57-289`; the markdown body sections inside the template `:323-370`; "Populate
  every section" `:372-378`; "Important Guidelines" (8 rules) `:395-499`.
- **Envelope to keep:** "Writing the Ticket" steps `:291-313` — determine number via
  `"${CLAUDE_PLUGIN_ROOT}/scripts/next-ticket.sh"` (`:296`), sub-ticket letter suffix
  (`:297`), filename convention (`:300-303`), "check downstream consumer
  expectations" reading tce's `tickets.md` (`:305-309`), write location (`:311`); and
  the header lines `:316-321` (`# [PREFIX]-XXXX:`, `**Status:** Open`,
  `**Estimated Complexity:**`, `**Created:**`, `**Updated:**`). "Present the result"
  `:379-393`.

Per decision 1b, gutted `/tmt:create` keeps the envelope + a *gentle, content-agnostic*
nudge (no prescribed body sections) + a one-line reminder about `/tce:ticket` when
tce is present.

### B. tmt — status enum + validation hook (the enforcement boundary)

- Validity enum (authoritative): `validate-ticket-status.sh:75`
  `VALID_STATUSES="Open|In Progress|Done|Rejected"`; human-readable descriptions at
  `:83-86`.
- Policy subsets (semantic, not just the enum): `open_tickets.sh:47` (Open / In
  Progress = "open"); `check-ticket-status.sh:90-94` (Open→In Progress→Done reminder
  transitions). `list.md:1,3` references "Open or In Progress" in prose. Template
  default `**Status:** Open` at `create.md:318`.
- Hook: `hooks.json:13-21`, `PostToolUse` matcher `Edit|Write` →
  `validate-ticket-status.sh`. Script: sources `lib.sh`, no-ops if no prefix
  (`:33-36`); reads stdin JSON; extracts `file_path` and `new_string // content`
  (`:40-43`); **gates on path** `thoughts/shared/tickets/<PREFIX>-*.md` (`:53`) and
  **presence of a `**Status:**` line** (`:59`); validates (`:75-78`); emits advisory
  `additionalContext` (`:89-97`); always `exit 0` — **advises, never blocks, and does
  not check transition legality**.
- Consequence for TP-0007: tce's direct status writes and `/tmt:update`'s writes both
  pass through this hook with no new wiring. The enum being scattered means
  `/tmt:update` would add a 4th copy unless centralized (see Impact / Decisions note).

### C. tmt — numbering, location, helpers, `/tmt:update` feasibility

- `next-ticket.sh`: prefix via `tmt_ticket_prefix` (`:18`, errors if unset),
  `TICKETS_DIR=$(tmt_project_root)/thoughts/shared/tickets` (`:24`), highest-number
  scan (`:33-39`), `printf "%s-%04d"` (`:49`).
- `lib.sh`: only `tmt_project_root` (`:12-14`) and `tmt_ticket_prefix` (`:22-35`,
  with legacy `.claude/tce/config` fallback). No `tmt_tickets_dir`, `tmt_find_ticket`,
  or `tmt_read_status` — each script inlines those.
- `/tmt:update` can reuse: `tmt_ticket_prefix`, `tmt_project_root`, the find glob
  (`check-ticket-status.sh:84`), the status read idiom (`open_tickets.sh:44`), and an
  Edit/Write to the `**Status:**` line (validated by the hook). It needs the enum for
  its AskUserQuestion options — argues for a tiny `tmt_valid_statuses` helper.

### D. tmt — config + version markers + idempotency

- `templates/tmt/config`: `TICKET_PREFIX=` (`:6`), `TMT_CONFIG_VERSION=` (`:10`).
- `/tmt:init` stamps the marker from `plugin.json` version (`init.md:130-132`);
  compares on re-run (`:228-237`); the upgrade list today is the single parenthetical
  at `:235`. Adding `/tmt:update` needs **no new config key**, so no upgrade-list
  entry is forced unless the create/update split changes required config.

### E. tce — `tickets.md` template structure (adapter target)

`templates/tce/tickets.md` (74 lines). Sections in order: preamble `:1-6`; System
`:8-11`; Canonical ticket ID `:13-18`; Reading a ticket `:20-24`; Parent/epic
`:26-30`; Creating a ticket `:32-37`; Status / completion `:39-45`; What tce needs
`:47-74` (fenced "keep as-is", `:49-50`). The adapter (lifecycle→action mapping with
an explicit **reject** moment + a **title/body layout**) extends the create/status
sections and slots into the backend-filled region.

### F. tce — `/tce:init` discovery + idempotency + marker

- Detection `init.md:102-115`; dialog (verbatim) `:184-253` (system `:195-205`,
  status policy `:225-241`, creation policy `:243-249`); per-system fill `:300-321`.
- `tce-config-version` marker written `:296-298`, compared `:409-418`; upgrade list =
  the parenthetical at `:415-418`. **TP-0007 must add the adapter to the fill
  guidance + dialog and add an upgrade-list entry + bump the marker.**

### G. tce — `/tce:refresh` scope

Profile-only today; explicitly anticipates `tickets.md` (`refresh.md:26-27`). Phase 1
re-derives Tech stack / Commands / Code map only (`:49-69`); version marker handling
`:108-114`. Extending to reconcile the adapter is in scope and must stay in lock-step
with init (the `CLAUDE.md` refresh↔init rule).

### H. tce — research drift triplet (+ mirrors)

`research.md`: sanctioned-exception preamble `:68-72`; detection step 4 `:218-225`;
"Profile Drift" doc-section template `:324-329`; advisory step 8 `:345-347`. Mirrors:
`quickfix.md:185` (detect) + `:270-272` (advisory); `work.md:85` (detect) + `:144-147`
/ `:177-179` (advisory). Extending to the adapter = a parallel "tickets drift" path in
all three files.

### I. tce — `/tce:quickfix` ticket creation

Precondition (creation-not-allowed → STOP) at `:18` and `:99-100`. Phase 2 `:96-167`;
"hosted vs tmt" branch `:102-110`; **inlined tmt template `:112-162`** (the duplication
to re-point); commit step `:164-168`. Crucially, quickfix **invokes `tce:plan` and
`tce:implement` as skills** (`:203`, `:225`) with autonomy overrides, but **inlines
research and ticket creation**. So quickfix could invoke a new `tce:ticket` skill the
same way (Q1).

### J. Registration, the AskUserQuestion block, versions

- **Auto-discovery:** no manifest lists commands (`plugins/*/.claude-plugin/plugin.json`
  carry only name/version/description/author/keywords; tce also has the
  `show_setup_reminders` userConfig). Adding command files suffices.
- **AskUserQuestion block:** 7 byte-identical copies — `tce/{init:15, research:18,
  plan:18, work:26, quickfix:24, refresh:29}` + `tmt/init:14`. `/tce:ticket` (and
  `/tmt:update`, if it has a dialog) become new copies; the `CLAUDE.md` rule at
  `:204-219` (count "seven" `:205`, file list `:209-210`) must update.
- **Versions:** tce `plugin.json:3` = `3.0.1` + `marketplace.json:15`; tmt
  `plugin.json:3` = `1.0.1` + `marketplace.json:21`.

## Exhaustive edit-site checklist (for planning)

- **New files:** `plugins/tce/commands/ticket.md`, `plugins/tmt/commands/update.md`.
- **tmt gut/refactor:** `plugins/tmt/commands/create.md` (extract content, keep
  envelope + nudge); optionally `plugins/tmt/scripts/lib.sh` (+`tmt_valid_statuses`)
  and `validate-ticket-status.sh` to source it.
- **tce adapter + discovery:** `templates/tce/tickets.md` (adapter section);
  `init.md` (dialog `:184-253`, fill `:300-321`, upgrade list `:415-418`); `refresh.md`
  (bring `tickets.md` into scope `:26-27`, Phase 1/2).
- **tce drift:** `research.md` triplet (`:218-225`/`:324-329`/`:345-347`) + mirrors
  `quickfix.md` (`:185`,`:270-272`) and `work.md` (`:85`,`:144-147`,`:177-179`).
- **tce quickfix creation:** `quickfix.md:96-168` (re-point Phase 2 — inline-mirror or
  skill per Q1; update `:22`, `:107-110`, `:112-162`, `:278`).
- **`/tmt:create` references to reword:** `quickfix.md:22,110,278`; `research.md:46`;
  `plan.md:46`; `implement.md:26`; `review.md:31`; `discuss.md:15`; `init.md:397`
  (tce). `tmt/create.md:43`; `tmt/init.md:212` (and the frozen `create_ticket.md`
  migration names at `tmt/init.md:83,156` **must stay** per `CLAUDE.md:150-157`).
- **Workflow-chain framings ("step 1 = ticket creation"):** `README.md:10`;
  `marketplace.json:14`; `tce/plugin.json:4`; `tmt/plugin.json:4`; `check-init.sh:85`;
  `tmt/README.md:11-12`; `tmt/create.md:20`; `tce/README.md:33,135`;
  `research.md:46`/`plan.md:46`/`implement.md:26`/`review.md:31`.
- **READMEs:** `tce/README.md` Commands table `:128-145` (+`/tce:ticket` row); `tmt/README.md`
  "What you get" `:14-19`, Commands table `:73-79` (+`/tmt:update` row, reword create),
  "Using tmt with tce" `:108-115`; root `README.md:69` layout comment.
- **CLAUDE.md rules:** "tmt owns the ticket envelope" `:58-66`; Migrations/version
  markers `:127-160` (+ idempotency rule `:136-139`); Composite-commands sync
  `:161-188` (reword the `/tmt:create`-mirror clause `:182-183`); refresh↔init `:189-203`
  (now refresh DOES change tickets.md scope); AskUserQuestion duplication `:204-219`;
  Layout comment `:33`; Releasing `:233-243`.
- **Releases:** bump tce + tmt in `plugin.json` + `marketplace.json`; tag via
  `claude plugin tag` (see Decisions — leave tagging to the user).

## Impact Analysis (shared code reused/extended)

- **`validate-ticket-status.sh` hook** is the reused enforcement boundary for both
  tce status writes and `/tmt:update` — no change needed for it to apply, but if the
  enum is centralized, this script should source the helper.
- **`lib.sh` helpers** are reused by `/tmt:update`; adding `tmt_valid_statuses` is the
  one low-risk extension that prevents a 4th hardcoded enum copy. The policy subsets
  in `open_tickets.sh` / `check-ticket-status.sh` are semantic and stay as-is.
- **The composite-command sync rule** and **the AskUserQuestion duplication rule** are
  process invariants that this ticket extends (new command copies, quickfix re-point).
- **The refresh↔init sync rule** changes character: refresh gains a section that *does*
  change what `tickets.md` must contain — the `CLAUDE.md` note "(refresh) does not
  change what profile.md must contain" (`:199-200`) needs nuancing for tickets.md.

## Open questions / decisions for the checkpoint

1. **quickfix ↔ `/tce:ticket` integration** — give `/tce:ticket` an autonomous mode and
   have quickfix invoke it as a skill (eliminates the inlined template entirely, like
   plan/implement), or keep quickfix inlining a structure that mirrors `/tce:ticket`
   under the composite rule (what the discussion literally said). See Phase 2.
2. **Implementation autonomy** — given the breadth (two plugins, public commands, a
   release), proceed autonomously through implementation per `/tce:work`, or stop after
   the committed plan for review. Releases (`claude plugin tag`) will be left to the
   user regardless.

Decided from research/discussion (not asked): tmt enum stays plugin-internal (not
project-configurable) per the discussion's lean — centralized into a `lib.sh` helper
only to avoid a 4th copy; `/tce:ticket` carries the rich body layout moved from
`/tmt:create`; versioning leans tce minor / tmt minor (Impact).

## Profile drift

None. `profile.md` accurately reflects the stack (markdown/bash/JSON, no
test/typecheck/lint runtime beyond `claude plugin validate`), the commands, and the
code map; no high-confidence drift observed during research.
