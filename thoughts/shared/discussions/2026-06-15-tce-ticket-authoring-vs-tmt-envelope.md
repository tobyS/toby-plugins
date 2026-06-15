---
date: 2026-06-15
topic: "Ticket authoring for non-tmt backends: envelope (tmt) vs. payload (tce) split"
status: complete
---

# Technical Discussion: Ticket authoring for non-tmt backends — splitting envelope from payload

## Challenge

A project that uses **GitHub Issues** (not tmt) as its tce ticket backend has the
full `/tce:*` workflow available, and `/tce:quickfix` can even create a GitHub
issue autonomously. What it lacks is an **interactive, guided** way to author a
well-structured ticket — the thing the predecessor claude-template offered as
`/create_ticket` and that survives today only as tmt's `/tmt:create`. Because
`/tmt:create` is tmt-specific (it owns numbering, file location, the status enum)
it isn't available — and shouldn't be made available — in a GitHub-backed project.

How do we give every tce-attached backend a guided "author a proper ticket"
experience without coupling the plugins or duplicating logic?

## Key insight: ticket creation is two layers, and tce already owns one

A `/tmt:create` ticket welds together two separable concerns:

1. **Authoring (payload)** — the guided WHAT & WHY discussion (problem, outcome,
   user stories, acceptance criteria, boundaries, open questions). Completely
   backend-independent.
2. **Persistence (envelope)** — numbering, filename, the `**Status:**` enum, the
   `thoughts/shared/tickets/` location. tmt-specific, and already abstracted by
   tce behind `tickets.md` → "Creating a ticket".

tce can *already* create tickets in any backend — but only **autonomously**, via
`/tce:quickfix` (which reads `tickets.md` and runs `gh issue create` or writes a
tmt file). The missing capability is the **interactive** counterpart. That
asymmetry is the whole problem.

## Approaches Explored

### A. New `/tce:create`, duplicating the discussion under a sync rule

**How it works**: tce gains a guided ticket-authoring command that runs the same
discussion as `/tmt:create`, then persists via `tickets.md`. `/tmt:create` stays
as-is.

**Pros**: Fits the existing abstraction (quickfix already creates via
`tickets.md`); gives back the missing interactive path for any backend.

