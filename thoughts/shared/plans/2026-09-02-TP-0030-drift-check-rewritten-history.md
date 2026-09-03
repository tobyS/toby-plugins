# Make tce's Recorded Commit SHAs Survive Squash Merges Implementation Plan

## Overview

Every commit SHA a tce thoughts document records — the research frontmatter's
`git_commit`, the plan's `**Base commit**`, the per-phase `**Commit**` lines —
is recorded on whatever branch the work happened on. When that branch is
squash- or rebase-merged and deleted, none of those commits is an ancestor of
the merged history any more, and the two consumers that diff from them
(`/tce:implement`'s repository state check and the Plan-Compliance Gate) lose
their baseline.

This plan adds a shipped resolver script that turns a recorded SHA into a
*usable* baseline — the recorded commit when it is still reachable, otherwise
the commit that introduced the document into the current history — and wires it
into `implement.md` and the composites, so both consumers keep working and both
say which baseline they used.

## Current State Analysis

- `implement.md:58` compares the research `git_commit` against HEAD and, on a
  difference, runs `git diff --stat <research_commit>..HEAD`. It defines no
  branch for a SHA that is unreachable, so the command either dies with
  `fatal: bad object` (fresh clone) or diffs against a dangling commit and
  reports the branch's own squashed-away changes as drift (originating clone).
- `implement.md:259-266` (Plan-Compliance Gate step 2) diffs from the plan's
  `**Base commit**` with the same failure. Its three-level fallback chain
  (plan log → legacy `.status.md` → `git log --grep`) keys on the base being
  *missing*, never on it being *unreachable*, so it never engages here.
- Per-phase `**Commit**` hashes (`implement.md:103`, recorded at `:220`) have no
  programmatic consumer; they simply stop resolving in a fresh clone, so the
  implementation log stops being navigable. No computation can recover them —
  only a durable reference recorded alongside can.
- `work.md:256` mirrors the gate's diff invocation verbatim; `work.md:228`
  mirrors the base-commit recording; `work.md:225` asserts the state check is
  trivially satisfied and does not re-describe it. `quickfix.md` inherits
  everything through its `tce:implement` Skill delegation (`quickfix.md:185`)
  and only surfaces the gate outcome (`:218`, `:233-242`).
- All git logic in this area is prompt prose plus `allowed-tools` prefix grants
  (`implement.md:4`); tce ships three scripts, none git-related.

### Key Discoveries:

- **`git cat-file -e <sha>^{commit}` (the ticket's prescribed probe) is an
  object-existence test, not a reachability test.** It succeeds for dangling
  commits, which survive locally for weeks after a squash merge
  (`gc.reflogExpireUnreachable` defaults to 30 days). It would pass on the
  machine that created the branch and fire only in a fresh clone or CI.
  `git merge-base --is-ancestor <sha> HEAD` is the correct test: exit 0 =
  reachable, 1 = present but not an ancestor, 128 = unknown object.
  (Research: "git semantics that determine the correct mechanism".)
- **`git log --diff-filter=A -1 -- <path>` is not reliable as written.** It
  needs `--first-parent` to attribute an add to the mainline commit uniformly
  across squash merges and true merges; path-limiting disables rename detection
  so a rename surfaces as an `A` of the new path (`--follow` fixes it, single
  path only); and it returns an **empty string with exit status 0** in a shallow
  clone, so the caller must test the output, not `$?`.
- **`plan-document-template.md` deliberately contains no `## Implementation
  Closeout` template** — `:168-176` says "Their formats are owned by
  implement.md. **A plan is always authored without them**". The file's prose
  paraphrase at `:171-173` is the only thing there that a new field may extend.
- **`plan-compliance-checker.md` never mentions the diff's baseline** and
  declares `tools: Read, Grep, Glob, LS` (no Bash), so it cannot compute a diff.
  The agent file needs no change; CLAUDE.md's four-file gate rule narrows to
  three files here.
- **`plan.md` has no analogous weakness** — `plan.md:101` is its only
  research-frontmatter read and it reads `last_updated`, a date-versus-recent-
  changes judgement, never a commit.
- **The prior design's assumption is explicit and repo-local**: TP-0020's
  research justified the base-commit design with "In this repo (single `main`,
  no branches) a commit range is straightforward". There is no prior decision to
  overturn, only that assumption to replace.
- `refs/pull/<n>/head` is GitHub-specific and GitLab's
  `refs/merge-requests/<iid>/head` **is deleted 14 days after merge**, so no
  forge-specific retrieval path may be baked into a project-agnostic command.

## Desired End State

`/tce:implement` (and `/tce:work`) work correctly on a repository that
squash-merges branches:

- The repository state check resolves a baseline through the new script, runs
  its `--stat` diff against that baseline, and states which baseline it used.
- The Plan-Compliance Gate resolves its base commit the same way and states the
  same, and defines what to do when no baseline can be resolved at all.
- No command path runs a git invocation that can fail with `fatal: bad object`
  on an unreachable recorded SHA.
- Resolvable paths behave exactly as before: a reachable recorded SHA yields
  `source: recorded` and the unchanged flow; the same-session fast path still
  short-circuits before the script is called.
- The closeout records a generic, forge-neutral merge reference so the phase
  commit hashes stay retrievable after a branch is deleted.

Verify with: `claude plugin validate` on the marketplace and all three plugins;
`bash -n` on the new script; and the scratch-repo reproduction in Phase 1.

## What We're NOT Doing

- Not prescribing or changing any project's merge strategy.
- Not re-running research automatically, and not rewriting recorded SHAs in
  existing thoughts documents after a merge.
- Not changing `/tce:review`'s frontmatter SHA — research confirmed it records
  provenance and has no consumer (`review.md:276,291,304`).
- Not changing `plan.md` — research confirmed no analogous weakness.
- Not changing `plan-compliance-checker.md` — it never sees or computes the
  baseline.
- Not adding a `## Implementation Closeout` template to
  `plan-document-template.md` — that would invert the ownership boundary the
  file states twice. Its prose paraphrase is extended instead.
- Not naming any forge, PR-ref namespace, or ticket prefix in plugin command
  text.
- Not fixing the pre-existing asymmetry whereby the gate's `--stat` companion
  omits the `':(exclude)thoughts/'` pathspec — out of scope, noted in research.
- Not bumping plugin versions or tagging a release: `tce` has stayed at `1.0.1`
  across TP-0020/TP-0025/TP-0029, so releasing is a separate human-decided step.

## Implementation Approach

A single shipped script, `plugins/tce/scripts/baseline.sh`, owns all git
subtlety (ancestry probe, mainline-aware introducing-commit lookup, rename and
shallow-clone handling, exit-code triage). It prints three fixed lines —
`baseline:`, `source:`, `detail:` — so the calling command reads a resolved SHA
and a provenance token instead of running a decision tree in prose. That keeps
the logic out of the compaction-vulnerable tail of a 352-line command and means
`implement.md` and `work.md` reference one behaviour rather than duplicating it.

Phase 1 builds and proves the script. Phase 2 wires it into `implement.md` (the
owner of both consumers and of the closeout format). Phase 3 mirrors into the
composites, updates the two reference files, and records the new artefact and
rule in the repository docs.

## Phase 1: The baseline resolver script

### Overview

Add `plugins/tce/scripts/baseline.sh` following the established
`ticket.sh`/`next-ticket.sh` pattern, and prove it against a scratch repository
that reproduces the squash-merge failure.

### Changes Required:

#### 1. New script

**File**: `plugins/tce/scripts/baseline.sh` (new, mode 755)
**Changes**: Resolve a usable diff baseline from a recorded SHA, with a
document-introducing-commit fallback.

```bash
#!/bin/bash

# Resolve a usable diff baseline from a commit SHA recorded in a thoughts
# document, falling back to the commit that introduced that document into the
# current history when the recorded SHA is not reachable from HEAD.
# Usage: baseline.sh <recorded-sha> [<document-path>]
#
# Why a recorded SHA can stop being usable: a squash or rebase merge rewrites
# history, so commits made on a feature branch are not ancestors of the commit
# that lands on the main branch. Reachability, not object existence, is the
# test -- after the branch is deleted the objects usually survive locally as
# dangling commits for weeks (the reflog keeps them), so an existence check
# would pass on the machine that made the branch and fail only in a fresh
# clone or in CI.
#
# Prints exactly three lines:
#   baseline: <sha>          (empty when nothing could be resolved)
#   source:   recorded | introducing | none
#   detail:   <one-line explanation the caller can report to the user>
#
# The project root is resolved from the project (see lib.sh), not from this
# script's location -- it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if [ -z "$1" ] && [ -z "$2" ]; then
    echo "Usage: $0 <recorded-sha> [<document-path>]"
    echo "Example: $0 a1b2c3d thoughts/shared/research/2026-01-01-X-0001-topic.md"
    exit 1
fi

RECORDED="$1"
DOC="$2"

cd "$(tce_project_root)"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not a git repository at $(tce_project_root)" >&2
    exit 1
fi

report() {
    printf 'baseline: %s\n' "$1"
    printf 'source:   %s\n' "$2"
    printf 'detail:   %s\n' "$3"
    exit 0
}

SHALLOW_NOTE=""
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
    SHALLOW_NOTE=" (shallow clone, so history lookups may be incomplete)"
fi

# 1. Prefer the recorded commit, but only if it is in the current history.
if [ -n "$RECORDED" ]; then
    if git merge-base --is-ancestor "$RECORDED" HEAD >/dev/null 2>&1; then
        report "$RECORDED" "recorded" "the recorded commit is in the current history"
    fi
    if git rev-parse --verify --quiet "${RECORDED}^{commit}" >/dev/null 2>&1; then
        WHY="the recorded commit exists locally but is not an ancestor of HEAD, so history was rewritten (e.g. a squash or rebase merge)"
    else
        WHY="the recorded commit is unknown in this clone, so history was rewritten and the original branch is gone${SHALLOW_NOTE}"
    fi
else
    WHY="no commit was recorded"
fi

# 2. Fall back to the commit that introduced the document into this history.
if [ -n "$DOC" ]; then
    INTRODUCING="$(git log --first-parent --diff-filter=A --max-count=1 \
        --format=%H -- "$DOC" 2>/dev/null || true)"
    if [ -z "$INTRODUCING" ]; then
        # Path-limiting disables rename detection, so a renamed document shows
        # up as an add of the new path; --follow walks past the rename.
        INTRODUCING="$(git log --follow --diff-filter=A --max-count=1 \
            --format=%H -- "$DOC" 2>/dev/null || true)"
    fi
    if [ -z "$INTRODUCING" ]; then
        INTRODUCING="$(git rev-list HEAD -- "$DOC" 2>/dev/null | tail -1 || true)"
    fi
    if [ -n "$INTRODUCING" ]; then
        report "$INTRODUCING" "introducing" \
            "$WHY; using the commit that introduced $DOC into the current history"
    fi
    report "" "none" \
        "$WHY, and $DOC has no commit in the current history${SHALLOW_NOTE}"
fi

report "" "none" "$WHY, and no document path was given to fall back on"
```

Notes on the choices, for reviewers: `--first-parent` is what makes squash
merges and true merges resolve to the same *kind* of answer (a mainline
commit); `--follow` is the rename escape hatch and is tried second because it
accepts only one pathspec; `git rev-list … | tail -1` is the last-resort oldest
touch; every lookup is tested for an **empty string** rather than an exit
status because `git log` exits 0 when it matches nothing.

#### 2. Scratch-repo verification

**File**: none (throwaway directory under the scratchpad, per `CLAUDE.md`'s
"Testing changes")
**Changes**: reproduce the failure and prove each branch of the script:

1. `git init` a repo, commit a `thoughts/shared/research/…md` on `main`.
2. Branch `gh-1`, commit a document + a code change, record the branch HEAD.
3. `git checkout main`, `git merge --squash gh-1`, commit, `git branch -D gh-1`
   — this reproduces a squash merge and branch deletion exactly, without a
   forge.
4. Assert: `baseline.sh <branch-sha> <doc-path>` → `source: introducing`, and
   the returned SHA is the squash commit;
   `baseline.sh <main-sha> <doc-path>` → `source: recorded`;
   `baseline.sh <bogus-sha> <doc-path>` → `source: introducing` (unknown object
   path); `baseline.sh <bogus-sha> nonexistent.md` → `source: none`;
   `baseline.sh` with no arguments → usage, exit 1.
5. Assert `git diff <returned-baseline> --stat` succeeds in every non-`none`
   case (no `fatal: bad object`).

### Success Criteria:

#### Automated Verification:

- [x] `bash -n plugins/tce/scripts/baseline.sh` reports no syntax errors
- [x] The script is executable (`test -x plugins/tce/scripts/baseline.sh`)
- [x] In the scratch repo, a stranded branch SHA resolves to `source: introducing`
      with the squash commit as the baseline
- [x] In the scratch repo, a reachable SHA resolves to `source: recorded` and
      returns that SHA unchanged
- [x] An unknown SHA with an unknown document path resolves to `source: none`
      with an empty `baseline:` and a non-empty `detail:`
- [x] Invoked with no arguments, the script prints usage and exits 1
- [x] `git diff <baseline> --stat` succeeds for every resolved baseline
      (no `fatal: bad object`)

#### Manual Verification:

- [ ] The script's output is readable enough that its `detail:` line can be
      quoted verbatim to a user as the "which baseline was used" statement

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `690aebc2f0fc493e93edda7782d0330ab0b45d89`
- **Commit**: `a44fb1e` feat(TP-0030): add baseline.sh to resolve stranded recorded SHAs
- **Did**: added `plugins/tce/scripts/baseline.sh` (755); verified with a
  scratch repo that squash-merges and deletes a `gh-1` branch, plus a
  `file://` clone for the genuinely-absent case.
- **Issues**: the first clone test shared the origin's object store (local-path
  clone hardlinks it), so the dangling commit was still visible → switched the
  test to a `file://` URL, which forces the git transport.
