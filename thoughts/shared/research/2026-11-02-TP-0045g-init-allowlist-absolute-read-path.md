---
date: 2026-11-02T11:51:26Z
git_commit: 88777eb3e0850a99f7a7d86fbde318e308e0796e
branch: main
repository: toby-plugins
topic: "TP-0045g: /tce:init writes an absolute Read grant that never matches"
tags: [research, tce, init, allowlist, permissions, settings-json, readme]
status: complete
last_updated: 2026-11-02
---

# Research: TP-0045g — /tce:init writes an absolute Read grant that never matches

**Date**: 2026-11-02T11:51:26Z
**Git Commit**: 88777eb3e0850a99f7a7d86fbde318e308e0796e
**Branch**: main
**Repository**: toby-plugins

## Research Question

How does `/tce:init`'s allowlist step build the `Read` grant for tce's own
files, why does the directory-sourced form not match, what does a re-run do
with an existing entry, and which other shipped text writes a permission path?
Inputs: ticket `thoughts/shared/tickets/TP-0045g-init-allowlist-absolute-read-path.md`,
intent `thoughts/shared/intents/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md`
(takes precedence), parent epic `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md`.

## Summary

- `plugins/tce/commands/init.md:579-625` (Phase 4 step 6, "Allowlist") builds
  the entries. For tce's own files it branches on where `${CLAUDE_PLUGIN_ROOT}`
  resolved: under `~/.claude/plugins/` → `Read(~/.claude/plugins/**)`;
  anywhere else → `Read(<that path>/**)` "with the absolute path written out"
  (`init.md:586-589`). An absolute path starts with `/`, so the written entry
  is `Read(/Users/.../plugins/tce/**)` — a single leading slash.
- Claude Code's permission docs define a single leading `/` as **relative to
  the settings source** (for `.claude/settings.json`: the primary working
  directory) and `//path` as absolute, with an explicit warning that
  `/Users/alice/file` is not an absolute path. TP-0045e's phase 5 observed the
  same on Claude Code 2.1.310: the single-slash form was denied in a trusted
  folder, only `Read(//abs/**)` matched.
- Re-run: the tce 1.4.0 Idempotency bullet (`init.md:687-690`) runs step 6 on
  **every** re-run, same version included, and step 6 skips only entries
  `permissions.allow` "already holds" (`init.md:597-598`). An existing
  `Read(/abs/**)` is a different string from `Read(//abs/**)`, so once step 6
  computes the `//` form it is reported as missing and offered through the
  existing dialog. No separate upgrade-list entry exists or is structurally
  required for that.
- Step 6's write rule appends only and leaves "every other key and entry
  byte-identical" (`init.md:621-624`); `init.md:710-714` and CLAUDE.md
  (`CLAUDE.md:449-454`) describe the allowlist append as the one sanctioned
  `/tce:init` edit to `settings.json`, "never widened". Removing an entry is
  not part of either description today.
- Other shipped permission paths: no other single-slash absolute path was
  found. tsf writes only `Read(~/.claude/plugins/**)`; `/tsf:cycle`'s
  frontmatter uses `Read(/${CLAUDE_PLUGIN_ROOT}/**)`, which expands to
  `//<abs>/**` because the substituted value starts with `/`.
  `check-init.sh` writes no permission paths.
- README: `plugins/tce/README.md:335-340` ("Accept the allowlist") and
  `:342-355` ("Headless runs") describe the allowlist without naming the
  `Read` form; neither names `--plugin-dir` or the path syntax.

## Detailed Findings

### The allowlist step in `/tce:init`

- `plugins/tce/commands/init.md:579-581` — the step's rationale: `/tce:work`'s
  agents run in their own contexts, where command-level grants do not reach.
- `init.md:582-589` — the "tce's own files" bullet, verbatim:
  "Look at the path `${CLAUDE_PLUGIN_ROOT}` resolved to in this session: under
  `~/.claude/plugins/` (a marketplace install, whose cache directory changes
  with every version) → `Read(~/.claude/plugins/**)`; anywhere else (a
  directory-sourced marketplace or `--plugin-dir`, which load the plugin from
  its source directory) → `Read(<that path>/**)`, with the absolute path
  written out."
- `init.md:590-594` — the remaining entries: `Edit(thoughts/shared/**)`
  (project-relative, no leading slash), eight `Bash(git …:*)` entries, the
  profile's test/typecheck/lint commands.
