---
date: 2026-10-28
ticket: TP-0045f
intent: thoughts/shared/intents/2026-10-27-TP-0045f-ticketless-branch-and-delivery.md
research: thoughts/shared/research/2026-10-28-TP-0045f-ticketless-branch-and-delivery.md
status: draft
---

# TP-0045f: ticketless runs follow the branch convention and delivery — Implementation Plan

## Overview

TP-0045c decided that ticketless work never branches and is always delivered
Direct. In a Branch per ticket / Pull request project that puts a quickfix's
intent, research, plan, code and dossier on the base branch and skips the
project's review flow. This plan makes ticketless runs (`/tce:quickfix`, and
every step command or `/tce:work` given an intent path) follow the profile's
`## Branch convention` and `## Delivery` exactly as ticket runs do. The branch
name is the existing pattern with the intent's slug in place of the ticket ID.
Under Current branch / Direct (or with the sections absent) nothing changes.

## Current State Analysis

The rule lives in a handful of explicit overrides (research §1, §3, §4, §11):

- `plugins/tce/references/work-loop.md:116` — Step 2: "Ticketless: skip this
  step entirely and print nothing."
- `plugins/tce/references/work-loop.md:243-244` — Step 10: "Ticketless: always
  Direct, whatever the section says."; `:258-259` — the *no delivery* variant
  says "Direct (or ticketless)".
- `plugins/tce/references/work-loop.md:252` — the only pull-request title form,
  `"[PREFIX]-XXXX: <ticket title>"`.
- `plugins/tce/references/work-loop.md:81-85`, `:107-112` — the Entry greps the
  intent's `ticket:` line and Step 1 reads the intent, both **before** Step 2.
  An intent that lives only on its branch is not on disk while the session is
  on the base branch.
- `plugins/tce/commands/quickfix.md:5` (no `branch.sh`, `git push`, `gh pr`
  grants), `:16`, `:69-70` (Step 10 *no delivery*), `:83-87` (Resuming rests on
  "ticketless always Direct"), `:95-96` (Rule 3 "Never branch, push or
  deliver").
- `plugins/tce/commands/intent.md:76-78` (autonomous: "no branch step"),
  `:115-154` (branch step for ticket intents only; the one verbatim base-branch
  dialog), `:156-173` (existing-intent lookup; for (c)/(d) the slug is chosen
  here, after the branch step), `:394-433` (autonomous mode: slug at step 3,
  write at step 4, commit at step 5 with "There is no branch step").
- `plugins/tce/commands/commit.md:60-71` — item h) runs only "if the chat is
  about a ticket".
- `plugins/tce/scripts/branch.sh:11-20` — header names `/tce:intent` as the
  only `create` caller. `create` with `--trust-local` cuts from the local base;
  an existing branch of the same name is switched to, not refused
  (`branch.sh:130-163`).
- Docs: `plugins/tce/templates/tce/profile.md:73-78`, `:94` (still says
  "`/tce:research` creates the branch"), `:99-104`; `plugins/tce/README.md:223-227`,
  `:234`, `:395-410` (also still says `/tce:research` cuts the branch);
  `CLAUDE.md:322-333`, `:343-349`, `:393-398`, `:440-445`, `:480-490`.
- Release state: tce `1.5.1` in `plugins/tce/.claude-plugin/plugin.json:3` and
  `.claude-plugin/marketplace.json:15`; tags up to `tce--v1.5.1` exist.

## Desired End State

- Under **Branch per ticket**, every ticketless run works on
  `<pattern with <ticket-id> → slug, <slug> element dropped>`. `/tce:intent`
  (interactive ticketless, and `--autonomous`) cuts it before writing the
  intent, from the freshly fetched base, with the same stop-and-ask dialog as
  a ticket intent. The loop's Step 2 switches to it. A ticketless intent
  written before this release (no branch, committed on the base) gets its
  branch cut from the local base that holds it.
- Under **Pull request**, `/tce:quickfix` and a ticketless `/tce:work` push the
  branch and open a pull request titled with the intent's title and with the
  dossier as body. `/tce:research`, `/tce:plan`, `/tce:implement` on an intent
  path behave as for a ticket (`/tce:implement` records `undelivered:`).
- `/tce:commit` item h) warns before a ticketless commit off the ticketless
  branch.
- Under Current branch / Direct (or absent sections) every changed site hits
  the existing absent-section guard first and prints nothing new.
- CLAUDE.md, the tce README and the profile template describe this; tce is
  `1.6.0` in both manifests and the tag command is handed to the human.

Verify: the grep checks in each phase return what they say, `claude plugin
validate` passes for the marketplace and all four plugins, and the scratch-
project runs in the Manual items behave as stated.

### Key Discoveries:

- Autonomous mode fixes the slug at step 3 before it writes at step 4
  (`intent.md:414-428`), so a branch step fits between them and the intent
  becomes the branch's first commit.