- **Verification**: ✅ `bash -n`, ✅ 22/22 scratch-repo assertions (recorded /
  introducing / none / renamed doc / fresh clone / usage), ✅ every resolved
  baseline diffs without `fatal: bad object`

---

## Phase 2: Wire the resolver into `/tce:implement`

### Overview

Both consumers of a recorded SHA live in `implement.md`, as does the closeout
format. Change all four sites here.

### Changes Required:

#### 1. Tool allowlist

**File**: `plugins/tce/commands/implement.md`
**Changes**: line 4 — add the new script to `allowed-tools`, keeping the
existing git grants.

```
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*)
```

#### 2. Repository state check

**File**: `plugins/tce/commands/implement.md`
**Changes**: replace the single paragraph at line 58. The surrounding block
must stay intact — in particular the TP-0013 ordered re-read instruction at
`:64` is a separate paragraph and is not touched.

```markdown
**Repository state check:** The research document records the commit it was written at (`git_commit` and `branch` in its frontmatter). That commit is not guaranteed to still be part of the current history — if the work landed through a squash or rebase merge, it isn't. So resolve a usable baseline first: run `"${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh" <git_commit> <research-doc-path>`, which reports `source: recorded` when the recorded commit is still reachable, `source: introducing` when it isn't (falling back to the commit that introduced the research document into the current history), or `source: none` when neither is available. If the resolved baseline is the current HEAD (`git rev-parse HEAD`), the context documents reflect the current codebase. If it differs, the repository has moved on since research: run `git diff --stat <baseline>..HEAD` to see which files changed, and spot-verify what the research and plan claim about any of those files before relying on it. On `source: none`, run no diff — treat the research as potentially stale and spot-verify the claims you actually rely on. **State in your output which baseline you used** (the script's `detail:` line says it). Fast path: when the research and plan were produced earlier in this same session (e.g. by `/tce:work` or `/tce:quickfix`) and HEAD has only advanced by this session's own commits, the check is trivially satisfied — skip the script and the spot-verification.
```

