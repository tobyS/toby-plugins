# Declarable branch convention in the tce profile — Implementation Plan

## Overview

Let a project declare its branch model in `.claude/tce/profile.md` and make tce
follow it. A new `## Branch convention` section — shaped like `## Commit
convention` — is agreed at `/tce:init`, preserved by `/tce:refresh`, and read at
runtime by the four ticket-scoped workflow commands (`/tce:research`,
`/tce:plan`, `/tce:implement`, `/tce:review`), by `/tce:commit`, and by the two
composites. Two options: **Current branch** (today's behaviour, the default) and
**Branch per ticket**. The git work lives in one shipped script,
`plugins/tce/scripts/branch.sh`, modelled on `baseline.sh`. A project that
declares nothing sees no change at all.

Decisions taken at the `/tce:work` question checkpoint (2026-09-04):

1. **Commands:** `/tce:research` creates the ticket branch (or switches to it if
   it exists); `/tce:plan`, `/tce:implement` and `/tce:review` switch to the
   existing branch when the session is elsewhere, never create one, and stop and
   ask when it is missing or the tree is dirty. `/tce:work` mirrors this inline;
   `/tce:quickfix` mirrors the research step in its own Phase 3 and inherits the
   rest through Skill delegation.
2. **Shared logic:** a shipped `scripts/branch.sh` (one `allowed-tools` entry per
   invoking command); no reference file.
3. **Base branch freshness:** attempt a fetch of the recorded base branch from
   its remote; on success branch from the fetched tip; on any failure stop and
   ask the user to update it or confirm the local tip is current. Never branch
   from anything else.
4. **Refresh / upgrade:** the section is **hand-authored** — `/tce:refresh`
   preserves it and does not re-detect it; `/tce:init`'s Idempotency list gets a
   bullet that runs the branch dialog when the section is missing. (Deviates
   from the ticket's refresh wording; the ticket is amended in Phase 1.)
5. **`/tce:commit`:** warns and asks (does not refuse) before a ticket-scoped
   commit that would land on the base branch under branch-per-ticket.
6. **Merge strategy:** not recorded.
7. **Version:** bump tce to `1.1.0` in `plugin.json` and `marketplace.json` so the
   upgrade bullet fires; tagging stays with the maintainer.

## Current State Analysis

From `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`:

- No tce command creates, switches or checks out a branch. Five commands gather
  `git branch --show-current` as metadata; only `research.md` (step 5) and
  `review.md` persist it. `implement.md:58` names the research frontmatter's
  `branch:` but acts only on `git_commit`.
- `/tce:research` reads the ticket in "Ticket Document Discovery" (`research.md:88-112`),
  then runs numbered steps 1–10; step 5 gathers metadata, step 6 writes, step 9
  commits. Step numbers are cross-referenced from `research-document-template.md:3,9,41-43`
  and from within `research.md:77,84,243-244,267,283`.
- The `## Commit convention` lifecycle (TP-0008) is the exact shape to copy:
  template section `templates/tce/profile.md:53-68`; init gather item
  `init.md:140-145`, dialog `init.md:258-278`, refine list `init.md:286-288`, fill
  `init.md:321-334`, Idempotency list `init.md:444-466`; reader with fallback
  `commit.md:59-82`; refresh classification `refresh.md:95-105`; README
  `plugins/tce/README.md:156-169,222,265-276`.
- `baseline.sh` is the git-helper pattern: `set -e`, sources `lib.sh`,
  `cd "$(tce_project_root)"`, usage → exit 1, three-line stdout contract, exit 0
  for every resolved outcome; invoked as
  `"${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh" …` and pre-authorized with
  `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/baseline.sh":*)` in each invoking command.
- `allowed-tools` today: `research.md:4`, `plan.md:4`, `review.md:5` allow only
  `ticket.sh`; `implement.md:4` and `work.md:5` add `baseline.sh` + git verbs;
  `quickfix.md`, `commit.md` declare none.
- `/tce:init`'s Idempotency list has two bullets (version marker; `## Dev
  environment`); an entry fires only when the marker differs from the installed
  `plugin.json` version (`1.0.1` today). `/tce:refresh` has no missing-section
  handling and by rule defines no new required config.
- Non-ticket work: `commit.md:64-66` includes the ticket ID only "if the chat is
  about a ticket"; `discuss.md`, `design_explore.md`, `init.md`, `refresh.md`
  never commit; `ticket.md` commits the ticket file on the current branch.
- This repository commits straight to `main` (`CLAUDE.md` Conventions,
  `CONTRIBUTING.md:66-67`); its profile has no branch statement and no
  `## Dev environment` section; `refs/remotes/origin/HEAD` → `origin/main`.

## Desired End State

- `plugins/tce/templates/tce/profile.md` has a `## Branch convention` section
  directly after `## Commit convention` (intro + bracketed two-option block).
- `plugins/tce/scripts/branch.sh` exists with modes `create`, `switch`, `check`,
  a three-line stdout contract (`branch:` / `result:` / `detail:`), exit 0 for
  every reported outcome, exit 1 for usage errors and non-repos.
- `/tce:init` detects a suggestion, asks the branch dialog(s) after the commit
  dialog with verbatim copy, fills the section in Phase 4, and its Idempotency
  list walks a pre-1.1.0 profile through the dialog.
- `/tce:refresh` lists `## Branch convention` among the preserved hand-authored
  sections.
- `research.md`, `plan.md`, `implement.md`, `review.md` run the branch step in
  their Ticket Document Discovery, right after fetching the ticket and before
  the discovery script; `commit.md` runs the `check` before a ticket-scoped
  commit; `work.md` and `quickfix.md` mirror the research step and inherit the
  rest; every invoking command pre-authorizes `branch.sh`.
- With no `## Branch convention` section, or with **Current branch**, every
  command behaves exactly as today: no script call, no prompt, no extra output.
- `CLAUDE.md` records the same-commit span; `plugins/tce/README.md` documents the
  convention; `CONTRIBUTING.md` and the `CLAUDE.md` layout tree list `branch.sh`.
- tce is `1.1.0` in `plugin.json` and `marketplace.json`; this repo's own
  profile carries `## Branch convention` = Current branch and marker `1.1.0`.
- `claude plugin validate .` and the three per-plugin validations pass; the
  script scenario matrix (Testing Strategy) passes in a scratch repository.

### Key Discoveries:

- Section shape to copy: `plugins/tce/templates/tce/profile.md:53-68` (intro
  naming who fills/reads it, then `[Filled by /tce:init with one of: …]`).
- Init fill rule to copy: `init.md:331-334` ("replace the bracketed guidance with
  just the chosen convention's spec … keeping the intro paragraph above it").
- Reader fallback principle: `commit.md:73-82` — absent section = pre-feature
  behaviour, so un-upgraded projects change nothing.
- The ticket's thoughts documents live on the ticket branch under
  branch-per-ticket, so the switch must happen **before** `ticket.sh` runs in
  plan/implement/review — hence the step's position in Ticket Document Discovery.
- `git switch -c <name> <remote>/<base>` sets upstream to the base by default
  (`branch.autoSetupMerge`); the script must pass `--no-track`.
- `git switch -c` refuses an existing name (use `git switch` instead);
  `git check-ref-format --branch` validates generated names;
  `git branch --show-current` prints nothing on detached HEAD.
- `allowed-tools` grants are per invoking skill turn and `${CLAUDE_PLUGIN_ROOT}`
  is substituted in Bash rules — one `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`
  per command suffices; no raw `git switch`/`git fetch` grants needed.
- Idempotency entries are inert until `plugin.json` changes (TP-0003 plan:66-67,
  90-91) — hence the 1.1.0 bump in this ticket.
- Ticket files (tmt) are created on the branch the session is on, normally the
  base branch, so tmt numbering stays shared; ticket creation is deliberately
  **not** moved to a ticket branch.

## What We're NOT Doing

- Prescribing any branch model, name or merge strategy; recording the merge
  strategy (decision 6).
- Pushing, opening or updating pull requests, deleting or merging branches.
  `branch.sh` fetches (read-only network) and creates/switches local branches;
  it never pushes.
- Syncing a long-lived ticket branch with its base.
- Refusing commits (`/tce:commit` warns and asks only).
- Making `/tce:refresh` add a missing section (refresh reconciles existing
  config; init's upgrade list adds required config).
- Moving ticket creation (`/tce:ticket`, quickfix Phase 2) onto a ticket branch.
- Branch steps in `/tce:discuss`, `/tce:design_explore`, `/tce:init`,
  `/tce:refresh` (non-ticket work stays where the session is).
- Teaching tle's `loop-implementer` the branch convention (tle writes no project
  config and is not dogfooded here).
- Editing the byte-identical `### AskUserQuestion dialog guidelines` block or
  adding an eleventh copy: `commit.md` asks its one yes/no in prose.
- Tagging the `tce--v1.1.0` release (the maintainer tags).
- tmt ticket numbering across branches (a tmt concern).
- A fetch timeout for SSH remotes (git offers none without overriding the
  user's SSH command; HTTP low-speed limits are set).

## Implementation Approach

Copy the TP-0008 lifecycle one artifact at a time, in dependency order: the
script first (everything else references it), then the profile template and the
config commands (init/refresh), then the runtime readers (research + composites,
then plan/implement/review/commit), then docs, version bump and dogfooding. Each
phase is committed separately; the same-commit spans that matter (script ↔
invoking commands ↔ composites) are kept inside single phases.

Every command edit is surgical: a new numbered item or paragraph at the named
location, existing prose untouched. The branch step is always guarded first by
"section absent or **Current branch** → skip entirely, print nothing", which is
what makes the absent-section behaviour byte-identical.

---

## Phase 1: `branch.sh` and the ticket amendment

### Overview

Ship the one location for the branch logic, prove it against a scratch
repository, register it in the repo's file listings, and record the checkpoint
decisions in the ticket (including the amended refresh acceptance criterion).

### Changes Required:

#### 1. New script

**File**: `plugins/tce/scripts/branch.sh` (executable, `chmod +x`)
**Changes**: create with this content.

```bash
#!/bin/bash

# Put a ticket's branch in place per the project's `## Branch convention`
# (branch-per-ticket projects only -- the calling command decides whether the
# convention applies and resolves the branch name; this script does the git).
#
# Usage: branch.sh create <branch> <base> [<remote>] [--trust-local]
#        branch.sh switch <branch>
#        branch.sh check  <branch> <base>
#
#   create  -- for /tce:research: switch to <branch> if it already exists
#              (locally or on <remote>); otherwise fetch <base> from <remote>
#              and create <branch> from the fetched tip. If the fetch fails or
#              there is no remote, nothing is created: the caller must ask the
#              user, and re-run with --trust-local only once the user confirmed
#              that the local <base> tip is current. Never cuts the branch from
#              anything but <remote>/<base> (or, trusted, the local <base>).
#   switch  -- for /tce:plan, /tce:implement, /tce:review: switch to an existing
#              <branch>; never creates one.
#   check   -- for /tce:commit: report where HEAD is; no side effects.
#
# create and switch refuse to move a working tree with uncommitted tracked
# changes (result: dirty) -- untracked files carry over harmlessly and are
# ignored. A branch that already is the current branch is always fine.
#
# Prints exactly three lines:
#   branch:  <current branch after the command ran; empty on detached HEAD>
#   result:  create: created | switched | already | fetch-failed | no-remote |
#                    missing-base | dirty | blocked | invalid-name
#            switch: switched | already | missing | dirty | blocked
#            check:  on-branch | on-base | elsewhere | detached
#   detail:  <one-line explanation the caller can report to the user>
#
# Every reported outcome exits 0; only usage errors and "not a git repository"
# exit 1. The project root is resolved from the project (see lib.sh), not from
# this script's location -- it ships inside the tce plugin.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
    echo "Usage: $0 create <branch> <base> [<remote>] [--trust-local]"
    echo "       $0 switch <branch>"
    echo "       $0 check  <branch> <base>"
    echo "Example: $0 create MYAPP-0042 main origin"
    exit 1
}

MODE="$1"
shift || usage
TRUST_LOCAL=0
POSITIONAL=()
for ARG in "$@"; do
    case "$ARG" in
        --trust-local) TRUST_LOCAL=1 ;;
        *) POSITIONAL+=("$ARG") ;;
    esac
done
BRANCH="${POSITIONAL[0]:-}"
BASE="${POSITIONAL[1]:-}"
REMOTE="${POSITIONAL[2]:-}"

case "$MODE" in
    create) [ -n "$BRANCH" ] && [ -n "$BASE" ] || usage ;;
    switch) [ -n "$BRANCH" ] || usage ;;
    check)  [ -n "$BRANCH" ] && [ -n "$BASE" ] || usage ;;
    *) usage ;;