- Autonomous mode runs inside `/tce:quickfix`'s turn (Skill call, no
  `context: fork` — TP-0045e research :90-94), so AskUserQuestion is available
  for the verbatim dialog. Whether `intent.md:4`'s grants apply during a Skill
  call is undocumented (issue #67198), so `quickfix.md` must grant `branch.sh`
  itself.
- `branch.sh create` switches to an existing same-named branch
  (`branch.sh:137-139`), and the autonomous slug glob only sees the current
  checkout (`intent.md:414-418`). An unmerged ticketless branch from an earlier
  run would be silently resumed unless the uniqueness check also covers branch
  names. `git rev-parse` is already granted in `quickfix.md:5`.
- `branch.sh`'s modes, arguments and `result:` vocabulary need no change, so
  the TP-0031 same-commit rule's trigger (script interface change) does not
  fire; only its header comment (callers) changes.
- Every behaviour change sits behind an existing absent-section guard
  (research "Option A"), which is what keeps Current branch / Direct
  byte-identical.

## What We're NOT Doing

- The four defects of TP-0045e.
- New profile options or sub-fields (no ticketless branch pattern), so no
  change to `init.md`'s dialogs, fill or Idempotency list, or to `refresh.md`.
- Any change to how ticket runs branch or deliver.
- Changes to `branch.sh`'s modes, arguments or `result:` vocabulary.
- `/tce:review` (it takes ticket references only) and its stale "`/tce:research`
  creates it" text (`review.md:117-129`).
- This repository's own `.claude/tce/profile.md` prose (Current branch here,
  so its "ticketless … never moved" wording stays true).

## Implementation Approach

Remove the ticketless overrides and let ticketless runs fall into the same
guarded paths as ticket runs, adding only what a ticketless run needs that a
ticket run does not: the name rule (slug for `<ticket-id>`, `<slug>` element
dropped), a branch step in autonomous mode, an Entry that copes with an intent
that lives only on its branch, a one-case `create` in the loop for intents
written before this release, and a ticketless pull-request title. Phase 1
changes behaviour (the loop and the commands that run it); Phase 2 changes
the documentation that states the old rule and releases.

Rejected: a separate ticketless code path in every command (its own branch
and delivery rules beside the ticket ones) — a second set of rules to keep in
sync, where removing the overrides lets the existing guarded paths serve both.

**Riskiest assumption:** the local base that holds a pre-1.6.0 ticketless
intent is current enough to cut its branch from. The old-intent `create` runs
with `--trust-local` and no fetch, so a stale local base would be used. That
is printed in one line, not silent, but it skips the base-branch dialog that
ticket runs get when the fetch fails.

**Ticketless branch name** (used verbatim in `work-loop.md` Step 2, `intent.md`
and `commit.md` h): substitute the intent's slug for `<ticket-id>` in the
recorded pattern; a `<slug>` element is dropped together with one adjoining
separator (`-`, `_` or `/`). So `<ticket-id>` → `fix-greeting-typo`,
`feature/<ticket-id>` → `feature/fix-greeting-typo`, `<ticket-id>-<slug>` →
`fix-greeting-typo`.

## Decisions

- **Ticketless runs follow the Branch convention and Delivery like ticket
  runs** — over TP-0045c's "ticketless never branches, always Direct": a
  quickfix landing on the base branch bypasses the project's review flow.
  *(yours)*
- **The rule applies to every ticketless run, not only `/tce:quickfix`** — over
  a quickfix-only exception: one rule in `work-loop.md`. *(yours)*
- **The branch name substitutes the intent's slug for the ticket ID in the
  existing pattern** — over a separate ticketless pattern: no new profile
  field. *(yours)*
- **Under Pull request delivery `/tce:quickfix` pushes and opens the pull
  request** — over branching only: a small fix ends reviewable in one command.
  *(yours)*
- **Its own sub-ticket of the epic** — over folding it into TP-0045e. *(yours)*
- **The autonomous intent cuts the quickfix's branch, between choosing the
  slug and writing** — over quickfix cutting it: the intent is the branch's
  first commit, `intent.md` keeps the dialog's one copy. *(yours)*
- **An interactive ticketless `/tce:intent` cuts its branch like a ticket
  intent** — over the loop creating it: one create site for new intents.
  *(yours)*
- **A ticketless intent with no branch (written before this release) gets its
  branch created from the base that holds it** — over refusing or working in
  place. *(yours)*
- **A pattern's `<slug>` element is dropped, with one adjoining separator, for
  a ticketless run** — over substituting the slug twice. *(yours)*
- **`/tce:commit`'s branch check also covers ticketless commits** — over
  keeping it ticket-only. *(yours)*
- **The old-intent branch is cut from the local base (`--trust-local`), with a
  printed line saying so** — over the freshly fetched remote base: an intent
  committed on the local base but never pushed would be missing from a branch
  cut from the remote, and "the base that now includes the intent" is the
  local one. *(decided for you)*
- **Autonomous mode asks the existing verbatim base-branch dialog itself** —
  over returning a new line for quickfix to ask: the intent's acceptance
  criterion says "stops and asks exactly as a ticket run does", the dialog
  keeps one copy, and the call runs in quickfix's turn. *(decided for you)*
- **Autonomous mode gets a third return line, `stopped: <reason>`, for a
  branch step that ends the run (Stop here, dirty tree, invalid name, missing
  base, blocked)** — over reusing `insufficient:`: the description was
  sufficient, and quickfix's stop message must say what actually happened.
  *(decided for you)*
