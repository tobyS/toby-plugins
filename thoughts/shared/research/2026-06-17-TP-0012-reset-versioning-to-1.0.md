---
date: 2026-06-17
ticket: TP-0012
branch: main
commit: 657d757
topic: "Reset release versioning to 1.0.0 for both plugins"
status: complete
---

# Research: Reset release versioning to 1.0.0 (TP-0012)

## Research question

What is the complete, verified set of changes needed to reset both `tce` (3.2.1)
and `tmt` (1.1.0) to `1.0.0` for the public launch — every version touch-point, the
safe way to collapse the version-keyed migration list in `/tce:init`, and the exact
git-tag reset sequence — with no behavior change?

## Summary

The reset is small and fully contained. **Four manifest edits + one dogfood marker**
cover every version touch-point in tracked source; **one command-text edit** collapses
the now-obsolete migration list in `tce/init.md`; and a **git-tag reset** (delete
pre-1.0 tags local + remote, recreate `…--v1.0.0`) completes it. Independent research
confirmed the riskiest assumption — that collapsing the `v3.1.0`/`v3.2.0` upgrade
entries loses nothing — is **true**: every config section those entries describe is
already part of the fresh 1.0.0 baseline (templates + init Phase steps). No other
stale version references exist in command text, scripts, or hooks. No config drift
found.

The enabling fact (from the prior discussion, re-confirmed): Claude Code resolves the
installed version from `marketplace.json`/`plugin.json` at HEAD, **not** from git
tags, and applies no semver-monotonicity check for direct installs — so lowering the
version string is mechanically safe with the author as sole consumer.

## Touch-point inventory (exhaustive)

### Must change (5 files / locations)

| # | File:line | Current | Target | Note |
|---|-----------|---------|--------|------|
| 1 | `plugins/tce/.claude-plugin/plugin.json:3` | `"version": "3.2.1"` | `1.0.0` | tce manifest |
| 2 | `.claude-plugin/marketplace.json:15` | `"version": "3.2.1"` | `1.0.0` | tce marketplace entry |
| 3 | `plugins/tmt/.claude-plugin/plugin.json:3` | `"version": "1.1.0"` | `1.0.0` | tmt manifest |
| 4 | `.claude-plugin/marketplace.json:21` | `"version": "1.1.0"` | `1.0.0` | tmt marketplace entry |
| 5 | `.claude/tce/profile.md:1` | `<!-- tce-config-version: 3.2.0 -->` | `1.0.0` | this repo's dogfood marker |

`claude plugin tag` validates that the manifest and marketplace versions agree, so
#1+#2 (and #3+#4) must be consistent before tagging.

### Command-text edit (the migration-list collapse)

