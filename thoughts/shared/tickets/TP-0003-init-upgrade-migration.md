# TP-0003: Init commands detect and migrate prior installs (template & older plugin versions)

**Status:** In Progress
**Estimated Complexity:** Large
**Created:** 2026-06-12
**Updated:** 2026-06-12

## Problem Statement

`/tce:init` and `/tmt:init` assume a blank project. But a repository may already
carry an older workflow state:

a) **A previous plugin version** — e.g. the legacy `.claude/tce/config` holding
   `TICKET_PREFIX` from tce ≤1.x, or (in the future) any config written by an
   older plugin version that a newer version changes.
b) **A template install** from the original
   [claude-template](https://github.com/tobyS/claude-template): un-namespaced
   commands in `.claude/commands/*.md`, agents in `.claude/agents/*.md`,
   root-level `scripts/*.sh` (with `TICKET_PREFIX` hardcoded per script),
   workflow sections in `CLAUDE.md`, `.claude/references/design-system.md`,
   `.claude/settings.json`, and a populated `thoughts/` tree.

Today the init commands ignore this state, leaving duplicate commands shadowing
the plugin versions and no path to carry over the established ticket prefix and
existing tickets/research/plans. The template→plugin migration matters most
right now (the author and other template users need it); plugin-to-plugin
upgrades don't exist in the wild yet but will occur increasingly often as the
plugins evolve.

## Desired Outcome

Running `/tce:init` or `/tmt:init` in a repository with prior state detects
which situation applies (template install, legacy plugin config, or outdated
plugin version), explains what it found, proposes the appropriate migration,
asks the right questions, and — on confirmation — performs the upgrade. All
existing content under `thoughts/` and the established ticket prefix are
preserved. In a clean repository, both commands behave exactly as today.

## User Stories / Use Cases

- As a template user, I want the init commands to recognize my template install
  and migrate it, so that I get the maintained plugin workflow without losing
  tickets, research, plans, or my ticket prefix.
- As a user of an older plugin version, I want init to detect my outdated
  config and upgrade it, so that plugin version bumps don't leave my project in
  a stale or inconsistent state.
- As a new user in a clean repository, I want init to behave exactly as it does
  today, so that the migration logic never gets in my way.

## Acceptance Criteria

- [ ] `/tmt:init` in a template repo detects the template install, reads the
      hardcoded `TICKET_PREFIX` from the template's `scripts/*.sh`, and
      proposes it as the default prefix; the resulting `.claude/tmt/config`
      carries the established prefix so ticket numbering continues seamlessly.
- [ ] `/tce:init` in a template repo detects the template's un-namespaced
      commands and agents and recognizes the project as a migration case (not a
      fresh setup).
- [ ] Redundant template artifacts (`.claude/commands/*.md`,
      `.claude/agents/*.md`, `scripts/*.sh` — only files matching the
      template's known footprint) are listed exactly, and deleted only after a
      single explicit confirmation.
- [ ] Template-originated workflow sections in `CLAUDE.md` are identified;
      edits are proposed and applied only on approval; user-written content is
      never touched.
- [ ] A legacy `.claude/tce/config` (tce ≤1.x) is detected and its
      `TICKET_PREFIX` migrated into `.claude/tmt/config`.
- [ ] Each init stamps its plugin version into the project config (version
      marker). Rerunning init with a newer plugin against an older marker
      offers the upgrade; with a matching version it reports "already up to
      date" and changes nothing.
- [ ] The SessionStart nudge (`check-init.sh`) recognizes a template install
      and tailors its message to suggest running init to migrate.
- [ ] Nothing under `thoughts/shared/` (tickets, research, plans, reviews,
      discussions, mockups) is modified or deleted by any migration step.
- [ ] In a repository with no prior state, both init commands behave exactly as
      before (no migration prompts, no new questions).

## Out of Scope

- Downgrades (migrating from a newer to an older plugin version).
- Auto-porting user customizations of template commands/agents into the plugin
  configuration — customized files may be flagged for manual review, but their
  content is not migrated.
- Unconfirmed/automatic migration (e.g. performed by hooks without the user
  running init) — hooks may only detect and advise.
- Supporting migration from third-party or unrelated workflow templates.

## Open Questions

None — all business decisions were resolved during ticket creation (see Notes).

## Questions for Research/Planning

- [ ] Where exactly does the version marker live per plugin, and in what format
      (e.g. a key in `.claude/tmt/config`, frontmatter in
      `.claude/tce/profile.md`, a dedicated file)?
- [ ] How are migration duties divided between `/tce:init` and `/tmt:init`, and
      what is the hand-off order when both need to run (the tce init's
      ticket-system dialog already points to `/tmt:init`)?
- [ ] How to fingerprint template files reliably — known filename set vs.
      content hashes — so user-modified copies can be flagged before deletion?
- [ ] Does the template's `.claude/settings.json` need migration handling
      (permissions/hooks that clash with or duplicate the plugins')?
- [ ] How should `.claude/references/design-system.md` from the template map to
      tce's `design-system.md` template/location?
- [ ] How does `check-init.sh` detect the template footprint cheaply enough for
      a SessionStart hook?
- [ ] What does the legacy-config detection need beyond the existing
      `tmt_ticket_prefix` fallback in `scripts/lib.sh`?

## References

- https://github.com/tobyS/claude-template — the original template; its file
  footprint (commands, agents, scripts with hardcoded `TICKET_PREFIX`,
  `CLAUDE.md`, `thoughts/` tree) defines the template-detection surface.
- `plugins/tce/scripts/check-init.sh` — the SessionStart nudge to extend.
- `plugins/*/scripts/lib.sh` — existing legacy fallback to `.claude/tce/config`.

## Implementation Plan

[Leave empty - will be filled when plan is created]

## Notes & Updates

### 2026-06-12

Decisions made during ticket creation:

- **Cleanup strategy:** delete redundant template artifacts after listing them
  and getting one explicit confirmation (git history preserves everything);
  no warn-only mode, no backup folder.
- **CLAUDE.md:** propose edits to template-originated sections and apply each
  only on approval; never touch user-written content.
- **Version handling:** write a version marker into project config rather than
  relying solely on ad-hoc heuristics for known legacy states — accepted as a
  contract to maintain going forward.
- **Nudge scope:** `check-init.sh` should also detect a template install and
  tailor its message, in addition to the detection inside the init commands.
- **Complexity rationale:** Large — touches both init commands, the
  SessionStart hook, and introduces the version-marker contract; not XL because
  the detection surface is well-defined (one known template, one known legacy
  config).