#### 3. Closeout template gains a merge reference

**File**: `plugins/tce/commands/implement.md`
**Changes**: lines 113-119 — add one field, phrased without naming a forge, and
one sentence after the fence saying why it exists.

```markdown
## Implementation Closeout

- **Plan-compliance gate**: [PASS — N met, … one-line summary of the gate run]
- **Manual verification**: [confirmed by user YYYY-MM-DD | pending: <items>]
- **Merge reference**: [the project's durable reference for how this change
  reached the main branch — e.g. a pull/merge request number — or `n/a` when
  the project commits directly]
- **Ticket**: [PREFIX]-XXXX → Done
```

Sentence appended after the fence:

> The **Merge reference** is what keeps the per-phase `**Commit**` hashes
> retrievable. Where a project develops on branches that are squash- or
> rebase-merged and then deleted, those hashes stop resolving once the branch is
> gone; the review/merge request that carried them usually still does. Ask the
> user for it if you don't know it, and write `n/a` when the project has none.

#### 4. Plan-Compliance Gate step 2

**File**: `plugins/tce/commands/implement.md`
**Changes**: replace lines 259-266. The existing absence-keyed chain is kept
(it covers a different failure — a base that was never recorded), the
unreachability probe is added ahead of it, the `--grep` fallback's precondition
is documented in terms of the project's commit convention, and the
no-baseline-at-all path gets a defined behaviour.

