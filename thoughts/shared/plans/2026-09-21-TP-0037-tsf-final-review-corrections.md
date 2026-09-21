# TP-0037: tsf final-review corrections Implementation Plan

## Overview

Fix the three contradictions TP-0037 names (C1 unresumable `blocked` state,
C2 dispatcher-authored pull-request/addendum text, C3 unexecutable failed-manual
route) plus the same-class instances research found and the user accepted into
scope on 2026-09-21: the twice-invalid journal shape, blocked implement in
rework/fix mode, a resumed landing skipping its decision cycle, and three more
places pull-request text passes through the dispatcher. Ships as tsf 1.1.1.

## Current State Analysis

See `thoughts/shared/research/2026-09-21-TP-0037-tsf-final-review-corrections.md`.
In short:

- `result-block.md:90` has a wildcard `blocked` row yielding out-of-vocabulary
  `verify-fix` / `manual-verify`; `journal-entry.md:204` repeats the hole for
  twice-invalid returns; blocked rework/fix resumes into fresh mode.
- Row 12 treats any `step: landing` last entry as "decision recorded"
  (`cycle-dispatch.md:334-336`), and a resume entry into landing is exactly
  that shape (`journal-entry.md:139`).
- The dispatcher composes the PR title/body (`cycle-write-phase.md:79-84`),
  the corrected title/body (`:140-150`), the merge message
  (`cycle-dispatch.md:395-397`) and the refusal addendum (`:361-362`), and
  carries the live body verbatim into the dossier payload (`:255-258, 479-480`),
  against invariant 3 (`cycle.md:24-29`).
- Row 6 routes a failed manual item into verify-fix (`cycle-dispatch.md:207-208`,
  echoed by `manual-verify.md:100-102`); `agents/dossier.md:69-72` omits failed
  manual items.

## Desired End State

- Every `blocked` row in the allowed-outcomes table names a `next-step` from the
  closed vocabulary; the twice-invalid entry repeats the derived step; each
  agent's `## Return` names its blocked `next-step`.
- A landing is recognised as decided only by a decision entry (the one shape
  with an `- Attempt:` line); a resume into landing restarts the attempt count.
- The pull request's text is an agent artifact: the committed file
  `thoughts/factory/GH-<n>/pr-body.md` (title on line 1, blank line 2, body
  from line 3), written by implement's final fresh batch, corrected by the
  dossier agent, and handed to `gh-write.sh` by path. The live PR reaches the
  dossier agent and the merge as a file written by `gh-read.sh pr --out`.
- The landing refusal addendum is written by the dossier agent (`mode: refusal`,
  `cause:`), dispatched in the decision cycle; the dispatcher only posts it.
- Invariant 3 matches every instruction; the dispatcher's own one-liners are
  stated as allowed.
- A failed manual item travels to the dossier as an open item; nothing routes
  it into verify-fix.
- tsf 1.1.1 in both manifests, tagged; governance recorded in CLAUDE.md and
  DESIGN.md §16.

### Key Discoveries:

- `gh-write.sh` has exactly one caller of `pr-create`, `pr-edit` and `merge`
  (the cycle references); `spec.md`/`init.md` use none of them.
- `gh-read.sh pr` is called only by row 9; `review-brief --out` is the
  established write-to-file pattern (`gh-read.sh:121-133`).
- The landing decision entry is the only journal shape carrying `- Attempt:`
  (`journal-entry.md:177-185`).
- The decision cycle writes (only the merge cycle is write-free), so it can
  dispatch the dossier agent and post its addendum.

## What We're NOT Doing

