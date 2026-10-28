# TP-0045e: Defects From the Stage-2 Run — Implementation Plan

## Overview

TP-0045c's headless verification run found four places where tce does not
behave as its own text says. This plan fixes all four in one patch release
(tce 1.5.1):

1. Autonomous `/tce:intent` prints prose before its return line, and
   `/tce:quickfix` has no explicit rule for reading that line.
2. The preflight refusal (`work-loop.md` Step 0) is paraphrased instead of
   printed as the fixed block.
3. The quoted `allowed-tools` script grants did not approve the
   absolute-path script calls under `claude -p`. The cause is not yet
   known, so it is established first.
4. An interruption between the phase commit and the log-hash commit leaves
   the log edit uncommitted, and the next phase's feature commit absorbs it.

## Current State Analysis

- **Autonomous intent** (`plugins/tce/commands/intent.md:394-430`): the mode
  says "end with exactly one return line". That constrains only the end of
  the output, and "Nothing else is written" refers to files. The skill runs
  inline in quickfix's turn (no `context: fork`, `intent.md:1-5`).
  `quickfix.md:37-45` branches on the two prefixes and has no rule for
  surrounding text or for a missing prefix.
- **Preflight** (`plugins/tce/references/work-loop.md:90-101`): "refuse and
  stop:" followed by a block whose first line contains the `<command>`
  placeholder. The model has to fill the template in, so it composes. There
  is no verbatim instruction. `work.sh preflight`'s `detail:`
  (`plugins/tce/scripts/work.sh:59-66`) is different text that nobody relays.
  The block text appears nowhere else in `plugins/` or `CLAUDE.md`.
- **Grants**: all nine tce commands use the quoted form
  `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh":*)`: `research.md:4`,
  `plan.md:4`, `implement.md:4`, `quickfix.md:5`, `work.md:5`,
  `intent.md:4`, `commit.md:3`, `review.md:5`, `list.md:4`. `CLAUDE.md:343`
  quotes the same form. The docs and Anthropic's ralph-loop plugin use the
  unquoted form. Issue #14956 reports that a quoted pattern does not match
  under `-p`. The TP-0045c run (2.1.301) did not record the denied strings.
  Installed now: Claude Code 2.1.310. That version has `--plugin-dir`,
  `--permission-mode manual`, `--permission-prompts none` and
  `--setting-sources`.
- **Log commit** (`plugins/tce/agents/implementer.md:128-151`): step 6 writes
  `✅ Complete` before the first commit, and step 7 commits the hash in a
  second, docs-only commit. `stage.sh:154-159` counts a phase as done from
  the working tree's `**Status**` line, so after an interruption the re-run
  goes on to phase k+1. That phase's `tce:commit` stages "the plan" whole,
  stray hash edit included. Fix mode (`implementer.md:153-166`) also commits
  through `tce:commit`.
- tce is at `1.5.0` (`plugins/tce/.claude-plugin/plugin.json:3`,
  `.claude-plugin/marketplace.json:15`).

## Desired End State

- Autonomous `/tce:intent` prints exactly one line and nothing around it.
  quickfix decides on the **last** line that starts with `intent:` or
  `insufficient:`. On `intent:` it continues only when
  `work.sh artifact <path>` reports `yes` three times. With no prefixed line
  it stops with a fixed message.
- With either environment variable missing, every step command prints the
  Step 0 block exactly as written in `work-loop.md`, and nothing else.
- The headless grant behaviour has been reproduced or ruled out, both under
  `claude -p` and interactively. The outcome is either corrected grants in
  all nine tce commands or a tce README note. The README also gains a
  "Headless runs" note that records what was verified and on which version.
- A re-run after an interruption between the two implementer commits first
  commits the stray plan edit on its own. The next feature commit does not
  touch the earlier phase's log.
- tce 1.5.1 in both manifests, tagged `tce--v1.5.1`.

### Key Discoveries:

- A file cannot contain the hash of the commit that holds it, and the
  implementer must never amend (`implementer.md:29`). The fix therefore
  keeps two commits and makes the re-run clean up after an interruption.
- `work.sh artifact` (`work.sh:70-87`) is the existing
  "exists, non-empty, committed" check, and quickfix already grants
  `work.sh` (`quickfix.md:5`). The disk check needs no new script.
- Position row 7 (`work-dispatch.md:53-54`) sends `k/N`, `k < N` to the
  implementer. So an interrupted state built by hand (phase 1 logged
  `✅ Complete`, plus an uncommitted hash edit) reproduces defect 4
  deterministically.
