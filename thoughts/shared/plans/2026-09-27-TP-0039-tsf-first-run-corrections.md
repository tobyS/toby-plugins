# TP-0039: tsf first-run corrections Implementation Plan

## Overview

Six independent corrections agreed from the analysis of the first successful
tsf run (chat-sustainability GH-40, factory session `8867f1a0`, 2026-09-26).
None blocked the run; each recurs on every ticket. After them: an invalid
worker return is rare rather than a coin flip, gate evidence points at lines a
human can open, the factory's links on a closed issue still resolve, the first
scan of a session succeeds, a green CI result on the head is not followed by a
redundant local suite run, and the docs state the permission mode the factory
requires.

## Current State Analysis

Full evidence is in
`thoughts/shared/research/2026-09-27-TP-0039-tsf-first-run-corrections.md`. In
short:

- The three fence names and the field order exist in exactly one file,
  `references/templates/result-block.md:28-50`; no worker's `## Return`
  restates them (`triage.md:87-103` and the seven siblings).
- The citation rule that produced patch offsets is
  `agents/plan-compliance.md:51` and its twin `references/templates/report.md:125`;
  `agents/integration.md` has no citation rule at all.
- `scripts/gh-write.sh:308-309` builds every artifact URL from `$BRANCH`, the
  only ref `marker` accepts (`:233`); the merge cycle deletes that branch
  (`cycle-dispatch.md:437-439`) and writes no marker (`cycle-write-phase.md:193`).
- `commands/cycle.md:77` shows `--branch-pattern <pattern>` unquoted; the
  value must literally contain `<n>` (`scan.sh:137`).
- `references/cycle-dispatch.md:188-192` runs the project's suite
  unconditionally in verification mode `local`, without consulting `ci:` or
  `pr_head:` — both already established facts at `cycle-dispatch.md:42-45`.
- `dangerously-skip-permissions`, `bypassPermissions` and `permissionMode`
  appear zero times in `plugins/tsf/`; `TODO.md:84-114` holds the deferral.

### Key Discoveries:

- **The squash commit carries the artifacts.** `0966ec4` in
  chat-sustainability contains all nine `thoughts/factory/GH-40/` files, so
  `blob/<merge_sha>/thoughts/factory/GH-<n>/…` resolves. A branch commit's sha
  would not: after a squash merge those commits are unreachable and GitHub
  publishes no retention guarantee for them.
- **`merge_sha` is already in scope.** `gh-write.sh:539-543` prints
  `merge_sha:` on `result: merged`, and row 12 step 4 already writes the live
  pull request to `.tsf-tmp/pr.md` — so both the sha and the live body text
  are in hand at the exact point the post-merge writes run. No new read.
- **`ci: success` already implies `checks ≥ 1`.** `scan.sh:216-222` emits
  `pending`, not `success`, when zero required runs match, and a project
  without CI yields the distinct `no-ci`. C5 needs no `checks:` condition; one
  would be dead code implying the opposite.
- **Row 6's green branch does more than exit.** It runs `plan.sh criteria` and
  dispatches `tsf:manual-verify` (`cycle-dispatch.md:198-210`); row 8 re-runs
  the extraction only "if this cycle has not already". The C5 skip must land
  **on** the green branch, not past it.
- **The diff carries hunk headers.** `diff.sh:197` runs a plain
  `git diff "$BASE_REF...HEAD"` with no `--no-prefix` and no `-U` override, so
  post-change line numbers are computable without opening a file — and the
  gates may open the file anyway (`plan-compliance.md:32-35` and siblings).
- **Deny rules survive bypass, allow rules do not** ("Deny rules block in
  every mode, including `bypassPermissions`"; "Allow rules have no effect in
  `bypassPermissions`"). And a project's `.claude/settings.json` **cannot**
  set `defaultMode: "bypassPermissions"` — which is exactly why C6 is
  documentation and not a config change.
- **`result-block.md:7-12` already names every `## Return` as its span**, so
  C1 extends an existing same-commit rule rather than creating one.
- **DESIGN.md §5.3's allowlist parenthetical is already wrong** (`:437` says
  the allowlist covers `gh api …` and `git` incl. push; `init.md:368` says
  "**Never** `git push` and never `gh`"). C6 corrects it in passing.

## Desired End State

- Every worker agent's `## Return` shows the three-fence skeleton filled in
  with that step's own legal values, and still reads `result-block.md` for the
  outcome table and parsing rules.
- All **four** gate agents and `report.md` require post-change source line
  numbers and forbid the patch file's own offsets.
- `gh-write.sh marker` and `pr-edit` accept `--ref`; the merge cycle re-points
  the issue's marker block and the pull request body at the merge commit, so
  every factory link on a landed ticket resolves.
- `cycle.md` Step 2 quotes the branch pattern.
- A `tsf:verify` pickup whose scan reported `ci: success` on the branch's
  current head continues without invoking the project's `verify`.
- The README, `/tsf:init`'s clone checklist and DESIGN.md §5.3 state the
  permission-mode requirement and the dispatcher's own dependence on it; the
  TODO entry is gone.
- `claude plugin validate ./plugins/tsf` passes; tsf is released as `1.2.0`
  and tagged.

## What We're NOT Doing

- The `claude -p` runner, the script-side pick and the closing-report contract
  — TP-0038.
- Parallel factories — `plugins/tsf/TODO.md`.
- Rewriting the **per-step comments'** branch links after landing. They are
  history and the marker block sits above them.
