# TP-0045g: /tce:init writes a Read grant for a directory-sourced tce that matches — Implementation Plan

## Overview

`/tce:init`'s allowlist step writes `Read(<abs path>/**)` for a tce loaded
from its source directory (`--plugin-dir` or a marketplace added from a local
path). The absolute path starts with `/`, so the entry has a single leading
slash, which Claude Code reads as a path inside the project: the grant never
matches, and the step agents' reads of tce's reference files prompt
(interactive) or are denied (`claude -p`). This plan switches the instruction
to the `//` absolute form, lets a re-run replace the stale single-slash entry
on approval, aligns the README and CLAUDE.md, verifies on a real run, and
releases tce 1.7.1.

## Current State Analysis

- `plugins/tce/commands/init.md:579-625` — Phase 4 step 6 "Allowlist". The
  "tce's own files" bullet (`:582-589`) ends "→ `Read(<that path>/**)`, with
  the absolute path written out", which yields `Read(/abs/**)`.
- `init.md:596-600` — skip entries already present; skip the step silently
  when none are missing. `:601-618` — verbatim intro ("They are appended to
  .claude/settings.json; nothing else in that file changes.") and the
  AskUserQuestion dialog (header "Allowlist", "Append them (Recommended)" /
  "Skip"). `:620-624` — append-only, byte-identical write.
- `init.md:197-199` — Phase 2 proposal line "[N] entries are missing…".
- `init.md:633` (hand-off block) — "N allowlist entries appended".
- `init.md:687-690` — the tce 1.4.0 Idempotency bullet: on every re-run, same
  version too, compute the entries and offer the missing ones.
- `init.md:710-714` (Notes) — the allowlist append is "the one edit" to
  `settings.json`, "never widened".
- `CLAUDE.md:449-454` — "`/tce:init`'s allowlist append is the third
  sanctioned `settings.json` edit … **Never widen it**".
- `plugins/tce/README.md:335-340` ("Accept the allowlist") and `:342-355`
  ("Headless runs") — name no `Read` form and no source type.
- `plugins/tce/.claude-plugin/plugin.json:3` and
  `.claude-plugin/marketplace.json:15` — version 1.7.0.

## Desired End State

For a directory-sourced tce, `/tce:init` offers `Read(//<abs path without
its leading slash>/**)`, says why in one sentence, and on a re-run in a
project holding the old `Read(/<abs>/**)` entry offers the corrected entry as
missing plus the stale entry's removal, in one approval. The README and
CLAUDE.md say the same. A real run in a trusted scratch project with a
`--plugin-dir` tce shows an agent's reference read allowed with no prompt and
no `claude -p` denial. tce 1.7.1 is committed and the tag command handed over.

### Key Discoveries:

- Claude Code permission docs: `//path` is absolute, `/path` is relative to
  the settings source (project settings: the primary working directory) —
  research "Claude Code permission path syntax".
- TP-0045e phase 5 (`thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md:463`):
  only `Read(//abs/**)` matched on Claude Code 2.1.310, in a trusted folder.
- The 1.4.0 bullet (`init.md:687-690`) already reaches step 6 on every
  re-run; once step 6 computes the `//` string, it differs from the stored
  single-slash string and is offered as missing.
- No other shipped text writes a single-slash absolute permission path
  (tsf's `Read(/${CLAUDE_PLUGIN_ROOT}/**)` expands to `//…`).

## What We're NOT Doing

- The marketplace-install grant `Read(~/.claude/plugins/**)`.
- Untrusted-folder behaviour under `claude -p` (README note from TP-0045e).
- tsf's `/tsf:init` allowlist.
- This repository's own `.claude/settings.json` (holds no `Read(` grant) and
  re-stamping this repo's `profile.md` marker to 1.7.1 (`/tce:init` re-run,
  the human's call after the release).
- Removing any entry other than the exact stale string for the current
  plugin root (an entry for an earlier tce location stays).
- Windows `//c/...` forms.

## Implementation Approach

One text change in `init.md` step 6 carries the fix; re-runs pick it up
through the existing every-re-run check. The stale-entry removal joins the
same dialog with a variant intro, and the two texts that call the allowlist
append-only and "never widened" (`init.md` Notes, CLAUDE.md) name the one
removal. The README follows, then a real-run check in a scratch fixture, then
the release, so the tag lands on verified text.

## Decisions

- **Use the `//<absolute path>/**` form** — over a `~/`-relative form: `~/` only covers a tce under the home directory, and only `//` was verified on a real run *(yours)*
- **Rely on the existing every-re-run allowlist check for upgrades** — over a separate version-gated migration step: the 1.4.0 Idempotency bullet already offers whatever is missing regardless of version *(yours)*
- **Offer removal of the stale single-slash entry** — over leaving it inert and naming it in the hand-off *(yours)*
- **Remove only the exact string `Read(<current root>/**)` (single slash)** — over matching any single-slash `Read` entry that looks like tce: only the exact string is provably the one tce wrote *(decided for you)*
- **Removal in the same dialog as the append, with a variant intro and question ("Apply these changes…", "Apply them (Recommended)") shown only when the stale entry is present** — over a second dialog, or the unchanged copy: one approval, one write, and the unchanged intro's "nothing else in that file changes" would be false *(decided for you)*
- **Name the one removal in CLAUDE.md's sanctioned-edit rule and `init.md`'s Notes, adding "never any other removal"** — over leaving "never widen it" unqualified: the texts would otherwise contradict the command *(decided for you)*
- **A short tce 1.7.1 bullet in the Idempotency list pointing at step 6, not version-gated** — over no bullet: makes the upgrade path findable next to the other upgrades, without a second mechanism *(decided for you)*
- **Verify in a scratch fixture loaded with `--plugin-dir` and `--setting-sources project`** — over this repository: this repo uses the marketplace install, and the user's own settings must not mask a miss *(decided for you)*
- **Patch release 1.7.1 as the last phase** — over bumping first: the tag lands on verified text (TP-0045e's pattern) *(decided for you)*

## Phase 1: init.md step 6 and the sanctioned-edit texts

### Overview

Write the `//` form, offer the stale entry's removal, and make every text
describing the allowlist edit agree.

### Changes Required:

#### 1. The `Read` form and the stale entry

**File**: `plugins/tce/commands/init.md`
**Changes**: In step 6's "tce's own files" bullet (`:582-589`), replace
"→ `Read(<that path>/**)`, with the absolute path written out." with:

```markdown
     anywhere else (a directory-sourced marketplace or `--plugin-dir`, which
     load the plugin from its source directory) → `Read(//<that path, without
     its leading slash>/**)`, e.g. `Read(//src/tce/**)` for `/src/tce`. The
     double slash is Claude Code's absolute form: a single leading `/` is
     relative to the project, so `Read(/src/tce/**)` never matches.
     **Stale entry:** if `permissions.allow` holds that single-slash form for
     this path — exactly `Read(<that path>/**)`, which tce up to 1.7.0 wrote —
     offer its removal in this step's dialog. Match that exact string only;
     never remove any other entry.
```

#### 2. Skip rule, variant intro, question and write rule

**File**: `plugins/tce/commands/init.md`
**Changes**:
- `:597-598`: "if none are missing **and no stale entry is present**, skip
  this step silently"; show the entries to append and the entry to remove.
- After the existing verbatim intro (`:601-608`), add a second verbatim
  intro, used instead of the first only when a stale entry is present:

  ```
  These permission entries let /tce:work's agents read tce's reference files,
  commit, and run your project's test commands without stopping on a prompt.
  They are appended to .claude/settings.json, and the entry
  Read(<path>/**) is removed: an earlier tce wrote it with a single leading
  slash, which Claude Code reads as a path inside this project, so it never
  matched. Nothing else in that file changes.
  ```

  and its question variant: "Apply these changes to .claude/settings.json?"
  — header "Allowlist", options **Apply them (Recommended)** — Teammates get
  them once you commit the file. / **Skip** — unchanged text.
- Write rule (`:620-624`): on approval also remove exactly the stale array
  element; every other key and entry stays byte-identical.

#### 3. Proposal line, hand-off, Idempotency, Notes

**File**: `plugins/tce/commands/init.md`
**Changes**:
- `:197-199`: "[N] entries are missing from .claude/settings.json[, and one
  stale tce Read entry would be removed] — …".
- Hand-off (`:633`): "[.claude/settings.json — N allowlist entries
  appended[, stale Read entry removed], only if step 6 ran]".
- Idempotency, after the 1.4.0 bullet (`:687-690`): a bullet "tce 1.7.1
  corrects the `Read` entry for a directory-sourced tce (step 6): the every-
  re-run check above offers `Read(//…/**)` as missing and the stale
  single-slash entry's removal; nothing is version-gated."
- Notes (`:710-714`): "The edits this command makes to
  `.claude/settings.json` are the allowlist append in Phase 4 step 6 and, in
  the same approval, the removal of tce's own stale single-slash `Read` entry
  for the current plugin root — only on explicit approval, surgically, and
  never widened (never `git push`, never `gh`, never any other key, never any
  other removal)."

#### 4. CLAUDE.md sanctioned-edit rule

**File**: `CLAUDE.md`
**Changes**: In the bullet at `:449-454`, after "re-offered on re-run.", add
"Its one removal (TP-0045g) is tce's own stale `Read(<plugin root>/**)`
entry — the single-slash form up to 1.7.0 wrote, which never matched — by
exact string, in the same approval." and extend the bold rule to "**Never
widen it — never `git push`, never `gh`, never any other key, never any
other removal.**"

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes, and `claude plugin validate ./plugins/tce`, `./plugins/tmt`, `./plugins/tle`, `./plugins/tsf` pass (repo root)
- [x] `grep -c 'with the absolute path written out' plugins/tce/commands/init.md` prints 0
- [x] `grep -c 'Read(//src/tce/\*\*)' plugins/tce/commands/init.md` prints at least 1, and `grep -n 'relative to the project' plugins/tce/commands/init.md` hits step 6
- [x] `grep -c 'Apply these changes to .claude/settings.json?' plugins/tce/commands/init.md` prints 1 and `grep -c 'Append these entries to .claude/settings.json?' plugins/tce/commands/init.md` still prints 1
- [x] `grep -n 'never any other removal' plugins/tce/commands/init.md CLAUDE.md` hits both files
- [x] `grep -n 'tce 1.7.1' plugins/tce/commands/init.md` hits the Idempotency list

#### Manual Verification:

None (covered by Phase 3).

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `cfa4caa7353019a1c34fb09089bb540e5fe8ccbd`
- **Commit**: `0436c48` fix(TP-0045g): write the absolute // Read grant in /tce:init
- **Did**: init.md step 6 `//` form + stale-entry removal (variant intro/question, write rule), proposal line, hand-off, 1.7.1 Idempotency bullet, Notes; CLAUDE.md sanctioned-edit rule. Ticket → In Progress.
- **Issues**: `never any other removal` grep missed init.md (line wrap) → rewrapped Notes bullet
- **Verification**: ✅ plugin validate (all 5), ✅ six grep criteria
- **Fix rounds**: 1/3

---

## Phase 2: README

### Overview

Make the README's allowlist and headless notes name the form.

### Changes Required:

#### 1. Allowlist and headless paragraphs

**File**: `plugins/tce/README.md`
**Changes**:
- After "it never adds `git push` or `gh`." (`:340`): "For a tce loaded
  from its source directory (`--plugin-dir`, or a marketplace added from a
  local path) the read entry is `Read(//<absolute path>/**)`: the double
  slash is Claude Code's absolute form, while a single leading `/` is
  relative to the project and never matched. A re-run replaces the
  single-slash entry tce up to 1.7.0 wrote, on your approval."
- In "Headless runs" (`:352`), after "The agents still need the `/tce:init`
  allowlist": "(for a directory-loaded tce, the one from 1.7.1 on — re-run
  `/tce:init` in a project set up earlier)".

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -c 'Read(//<absolute path>/\*\*)' plugins/tce/README.md` prints 1
- [x] `grep -n '1.7.1' plugins/tce/README.md` hits the headless paragraph

#### Manual Verification:

None.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `9b2e35f` docs(TP-0045g): name the // Read grant in the tce README
- **Did**: README "Accept the allowlist" names the `Read(//<absolute path>/**)` form and the re-run replacement; "Headless runs" points directory-loaded tce at the 1.7.1 allowlist.
- **Issues**: none
- **Verification**: ✅ plugin validate tce, ✅ two grep criteria
- **Fix rounds**: 0/3

---

## Phase 3: Real-run verification

### Overview

Prove the written grant matches on a real run, interactively and under
`claude -p`, and that a re-run replaces the stale entry. No repository
changes; evidence goes into the implementation log, with `claude --version`.

### Changes Required:

#### 1. Scratch fixture (never committed)

Created with `mktemp -d`, path recorded in the log:
- `git init` and one initial commit.
- `.claude/tce/profile.md` (marker `<!-- tce-config-version: 1.7.0 -->`,
  Test `ls`, Typecheck/Lint none, Branch convention Current branch, Commit
  convention Conventional Commits) and `.claude/tce/tickets.md` copied from
  this repo; `.claude/tmt/config` with `TICKET_PREFIX=TP`; `thoughts/shared/`
  scaffolded.
- `.claude/settings.json` with the allowlist step 6 computes, except the
  read entry in the stale form
  `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)`; a copy saved as
  `settings.before.json` outside the fixture.
- Every run: `--plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce
  --setting-sources project`.

#### 2. Negative control (implementer, if the folder is trusted)

`claude -p` with the stale entry only, prompt "Use the Agent tool with the
general-purpose subagent to Read
/Users/toby/code/work/toby-plugins/plugins/tce/references/work-brief.md and
print its first line", `--output-format json`; expect a denial for that
path. If the folder is not trusted yet, record that and leave it to the
Manual items.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] The fixture exists with the stale entry, and `jq '.permissions.allow' <fixture>/.claude/settings.json` lists `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)`

#### Manual Verification:

- [x] Re-run replaces the stale entry: `cd <fixture> && claude --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce --setting-sources project`, trust the folder, run `/tce:init`. Pass: the allowlist dialog uses the "Apply these changes" variant, lists `Read(//Users/toby/code/work/toby-plugins/plugins/tce/**)` to append and the single-slash entry to remove; after "Apply them", `diff <(jq -S . settings.before.json) <(jq -S . <fixture>/.claude/settings.json)` shows only those two lines changed. Fail: no dialog, or the `//` entry missing. — accepted by user 2026-11-02 without running it (re-open the ticket if it fails)
- [x] Interactive read, no prompt: in the same fixture session, the Agent-read prompt from Change 2 prints the file's first line with no permission prompt. Fail: a prompt for the `references/` path. — accepted by user 2026-11-02 without running it (re-open the ticket if it fails)
- [x] Headless read, no denial (verifier attempts this first, once the folder is trusted): `cd <fixture> && claude -p --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce --setting-sources project --output-format json "<the Agent-read prompt>" > out.json && jq '.permission_denials' out.json`. Pass: `[]`. Record `claude --version`. — accepted by user 2026-11-02 without running it (re-open the ticket if it fails)

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `9c93721` docs(TP-0045g): record phase 3's scratch fixture
- **Did**: fixture `/tmp/tce-0045g.gjHLcA/project` (git repo, 1.7.0 profile, tickets.md, tmt config, `thoughts/shared/`), settings.json = step 6's allowlist with the stale `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)`; copy at `/tmp/tce-0045g.gjHLcA/settings.before.json`. No repo changes.
- **Issues**: fixture not trusted (fresh path, no `hasTrustDialogAccepted` in `~/.claude.json`) → negative control not run, left to the Manual items; the first Manual item trusts it (key may be `/private/tmp/…`). Claude Code 2.1.316.
- **Verification**: ✅ plugin validate tce, ✅ fixture `jq` lists the stale entry
- **Fix rounds**: 0/3

---

## Phase 4: Release tce 1.7.1

### Overview

Bump and hand the tag command to the human (CLAUDE.md "Releasing").

### Changes Required:

#### 1. Version

**File**: `plugins/tce/.claude-plugin/plugin.json` (`:3`), `.claude-plugin/marketplace.json` (`:15`)
**Changes**: `"version": "1.7.0"` → `"version": "1.7.1"` in both.

#### 2. Tag hand-over

Run `claude plugin tag --dry-run ./plugins/tce`; hand the human
`claude plugin tag ./plugins/tce` when the bump commit is HEAD, otherwise
`git tag -s tce--v1.7.1 <sha> -m "tce 1.7.1"`. Record the tag as handed
over, not created.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes, and `claude plugin validate ./plugins/tce`, `./plugins/tmt`, `./plugins/tle`, `./plugins/tsf` pass
- [x] `grep -c '"version": "1.7.1"' plugins/tce/.claude-plugin/plugin.json` prints 1, and `jq -r '.plugins[] | select(.name=="tce") | .version' .claude-plugin/marketplace.json` prints `1.7.1`
- [x] `claude plugin tag --dry-run ./plugins/tce` succeeds

#### Manual Verification:

- [x] The human ran the handed-over tag command outside the sandbox; `git tag --list 'tce--v1.7.1'` prints the tag and `git tag -v tce--v1.7.1` verifies the signature. — confirmed by user 2026-11-02

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `2ba5a94` chore(TP-0045g): release tce 1.7.1
- **Did**: tce 1.7.0 → 1.7.1 in `plugins/tce/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.
- **Issues**: `claude plugin tag --dry-run` refuses uncommitted manifest changes → run after the bump commit. Tag handed over, not created: `git tag -s tce--v1.7.1 2ba5a94 -m "tce 1.7.1"` (bump commit is no longer HEAD).
- **Verification**: ✅ plugin validate (all 5), ✅ version greps, ✅ tag dry-run (tce--v1.7.1)
- **Fix rounds**: 0/3

---

## Testing Strategy

### Unit Tests:

- None (markdown prompts; the profile's Test command is `claude plugin validate`).

### Integration Tests:

- Phase 3's fixture: stale-entry re-run, interactive read, headless read.

### Manual Testing Steps:

1. Phase 3's three Manual items, in order (the first trusts the folder).
2. Phase 4's tag confirmation.

## Risks

- **Riskiest assumption: a `//` rule covers a read a subagent makes.**
  Claude Code issue anthropics/claude-code#39387 (a duplicate of #37730)
  reports a `//` rule still prompting for a read inside an Explore subagent.
  TP-0045e's evidence shows `Read(//abs/**)` matching, but the step agents'
  reads are subagent reads. Phase 3's interactive and headless Agent-read
  items test exactly this. If they fail, the run stops there and the finding
  goes back to you before the release phase.

## Performance Considerations

None.

## Migration Notes

Projects initialised with a directory-sourced tce up to 1.7.0 hold the dead
`Read(/<abs>/**)` entry. A `/tce:init` re-run (which `work.sh preflight`
already prompts for once the profile marker is older than 1.7.1) offers the
corrected entry and the removal in one approval.

## References

- Original ticket: `thoughts/shared/tickets/TP-0045g-init-allowlist-absolute-read-path.md`
- Intent: `thoughts/shared/intents/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md`
- Related research: `thoughts/shared/research/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md`
- Evidence: `thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md:463`

## Verification

Baseline: `cfa4caa7353019a1c34fb09089bb540e5fe8ccbd` (recorded) · suites: ✅ `claude plugin validate .`, ✅ `./plugins/tce`, ✅ `./plugins/tmt`, ✅ `./plugins/tle`, ✅ `./plugins/tsf` (all exit 0, "Validation passed"; the LICENSE/icon lines are plugin-directory checks that "do not change the result", unchanged by this diff) · Claude Code 2.1.316

Criteria: ticket acceptance criteria (1-5), intent acceptance criteria (6-11), phase criteria (12-29).

- 1. For a directory-sourced tce, `init.md` instructs the `Read(//<absolute path>/**)` form and says why — met — `plugins/tce/commands/init.md:588-592` the `Read(//<that path, without its leading slash>/**)` form, the `Read(//src/tce/**)` example and "a single leading `/` is relative to the project"
- 2. Re-run detects an existing single-slash entry as missing and offers the corrected one; the old entry's handling is decided — met — `plugins/tce/commands/init.md:721-723` (every re-run offers `Read(//…/**)` as missing), `:593-596` (removal of the exact stale string offered)
- 3. (MANUAL) Real run: an agent's read of a reference file under a `--plugin-dir` tce is allowed by the written grant, no prompt interactively, no denial under `claude -p`, in a trusted folder — for you to check — partial evidence: ran `claude -p --plugin-dir …/plugins/tce --setting-sources project --settings <file>` with an Agent-tool subagent read of `plugins/tce/references/work-brief.md` in an untrusted throwaway fixture (project settings ignored, so the `--settings` file alone decided): the single-slash `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)` gave one `Read` permission denial; the `Read(//Users/toby/code/work/toby-plugins/plugins/tce/**)` entry gave `permission_denials: []` and the first line `<!--`. The criterion's trusted-folder project-settings run needs the folder trusted (see below)
- 4. The tce README's allowlist / headless notes agree with the new form — met — `plugins/tce/README.md:340-345` (`Read(//<absolute path>/**)`, single `/` project-relative, re-run replaces it), `:357-358` (headless note points at the 1.7.1 allowlist)
- 5. tce version bumped; the human tags it outside the sandbox — for you to check — bump met (`plugins/tce/.claude-plugin/plugin.json:3`, `.claude-plugin/marketplace.json:15` = 1.7.1); `git tag --list 'tce--v1.7*'` prints only `tce--v1.7.0`, so the tag is not created yet
- 6. `init.md` instructs `Read(//<absolute path>/**)` and states in one sentence why — met — `plugins/tce/commands/init.md:591-592` "The double slash is Claude Code's absolute form: a single leading `/` is relative to the project, so `Read(/src/tce/**)` never matches."
- 7. Re-run with only `Read(/<path>/**)`: lists `Read(//<path>/**)` as missing and offers it through the allowlist dialog — met — `plugins/tce/commands/init.md:721-723`, `:605-608` (entries to append plus stale entry shown), `:628-646` (step 6's dialog, stale-entry variant)
- 8. Handling of the stale single-slash entry decided and stated in `init.md` — met — `plugins/tce/commands/init.md:593-596` (removal offered, exact string only), `:651` (removed on approval)
- 9. (MANUAL) Real run in a trusted scratch project with a `--plugin-dir` tce, no prompt / no `-p` denial, Claude Code version recorded — for you to check — same partial evidence as 3 (2.1.316); needs the trusted-folder run below
- 10. README allowlist and headless notes agree with `init.md` — met — `plugins/tce/README.md:340-345`, `:357-358` match `plugins/tce/commands/init.md:588-596`
- 11. Version bumped in `plugin.json` and `marketplace.json`; tag command handed to the human — met — ran `jq -r '.plugins[] | select(.name=="tce") | .version' .claude-plugin/marketplace.json`: `1.7.1`; `plugin.json:3` `"version": "1.7.1"`; hand-over recorded in Phase 4's log (`git tag -s tce--v1.7.1 2ba5a94 -m "tce 1.7.1"`); `git show --stat 2ba5a94` confirms it is the bump commit and HEAD is `1923b36`, so the `git tag -s` form is the right one
- 12. `claude plugin validate` for the marketplace and all four plugins passes — met — ran all five: exit 0, "Validation passed"
- 13. `grep -c 'with the absolute path written out'` prints 0 — met — phrase gone (diff removes it; no grep hit)
- 14. `Read(//src/tce/**)` appears at least once; `relative to the project` hits step 6 — met — `plugins/tce/commands/init.md:590`, `:592`
- 15. "Apply these changes…" count 1; "Append these entries…" count 1 — met — `plugins/tce/commands/init.md:640`, `:620`
- 16. `never any other removal` hits both files — met — `plugins/tce/commands/init.md:748`, `CLAUDE.md:455`
- 17. `tce 1.7.1` hits the Idempotency list — met — `plugins/tce/commands/init.md:721`
- 18. `claude plugin validate ./plugins/tce` passes — met — ran it: exit 0
- 19. `Read(//<absolute path>/**)` count in README is 1 — met — `plugins/tce/README.md:342`
- 20. `1.7.1` in README hits the headless paragraph — met — `plugins/tce/README.md:358`
- 21. `claude plugin validate ./plugins/tce` passes — met — ran it: exit 0
- 22. Fixture exists with the stale entry and `jq` lists it — met — ran `jq '.permissions.allow' /tmp/tce-0045g.gjHLcA/project/.claude/settings.json`: first element `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)`
- 23. (MANUAL) Re-run replaces the stale entry via the "Apply these changes" dialog; only those two lines change — for you to check — interactive `/tce:init` dialog in a folder that must first be trusted
- 24. (MANUAL) Interactive subagent read, no prompt — for you to check — interactive session; folder trust required
- 25. (MANUAL) Headless read gives `.permission_denials == []`; version recorded — for you to check — the fixture is untrusted (`claude -p` printed "Ignoring 11 permissions.allow entries from .claude/settings.json: this workspace has not been trusted"); the `//` rule itself matched via `--settings` (see 3)
- 26. `claude plugin validate` for the marketplace and all four plugins passes — met — ran all five: exit 0
- 27. `"version": "1.7.1"` in plugin.json; marketplace tce version 1.7.1 — met — `plugins/tce/.claude-plugin/plugin.json:3`, `jq` printed `1.7.1`
- 28. `claude plugin tag --dry-run ./plugins/tce` succeeds — met — ran it: exit 0, "Dry run — would create tag tce--v1.7.1"
- 29. (MANUAL) The human ran the tag command; the tag exists and its signature verifies — for you to check — not created yet (`git tag --list` shows only `tce--v1.7.0`)

For you to check:
- 3, 9, 23, 24. Trust the fixture, re-run `/tce:init` and check an interactive read — run `cd /tmp/tce-0045g.gjHLcA/project && claude --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce --setting-sources project`, accept the trust dialog, run `/tce:init`, and choose "Apply them" at the allowlist dialog; then in the same session type `Use the Agent tool with the general-purpose subagent to Read /Users/toby/code/work/toby-plugins/plugins/tce/references/work-brief.md and print its first line. Do not read it yourself.` Pass looks like this: the dialog is the "Apply these changes to .claude/settings.json?" variant, lists `Read(//Users/toby/code/work/toby-plugins/plugins/tce/**)` to append and `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)` to remove; `diff <(jq -S . /tmp/tce-0045g.gjHLcA/settings.before.json) <(jq -S . /tmp/tce-0045g.gjHLcA/project/.claude/settings.json)` shows only those two lines; the read prints `<!--` with no permission prompt. The trust dialog is a human acceptance (setting it in `~/.claude/.claude.json` would change your user config), and the AskUserQuestion dialog cannot be answered headless.
- 3, 9, 25. Headless read in the now-trusted fixture — run `cd /tmp/tce-0045g.gjHLcA/project && claude -p --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce --setting-sources project --output-format json "Use the Agent tool with the general-purpose subagent to Read /Users/toby/code/work/toby-plugins/plugins/tce/references/work-brief.md and print its first line. Do not read it yourself." > /tmp/tce-0045g.gjHLcA/out.json && jq '.permission_denials' /tmp/tce-0045g.gjHLcA/out.json && claude --version`; pass looks like `[]` and no "has not been trusted" line on stderr. Depends on the trust step above.
- 5, 29. Create the release tag — outside the sandbox, run `git -C /Users/toby/code/work/toby-plugins tag -s tce--v1.7.1 2ba5a94 -m "tce 1.7.1"`, then `git tag --list 'tce--v1.7.1'` and `git tag -v tce--v1.7.1`; pass looks like the tag listed and "Good signature". The agent never tags (CLAUDE.md "Releasing": the personal signing key is outside the sandbox).

## Implementation Closeout

- **Plan-compliance gate**: Suites green (validate x5). Gate: 19 met, 10 cannot verify, 5 manual; 3 settled by runs — criteria met 22/29, 3 for you to check, 0 not met.
- **Manual verification**: accepted by user 2026-11-02 without running the real-run checks (3, 9, 23, 24, 25) — the ticket is re-opened if the grant does not match; signed tag `tce--v1.7.1` at `2ba5a94` (5, 29) confirmed by user 2026-11-02 (good signature)
- **Merge reference**: direct: main @ 28845c7
- **Ticket**: TP-0045g → Done
