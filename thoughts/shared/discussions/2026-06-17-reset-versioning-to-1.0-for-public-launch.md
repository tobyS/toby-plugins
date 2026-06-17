---
date: 2026-06-17
topic: "Reset release versioning to 1.0.0 for both plugins before public launch"
status: complete
---

# Technical Discussion: Reset release versioning to 1.0.0 for public launch

## Challenge

The marketplace has been iterated on with semantic versioning applied throughout,
so `tce` has climbed to `3.2.1` (tags `tce--v2.0.0` … `tce--v3.2.1`) and `tmt` is
at `1.1.0` (tags `tmt--v1.0.0` … `tmt--v1.1.0`). Neither plugin has been announced
anywhere; the author is the sole consumer. With both now in a state worth
announcing, the goal is to debut **both plugins at a proper `1.0.0`** — i.e. reset
the release versioning rather than carry the inflated numbers into the public
launch.

Decisions taken during the discussion:

- **Scope:** reset **both** plugins to `1.0.0` (coherent "both debut at 1.0" story).
- **Tags:** **delete** the pre-1.0 tags so the tag timeline starts cleanly at v1.0.0.

## Key findings that framed the decision

### How Claude Code resolves plugin versions (decisive)

Verified against the official docs (claude-code-guide research):

- Install/update resolves **which version to install from the `version` field in
  `marketplace.json` / `plugin.json` at the HEAD of the default branch — NOT from
  git tags.** (https://code.claude.com/docs/en/plugins-reference#version-management)
- Git tags (`<name>--v<version>` from `claude plugin tag`) are consumed **only for
  inter-plugin dependency constraint resolution**
  (https://code.claude.com/docs/en/plugin-dependencies). `tce` and `tmt`
  deliberately never depend on each other (the ownership boundary in `CLAUDE.md`
  forbids cross-plugin coupling), so the tags drive nothing here.
- There is **no semver-monotonicity check** for direct installs — the version
  string is just a cache key compared for *equality*. Lowering `3.2.1` → `1.0.0`
  is therefore not "going backwards" in any way Claude Code polices; the next
  `/plugin marketplace update` simply sees a changed string and reinstalls.
- No consumer-side version pinning exists; deleting/recreating tags does not affect
  already-installed direct consumers.

**Implication:** the reset is mechanically low-risk and the version numbers are
largely cosmetic. The remaining questions are semantic correctness and edit scope.

### The semantic case favours the reset

SemVer defines `0.y.z` as "initial development" and `1.0.0` as "first stable public
API." Since nothing was announced, the work so far was effectively `0.x` — the
`2.0.0`/`3.0.0` bumps labelled pre-release churn as breaking *public-API* changes
when there was no public API to break. Debuting at `1.0.0` is therefore the
textbook meaning of `1.0.0`, not a dishonest rewrite. The development **commit**
history stays intact; only the version line resets.

### tmt asymmetry (the real fork)

`tmt` is already a clean `1.x` line (`1.0.0 → 1.0.1 → 1.1.0`); it does **not** have
the inflated-number problem. Resetting `tmt 1.1.0 → 1.0.0` is a genuine backward
step that discards real 1.x history, purely to make both plugins read `1.0.0` on
launch day. Decision: accept that cost for the coherent dual-launch story (harmless
because unannounced).

## Approaches Explored

### Approach A — Reset tce only → 1.0.0, leave tmt at 1.1.0

**How it works**: Bump only `tce` (the inflated one) down to `1.0.0`; `tmt` keeps
its already-clean `1.x` line.

**Pros**: Most honest; nothing goes backwards; least work; no tmt tag rewrite.

**Cons**: Launch story is "tce 1.0, tmt 1.1" — less tidy than a coordinated 1.0.

### Approach B — Reset both → 1.0.0 (CHOSEN)

**How it works**: Set both `plugin.json` + `marketplace.json` entries to `1.0.0`,
delete the pre-1.0 tags, recreate `…--v1.0.0` tags on the launch commit.

**Pros**: Coherent "both debut at 1.0" optics; clean slate.

**Cons**: `tmt` steps backwards `1.1.0 → 1.0.0` and discards its real 1.x history;
requires force-moving `tmt--v1.0.0` to a new commit and deleting pushed tags.

### Approach C — No reset; bump forward for launch

**How it works**: Keep history strictly monotonic — e.g. bump `tce` to `4.0.0`,
keep `tmt` at/above `1.1.0`.

**Pros**: Purist honest-history; never rewrites a tag.

**Cons**: Rejects the premise — `tce` keeps an inflated number the author
explicitly wants gone for the public debut.

## Conclusion

**Approach B — reset both plugins to `1.0.0` and delete the pre-1.0 tags.** It is
mechanically safe (tags don't drive installs; no monotonicity check; sole
consumer), semantically *more* correct than continuing a `3.x` line that was never
a public contract, and gives a clean coordinated launch.

### Execution plan (in order)

Source touch-points are small and fully contained:

1. `plugins/tce/.claude-plugin/plugin.json` → `1.0.0`; matching `marketplace.json`
   entry → `1.0.0`.
2. `plugins/tmt/.claude-plugin/plugin.json` → `1.0.0`; matching `marketplace.json`
   entry → `1.0.0`.
3. **Collapse `plugins/tce/commands/init.md` lines 458–463** — delete the `v3.1.0`
   / `v3.2.0` upgrade entries. Those sections (tickets.md "Ticket title & body
   layout", the reject moment, `profile.md` `## Commit convention`) are already in
   the 1.0.0 templates/Phase steps, so a fresh init writes them as baseline; the
   only upgrade case left is the generic "marker missing → add it."
4. **Rewrite this repo's own `.claude/tce/profile.md` line 1** marker
   `<!-- tce-config-version: 3.2.0 -->` → `1.0.0` (dogfood; avoids the undefined
   "downgrade" comparison where project=3.2.0 vs plugin=1.0.0). Note: this repo's
   `.claude/tmt/config` has **no** `TMT_CONFIG_VERSION` line, so tmt has no marker
   hazard here.
5. Commit (conventional, e.g. `chore: reset tce/tmt to 1.0.0 for public launch`).
6. **Tags:** delete all `tce--v2.*`/`v3.*` and `tmt--v1.0.0`/`v1.0.1`/`v1.1.0`
   (local `git tag -d` **and** remote `git push origin --delete <tag>`), then
   `claude plugin tag ./plugins/tce` and `./plugins/tmt` on the launch commit.

`claude plugin tag` validates that `plugin.json` and `marketplace.json` agree on
the version, so steps 1–2 must precede step 6.

### Execution gotchas

- **`tmt--v1.0.0` already exists** (tmt started at 1.0.0). Recreating it requires
  deleting the old tag first; the new tag points at a different commit SHA
  (harmless — no dependents).
- **Tags are pushed** to `github.com:tobyS/toby-plugins`, so deletion is two-sided
  (local + remote). Remote deletion is a push — author authorises per the repo's
  "never auto-push" rule.
- **Author's own dogfood installs** (if tce/tmt are `/plugin install`ed locally)
  will see the version strings drop on the next `/plugin marketplace update` and
  reinstall `1.0.0` cleanly — expected, not a breakage.

### Trade-offs Accepted

- `tmt` steps backwards `1.1.0 → 1.0.0` and discards a genuine 1.x line — accepted
  for the coherent dual-launch story; harmless because unannounced.
- Tag-history rewrite (force-moving `tmt--v1.0.0`, deleting pushed tags) — accepted
  because tags drive nothing here (no inter-plugin dependencies; install resolves
  from `marketplace.json` at HEAD; sole consumer).
- Version line no longer matches commit count — accepted, and actually more
  SemVer-correct (pre-launch churn was really `0.x`).

## References

- Current state: `tce` `3.2.1`, `tmt` `1.1.0`
  (`plugins/*/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`).
- Tags present: `tce--v2.0.0…v3.2.1`, `tmt--v1.0.0…v1.1.0` (pushed to `origin`).
- `plugins/tce/commands/init.md:448-463` — version-marker comparison + `v3.1.0` /
  `v3.2.0` upgrade list to collapse.
- `.claude/tce/profile.md:1` — this repo's `tce-config-version: 3.2.0` marker.
- `.claude/tmt/config` — no `TMT_CONFIG_VERSION` line (no tmt marker hazard here).
- `CLAUDE.md` — "Releasing" + "Migrations & version markers" (version-marker
  mechanics, "plugins start at 1.0.0" convention, cross-plugin coupling ban).
- https://code.claude.com/docs/en/plugins-reference#version-management — install
  version resolution.
- https://code.claude.com/docs/en/plugin-dependencies — git tags used only for
  dependency constraint resolution.