- The implement agent's `rm -rf .tsf-tmp`.
- Making the local-verify skip depend on anything but same-head equality — no
  comparison of what CI ran against `verify`.
- Adding a preflight check for the permission mode: Claude Code exposes it to
  a script in no documented way.
- Widening `/tsf:init`'s allowlist append, or making it write `permissions.deny`.
  C6 is documentation for the human; the append stays exactly as it is.

## Implementation Approach

Seven phases, each a coherent same-commit span, ordered cheapest and most
isolated first so the plugin is self-consistent after every one:

1. **C4 first** — a one-line quoting fix with no dependents.
2. **C2 then C1** — both edit the agent corpus but disjoint files (C2 the four
   gates + `report.md`, C1 the eight workers + `result-block.md`), so they do
   not collide and each is verifiable on its own.
3. **C5 before C3** — C5 touches `cycle-dispatch.md` rows 6–7 and `cycle.md`
   Step 4's cross-reference; C3 touches row 12 and `cycle.md`'s frontmatter
   neighbourhood. Doing the smaller one first keeps C3's larger diff clean.
4. **C3** — the only script-flag change, so it lands with every caller in one
   commit (the dispatcher-owns-writes rule).
5. **C6** — documentation only, and the one phase that closes a TODO entry.
6. **Governance and release last**, as in TP-0037 and TP-0036.

There is no test suite; verification is `claude plugin validate`, `bash -n`,
targeted greps, and fake-`gh` fixtures in the scratchpad. Manual criteria are
reserved for what needs a live factory run.

---

## Phase 1: C4 — quote the branch pattern

### Overview

`cycle.md:77` is the only command line in the plugin that hands a literal
`<n>` to a shell. Quote it, and say why in one line so it is not "tidied" back.

### Changes Required:

#### 1. The Step 2 invocation

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: in the fenced command at line 77, change
`--branch-pattern <pattern>` to `--branch-pattern "<pattern>"`.

#### 2. The reason

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: in the paragraph at lines 80–84, add one sentence after the
`--required-check` sentence:

```markdown
**Quote the branch pattern too**: its value contains `<n>` literally, which an
unquoted shell reads as a redirection.
```

### Success Criteria:

#### Automated Verification:

- [x] `grep -n 'branch-pattern "' plugins/tsf/commands/cycle.md` finds the quoted form
- [x] `grep -n 'branch-pattern <' plugins/tsf/commands/cycle.md` finds nothing
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] A shell check reproduces the defect and the fix: in `zsh -c`, the
      unquoted form fails with `no such file or directory: n` and the quoted
      form passes `gh-<n>` through intact

#### Manual Verification:

- [ ] The first scan of a fresh factory session succeeds without a retry

### Implementation log

**Status**: ✅ Complete
**Base commit**: `ba30564`
**Commit**: (this phase)
**Did**: `cycle.md:77` now passes `--branch-pattern "<pattern>"`; the paragraph
below it gained the one-line reason.
**Issues**: the defect reproduces as a zsh **parse error near `>`** rather than
the run's `no such file or directory: n` — the run's shell had the pattern
substituted (`gh-<n>` with a real `n` glob target), this check used the literal
placeholder. Same cause, different message; the criterion is met in substance.
**Verification**: both greps as specified; `zsh -c` with and without quotes;
`claude plugin validate ./plugins/tsf` passed.

---

## Phase 2: C2 — gates cite post-change source lines

### Overview

The rule "cite `path:line` in the diff" invites the patch file's own offsets,
and the first run produced two. State one rule, in the same words, in all four
gate agents and the report template. Scope includes `integration.md`, which
has no citation rule today yet writes into the same Evidence column.

### Changes Required:

#### 1. The shared rule

Use this wording verbatim wherever the rule is stated, so the copies can be
diffed:

```markdown
**Line numbers are the post-change source's, never the patch file's.** The
diff reaches you as a *file*, so a position inside it means nothing to a
reader. Get the real number by reading the file at head, or by computing it
from the hunk header (`@@ -old,+new @@` — count forward from the `+` side).
Before citing, sanity-check it against the file's length.
```

#### 2. plan-compliance

**File**: `plugins/tsf/agents/plan-compliance.md`
**Changes**: replace the "in the diff or the post-change source" clause at
`:51-52` with "cite `path:line` in the post-change source."; add the shared
rule as a paragraph under `## Verdicts` after the tie-break at `:59-60`; extend
`## Process` step 4 (`:69`) to name where the number comes from; add to
`## What NOT to Do`: "Don't cite line numbers from the diff file — they are
positions in a patch, not in the code".

#### 3. spec-coverage

**File**: `plugins/tsf/agents/spec-coverage.md`
**Changes**: same shared rule after the tie-break at `:66-67`; same
`## What NOT to Do` bullet. Its `:59` bullet already says only
"cite `path:line`" and needs no change beyond the added rule.

#### 4. security

**File**: `plugins/tsf/agents/security.md`
**Changes**: same shared rule as a paragraph after `## Classification`'s
tie-break at `:60-62`; same `## What NOT to Do` bullet. `:32` and `:70` keep
their `file:line` wording.

#### 5. integration

**File**: `plugins/tsf/agents/integration.md`
**Changes**: it has no citation rule — add one. A `## Verdicts` addition
stating that an interaction's evidence is `path:line` in each side, plus the
shared rule, plus the `## What NOT to Do` bullet.

#### 6. The report template

