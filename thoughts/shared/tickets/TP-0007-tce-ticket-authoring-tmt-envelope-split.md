# TP-0007: Split ticket authoring (tce payload) from the ticket envelope (tmt)

**Status:** In Progress
**Estimated Complexity:** Large
**Created:** 2026-06-15
**Updated:** 2026-06-15

## Problem Statement

Guided, well-structured ticket authoring currently lives only inside tmt's
`/tmt:create`. Because that command also owns the tmt **envelope** (prefix/ID,
numbering, file location, the `**Status:**` enum), it cannot be offered to
projects on a different tce ticket backend (e.g. GitHub Issues). Those projects
therefore have only the **autonomous** creation path in `/tce:quickfix` and no
**interactive** way to shape a proper ticket — the experience the predecessor
claude-template offered as `/create_ticket`.

The fix is to draw a clean seam between the two concerns that `/tmt:create` welds
together:

- **Payload (authoring)** — the guided WHAT & WHY discussion. Backend-independent;
  belongs to tce.
- **Envelope (persistence)** — numbering, filename, status enum, file location.
  tmt-specific; stays in tmt.

See the full design discussion in
`thoughts/shared/discussions/2026-06-15-tce-ticket-authoring-vs-tmt-envelope.md`.

## Desired Outcome

A new `/tce:ticket` command is the single home of "what a good tce ticket
contains," persisting through a backend **adapter** recorded in the project's
`.claude/tce/tickets.md`. tmt shrinks to envelope-only (its `/tmt:create` becomes
content-agnostic), and quickfix, drift-detection, the docs, and a new
`/tmt:update` are realigned to the split. The same guided authoring experience is
then available on **any** tce-attached backend, without coupling the two plugins
or duplicating the authoring logic.

## User Stories / Use Cases