- `-p` without a permission mode denies whatever no allow rule approves
  (v2.1.302 and later). `--setting-sources project` keeps the user's own
  allowlist from hiding a miss.

## What We're NOT Doing

- tsf's identically quoted grants (`plugins/tsf/commands/cycle.md:4`,
  `spec.md:5`, `init.md:5`), and tle: excluded by the intent.
- Widening `/tce:init`'s allowlist.
- Changing `work.sh`'s output or arguments, `stage.sh`'s derivation, the log
  format, or any agent's return contract.
- Turning the autonomous intent's return into a fenced block, or giving
  `intent.md` `context: fork`.
- TP-0045d improvements, and ticketless branching or delivery (TP-0045f).

## Implementation Approach

Phase 1 investigates first, because its outcome decides which files change.
Phases 2–4 are independent text fixes, one defect each. Phase 5 re-runs all
four reproductions against the fixed plugin in a scratch consuming project.
Phase 6 releases, so the tag lands on verified code.

**Scratch fixture** (Phases 1 and 5). Built by the implementer outside the
repository (`mktemp -d`), never committed:

- `git init` with one initial commit.
- `.claude/tce/profile.md`: a minimal profile with `## Commands` Test
  `ls`, Typecheck none, Lint none; `## Branch convention` Current branch;
  `## Commit convention` Conventional Commits.
- `.claude/tce/tickets.md` and `.claude/tmt/config` copied from this repo
  (prefix `TP`), with `thoughts/shared/tickets/TP-0001-scratch.md` as a
  minimal Open ticket.
- For runs that need the agents: `.claude/settings.json` with the allowlist
  `/tce:init` offers (`plugins/tce/commands/init.md:580-593`), with
  `Read(/Users/toby/code/work/toby-plugins/plugins/tce/**)` for the
  `--plugin-dir` load.
- Every run loads the plugin with
  `--plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce`, or with a
  scratch copy of it where a grant variant is tested.

## Decisions

- **One sub-ticket and one release for all four defects** — over four tickets: each fix is small and they share the verification setup *(yours)*
- **Establish the headless grant cause first, and document a platform limit rather than work around it** — over adding the scripts to `/tce:init`'s allowlist: CLAUDE.md forbids widening it *(yours)*
- **A fixed message counts only if it reaches the user verbatim** — over "the message mentions the export lines": a paraphrase is exactly what failed *(yours)*
- **Preflight: a static block with no placeholder, plus an explicit "print exactly this, nothing before or after" rule** — over the script printing the block: the model repeats script text too, and the script's three-line contract would change *(yours)*
- **quickfix reads the last line starting with `intent:` or `insufficient:`, and on `intent:` also checks with `work.sh artifact` that the file is written and committed** — over the line rule alone: it also catches a line that names an unwritten file *(yours)*
- **Interrupted log edit: the implementer commits a dirty plan on its own before any phase work** — over counting a phase without a hash as unfinished: no change to `stage.sh`, `list.md` or the log format *(yours)*
- **If the quoted form is the cause, correct the grants in all nine tce commands** — over the five step commands only: the other four carry the same defect *(yours)*
- **Reproduce the grant issue with `/tce:list` plus one `/tce:plan` preflight, in a scratch project with `--setting-sources project`** — over re-running full step commands: one script call isolates the grant, and the user's own allowlist cannot hide a miss *(decided for you)*
- **Add a "Headless runs" README note in every outcome** — over a note only when the grants cannot be fixed: it records the version verified and the `--allowedTools` workaround for older versions *(decided for you)*
- **If both grant forms fail only under `-p`, leave the grants unchanged and document the limitation** — over trying further pattern variants: the intent prefers documenting a platform limit to working around it *(decided for you)*
- **Static block opens with "This tce command"** — over naming the command: a name means a placeholder the model fills in *(decided for you)*
- **Leave `work.sh preflight`'s `detail:` line as it is** — over aligning it with the block: nothing relays it *(decided for you)*
- **The dirty-plan commit lives in the implementer, in both phase and fix mode** — over a check in the orchestrator, which commits nothing today, and over phase mode only, since fix commits are feature commits too *(decided for you)*
- **Defect 4 is reproduced from an interrupted state built by hand** — over killing a live run at the right moment: a timed kill is not repeatable *(decided for you)*
- **The reproductions run before the release phase** — over releasing first as TP-0045c did: the tag then lands on verified code *(decided for you)*
- **Patch release 1.5.1, no Idempotency entry** — over 1.6.0: defects only, no new behaviour or project config *(decided for you)*
- **If a refusal is still paraphrased after the fix, stop with `needs decision`** — over switching to a script-sourced block unasked: the static block was your choice *(decided for you)*