**File**: `plugins/tsf/references/templates/report.md`
**Changes**: at `:125-126`, drop "in the diff or" so the bullet reads "cite
`path:line` in the post-change source"; add the shared rule as a short
`# Evidence` section after the skeletons (there is no Evidence section today —
"Evidence" is only a table column), so the template states it once for all
four gates; extend the header comment's same-commit list (`:8-12`) to name all
four agents, which it already does, and the new section.

### Success Criteria:

#### Automated Verification:

- [x] `grep -rn "in the diff or the post-change source" plugins/tsf` finds nothing
- [x] All four gate agents and `report.md` contain the shared rule's first
      sentence, byte-identically (extract and diff)
- [x] `grep -c "Don't cite line numbers from the diff file" plugins/tsf/agents/*.md`
      reports the bullet in all four gate agents
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] Read all four gate files end to end: no instruction anywhere still
      licenses a diff-relative number

#### Manual Verification:

- [ ] A gate run on a scratch ticket cites lines that exist in the files at
      head (spot-check each cited `path:line` against the file's length)

### Implementation log

**Status**: ✅ Complete
**Base commit**: `ba30564`
**Commit**: (this phase)
**Did**: the five-line rule added verbatim to all four gate agents and to a new
`# Evidence` section in `report.md`; the "in the diff or" clause dropped from
`plan-compliance.md:51` and `report.md:125`; a `## What NOT to Do` bullet in
each of the four; `plan-compliance`'s Process step 4 points at the rule;
`integration.md` gained the per-side `path:line` sentence it never had; the
template's header comment names the duplication and gains a Contents entry.
**Issues**: the rule block is duplicated five times by design (cross-plugin
reference files cannot be shared and the rule governs a whole agent body, not
one moment of use) — the same trade-off as the AskUserQuestion block. Verified
byte-identical by checksum rather than by eye, and the header comment now says
so, but nothing enforces it mechanically.
**Verification**: five extracted rule blocks hash to one value; both greps;
every remaining `path:line`/`file:line` mention re-read (8 sites, none
licensing a patch offset); `claude plugin validate ./plugins/tsf` passed.

---

## Phase 3: C1 — every worker carries the result skeleton

### Overview

Inline the three-fence skeleton in each worker's `## Return`, filled in with
that step's own legal values, so an agent that skipped the Read still has the
format. The Read stays: the outcome table, the parsing rules and the
`question-comment.md` guidance are not duplicated.

### Changes Required:

#### 1. The skeleton's shape

Each agent gets, immediately after its existing Read sentence, a
four-backtick-wrapped block showing the three fences (four for verify-fix and
manual-verify) with **that step's** values. Field order follows
`result-block.md:29-36` exactly — `step:`, `outcome:`, `next-step:`,
`next-label:`, `commits:`, the step's extra field, `summary:` — and the
journal's follows `:45-49`. Example, for `triage`:

````markdown
```tsf-result
step: triage
outcome: continued | parked | blocked
next-step: research | triage
next-label: tsf:research | tsf:needs-answer | tsf:needs-human
commits: <short sha> | none
summary: <one line for the cycle's closing report>
```

```tsf-comment
<the outcome comment, the question comment, or what is wrong and what would fix it>
```

```tsf-journal
- Outcome: <one line>
- Questions asked: none (gate skipped: nothing to ask) | <k> (parked)
- Commits: <short sha> | none
- Label: <same as next-label>
- Next step: <same as next-step>
```
````

Followed by the existing per-branch bullets, unchanged — they are what pairs
the values up.

#### 2. The eight workers

**Files**: `plugins/tsf/agents/{triage,research,plan,implement,verify-fix,manual-verify,dossier,merge-resolver}.md`
**Changes**: add the skeleton to each `## Return`, with these per-step values
(from the table at `result-block.md:85-107`):

| agent | `next-step` values | `next-label` values | extra |
|---|---|---|---|
| triage | `research \| triage` | `tsf:research \| tsf:needs-answer \| tsf:needs-human` | — |
| research | `plan \| research` | `tsf:plan \| tsf:needs-answer \| tsf:needs-human` | — |
| plan | `implement \| plan` | `tsf:implement \| tsf:needs-plan-approval \| tsf:needs-human` | — |
| implement | `verify \| implement \| review` | `tsf:verify \| tsf:implement \| tsf:needs-answer \| tsf:needs-human` | `- Increments:` line, fresh mode |
| verify-fix | `verify` | `tsf:verify \| tsf:needs-human` | `tsf-report` fence |
| manual-verify | `gates \| verify` | `tsf:verify \| tsf:needs-human` | `manual:`, `tsf-report` fence |
| dossier | `review \| dossier` | `tsf:needs-review \| tsf:needs-human` | `pr-fix:` |
| merge-resolver | `landing` | `tsf:landing \| tsf:needs-human` | — |

`verify-fix` and `manual-verify` show the `tsf-report` fence as the fourth
block in their skeleton; both already explain it in prose and that prose stays.
`implement`'s skeleton shows the `- Increments:` line in the journal fence with
its existing "fresh mode only" note; `implement` omits `outcome: parked`'s
fourth row nowhere — all three outcomes appear.

#### 3. The maintenance note

**File**: `plugins/tsf/references/templates/result-block.md`
**Changes**: the HTML comment at `:7-12` already names every `## Return` as
part of the span. Extend it to say **why** they must move together now — each
carries a filled-in copy of the skeleton, so a fence rename or a field
reorder is eight edits plus this file.

#### 4. The re-dispatch note

**File**: `plugins/tsf/references/templates/result-block.md`
**Changes**: parsing rule 5 (`:170-175`) appends the template's path to the
re-dispatch note, so the retry is pointed at the file rather than repeating a
bare complaint:

```
note: your previous return had no valid result block — the format is in
${CLAUDE_PLUGIN_ROOT}/references/templates/result-block.md and in your own
`## Return` section; read it and return the blocks exactly
```

### Success Criteria:

#### Automated Verification:

- [x] All eight worker agents contain a ```` ```tsf-result ```` fence,
      a ```` ```tsf-comment ```` fence and a ```` ```tsf-journal ```` fence
      (`grep -c` per file = 1 each)
- [x] `verify-fix.md` and `manual-verify.md` additionally contain a
      ```` ```tsf-report ```` fence in their skeleton
- [x] Every skeleton's `step:` value equals the agent's frontmatter `name:`
- [x] Every `next-step`/`next-label` value in every skeleton appears in that
      agent's rows of `result-block.md`'s table, and no row of the table is
      missing from its agent's skeleton (read the table against the eight)
- [x] All eight still contain the point-of-use Read of `result-block.md`
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] A dispatch of `tsf:implement` on a scratch ticket returns a valid result
      block first time, without the retry

### Implementation log

**Status**: ✅ Complete
**Base commit**: `ba30564`
**Commit**: (this phase)
**Did**: all eight `## Return` sections gained a four-backtick-wrapped skeleton
with that step's own values, followed by the existing per-branch bullets under
a "Which values go together:" lead-in. `verify-fix` and `manual-verify` show
four fences and say so; `implement` shows the `- Increments:` line with its
fresh-mode note; `dossier` shows `pr-fix:`; `merge-resolver` gained a pointer
that its classification is a commit trailer, not a result field. The template's
header comment explains why the copies exist and warns that its field order is
**not** the outcome table's column order; parsing rule 5's re-dispatch note now
names the template path and the agent's own section.
**Issues**: two agents' Read sentences said "exactly the three blocks" while
their steps require four — a pre-existing inconsistency the skeleton made
visible. Both now say four. Also confirmed that `merge-resolver`'s second
mention of the template (in Commit rules) is a bare filename, not a second
point-of-use Read, so the grep for the full path correctly returns 1 per file.
**Verification**: fence counts and `step:`-vs-`name:` equality for all eight
(scripted); every skeleton's `outcome`/`next-step`/`next-label` set compared
against the table's rows for that step, both directions — all match, no row
unrepresented; Read present in all eight; `claude plugin validate` on the
plugin and the marketplace passed; nesting spot-checked rendered.

---

## Phase 4: C5 — trust green CI on the same head

### Overview

When the scan already reported `ci: success` on a `pr_head:` equal to the
branch's HEAD after prepare, the local suite would re-run the same commit's
same suite. Skip it and continue on row 6's green branch. Every other case
runs the suite as today, and red CI still routes to `verify-fix` with
`failure: ci`.

### Changes Required:

#### 1. Row 6's opening

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: replace the opening sentence at `:188-192` with a three-way
entry — mode `ci`, the CI-green skip, and the run:

```markdown
**Row 6 — `tsf:verify`, local verification red.** Before deciding anything,
establish local verification:

- Verification mode `ci` → skip straight to row 7.
- Mode `local`, and the scan's `ci:` is `success` with its `pr_head:` equal to
  `git rev-parse HEAD` after prepare → **green, without running it**: it is
  the same commit and the same suite, because the config declares `verify` is
  what CI runs. Continue with the manual items below. Say so in the journal
  entry's outcome, naming the head, so the evidence is on the record.
- Otherwise → run the project's `verify` script **with the Bash tool's maximum
  timeout**, and keep its output in a file under `.tsf-tmp/` — a failing
  command returns only a truncated excerpt and no file path, so the redirect
  is what makes the output readable at all.
```

The equality is against HEAD **after** prepare, not against the scan alone:
the scan runs at Step 2 and prepare at Step 4, so a push in between must send
the ticket down the run branch. No `checks:` condition is added — `ci: success`
already implies at least one required run (`scan.sh:216-222`).

#### 2. Row 6's branches

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: the existing **red** and **green** bullets (`:194-212`) stay
exactly as they are; the skip enters at **green**. Make that explicit in the
green bullet's first words ("**green** — whether run or taken from CI — → the
**manual items**") so the `plan.sh criteria` extraction and the
`tsf:manual-verify` dispatch are unmistakably still in play.

#### 3. Row 7

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: row 7's heading (`:214`) reads "local green (or mode `ci`)" —
extend to "(or mode `ci`, or CI-green on the same head)". Its `success → row 8`
branch is unchanged and is what the skip path lands on.

#### 4. The timeout cross-reference

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: at `:175-179`, "and the same wherever you run the project's
`verify` (Step 5's row 6)" becomes "… (Step 5's row 6, when it runs it)".

#### 5. The design

**File**: `plugins/tsf/DESIGN.md`
**Changes**: §4 row 6 (`:302-303`) gains the skip in one clause. §7's
precondition paragraph (`:619-627`) — the sentence "The local run gives the
factory its evidence first and cheapest; CI confirms it on the real head
before any gate spends tokens" is what C5 falsifies; reword to state that
either source establishes green on the head, and that a green required check
on the very commit makes a second local run redundant.

### Success Criteria:

#### Automated Verification:

- [x] `grep -n "pr_head" plugins/tsf/references/cycle-dispatch.md` shows row 6
      consuming it
- [x] `grep -n "first and cheapest" plugins/tsf/DESIGN.md` finds nothing
- [x] `grep -n "checks:" plugins/tsf/references/cycle-dispatch.md` shows no new
      condition in row 6
- [x] Read row 6 end to end: the green branch still runs `plan.sh criteria`
      and still dispatches `tsf:manual-verify` on both paths
- [x] Read row 7: `failure` still routes to `tsf:verify-fix` with `failure: ci`,
      and `no-ci` is untouched
- [x] `claude plugin validate ./plugins/tsf` passes

#### Manual Verification:

- [ ] A `tsf:verify` cycle picked up with green CI on its head dispatches the
      gates without invoking `verify`, visible in the transcript
- [ ] A `tsf:verify` cycle whose head moved since the scan does run the suite

### Implementation log

**Status**: ✅ Complete
**Base commit**: `ba30564`
**Commit**: (this phase)
**Did**: row 6 restructured into a three-way "establish local verification"
(mode `ci` → row 7; CI-green on the same head → green without running; else
run), with the red/green branches unchanged below it and "whether run or taken
from CI" on the green one. Row 7's heading names the third path. `cycle.md`'s
timeout cross-reference says "when it runs it". DESIGN.md §4 row 6 gains the
skip clause and §7's "first and cheapest" sentence is replaced with one that
prefers whichever evidence is already in hand.
**Issues**: the skip had to land **on** row 6's green branch, not jump to row
7 — the green branch is also where `plan.sh criteria` runs and where
`tsf:manual-verify` is dispatched, and row 8 re-runs the extraction only "if
this cycle has not already". Jumping past it would have silently dropped the
manual items. Checked the three combinations that must still run the suite:
`no-ci`, a `pr_head:` that moved since the scan, and mode `ci` (which skips
for its own pre-existing reason).
**Verification**: both greps; row 6 and row 7 re-read end to end; the `no-ci`
and `failure: ci` branches confirmed byte-unchanged; `claude plugin validate
./plugins/tsf` passed.

---

## Phase 5: C3 — the factory's links survive the landing

### Overview

`marker` and `pr-edit` gain `--ref`, and the merge cycle re-points the issue's
marker block and the pull request's body at the merge commit. This is the only
phase that changes a script's flags, so it lands with every caller.

### Changes Required:

#### 1. `marker --ref`

**File**: `plugins/tsf/scripts/gh-write.sh`
**Changes**: parse `--ref SHA` (add `REF=""` to the declarations at `:184-186`
and a `--ref)` case at `:200`). In the `marker` body at `:306-311`, use the ref
where one was given:

```sh
marker)
    BASE_URL="https://github.com/$REPO"
    LINK_REF="${REF:-$BRANCH}"
    LINKS="[spec]($BASE_URL/blob/$LINK_REF/thoughts/factory/$TICKET/spec.md) · [branch]($BASE_URL/tree/$LINK_REF)"
    [ "$JOURNAL" = "0" ] || LINKS="$LINKS · [journal]($BASE_URL/blob/$LINK_REF/thoughts/factory/$TICKET/journal.md)"
    [ -z "$PR" ] || LINKS="$LINKS · [PR]($BASE_URL/pull/$PR)"
```

`--branch` stays mandatory (it is the default and names the ticket); absent
`--ref`, the output is byte-identical to today. The split-and-replace, the
read-back and the `result: ok | mismatch` contract are untouched.

#### 2. `pr-edit --branch --ref`

**File**: `plugins/tsf/scripts/gh-write.sh`
**Changes**: `pr-edit` gains an optional `--branch B --ref SHA` pair. When both
are given and the field being sent includes the body, rewrite the body file's
ref-bearing links before the PATCH — a mechanical substitution of
`/blob/<B>/` → `/blob/<SHA>/` and `/tree/<B>` → `/tree/<SHA>`, nothing else:

```sh
# Re-point branch-keyed links at a commit. Mechanical: only the ref segment of
# a blob/tree URL for THIS repository changes, so the script never composes
# pull-request text (cycle.md invariant 3).
if [ -n "$REF" ] && [ -n "$BRANCH" ] && [ -f "$BODY_FILE" ]; then
    sed -e "s|/blob/$BRANCH/|/blob/$REF/|g" -e "s|/tree/$BRANCH|/tree/$REF|g" \
        "$BODY_FILE" >"$TSF_TMP/pr-body-ref" && mv "$TSF_TMP/pr-body-ref" "$BODY_FILE"
fi
```

Validation: `--ref` without `--branch` (or with `--field title`) is a usage
error. The read-back comparison at `:442-451` then compares the **rewritten**
text, which is what was sent — so `mismatch` keeps its meaning.

Take the body from `.tsf-tmp/pr.md`, the **live** pull request that row 12
step 4 already fetched, not from the committed `pr-body.md`: it preserves any
human edit, and it is already on disk.

#### 3. The script's documentation

**File**: `plugins/tsf/scripts/gh-write.sh`
**Changes**: extend the header block's `marker` entry (`:28-33`) and `pr-edit`
entry (`:60-70`) with `--ref`, stating what it is for — a branch that is about
to be deleted takes its links with it, and after a squash merge the branch's
own commits are unreachable, so the merge commit is the only durable ref.
Extend the two `usage()` lines (`:168`, `:173`).

#### 4. The merge cycle

**File**: `plugins/tsf/references/cycle-dispatch.md`
**Changes**: row 12's step 5 (`:434-448`) gains the two rewrites **between**
the label clear and the branch deletion, so the branch still exists if one
fails:

```markdown
5. **After the merge — GitHub writes only** (§3.2, §9.4), a second apart:
   a. `gh-write.sh labels … --issue <n> --clear`
   b. `gh-write.sh marker … --issue <n> --ticket GH-<n> --branch <branch>
      --journal --pr <n> --ref <merge_sha>` — the block's links move to the
      merge commit, which is on the base branch and outlives the branch.
   c. `gh-write.sh pr-edit … --pr <n> --pr-file .tsf-tmp/pr.md --field body
      --branch <branch> --ref <merge_sha>` — the same for the pull request
      body's Artifacts links, from the live text step 4 already fetched. You
      do not open it.
   d. `gh-read.sh branch --branch <branch>`: `exists: no` → done.
      `exists: yes` → `gh-write.sh ref-delete --branch <branch>`.
```

`<merge_sha>` is step 4's `merge_sha:` line. A failure in any of a–d is
**reported, never parked**, exactly as today.

#### 5. The write phase

**File**: `plugins/tsf/references/cycle-write-phase.md`
**Changes**: the merge-cycle section (`:190-199`) says "no marker call". It
must now distinguish the repository (still nothing) from GitHub: the merge
cycle makes four GitHub writes, two of which re-point links, and still writes
nothing to the branch. Keep the "must not" reasoning intact.

#### 6. The closing report

**File**: `plugins/tsf/references/cycle-report.md`
**Changes**: the merge-cycle Writes line (`:49-51`) becomes
`merge <short sha> · label cleared · links re-pointed · branch deleted`.

#### 7. The pull-request template

**File**: `plugins/tsf/references/templates/pr-body.md`
**Changes**: the Artifacts links (`:74-77`) stay branch-keyed — at write time
the branch is all there is. Add one line under `# Rules` saying the landing
re-points them at the merge commit, so a reader does not "fix" them to a sha
the agent cannot know. Its header comment (`:10-17`) already names
`gh-write.sh`, `gh-read.sh` and `cycle-write-phase.md` as the span.

#### 8. The other two callers

**Files**: `plugins/tsf/commands/spec.md`, `plugins/tsf/commands/init.md`
**Changes**: `/tsf:spec`'s marker call (`spec.md:107-110`) passes no `--ref`
and needs none — confirm and leave it. `init.md` has no `marker` call (its
"marker" hits are the config version marker). Both are named by the
dispatcher-owns-writes rule, so both are read and, where the flag list is
described, updated; if neither needs a change, record that in the phase log
rather than silently skipping them.

#### 9. `cycle.md`

**File**: `plugins/tsf/commands/cycle.md`
**Changes**: `allowed-tools` already grants `gh-write.sh` by prefix, so no
frontmatter change. Confirm Step 5's "a write-free merge" description
(`:201-202`) and Important Rule 4 (`:284-287`) still read correctly — they
speak of repository writes and remain true; adjust only if their wording
implies GitHub silence.

### Success Criteria:

#### Automated Verification:

- [x] `bash -n plugins/tsf/scripts/gh-write.sh` passes
- [x] Fake-`gh` smoke test: `marker` without `--ref` produces byte-identical
      output to the pre-change script for the same arguments
- [x] Fake-`gh` smoke test: `marker --ref <sha>` sends a body whose spec,
      journal and branch links carry `<sha>` and whose `[PR]` link is unchanged
- [x] Fake-`gh` smoke test: `pr-edit --field body --branch b --ref <sha>`
      sends a body with `/blob/b/` and `/tree/b` rewritten and everything else
      byte-identical; `--ref` without `--branch` and `--ref` with
      `--field title` exit 1
- [x] `grep -rn "no marker call" plugins/tsf` finds nothing stale
- [x] `grep -n "links re-pointed" plugins/tsf/references/cycle-report.md` matches
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] Read row 12 step 5 and the write-phase merge section together: the merge
      cycle still writes nothing to the repository

