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
3. Rows (slice 1: DESIGN.md §4 rows 1–4 and 13)
4. The spawn payload
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

The derived step `implement` in any row → **re-pick** (Step 5 of `cycle.md`):
it is not implemented in this slice.

# Rows

Evaluated in order for the picked ticket.

**Row 1 — a reply arrived** (`tsf:answered`, or `tsf:needs-answer` /
`tsf:needs-plan-approval` with a polled `reply:`).

1. The **parking step** is the last journal entry's `step:`. The step that
   parked resumes with the reply: `triage` → **tsf:triage**, `research` →
   **tsf:research**, `plan` → **tsf:plan**. The agent folds the reply into the
   artifact the parking step maps to (triage, research → `spec.md`; plan gate →
   `plan.md`); you do no content work.
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

**Row 13 — `tsf:needs-*` without a new signal** never reaches this file: Step 3
skipped it.

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
- A re-dispatch after an invalid return adds
  `note: your previous return had no valid result block`.