- The environment-wide prepare/push failure (review #3) — stays in `TODO.md`.
- Re-opening a pull request after a cycle died between push and `pr-create`
  (the committed file makes it possible; wiring it is not in scope).
- `mergeable_state: unstable`, the built-set reset after an implementation
  question, the session permission mode.
- Any state-machine change beyond the above (no new label, no new `Next step`
  value, no new dispatch row).

## Implementation Approach

Four phases, each a coherent same-commit span. Phase 3 changes script flags and
must therefore land together with every caller (the dispatcher-owns-writes
rule), so scripts and prose are one phase.

## Phase 1: C1 — every blocked return is resumable; the landing resume

### Changes Required:

#### 1. The allowed-outcomes table
**File**: `plugins/tsf/references/templates/result-block.md`
- Replace `| any | blocked | tsf:needs-human | the step itself |` with explicit
  rows: triage→triage, research→research, plan→plan, implement→implement /
  verify / review, verify-fix→verify, manual-verify→verify, dossier→dossier,
  merge-resolver→landing (all `tsf:needs-human`).
- Prose after the table: the three `implement | blocked` rows by mode (fresh →
  `implement`, fix → `verify`, rework → `review`) and why; verify-fix and
  manual-verify block to `verify` so the resume opens a new episode; "a blocked
  row always names a step of the closed vocabulary — the table has no wildcard".
- Header comment: agent list covers every worker.

#### 2. The journal entry template
**File**: `plugins/tsf/references/templates/journal-entry.md`
- Heading `step:` vocabulary gains `merge-resolver` (its blocked return has an
  entry of its own).
- Twice-invalid shape: `Next step: [the step's own Next step | the derived step
  this cycle dispatched from]` with a sentence that a step name outside the
  vocabulary never goes there.
- The attempt line: attempts count **landing decision entries** (a
  `step: landing` entry carrying `- Attempt:`) since the newest entry whose
  `- Label:` is `tsf:landing` and which is not a decision entry — the approving
  review entry or a resume entry; a resume therefore restarts the count.
- Resume shape: note that it never carries `- Attempt:`, which is what keeps a
  resumed landing out of the merge cycle.

#### 3. The dispatch reference
**File**: `plugins/tsf/references/cycle-dispatch.md`
- Row 12 intro: the merge cycle runs only when the last entry is a landing
  **decision** entry (`step: landing` with an `- Attempt:` line); any other
  last entry — a resume, a park — means the decision cycle.
- Derived state bullet: take the `- Attempt:` line "on a landing decision
  entry".
- Landing-attempt counter: same definition as journal-entry.md.

#### 4. Agent returns
**Files**: `plugins/tsf/agents/verify-fix.md`, `manual-verify.md`, `implement.md`
- verify-fix / manual-verify blocked bullet: `next-step: verify`, why (resume
  opens a new episode, the step re-runs).
- implement blocked bullet: `next-step: implement` (fresh), `verify` (fix),
  `review` (rework), one reason each.
- (merge-resolver already says `landing`; triage/research/plan/dossier: check
  each names its own step and add it where missing.)

### Success Criteria:

#### Automated Verification:
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `grep -n "| any |" plugins/tsf/references/templates/result-block.md` finds nothing
- [x] Every `blocked` row's last cell is in the closed vocabulary (read the table)
- [x] `grep -rn "the step itself" plugins/tsf` finds no out-of-vocabulary use

#### Manual Verification:
- [x] Trace on paper: verify-fix blocked → re-queue → row 3 → `tsf:verify` with a new episode → row 6 re-runs
- [x] Trace on paper: merge-resolver blocked → re-queue → resume entry → row 12 decision cycle, not the merge cycle

### Implementation log

- **Status**: complete
- **Base commit**: cf58243
- **Done**: explicit blocked rows in `result-block.md`; journal heading gains
  `merge-resolver`, twice-invalid entry repeats the derived step, attempt line
  and row 12 key on the decision entry's `- Attempt:` line (resume restarts the
  count); every worker's `## Return` names its blocked `next-step`. The
  manual-verify paragraph was rewritten once for both C1 and C3.
- **Verification**: `claude plugin validate ./plugins/tsf` passed; no wildcard
  row, no "the step itself" left.

---

## Phase 2: C3 — a failed manual item is an open item

### Changes Required:

#### 1. Row 6
**File**: `plugins/tsf/references/cycle-dispatch.md`
- Delete "a `failed` item routes exactly like a red verification (…)". Add: a
  failed item is recorded in the manual report and reaches the human through
  the dossier's open items; it never re-enters the fix loop.

#### 2. manual-verify agent
**File**: `plugins/tsf/agents/manual-verify.md`
- Replace "the dispatcher routes it like any other red verification" with "it
  travels to the dossier as an open item, with the evidence in your report".

#### 3. dossier agent
**File**: `plugins/tsf/agents/dossier.md`
- Open items list: add manual items that were attempted and failed or were
  inconclusive, with the evidence from `reports/manual-<episode>.md` — matching
  `templates/dossier.md:99-101`.

### Success Criteria:

#### Automated Verification:
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `grep -rn "routes exactly like a red\|routes it like any other red" plugins/tsf` finds nothing

#### Manual Verification:
- [x] dossier agent and dossier template agree on failed manual items (read both)

### Implementation log

- **Status**: complete
- **Done**: row 6's routing sentence replaced (a failed item goes to the
  dossier, not verify-fix); `agents/dossier.md` names attempted-and-failed or
  inconclusive manual items as open items with their evidence. The
  manual-verify wording landed in phase 1.