#### Manual Verification:

- [ ] After a scratch landing, every link in the issue's marker block resolves
- [ ] After the same landing, every link in the pull request body's Artifacts
      section resolves
- [ ] The squash commit's message is unaffected by the post-merge body edit

### Implementation log

**Status**: ✅ Complete
**Base commit**: `ba30564`
**Commit**: (this phase)
**Did**: `gh-write.sh` gained `--ref` on `marker` (pins the spec, journal and
branch links to a commit; defaults to `--branch`) and on `pr-edit` (rewrites
`/blob/<branch>/` and `/tree/<branch>` in the body before the PATCH, requiring
`--branch` and a body-carrying field). Row 12 step 5 gained calls b and c
before the branch deletion, with the reason for that order; its failure
sentence now covers all four. The write-phase merge section distinguishes
repository writes (still none) from GitHub writes (now five), and names this
as the one marker call that is not step 4 of the sequence. `cycle-report.md`'s
merge-cycle Writes line gained `links re-pointed`. `pr-body.md` tells the
agent its branch links are correct and the landing re-points them.
**Issues**: three judgment calls worth recording. (1) `pr-edit` takes the body
from `.tsf-tmp/pr.md` — the **live** pull request that step 4 already fetched —
not from the committed `pr-body.md`, so a human's edit of the body survives and
no new read is added. (2) The rewrite is a `sed` on the ref segment only; that
is mechanical re-pointing, not composing text, so invariant 3 holds — but it is
the first time a script touches artifact text at all, and the comment in the
script says why that line is where it stops. (3) `spec.md`'s marker call and
`init.md` were read as the dispatcher-owns-writes rule requires: neither needs
a change (spec has no ref to pin at branch-creation time; init has no marker
call — its "marker" hits are the config version marker). `cycle.md`'s Step 5
and Important Rule 4 both speak of *repository* writes and remain true as
written.
**Verification**: `bash -n`; a fake `gh` on `PATH` recording each request —
`marker` with and without `--ref`, `pr-edit` with and without, both diffed
byte-for-byte against the pre-change script checked out from `c83682a` (both
identical without the flag); the two usage-error cases exit 1; `claude plugin
validate ./plugins/tsf` passed.

