# Dossier: TP-0045g — /tce:init writes an absolute Read grant that never matches

## Summary

For a tce loaded from its source directory, `/tce:init` now offers the `Read(//<absolute path>/**)` grant that Claude Code actually matches, and a re-run replaces the dead single-slash entry tce up to 1.7.0 wrote, in one approval; released as tce 1.7.1 (untagged).

Criteria met 22/29 · fix rounds 1 · tests added 0 · decisions made for you 6 · for you to check 3

**Start here:** The release commit landed before the real-run check in a trusted folder, which tests the plan's riskiest assumption (a `//` rule also covers a read a subagent makes). A headless run with the rule passed through `--settings` already matched (`permission_denials: []`), but the trusted-folder runs below are still yours, and the tag should wait until they pass. [`plugins/tce/commands/init.md:588-596`](https://github.com/tobyS/toby-plugins/blob/e9d8295916889ca52c4f6bd6875c422115265244/plugins/tce/commands/init.md#L588-L596)

## What was built

Step 6 of `/tce:init` (the allowlist step) now writes `Read(//<path without its leading slash>/**)` for a directory-sourced tce and says why in one sentence: a single leading `/` is relative to the project in Claude Code's permission syntax. A re-run already recomputes the allowlist every time, so the `//` entry shows up as missing on its own. Because the old entry would otherwise sit there dead, the step now also offers removing exactly the string `Read(<plugin root>/**)`, in the same dialog, with a variant intro and question ("Apply these changes…") shown only when that entry is present. That makes the allowlist edit more than append-only for the first time, so `init.md`'s Notes and CLAUDE.md's sanctioned-edit rule now name the one removal and add "never any other removal". The README's allowlist and headless notes name the new form, and tce is bumped to 1.7.1. The trusted-folder real run could not happen in-session because the scratch folder was never trusted, and trusting it is a human step.

## Where to look

- [`plugins/tce/commands/init.md:593-596`](https://github.com/tobyS/toby-plugins/blob/e9d8295916889ca52c4f6bd6875c422115265244/plugins/tce/commands/init.md#L593-L596): the stale-entry rule, the first time `/tce:init` removes anything from `settings.json`. It matches one exact string only, so an entry left from an earlier tce location stays.
- [`plugins/tce/commands/init.md:628-651`](https://github.com/tobyS/toby-plugins/blob/e9d8295916889ca52c4f6bd6875c422115265244/plugins/tce/commands/init.md#L628-L651): the variant intro, question and write rule. This dialog copy is verbatim contract text, and it has only been read, not seen in a real `/tce:init` run (check 1 below).
- [`CLAUDE.md:449-456`](https://github.com/tobyS/toby-plugins/blob/e9d8295916889ca52c4f6bd6875c422115265244/CLAUDE.md#L449-L456): the repository rule that now allows the one removal. It is policy, so check that the wording is what you want to bind future changes to.

## Decided for you

- **Remove only the exact string `Read(<current root>/**)` (single slash)** — over matching any single-slash `Read` entry that looks like tce: only the exact string is provably the one tce wrote
- **Removal in the same dialog as the append, with a variant intro and question ("Apply these changes…", "Apply them (Recommended)") shown only when the stale entry is present** — over a second dialog, or the unchanged copy: one approval, one write, and the unchanged intro's "nothing else in that file changes" would be false
- **Name the one removal in CLAUDE.md's sanctioned-edit rule and `init.md`'s Notes, adding "never any other removal"** — over leaving "never widen it" unqualified: the texts would otherwise contradict the command
- **A short tce 1.7.1 bullet in the Idempotency list pointing at step 6, not version-gated** — over no bullet: makes the upgrade path findable next to the other upgrades, without a second mechanism
- **Verify in a scratch fixture loaded with `--plugin-dir` and `--setting-sources project`** — over this repository: this repo uses the marketplace install, and the user's own settings must not mask a miss
- **Patch release 1.7.1 as the last phase** — over bumping first: the tag lands on verified text (TP-0045e's pattern)

## For you to check

- [ ] 3, 9, 23, 24. Trust the fixture, re-run `/tce:init` and check an interactive read — run `cd /tmp/tce-0045g.gjHLcA/project && claude --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce --setting-sources project`, accept the trust dialog, run `/tce:init`, and choose "Apply them" at the allowlist dialog; then in the same session type `Use the Agent tool with the general-purpose subagent to Read /Users/toby/code/work/toby-plugins/plugins/tce/references/work-brief.md and print its first line. Do not read it yourself.` Pass looks like this: the dialog is the "Apply these changes to .claude/settings.json?" variant, lists `Read(//Users/toby/code/work/toby-plugins/plugins/tce/**)` to append and `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)` to remove; `diff <(jq -S . /tmp/tce-0045g.gjHLcA/settings.before.json) <(jq -S . /tmp/tce-0045g.gjHLcA/project/.claude/settings.json)` shows only those two lines; the read prints `<!--` with no permission prompt. The trust dialog is a human acceptance (setting it in your Claude config would change your user config), and the dialog cannot be answered headless.
- [ ] 3, 9, 25. Headless read in the now-trusted fixture — run `cd /tmp/tce-0045g.gjHLcA/project && claude -p --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce --setting-sources project --output-format json "Use the Agent tool with the general-purpose subagent to Read /Users/toby/code/work/toby-plugins/plugins/tce/references/work-brief.md and print its first line. Do not read it yourself." > /tmp/tce-0045g.gjHLcA/out.json && jq '.permission_denials' /tmp/tce-0045g.gjHLcA/out.json && claude --version`; pass looks like `[]` and no "has not been trusted" line on stderr. Depends on the trust step above.
- [ ] 5, 29. Create the release tag — outside the sandbox, run `git -C /Users/toby/code/work/toby-plugins tag -s tce--v1.7.1 2ba5a94 -m "tce 1.7.1"`, then `git tag --list 'tce--v1.7.1'` and `git tag -v tce--v1.7.1`; pass looks like the tag listed and "Good signature". The agent never tags: the personal signing key is outside the sandbox (CLAUDE.md "Releasing").

## Concerns

- Negative control not run: the fresh fixture folder is not trusted yet, so it falls to the checks above (the first one trusts it). Plan Phase 3.
- The fixture lives under `/tmp` (macOS resolves it to `/private/tmp`), so the trust entry may be stored under the `/private` path, and the folder may be gone after a reboot. Plan Phase 3.
- The release was committed before Phase 3's real-run checks (the plan's riskiest assumption); the tag should wait until they pass. Plan Phase 4.
- The tag must be created by you outside the sandbox on the bump commit, which is no longer HEAD: `git tag -s tce--v1.7.1 2ba5a94 -m "tce 1.7.1"`. Plan Phase 4.
- `init.md` step 6: the `//` rule already matched a subagent read under `claude -p` on Claude Code 2.1.316, passed with `--settings`; the trusted-folder project-settings run is still open (checks 1 and 2 above).

## Artifacts

- Intent: `thoughts/shared/intents/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md`
- Research: `thoughts/shared/research/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md`
- Plan: `thoughts/shared/plans/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md` (its `## Verification` section holds the evidence per criterion)