**Cons**: The discussion logic would exist in **both** `/tce:create` and
`/tmt:create`, governed by a keep-in-sync rule — another duplicated-with-a-rule
artifact (like quickfix's inlined template and the 7× AskUserQuestion block). It
*relocates* duplication rather than removing it.

### B. (Chosen) Split envelope from payload: tmt = envelope-only, `/tce:ticket` = payload

**How it works**: Draw the seam at envelope vs. payload.

- **tmt becomes envelope-only.** It owns prefix/ID, numbering, file location,
  heading format, the status enum and its validation hook — and nothing about
  ticket *content*. `/tmt:create` mints the envelope, lets the user write whatever
  content they like, gently inspires them, and states the user owns the content.
  When tce is present it adds a one-line reminder that `/tce:ticket` handles
  richness — a nudge, never a redirect or block.
- **tce gains `/tce:ticket`**, the single home of "what a good tce ticket
  contains." It runs the guided discussion (the former `/tmt:create` richness),
  assembles a compliant ticket via the backend adapter (creating the envelope the
  way `/tce:quickfix` does today), and hands off to `/tce:research`.
- **`/tce:init` / `/tce:refresh`** discover the attached ticket system and write
  the **adapter** into `tickets.md`.
- **`/tce:quickfix`** re-points its autonomous creation to mirror `/tce:ticket`
  (intra-tce, under the existing composite-command sync rule) instead of inlining
  tmt's template.

**Pros**: Removes the duplication instead of relocating it — content authoring
lives in exactly one place because it's *deleted* from tmt, not copied. Converts
quickfix's cross-plugin template mirror into an intra-tce one already governed by
an existing rule. Cleaner conceptual ownership: tmt = envelope, tce = payload.

**Cons**: Bigger change (an epic). tmt's **standalone** value drops: with tce
absent, `/tmt:create` goes from rich guided authoring to "envelope + free-form
body + light nudge." Accepted deliberately (decision 1 below).

### C. Just use `/tce:quickfix` / document a recipe

**How it works**: Tell users to use quickfix, or write a how-to.

**Cons**: Rejected. Quickfix forces size=Small, auto-fills from a one-line
understanding, and targets trivial well-understood fixes — the opposite of a
guided shaping discussion. A recipe doesn't give the interactive ergonomics the
user wants.

### D. Make `/tmt:create` write GitHub issues

**Cons**: Rejected. It breaks tmt's identity (it *is* the markdown tracker; a
GitHub project wouldn't install it) and the standalone / no-cross-plugin rules.

## The adapter contract (the seam)

The only thing that crosses the envelope/payload seam is a small **adapter** that
`/tce:ticket` (and research/plan/implement) read from `tickets.md`. The crucial
realization: it is **not a flat list of states** but a mapping from **tce
lifecycle moments to backend actions**, because tce thinks in moments, not states,
and backends won't translate tce's semantics for us (GitHub won't):

- create → initial state (`Open` for tmt; `open` for GitHub)
- start → in-progress action (edit `**Status:**` / `gh issue edit --add-label`)
- complete → done action (`Done` / `gh issue close`)
- reject → won't-fix action (`Rejected` / `gh issue close` + label)
- plus the **title/body layout** (where the heading comes from, where tce's
  content body goes)

`/tce:init` discovers the ticket system and **describes, in `tickets.md`, what
tce's semantics mean in that system**. The discovery *mechanism* is an
implementation detail (internal knowledge for tmt, interactive/`gh` inspection for
GitHub/Jira); the durable artifact is the adapter in `tickets.md`, which tce reads
as its own file (no live cross-plugin reads).

## Full decoupling via delegation was considered and rejected

We weighed making tce **delegate** the actual state change to tmt (e.g. a
`/tmt:update`) so tce never touches tmt's files. It is **not durably achievable**
under the marketplace's core rules:

1. tce can't invoke `/tmt:update` as a slash command — commands can't execute
   slash commands (the same constraint hooks live under). Kills autonomy.
2. tce can't shell out to a tmt script — that needs tmt's `${CLAUDE_PLUGIN_ROOT}`,
   which tce may not reference (no cross-plugin root).
3. Recording tmt's resolved script path in a project file is the only
   technically-possible route, and it's exactly the fragile pattern
   `${CLAUDE_PLUGIN_ROOT}` exists to avoid — plugin install paths rot across
   updates.

**The reframe that makes direct-write clean rather than leaky**: under the adapter
design the tce *plugin* knows nothing about tmt — its commands say "do what
`tickets.md` says," and the tmt-specific facts live in the *project's*
`tickets.md`, discovered at init. This is identical to how tce "knows" the test
command (it doesn't — `profile.md` does). Ownership is preserved because tmt's
**validation hook remains the enforcement authority**: tce writes the status line
through the documented contract, and tmt's PostToolUse hook validates and rejects
anything illegal (and the same edit naturally fires tmt's git-add reminder).
Write-through + verify, with no fragile delegation machinery.

## Drift detection gap (must be built)

The project's existing mechanisms do **not** currently cover the adapter:

- `check-init.sh` (SessionStart) is a silent no-op once `.claude/tce/profile.md`
  exists (`check-init.sh:51`) — it only catches *uninitialized* projects, never
  post-init change.
- The drift check that recommends `/tce:refresh` lives in `/tce:research`
  (`research.md:218`) and diffs **profile.md only** — it never inspects
  `tickets.md`.

So there is currently **no drift detection for the ticket-system adapter**. The
epic must add it, in two layers:

1. **Active detection** — extend the research-phase drift check (and its composite
   mirrors) to also reconcile the `tickets.md` adapter, recommending
   `/tce:refresh` when stale.
2. **Backstop** — tmt's validation hook already catches the most damaging
   staleness (writing a status tmt no longer accepts) at write time; version
   markers drive reconciliation on plugin upgrade.

## Conclusion

Adopt approach **B**: split the envelope (tmt) from the payload (tce).

- **tmt** shrinks to envelope-only and stops prescribing ticket content; even its
  standalone `/tmt:create` stays content-agnostic (gentle inspiration + "you own
  the content").
- **tce** gains `/tce:ticket` as the sole home of ticket richness, persisting via
  a backend adapter recorded in `tickets.md` by `/tce:init`/`/tce:refresh`.
- The adapter is a **lifecycle→action mapping** (plus title/body layout), not a
  state list.
- tce performs transitions **directly** per the adapter; tmt's validation hook is
  the ownership/enforcement boundary — **no runtime delegation**.
- **Drift detection** is extended to cover the `tickets.md` adapter.

### Decisions made

1. **Standalone tmt fallback richness** → (b) gentle inspiration + tell the user
   they own the ticket content. No prescribed body sections (that would
   reintroduce the drift we're deleting).
2. **Where the adapter lives at tce runtime** → tce reads only its own
   `tickets.md`/`profile.md`, populated by init/refresh. The discovery mechanism
   is an implementation detail the user is indifferent to.
3. **`/tmt:create` when tce is present** → just a reminder that tce cares for
   richness; the user stays free to create tickets however they like (a nudge,
   not a redirect).

### Trade-offs Accepted

- **tmt's standalone authoring experience is intentionally downgraded** (rich
  guided discussion → envelope + free-form + nudge) in exchange for deleting the
  content-authoring duplication entirely. Acceptable because tmt is primarily used
  alongside tce here.
- **tce writes backend ticket files directly** rather than delegating, because
  durable delegation is impossible under the no-cross-plugin-calls rule; tmt's
  validation hook keeps tmt the source of truth and gatekeeper.
- **New maintenance surface**: the `tickets.md` adapter and its drift detection
  must be kept current via init/refresh + version markers.

### Suggested epic breakdown

- (a) `tickets.md` **adapter** (lifecycle→action mapping + title/body layout) +
  `/tce:init`/`/tce:refresh` discovery, with migration/version-marker handling for
  already-initialized projects.
- (b) New **`/tce:ticket`** command (guided authoring → persist via adapter →
  hand off to `/tce:research`).
- (c) **Gut `/tmt:create`** to envelope-only + gentle content-agnostic nudge.
- (d) **Re-point `/tce:quickfix`** autonomous creation to mirror `/tce:ticket`.
- (e) **Extend drift detection** in `/tce:research` (+ composite mirrors) to the
  `tickets.md` adapter.
- Out of scope / optional: a `/tmt:update` standalone status-change convenience —
  tce never needs it.

## References

- `plugins/tmt/commands/create.md` — current guided 7-phase ticket authoring (to
  be moved to tce / gutted from tmt)
- `plugins/tce/templates/tce/tickets.md` — the adapter's home; "Creating a
  ticket", "Status / completion", "What tce needs from a ticket"
- `plugins/tce/commands/quickfix.md` — existing autonomous create via `tickets.md`
  (the pattern `/tce:ticket` generalizes; its inlined tmt template is the
  duplication to remove)
- `plugins/tce/scripts/check-init.sh:51` — SessionStart no-op once initialized
  (not a drift detector)
- `plugins/tce/commands/research.md:218` — profile-only drift check that
  recommends `/tce:refresh` (to be extended to the adapter)
- `CLAUDE.md` — core design rule (project-agnostic plugins, no cross-plugin
  `${CLAUDE_PLUGIN_ROOT}`, coordinate only through project config), "tmt owns the
  ticket envelope", composite-command sync rule, migrations & version markers