---

## Phase 6: C6 — the permission mode is written down

### Overview

State the requirement the factory has always had: the session runs with
`--dangerously-skip-permissions` inside a sandbox or cage, the dispatcher
itself depends on it, and `permissions.deny` is the recommended guardrail
because deny survives that mode. Close the TODO entry.

### Changes Required:

#### 1. The README

**File**: `plugins/tsf/README.md`
**Changes**: in `## /tsf:cycle and /loop /tsf:cycle` (`:82-125`), the shell
block's bare `claude` (`:90`) becomes
`claude --dangerously-skip-permissions   # inside a sandbox or container`, and
a paragraph joins the two env-var justifications (`:111-125`) stating:

- the factory is unattended, so any prompt hangs the cycle forever;
- it is **not only the workers**: the dispatcher itself writes the journal, the
  gate reports and the comment bodies, and runs the project's contract scripts
  and `verify` with a shell redirect — none of which `/tsf:cycle`'s
  `allowed-tools` or `/tsf:init`'s allowlist covers;
- therefore a sandbox or container is the boundary, not the permission prompt;
- recommended `permissions.deny` entries, because **deny rules apply in every
  mode including `bypassPermissions` while allow rules do not**:

```json
{
  "permissions": {
    "deny": ["Bash(git push:*)", "Bash(gh:*)"]
  }
}
```

  with the honest caveat that a deny rule matches the command line an agent
  normally writes and is a guardrail against drift, not a security boundary
  (`git -C . push` slips past it) — its point is to make DESIGN.md §11.3's
  "no agent pushes or calls GitHub" enforced rather than merely intended, while
  `push.sh` and `gh-write.sh` keep working because deny does not reach a
  script's child processes;