- `init.md:596-600` — never `git push`/`gh`; "Skip entries
  `permissions.allow` already holds; if none are missing, skip this step
  silently." The comparison method is not specified beyond "already holds".
- `init.md:601-618` — the verbatim intro and the AskUserQuestion dialog
  (header "Allowlist", options "Append them (Recommended)" / "Skip").
- `init.md:620-624` — the write: create the file with only
  `{"permissions": {"allow": [...]}}`, or append missing entries, no
  duplicates, "leave every other key and entry byte-identical".
- `init.md:197-199` — the Phase 2 proposal line announcing "[N] entries are
  missing from .claude/settings.json", computed from the same entries.
- `init.md:633` — the hand-off line "N allowlist entries appended".
- `init.md:710-714` (Notes) — "The one edit this command makes to
  `.claude/settings.json` is the allowlist append in Phase 4 step 6 — only on
  explicit approval, surgically, and never widened (never `git push`, never
  `gh`, never any other key)."

### Re-run / Idempotency

- `init.md:643-647` — re-run is "review and amend the existing setup".
- `init.md:649-660` — version comparison: same version → "already up to
  date"; older/missing → walk the upgrade list.
- `init.md:687-690` — the tce 1.4.0 bullet: "On every re-run — on the same
  version too — compute the entries and offer the missing ones with that
  step's dialog; skip silently when none are missing." This bullet is
  version-independent: it runs whether the marker is the same or older.
- `init.md:691-694` — the 1.4.3 bullet uses the same "on every re-run" form
  for the dossiers directory and the `thoughts/` rules edit.
- Consequence as written: a project holding `Read(/abs/**)` reaches step 6 on
  any re-run; whether `Read(//abs/**)` is offered depends only on what step 6
  computes. The stale single-slash entry stays in the file under the current
  write rule (`init.md:621-624`).

### Claude Code permission path syntax (web)