- **The autonomous slug must also be unused as a branch name** (local branch
  and `<remote>`'s remote-tracking ref, via `git rev-parse --verify --quiet`)
  — over relying on the `thoughts/` glob only: `branch.sh create` would
  silently resume an unmerged ticketless branch of the same name.
  *(decided for you)*
- **For interactive ticketless input, the slug is chosen before the branch
  step and the existing-intent lookup runs after it** — over keeping today's
  order: the branch needs the slug, and an earlier intent with that slug lives
  on that branch, so the lookup finds it only after the switch.
  *(decided for you)*
- **The loop's Entry accepts an intent path that is not on the current
  checkout, under Branch per ticket only: it treats it as ticketless, switches
  by the filename's slug in Step 2, and reads the intent after the switch** —
  over requiring the session to be on the branch first: a re-run from the base
  branch (the normal case after `/tce:quickfix` stops) would otherwise refuse.
  *(decided for you)*
- **The ticketless pull-request title is the intent's `# Intent:` heading
  text** — over the slug or the dossier heading: it is the human-readable
  name the intent was agreed under. *(decided for you)*
- **`/tce:quickfix` grants `branch.sh`, `git push`, `gh pr create` and `gh pr
  view` in its own `allowed-tools`** — over relying on `intent.md`'s grant
  during the Skill call: Skill-call grant scoping is undocumented, and Step 10
  runs in quickfix's own turn. *(decided for you)*
- **The quickfix lane runs Step 10 in full, not in its *no delivery* variant**
  — over keeping *no delivery* and leaving `undelivered:` for `/tce:work`:
  follows from your Pull request decision; under Direct both give the same
  `direct:` reference. *(decided for you)*
- **The stale "`/tce:research` creates the branch" lines in the profile
  template and README are corrected to `/tce:intent` while those paragraphs
  are rewritten** — over leaving them: they sit in the same sentences this
  ticket rewrites. *(decided for you)*
- **No `init.md` Idempotency bullet for 1.6.0** — over adding one: no config
  content changes; only template prose does, and nothing reads that prose to
  decide behaviour. *(decided for you)*
- **Version 1.6.0** — over 1.5.2: a behaviour change for Branch per ticket
  and Pull request projects, not a fix. *(decided for you)*
- **Not in scope: `/tce:review` and its stale `missing` text** — over fixing
  it here: it takes ticket references only and is not a ticketless run.
  *(decided for you)*

## Phase 1: Ticketless runs branch and deliver

### Overview

The loop, `/tce:quickfix`, `/tce:intent` and `/tce:commit` treat ticketless
runs like ticket runs behind the existing guards; `branch.sh`'s header names
the new callers. One commit (the TP-0031 span's command files move together).

### Changes Required:

#### 1. The loop

**File**: `plugins/tce/references/work-loop.md`
**Changes**:

- **Entry (:81-85).** Keep the existing bullet. Add: if the path is not on the
  current checkout and `profile.md`'s `## Branch convention` says **Branch per
  ticket**, treat the run as ticketless with `<ID>` = the filename's slug and
  defer reading its `ticket:` line to the end of Step 2; otherwise (no file,
  any other convention) refuse with the existing "Anything else" message.
- **Step 1 (:107-112).** Ticketless: "read the intent at the end of Step 2
  instead — it may live only on its branch."
- **Step 2 (:114-127).** Delete ":116 Ticketless: skip this step entirely and
  print nothing." The guard ("absent or **Current branch** → skip, print
  nothing") stays first and now covers ticketless runs too. Name resolution:
  ticket runs as today; ticketless runs use the ticketless branch name (see
  Implementation Approach). `switch` results as today, except `missing` for a
  ticketless run:
  - the intent file is on the current checkout (an intent written before tce
    1.6.0, committed where the session is) → run
    `"${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh" create <branch> <base> <remote> --trust-local`;
    `created` → print one line: "Cut <branch> from the local <base>, which
    holds this intent (written before tce 1.6.0)."; `dirty` → ask to commit or
    stash, then re-run; any other result → report `detail:` and stop. If the
    intent file is not on disk after the switch, stop: "<branch> does not
    contain <path>; switch to the branch that holds the intent and re-run
    <command> <argument>."
  - otherwise → refuse: "No intent at <path> — write one with `/tce:intent`."
  Then, ticketless: read the intent fully now; if its `ticket:` line is not
  `none`, refuse: "<path> is <ID>'s intent — run <command> <ID>."
- **Step 10 (:243-244).** Delete "Ticketless: always Direct, whatever the
  section says." In the Pull request bullet (:252), the `--title` is
  `"[PREFIX]-XXXX: <ticket title>"` for a ticket run and `"<intent title>"`
  (the intent's `# Intent: ` heading, prefix stripped) for a ticketless run.
- **No-delivery variant (:258-259).** "Direct (or ticketless) →" becomes
  "Direct →".

#### 2. `/tce:quickfix`

**File**: `plugins/tce/commands/quickfix.md`
**Changes**:

- `:5` `allowed-tools`: add `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh:*)`,
  `Bash(git push:*)`, `Bash(gh pr create:*)`, `Bash(gh pr view:*)` (the same
  entries `work.md:5` carries).
- `:16` "Nothing is branched, pushed or delivered." → "Branching and delivery
  follow the profile, as for a ticket: under Branch per ticket the work lives
  on its own branch, under Pull request it ends with an open pull request."
- Section 2 (:41-57): the reading rule's prefixes become `intent:`,
  `insufficient:` or `stopped:`; add a bullet:
  `stopped: <line>` → stop: "Stopped before the intent was written: <line>.
  Nothing was written. Re-run `/tce:quickfix` once that is resolved."
- Lane (:69-70): "10 in its *no delivery* variant" → "10 — delivery".
- Resuming (:86-87): "For a ticketless intent `/tce:work` always delivers
  Direct, so it resumes exactly where this run stopped." → "`/tce:work`
  follows the same branch convention and delivery, so it resumes exactly where
  this run stopped."
- Rule 3 (:95-96) → "**Branch and deliver only as the profile says** — the
  branch convention and delivery apply exactly as for a ticket; under Current
  branch and Direct the work stays where the session is."

#### 3. `/tce:intent`

**File**: `plugins/tce/commands/intent.md`
**Changes**:

- `:4` `allowed-tools`: add `Bash(git rev-parse:*)` (for the autonomous
  branch-name uniqueness check when the grant applies; quickfix grants it too).
- `:76-78`: "no dialogue, no branch step, no confirmation" → "no dialogue and
  no confirmation; its branch step is in that section".
- `:115` heading → "## Put the branch in place". `:117-120`: the step now
  applies to (a), (b) and ticketless (c)/(d); skip only when the section is
  absent or says **Current branch**. Name: ticket intents as today; ticketless
  ones use the ticketless branch name (slug for `<ticket-id>`, `<slug>`
  element dropped with one adjoining separator). For (c)/(d) choose the slug
  you will use **now**, before this step. For (b) ticketless, the slug is the
  filename's, and a `switch` → `missing` with the intent file on disk is
  handled as in `work-loop.md` Step 2 (create with `--trust-local`, one line)
  — use `switch` first for (b), `create` for new intents. The results list,
  the "before the existing-intent lookup" timing and the dialog stay
  unchanged; replace "which `/tce:research` later finds in place" with "which
  the step commands later switch to".
- `:163-164` (c)/(d): "check `thoughts/shared/intents/*-<slug>.md` for the slug
  you chose before the branch step" (the lookup runs on that branch).
- Autonomous mode (:394-433):
  - `:396-398`: "Ask nothing" → "Ask nothing, except the base-branch dialog of
    'Put the branch in place' when the base cannot be fetched". The single
    output line may also be `stopped: <reason>`.
  - Step 3 Slug: after the glob, resolve the ticketless branch name (Branch
    per ticket only) and also lengthen the slug while
    `git rev-parse --verify --quiet refs/heads/<branch>` or
    `git rev-parse --verify --quiet refs/remotes/<remote>/<branch>` succeeds.
  - New step between 3 and 4, **Branch**: run "Put the branch in place" for
    this ticketless intent with `create` (skip it when the section is absent
    or says Current branch). `created` / `already` → continue; `fetch-failed`
    / `no-remote` → the verbatim dialog, then `--trust-local` on **Local tip
    is current**, or return `stopped: you chose to update <base> first` on
    **Stop here**; `switched` → return `stopped: branch <branch> already
    exists` (the uniqueness check should have prevented it); `dirty` → return
    `stopped: uncommitted changes — commit or stash them`; `invalid-name`,
    `missing-base`, `blocked` → return `stopped: <detail line>`. Renumber the
    following steps.
  - Commit step (:429-431): delete "There is no branch step — ticketless work
    stays on the current branch."

#### 4. `/tce:commit` item h)

**File**: `plugins/tce/commands/commit.md`
**Changes** (:60-71): "If the chat is about a ticket" → "If the chat is about
a ticket or a ticketless intent"; the branch name for a ticketless intent is
the recorded pattern with the intent's slug (filename minus `YYYY-MM-DD-` and
`.md`) for `<ticket-id>` and a `<slug>` element dropped with one adjoining
separator; the warning says "this intent's work" instead of "this ticket's
work" then. The skip sentence becomes "…or the commit is about neither a
ticket nor a ticketless intent."

#### 5. `branch.sh` header

**File**: `plugins/tce/scripts/branch.sh`
**Changes** (comment only, :3 and :11-20): "Put a ticket's branch in place" →
"Put a ticket's (or ticketless intent's) branch in place"; `create` — "for
/tce:intent (ticket and ticketless intents), and for work-loop.md Step 2 when
a ticketless intent written before tce 1.6.0 has no branch (always
--trust-local)". No code change.

### Success Criteria:

#### Automated Verification:

- [x] Marketplace validates: `claude plugin validate .` (repo root)
- [x] Each plugin validates: `claude plugin validate ./plugins/tce`,
      `claude plugin validate ./plugins/tmt`, `claude plugin validate ./plugins/tle`,
      `claude plugin validate ./plugins/tsf`
- [x] Script still parses: `bash -n plugins/tce/scripts/branch.sh`
- [x] `grep -n "Ticketless: skip this step\|Ticketless: always Direct\|Direct (or ticketless)" plugins/tce/references/work-loop.md` prints nothing
- [x] `grep -n "Never branch, push or deliver\|Nothing is branched\|always delivers Direct" plugins/tce/commands/quickfix.md` prints nothing
- [x] `grep -n "There is no branch step\|no branch step, no confirmation" plugins/tce/commands/intent.md` prints nothing
- [x] `sed -n 5p plugins/tce/commands/quickfix.md | grep -o "branch.sh:\*\|git push:\*\|gh pr create:\*\|gh pr view:\*" | wc -l` prints `4`
- [x] `grep -n "stopped:" plugins/tce/commands/intent.md plugins/tce/commands/quickfix.md` shows the return line in both
- [x] The base-branch dialog has exactly one copy: `grep -rn "How should I proceed with the base branch" plugins/tce` prints one line (in `intent.md`)
- [x] The AskUserQuestion guidelines block in `intent.md` and `work-loop.md` is unchanged: `git diff <base-commit> -- plugins/tce/commands/intent.md plugins/tce/references/work-loop.md` shows no hunk inside `### AskUserQuestion dialog guidelines`
- [x] `branch.sh` code is unchanged: `git diff <base-commit> -- plugins/tce/scripts/branch.sh` touches only lines starting with `#`

#### Manual Verification:

- [x] Branch per ticket + Direct, scratch project with a local bare remote
      (`git init --bare`, profile with Branch per ticket, pattern
      `<ticket-id>-<slug>`): `/tce:quickfix "<small fix>"` ends on branch
      `<slug>`; `git log <base>` shows no new commit; the intent, research,
      plan, code and dossier commits are on `<slug>`; Closeout says
      `direct: <slug> @ <sha>`. — verified by agent, see ## Verification
- [x] Same project with the remote made unreachable: `/tce:quickfix` asks the
      "Base branch" dialog before writing anything; **Stop here** prints the
      `stopped:` message and leaves no commit and no branch. — verified by agent, see ## Verification
- [x] A ticketless intent committed on the base before the change (no branch):
      `/tce:work <intent path>` prints the "Cut … from the local …" line and
      continues on the new branch. — verified by agent, see ## Verification
- [x] Current branch (this repository, or the scratch project without the
      sections): `/tce:quickfix` and `/tce:work <intent path>` print no branch
      line, stay on the current branch, and the Closeout says
      `direct: <branch> @ <sha>` — as in tce 1.5.0. — verified by agent, see ## Verification

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `13fbe848718073f070f7b351bbb1ba6718b39745`
- **Commit**: `04c6285` feat(TP-0045f): ticketless runs follow branch convention and delivery
- **Did**: work-loop.md Entry/Steps 1-2/10 (ticketless branch name, old-intent create, intent title as PR title); quickfix.md grants, `stopped:`, full Step 10; intent.md branch step for ticketless + autonomous Branch step; commit.md h); branch.sh header
- **Issues**: intent.md (b) with a ticketless intent not on the checkout had no reading rule → added: ticket from filename, else slug, read after the branch step
- **Verification**: ✅ validate x5, ✅ bash -n, ✅ 9 grep/diff checks
- **Fix rounds**: 0/3

---

## Phase 2: Documentation and release

### Overview

Every place that states "ticketless never branches / always Direct" says the
new rule; tce is bumped to 1.6.0 and the tag command handed to the human.

### Changes Required:

#### 1. Repository instructions

**File**: `CLAUDE.md`
**Changes**:

- `:322-325`: `intent.md` is "the `create` site for new intents — ticket and
  ticketless, `--autonomous` included — before the existing-intent lookup";
  delete "Ticketless intents — including `--autonomous` ones — never branch."
- `:326-333`: Step 2 runs `switch` for every loop command including
  `/tce:quickfix`; it creates in one case only — a ticketless intent written
  before tce 1.6.0 that has no branch, cut from the local base with
  `--trust-local`; otherwise `missing` refuses.
- `:343-349`: drop `/tce:quickfix` from the never-branch list; "non-ticket
  work" → "work that is neither a ticket nor a ticketless intent".
- Add one sentence to the TP-0031 section: the ticketless branch name is the
  pattern with the slug for `<ticket-id>` and a `<slug>` element dropped with
  one adjoining separator, stated in `work-loop.md`, `intent.md` and
  `commit.md`.
- `:396-398`: "only `/tce:work` delivers" → "`/tce:work` and `/tce:quickfix`
  deliver"; delete "and ticketless runs are always Direct".
- `:443-445`: "granted only in `work.md`'s own `allowed-tools`" → "granted only
  in `work.md`'s and `quickfix.md`'s own `allowed-tools`, for delivery — the
  other lanes never deliver."
- `:480-490` Ticketless naming span: add that the Autonomous mode's
  uniqueness rule also covers branch names.

#### 2. Consumer README

**File**: `plugins/tce/README.md`
**Changes**: `:223-227` "no branch is cut, no ticket is closed, and
`/tce:work` delivers Direct" → "no ticket is closed, and branching and
delivery follow the profile as for a ticket (the branch is named with the
slug in place of the ticket ID)"; `:234` quickfix row "no ticket, no branch,
no delivery" → "no ticket; branches and delivers as the profile says";
`:395-410` Branch convention paragraph: `/tce:intent` (not `/tce:research`)
cuts the branch, ticketless intents get one too, "Non-ticket work" →
"Other non-ticket work", and "Only `/tce:work` under **Pull request** delivery
pushes" → "`/tce:work` and `/tce:quickfix` push under **Pull request**".
Delivery paragraph: `/tce:quickfix` acts on it too.

#### 3. Profile template

**File**: `plugins/tce/templates/tce/profile.md`
**Changes**: `:73-78` — ticketless intents and `/tce:quickfix` follow the
convention like tickets; discussions, design explorations, config, chores and
ticket *creation* are never moved. `:87-90` Branch name: add "for a
ticketless intent, `<ticket-id>` is the intent's slug and a `<slug>` element
is dropped". `:94` "`/tce:research` creates the branch" → "`/tce:intent`
creates the branch". `:99-104` Delivery intro: "a ticket's finished work" →
"a ticket's (or ticketless intent's) finished work"; `/tce:work` and
`/tce:quickfix` read it. Options and sub-fields unchanged.

#### 4. Version bump

**Files**: `plugins/tce/.claude-plugin/plugin.json:3`,
`.claude-plugin/marketplace.json:15`
**Changes**: `1.5.1` → `1.6.0` in both. Run
`claude plugin tag --dry-run ./plugins/tce`, then hand the human
`claude plugin tag ./plugins/tce` (bump commit is HEAD) or
`git tag -s tce--v1.6.0 <sha> -m "tce 1.6.0"`.

### Success Criteria:

#### Automated Verification:

- [x] Marketplace validates: `claude plugin validate .` (repo root)
- [x] Each plugin validates: `claude plugin validate ./plugins/tce`,
      `claude plugin validate ./plugins/tmt`, `claude plugin validate ./plugins/tle`,
      `claude plugin validate ./plugins/tsf`
- [x] `claude plugin tag --dry-run ./plugins/tce` succeeds and names `tce--v1.6.0`
- [x] `grep -n "never branch\|always Direct\|no branch is cut\|no branch, no delivery" CLAUDE.md plugins/tce/README.md plugins/tce/templates/tce/profile.md` prints no line about ticketless runs
- [x] `grep -n '"version": "1.6.0"' plugins/tce/.claude-plugin/plugin.json .claude-plugin/marketplace.json` prints two lines
- [x] `grep -n "/tce:research\` creates the branch\|makes \`/tce:research\`" plugins/tce/README.md plugins/tce/templates/tce/profile.md` prints nothing

#### Manual Verification:

- [ ] Pull request delivery in a scratch GitHub repository (Branch per ticket +
      Pull request, `gh` authenticated): `/tce:quickfix "<small fix>"` ends
      with an open pull request from `<slug>` into the base, titled with the
      intent's `# Intent:` title, body equal to the dossier. Needs a real
      GitHub repository and credentials.
- [ ] The human creates the tag outside the sandbox and confirms with
      `git tag --list 'tce--v1.6.0'` and `git tag -v tce--v1.6.0`.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `6672861` docs(TP-0045f): describe ticketless branching and release tce 1.6.0
- **Did**: CLAUDE.md TP-0031/intent/Delivery/orchestrator/ticketless-naming text; README ticketless, quickfix row, Branch convention and Delivery paragraphs; profile template Branch convention + Delivery prose; tce 1.5.1 → 1.6.0 in both manifests; fix round 1: README step-commands list (quickfix "without delivery" → delivers as the profile says)
- **Issues**: tag dry-run refuses uncommitted changes → run after the commit; CLAUDE.md intent section's "one `create` site" also reworded (loop's old-intent create); verifier items 4/10: README:277-278 still said quickfix runs "without delivery" → reworded (fix round 1, validate x5 + grep green)
- **Verification**: ✅ validate x5, ✅ 3 grep checks, ✅ version grep, ✅ tag dry-run (tce--v1.6.0; tag handed to the human: `git tag -s tce--v1.6.0 6672861 -m "tce 1.6.0"`)
- **Fix rounds**: 0/3
- **Final fix rounds**: 1/3