- one line noting `--permission-mode auto` as a lower-risk alternative whose
  background safety checks can still interrupt an unattended loop — bypass is
  what the factory has been run with.

Also worth one sentence, since both bite on first use: bypass refuses to start
as root or under `sudo` outside a recognized sandbox, and the first interactive
session shows a one-time acceptance dialog.

#### 2. The clone checklist

**File**: `plugins/tsf/commands/init.md`
**Changes**: the factory-checkout checklist (`:441-450`) gains two items before
the last one:

```
   [ ] The factory session is started with --dangerously-skip-permissions,
       inside a sandbox or container — the dispatcher and its agents both
       need it, and an unattended cycle cannot answer a prompt
   [ ] Optional guardrail: permissions.deny for "Bash(git push:*)" and
       "Bash(gh:*)" — deny still applies in that mode; the plugin's own
       scripts are unaffected
```

and the last item becomes "Start claude in the clone **with that flag**, run
/tsf:cycle once, then /loop /tsf:cycle". The allowlist step (`:352-393`) is
**not** touched.

#### 3. The design

**File**: `plugins/tsf/DESIGN.md`
**Changes**: §5.3's last paragraph (`:433-441`) names the flag, states the
dispatcher's own dependence, and **corrects the wrong parenthetical** at
`:437`: the allowlist covers the registered contract scripts, local git, the
profile's commands and `Read(~/.claude/plugins/**)` — never `git push`, never
`gh`. Add that allow rules are inert under bypass while deny rules are not, so
the allowlist matters for any non-bypass posture and the deny rules are the
containment inside it.