## Phase 1: Reproduce and resolve the headless grant issue

### Overview

Establish whether the quoted grant form, the invocation path (typed versus
the Skill tool), or `-p` itself causes the miss. Then apply the outcome: a
grant rewrite, or a documented limitation. Either way the README gets a
headless note.

### Changes Required:

#### 1. Reproduction (no repository change)

Build the scratch fixture (Implementation Approach), plus a second copy of
the plugin in the scratch area whose `commands/list.md` line 4 reads
`allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh:*)` (unquoted).

Run this matrix in the scratch project. Each run is
`claude -p --plugin-dir <copy> --setting-sources project --permission-mode manual --permission-prompts none --output-format json "<prompt>"`,
and you read the result's `permission_denials` with `jq` (fall back to
`--output-format stream-json --verbose` if that field is absent):

| Run | Plugin copy | Prompt |
|---|---|---|
| A | quoted (this repo) | `/tce:list` |
| B | unquoted copy | `/tce:list` |
| C | quoted | `Use the tce:list skill.` (the model invokes it through the Skill tool) |
| D | unquoted copy | `Use the tce:list skill.` |
| E | quoted | `/tce:plan TP-0001` with both environment variables exported (exercises the `work.sh preflight` grant) |

For every denial, record the exact command string the model wrote.
Interactively, start `claude --plugin-dir <copy> --setting-sources project`
in the scratch project and run `/tce:list` with each copy (Manual item
below). Try this with `expect` first; a permission prompt for `stage.sh`
means a miss.

#### 2. Apply the outcome

Exactly one branch:

- **(i) The quoted form misses and the unquoted form matches** (in `-p`, and
  interactively when that could be checked). Rewrite every
  `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh":*)` to
  `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh:*)` in
  `plugins/tce/commands/{research,plan,implement,quickfix,work,intent,commit,review,list}.md`
  (the frontmatter lines listed under Current State). Prose call sites keep
  their quoted calls; only the patterns change. Update `CLAUDE.md:343` to the
  unquoted form.
- **(ii) Both forms miss only under `-p`.** Change no grant.
- **(iii) Both forms match everywhere on 2.1.310.** Change no grant: the
  defect is ruled out on this version.

#### 3. README note

**File**: `plugins/tce/README.md`, in `## Running the step commands`, after
the "Accept the allowlist" paragraph (`:328-333`).
**Changes**: a short paragraph headed **Headless runs (`claude -p`).** that
states the Claude Code version verified, which invocation paths were tested,
and the outcome:

- (i): the grants match headless from 1.5.1 on, and the agents still need
  the `/tce:init` allowlist;
- (ii): a headless run must pass the scripts on the command line, giving the
  exact `--allowedTools` value that worked in the matrix;
- (iii): no flag is needed on the version verified, with the
  `--allowedTools` value as the workaround for older versions.

Name `--allowedTools` in half a sentence, per the profile's Reader.

### Success Criteria:

#### Automated Verification:

- [x] Runs A–E completed, and the phase log's `**Did**`/`**Issues**` lines name the branch taken (i/ii/iii) and the denied command strings, or "none denied"
- [x] Branch (i) only: `grep -rn -F 'Bash("' plugins/tce/commands CLAUDE.md` returns nothing, and `grep -o -F 'Bash(${CLAUDE_PLUGIN_ROOT}/scripts/' plugins/tce/commands/*.md | cut -d: -f1 | sort | uniq -c` (counts occurrences, not lines, because each command keeps all its grants on one frontmatter line) reports the same per-file script counts as before (research 4, plan 4, implement 5, quickfix 4, work 5, intent 2, commit 1, review 2, list 1)
- [x] `grep -n "Headless runs" plugins/tce/README.md` finds the note, and it names a Claude Code version
- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass (plus `./plugins/tmt`, `./plugins/tle`, `./plugins/tsf`)

#### Manual Verification:

- [x] Interactive check in the scratch project (`claude --plugin-dir <copy> --setting-sources project`, then `/tce:list`) with the grant form the phase ships: the table appears with no permission prompt for `stage.sh`. Pass: no prompt. Fail: a prompt naming the absolute `stage.sh` path. — verified by agent, see ## Verification

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `4fc230e4532c9bfe145d0fe671b635ba6c3cd83b`
- **Commit**: `13164b8` fix(TP-0045e): unquote the tce script grants so they match headless
- **Did**: Branch (i). Unquoted the 30 script grants in the 9 tce commands and CLAUDE.md:343; README "Headless runs" note (2.1.310). Matrix on 2.1.310: A (quoted) denied `<root>/scripts/stage.sh TP-0001` (path unquoted); B, C, D, E5 none denied for the scripts; probe plugin (grant x call, `-p` and interactive): quoted grant misses only the unquoted call, unquoted grant matches both.
- **Issues**: C/D need `--allowedTools "Skill(tce:list)"` (Skill tool prompts in manual mode); untrusted fixture ignored project settings under `-p` (reads denied until trusted) → noted in README; unrelated denials of the model's own `for f in …` loops.
- **Verification**: ✅ grep checks, ✅ validate (marketplace + 4 plugins), ✅ interactive `/tce:list` (unquoted): stage.sh part approved, only a chained `echo` prompted
- **Fix rounds**: 0/3

---

## Phase 2: Preflight refusal as a fixed block

### Overview

Make Step 0's refusal a literal block that the model copies, not a template
it fills in.

### Changes Required:

#### 1. Step 0

**File**: `plugins/tce/references/work-loop.md` (`:90-101`)
**Changes**: Replace "Unless both `foreground:` and `timeout:` say `ok`,
refuse and stop:" and the block with:

````markdown
Run `"${CLAUDE_PLUGIN_ROOT}/scripts/work.sh" preflight`. Unless both
`foreground:` and `timeout:` say `ok`, print the block below **exactly as
written** — every character and line break, nothing before it, nothing after
it, no mention of the check's output and no re-run line — and stop:

```
This tce command needs foreground agents and a long Bash timeout. Quit Claude Code,
then start it again with:

  export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
  export BASH_DEFAULT_TIMEOUT_MS=600000
```
````

`quickfix.md:34-35` ("run its Step 0 with `<command>` = `/tce:quickfix`")
stays as it is, because `<command>` is still used elsewhere in the loop.

### Success Criteria:

#### Automated Verification:

- [x] `grep -n "<command> needs foreground" plugins/tce/references/work-loop.md` returns nothing
- [x] `grep -n "This tce command needs foreground agents" plugins/tce/references/work-loop.md` returns one line, and `grep -n "every character and line break" plugins/tce/references/work-loop.md` returns one line, in Step 0 (neither phrase exists today)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

None. The behaviour is checked headless in Phase 5.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `7532910` fix(TP-0045e): print the preflight refusal as a fixed block
- **Did**: `plugins/tce/references/work-loop.md` Step 0: block opens "This tce command" (no `<command>` placeholder) and carries an explicit print-exactly-as-written rule.
- **Issues**: none
- **Verification**: ✅ grep checks (old phrase gone, both new phrases once in Step 0), ✅ validate (marketplace + 4 plugins)
- **Fix rounds**: 0/3

---

## Phase 3: Autonomous intent hand-off

### Overview

The intent prints one line only, and quickfix reads it by an explicit rule
backed by a disk check.

### Changes Required:

#### 1. Autonomous mode output

**File**: `plugins/tce/commands/intent.md` (`:396-400`)
**Changes**: Replace "Ask nothing, print no draft, and end with exactly one
return line to the caller — `intent: <path>` on success, `insufficient: …`
on failure. Nothing else is written on failure." with: "Ask nothing and
print no draft. Your **entire output** is exactly one line — `intent:
<path>` on success, `insufficient: …` on failure — with no text before or
after it: no explanation, no summary, no heading. Nothing else is written on
failure." Steps 1, 2 and 6 keep their return forms. The frontmatter is
unchanged, so `intent` stays unflagged (TP-0017).

#### 2. quickfix's reading rule

**File**: `plugins/tce/commands/quickfix.md` (`:37-45`)
**Changes**: Replace "returns one line:" and the two bullets with:

```markdown
intent and returns one line. Read its output by this rule: the **last** line
that starts with `intent:` or `insufficient:` decides; any other text is
ignored.

- `intent: <path>` → run `"${CLAUDE_PLUGIN_ROOT}/scripts/work.sh" artifact
  <path>`. Continue with that path as `<argument>` only when `exists:`,
  `nonempty:` and `committed:` all say `yes`; otherwise stop: "The intent
  step named <path>, but that file is not written and committed. Re-run
  `/tce:quickfix`, or use `/tce:intent` for a dialogue."
- `insufficient: <line>` → stop: "Not enough to go on: <line>. Re-run
  `/tce:quickfix` with that added, or use `/tce:intent` for a dialogue."
- neither → stop: "The intent step returned no result. Re-run
  `/tce:quickfix`, or use `/tce:intent` for a dialogue."
```