esac

cd "$(tce_project_root)"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: not a git repository at $(tce_project_root)" >&2
    exit 1
fi

report() {
    printf 'branch:  %s\n' "$(git branch --show-current 2>/dev/null || true)"
    printf 'result:  %s\n' "$1"
    printf 'detail:  %s\n' "$2"
    exit 0
}

CURRENT="$(git branch --show-current 2>/dev/null || true)"

local_exists()  { git show-ref --verify --quiet "refs/heads/$1"; }
remote_exists() { [ -n "$REMOTE" ] && git show-ref --verify --quiet "refs/remotes/$REMOTE/$1"; }
tree_dirty()    { [ -n "$(git status --porcelain --untracked-files=no 2>/dev/null)" ]; }

# Switch to an existing local branch, or to a remote-tracking one (git creates
# the local tracking branch). Reports and exits.
switch_existing() {
    if tree_dirty; then
        report "dirty" "the working tree has uncommitted changes; commit or stash them before switching to $BRANCH"
    fi
    if OUT="$(git switch "$BRANCH" 2>&1)"; then
        report "switched" "switched to $BRANCH"
    fi
    report "blocked" "git could not switch to $BRANCH: $(printf '%s' "$OUT" | tail -1)"
}

case "$MODE" in

check)
    if [ -z "$CURRENT" ]; then
        report "detached" "HEAD is detached, not on $BRANCH"
    elif [ "$CURRENT" = "$BRANCH" ]; then
        report "on-branch" "on the ticket branch $BRANCH"
    elif [ "$CURRENT" = "$BASE" ]; then
        report "on-base" "on the base branch $BASE, not on the ticket branch $BRANCH"
    fi
    report "elsewhere" "on $CURRENT, neither the ticket branch $BRANCH nor the base branch $BASE"
    ;;

