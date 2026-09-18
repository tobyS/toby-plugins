<!--
Runtime reference for the tsf software factory. Read by /tsf:cycle at Step 5
(Decide) — always in full, even if already read earlier in the session. Never
copied into consuming projects.

Changes to this file are command-contract changes. It is one of two
descriptions of the state machine (DESIGN.md §4) — the other is the agents'
result-block vocabulary — so the CLAUDE.md rules "tsf: the journal's Next step
is the derived state" and "tsf: the result block is a machine contract" apply:
update plugins/tsf/references/templates/journal-entry.md,
plugins/tsf/references/templates/result-block.md, plugins/tsf/commands/cycle.md
and the agents in the same commit. Dispatch rows grow only with a slice.

Contents:
1. Derived state
2. Validation
3. Rows (DESIGN.md §4 rows 1–11 and 13; row 12, landing, is a later slice)
4. Episodes and rounds
5. The spawn payload
-->

# Derived state

You are on the ticket branch (Step 4 checked it out). Establish, without reading
any artifact's body:

- **Artifacts:** which of `thoughts/factory/GH-<n>/spec.md`, `research.md`,
  `plan.md` and `journal.md` are committed on the branch:
  `git ls-files thoughts/factory/GH-<n>/`. (Prepare left the checkout pristine,
  so committed and present are the same thing.)
- **The journal's last entry**, when `journal.md` exists: Read the file and act
  only on its last entry — from the last line starting `## Cycle ` to the end.
  Take its heading's `step:` value and its `- Label:` and `- Next step:` lines.
  A `Next step` outside `triage | research | plan | implement` is unreadable:
  treat it as a mismatch (park, below).
- **The derived step:**
  - with a journal → the last entry's `Next step`;
  - without one → from the artifacts: no `spec.md` → `triage`; `spec.md` but no
    `research.md` → `research`; otherwise → `plan`.
- **The verification facts**, for a ticket past `tsf:implement`: the scan's
  `pr:`, `pr_head:`, `ci:`, `review:`, `review_ref:` and `factory_comment:`
  fields; the reports present under `thoughts/factory/GH-<n>/reports/`; and the
  logic head from `<plugin root>/scripts/diff.sh logic-head`.

The label's step: `tsf:queued` → the derived step (the label names no step of
its own); `tsf:research` → `research`; `tsf:plan` → `plan`; `tsf:answered` and a
polled reply → the parking step (row 1).

# Validation

Two kinds of disagreement, handled differently (DESIGN.md §3.4):

- **Factory-side label is stale** (`tsf:research` or `tsf:plan` whose step is not
  the derived step): correct it — `<plugin root>/scripts/gh-write.sh labels
  --repo <owner/repo> --as factory --credential <source> --issue <n> --set
  <label of the derived step>` (triage → `tsf:queued`, research → `tsf:research`,
  plan → `tsf:plan`, implement → `tsf:implement`) — then continue with the row of
  the derived step. A failed correction is a failed write: park as
  cycle-write-phase.md says.
- **Human-side state disagrees with the artifacts** → **park**, never guess.
  Cases in this slice:
  - `tsf:answered` (or a polled reply) but no journal, or the last entry's
    `Label` is neither `tsf:needs-answer` nor `tsf:needs-plan-approval`;
  - a plan-gate reply (last `Label` `tsf:needs-plan-approval`) but no `plan.md`;
  - a research-parked reply but no `research.md`; any reply but no `spec.md`;
  - `tsf:answered` but `gh-read.sh reply` finds no responder comment after the
    factory's last comment;
  - an unreadable `Next step`.

  A park is recorded as the state-mismatch entry of `journal-entry.md`: the
  outcome line names the label and what the artifacts show, `step:` and
  `Next step` repeat the derived step. Hand it to Step 7.

The derived step `landing` in any row → **re-pick** (Step 5 of `cycle.md`): the
landing loop is not implemented in this slice.

# Rows

Evaluated in order for the picked ticket.

**Row 1 — a reply arrived** (`tsf:answered`, or `tsf:needs-answer` /
`tsf:needs-plan-approval` with a polled `reply:`).

1. The **parking step** is the last journal entry's `step:`. The step that
   parked resumes with the reply: `triage` → **tsf:triage**, `research` →
   **tsf:research**, `plan` → **tsf:plan**. The agent folds the reply into the
   artifact the parking step maps to (triage, research → `spec.md`; plan gate →
   `plan.md`); you do no content work.

   **`implement` is the exception**: an implementation question is a plan-gate
   question (§6.3), so its reply goes into `plan.md` and **tsf:plan** resumes —
   not the parking step. It folds the answer in, re-summarizes, and the ticket
   parks at `tsf:needs-plan-approval` again, so the human approves the changed
   plan before implementation continues.
