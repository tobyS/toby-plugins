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
3. Rows (DESIGN.md §4 rows 1–13)
4. Episodes, rounds and landing attempts
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
  Take its heading's `step:` value and its `- Label:` and `- Next step:` lines,
  and — on a `step: landing` entry — its `- Attempt:` line. A `Next step`
  outside the closed vocabulary of `journal-entry.md` (`triage | research |
  plan | implement | verify | gates | dossier | review | landing`) is
  unreadable: treat it as a mismatch (park, below).
- **The derived step:**
  - with a journal → the last entry's `Next step`;
  - without one → from the artifacts: no `spec.md` → `triage`; `spec.md` but no
    `research.md` → `research`; otherwise → `plan`.
- **The verification facts**, for a ticket past `tsf:implement`: the scan's
  `pr:`, `pr_head:`, `ci:`, `review:`, `review_commit:`, `review_at:` and `factory_comment:`
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

**The re-pick.** A row may conclude that the picked ticket cannot be advanced
after all, without anything being wrong with it. That is a **re-pick** (Step 5
of `cycle.md`): add the ticket to the skipped list with the row's reason and
return to Step 3 with the remaining actionable tickets. It writes nothing — it
is not a park, and it never changes a label. Row 12's `mergeable: unknown` is
the one case in the current row set.

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
straight to row 7) **with the Bash tool's maximum timeout**, and keep its output
in a file under `.tsf-tmp/` — a failing command returns only a truncated excerpt
and no file path, so the redirect is what makes the output readable at all:

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

- `pending` → Step 3 skipped it, **unless** it let the ticket through for one of
  the two reasons below. It names which:
  - **conflicted** (`mergeable: false`) → the pull request conflicts with the
    base branch, and GitHub runs no `pull_request` workflow while a conflict is
    open — so CI will never start on this head and waiting is pointless. Run
    **the sync sequence** (below). A clean or resolved sync is pushed in the
    write phase, which restarts CI; the ticket stays `tsf:verify` and the
    journal entry says what was synced.
  - **pending too long** (the head is older than `ci_pending_bound`) → park
    `tsf:needs-human`, naming the head, how long it has been pending and the
    bound. This is the net under everything GitHub does not document: a
    workflow that was never installed, a path filter that excludes the head, a
    runner that never picked the job up.
- `failure` → **tsf:verify-fix**, `failure: ci`, with `failed-checks:` from
  `<plugin root>/scripts/gh-read.sh checks --ref <pr_head>` — passing the same
  `--required-check` flags the scan was given — and the same attempt bound.
- `success` → row 8.
- `no-ci` → the project runs no pull-request CI (its config says so): there is
  nothing to wait for and nothing to read, so local green alone is the
  precondition → row 8. In verification mode `ci` this combination is a
  contradiction — the config asks CI to be the only verifier and also says
  there is none → park `tsf:needs-human` naming it.

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
  `<plugin root>/scripts/diff.sh ancestor --commit <logic head> --of <review_commit>`.
  `yes` → the approval is at or after the logic head → `tsf:landing`. `no` → the
  code moved after the approval: the ticket **stays** `tsf:needs-review`, and the
  addendum that moved it has already asked for a new review. This is a
  **re-pick** — add the ticket to the skipped list as "approval behind the logic
  head" and return to Step 3. **Write nothing, not even a journal entry**: the
  ticket is picked again every cycle until the human reviews, and an entry per
  cycle would be a commit, a push and a CI run each time.
- `review: changes-requested` → `tsf:rework`. No recency test is needed here:
  `scan.sh` already reports a review the factory has since answered as
  `review: none`, so a record that says `changes-requested` is by construction
  one nobody has addressed yet.
- `review: none` → not actionable; Step 3 skipped it.

**Row 11 — `tsf:rework`** → **tsf:implement**, `mode: rework`. First fetch the
brief:

```
<plugin root>/scripts/gh-read.sh review-brief --repo <owner/repo> --as factory
  --credential <source> --pr <n> --out .tsf-tmp/review-brief.md
```

Pass its path as `review-brief:`. **Do not read the file** — it is the human's
review text, and it belongs in the agent's context, not yours. `result: none`
means the latest decisive review is not a changes-requested one, which
contradicts the `tsf:rework` label → park as a state mismatch. It returns the
ticket to `tsf:verify` as a **new episode** (the journal entry carries the next
`Episode:` number).