switch)
    if [ "$CURRENT" = "$BRANCH" ]; then
        report "already" "already on $BRANCH"
    fi
    if local_exists "$BRANCH" || git show-ref --quiet "refs/remotes/*/$BRANCH" 2>/dev/null; then
        switch_existing
    fi
    report "missing" "branch $BRANCH does not exist; /tce:research creates it"
    ;;

create)
    if [ "$CURRENT" = "$BRANCH" ]; then
        report "already" "already on $BRANCH"
    fi
    if ! git check-ref-format --branch "$BRANCH" >/dev/null 2>&1; then
        report "invalid-name" "$BRANCH is not a valid git branch name; check the pattern in the profile's Branch convention"
    fi
    if local_exists "$BRANCH" || remote_exists "$BRANCH"; then
        switch_existing
    fi
    if tree_dirty; then
        report "dirty" "the working tree has uncommitted changes; commit or stash them before creating $BRANCH"
    fi
    if [ "$TRUST_LOCAL" = "1" ]; then
        if ! local_exists "$BASE"; then
            report "missing-base" "the base branch $BASE does not exist locally"
        fi
        if OUT="$(git switch -c "$BRANCH" --no-track "$BASE" 2>&1)"; then
            report "created" "created $BRANCH from the local $BASE tip $(git rev-parse --short HEAD) (trusted as current)"
        fi
        report "blocked" "git could not create $BRANCH: $(printf '%s' "$OUT" | tail -1)"
    fi
    if [ -z "$REMOTE" ] || [ "$REMOTE" = "none" ]; then
        report "no-remote" "no remote is configured for $BASE, so it cannot be brought up to date; confirm the local $BASE tip is current, then re-run with --trust-local"
    fi
    if ! OUT="$(GIT_HTTP_LOW_SPEED_LIMIT=1000 GIT_HTTP_LOW_SPEED_TIME=20 \
            git fetch "$REMOTE" "$BASE" 2>&1)"; then
        report "fetch-failed" "could not fetch $BASE from $REMOTE ($(printf '%s' "$OUT" | tail -1)); update it or confirm the local $BASE tip is current, then re-run with --trust-local"
    fi
    if OUT="$(git switch -c "$BRANCH" --no-track "$REMOTE/$BASE" 2>&1)"; then
        report "created" "created $BRANCH from $REMOTE/$BASE at $(git rev-parse --short HEAD)"
    fi
    report "blocked" "git could not create $BRANCH: $(printf '%s' "$OUT" | tail -1)"
    ;;