- [Configure permissions — How path patterns match](https://code.claude.com/docs/en/permissions):
  `//path` = absolute from filesystem root (`Read(//Users/alice/secrets/**)`);
  `~/path` = from home; `/path` = "relative to the settings source";
  `path`/`./path` = relative to the current directory. Warning: "A pattern
  like `/Users/alice/file` isn't an absolute path. The single leading slash
  anchors at the settings source, not the filesystem root. Use
  `//Users/alice/file` for absolute paths."
- Same page, "Where a pattern anchors": project `.claude/settings.json` and
  `.claude/settings.local.json` → `<primary working directory>/path`; user
  settings `~/.claude/settings.json` → `~/.claude/path`; `--settings <file>` →
  `<directory of file>/path`; CLI flags/session rules → primary working
  directory.
- Same page: gitignore globbing (`**` crosses directories); allow rules apply
  through a symlink only when both the requested path and its target match;
  Windows paths are normalized to `/c/...` form and matched with `//c/...`;
  "An allow rule with an unusable pattern doesn't approve anything."
- [Plugin loading reference — In-place and copied plugins](https://code.claude.com/docs/en/plugins/loading):
  `--plugin-dir` loads in place; relative-path plugins in a marketplace added
  from a local path load in place from the source directory; every other
  marketplace plugin is copied to `cache/<marketplace>/<plugin>/<version>/`,
  where `${CLAUDE_PLUGIN_ROOT}` points. (The docs state "points at the source
  directory" explicitly only for local-marketplace plugins' hooks/MCP/LSP.)
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference):
  `${CLAUDE_PLUGIN_ROOT}` is the "Absolute path of the plugin's installed
  version", substituted anywhere in skill/command/agent markdown.
- [Skills](https://code.claude.com/docs/en/skills): `allowed-tools`
  substitution of `${CLAUDE_PLUGIN_ROOT}` is documented for Bash rules only;
  `Read(...)` rules in frontmatter and their anchor are undocumented.
- GitHub: [anthropics/claude-code#76431](https://github.com/anthropics/claude-code/issues/76431)
  (maintainer: `Read(~/…)`, `Edit(//home/<user>/…)` work; `Write(...)` never
  matches); [#44106](https://github.com/anthropics/claude-code/issues/44106)
  and [#52835](https://github.com/anthropics/claude-code/issues/52835) (users
  confused by Claude Code writing `//` on prompt approval; both closed
  inactive, conflicting anecdotes); [#19109](https://github.com/anthropics/claude-code/issues/19109)
  (`Read(/etc/**)` in user settings prompting — consistent with the anchor
  table); [#39387](https://github.com/anthropics/claude-code/issues/39387)
  (`//` rule prompting in an Explore subagent, duplicate of #37730);
  third-party test [jeffery777/claude-dev-skills#66](https://github.com/jeffery777/claude-dev-skills/issues/66)
  (2.1.310, `claude -p`: `Read(/${CLAUDE_PLUGIN_ROOT}/**)` in `allowed-tools`
  allowed, `Read(${CLAUDE_PLUGIN_ROOT}/**)` denied). Unverified (secondary
  sources only): a 2.1.89 changelog line about `Read(//path/**)` checking
  symlink targets.

### Local corroboration of the `//` form

- `.claude/settings.local.json` (this repo, untracked personal settings) holds
  `Read(//Users/toby/code/work/chat-sustainability/**)` and
  `Read(//Users/toby/code/work/chat-sustainability/.claude/**)` — entries in
  the double-slash form as Claude Code records approved absolute reads.
- This repo's `.claude/settings.json` holds no `Read(` entry (it has the
  `Edit`/`git` allowlist and `claude plugin validate`); tce is enabled as
  `tce@toby-plugins` there.

### Other shipped text writing permission paths

A repo-wide grep for `Read(`, `Edit(`, `Write(` over `plugins/*/commands`,
`agents`, `scripts`, `templates`, README and CLAUDE.md found:

- `plugins/tce/commands/init.md:586,588` — the two `Read` forms above.
- `plugins/tce/commands/init.md:590` — `Edit(thoughts/shared/**)` (relative).
- `plugins/tsf/commands/init.md:358` — `Edit(thoughts/factory/**)`;
  `:360` — `Read(~/.claude/plugins/**)` only.
- `plugins/tsf/commands/cycle.md:4` — frontmatter
  `allowed-tools: Read(/${CLAUDE_PLUGIN_ROOT}/**), …` (introduced by `5fa4b8a`,
  TP-0034a). After substitution of an absolute root this is `//<root>/**`.
- `plugins/tsf/README.md:415`, `plugins/tsf/DESIGN.md:449`, `CLAUDE.md:842` —
  mention `Read(~/.claude/plugins/**)`.
- No tce command carries a `Read(` grant in its `allowed-tools`.
- `plugins/tce/scripts/check-init.sh` — no permission paths.
- tle — no permission paths.

### README

- `plugins/tce/README.md:335-340` — "**Accept the allowlist `/tce:init`
  offers.**" Lists what the entries cover (reading tce's reference files,
  writing under `thoughts/shared/`, local git, test commands); "re-run it to
  get them in an existing project"; never `git push` or `gh`. No `Read` form,
  no source-type distinction.
- `plugins/tce/README.md:342-355` — "**Headless runs (`claude -p`).**"
  Verified on 2.1.310; script grants since 1.5.1; `--allowedTools` for ≤1.5.0;
  "The agents still need the `/tce:init` allowlist", and an untrusted folder
  denied every reference read despite the allowlist.
- `plugins/tce/README.md` has no mention of `--plugin-dir` or
  directory-sourced marketplaces (grep).

### Version

- `plugins/tce/.claude-plugin/plugin.json:3` — `"version": "1.7.0"`;
  `.claude-plugin/marketplace.json:15` — `"version": "1.7.0"` for tce.
- `.claude/tce/profile.md:1` — `<!-- tce-config-version: 1.7.0 -->`.

## Defect Mechanism

- **Intended**: the entry from `init.md:582-589` allows the step agents to
  read `${CLAUDE_PLUGIN_ROOT}/references/*` without a prompt, for a tce loaded
  from any directory (stated rationale `init.md:579-584`; ticket's Desired
  Outcome).
- **Actual**: for a non-`~/.claude/plugins/` root, the instruction "the
  absolute path written out" inside `Read(<that path>/**)` produces
  `Read(/<abs>/**)`, since an absolute path begins with `/`.
- **Divergence**: Claude Code reads a single leading `/` in project settings as
  `<primary working directory>/<abs>/**` (permissions docs, anchor table). The
  rule therefore names a path under the project that does not exist, and the
  agents' reads of `<abs>/references/...` match no allow rule.
- **Propagation**: an unmatched read outside the project prompts
  interactively, and is denied under `claude -p` where nobody answers
  (ticket; TP-0045e plan `:463`; dossier `:43`). Marketplace installs take the
  `~/` branch (`init.md:586`), which the docs define as home-relative, so they
  are unaffected.
- **Re-run**: because the step offers whatever it computes and skips what is
  present (`init.md:597-598`, `:687-690`), a re-run today recomputes the same
  single-slash string, finds it present, and offers nothing.

## Code References

- `plugins/tce/commands/init.md:197-199` — Phase 2 proposal's allowlist line
- `plugins/tce/commands/init.md:579-625` — Phase 4 step 6 "Allowlist"
- `plugins/tce/commands/init.md:586-589` — the two `Read` forms
- `plugins/tce/commands/init.md:597-600` — skip-present / skip-silently rule
- `plugins/tce/commands/init.md:620-624` — append-only, byte-identical write
- `plugins/tce/commands/init.md:687-690` — tce 1.4.0 every-re-run bullet
- `plugins/tce/commands/init.md:710-714` — Notes: the one sanctioned edit
- `plugins/tce/README.md:335-340` — allowlist paragraph
- `plugins/tce/README.md:342-355` — headless paragraph
- `plugins/tsf/commands/cycle.md:4` — `Read(/${CLAUDE_PLUGIN_ROOT}/**)`
- `plugins/tsf/commands/init.md:360` — `Read(~/.claude/plugins/**)`
- `CLAUDE.md:449-454` — `/tce:init`'s allowlist append, "Never widen it"
- `plugins/tce/.claude-plugin/plugin.json:3`, `.claude-plugin/marketplace.json:15` — version 1.7.0

## Architecture Documentation

- The allowlist is computed at runtime from the session's resolved
  `${CLAUDE_PLUGIN_ROOT}` (introduced in `d68f467`, TP-0045b, released as tce
  1.4.2; before that the text was a fixed `Read(~/.claude/plugins/**)` with a
  parenthetical "grant that directory instead" for `--plugin-dir`).
- Re-run upgrades of the allowlist are not version-gated: the 1.4.0
  Idempotency bullet re-derives and offers missing entries on every run. The
  upgrade list's other bullets are tied to a missing section or directory.
- Sanctioned `settings.json` edits in the repo: `/tmt:init` removes the
  template's hook entries (CLAUDE.md:228), `/tsf:init` appends its allowlist,
  `/tce:init` appends its allowlist (CLAUDE.md:449-454); all approval-gated
  and surgical. No sanctioned edit removes an allow entry.
- CLAUDE.md's same-commit spans: no span names init.md step 6 together with
  the README; the "Releasing" section requires the version bump in both
  `plugin.json` and `marketplace.json` and the tag hand-over to the human.

## Historical Context (from thoughts/)

- `thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md:115-118`
  — the scratch fixture was planned with
  `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)` for the
  `--plugin-dir` load; `:463` (phase 5 Issues) records: "Fixture needed
  `Read(//abs/**)`: `init.md`'s single-slash `Read(<abs path>/**)` is denied
  even when trusted (untrusted denied as well)." Runs were on 2.1.310 with
  `--plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce`.
- `thoughts/shared/dossiers/2026-10-27-TP-0045e-defects-from-stage-2-run.md:43`
  — the defect recorded as out of scope, "Worth a ticket"; `:42` — untrusted
  folders ignore project allow rules under `claude -p`; `:44` — the scratch
  folder is marked trusted in the user's Claude config.
- `d68f467` (TP-0045b) — commit that introduced the resolved-root branch in
  step 6.
- `5fa4b8a` (TP-0034a) — commit that added `Read(/${CLAUDE_PLUGIN_ROOT}/**)` to
  `/tsf:cycle` and `Read(~/.claude/plugins/**)` to `/tsf:init`.

## Related Research

- TP-0045e's plan and dossier above (no separate research document on the
  permission syntax).

## Open Questions

1. **Stale single-slash entry: leave it, or offer its removal?** After the
   fix, a re-run appends `Read(//<abs>/**)`; the old `Read(/<abs>/**)` stays
   because step 6 is append-only (`init.md:621-624`). Option A: leave it and
   say so in the dialog intro or hand-off (no new kind of edit; the dead entry
   is inert, it matches a non-existent project path). Option B: offer removal
   in the same approval (one more sanctioned edit kind, which
   `init.md:710-714` and `CLAUDE.md:449-454` describe today as append-only and
   "never widened" — those texts would have to say removal is allowed and of
   what exactly). The intent assigns this decision to planning.
2. **How does step 6 recognise "tce's path" in an old entry, if removal is
   chosen?** Only an exact match on `Read(/<current root>/**)` is
   unambiguous; an entry for a previous root (tce moved) would not match.
   Relevant only under Option B.
