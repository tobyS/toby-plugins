# TP-0012: Reset release versioning to 1.0.0 for both plugins before public launch

**Status:** Open
**Estimated Complexity:** Small
**Created:** 2026-06-17
**Updated:** 2026-06-17

## Problem Statement

Both plugins have been iterated on with semantic versioning applied throughout,
so `tce` has climbed to `3.2.1` and `tmt` to `1.1.0`. Neither plugin has been
announced anywhere and the author is the sole consumer — by SemVer's own
definition the work so far was effectively `0.x` "initial development", and the
`2.x`/`3.x` bumps labelled pre-release churn as breaking public-API changes when
there was no public API. With both plugins now in a state worth announcing, the
first public release should debut at a clean, coordinated `1.0.0` rather than
carry the inflated numbers into the launch.

## Desired Outcome

Both plugins report `1.0.0` everywhere a version lives, the git tag timeline
starts cleanly at `…--v1.0.0`, this repo's own dogfood config no longer carries a
stale pre-1.0 version marker, and the manifests still validate. Concretely, when
this is complete:

- `tce` and `tmt` are each at `1.0.0` in their `plugin.json` and their
  `marketplace.json` entry.
- The pre-1.0 git tags are gone (locally and on `origin`) and fresh
  `tce--v1.0.0` / `tmt--v1.0.0` tags exist on the launch commit.
- No stale version references remain in command text or this repo's config.

## User Stories / Use Cases

- As the maintainer, I want both plugins to debut at `1.0.0` so that the public
  launch presents a coherent, credible "first stable release" rather than an
  unexplained `tce 3.2.1` / `tmt 1.1.0`.
- As a future consumer browsing the repo, I want the git tag timeline to start at
  `v1.0.0` so that the release history is not confusing (no `v3.2.1` sitting
  before a later `v1.0.0`).

## Acceptance Criteria

- [ ] `plugins/tce/.claude-plugin/plugin.json` version is `1.0.0` and the `tce`
      entry in `.claude-plugin/marketplace.json` is `1.0.0`.
- [ ] `plugins/tmt/.claude-plugin/plugin.json` version is `1.0.0` and the `tmt`
      entry in `.claude-plugin/marketplace.json` is `1.0.0`.
- [ ] The version-keyed upgrade entries in `plugins/tce/commands/init.md`
      (the `v3.1.0` / `v3.2.0` steps, ~lines 458–463) are collapsed so `1.0.0`
      is the baseline and only the generic "marker missing → add it" upgrade
      case remains; no broken references to discarded versions remain.
- [ ] This repo's `.claude/tce/profile.md` line 1 marker reads
      `<!-- tce-config-version: 1.0.0 -->` (was `3.2.0`).
- [ ] `claude plugin validate .`, `claude plugin validate ./plugins/tce`, and
      `claude plugin validate ./plugins/tmt` all pass.
- [ ] All pre-1.0 tags (`tce--v2.0.0`…`tce--v3.2.1`, `tmt--v1.0.0`,
      `tmt--v1.0.1`, `tmt--v1.1.0`) are deleted locally and on `origin`, and
      fresh `tce--v1.0.0` and `tmt--v1.0.0` tags exist on the launch commit.
      (The remote-affecting commands are surfaced for the author to authorize,
      per the repo's no-auto-push rule.)
- [ ] No other stale version references remain (a repo grep for the old version
      strings in `plugins/`, `README.md`, `CLAUDE.md` comes back clean apart from
      intended history).

## Out of Scope

- The announcement / marketing itself (blog post, social, etc.).
- User-facing README content changes — handled by TP-0011.
- Any feature or behavior change. This is a version-label reset only.
- Introducing a CHANGELOG (could be a follow-up; not required for the reset).

## Open Questions

None — the approach was fully decided in the discussion (both plugins reset to
`1.0.0`; pre-1.0 tags deleted).

## Questions for Research/Planning

- [ ] Confirm the exact edit to collapse the `init.md` upgrade list, verifying the
      sections it described (`tickets.md` "Ticket title & body layout" + reject
      moment; `profile.md` `## Commit convention`) are already shipped as `1.0.0`
      baseline in the templates/Phase steps so nothing is lost by removing them.
- [ ] Confirm the complete set of version touch-points (the five mapped in the
      discussion) — re-grep to be sure nothing else references the old versions.
- [ ] Confirm the tag-reset sequence: version edits + commit first (so
      `claude plugin tag` sees matching `plugin.json`/`marketplace.json`), then
      delete old tags (local `git tag -d` + remote `git push origin --delete`),
      then `claude plugin tag ./plugins/tce` and `./plugins/tmt`. Note
      `tmt--v1.0.0` already exists and must be force-moved to the new commit.

## References

- `thoughts/shared/discussions/2026-06-17-reset-versioning-to-1.0-for-public-launch.md`
  — full analysis, approaches, trade-offs, and execution gotchas.
- `CLAUDE.md` — "Releasing" + "Migrations & version markers" (version-marker
  mechanics; "plugins start at 1.0.0" convention; cross-plugin coupling ban).
- `plugins/tce/commands/init.md:448-463` — version-marker comparison + upgrade list.
- `.claude/tce/profile.md:1` — this repo's `tce-config-version` marker.
- https://code.claude.com/docs/en/plugins-reference#version-management — install
  version resolution (from `marketplace.json`/`plugin.json` at HEAD, not tags).
- https://code.claude.com/docs/en/plugin-dependencies — git tags consumed only for
  inter-plugin dependency constraints (these plugins declare none).

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-06-17

- Created from the technical discussion of the same date. Decisions carried in:
  reset **both** plugins to `1.0.0` (coherent dual launch), and **delete** the
  pre-1.0 tags so the tag timeline starts at `v1.0.0`.
- Key enabling fact: Claude Code resolves the installed version from
  `marketplace.json`/`plugin.json` at HEAD, **not** from git tags, and applies no
  semver-monotonicity check for direct installs — so lowering the version string
  is mechanically safe with the author as sole consumer.
- Complexity **Small**: six contained source touch-points plus a tag operation;
  no behavior change.
- Tag lifecycle (local + remote) is **in scope** per the author's decision;
  remote pushes are surfaced for manual authorization.
- `tmt` stepping back `1.1.0 → 1.0.0` (discarding a real 1.x line) is an accepted
  trade-off for the coordinated launch, harmless because unannounced.