```markdown
2. **Assemble the diff.** Use the `**Base commit**` recorded in the first
   phase's `### Implementation log` block in the plan, and resolve it with
   `"${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh" <base> <plan-path>` — a base
   commit recorded on a branch that was later squash- or rebase-merged is no
   longer in the current history, and the script falls back to the commit that
   introduced the plan document instead. Compute the implementation diff from
   the resolved baseline with
   `git diff <baseline> -- . ':(exclude)thoughts/'` plus a
   `git diff <baseline> --stat` summary, and note in the gate's summary line
   which baseline was used (`recorded` or `introducing`).
   If the plan's log records no base commit at all, check a legacy
   `.status.md` next to the plan for one; failing that, fall back to
   `git log --grep="[PREFIX]-XXXX" --format=%H | tail -1` and diff from that
   commit's parent — note that this last fallback only finds anything if the
   project's commit convention (see `profile.md`) puts the ticket ID in the
   commit message, and where changes reach the main branch as a single merged
   commit, that commit's own message has to carry it too.
   If nothing yields a baseline (`source: none` and no fallback matched), do
   **not** guess one and do **not** diff against an arbitrary commit: report
   that the gate cannot be run against a real diff, and treat that as blocking
   the done transition exactly like a "cannot verify" verdict in step 4.