**The sync sequence.** Bringing a ticket branch up to date with the base branch.
Two rows need it — row 7's conflicted pull request and row 12's landing — and it
is written once here so they cannot drift apart.

```
<plugin root>/scripts/gh-write.sh update-branch --repo <owner/repo> --as factory
  --credential <source> --pr <n> --expected-head <pr_head>
```

- `synced` → the server merged the base branch in. Run
  `<prepare path> <branch> <base branch>` **again** so the clone holds the
  merged head, then continue.
- `up-to-date` → nothing to merge; continue.
- `head-moved` → somebody pushed while you were reading. **Stop**: end the cycle
  with no write; the next one starts from the new head.
- `conflict` → dispatch **tsf:merge-resolver** (payload below). `blocked` →
  **stop**: park `tsf:needs-human` with its comment. `continued` → the
  resolution is committed locally and is pushed in the write phase. **Do not run
  `prepare` after the resolver** — it would discard the merge.
- anything else → **stop**: a failed write, park (cycle-write-phase.md).

A resolution the resolver classified **logic** advances the logic head (its
commit carries `Tsf-Resolution: logic`, or no trailer at all, which is read the
same way). That is not a special case to handle here: the gates are stale
against the new logic head, so row 8 re-runs them, and an approval behind it is
stale by row 10.

**Row 12 — `tsf:landing`: the landing loop** (§9.3). It spans **two cycles**.
Which one this is comes from the journal's last entry: a `step: landing` entry
means the decision is already recorded, so this is the merge cycle; anything
else means this is the decision cycle.

*The decision cycle (steps 1 to 4). It writes.*

1. **Sync.** Run **the sync sequence** (just above), then continue with step 2.
   Its `stop` outcomes end the cycle where they say.
2. **Integration gate.** Establish the start point: the `main-head:` line of the
   newest `reports/integration-*.md`, or — when there is none — the approving
   review's `commit_id` (the scan's `review_commit:`). Then
   `<plugin root>/scripts/diff.sh main-delta --base <base branch> --from <that main head>`
   (or `--approval <review_commit>` when there was no report).
   - `moved: no` → skip the gate and say so in the journal.
   - `moved: yes` → dispatch **tsf:integration** alone, foreground, with the
     two diff paths and the spec's text. Write its report to
     `reports/integration-<attempt>.md`, filling `head:` from `diff.sh
     logic-head` and `main-head:` from this call's `main_head:`.
3. **Decide.** Decide for the merge only when **all** of:
   - the sync ended `synced` or `up-to-date`;
   - no resolution ran, or its commit carries `Tsf-Resolution: mechanical`;
   - the gate returned `safe`, or was skipped;
   - the approval is still current —
     `diff.sh ancestor --commit <logic head> --of <review_commit>` is `yes`.

   **Decided** → the landing decision entry (journal-entry.md), committed with
   the integration report, pushed; the label stays `tsf:landing`; the cycle
   ends. **Not decided** → a dossier addendum naming the cause (dossier.md, "The
   landing refusal") and the label `tsf:needs-review`. A **logic** resolution is
   the one case that does not go straight to review: it advanced the logic head
   and started CI, so the ticket goes to **`tsf:verify`** as a new episode and is
   re-gated first (§16.40).
4. **Attempt bound.** The attempt number is the journal-derived count
   (journal-entry.md, "The attempt line"). If it would exceed
   `landing_attempt_bound`, park `tsf:needs-human`: the base branch moved that
   many times during this landing and the factory cannot converge. Say so —
   the pull request is healthy, the repository is simply busier than a landing.

*The merge cycle (step 5). It writes nothing to the repository and posts no
comment.*

1. `<plugin root>/scripts/diff.sh decision-head --journal thoughts/factory/GH-<n>/journal.md`.
   `unchanged: no` → someone pushed after the decision: it is void. Restart at
   the decision cycle's step 1, silently, counting the attempt.
2. The scan's `ci:` for that head. `pending` → not actionable (Step 3 skipped
   it). `no-ci` → there is nothing to wait for; continue to 3.
   `failure` → the combination is red: the ticket leaves landing for
   **`tsf:verify`** as a **new episode** (§6.7, §9.3 step 3) — verify-fix, the
   gates on the new logic head, a dossier addendum, `tsf:needs-review`, and the
   landing restarts once the human approves again.
