---
date: 2026-06-17
ticket: TP-0012
branch: main
commit: e9d22e8
topic: "Reset release versioning to 1.0.0 for both plugins"
status: ready
---

# Implementation Plan: Reset release versioning to 1.0.0 (TP-0012)

## Overview

Reset both plugins from `tce 3.2.1` / `tmt 1.1.0` to a clean, coordinated `1.0.0`
for the public launch. This is a version-label reset with no behavior change: four
manifest edits, one dogfood marker, one command-text cleanup (collapsing an obsolete
migration list), then a git-tag reset (delete pre-1.0 tags, recreate `…--v1.0.0`).

## Current state

- `tce` is `3.2.1`, `tmt` is `1.1.0` in their `plugin.json` and `marketplace.json`
  entries (`research:Touch-point inventory`).
- This repo's `.claude/tce/profile.md:1` carries a stale `tce-config-version: 3.2.0`
  marker.
- `plugins/tce/commands/init.md:456-463` carries `v3.1.0`/`v3.2.0` migration
  sub-bullets that describe config now shipped as 1.0.0 baseline (verified redundant
  — `research:Verification`).
- Pre-1.0 git tags exist locally and on `origin` for both plugins.

## Desired end state

- Both plugins read `1.0.0` everywhere a version lives; manifests validate.
- `init.md`'s Idempotency section keeps only the generic "marker missing → add it"
  upgrade case; no references to discarded versions remain.
- `.claude/tce/profile.md:1` reads `<!-- tce-config-version: 1.0.0 -->`.
- Pre-1.0 tags are gone (local + remote); fresh `tce--v1.0.0` / `tmt--v1.0.0` exist
  on the launch commit.
- A repo grep for old version strings comes back clean apart from intended docs/history.

## What we're NOT doing

- No announcement/marketing; no README user-facing content (TP-0011); no feature or
  behavior change; no CHANGELOG introduction.
- Not changing template placeholders (`FILLED-BY-INIT`, empty `TMT_CONFIG_VERSION=`),
  the "plugins start at 1.0.0" convention text, or the informational version-mechanics
  prose in `CONTRIBUTING.md` / `CLAUDE.md` (`research:Must NOT change`).

---

## Phase 1 — Reset version numbers and collapse the migration list

Source edits only; one commit. Group these so the manifest/marketplace versions stay
consistent for tagging later.

### Changes

1. `plugins/tce/.claude-plugin/plugin.json:3` — `"version": "3.2.1"` → `"1.0.0"`.
2. `.claude-plugin/marketplace.json` (tce entry, ~line 15) — `"3.2.1"` → `"1.0.0"`.
3. `plugins/tmt/.claude-plugin/plugin.json:3` — `"version": "1.1.0"` → `"1.0.0"`.
4. `.claude-plugin/marketplace.json` (tmt entry, ~line 21) — `"1.1.0"` → `"1.0.0"`.
5. `.claude/tce/profile.md:1` — `<!-- tce-config-version: 3.2.0 -->` →
   `<!-- tce-config-version: 1.0.0 -->`.
6. `plugins/tce/commands/init.md:456-463` — collapse the migration sub-list:
   - Keep the generic case (current line 457): "a `profile.md` without the marker
     comment needs the comment line added".
   - Remove the `v3.1.0` sub-bullet (458-460) and the `v3.2.0` sub-bullet (461-463).
   - Reword the lead-in on line 456 so it no longer says "Changes by version:" (only
     one generic case remains) — e.g. fold the generic case directly into the
     "Older or missing" bullet prose. Preserve the surrounding structure/altitude
     (`CLAUDE.md`: surgical edits over rewrites).

### Success criteria

#### Automated

- [x] `claude plugin validate .` passes.
- [x] `claude plugin validate ./plugins/tce` passes.
- [x] `claude plugin validate ./plugins/tmt` passes.
- [x] `grep -rIn -e "3\.2\.1" -e "3\.2\.0" -e "3\.1\.0" -e "3\.0\." -e "2\.[01]\.0" -e "1\.1\.0" -e "1\.0\.1" plugins/ .claude-plugin/ .claude/tce/profile.md`
      returns no version-state hits (only the convention text `.claude/tce/profile.md:65`
      "start at 1.0.0…" and any intended docs remain — none of the *old* strings).

#### Manual

- [x] Both `plugin.json` files and both `marketplace.json` entries read `1.0.0`.
- [x] `init.md` Idempotency section reads cleanly with only the generic upgrade case;
      no dangling "Changes by version:" lead-in, no `v3.x` references.
- [x] `.claude/tce/profile.md` line 1 marker reads `1.0.0`.

### Commit

Code commit (manifest + command text). Run the validate checks first (the project's
"Test" command per `profile.md`), then commit, e.g.
`chore(TP-0012): reset tce and tmt to 1.0.0 and collapse init migration list`.

---

## Phase 2 — Git-tag reset

Tags are not edits to tracked files; they run after the Phase 1 commit exists (so the
new `…--v1.0.0` tags land on the reset commit). Remote operations are pushes — per the
repo's no-auto-push rule, **surface the exact commands for the author to run/authorize
rather than executing them silently**.

### Steps

1. Delete pre-1.0 tags locally:
   - `git tag -d tce--v2.0.0 tce--v2.1.0 tce--v3.0.0 tce--v3.0.1 tce--v3.1.0 tce--v3.2.0 tce--v3.2.1`
   - `git tag -d tmt--v1.0.0 tmt--v1.0.1 tmt--v1.1.0`
2. Delete the same tags on the remote (author authorizes):
   - `git push origin --delete tce--v2.0.0 tce--v2.1.0 tce--v3.0.0 tce--v3.0.1 tce--v3.1.0 tce--v3.2.0 tce--v3.2.1`
   - `git push origin --delete tmt--v1.0.0 tmt--v1.0.1 tmt--v1.1.0`
3. Create the new tags on the launch commit:
   - `claude plugin tag ./plugins/tce`  (creates `tce--v1.0.0`)
   - `claude plugin tag ./plugins/tmt`  (creates `tmt--v1.0.0`)
4. Push the new tags (author authorizes): `git push origin tce--v1.0.0 tmt--v1.0.0`.

Note: `tmt--v1.0.0` already exists — step 1/2 must delete it before step 3 recreates
it on the new commit (`research:Git-tag reset`).

### Success criteria

#### Automated

- [x] `git tag --list "tce--*" "tmt--*"` lists only `tce--v1.0.0` and `tmt--v1.0.0`
      locally.

#### Manual

- [x] `git ls-remote --tags origin` shows only `…--v1.0.0` tags for both plugins
      (after the author runs the push/delete commands).
- [x] `tce--v1.0.0` and `tmt--v1.0.0` point at the Phase 1 reset commit (`a239f93`).

---

## Testing strategy

The only automated verification this repo has is manifest validation
(`claude plugin validate …`) — there is no test/typecheck/lint suite (`profile.md`
Commands). Run all three validate invocations after Phase 1. The version-string grep
is the regression check that no touch-point was missed. Tag state is verified with
`git tag --list` / `git ls-remote`.

## Notes

- Local tag deletion and `claude plugin tag` are safe to run in-session; the remote
  pushes (`git push origin --delete …` and pushing the new tags) are the author's to
  authorize.
- After the reset, the author's own dogfood installs (if any) will see the version
  string change on the next `/plugin marketplace update` and reinstall `1.0.0` — expected.