- **Verification**: validate passed; no route claim left.

---

## Phase 3: C2 — the pull request's text and the refusal addendum are agent artifacts

### Changes Required:

#### 1. gh-write.sh
**File**: `plugins/tsf/scripts/gh-write.sh`
- New flag `--pr-file F`: line 1 is the title, line 2 must be empty, lines 3…
  are the body. Parsed once in a helper; a file whose line 1 is empty or whose
  line 2 is not empty is a usage error.
- `pr-create --branch B --base BASE --pr-file F` (replaces `--title`/`--body-file`).
- `pr-edit --pr N --pr-file F --field title|body|both` (replaces the optional
  `--title`/`--body-file`): sends only the named field(s); read-back unchanged.
- `merge --pr N --sha SHA --pr-file F` (replaces `--title`/`--message-file`):
  commit title = the title line, message = the body.
- Header and usage lines updated.

#### 2. gh-read.sh
**File**: `plugins/tsf/scripts/gh-read.sh`
- `pr --branch B [--out FILE]`: with `--out`, the title and body are written to
  FILE in the pr-file shape and **no** `body:` section is printed; the `title:`
  line stays. Without `--out`, unchanged.

#### 3. Templates
- `references/templates/pr-body.md`: readers are the implement agent (writes
  `thoughts/factory/GH-<n>/pr-body.md`) and the dossier agent (validates the
  live PR, corrects the file); new "The file" section (title line, blank line,
  body); drop the "travels through the dispatcher as text" rationale.
- `references/templates/result-block.md`: dossier-only field `pr-fix: none |
  title | body | both` (validity: present on a dossier return); header span.
- `references/templates/dossier.md`: "The landing refusal" names two causes
  (`integration-risk`, `approval-stale`), written by the dossier agent in
  `mode: refusal`; the logic-resolution case is explained by the next
  episode's addendum.

#### 4. Agents
- `agents/implement.md`: final fresh batch (the return with `next-step:
  verify`) writes `pr-body.md` from the template and commits it on its own
  (`docs(GH-<n>): pull request text`); rework/fix never touch it; "don't open
  the pull request" stays.
- `agents/dossier.md`: inputs `pr-number:` and `pr-file:` (the live PR, a path)
  replace `pr-title:`/`pr-body:`; validation compares the live PR with the
  template and rewrites the committed `pr-body.md` when wrong (creating it if
  absent), committing it with the dossier; returns `pr-fix:`. New
  `mode: refusal` with `cause:` (and `report:` for integration risk): append the
  refusal addendum only, no PR validation (`pr-fix: none`).

#### 5. Dispatcher prose
- `commands/cycle.md`: invariant 3 rewritten (bodies of spec, research, plan,
  diff, dossier and pull request never read; scripts' one-line fields readable;
  the human's issue text and replies passed on verbatim; own one-line status
  comments allowed and never built from an artifact). MANDATORY OUTPUT gains
  `pr-body.md` for an implement return with `next-step: verify` in fresh mode.
- `references/cycle-write-phase.md`: "Opening the pull request" becomes
  `pr-create --pr-file thoughts/factory/GH-<n>/pr-body.md` — no template read,
  no composition; "The dossier's writes" uses `pr-edit --pr-file <that path>
  --field <pr-fix>`; new "not decided" variant under the landing decision
  cycle's writes (report + journal from the dossier's block, one commit, push,
  marker, the addendum on the pull request, the gate one-liner, label
  `tsf:needs-review`).
- `references/cycle-dispatch.md`: row 9 runs `gh-read.sh pr --branch --out
  .tsf-tmp/pr.md` and passes `pr-number:` + `pr-file:`; row 12 "Not decided"
  writes the integration report to disk, then dispatches **tsf:dossier** with
  `mode: refusal`, `cause:`, `report:`; merge step fetches the live PR with
  `gh-read.sh pr --out` and calls `merge --pr-file`; payload section updated.
- `references/cycle-report.md`: a refusal line for the landing.

### Success Criteria:

#### Automated Verification:
- [x] `claude plugin validate ./plugins/tsf` passes
- [x] `bash -n` on both scripts passes
- [x] Fake-`gh` smoke test: `pr-create --pr-file` sends the title line and the body from line 3; `pr-edit --field title` sends only the title; `merge --pr-file` sends commit_title/commit_message; a malformed pr file is a usage error (exit 1)
- [x] Fake-`gh` smoke test: `gh-read.sh pr --out F` writes the pr-file shape and prints no `body:`
- [x] `grep -rn "pr-title:\|pr-body:\|--message-file\|corrected title" plugins/tsf` finds no stale use