3. `<plugin root>/scripts/gh-read.sh pr-state --repo <owner/repo> --as factory
   --credential <source> --pr <n>`:
   - `clean` → merge.
   - `behind` → the base branch moved since the decision. **Routine, never
     §10's retry-then-park**: the decision is void; restart at the decision
     cycle's step 1, silently, counting the attempt.
   - `unknown` → GitHub has not finished computing it: **re-pick** and ask again
     next cycle.
   - `dirty`, `blocked` or anything else → restart at step 1. If the previous
     cycle already restarted on the **same** value, park `tsf:needs-human`
     naming it: the state machine is not converging and a human should look.
4. **Merge.** `<plugin root>/scripts/gh-write.sh merge --repo <owner/repo> --as
   factory --credential <source> --pr <n> --sha <the decided head> --title <the
   pull request's title> --message-file <the body with its closing keyword>`.
   - `merged` → continue to 5.
   - `blocked` → report the `reason:` line and end the cycle; the next one
     re-evaluates. Never retry inside the cycle.
   - `head-moved` → the decision is void; restart at step 1.
5. **After the merge — GitHub writes only** (§3.2, §9.4), a second apart:
   a. `gh-write.sh labels --repo <owner/repo> --as factory --credential <source>
      --issue <n> --clear` — the closed issue keeps no state label.
   b. `gh-read.sh branch --branch <branch>`: `exists: no` → done. `exists: yes` →
      `gh-write.sh ref-delete --branch <branch>`; `deleted` and `absent` are both
      success.

   **Never read the bare repository object** to find out whether GitHub deletes
   branches itself: that path is not reachable under every proxy allowlist. Read
   the ref and act on what is there.

   A failure in a or b is **reported, never parked**: the issue is closed, and a
   `tsf:needs-human` label on a closed issue is invisible to the open-only scan
   — the ticket would be lost. Name the failed operation and its `detail:` in
   the closing report.

**Row 13 — `tsf:needs-*` without a new signal** never reaches this file: Step 3
skipped it.

# Episodes, rounds and landing attempts

Every counter is read from disk, never remembered:

- **Episode** — the highest `- Episode:` line in `journal.md`. A ticket entering
  `tsf:verify` from **implement** or **rework** opens the next one (1 for the
  first); a fix-mode or verify-fix return stays inside the current episode.
- **Verify-fix attempt** — the highest `<attempt>` in
  `reports/verify-fix-<episode>-<attempt>.md`, plus one. Bound:
  `verify_fix_bound` from the config.
- **Gate round** — the highest `<round>` in
  `reports/<gate>-<episode>-<round>.md`, plus one; the three post-implement
  gates share it. Bound: `gate_fix_bound`.
- **Landing attempt** — the number of `step: landing` entries in `journal.md`
  since the ticket last entered `tsf:landing` (that is, since the newest
  `step: review` entry whose `- Label:` is `tsf:landing`), plus one. Counted
  from the journal and **not** from `reports/integration-<n>.md`, because the
  integration gate is skipped when the base branch has not moved, so the
  filenames undercount. Bound: `landing_attempt_bound`. A CI-red landing that
  leaves for `tsf:verify` ends the landing; when the ticket comes back through
  row 10 it is a new one, counted from zero again.

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
  `review-brief:` (rework, the path `gh-read.sh review-brief` wrote) or
  `reports:` (fix, the failing report paths on the branch).
- **tsf:verify-fix** adds `failure: local | ci`, `verify-output:` or
  `failed-checks:`, `verify-command:`, `episode:` and `attempt:`.
- **tsf:manual-verify** adds `manual-items:` (the plan's `**Manual**` items,
  verbatim and numbered) and `episode:`.
- **tsf:dossier** adds `diff:`, `head:`, `pr-number:`, `pr-title:`, `pr-body:`
  and `other-prs:`.
- **tsf:merge-resolver** adds `main-delta:` and `pr-diff:` — both paths. It gets
  no `mode:` and no `responders:`.
- **The four gates** get a payload of their own, and nothing else:
  - **tsf:plan-compliance** — the numbered per-increment criteria (addenda
    included), verbatim, and `diff:` plus `stat:`;
  - **tsf:spec-coverage** — the spec's text, verbatim, and `diff:` plus `stat:`;
  - **tsf:security** — `diff:` plus `stat:`;
  - **tsf:integration** — the spec's text, verbatim, `diff:` plus `stat:` (the
    pull request's), and `main-delta:` plus `main-stat:`.
  All four also get `templates:`. Never pass a gate the plan's prose, the
  research, the journal, another gate's report, or anything about why the code
  looks as it does.
- A re-dispatch after an invalid return adds
  `note: your previous return had no valid result block`.