### Success Criteria:

#### Automated Verification:

- [x] `grep -n "entire output" plugins/tce/commands/intent.md` finds the Autonomous mode sentence, and `grep -n "end with exactly one" plugins/tce/commands/intent.md` returns nothing
- [x] `grep -n "last\*\* line" plugins/tce/commands/quickfix.md` and `grep -n "work.sh\" artifact" plugins/tce/commands/quickfix.md` each return a line in section "2. Intent"
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

None. The behaviour is checked headless in Phase 5.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `23f9183` fix(TP-0045e): make the autonomous intent hand-off one line
- **Did**: `intent.md` Autonomous mode: entire output is the one return line, nothing around it. `quickfix.md` "2. Intent": last-prefixed-line rule, `work.sh artifact` check on `intent:`, stop on neither.
- **Issues**: none
- **Verification**: ✅ grep checks, ✅ validate (marketplace + 4 plugins)
- **Fix rounds**: 0/3

---

## Phase 4: Commit a stray plan edit before phase work

### Overview

A re-run after an interruption commits the leftover plan edit on its own, so
no feature commit carries it.

### Changes Required:

#### 1. Phase mode

**File**: `plugins/tce/agents/implementer.md` (`## Process — mode: phase`, before step 1)
**Changes**: Insert a step 0 and keep the existing numbering:

```markdown
0. **Stray plan edit.** Run `git status --porcelain -- <plan>`. If it lists
   the plan, an earlier dispatch was interrupted before its last plan commit.
   Commit the plan **alone** through `tce:commit`, as a docs-only commit
   (e.g. `docs(<ticket-id>): record the interrupted phase's log`, with no
   ticket scope when `ticket: none`), before reading the state or changing
   anything else. If the commit would ask or fails, return `blocked` with
   what it said.
```

#### 2. Fix mode

**File**: `plugins/tce/agents/implementer.md` (`## Process — mode: fix`, step 1)
**Changes**: Prefix step 1 with "First apply phase mode's step 0 (stray plan
edit)."

### Success Criteria:

#### Automated Verification:

- [x] `grep -n "Stray plan edit" plugins/tce/agents/implementer.md` returns the phase-mode step, and `grep -n "step 0 (stray plan" plugins/tce/agents/implementer.md` returns the fix-mode reference
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

None. The behaviour is checked headless in Phase 5.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `eb30f11` fix(TP-0045e): commit a stray plan edit before phase work
- **Did**: `plugins/tce/agents/implementer.md`: phase-mode step 0 commits a dirty plan alone (docs-only) before any phase work; fix-mode step 1 applies it first.
- **Issues**: none
- **Verification**: ✅ grep checks, ✅ validate (marketplace + 4 plugins)
- **Fix rounds**: 0/3

---

## Phase 5: Re-run the four reproductions

### Overview

Show the observable outcome from the intent against the fixed plugin. A
defect found here is fixed in this phase with its own commit, and the
reproduction is repeated. One exception: if a preflight refusal is still
paraphrased after one fix attempt within the static-block approach, stop and
return `needs decision` with the five captured outputs. Do not switch to a
script-printed block on your own.

### Changes Required:

None in this repository unless a reproduction fails. Use the scratch fixture
with `--plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce`, adding
Phase 1's `--allowedTools` value only if Phase 1 took branch (ii). Run each
`claude -p` with `--setting-sources project --output-format text` and
capture stdout to a file.

- **Defect 1:** `claude -p "/tce:intent --autonomous make it better"`.
- **Defect 2:** for each of `/tce:research TP-0001`, `/tce:plan TP-0001`,
  `/tce:implement TP-0001`, `/tce:work TP-0001` and `/tce:quickfix fix the
  typo in README`, run
  `env -u CLAUDE_CODE_DISABLE_BACKGROUND_TASKS claude -p "<command>"`.
  Diff each output against a file holding the Step 0 block (from
  `work-loop.md`, fence lines excluded).