- As a developer on a **GitHub-backed** tce project, I want an interactive
  `/tce:ticket` command so that I can author a well-structured ticket and have it
  created as a GitHub issue (or get copy/paste-ready content when direct creation
  isn't permitted).
- As a developer on a **tmt** project, I want `/tce:ticket` to produce the same
  rich ticket it always did, while `/tmt:create` still lets me mint a ticket
  envelope and write content however I like.
- As a **standalone tmt** user (no tce), I want `/tmt:create` to give me a valid
  ticket envelope plus gentle guidance, and a `/tmt:update` command to change a
  ticket's status without hand-editing the file.
- As a maintainer, I want the ticket-system facts to live in one discovered,
  refreshable place (`tickets.md`) so the plugins stay project-agnostic and the
  authoring logic isn't duplicated across commands.

## Acceptance Criteria

### `/tce:ticket` (new tce command — the payload home)

- [ ] Runs the guided authoring discussion (the richness moved out of
      `/tmt:create`) and produces a ticket meeting the "What tce needs from a
      ticket" bar.
- [ ] Persists via the `tickets.md` adapter (creating the envelope the way
      `/tce:quickfix` does today) and hands off by suggesting `/tce:research`.
- [ ] **Backend allows creation:** runs the discussion, asks **final permission**
      before any backend write, then creates the ticket.
- [ ] **Backend forbids creation:** **warns upfront** that nothing will be written
      to the backend, still runs the **full** discussion, and offers a
      **one-time override** to permit backend creation for this run only (the
      durable `tickets.md` rule is never modified).
- [ ] On the forbidden path **without** override: presents a **copy/paste-able
      ticket body** plus instructions to paste it into the user's ticket system.
- [ ] On the forbidden path **with** override: asks **final permission**, then
      creates.
- [ ] In **every** case, asks for explicit final permission before any backend
      write.

### `tickets.md` adapter + discovery

- [ ] `tickets.md` template gains the **adapter**: a lifecycle→action mapping
      (create → initial state; start → in-progress; complete → done; reject →
      won't-fix, each as a concrete backend state or command) plus the
      **title/body layout** (where the heading comes from, where the content body
      goes).
- [ ] `/tce:init` discovers the attached ticket system and writes the adapter into
      `tickets.md`; `/tce:refresh` re-derives it in lock-step (per the existing
      init↔refresh sync rule).
- [ ] Already-initialized projects are migrated: the adapter sections are added via
      the init Idempotency upgrade list, and the `tce-config-version` marker is
      bumped accordingly.

### Drift detection

- [ ] The `/tce:research` drift check (and its composite mirrors in `work.md` /
      `quickfix.md`) is extended to reconcile the `tickets.md` adapter, not just
      `profile.md`, recommending `/tce:refresh` when stale (read-only; never edits
      the config).

### tmt becomes envelope-only

- [ ] `/tmt:create` is gutted to envelope-only: it mints the envelope, lets the
      user write whatever content they like, gently inspires them, and states the
      user owns the content. No prescribed body sections.
- [ ] When tce is present, `/tmt:create` adds a one-line reminder that
      `/tce:ticket` handles richness — a nudge, not a redirect or block; the user
      stays free to create tickets however they like.
- [ ] New `/tmt:update` standalone command changes a ticket's status using the
      lifecycle vocabulary (start/done/reject), honoring tmt's status enum and its
      validation hook. **Not** invoked by tce (the no-delegation conclusion
      stands).

### quickfix realignment

- [ ] `/tce:quickfix` re-points its autonomous ticket creation to mirror
      `/tce:ticket` (intra-tce, under the existing composite-command sync rule)
      instead of inlining tmt's template. Its "stop if creation not allowed"
      precondition is unchanged (no interactive override in the autonomous flow).

### Docs, rules, and release

- [ ] Both plugin READMEs and `CLAUDE.md` are updated where they frame
      `/tmt:create` as the tce-chain authoring step, and the relevant CLAUDE.md
      sync-rule sections are updated (incl. adding `/tce:ticket` to the duplicated
      AskUserQuestion-block list, and the composite-command rule now covering
      quickfix mirroring `/tce:ticket`).
- [ ] `claude plugin validate` passes for the marketplace and both plugins.
- [ ] Both plugins are version-bumped and tagged as appropriate (plugin.json +
      marketplace.json), per the releasing convention.

## Out of Scope

- Wiring concrete **Jira / Linear** adapters. The adapter mechanism stays generic
  and must be expressible for them, but only tmt and GitHub are verified in this
  ticket.
- Changing tce's transition model to **delegate** to tmt at runtime — rejected in
  the discussion (undurable under the no-cross-plugin rule); tce keeps writing
  transitions directly with tmt's validation hook as the enforcement boundary.

## Open Questions

None — the design discussion resolved the product decisions (envelope/payload
split, content-agnostic `/tmt:create`, adapter lives in tce's own `tickets.md`,
`/tmt:update` in scope, no runtime delegation).

## Questions for Research/Planning

- [ ] Exact structure/wording of the adapter sections in the `tickets.md` template
      — how to express the lifecycle→action mapping and title/body layout concisely
      for tmt, GitHub, and a generic backend.
- [ ] How `/tce:init` detects the backend (tmt present vs. GitHub/`gh` vs. other)
      and what it writes for each; how `/tce:refresh` re-derives it.
- [ ] Where the guided-authoring content is defined so `/tce:quickfix` can mirror
      it under the composite-command rule (the intra-tce duplication boundary).
- [ ] Whether tmt's status enum stays hardcoded in its validation hook (discussion
      leaned: yes, for now) or becomes declared data — and the migration/coupling
      implications either way.
- [ ] `/tmt:update` design: which transitions it exposes, how it maps the lifecycle
      vocabulary to tmt states, and its interaction with the validation + git-add
      hooks.
- [ ] Versioning: appropriate semver bumps for tce (new command + adapter) and tmt
      (gutted `/tmt:create` + new `/tmt:update`), and migration coverage for
      existing initialized projects.
- [ ] Migration specifics: exactly what gets added to an existing `tickets.md`, the
      init Idempotency upgrade-list wording, and the version-marker bumps.

## References

- `thoughts/shared/discussions/2026-06-15-tce-ticket-authoring-vs-tmt-envelope.md`
  — full design discussion (the source of this ticket)
- `plugins/tmt/commands/create.md` — current guided authoring (to be gutted to
  envelope-only)
- `plugins/tce/templates/tce/tickets.md` — the adapter's home
- `plugins/tce/commands/quickfix.md` — existing autonomous create via `tickets.md`
- `plugins/tce/scripts/check-init.sh` — SessionStart no-op once initialized (not a
  drift detector)
- `plugins/tce/commands/research.md` — profile-only drift check (to be extended)
- `CLAUDE.md` — core design rule, "tmt owns the ticket envelope", composite-command
  sync rule, migrations & version markers, duplicated AskUserQuestion block

## Implementation Plan

[Leave empty - will be filled when plan is created]

## Notes & Updates

### 2026-06-15
- Created from the 2026-06-15 design discussion. Scope deliberately kept to a
  single coherent ticket: the five originally-sketched epic items (adapter +
  discovery, `/tce:ticket`, gutting `/tmt:create`, re-pointing quickfix, drift
  detection) are mutually dependent and phase naturally during planning.
- `/tmt:update` was pulled **into** scope (initially noted optional): it is a
  clean tmt-standalone convenience and sharpens the lifecycle vocabulary the
  adapter depends on. It is not called by tce.
- The `/tce:ticket` "creation not allowed" path was specified as discuss-anyway +
  upfront warning + one-time override + copy/paste fallback + always-ask final
  permission, rather than a flat refusal.
- Sized Large: touches both plugins, the `tickets.md` template, init/refresh,
  drift detection, several CLAUDE.md sync-rule sections, docs, and two releases.