#### 4. The TODO entry

**File**: `plugins/tsf/TODO.md`
**Changes**: delete "Document and check the factory session's permission mode"
(`:84-114`) in full. The preflight check it wished for stays impossible and
that is now recorded in the README paragraph instead.

### Success Criteria:

#### Automated Verification:

- [x] `grep -rn "dangerously-skip-permissions" plugins/tsf` matches in
      `README.md`, `commands/init.md` and `DESIGN.md`
- [x] `grep -n "Document and check the factory session" plugins/tsf/TODO.md`
      finds nothing
- [x] `grep -n "gh api" plugins/tsf/DESIGN.md` no longer shows §5.3 claiming
      the allowlist grants it
- [x] `git diff plugins/tsf/commands/init.md` touches the checklist only —
      the allowlist step is byte-identical
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] Read the three passages: README, checklist and §5.3 agree on the flag,
      the sandbox, the dispatcher's dependence and the deny recommendation

#### Manual Verification:

- [ ] A reader following only the README can start a factory session that does
      not stop on a prompt

### Implementation log

**Status**: ✅ Complete
**Base commit**: `ba30564`
**Commit**: (this phase)
**Did**: the README's run block starts `claude --dangerously-skip-permissions`
and a new subsection explains why the sandbox is the boundary, lists the
dispatcher's own ungranted work, gives the `permissions.deny` snippet with its
honest reach, and notes `auto` in one line. `/tsf:init`'s clone checklist makes
the sandbox unconditional, adds the deny guardrail and puts the flag on the
start item with its reason. DESIGN.md §5.3 names the flag, states the
dispatcher's dependence, and corrects its allowlist parenthetical. The TODO
entry is deleted (9 headings → 8).
**Issues**: two facts postdate the TODO entry and changed the wording. Allow
rules are **inert** under bypass while deny rules still apply — so the
allowlist is framed as what keeps a non-bypass posture workable, and deny as
the containment inside bypass. And a project's own `settings.json` cannot set
this mode at all, which is the reason C6 is documentation rather than
configuration; §5.3 now says so. Also recorded the two first-use gotchas
(root/sudo refusal, the one-time acceptance dialog) that would otherwise make
a correct setup look broken.
**Verification**: the flag present in all three files; the TODO entry gone with
the other eight headings intact; the stale `gh api …` parenthetical gone;
`git diff -U0` on `init.md` shows two hunks, both in the checklist — the
allowlist step at 352-393 untouched; `claude plugin validate ./plugins/tsf`
passed.