- `plugins/tce/commands/init.md:456-463` — the version-keyed "Changes by version:"
  sub-list inside the Idempotency section's "Older or missing" bullet. Keep the
  generic case (line 457: "a `profile.md` without the marker comment needs the
  comment line added"), **drop** the `v3.1.0` sub-bullet (458-460) and the `v3.2.0`
  sub-bullet (461-463), and **reword line 456's** trailing "Changes by version:"
  lead-in since only the single generic case remains.

### Must NOT change (matched version strings that are correct as-is)

- `plugins/tce/templates/tce/profile.md:1` — `<!-- tce-config-version: FILLED-BY-INIT -->`
  (placeholder; init fills it at runtime from the live plugin version).
- `plugins/tmt/templates/tmt/config:10` — `TMT_CONFIG_VERSION=` (empty placeholder).
- `.claude/tce/profile.md:65` — "…start at 1.0.0 and are versioned independently."
  (states the convention, not a version state).
- `CONTRIBUTING.md:102`, `CLAUDE.md:133-134,201,239` — release/marker mechanics docs;
  informational, describe *how* versioning works, no version state to reset.
- `plugins/tce/commands/{init,refresh}.md` and `plugins/tmt/commands/init.md`
  marker-handling prose (`init.md:324,448`; `refresh.md:138`; `tmt init.md:131,228,235`)
  — describe the comparison mechanism generically; no hardcoded version.

### Notable absences (no hazard)

- `.claude/tmt/config` has **no** `TMT_CONFIG_VERSION` line at all (predates the
  marker), so tmt has zero marker hazard in this repo — nothing to edit there.
- `plugins/tmt/commands/init.md` has **no** version-keyed upgrade list (only the
  generic "add the missing `TMT_CONFIG_VERSION` line" case, which its own text calls
  "the only one today" at line 236). Nothing tmt-side to collapse.

## Verification: collapsing the init.md upgrade list loses nothing

The `v3.1.0`/`v3.2.0` entries describe config that re-running init would otherwise
need to *retrofit* onto an older project. They are safe to remove only if a fresh
`/tce:init` already writes that config as baseline. Confirmed for all three:

| Section described by the entry | In template? | In fresh Phase steps? | Safe to drop? |
|---|---|---|---|
| (a) `tickets.md` "Ticket title & body layout" | Yes — `templates/tce/tickets.md:42-49` | Yes — `init.md:333-336`, per-system fill at `346-354` | Yes |
| (b) `tickets.md` "reject" moment in Status/completion | Yes — `templates/tce/tickets.md:52-62` (esp. :58) | Yes — `init.md:344-360` (tmt :347, GH :355) | Yes |
| (c) `profile.md` `## Commit convention` | Yes — `templates/tce/profile.md:44-59` | Yes — Phase 2 dialog `init.md:257-277`, write `init.md:320-331` | Yes |

Because the baseline output already contains all three, dropping the per-version
migration sub-bullets removes redundant text only — a fresh 1.0.0 init produces an
identical project config either way.

## Git-tag reset

Current tags (all pushed to `origin` = `github.com:tobyS/toby-plugins`):

- tce: `tce--v2.0.0`, `v2.1.0`, `v3.0.0`, `v3.0.1`, `v3.1.0`, `v3.2.0`, `v3.2.1`
- tmt: `tmt--v1.0.0`, `v1.0.1`, `v1.1.0`

Sequence (confirmed):

1. Land the source edits + commit first (so `claude plugin tag` sees matching
   manifest/marketplace versions).
2. Delete every pre-1.0 tag **locally** (`git tag -d <tag>`) **and on the remote**
   (`git push origin --delete <tag>`). The remote deletions are pushes → surfaced for
   the author to authorize per the repo's no-auto-push rule; not executed silently.
3. `claude plugin tag ./plugins/tce` and `claude plugin tag ./plugins/tmt` to create
   `tce--v1.0.0` / `tmt--v1.0.0` on the launch commit.

Gotchas:

- **`tmt--v1.0.0` already exists** (tmt started at 1.0.0). It must be deleted (local +
  remote) before recreation; the new tag points at a different commit SHA. Harmless —
  nothing depends on it (no inter-plugin dependency constraints; install resolves from
  `marketplace.json` at HEAD).
- Pushing the new tags is likewise the author's call.

## Config drift check

`.claude/tce/profile.md` (stack, commands, code map) and `.claude/tce/tickets.md`
(tmt adapter) match the repo as it stands — no stale/vanished commands or moved
directories. **No "tce Config Drift" condition.** (The `3.2.0` marker on profile.md is
the *subject* of this ticket, not adapter drift.)

## Open questions

None. The ticket's "Open Questions" are explicitly none, and all three
"Questions for Research/Planning" are resolved above (collapse is safe; touch-points
are complete; tag sequence confirmed).

## References

- Ticket: `thoughts/shared/tickets/TP-0012-reset-versioning-to-1.0.md`
- Discussion: `thoughts/shared/discussions/2026-06-17-reset-versioning-to-1.0-for-public-launch.md`
- `plugins/tce/commands/init.md:456-463` — collapsible migration list
- `plugins/tce/templates/tce/{tickets,profile}.md` — baseline sections (a)(b)(c)
- `plugins/tmt/commands/init.md:234-237` — generic-only upgrade case
- `CLAUDE.md` "Releasing" + "Migrations & version markers"
- https://code.claude.com/docs/en/plugins-reference#version-management
- https://code.claude.com/docs/en/plugin-dependencies