```

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `claude plugin validate .` passes
- [x] No occurrence of `git diff --stat <research_commit>..HEAD` or
      `git diff <base> --` remains in `implement.md` (all diffs go through a
      resolved baseline)
- [x] `implement.md`'s `allowed-tools` line contains `baseline.sh`

#### Manual Verification:

- [ ] The rewritten `:58` paragraph reads at the same altitude as the rest of
      the section and leaves the TP-0013 re-read instruction untouched
- [ ] The closeout's merge-reference wording names no forge and no ticket prefix

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `3ccaeab` feat(TP-0030): diff from a resolved baseline in /tce:implement
- **Did**: `implement.md` — allowlisted `baseline.sh`; rewrote the repository
  state check (`:58`) and Plan-Compliance Gate step 2 to diff from a resolved
  baseline; added the generic `**Merge reference**` closeout field plus the
  sentence explaining what it preserves.
- **Issues**: none — the TP-0013 re-read instruction is a separate paragraph
  and was not touched by the `:58` rewrite.
- **Verification**: ✅ `claude plugin validate .`, ✅ `claude plugin validate
  ./plugins/tce`, ✅ grep confirms no raw-SHA diff invocation remains

---

## Phase 3: Mirror into the composites, the reference files, and repo docs

### Overview

Apply CLAUDE.md's composite-tracking and TP-0020 gate rules, extend the two
reference-file contracts, and record the new script and rule in the repository
documentation.

### Changes Required:

#### 1. `work.md` — allowlist, state check, gate mirror

**File**: `plugins/tce/commands/work.md`
**Changes**:

- Line 5 — add the script to `allowed-tools`:
  ```
  allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*), Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*), Bash(git diff:*), Bash(git rev-parse:*)
  ```
  (`git diff`/`git rev-parse` are added because Phase 4d now runs them inline;
  they were previously exercised only through the delegated command.)
- Line 225 — qualify the fast-path assertion for the resumed-session case,
  which is the one situation where `/tce:work` can meet a stranded SHA:
  ```markdown
  2. The repository state check from `/tce:implement` is trivially satisfied when research and plan were produced earlier in this same session — skip the spot-verification. If you are resuming a `/tce:work` run in a **later** session, run that check as `/tce:implement` specifies, including its `baseline.sh` resolution for a recorded commit that history rewriting has stranded
  ```
- Line 256 — mirror the resolved baseline into the inline gate description,
  replacing the parenthetical diff invocation with:
  ```
  the implementation diff (resolve the baseline from the `**Base commit**` in the plan's first-phase `### Implementation log` with `"${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh" <base> <plan-path>` — it falls back to the commit that introduced the plan when a squash or rebase merge stranded the recorded one — then `git diff <baseline> -- . ':(exclude)thoughts/'`)
  ```
  and extend the all-pass clause so it reads "an all-pass run adds a single line
  to the completion summary, naming the baseline the gate used".

#### 2. `quickfix.md` — surface a fallback baseline

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: `quickfix.md` inherits the gate through the `tce:implement` Skill
delegation, so nothing about the mechanics is restated there. The one thing it
owns is what the Final Summary reports, and in a fully autonomous flow the user
should learn when the gate judged against a fallback baseline. Extend the prose
at `:233-242` with one sentence:

> If the gate had to fall back to a non-recorded baseline (because history
> rewriting stranded the recorded one), say which baseline it used — the
> comparison is still sound, but the user should know it wasn't the recorded
> commit.

#### 3. `research-document-template.md` — contract note

**File**: `plugins/tce/references/research-document-template.md`
**Changes**: extend the header comment's consumer note at lines 10-11:

```
Downstream consumers depend on the frontmatter: implement.md reads
`git_commit`/`branch`, plan.md reads `last_updated`. Note that `git_commit`
is the commit the research was written at and is not guaranteed to stay
reachable — if the work lands through a squash or rebase merge, that commit is
no longer part of the main branch's history. implement.md handles this by
resolving a baseline (falling back to the commit that introduced this
document); do not treat `git_commit` as a stable anchor elsewhere.
```

#### 4. `plan-document-template.md` — extend the prose paraphrase

**File**: `plugins/tce/references/plan-document-template.md`
**Changes**: at lines 170-176, extend the existing field paraphrase to name the
closeout's fields (including the new one). The section keeps its "do not author
these" framing and gains **no** template — the formats stay owned by
`implement.md`:

```
During implementation, /tce:implement appends a terse `### Implementation log`
block as the last subsection of each phase (status, base/phase commit hashes,
what was done, issues, verification results) and an `## Implementation
Closeout` section at the very end of the document (gate result, manual-
verification state, a durable reference for how the change reached the main
branch, ticket transition). Their formats are owned by implement.md. **A plan
is always authored without them** — never include log blocks, a closeout
section, or pre-ticked success-criteria checkboxes when writing a plan.
```

#### 5. Repository documentation

**File**: `CLAUDE.md`
**Changes**:

- Line 34 — add the script to the tce layout listing:
  ```
  ├── scripts/*.sh                # lib.sh, ticket.sh (thoughts lookup by ID), baseline.sh
  │                               #   (resolve a diff baseline from a recorded SHA), check-init.sh
  ```
- In the TP-0020 gate section, append a short paragraph recording that the
  gate's baseline resolution is shipped as `scripts/baseline.sh` and that the
  script, `implement.md` and `work.md` must move together when the baseline
  mechanics change (the same span rule, extended by one file), and that a
  recorded SHA is checked for **reachability** (`git merge-base --is-ancestor`),
  never mere existence (`git cat-file -e` succeeds on dangling commits and would
  make the behaviour differ between the author's clone and CI).

**File**: `CONTRIBUTING.md`
**Changes**: line 41 — mirror the script listing:
```
│   ├── scripts/                    # lib.sh, ticket.sh (thoughts lookup), baseline.sh, check-init.sh
```

**File**: `.claude/settings.local.json`
**Changes**: add this repo's dogfooding allowlist entry alongside the existing
`ticket.sh` one:
```
"Bash(/Users/toby/code/work/toby-plugins/plugins/tce/scripts/baseline.sh *)",
```

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes
- [x] `claude plugin validate ./plugins/tce` passes
- [x] `claude plugin validate ./plugins/tmt` passes
- [x] `claude plugin validate ./plugins/tle` passes
- [x] `.claude/settings.local.json` is valid JSON (`jq . .claude/settings.local.json`)
- [x] `baseline.sh` is referenced in `implement.md`, `work.md`, `CLAUDE.md` and
      `CONTRIBUTING.md`
- [x] No forge name, PR-ref namespace (`refs/pull`, `refs/merge-requests`) or
      concrete ticket prefix appears in any changed file under `plugins/`

#### Manual Verification:

- [ ] `work.md`'s gate paragraph and `implement.md`'s gate step still describe
      the same mechanism, at their respective altitudes
- [ ] End-to-end: in a scratch project whose branch was squash-merged and
      deleted and which is then freshly cloned, `/tce:implement` completes both
      the repository state check and the Plan-Compliance Gate, producing a
      correct result and naming the baseline used

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `2fca9a8` feat(TP-0030): mirror the baseline resolution across the composites
- **Did**: `work.md` — allowlist, resumed-session qualifier at the state-check
  step, baseline resolution in the inline gate, baseline named in the all-pass
  summary; `quickfix.md` — surfaces a fallback baseline in the Final Summary;
  `research-document-template.md` — `git_commit` is not a stable anchor;
  `plan-document-template.md` — closeout field paraphrase extended (no template
  added, ownership boundary preserved); `CLAUDE.md` + `CONTRIBUTING.md` script
  listings and a new TP-0030 paragraph in the gate section; dogfooding
  allowlist entry.
- **Issues**: `.claude/settings.local.json` is gitignored, so the dogfooding
  allowlist entry was applied locally but is not part of the commit — correct
  for a local-only file, and it affects nothing shipped.
- **Verification**: ✅ 4/4 `claude plugin validate`, ✅ `jq` on
  settings.local.json, ✅ `baseline.sh` referenced from all four files, ✅ no
  forge/prefix literal on any added line under `plugins/`

---

## Testing Strategy

### Unit Tests:

The repo has no test framework; verification is `claude plugin validate` plus
script smoke tests against a throwaway project directory, per `CLAUDE.md`'s
"Testing changes". The script's cases to cover are listed in Phase 1's
verification steps — reachable SHA, stranded-but-present SHA, absent SHA,
missing document, no arguments.

### Integration Tests:

`git merge --squash` + `git branch -D` in a scratch repository reproduces the
exact failure locally, with no forge involved. That covers the "documents
committed on a branch, branch squash-merged into main and deleted" half of the
ticket's verification criterion; the "fresh clone" half is covered by cloning
that scratch repo into a second directory and re-running the script there
(where the branch objects are genuinely absent rather than dangling).

### Manual Testing Steps:

1. Build the scratch repo as in Phase 1, then `git clone` it to a second path.
2. In the clone, run `baseline.sh <stranded-sha> <doc-path>` and confirm
   `source: introducing` (in the clone the object is absent, so this exercises
   the 128/unknown branch rather than the dangling branch).
3. In a scratch project with tce installed, run `/tce:implement` against a plan
   whose recorded SHAs are stranded, and confirm the state check and the gate
   both complete and name their baseline.

## Performance Considerations

`git merge-base --is-ancestor` is O(distance) rather than a full history walk,
and replaces no existing command in the fast path (the same-session shortcut
still skips the script entirely). The `git log` fallbacks run only when the
recorded SHA is already unusable.

## Migration Notes

No project config changes, so no `tce-config-version` bump and no addition to
`/tce:init`'s idempotency upgrade list. Existing plans keep working unchanged: a
reachable `**Base commit**` resolves to `source: recorded`, and plans with no
base commit still fall through the legacy `.status.md` and `git log --grep`
chain. Closeouts written before this change simply lack the merge-reference
line; nothing reads it programmatically.

## References

- Original ticket: `TP-0030` —
  `thoughts/shared/tickets/TP-0030-drift-check-rewritten-history.md`
- Related research:
  `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md`
- Prior gate design:
  `thoughts/shared/plans/2026-07-05-TP-0020-plan-compliance-gate.md`
- Similar script pattern: `plugins/tce/scripts/ticket.sh:1-33`
- Decisions taken at the TP-0030 question checkpoint (see the Closeout below): adopt
  `merge-base --is-ancestor` over the ticket's `cat-file -e` (amending
  acceptance criteria 1 and 2); ship the logic as a script; extend the plan
  template's prose rather than adding a closeout template to it (amending
  acceptance criterion 3); phrase the merge reference generically.

## Implementation Closeout

- **Plan-compliance gate**: PASS — 29 criteria, 15 met, 0 not met, 8 "cannot
  verify from diff" (the four `claude plugin validate` runs and the scratch-repo
  assertions, which the read-only checker cannot execute — all were run and
  passed in the implementing session), 6 MANUAL. Baseline used: `recorded`
  (`690aebc`).
- **Manual verification**: pending — items 8, 16, 21, 22, 28, 29 (scratch-repo
  and end-to-end `/tce:implement` runs, the `detail:` line's quotability, the
  altitude of the rewritten `:58` paragraph, the forge-neutrality of the
  closeout wording, and the `work.md`/`implement.md` gate parity). The user
  chose on 2026-09-03 to close the ticket without them and to confirm the
  behaviour when next working in a production repository, so their checkboxes
  are deliberately left unticked.
- **Merge reference**: n/a — this repository commits directly to `main` (see
  `CLAUDE.md`, "Conventions").
- **Ticket**: TP-0030 → Done