---

## Phase 7: Governance, documentation and release

### Overview

Record the rules the six corrections establish, then release tsf `1.2.0`.
`1.2.0` rather than a patch: `gh-write.sh` gains a flag, the merge cycle gains
two writes, and row 6 changes when the project's suite runs.

### Changes Required:

**File**: `/Users/toby/code/work/toby-plugins/CLAUDE.md`

- "tsf: the result block is a machine contract (TP-0034a)" — add that each
  worker's `## Return` now carries a **filled-in copy** of the three-fence
  skeleton with that step's own values, so a fence rename or field reorder is
  nine files, and that the Read stays for the table and parsing rules.
- "tsf: the gate report is a machine contract (TP-0034b)" — the rule names
  three gate agents; make it four, and add that evidence line numbers are the
  post-change source's, never the patch file's, in all four plus `report.md`.
- "tsf: the dispatcher owns every GitHub write (TP-0034a)" — add that a link
  the factory publishes must name a ref that outlives the branch: after a
  squash merge the branch's commits are unreachable, so the landing re-points
  the marker block and the pull request body at the merge commit via
  `--ref`.
- "tsf: the landing is a decision cycle plus a write-free merge cycle
  (TP-0034c)" — the merge cycle now makes four GitHub writes; "write-free"
  means the **repository**, and the rule must say so explicitly so the two are
  never conflated again.
- "tsf: the environment contract's cadence (TP-0034b)" — add C5: the project's
  `verify` is skipped when a green required check already covers the branch's
  current head, and the equality is measured after `prepare`, never against
  the scan alone.
- "tsf: `/tsf:init`'s allowlist append …" — add that the factory's permission
  mode is **documentation**, never something `/tsf:init` writes: a project
  `settings.json` cannot set `bypassPermissions`, and deny rules — which do
  survive that mode — are recommended to the human, not written by the command.

**Files**: `plugins/tsf/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Changes**: `1.1.1` → `1.2.0` in both.

**Release**: `claude plugin tag ./plugins/tsf`, then confirm with
`git tag --list 'tsf--v*'`.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [ ] `jq -r .version plugins/tsf/.claude-plugin/plugin.json` is `1.2.0` and
      the marketplace entry matches
- [ ] `git tag --list 'tsf--v1.2.0'` shows the tag
- [ ] Every CLAUDE.md rule touched names every file of its span, and each named
      file exists
- [ ] All six ticket acceptance criteria re-read against the tree

#### Manual Verification:

- [ ] The tag points at the version-bump commit

---

## Testing Strategy

No test suite exists; this is a markdown-and-bash plugin repo. Verification is:

- `claude plugin validate .` and `claude plugin validate ./plugins/tsf` after
  every phase.
- `bash -n` on `gh-write.sh` (Phase 5).
- Targeted greps for the exact strings each phase adds or removes.
- **Fake-`gh` fixtures** for Phase 5, in the scratchpad: a `gh` earlier on
  `PATH` that answers with a status line, `X-GitHub-Request-Id` headers and a
  JSON body, so `marker` and `pr-edit` can be exercised without GitHub. The
  decisive test is the **no-`--ref` byte-identity check** against the current
  script's output.
- Cross-file reads where the contract is prose: the four gate agents against
  each other (Phase 2), the eight skeletons against `result-block.md`'s table
  (Phase 3), row 6 end to end (Phase 4).

The live-run criteria (a scratch landing, a scratch `tsf:implement` dispatch, a
gate run) need a real GitHub repository and the factory identity, and are the
Manual items.

## Migration Notes

Nothing in `.claude/tsf/config.md` changes, so `/tsf:init`'s Idempotency
upgrade list needs no `1.2.0` entry. A project on `1.1.1` picks the change up
with `/plugin marketplace update toby-plugins` and needs no re-init. C6 is the
one change that asks something of an existing consumer — to start the session
with the flag — and it asks for what they were already doing.

## References

- Original ticket: `thoughts/shared/tickets/TP-0039-tsf-first-run-corrections.md`
- Research: `thoughts/shared/research/2026-09-27-TP-0039-tsf-first-run-corrections.md`
- Shape precedents: `thoughts/shared/plans/2026-09-21-TP-0037-tsf-final-review-corrections.md`,
  `thoughts/shared/plans/2026-09-20-TP-0036-tsf-review-corrections.md`
- Companion ticket: `thoughts/shared/tickets/TP-0038-*.md` (the runner)
- First run's artifacts: `/Users/toby/code/work/chat-sustainability/thoughts/factory/GH-40/`