- **Defect 3:** Phase 1's run A (or E) with the shipped grant form.
- **Defect 4:** in the fixture, add an intent, a research document with a
  `git_commit:` line, and a two-phase plan (Phase 1 creates `a.txt`, Phase 2
  creates `b.txt`, Automated `test -f <file>`). Commit phase 1's change with
  its log `✅ Complete` and a placeholder `**Commit**` hash. Then edit the
  hash line to the real hash **without committing**. Run `claude -p
  "/tce:implement TP-0001"` with both variables exported.

### Success Criteria:

#### Automated Verification:

- [x] Defect 1: the captured output is exactly one line that starts with `insufficient:` (`wc -l` prints 1), and `git status --porcelain` in the fixture is empty
- [x] Defect 2: all five diffs are empty (ignoring one trailing newline)
- [x] Defect 3: the run's outcome matches Phase 1's branch (i: no `permission_denials`; ii: none with the documented `--allowedTools`; iii: none)
- [x] Defect 4: `git log --format=%s` shows a docs-only commit before phase 2's feature commit; `git show --stat <phase-2 commit>` either omits the plan or `git show <phase-2 commit> -- <plan>` does not touch phase 1's `**Commit**` line; `git status --porcelain` is empty at the end
- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass after any fix from this phase

#### Manual Verification:

- [x] Defect 1 in quickfix: in the fixture, `/tce:quickfix make it better` stops with "Not enough to go on: …" and writes nothing, interactively or headless. Pass: that stop message and a clean `git status`. — verified by agent, see ## Verification

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `f220d0a` fix(TP-0045e): make the preflight refusal the entire reply; `494d4f2` fix(TP-0045e): make quickfix act on the intent's line in its own turn
- **Did**: Reproductions on 2.1.310 in trusted scratch fixtures. D1: 5/5 standalone runs one `insufficient:` line, tree clean. D2: 15/15 exact after fix (first round: quickfix prose line, implement fenced) — `work-loop.md` Step 0 "entire reply", fences excluded. D3: `/tce:list` approved unquoted `<root>/scripts/stage.sh TP-0001`. D4: `911cddf` docs-only commit before phase 2's `bbae7a8`, which leaves phase 1's `**Commit**` line alone; tree clean.
- **Issues**: quickfix ended its turn on the intent's line or paraphrased its stop (headless: 1 of 2 runs bad, then 3 of 3 after a first attempt) → `intent.md` "return value, not the end of the turn" + `quickfix.md` verbatim stops: 3/3 exact. D3's one denial is the model's own `for` loop (as in Phase 1). Fixture needed `Read(//abs/**)`: `init.md`'s single-slash `Read(<abs path>/**)` is denied even when trusted (untrusted denied as well). D4's verifier stop was a harness denial on writes under `.git/`.
- **Verification**: ✅ D1–D4, ✅ validate (marketplace + 4 plugins), ✅ Phase 2/3 grep criteria still hold
- **Fix rounds**: 3/3

---

## Phase 6: Release

### Overview

Ship tce 1.5.1.

### Changes Required:

#### 1. Version