#### Manual Verification:
- [x] Read cycle.md, cycle-dispatch.md, cycle-write-phase.md: no instruction requires the dispatcher to read a spec, plan, research, dossier or PR body or to compose artifact text

### Implementation log

- **Status**: complete
- **Done**: `gh-write.sh` `--pr-file` for pr-create / pr-edit (`--field`) /
  merge; `gh-read.sh pr --out`; `pr-body.md` gains "The file"; result block
  gains the dossier's `pr-fix:`; dossier template's refusal names two causes;
  implement's last fresh batch writes and commits `pr-body.md`; dossier agent
  gets `mode: review | refusal`, `pr-file:`, rewrites `pr-body.md`; invariant 3
  rewritten (dossier and PR bodies named, script one-liners, issue text and
  replies, own status comments); write phase opens/edits from the file and
  gains the refusal variant; rows 9 and 12 and the merge pass paths; report
  gains a refusal line. `spec.md`/`init.md` use none of the changed
  subcommands, so the dispatcher-owns-writes span needed no edit there.
- **Verification**: validate passed; `bash -n` on both scripts; fake-gh smoke
  test (scratchpad `fakegh/run.sh`) — request bodies for pr-create, pr-edit
  title/body/both and merge carry exactly the file's title and body, `pr --out`
  writes the pr-file shape with no `body:` on stdout, malformed files, a missing
  `--field` and the old flags exit 1; stale-wording grep clean.

---

## Phase 4: Governance, docs and release

### Changes Required:

- `CLAUDE.md`: new rule "tsf: the pull request's text is an agent artifact
  (TP-0037)" (file shape, writers, scripts, span); the result-block section
  records "no wildcard rows; every blocked row names a vocabulary step"; the
  landing section records the decision-entry-by-Attempt-line rule;
  dispatcher-owns-writes list unchanged.
- `plugins/tsf/DESIGN.md`: §6.6 PR opening, §9.1 open items (failed manual
  items), §9.3 step 4 (dossier agent writes the refusal addendum), §16
  entries 61–64.
- `plugins/tsf/README.md`: the pull-request paragraph (the agent writes the
  text).
- `plugins/tsf/commands/init.md`: Idempotency `1.1.1` — nothing to migrate.
- Version `1.1.1` in `plugins/tsf/.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json`; commit the pending `TODO.md` entry
  (review #3) with it; `claude plugin tag ./plugins/tsf`.

### Success Criteria:

#### Automated Verification:
- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tsf` pass
- [x] `git tag --list 'tsf--v*'` lists `tsf--v1.1.1`

#### Manual Verification:
- [x] CLAUDE.md's new rule names every file of its span

### Implementation log

- **Status**: complete (`tsf--v1.1.1` tagged on `ecf7c93`)
- **Done**: CLAUDE.md — no-wildcard rule under the result block, the
  decision-entry-by-Attempt-line rule under the landing, new section "tsf: the
  pull request's text is an agent artifact"; DESIGN §6.6, §9.1, §9.3 step 4 and
  §16.61–64; README pull-request paragraph; `/tsf:init` Idempotency `1.1.1`;
  version 1.1.1 in both manifests; the pending `TODO.md` entry (review #3)
  committed with it.
- **Verification**: both validations passed.

---

## Testing Strategy

No test suite exists; verification is `claude plugin validate`, `bash -n`, a
fake-`gh` smoke test of the changed script subcommands (the method CLAUDE.md
"Testing changes" prescribes), and grep checks for stale wording. A live
factory run is outside this session (needs a second GitHub account).

## References

- Original ticket: `thoughts/shared/tickets/TP-0037-tsf-final-review-corrections.md`
- Related research: `thoughts/shared/research/2026-09-21-TP-0037-tsf-final-review-corrections.md`
- Previous round: `thoughts/shared/plans/2026-09-20-TP-0036-tsf-review-corrections.md`

## Implementation Closeout

- **Plan-compliance gate**: passed against baseline `cf58243` (recorded) — 15
  criteria met, 0 not met, 5 manual items reported as needing human
  verification.
- **Manual verification**: accepted by the user on 2026-09-21 without a
  separate check here; they will be exercised in the upcoming live factory run.
- **Landed**: directly on `main` — `14b81c7` (C1), `f2fa690` (C3), `fbc275a`
  (C2), `ecf7c93` (governance, tsf 1.1.1, tagged `tsf--v1.1.1`); not pushed.
- **Ticket**: TP-0037 → Done.