---

## Testing Strategy

### Unit Tests:

- There is no test suite; `claude plugin validate` and the grep checks above
  are the automated layer. `branch.sh` is unchanged in code, so its existing
  behaviour (`create --trust-local`, `switch` → `missing`) needs no new smoke
  test; the verifier may still run it against a scratch repo.

### Integration Tests:

- The scratch-project runs in Phase 1 and Phase 2 Manual Verification: Branch
  per ticket + Direct with a local bare remote, the unreachable-remote dialog,
  the pre-1.6.0 intent, Current branch unchanged, and Pull request on GitHub.

### Manual Testing Steps:

1. `mkdir` a scratch project, `git init`, add a bare remote, run `/tmt:init`
   and `/tce:init` choosing Branch per ticket (`<ticket-id>-<slug>`) and
   Direct; start Claude Code with `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` and
   `BASH_DEFAULT_TIMEOUT_MS=600000`; run `/tce:quickfix` on a one-line fix;
   check `git branch --show-current` and `git log <base>`.
2. Remove the remote and repeat: the Base branch dialog appears.
3. Commit a ticketless intent on the base by hand, then `/tce:work <path>`.
4. In this repository (Current branch), run `/tce:quickfix` on a trivial fix
   and check the Closeout's `direct: main @ <sha>`.