esac
```

Notes for the implementer:

- `git fetch <remote> <base>` also updates `refs/remotes/<remote>/<base>`, which
  the subsequent `git switch -c … <remote>/<base>` relies on.
- `set -e` is kept for parity with `baseline.sh`; every command that may fail is
  inside an `if` or a `$(… || true)`.
- `local_exists`/`remote_exists`/`tree_dirty` are one-line functions; keep them
  in the script (not `lib.sh`) — nothing else needs them.

#### 2. File listings

**File**: `CLAUDE.md` (Layout block, the `scripts/*.sh` line for tce)
**Changes**: `lib.sh, ticket.sh (thoughts lookup by ID), baseline.sh` → add
`branch.sh (branch-per-ticket step)` to the parenthetical list; keep the wrap.

**File**: `CONTRIBUTING.md:41`
**Changes**: `# lib.sh, ticket.sh (thoughts lookup), baseline.sh, check-init.sh`
→ `# lib.sh, ticket.sh (thoughts lookup), baseline.sh, branch.sh, check-init.sh`.

#### 3. Ticket amendment

**File**: `thoughts/shared/tickets/TP-0031-declarable-branch-convention.md`
**Changes**:

- Acceptance criterion "Re-running `/tce:init` … and `/tce:refresh` reconciles
  it the way it reconciles `## Commit convention` (`refresh.md:79-98`)." →
  "Re-running `/tce:init` on a project whose `profile.md` predates the section
  offers to add it (extending the Idempotency upgrade list, per TP-0003), and
  `/tce:refresh` lists it among the hand-authored sections it preserves (decided
  at the 2026-09-04 checkpoint: a branch model is team policy, not something
  re-analysis can verify against the repo)."
- Under `## Notes & Updates`, add a `### 2026-09-04` entry listing the seven
  checkpoint decisions (Overview above), in one line each.
- Set `**Updated:** 2026-09-05`.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes (no manifest change, sanity).
- [x] `test -x plugins/tce/scripts/branch.sh` succeeds.
- [x] Script scenario matrix (Testing Strategy, scenarios S1–S13) passes in a
      scratch repository, each scenario's `result:` line matching the table.
- [x] `CLAUDE.md` layout block and `CONTRIBUTING.md` list `branch.sh`
      (`grep -n branch.sh CLAUDE.md CONTRIBUTING.md` shows both).

#### Manual Verification:

- [ ] Script header reads as a usable contract for someone who has not read
      this plan.

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `16c0420760b14558f78eb98055840bf6777c5588`
- **Commit**: (recorded in the closing hashes commit)
- **Did**: added `plugins/tce/scripts/branch.sh` (create/switch/check); listed it in
  `CLAUDE.md` layout + `CONTRIBUTING.md`; ticket → In Progress, refresh AC amended,
  checkpoint decisions noted.
- **Issues**: none
- **Verification**: ✅ 17/17 scenario checks (S1–S13) in a scratch bare-remote + clone,
  ✅ `claude plugin validate ./plugins/tce`, ✅ `test -x`, ✅ listing greps

---

## Phase 2: Profile template, `/tce:init`, `/tce:refresh`

### Overview

Add the section to the template and teach init to agree it (gather item,
dialogs, refine, fill, Idempotency) and refresh to preserve it.

### Changes Required:

#### 1. Template section

**File**: `plugins/tce/templates/tce/profile.md`
**Changes**: insert after the `## Commit convention` block (after line 68) and
before `## Preferred research sources`:

```markdown
## Branch convention

Where tce puts a ticket's work. `/tce:init` agrees this with you and fills in the
chosen model; `/tce:research`, `/tce:plan`, `/tce:implement` and `/tce:review` (and
the composites `/tce:work` / `/tce:quickfix`) read it right after fetching the
ticket, and `/tce:commit` checks it before a ticket-scoped commit. Work without a
ticket — discussions, design explorations, config, chores — and ticket *creation*
are never moved: they stay on whatever branch the session is on.

[Filled by `/tce:init` with one of:

- **Current branch** — tce works on whatever branch the session is on and never
  creates or switches branches. (The default — identical to leaving this section
  out.)
- **Branch per ticket** — each ticket's research, plan and implementation live on
  their own branch, cut from a freshly fetched base:
  - **Branch name:** `<pattern>` — `<ticket-id>` stands for the canonical ID per
    `.claude/tce/tickets.md` (e.g. `<ticket-id>`, `feature/<ticket-id>`,
    `<ticket-id>-<slug>` with a short kebab-case slug of the ticket title).
  - **Base branch:** `<branch>` on remote `<remote>` (or "no remote").
  - **When the base cannot be brought up to date** (fetch fails, no remote): tce
    stops and asks you to update it or confirm the local tip is current. It never
    cuts the branch from any other tip and never substitutes another branch.
  - `/tce:research` creates the branch (or switches to it if it exists);
    `/tce:plan`, `/tce:implement` and `/tce:review` switch to it when the session
    is elsewhere and stop and ask if it is missing or the working tree has
    uncommitted changes; `/tce:commit` warns and asks before a ticket-scoped
    commit that would land on the base branch.]
```

#### 2. `/tce:init` Phase 1 gather item

**File**: `plugins/tce/commands/init.md`
**Changes**: after item 9 (line 145) add:

```markdown
10. **Branch convention** — gather a suggestion for Phase 2 (the user decides):
    - **Base branch candidate:** for the remote `git remote` lists (the first, if
      several), `git symbolic-ref --short refs/remotes/<remote>/HEAD` names the
      remote's default branch; if that ref is absent, fall back to the current
      branch (`git branch --show-current`). No remote → no remote, current branch.
    - **Model suggestion:** if `git log --merges --first-parent -n 30 --format=%s`
      shows merge commits, or `git branch -r` lists branches matching the
      ticket-ID form detected in item 6, suggest **Branch per ticket**; otherwise
      **Current branch**. Empty history → **Current branch**. This is only a
      suggestion — a branch model is team policy.
```

#### 3. `/tce:init` Phase 2 dialog

**File**: `plugins/tce/commands/init.md`
**Changes**: after the commit-convention dialog (after line 278, before "For
anything genuinely ambiguous…") add:

````markdown
Then ask about the **branch convention** with the AskUserQuestion tool, following the
AskUserQuestion dialog guidelines (above). **Use this copy verbatim** — print the
intro, then ask (move the model suggested in Phase 1 to position 1, append
" (Recommended)" to its label, and prefix its description with the detection
reasoning, e.g. "Detected: no merge commits in recent history. " or "Detected:
remote branches named after ticket IDs. "):

```
Which branch should tce work on? By default tce works on whatever branch the
session is on. If this project develops each ticket on its own branch, tce can
cut that branch from a freshly fetched base before it writes the first artifact
and switch to it in later sessions. It's recorded in .claude/tce/profile.md and
you can change it there anytime.
```

Question: "Which branch model should tce follow?" — header: "Branches", options:

1. **Current branch** — tce never creates or switches branches; research, plan
   and implementation land on whatever branch the session is on.
2. **Branch per ticket** — tce creates the ticket's branch from the base branch
   before the first artifact and switches to it in later sessions; it stops and
   asks when the base cannot be fetched.

If the user picks **Branch per ticket**, follow up in a second AskUserQuestion
call. Use this copy verbatim; print the intro:

```
Two details for the branch-per-ticket model. The branch name is derived from the
canonical ticket ID; the base branch is where ticket branches are cut from — tce
fetches it before branching and never substitutes another branch.
```

Question: "Which branch name pattern?" — header: "Branch name", options:

1. **`<ticket-id>` (Recommended)** — the canonical ticket ID alone, e.g. `TP-0042`.
2. **`feature/<ticket-id>`** — a `feature/` prefix plus the ID, e.g. `feature/TP-0042`.
3. **`<ticket-id>-<slug>`** — the ID plus a short kebab-case slug of the ticket
   title, e.g. `TP-0042-login-timeout`.

Question: "Which base branch?" — header: "Base branch", options: the candidate
from Phase 1 first with " (Recommended)" and the description "Detected:
<remote>/HEAD points at it." (or "Detected: the current branch."), then `main`,
`develop`, `master` minus whichever equals the candidate — each described as
"Ticket branches are cut from <name> on <remote>." The remote is the one from
Phase 1; when there is none, say so in the descriptions ("no remote — tce will
ask you to confirm the base is current each time").
````

Replace `TP-0042` in the examples with the same placeholder style the commit
dialog uses (`TP-0001`-style tmt examples are already accepted there).

#### 4. `/tce:init` Phase 3 and Phase 4

**File**: `plugins/tce/commands/init.md`
**Changes**:

- Line 287: "conventions, commit convention, preferred research sources" →
  "conventions, commit convention, branch convention, preferred research sources".
- Line 321-322: "Tech stack, Commands, Code map, Conventions, Commit convention,
  and Preferred research sources" → "…, Commit convention, Branch convention, and
  Preferred research sources".
- After the `## Commit convention` fill paragraph (line 334) add:

  ```markdown
     For **`## Branch convention`**, replace the bracketed guidance with just the
     chosen model's bullet, keeping the intro paragraph above it. For **Branch per
     ticket**, fill the name pattern, base branch and remote with the agreed values
     (keep `<ticket-id>` literally in the pattern — it is resolved per ticket at
     runtime) and keep the model's sub-bullets that describe the stop-and-ask rule
     and which commands act. For **Current branch**, keep just that one bullet.
  ```

#### 5. `/tce:init` Idempotency

**File**: `plugins/tce/commands/init.md`
**Changes**: after the `## Dev environment` bullet (line 466) add:

```markdown
  - A `profile.md` without a `## Branch convention` section (added in tce 1.1.0)
    needs it inserted directly after `## Commit convention`. Do not assume a
    model: run the branch-convention dialog from Phase 2 and fill the section
    from the answer. **Current branch** is what the project effectively had so
    far, so it is the safe answer when in doubt.
```

#### 6. `/tce:refresh`

**File**: `plugins/tce/commands/refresh.md`
**Changes**:

- Scope statement (lines 27-33): after "are hand-authored and preserved." insert
  "So is `profile.md`'s `## Branch convention` — a branch model is team policy,
  not something re-analysis can verify against the repo; `/tce:init` adds it
  when a profile predates it."
- Line 86-88 parenthetical: extend to "(The `## Commit convention` section *is*
  refreshed — it is distinct from the free-form `## Conventions` block. The
  `## Branch convention` section is *not*: it is hand-authored, see Phase 2.)"
- Phase 2 hand-authored bullet (lines 102-105): "`profile.md`'s `## Conventions`
  and `## Preferred research sources`" → "`profile.md`'s `## Conventions`,
  `## Branch convention` and `## Preferred research sources`".
- Phase 3 (line 130-131): "Only offer to touch `## Conventions` / `## Preferred
  research sources`" → "Only offer to touch `## Conventions` / `## Branch
  convention` / `## Preferred research sources`".

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes.
- [x] `grep -c "## Branch convention" plugins/tce/templates/tce/profile.md` = 1,
      and it appears after `## Commit convention` and before `## Preferred
      research sources`.
- [x] `grep -n "Branch convention" plugins/tce/commands/init.md` shows hits in
      Phase 1 (gather item 10), Phase 2 (dialog), Phase 3 (refine list), Phase 4
      (fill list + paragraph) and Idempotency.
- [x] `grep -n "Branch convention" plugins/tce/commands/refresh.md` shows the
      scope, Phase 1 parenthetical, Phase 2 hand-authored and Phase 3 hits, and
      none in Phase 1's numbered gather items.
- [x] The `### AskUserQuestion dialog guidelines` block is byte-identical across
      the ten files (extract each block and `diff`).

#### Manual Verification:

- [ ] Dialog copy reads naturally in the AskUserQuestion UI (labels ≤5 words,
      headers ≤12 chars, plain text).

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (recorded in the closing hashes commit)
- **Did**: `## Branch convention` template section (after Commit convention); init gather
  item 10, two verbatim dialogs, refine list, Phase 4 fill paragraph, 1.1.0 Idempotency
  bullet; refresh scope + Phase 1 parenthetical + hand-authored list + Phase 3 offer.
- **Issues**: none
- **Verification**: ✅ `claude plugin validate ./plugins/tce`, ✅ section-order grep,
  ✅ init/refresh mention greps, ✅ 10/10 identical AskUserQuestion blocks (md5)

---

## Phase 3: `/tce:research` branch step and the composites

### Overview

Wire the `create` step into research at the right moment, and mirror it into
`work.md` and `quickfix.md`; pre-authorize the script in all three.

### Changes Required:

#### 1. `research.md`

**File**: `plugins/tce/commands/research.md`
**Changes**:

- Line 4 `allowed-tools`: append `, Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`.
- Ticket Document Discovery: insert a new item 3 after item 2 (line 93) and
  renumber the current item 3 ("Find related thoughts documents") to 4:

  ````markdown
  3. **Put the ticket's branch in place** — branch-per-ticket projects only. Read
     the `## Branch convention` section of `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`.
     If the section is absent, says **Current branch**, or this research has no
     ticket, skip this item entirely: stay on the current branch and print nothing.
     If it says **Branch per ticket**: resolve the branch name by substituting the
     canonical ticket ID into the recorded pattern (for a `<slug>` element, a short
     kebab-case slug of the ticket title), then run

     ```bash
     "${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" create <branch> <base> <remote>
     ```

     and act on its `result:` line — `created`, `switched`, `already`: continue
     (mention the branch in one line); `fetch-failed` or `no-remote`: stop and ask
     (dialog below), and only after the user confirms re-run the command with
     `--trust-local`; `dirty`: ask the user to commit or stash, then re-run;
     `invalid-name`, `missing-base`, `blocked`: report the `detail:` line and stop.
     Never cut the branch from anything else. Do this before anything is written or
     committed, so the branch recorded in the research frontmatter (step 5) is the
     ticket's branch.

     Stop-and-ask dialog (AskUserQuestion, following the guidelines above; **use
     this copy verbatim**, replacing the bracketed parts). Intro:

     ```
     tce could not bring the base branch [base] up to date from [remote]
     ([detail line]). The ticket branch must be cut from a current base, so I
     won't guess.
     ```

     Question: "How should I proceed with the base branch?" — header: "Base
     branch", options:

     1. **Local tip is current** — You have updated [base] yourself (or know it is
        current); cut [branch] from the local [base] now.
     2. **Stop here** — Nothing is created; the session stays on the current
        branch and you can update [base] first.
  ````

- Step 5 (line 252), the `Git branch:` bullet: append " (the branch step in
  Ticket Document Discovery ran before this, so under branch-per-ticket this is
  the ticket's branch)".

#### 2. `work.md`

**File**: `plugins/tce/commands/work.md`
**Changes**:

- Line 5 `allowed-tools`: append `, Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`.
- Phase 1a: insert a new item 2 after item 1 and renumber items 2–5 to 3–6:

  ```markdown
  2. **Put the ticket's branch in place** exactly as `/tce:research`'s Ticket
     Document Discovery specifies — branch-per-ticket projects only: skip silently
     when `profile.md` has no `## Branch convention` section or it says **Current
     branch**; otherwise resolve the branch name from the recorded pattern and run
     `"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" create <branch> <base> <remote>`,
     continuing on `created`/`switched`/`already`, asking the user with the
     research command's verbatim stop-and-ask dialog on `fetch-failed`/`no-remote`
     (re-run with `--trust-local` only after they confirm), asking them to commit
     or stash on `dirty`, and stopping with the `detail:` line otherwise. This is
     the other case where Phase 1 may interact.
  ```

  Since `work.md` re-describes research, include the dialog copy verbatim
  (intro, question, header, two options) right after this item, in the same
  fenced form as in `research.md`.
- Phase 1a item 4 (old): "this is the only case where Phase 1 interacts" → "this
  and the branch step are the only cases where Phase 1 interacts".
- Phase 1b: the "Gather git metadata" bullet → "Gather git metadata (under
  branch-per-ticket, the branch step already ran, so the recorded branch is the
  ticket's)".
- Phase 3a first bullet and Phase 4a item 2: append a sentence: "The branch step
  is likewise trivially satisfied in the same session; when resuming in a later
  session, run the `switch` step as `/tce:plan` / `/tce:implement` specify
  (`"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" switch <branch>` — stop and ask on
  `missing` or `dirty`)."
- "Interaction model" list (near the top): change "There are at most TWO
  interaction points" to name the branch step's stop-and-ask as part of point 1
  ("An upfront ticket sufficiency check — and, in branch-per-ticket projects, the
  branch step's stop-and-ask when the base cannot be fetched").

#### 3. `quickfix.md`

**File**: `plugins/tce/commands/quickfix.md`
**Changes**:

- Frontmatter: add `allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`
  after `disable-model-invocation: true`.
- Phase 3: insert a new item 2 after item 1 ("Read the ticket") and renumber
  items 2–6 to 3–7; grep `quickfix.md` for "Phase 3" cross-references to items by
  number and fix any:

  ```markdown
  2. **Put the ticket's branch in place** exactly as `/tce:research`'s Ticket
     Document Discovery specifies — branch-per-ticket projects only (skip silently
     when `profile.md` has no `## Branch convention` section or it says **Current
     branch**). Resolve the branch name from the recorded pattern and run
     `"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" create <branch> <base> <remote>`.
     `created`/`switched`/`already` → continue. `fetch-failed`/`no-remote` → this is
     the one place quickfix must pause: ask with the research command's verbatim
     stop-and-ask dialog and re-run with `--trust-local` only after the user
     confirms. `dirty` → ask the user to commit or stash, then re-run. Anything
     else → report the `detail:` line and stop. The ticket committed in Phase 2
     stays on the branch it was created on (normally the base) — ticket creation
     is never moved.
  ```

  Include the dialog copy verbatim after the item, as in `research.md`.
- Phase 6 Final Summary template: add an optional line after the ticket line:
  `**Branch:** [ticket branch and what it was cut from — only under branch-per-ticket]`.
- Important Rules: extend rule 3 ("Never push") with "— `branch.sh` fetches and
  creates local branches; nothing is pushed."

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes.
- [x] `grep -n 'scripts/branch.sh' plugins/tce/commands/{research,work,quickfix}.md`
      shows the `allowed-tools` entry and the invocation in each file.
- [x] The stop-and-ask dialog copy (intro, question, header, two option labels
      and descriptions) is identical in `research.md`, `work.md`, `quickfix.md`
      (extract and `diff`).
- [x] `research.md` numbered steps 1–10 are unchanged in number (`grep -n '^[0-9]*\. \*\*' plugins/tce/commands/research.md`
      lists the same ten headings as before) and no cross-reference in
      `research-document-template.md` needed changing.

#### Manual Verification:

- [ ] In a scratch project with **Current branch** (or no section), `/tce:research`
      produces the same output as before with no mention of branches.
- [ ] In a scratch project with **Branch per ticket** and a reachable remote,
      `/tce:research <id>` creates the branch before writing and the research
      frontmatter's `branch:` is the ticket branch; with the remote URL broken,
      the stop-and-ask dialog appears and "Stop here" leaves the repo untouched.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (recorded in the closing hashes commit)
- **Did**: research.md — `branch.sh` allowlist, new Ticket Document Discovery item 3
  (`create` step + verbatim stop-and-ask dialog), step 5 note; work.md — allowlist,
  interaction model, 1a item 2 + dialog, 1b metadata note, 3a/4a later-session `switch`
  notes; quickfix.md — allowlist, Phase 3 item 2 + dialog (items renumbered 3–7),
  summary `**Branch:**` line, rule 3.
- **Issues**: none
- **Verification**: ✅ validate tce, ✅ allowlist/invocation greps, ✅ 3/3 identical dialog
  copies (md5), ✅ research steps 1–10 unchanged, ✅ 10/10 AskUserQuestion blocks

---

## Phase 4: `/tce:plan`, `/tce:implement`, `/tce:review`, `/tce:commit`

### Overview

Wire the `switch` step into the three downstream readers and the `check` into
`/tce:commit`; pre-authorize the script in each.

### Changes Required:

#### 1. Shared `switch` step text

Insert this item into each command's Ticket Document Discovery **after** the
"Fetch the ticket's content" item and **before** "Find related thoughts documents"
(renumber the following items), adapting only the command name:

```markdown
N. **Switch to the ticket's branch** — branch-per-ticket projects only. Read the
   `## Branch convention` section of `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`.
   If the section is absent or says **Current branch**, skip this item entirely:
   stay on the current branch and print nothing. If it says **Branch per ticket**,
   resolve the branch name from the recorded pattern and the canonical ticket ID,
   then run `"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" switch <branch>` and act on
   its `result:` line: `switched` or `already` → continue (one line naming the
   branch); `missing` → stop and tell the user the ticket branch does not exist
   yet (`/tce:research` creates it) and wait; `dirty` → stop and ask the user to
   commit or stash their changes, then re-run; `blocked` → report the `detail:`
   line and stop. Never create the branch here. The ticket's research and plan
   documents live on that branch, so this must happen before the discovery
   script below.
```

**File**: `plugins/tce/commands/plan.md` — insert after item 2 (line 65) as item
3; renumber "Find related thoughts documents" to 4; line 4 `allowed-tools`:
append `, Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`.

**File**: `plugins/tce/commands/implement.md` — insert after item 2 (line 45)
as item 3; renumber "Find related thoughts documents" to 4; line 4
`allowed-tools`: append `, Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`.
Also in "When you receive a ticket number or plan path" (line 62), prefix item 1
with "(after the branch step above)".

**File**: `plugins/tce/commands/review.md` — Phase 1: insert as a new item 2
between "Fetch the ticket…" (item 1) and "Read all discovered documents" (item
2), renumbering 2–4 to 3–5; the discovery script currently sits inside item 1 —
split it: item 1 fetches the ticket, the new item 2 switches, item 3 runs the
discovery script and reads the documents. Line 5 `allowed-tools`: append
`, Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`. Custom (non-ticket)
reviews are unaffected.

#### 2. `commit.md`

**File**: `plugins/tce/commands/commit.md`
**Changes**:

- Frontmatter: add `allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)`
  after `description`.
- After checklist item g) (line 57) add:

  ```markdown
  ### h) Branch check (branch-per-ticket projects only)
  If the chat is about a ticket and the `## Branch convention` section of
  `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` says **Branch per ticket**, resolve
  the ticket's branch name from the recorded pattern and run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" check <branch> <base>`. On
  `on-branch`, continue silently. On `on-base`, `elsewhere` or `detached`, warn
  before committing — one plain sentence quoting the `detail:` line and stating
  that the convention puts this ticket's work on `<branch>` — and ask whether to
  commit here anyway or stop so the user can switch first; wait for the answer.
  This is a reminder, not enforcement: git hooks and forge rulesets are the
  project's business. Skip this item when the section is absent, says **Current
  branch**, or the commit is not about a ticket.
  ```

- Important list: after "NEVER run `git push`" add "- `branch.sh check` only
  reports; this command never creates or switches branches".

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes.
- [x] `grep -n 'scripts/branch.sh' plugins/tce/commands/{plan,implement,review,commit}.md`
      shows the `allowed-tools` entry and the invocation in each file
      (`switch` in plan/implement/review, `check` in commit).
- [x] TP-0017 classification unchanged: `grep -L disable-model-invocation plugins/tce/commands/{ticket,research,plan,implement,commit}.md`
      lists all five (no flag added to a delegation target).
- [x] The TP-0013 chain-order re-read instructions in plan/implement/review are
      intact (grep for "chain order" in each still matches).

#### Manual Verification:

- [ ] In a scratch branch-per-ticket project, `/tce:plan <id>` started on the base
      branch switches to the ticket branch before finding the research document;
      with the branch deleted it stops with the "does not exist yet" message.
- [ ] `/tce:commit` on the base branch in a ticket chat warns and waits; on the
      ticket branch it says nothing extra.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (recorded in the closing hashes commit)
- **Did**: `switch` step as Ticket Document Discovery item 3 in plan.md and implement.md
  (implement's read-order item 1 points back to it); review.md Phase 1 split into
  fetch / switch / discovery / read (items renumbered 1–7); commit.md pre-commit item h)
  `check` with prose warn-and-ask plus an Important bullet; `branch.sh` allowlisted in
  all four.
- **Issues**: none
- **Verification**: ✅ validate tce, ✅ allowlist/invocation greps (switch ×3, check ×1),
  ✅ no `disable-model-invocation` on the five delegation targets, ✅ chain-order greps

---

## Phase 5: Docs, governance rule, version bump, dogfooding

### Overview

Document the convention, record the same-commit span in `CLAUDE.md`, bump tce to
1.1.0, and give this repository its own (Current branch) section.

### Changes Required:

#### 1. `plugins/tce/README.md`

**Changes**:

- Line 156-161 Setup paragraph: "…conventions, and the **commit convention** tce
  should use — Conventional Commits, plain, or issue-reference, pre-selected from
  your git history) and detects…" → add after the commit-convention
  parenthetical: ", the **branch convention** (work on the current branch, or one
  branch per ticket cut from a fetched base)".
- Line 165 tree comment: "stack, commands, conventions, commit convention" →
  "stack, commands, conventions, commit + branch convention".
- After the "How project parameterization works" bullet on stack/commands
  (line 265-269) add a bullet:

  ```markdown
  - **Branch convention** — also in `profile.md`. **Current branch** (the
    default, and what a profile without the section means) leaves tce
    branch-unaware, exactly as before. **Branch per ticket** makes `/tce:research`
    cut the ticket's branch (name pattern + base branch + remote from the profile)
    from a freshly fetched base before it writes anything, `/tce:plan`,
    `/tce:implement` and `/tce:review` switch to it in later sessions, and
    `/tce:commit` warn before a ticket-scoped commit on the base branch. When the
    base cannot be fetched (offline, no remote) tce stops and asks rather than
    branching from another tip. Non-ticket work and ticket creation are never
    moved. tce still never pushes; the git steps live in
    `${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh`.
  ```

- Line 270-271 Scripts bullet: no change needed beyond the new bullet above.

#### 2. `CLAUDE.md` governance section

**File**: `CLAUDE.md`
**Changes**: add a new section after the TP-0020/TP-0030 gate section and before
the TP-0017 invocation-control section:

```markdown
## The branch convention spans one script and every command that acts on it (TP-0031)

`.claude/tce/profile.md`'s `## Branch convention` section (template:
`plugins/tce/templates/tce/profile.md`) is agreed at `/tce:init`, preserved as
**hand-authored** by `/tce:refresh` (a branch model is policy, not something
re-analysis can verify), and read at runtime. It has two options — **Current
branch** (the default; a profile without the section means exactly this and
produces byte-identical behaviour to a release without the feature) and **Branch
per ticket** (name pattern with the `<ticket-id>` placeholder, base branch,
remote). tce adapts to the repository, not the reverse (TP-0030): no branch
name, forge or merge strategy ships in plugin text.

The git work lives in exactly one shipped location, `plugins/tce/scripts/branch.sh`
(`create` / `switch` / `check`, three-line stdout contract, exit 0 for every
reported outcome — the `baseline.sh` pattern). The commands only decide whether
the convention applies, resolve the branch name, call the script, and act on its
`result:` line:

- `plugins/tce/commands/research.md` — `create`, in Ticket Document Discovery
  right after fetching the ticket and **before** the discovery script and before
  step 5 records `branch:` in the research frontmatter. Its stop-and-ask dialog
  (base branch cannot be fetched) is verbatim copy, duplicated into the two
  composites.
- `plugins/tce/commands/work.md` (Phase 1a, inline) and
  `plugins/tce/commands/quickfix.md` (Phase 3, inline) — **re-describe** the
  research step and carry the same dialog copy; both inherit the `switch` steps
  through Skill delegation / re-description of plan and implement.
- `plugins/tce/commands/plan.md`, `implement.md`, `review.md` — `switch`, in the
  same position (the ticket's documents live on the ticket branch, so this must
  precede `ticket.sh`); never create.
- `plugins/tce/commands/commit.md` — `check` as pre-commit item h); warns and
  asks in prose (no AskUserQuestion block in commit.md), never refuses.
- `plugins/tce/commands/init.md` (gather item 10, the two verbatim dialogs, refine
  list, Phase 4 fill, the 1.1.0 Idempotency bullet) and `refresh.md` (hand-authored,
  preserved) own the section's lifecycle, per the refresh-tracks-init rule above.

Every invoking command pre-authorizes the script with
`Bash("${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh":*)` in its `allowed-tools`; no raw
`git switch`/`git fetch` grants exist anywhere. Ticket creation (`/tce:ticket`,
quickfix Phase 2), `/tce:discuss`, `/tce:design_explore`, `/tce:init` and
`/tce:refresh` never branch — non-ticket work stays where the session is, and
tmt ticket files land on the branch the session is on (normally the base) so
numbering stays shared.

**RULE: When you change `branch.sh`'s modes, arguments or `result:` vocabulary,
update `research.md`, `plan.md`, `implement.md`, `review.md`, `commit.md`,
`work.md` and `quickfix.md` in the same commit; when you change the research
step or its dialog copy, update `work.md` and `quickfix.md` in the same commit
(the composite-tracking rule); when you change the section's options or
sub-fields, update the template, `init.md`'s dialogs + fill + Idempotency bullet,
`refresh.md`'s hand-authored list and `plugins/tce/README.md` together.** The
absent-section guard ("no section or Current branch → skip, print nothing") is
what keeps un-upgraded projects byte-identical — never weaken it.
```

Also update the TP-0017 section's user-only/delegation lists only if a flag
changed (none does), and the AskUserQuestion-block paragraph stays at "ten
commands" (commit.md asks in prose).

#### 3. Version bump

**File**: `plugins/tce/.claude-plugin/plugin.json:3` — `"version": "1.0.1"` →
`"version": "1.1.0"`.
**File**: `.claude-plugin/marketplace.json:15` — tce entry `"version": "1.0.1"`
→ `"version": "1.1.0"`.
Do **not** run `claude plugin tag`.

#### 4. Dogfood this repository's profile

**File**: `.claude/tce/profile.md`
**Changes**: line 1 marker `1.0.1` → `1.1.0`; insert after the `## Commit
convention` block (after line 79) and before `## Preferred research sources`:

```markdown
## Branch convention

Where tce puts a ticket's work. `/tce:init` agrees this with you and fills in the
chosen model; `/tce:research`, `/tce:plan`, `/tce:implement` and `/tce:review` (and
the composites `/tce:work` / `/tce:quickfix`) read it right after fetching the
ticket, and `/tce:commit` checks it before a ticket-scoped commit. Work without a
ticket and ticket *creation* are never moved: they stay on whatever branch the
session is on.

- **Current branch** — tce works on whatever branch the session is on and never
  creates or switches branches. (This repo always works on `main`; see
  `CLAUDE.md` Conventions.)
```

(Not adding `## Dev environment` — that is a separate pre-existing upgrade item
and out of this ticket's scope.)

#### 5. Sanity greps

- `grep -rn "github\|gitlab\|pull request\|merge request" plugins/tce/scripts/branch.sh plugins/tce/templates/tce/profile.md` → no hits (the only forge words allowed
  are in `init.md`'s pre-existing ticket-system detection).
- `grep -rn "TP-" plugins/tce/scripts/ plugins/tce/templates/` → no hits (the
  dialog examples in `init.md` use the same `TP-0001`-style illustrative examples
  the commit dialog already uses).

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes.
- [x] `claude plugin validate ./plugins/tce`, `./plugins/tmt`, `./plugins/tle` pass.
- [x] `grep -n '"version"' plugins/tce/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
      shows `1.1.0` for tce in both files.
- [x] `head -1 .claude/tce/profile.md` is `<!-- tce-config-version: 1.1.0 -->` and
      `grep -c "## Branch convention" .claude/tce/profile.md` = 1.
- [x] `grep -n "TP-0031" CLAUDE.md` finds the new section; `grep -c "branch.sh" CLAUDE.md` ≥ 3.
- [x] Sanity greps in item 5 return no hits.

#### Manual Verification:

- [ ] `plugins/tce/README.md` reads coherently top to bottom with the new bullet.
- [ ] Re-running `/tce:init` in a project stamped `1.0.1` walks through the
      Branch convention bullet (asks the dialog, inserts the section, updates the
      marker) — deferred to the next real use, like TP-0030's deferred items.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: (recorded in the closing hashes commit)
- **Did**: README setup paragraph, tree comment and parameterization bullet; CLAUDE.md
  TP-0031 same-commit-span section (before TP-0017); tce `1.0.1` → `1.1.0` in plugin.json
  and marketplace.json (no tag); this repo's profile marker `1.1.0` + `## Branch convention`
  = Current branch.
- **Issues**: none
- **Verification**: ✅ all four `claude plugin validate` runs, ✅ version greps, ✅ profile
  marker/section, ✅ CLAUDE.md greps (section at line 283, 4 `branch.sh` mentions),
  ✅ forge/prefix sanity greps empty

---

## Testing Strategy

### Unit Tests:

Script scenario matrix, run in a scratch directory under the session
scratchpad. Setup (once): create a bare repo `remote.git`, clone it to `proj`,
commit a file on `main`, push; `export CLAUDE_PROJECT_DIR=<proj>`; `B=<abs path>/plugins/tce/scripts/branch.sh`.

| # | Scenario | Command (in `proj`) | Expected `result:` |
|---|---|---|---|
| S1 | usage | `$B` / `$B create X` | exit 1, usage on stdout |
| S2 | not a repo | `CLAUDE_PROJECT_DIR=/tmp/empty $B check X main` | exit 1, error on stderr |
| S3 | create, fetch ok | `$B create FAKE-0001 main origin` | `created`; `git branch --show-current` = `FAKE-0001`; `git config branch.FAKE-0001.remote` empty (no tracking) |
| S4 | already | `$B create FAKE-0001 main origin` | `already` |
| S5 | switch existing | `git switch main`; `$B switch FAKE-0001` | `switched` |
| S6 | switch missing | `git switch main`; `$B switch FAKE-0002` | `missing` |
| S7 | dirty | `echo x >> file`; `$B switch FAKE-0001` | `dirty`; then `git checkout -- file` |
| S8 | fetch failed | `git remote set-url origin /nonexistent`; `$B create FAKE-0003 main origin` | `fetch-failed`; branch not created |
| S9 | trust local | `$B create FAKE-0003 main origin --trust-local` | `created` from local main |
| S10 | no remote | `git remote remove origin`; `$B create FAKE-0004 main` | `no-remote` |
| S11 | invalid name | `$B create 'bad..name' main origin` | `invalid-name` |
| S12 | check | on `main`: `$B check FAKE-0001 main` → `on-base`; on `FAKE-0001` → `on-branch`; `git switch -c other` → `elsewhere`; `git checkout --detach` → `detached` |
| S13 | remote-only branch | on a second clone create+push `FAKE-0005`; in `proj` `git fetch`; `$B switch FAKE-0005` | `switched` (tracking branch created) |

Every scenario also checks the output is exactly three lines and exit 0 (except
S1, S2).

### Integration Tests:

- `claude plugin validate .` and the three per-plugin validations after every
  phase that touches a manifest or command file.
- AskUserQuestion-block identity check across the ten files (Phase 2).
- Dialog-copy identity check across research/work/quickfix (Phase 3).

### Manual Testing Steps:

1. Scratch project with tmt + tce installed from this checkout, `/tce:init`
   choosing **Current branch**: run `/tce:research`, `/tce:plan`, `/tce:commit` on
   a ticket and confirm no branch-related output at all.
2. Same project, edit the profile to **Branch per ticket** (`<ticket-id>`, `main`,
   `origin`), with a reachable bare remote: `/tce:research <id>` creates the
   branch first; `git log` shows the research commit on the ticket branch;
   frontmatter `branch:` is the ticket branch.
3. Break the remote URL; `/tce:research <id2>` shows the stop-and-ask dialog;
   "Stop here" leaves no branch; re-run and pick "Local tip is current" creates
   from local `main`.
4. On `main` in a fresh session, `/tce:plan <id>` switches to the ticket branch
   before reading research; `/tce:commit` on `main` for the ticket warns.
5. Re-run `/tce:init` on a profile stamped `1.0.1`: the Idempotency walk-through
   offers the branch dialog and inserts the section.

## Performance Considerations

`branch.sh create` performs one `git fetch <remote> <base>` per ticket start;
HTTP transports get a 20-second low-speed cut-off, SSH relies on the user's SSH
configuration. All other calls are local ref lookups. No impact on projects
using **Current branch** or no section (the script is never called).

## Migration Notes

- Existing consuming projects: nothing changes until they re-run `/tce:init`
  (the 1.1.0 Idempotency bullet offers the section; **Current branch** preserves
  their behaviour) or add the section by hand.
- This repository: dogfoods **Current branch** (Phase 5).
- Release: the maintainer tags `tce--v1.1.0` with `claude plugin tag ./plugins/tce`
  when ready; consumers pick it up via `/plugin marketplace update toby-plugins`.

## References

- Original ticket: `thoughts/shared/tickets/TP-0031-declarable-branch-convention.md`
- Related research: `thoughts/shared/research/2026-09-03-TP-0031-declarable-branch-convention.md`
- Precedent (section lifecycle): `thoughts/shared/plans/2026-06-15-TP-0008-configurable-commit-convention.md`
- Precedent (shipped git script, allowlists): `thoughts/shared/plans/2026-09-02-TP-0030-drift-check-rewritten-history.md`,
  `plugins/tce/scripts/baseline.sh`
- Idempotency mechanics: `thoughts/shared/plans/2026-06-12-TP-0003-init-upgrade-migration.md`
- Refresh classification: `thoughts/shared/plans/2026-06-14-TP-0004-profile-drift-refresh.md`