**File**: `plugins/tce/.claude-plugin/plugin.json` (`:3`), `.claude-plugin/marketplace.json` (`:15`)
**Changes**: `1.5.0` → `1.5.1` in both. After the phase commit, run
`claude plugin tag ./plugins/tce`. If signing fails in the sandbox, create
the tag with `git tag -a tce--v1.5.1 <sha>` on the version-bump commit, as
TP-0045c did.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .`, `claude plugin validate ./plugins/tce`, `./plugins/tmt`, `./plugins/tle` and `./plugins/tsf` pass
- [x] `grep -n '"version": "1.5.1"' plugins/tce/.claude-plugin/plugin.json .claude-plugin/marketplace.json` returns two lines
- [x] `git tag --list 'tce--v*'` shows `tce--v1.5.1`

#### Manual Verification:

None.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `4e88a20` chore(TP-0045e): release tce 1.5.1
- **Did**: `plugins/tce/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`: tce `1.5.0` → `1.5.1`; tag `tce--v1.5.1` on `4e88a20`.
- **Issues**: `claude plugin tag` could not sign (sandbox lacks the signing key) → unsigned annotated `git tag -a tce--v1.5.1 4e88a20`, per the plan's fallback. Corrected 2026-10-28: `claude plugin tag` strips `GIT_CONFIG_GLOBAL` and reads the signing key from `~/.gitconfig` only, so it cannot sign in the nono sandbox; the human re-created `tce--v1.5.1` on `4e88a20` as a signed tag outside the sandbox (`git tag -s -f`, `git tag -v` → good signature). CLAUDE.md "Releasing" now has the agent hand the tag command to the human instead (`087dac8`).
- **Verification**: ✅ validate (marketplace + 4 plugins), ✅ version grep (2 lines), ✅ tag listed
- **Fix rounds**: 0/3

---

## Testing Strategy

### Unit Tests:

- None: the repository has no test runner. `claude plugin validate` is the
  project's test command and runs in every phase.

### Integration Tests:

- The headless reproduction matrix (Phase 1) and the four reproductions
  (Phase 5) in a scratch consuming project.

### Manual Testing Steps:

1. Interactive `/tce:list` in the scratch project with the shipped grant
   form: no permission prompt (Phase 1).
2. `/tce:quickfix make it better`: stops with "Not enough to go on" and
   writes nothing (Phase 5).

## Performance Considerations

None. The new `git status` call per implementer dispatch is negligible.

## Migration Notes

None. No project config changes, so `/tce:init` gets no Idempotency entry.

## References

- Original ticket: `thoughts/shared/tickets/TP-0045e-defects-from-stage-2-run.md`
- Intent: `thoughts/shared/intents/2026-10-27-TP-0045e-defects-from-stage-2-run.md`
- Related research: `thoughts/shared/research/2026-10-27-TP-0045e-defects-from-stage-2-run.md`
- Evidence: `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:860`, `:914`, `:924`, `:926`; `thoughts/shared/dossiers/2026-10-17-TP-0045c-single-step-commands-on-agents.md:55-59`
- Release precedent: `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:739-765`

## Verification

Baseline: `4fc230e4532c9bfe145d0fe671b635ba6c3cd83b` (recorded) · suites: ✅ `claude plugin validate .`, ✅ `./plugins/tce`, ✅ `./plugins/tmt`, ✅ `./plugins/tle`, ✅ `./plugins/tsf` (each "✔ Validation passed", exit 0; only the advisory directory LICENSE/icon notes)

Reproductions ran on Claude Code 2.1.310 against `--plugin-dir plugins/tce` in a scratch consuming project (git repo, tmt `TP` prefix, `TP-0001` ticket), built outside the repository.

- 1. Autonomous `/tce:intent` output on an insufficient description is exactly the one `insufficient:` line (or quickfix tolerates leading prose by an explicit rule) (MANUAL) — met — ran `claude -p "/tce:intent --autonomous make it better"` 3 times: every output is one line (`wc -l` = 1), e.g. `insufficient: scope — "make it better" doesn't say what should change or where…`; `git status --porcelain` empty, HEAD unchanged
- 2. The preflight refusal reaches the user as the fixed block, byte for byte (MANUAL) — met — 5 step commands run with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` unset; each 5-line output diffs empty against `plugins/tce/references/work-loop.md:100-104`
- 3. Item 3 reproduced or ruled out interactively; fix in `allowed-tools` or README note (MANUAL) — met — the grants are fixed (`plugins/tce/commands/list.md:4` etc., unquoted). Interactive `/tce:list` (`--permission-mode default`, driven by `expect`) ran `stage.sh` under the grant: the only dialog on that call offered "don't ask again for: `echo "exit=$?"`", i.e. only the model's chained `echo` needed approval. Under `-p` (item 28) the script calls were approved
- 4. Interrupted run never folds the log edit into a feature commit (MANUAL) — met — see item 29
- 5. tce version bumped and tagged — met — `plugins/tce/.claude-plugin/plugin.json:3` `"version": "1.5.1"`; `git tag --list 'tce--v*'` lists `tce--v1.5.1` → `4e88a20`
- 6. Autonomous `/tce:intent` on an insufficient description prints exactly one line (MANUAL) — met — as item 1 (3/3 single-line outputs)
- 7. `/tce:quickfix` acts on the intent's line by an explicit rule — met — `plugins/tce/commands/quickfix.md:41-58` (last prefixed line decides, artifact check, "neither" stop); ran `claude -p "/tce:quickfix make it better"` twice: each printed the `insufficient:` line, then "Not enough to go on: … Re-run `/tce:quickfix` with that added, or use `/tce:intent` for a dialogue."; tree clean
- 8. With `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` unset, every step command's refusal is the Step 0 block byte for byte (MANUAL) — met — `/tce:research`, `/tce:plan`, `/tce:implement`, `/tce:work`, `/tce:quickfix`: 5/5 empty diffs
- 9. Headless grant issue reproduced or ruled out interactively and under `-p`; corrected entries match in both (MANUAL) — met — `-p`: item 28; interactive: item 3; README note at `plugins/tce/README.md:335`
- 10. Killing a run after a phase commit leaves no log edit in the next feature commit (MANUAL) — met — see item 29
- 11. `claude plugin validate` passes for marketplace and all four plugins — met — ran all five, each exit 0
- 12. tce version bumped in both manifests and tagged — met — `plugins/tce/.claude-plugin/plugin.json:3`, `.claude-plugin/marketplace.json:15` both `1.5.1`; tag `tce--v1.5.1` on `4e88a20`
- 13. Runs A–E completed; the phase log names the branch and the denied strings — met — Phase 1 log `**Did**`: "Branch (i) … A (quoted) denied `<root>/scripts/stage.sh TP-0001` … B, C, D, E5 none denied"
- 14. No `Bash("` left; per-file grant counts unchanged — met — ran `grep -rn -F 'Bash("' plugins/tce/commands CLAUDE.md`: no output (exit 1); counts commit 1, implement 5, intent 2, list 1, plan 4, quickfix 4, research 4, review 2, work 5
- 15. README "Headless runs" note names a Claude Code version — met — `plugins/tce/README.md:335` "Verified on Claude Code 2.1.310"
- 16. validate passes (marketplace + 4 plugins) — met — as item 11
- 17. Interactive `/tce:list` with the shipped grant form: no permission prompt for `stage.sh` (MANUAL) — met — the call `"<root>/scripts/stage.sh" TP-0001; echo "exit=$?"` prompted only for its `echo` part (dialog option "don't ask again for: `echo "exit=$?"`"). `stage.sh` itself was covered by the grant, and the table rendered ("Showing 1 of 1 tickets")
- 18. `<command> needs foreground` gone — met — grep: no output (exit 1)
- 19. Both new phrases once, in Step 0 — met — `plugins/tce/references/work-loop.md:100` and `:95` (Step 0 heading at `:90`)
- 20. `claude plugin validate ./plugins/tce` passes — met — exit 0
- 21. "entire output" present, "end with exactly one" gone — met — `plugins/tce/commands/intent.md:398`; second grep exit 1
- 22. `last** line` and `work.sh" artifact` in section "2. Intent" — met — `plugins/tce/commands/quickfix.md:41`, `:48` (section spans `:37-58`)
- 23. `claude plugin validate ./plugins/tce` passes — met — exit 0
- 24. Phase-mode step 0 and fix-mode reference present — met — `plugins/tce/agents/implementer.md:89`, `:164`
- 25. `claude plugin validate ./plugins/tce` passes — met — exit 0
- 26. Defect 1 reproduction: one `insufficient:` line, clean tree — met — as item 1
- 27. Defect 2 reproduction: five empty diffs — met — as item 8
- 28. Defect 3 reproduction matches branch (i): no `permission_denials` for the scripts — met — `claude -p --permission-mode manual --output-format json "/tce:list"`: the table rendered and the only denial was the model's own `for f in …` loop; stream run: `"<root>/scripts/stage.sh" TP-0001` approved. `/tce:plan TP-0001`: `work.sh preflight`, `ticket.sh`, `stage.sh` approved (`foreground: ok`); denials only for `ls` / `echo` chained by the model
- 29. Defect 4 reproduction — met — fixture with phase 1 committed (`faf3c2d`, log `✅ Complete`) and its `**Commit**` hash edit left uncommitted; `claude -p "/tce:implement TP-0001"`: `git log` shows `5c5bb95 docs(TP-0001): record the interrupted phase's log` (plan only, 1 line) before `f60b1df feat(TP-0001): add b.txt`, whose plan diff touches only phase 2's section; `git status --porcelain` empty at the end
- 30. validate passes after this phase's fixes — met — as item 11
- 31. `/tce:quickfix make it better` stops with "Not enough to go on: …" and writes nothing (MANUAL) — met — as item 7 (2/2 headless runs, HEAD unchanged, tree clean)
- 32. validate passes (marketplace + 4 plugins) — met — as item 11
- 33. `"version": "1.5.1"` in both manifests — met — grep returns `plugin.json:3` and `marketplace.json:15`
- 34. `tce--v1.5.1` listed — met — `git tag --list 'tce--v*'` includes it

For you to check:
- None.

## Implementation Closeout

- **Plan-compliance gate**: Suites green (validate: marketplace + 4 plugins); gate settled 34/34 criteria met, 0 not met, all manual items verified by runs.
- **Manual verification**: verified by agent
- **Merge reference**: direct: main @ 44f7854
- **Ticket**: TP-0045e → Done