2. Validate (above).
3. A polled reply first gets `gh-write.sh labels … --set tsf:answered`, so the
   label history matches the workflow path.
4. Fetch the reply: `<plugin root>/scripts/gh-read.sh reply --repo <owner/repo>
   --as factory --credential <source> --issue <n> --responders <a,b>
   --factory-login <login>`. Everything after its `text:` line is the reply.
5. Dispatch with `mode: resume` and the reply.

**Row 2 — `tsf:queued`, no `spec.md`** → **tsf:triage**, `mode: fresh`.

**Row 3 — `tsf:queued` with `spec.md`, or `tsf:research`.**

- `tsf:queued` with `spec.md` and no journal (the `/tsf:spec` door) →
  **tsf:research**, `mode: fresh`.
- `tsf:queued` with a journal — the resume path after `tsf:needs-human` — →
  continue at the journal's `Next step`: `triage` → **tsf:triage** `mode: resume`
  with an empty `reply:` (it re-tests the spec); `research` → **tsf:research**
  `mode: fresh`; `plan` → **tsf:plan** `mode: fresh`; `implement` → re-pick.
- `tsf:research` (validated) → **tsf:research**, `mode: fresh`.

**Row 4 — `tsf:plan`** (validated) → **tsf:plan**, `mode: fresh`.

**Row 5 — `tsf:implement`** → **tsf:implement**, `mode: fresh`. The plan gate
approved the plan; this is the first code the factory writes for the ticket.

**Row 6 — `tsf:verify`, local verification red.** Before deciding anything, run
the project's `verify` script (verification mode `local` only; in mode `ci` skip
straight to row 7) and keep its output in a file under `.tsf-tmp/`:

- **red** → **tsf:verify-fix**, `failure: local`, with `verify-output:` the path
  and `attempt:` the next attempt in this episode. Exhausted
  (`verify_fix_bound`) → park `tsf:needs-human` with a journal entry naming
  every attempt.
- **green** → the **manual items**: when `plan.md` has `**Manual**` items and no
  `reports/manual-<episode>.md` exists yet, dispatch **tsf:manual-verify** with
  them; a `failed` item routes exactly like a red verification (row 6's
  verify-fix, `failure: local`). When they are done, or there are none,
  continue with row 7.

**Row 7 — `tsf:verify`, local green (or mode `ci`).** From the scan's `ci:`:

- `pending` → not actionable; Step 3 already skipped it.
- `failure` → **tsf:verify-fix**, `failure: ci`, with `failed-checks:` from
  `<plugin root>/scripts/gh-read.sh checks --ref <pr_head>` and the same
  attempt bound.
- `success` → row 8.

**Row 8 — `tsf:verify`, local and CI green: the gates.** Compare each of
`reports/plan-compliance-<episode>-<round>.md`, `spec-coverage-…`, `security-…`
for the highest round with the current logic head:

- a report **missing**, or its `head:` line naming **another** logic head → run
  the **gate cycle**: all three gates, one message, foreground, each given the
  `file:` path from `diff.sh pr-diff --base <base branch>` (plus, for
  plan-compliance, the plan's numbered per-increment criteria including addenda;
  for spec-coverage, the spec's text).
- all three present at the current logic head and `verdict: pass` →
  `tsf:dossier`.
- any `verdict: fail` → **tsf:implement**, `mode: fix`, with `reports:` the
  failing report paths and `round:` the next round. The ticket **stays**
  `tsf:verify`: fix mode is entered from the reports, never from a label.
  Exhausted (`gate_fix_bound`) → park `tsf:needs-human` with the last reports
  linked.

**Row 9 — `tsf:dossier`** → **tsf:dossier**, with `diff:` the diff path,
`head:` the logic head, and the pull request's `number:`, `title:` and body
from `<plugin root>/scripts/gh-read.sh pr --branch <branch>` (its `body:` line
is followed by the body verbatim).

`other-prs:` is the overlap warning's raw material, and it is computed locally —
no REST call. For every **other** ticket in this scan whose `pr:` is a number,
run
`<plugin root>/scripts/diff.sh files --base <base branch> --ref origin/<that ticket's branch>`
and pass its ticket, pull request number and file list. A branch the clone has
not fetched reports `failed`: pass that ticket with "files unknown" rather than
dropping it. With no other open factory pull request, pass `other-prs: none`.

**Row 10 — `tsf:needs-review`: the review read.** No agent is dispatched; the
dispatcher decides from GitHub's own facts (never from the journal):

- `review: approved` → is the approval still current? Run
  `<plugin root>/scripts/diff.sh ancestor --commit <logic head> --of <review_ref>`.
  `yes` → the approval is at or after the logic head → `tsf:landing` (then
  re-picked as "landing not implemented in this slice"). `no` → the code moved
  after the approval: the ticket **stays** `tsf:needs-review`, and the addendum
  that moved it has already asked for a new review — journal the stale approval
  and write nothing else.
- `review: changes-requested` → compare `review_ref:` (the review's
  `submitted_at`) with `factory_comment:` (the factory's last dossier or
  addendum comment). Newer → `tsf:rework`. Older or equal → it is the review a
  previous rework already addressed: ignore it, journal that, and leave the
  ticket parked.
- `review: none` → not actionable; Step 3 skipped it.

**Row 11 — `tsf:rework`** → **tsf:implement**, `mode: rework`, with
`review-comments:` the review's body and its comments, fetched with
`gh-read.sh reviews` and `gh-read.sh pr-comments`. It returns the ticket to
`tsf:verify` as a **new episode** (the journal entry carries the next
`Episode:` number).

**Row 13 — `tsf:needs-*` without a new signal** never reaches this file: Step 3
skipped it.

# Episodes and rounds

Both counters are read from disk, never remembered:

- **Episode** — the highest `- Episode:` line in `journal.md`. A ticket entering
  `tsf:verify` from **implement** or **rework** opens the next one (1 for the
  first); a fix-mode or verify-fix return stays inside the current episode.
- **Verify-fix attempt** — the highest `<attempt>` in
  `reports/verify-fix-<episode>-<attempt>.md`, plus one. Bound:
  `verify_fix_bound` from the config.
- **Gate round** — the highest `<round>` in
  `reports/<gate>-<episode>-<round>.md`, plus one; the three gates share it.
  Bound: `gate_fix_bound`.

A bound is exhausted when the next counter would exceed it: park
`tsf:needs-human`, journal what was tried, and link the last reports in the
comment.

For **tsf:triage** in any mode, first read the issue:
`<plugin root>/scripts/gh-read.sh issue --repo <owner/repo> --as factory
--credential <source> --issue <n>` — the `title:` line, and everything after its
`body:` line as the body. `pull: yes` → park as a mismatch ("a pull request, not
an issue").

# The spawn payload

Pass exactly these lines, then the verbatim blocks, and nothing else:

```
ticket: GH-<n>
branch: <branch>
base-branch: <base branch>
repo: <owner/repo>
responders: <a,b>
templates: <plugin root>/references/templates
mode: fresh | resume
Re-read every input artifact from disk, in chain order, before you act.
```

- **tsf:triage** adds `issue-title: <title>` and `issue-body:` followed by the
  issue body verbatim.
- `mode: resume` adds `reply:` followed by the reply text verbatim (empty for the
  re-queued triage resume).
- **tsf:implement** adds `mode: fresh | rework | fix`, and with it
  `review-comments:` (rework) or `reports:` (fix, the failing report paths on
  the branch).
- **tsf:verify-fix** adds `failure: local | ci`, `verify-output:` or
  `failed-checks:`, `verify-command:`, `episode:` and `attempt:`.
- **tsf:manual-verify** adds `manual-items:` (the plan's `**Manual**` items,
  verbatim and numbered) and `episode:`.
- **tsf:dossier** adds `diff:`, `head:`, `pr-number:`, `pr-title:`, `pr-body:`
  and `other-prs:`.
- **The three gates** get a payload of their own, and nothing else:
  - **tsf:plan-compliance** — the numbered per-increment criteria (addenda
    included), verbatim, and `diff:` plus `stat:`;
  - **tsf:spec-coverage** — the spec's text, verbatim, and `diff:` plus `stat:`;
  - **tsf:security** — `diff:` plus `stat:`.
  All three also get `templates:`. Never pass a gate the plan's prose, the
  research, the journal, another gate's report, or anything about why the code
  looks as it does.
- A re-dispatch after an invalid return adds
  `note: your previous return had no valid result block`.