## Performance Considerations

None — one extra `branch.sh` call and two `git rev-parse` checks per
ticketless run under Branch per ticket.

## Migration Notes

Ticketless intents written under Branch per ticket before 1.6.0 sit on the
base branch with no branch. The loop's Step 2 (and `/tce:intent` on such a
path) cuts their branch from the local base with `--trust-local` and says so
in one line. No config migration; un-upgraded profiles (no Branch convention
or Delivery section) behave exactly as before.

## References

- Original ticket: `thoughts/shared/tickets/TP-0045f-ticketless-branch-and-delivery.md`
- Intent: `thoughts/shared/intents/2026-10-27-TP-0045f-ticketless-branch-and-delivery.md`
- Related research: `thoughts/shared/research/2026-10-28-TP-0045f-ticketless-branch-and-delivery.md`
- Where the old rule was decided: `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md` (:319, :332, :565, :575-576)
- Similar implementation: ticket-intent branch step `plugins/tce/commands/intent.md:115-154`; delivery `plugins/tce/references/work-loop.md:241-266`

## Verification

Baseline: `13fbe848718073f070f7b351bbb1ba6718b39745` (recorded) · suites: ✅ `claude plugin validate .`, ✅ `claude plugin validate ./plugins/tce`, ✅ `./plugins/tmt`, ✅ `./plugins/tle`, ✅ `./plugins/tsf`, ✅ `bash -n` on every `plugins/tce/scripts/*.sh`

Scratch-project runs used headless `claude -p` with `--plugin-dir plugins/tce`, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` and `BASH_DEFAULT_TIMEOUT_MS=600000`, in throwaway git repos with a local bare remote.

- 1. Under Branch per ticket, a ticketless run works on its own branch and no commit of the run lands on the base branch — met — ran `/tce:quickfix` (Branch per ticket, `<ticket-id>-<slug>`, Direct): all 8 commits (intent, research, plan, fix, logs, dossier, closeout) are on `fix-greeting-hello-typo`; `git log main` and the remote's `main` still show only `init`
- 2. Under Pull request delivery, `/tce:quickfix` and a ticketless `/tce:work` push the branch and open a pull request — met — ran `/tce:quickfix` under Pull request with a recording fake `gh`: `origin` got `fix-greeting-hello-typo`, and `gh pr create --base main --head fix-greeting-hello-typo …` was called; the Closeout's Merge reference is the returned PR URL. `/tce:work` uses the same Step 10 (`plugins/tce/references/work-loop.md:268-281`). A real GitHub PR is in "For you to check"
- 3. Under Current branch / Direct (or with the sections absent), behaviour is unchanged from tce 1.5.0 — met — see 27
- 4. CLAUDE.md and the tce README describe the new ticketless behaviour — not met — `plugins/tce/README.md:277-278` still says "`/tce:quickfix` runs all of it from a description, without the approval and without delivery.", which contradicts `README.md:235` and `:401-415` and the new behaviour (quickfix now runs Step 10 in full and pushes under Pull request)
- 5. tce version bumped and tagged — met (bump) / for you to check (tag) — `plugins/tce/.claude-plugin/plugin.json:3` and `.claude-plugin/marketplace.json:15` say `1.6.0`; `git tag --list 'tce--v*'` ends at `tce--v1.5.1`
- 6. Ticketless run on the pattern's branch with the slug for the ticket ID; intent, research, plan, code and dossier commits all on it — met — ran: pattern `<ticket-id>-<slug>` gave branch `fix-greeting-hello-typo` (= intent slug, `<slug>` element dropped); every run commit is on it, none on `main`
- 7. Under Pull request, quickfix / ticketless work push and open a PR with the dossier as body; research/plan/implement behave as for a ticket — met — ran (fake `gh`): `--body-file thoughts/shared/dossiers/2026-10-28-fix-greeting-hello-typo.md`, and the captured body is byte-identical (`cmp`) to the committed dossier; no-delivery Pull request gives `undelivered:` (`plugins/tce/references/work-loop.md:287-289`)
- 8. When the base cannot be brought up to date, a ticketless run stops and asks; never cuts silently from a stale base — met — ran `/tce:quickfix` with `origin` at a non-existent path: `branch.sh create` → `fetch-failed`, the run asked "How should I proceed with the base branch?" (Local tip is current / Stop here) before writing anything; HEAD and branches unchanged
- 9. Under Current branch and Direct (or sections absent), ticketless runs behave byte-identically to tce 1.5.0 — met — see 27; every new branch/delivery path sits behind the absent-section guard (`work-loop.md:121-123`, `:85-90`; `intent.md:121-125`)
- 10. CLAUDE.md's TP-0031 and Delivery rules no longer say ticketless never branches / always Direct, and the README describes the ticketless behaviour — not met — the CLAUDE.md part is met (`CLAUDE.md:322-325`, `:401-402`); the README part fails on `plugins/tce/README.md:277-278` ("without delivery"), as in 4
- 11. `claude plugin validate` passes for the marketplace and all four plugins — met — ran all five: each `✔ Validation passed`, exit 0 (the LICENSE/icon notes are directory-profile advisories that do not change the result)
- 12. tce version bumped in both manifests and tagged — met (bump) / for you to check (tag) — as 5
- 13. Marketplace validates — met — ran `claude plugin validate .`: passed, exit 0
- 14. Each plugin validates — met — ran the four: passed, exit 0 each
- 15. Script still parses: `bash -n plugins/tce/scripts/branch.sh` — met — ran: exit 0
- 16. work-loop grep prints nothing — met — ran: no output, exit 1
- 17. quickfix grep prints nothing — met — ran: no output, exit 1
- 18. intent grep prints nothing — met — ran: no output, exit 1
- 19. `sed -n 5p … | wc -l` prints `4` — met — ran: `4`
- 20. `stopped:` in both files — met — ran: `plugins/tce/commands/intent.md:422`, `:451-454`; `plugins/tce/commands/quickfix.md:44`, `:58`
- 21. Base-branch dialog has one copy — met — ran: one line, `plugins/tce/commands/intent.md:169`
- 22. AskUserQuestion guidelines block unchanged — met — ran: extracted each block at the baseline and at head and diffed — identical in `intent.md` (`:52`) and `work-loop.md` (`:31`); no diff hunk inside either block
- 23. `branch.sh` diff touches only `#` lines — met — ran: no changed line outside `#` comments
- 24. (MANUAL) Branch per ticket + Direct quickfix — met — ran `/tce:quickfix "Fix the typo …"`: ended on `fix-greeting-hello-typo`; `git log main` = `init` only; intent `7f1abf4`, research `46c31c9`, plan `cc58dd1`, fix `ec0affa`, dossier `7b27c42` all on the branch; Closeout `direct: fix-greeting-hello-typo @ 7b27c42`
- 25. (MANUAL) Unreachable remote: dialog, Stop here — met — ran: the Base branch question came after the slug and branch-name uniqueness checks and before any write (HEAD `52e4048` unchanged, no new branch, clean tree); resumed the session with "Stop here" → printed exactly "Stopped before the intent was written: you chose to update main first. Nothing was written. Re-run `/tce:quickfix` once that is resolved."; still no commit and no branch. Headless mode has no AskUserQuestion, so the question was rendered in prose; its wording and options matched the verbatim dialog
- 26. (MANUAL) Pre-1.6.0 ticketless intent — met — ran `/tce:work thoughts/shared/intents/2026-10-20-farewell-capital.md` with the intent committed on `main` and no branch: printed "Cut farewell-capital from the local main, which holds this intent (written before tce 1.6.0)." and "farewell-capital: continuing at research"; research `1a90f1f` landed on `farewell-capital`, `main` unchanged
- 27. (MANUAL) Current branch — met — ran in a scratch project without the Branch convention and Delivery sections: `/tce:quickfix` stayed on `main`, created no branch, Closeout `direct: main @ ba3ef42`; `/tce:work <intent path>` printed no branch line, ran no `branch.sh` command and stayed on `main` through research and planning (it stopped at plan approval, which headless mode cannot answer; its Step 10 Direct path is the one quickfix exercised)
- 28. Marketplace validates — met — as 13
- 29. Each plugin validates — met — as 14
- 30. `claude plugin tag --dry-run ./plugins/tce` names `tce--v1.6.0` — met — ran: "✔ Dry run — would create tag tce--v1.6.0 at HEAD", exit 0
- 31. grep prints no line about ticketless runs — met — ran: only `CLAUDE.md:334` (the agents never branch) and `CLAUDE.md:348` (non-intent commands never branch), neither about ticketless runs
- 32. `"version": "1.6.0"` in both manifests — met — ran: `plugins/tce/.claude-plugin/plugin.json:3`, `.claude-plugin/marketplace.json:15`
- 33. stale `/tce:research` branch-creation grep prints nothing — met — ran: no output, exit 1
- 34. (MANUAL) Pull request delivery on a scratch GitHub repository — for you to check — see below; everything up to the `gh` boundary was run (see 2 and 7)
- 35. (MANUAL) The human creates and verifies the tag — for you to check — see below

For you to check:
- 34. Real pull request on GitHub — in a scratch GitHub repository whose profile has Branch per ticket (`<ticket-id>-<slug>`, base `main`, remote `origin`) and Pull request delivery, with `gh auth status` green, run `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 BASH_DEFAULT_TIMEOUT_MS=600000 claude --plugin-dir /Users/toby/code/work/toby-plugins/plugins/tce` and `/tce:quickfix "<small fix>"`. Pass looks like an open pull request from `<slug>` into `main` titled with the intent's `# Intent:` text, with the dossier as its body (`gh pr view <slug> --json title,body,state`). Push, title, head/base and body file were all observed against a local bare remote and a recording fake `gh`. This needs a real GitHub repository and credentials, which this session does not have.
- 5 / 12 / 35. Tag — the bump commit `6672861` is not HEAD, so run outside the sandbox: `git tag -s tce--v1.6.0 6672861 -m "tce 1.6.0"`, then `git tag --list 'tce--v1.6.0'` (prints the tag) and `git tag -v tce--v1.6.0` (good signature). Tag signing needs your personal key, which the sandbox denies (CLAUDE.md "Releasing").
