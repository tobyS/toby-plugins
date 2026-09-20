# tsf — Toby Software Factory: Design

**Status:** Design v1.5 — v1 agreed 2026-08-11; v1.1 on 2026-09-15 after the
fit review against the first consumer project (chat-sustainability); v1.2 the
same day after the simplification pass; v1.3 the same day after the
consistency review; v1.4 the same day after a second consistency review of
the state machine; v1.5 on 2026-09-20, correcting what the first real review
of the shipped 1.0.0 found. All five are reasoned in §16. Implemented in
TP-0034a/b/c; corrected in TP-0036.
**Background:** `thoughts/shared/research/2026-07-07-tce-software-factory-review.md`
— research on how agentic
software factories are built in 2025/26 and how tce's architecture maps onto
them. This document is the design that came out of discussing that review.
The v1.1 revision is reasoned in §16; the platform facts it rests on are in
`thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`.

## 1. Vision

tsf is an **agentic software factory for a single-engineer project**: a Claude
Code plugin that works a GitHub-issue backlog autonomously — picking the most
important ready ticket, advancing it exactly one work step per cycle in a fresh
context, and communicating with the human asynchronously through GitHub — while
all substantive artifacts (spec, research, plan, verification reports, journal)
live as versioned files in the repository.

The goal is to **reduce human interaction to the necessary minimum and make the
remaining interactions maximally informed**: the human writes and releases
specs, answers batched questions, approves plans from short decision-focused
summaries, and reviews finished work from an agent-curated dossier — never
babysitting generation, never reading agent transcripts. After the human's
review approval **nothing else is asked of them**: the factory lands the work
itself (§9).

tsf implements the layers the review identified as missing from tce (intake and
dispatch, async human gates, PR-based delivery, layered machine verification)
while keeping the tce ideas the factory literature identifies as hardest to get
right:

1. A typed artifact chain in git ("frequent intentional compaction").
2. Fresh, attention-isolated contexts per work step.
3. Context-starved verification agents (criteria + diff only — no access to the
   reasoning that produced the code).
4. Human gates at the irreducible decision points (spec sufficiency, plan
   trade-offs, final review) — moved from the terminal to GitHub, not removed.
5. Process/config separation: the workflow is centrally versioned and
   project-agnostic; everything project-specific lives in the consuming
   project's `.claude/tsf/`.

## 2. Relationship to tce: ideas, not code

tsf is a **standalone plugin**. It does not depend on, install, or invoke tce.

Reasoning (agreed explicitly):

- tce's commands are built for **interactive shell use** — they lean on
  AskUserQuestion dialogs, in-terminal approval, and a human present at every
  step. The factory's steps run headless inside subagents where none of that
  machinery exists. Reusing the commands would mean either crippling their
  interactivity or littering them with dual modes.
- The repo rule stands: plugins coordinate only through project config files,
  never by calling into each other. tsf re-states every step in its own words,
  written for autonomous execution from the start.

**One workflow per project** (revised twice, §16.12 and §16.21): a project
is either on tce or on tsf for its ticket work; v1 does not support running
both on the same backlog (two writers on one `gh-<n>` branch, two label
vocabularies on one issue). A project that migrates from tce keeps tce's
documents where they are, and `/tsf:init` may read `.claude/tce/profile.md`
as a *seed* for the project profile — the same pattern tle uses for its
optional profile read — but tsf never requires it, never reads it at
runtime, and never invokes a tce command. tsf's own config stays
`.claude/tsf/config.md`.

What carries over is the *design*: artifact chain, re-read discipline (every
step re-reads its input artifacts from disk, never trusting conversation
state), context starvation for verifiers, graduated ceremony, and the
project-agnostic core.

## 3. Core concepts

### 3.1 The ticket triple

A ticket exists for the factory only as three things together:

1. **A GitHub issue** — the human↔factory transport and workflow-state carrier.
2. **A ticket branch** — named by the project's branch pattern in
   `.claude/tsf/config.md` (e.g. `gh-<n>`; the canonical ticket ID stays
   `GH-<n>`, filesystem-safe and greppable; normalize `#123`, bare numbers,
   and issue URLs to it). The pattern is configuration because consumer
   projects already have branch conventions with hooks keyed on them.
3. **A spec artifact** — `thoughts/factory/GH-<n>/spec.md` on that branch: the
   canonical input specification the factory works from.

Both entry doors establish the full triple:

- `/tsf:spec` (interactive, primary): guided spec authoring on the shell →
  create issue → create branch and commit spec over REST (§6.1; no checkout
  is touched) → offer to label `tsf:queued`.
- Triage (idea-dump path): the human labels an existing raw issue
  `tsf:queued`; the factory's triage step creates branch + initial spec from
  the issue body and asks its clarifying questions from there.

### 3.2 Artifacts in the repo, summaries on GitHub

All content lives on the ticket branch under `thoughts/factory/GH-<n>/`:

```
thoughts/factory/GH-123/
├── spec.md          # canonical input spec (what & why, scope, observable outcome)
├── research.md      # codebase research: patterns, constraints, file:line evidence
├── plan.md          # implementation plan (see §6.5 for the format rules)
├── journal.md       # append-only factory journal: one entry per cycle
└── reports/         # one file per verification/fix run
    ├── plan-compliance-01-01.md   # <episode>-<round>, see §6.6 fix mode and §7
    ├── spec-coverage-01-01.md
    ├── security-01-01.md
    ├── verify-fix-01-01.md   # <episode>-<attempt>, see §6.7
    ├── integration-01.md   # <landing attempt>; landing-time gate, only when main moved (§9.3)
    └── dossier.md   # the human-facing final review dossier (also posted to the PR)
```

GitHub carries only **summaries and links**: every step posts one short comment
(decisions, not steps — see §10), and the factory maintains a small marker
block appended to the issue body with links to the spec, branch, journal, and
PR. The issue's original human-written text is **never modified** — it stays
the idea-dump register it was written as.

The `thoughts/factory/` root (not `thoughts/shared/`) keeps the tree separable
from tce's layout, so a project migrating from tce keeps its history intact
and the two document conventions never mix.

Everything under `thoughts/factory/GH-<n>/` reaches the main branch inside the
ticket's squash commit. **Nothing is written to the repository after the
merge** (§9.4): the branch is gone by then, and a post-merge commit would need
a human push in projects where agents cannot write main. The factory needs
no merge reference: the PR number is recorded in the issue's marker block
when the PR opens (and in the next journal entry — the entry of the cycle
that opens the PR is committed before the PR exists, §5.1), the ticket ID is
the squash commit's scope, and the per-increment commits stay reachable
through the PR after the branch is deleted.

### 3.3 The journal

`journal.md` is append-only; each cycle that touches the ticket appends one
entry:

```markdown
## Cycle 2026-08-11T03:14Z — step: research
- Outcome: research.md written; no open questions → auto-continued to planning eligibility
- Questions asked: none (gate skipped: nothing to ask)
- Commits: abc1234
- Next step: plan
```

The journal is the inspectable history of every decision the factory made about
the ticket, the debugging surface when a run goes wrong, and — deliberately —
the raw substrate for future telemetry (cycle times, gate-failure rates, replan
frequency) without any new instrumentation.

**The last entry's `Next step` line is the ticket's derived state** (§3.4):
it is what the dispatcher resumes from when a label is stale or the human
re-queues a parked ticket, validated against the artifacts (which files
exist, PR existence, CI status, review state). The artifacts alone cannot
tell "plan awaiting approval" from "plan approved" — both are a `plan.md`
without a PR — which is why the journal, not the file set, is the source.

The last entry a ticket gets is the **landing decision entry** (§9.3): the
cycle that brings the branch up to date records that the merge is to be
requested once CI on the named head is green. The cycle that performs the
merge writes nothing — a push at that point would move the PR head past the
commit CI checked — and the merge itself is visible on the PR and the issue,
so no post-merge entry is needed. The journal is a record, never a reference
point for the review rules: a cycle commits its journal entry *before* it
posts a comment or opens a PR (§5.1 step 6), so comment timestamps and PR
numbers reach the journal one cycle late at best. §4 row 10 therefore reads
its reference points from GitHub itself (review `commit_id`, comment
`created_at`), never from the journal.

### 3.4 Who has the ball: labels

Workflow state is carried by issue labels; artifacts carry content. Labels
answer one question cheaply queryable: **whose move is it, and at which
gate?** — and, since v1.1, they name **every transition between steps**, so
the backlog board reads as a factory board.

**tsf owns a label namespace: every label the factory reads or writes is
`tsf:*`.** Labels a repository already has (`bug`, `high`, `in progress`, a
project's own `ready` bridge label on PRs, a project's `high`/`critical`
scale, …) are neither read nor written by tsf, without exception: a project
that wants a ticket picked first sets `tsf:priority`. The factory acts
**only** on issues carrying a `tsf:*` state label; everything else is
invisible to it.

Two families, one colour each so the human can filter "what needs me" with a
single saved search (`is:open label:tsf:needs-answer,tsf:needs-plan-approval,tsf:needs-review,tsf:needs-human`
— a comma is OR in GitHub search):

| Label | Family | Meaning | Set by |
|---|---|---|---|
| `tsf:queued` | factory (grey) | Released by the human; the factory determines the first step | Human |
| `tsf:research` | factory | Spec sufficient; research is next | triage |
| `tsf:plan` | factory | Research done; planning is next | research |
| `tsf:implement` | factory | Plan approved; implementation is next | plan (on approval) |
| `tsf:verify` | factory | PR open; local verification, CI and the gates run | implement |
| `tsf:dossier` | factory | All gates green; dossier is next | gates |
| `tsf:rework` | factory | Changes requested; implementation addresses the review | dispatcher (on review) |
| `tsf:landing` | factory | Approved; sync, integration gate and merge are next | dispatcher (on review) |
| `tsf:answered` | factory | Human replied to questions or to the plan summary; distillation is next | comment-pickup workflow |
| `tsf:needs-answer` | human (red) | Parked: numbered questions posted | triage, research, implement |
| `tsf:needs-plan-approval` | human | Plan pushed + summarized; awaiting the human's reply | plan |
| `tsf:needs-review` | human | CI green, dossier posted on the PR; awaiting review | dossier |
| `tsf:needs-human` | human | Blocked: attempts exhausted, environment broken, logic conflict, state mismatch | any step |
| `tsf:priority` | modifier (yellow) | Pick before other tickets | Human |

Rules:

- **Exactly one state label per factory ticket at a time** (the modifier is
  additional) — until the ticket lands: the merge cycle removes the state
  label (§9.3 step 5), because a closed ticket is nobody's move.
- **Factory-side labels are a derived view.** The derived state is the
  journal's last `Next step` line (§3.3), validated against the artifacts
  (which files exist, PR existence, CI status, review state); the dispatcher
  *corrects* a stale factory-side label rather than parking — labels are a
  cache for the board, not a second source of truth.
- **Human-side labels are authoritative for "whose move".** When a human-side
  label disagrees with the artifacts (e.g. `tsf:needs-plan-approval` but no
  plan on the branch), the factory writes a journal entry describing the
  mismatch and parks the ticket `tsf:needs-human` — it never guesses.
- **Resuming from `tsf:needs-human`:** the human fixes the cause, removes
  `tsf:needs-human` and sets `tsf:queued`. The dispatcher treats
  `tsf:queued` on a ticket that already has a journal as "resume at the
  journal's `Next step`" (§4 row 3) — which the derived-view rule above
  already permits — so no other label is ever needed to resume.
- Labels name the **next** step, set by the dispatcher when a step finished
  (the "Set by" column names the step whose outcome decides it; the write is
  always the dispatcher's, §11.3). No lock label in v1: one runner, one step
  per cycle. A `tsf:working` lock is the first thing parallel runners will
  need (§15).

**The issue is the only conversation channel** (§10): every question, plan
summary and human reply lives on the issue. The PR carries the dossier, the
gates' one-line comments and the human's native review, nothing else; a
free-text comment on the PR is not read by the factory (the dossier says so
in its last line). **Pickup after a human reply is automatic, and the human
never touches a label to answer.** tsf ships a small project-side workflow
template (installed by `/tsf:init`, §12) that runs on `issue_comment`: when
the payload is an issue (not a PR), the issue carries `tsf:needs-answer` or
`tsf:needs-plan-approval` and the commenter is one of the configured
**responders** (§12; default: the repository owner), it swaps the label to
`tsf:answered`. Which artifact the reply belongs to is not encoded in the
label: the dispatcher derives it from the branch (§6.3). Comments by
anyone else (the factory identity, other collaborators) change nothing.
Labels on issues need no further workflow to fire, so the repository's
built-in token suffices. Where the workflow is not installed, the dispatcher
falls back to polling the comments of `tsf:needs-answer` and
`tsf:needs-plan-approval` tickets each scan (one REST call per parked
ticket), applying the same responder rule. Review
outcomes need no workflow: the PR's review state is read directly (§9.2).

### 3.5 The logic head and the PR diff

Two definitions the state machine, the gates and the landing loop share;
each exists exactly once, here.

- **The logic head** of a ticket branch is its newest commit that is *not*
  a mechanical sync merge (a server-side update-branch merge, §9.3 step 1,
  or a conflict resolution the merge-resolver classified *mechanical*) and
  that touches at least one path outside `thoughts/`. A push is
  **logic-changing** iff it advances the logic head. Consequences: every
  journal, report and dossier commit is inert by construction; an
  implementation, rework or verify-fix commit always advances it; a
  resolution classified *logic* advances it. Gate reports name the logic
  head they judged (§7), a report naming another logic head is stale
  (§4 row 8), and an approval is valid while the logic head has not moved
  past the commit it was given on (§4 row 10, §9.3 step 4). The plain PR
  head is deliberately *not* used for any of this: the commit that adds a
  report moves the PR head, so a report could never name it.
- **The PR diff** is the three-dot diff of the branch against the base
  branch — merge-base to head, what GitHub's Files tab shows — with
  `thoughts/` excluded. It is the diff every gate receives (§7, §11.2) and
  it stays correct after a sync merge, when a "recorded base commit → head"
  range would contain main's whole delta. No base commit is recorded
  anywhere.

## 4. The state machine

Derived state → next step, evaluated by the dispatcher in order:

1. `tsf:answered` → **distill** the human's reply into the artifact the
   parking step maps to (§6.3: triage and research → `spec.md`; plan gate
   and implement → `plan.md`; the parking step is the journal's last
   transition), then continue with the step the artifacts imply (at the plan
   gate: the plan step, which either proceeds on approval or replans).
2. `tsf:queued`, no `spec.md` on branch (or no branch) → **triage**.
3. `tsf:queued` with spec and no journal (the `/tsf:spec` door), or
   `tsf:research` → **research**. `tsf:queued` with a journal is the resume
   path (§3.4): the journal's last `Next step` names the step, and the
   table continues at that step's row.
4. `tsf:plan` → **plan** (ends at the plan gate: `tsf:needs-plan-approval`).
5. `tsf:implement` → **implement** (ends with the PR open — never a draft,
   §9.1; `tsf:verify`).
6. `tsf:verify`, local verification (§8) **red** → **verify-fix** (bounded
   attempts per verification episode, §6.7; then `tsf:needs-human`).
7. `tsf:verify`, local **green**, CI on the PR head **pending** → **not
   actionable** this cycle (§5.2): the pick continues with the next ticket
   and the closing report names the pending head. CI **red** →
   **verify-fix** against CI (bounded; then `tsf:needs-human`). In
   verification mode `ci` (§7) the CI result alone is the verification.
8. `tsf:verify`, local and CI **green**, gate reports missing **or naming
   another logic head** (§3.5) than the branch's current one → **the three
   post-implement gates** (plan-compliance, spec-coverage, security) in one cycle,
   dispatched in parallel and in the foreground (§7). Any "not met" or
   blocking security finding → back to implement in **fix mode** (§6.6;
   bounded per episode, then `tsf:needs-human`). All green → `tsf:dossier`.
9. `tsf:dossier` → **dossier** (writes and posts the dossier, validates the
   PR title/body; `tsf:needs-review`).
10. `tsf:needs-review`, read from GitHub, never from the journal (§3.3):
    the reviewer's latest review counts (GitHub keeps one state per
    reviewer). An **approving** review whose `commit_id` is at or after the
    logic head (§3.5) — no logic-changing commit after the commit it was
    given on — → `tsf:landing`. A **"changes requested"** review whose
    `submitted_at` is newer than the `created_at` of the factory's last
    dossier or addendum comment on the PR → `tsf:rework`; an older one is
    the review the rework already addressed and is ignored. An approval
    behind the logic head is stale: the ticket stays parked and the dossier
    addendum that moved the head has already asked for a new one.
11. `tsf:rework` → **implement** in rework mode (review comments as input),
    then `tsf:verify` again (CI runs on the push, gates re-run on the new
    diff, dossier addendum).
12. `tsf:landing` → the **landing loop** (§9.3): at most one landing **in
    flight** (every other `tsf:landing` ticket is not actionable while one
    awaits CI, §5.2), and at least two cycles per landing (a decision cycle
    that writes, then a write-free merge cycle once CI on the decided head
    is green). Ends with the merge, or with `tsf:verify` (CI red on the
    decided head: a new verification episode, §6.7, and the approval is
    re-earned through row 10), `tsf:needs-review` (logic-changing
    resolution, integration risk) or `tsf:needs-human` (unresolvable).
13. `tsf:needs-*` with no new signal → skipped.

Auto-continue rule (agreed): triage and research park the ticket
`tsf:needs-answer` **only if they actually have questions**. A research step
with no open questions journals "gate skipped: nothing to ask" and moves the
ticket to `tsf:plan` — no idle human touchpoint. The plan gate and the final
review gate are **never** skipped in v1.

The human's total interaction surface per ticket, in the best case: label it
`tsf:queued`, reply "approved" to the plan summary, approve the PR from the
dossier. Everything after the approval is the factory's (§9).

## 5. The cycle

### 5.1 `/tsf:cycle` — one cycle, thin dispatcher, fresh-context step

```
1. Scan:    REST calls: open issues carrying a tsf:* state label, the PR per
            ticket branch, check runs and review state per PR head (see §10
            for the REST rule). Closed issues are never read (§9.4).
2. Pick:    highest-priority actionable ticket (see §5.2). None → run the
            project's `prepare` command for the base branch (§8), report
            idle, end.
3. Decide:  next step from the state table (§4).
4. Prepare: in the factory clone — run the project's `prepare` command for
            the ticket branch (hard reset + checkout), then the rest of the
            environment contract as the step needs it (§8).
5. Execute: spawn the step's named agent (§11) with a fresh context, in the
            foreground. Worker agents re-read the ticket's artifacts in chain
            order (spec → research → plan, as applicable) from disk, perform
            the step, commit what they produced on the branch, and return a
            result block. Gate agents return their report content.
6. Write:   the dispatcher performs every GitHub write for the step (§11.3):
            it appends and commits the journal entry, pushes, opens the PR
            when the step calls for it, posts the one summary comment, and
            sets the next label — each write read back (§10).
7. Report:  relay the agent's compact summary to the invoker, plus the
            tickets that were skipped for a pending CI run, so the `/loop`
            runner (§5.3) can pace its next wake-up. End of cycle.
```

The dispatcher itself does no content work — its context stays small, which is
what makes the `/loop` runner viable (§5.3). The "single gh query" of v1 is
replaced by a handful of REST calls (§16): still cheap, and the only form
that works inside a sandbox that allows REST but not GraphQL.

### 5.2 Priority (hard-coded in v1)

A ticket is **actionable** when the state table (§4) yields a step to run
now. Not actionable, and skipped by the pick rather than ending the cycle:
a ticket waiting on a CI run (row 7, the landing merge cycle of §9.3),
a `tsf:needs-*` ticket without a new signal (row 13), and every
`tsf:landing` ticket other than the one landing in flight (§9.3). A cycle
ends idle only when no ticket at all is actionable. Among the actionable:

1. Landing tickets first — approved work is finished before anything else
   moves (and each landing invalidates the other approved PRs, §9.3).
2. Then other in-flight actionable tickets — a ticket with any artifact
   progress beats an untouched one.
3. Among those, `tsf:priority`-labeled before unlabeled.
4. Then oldest first.

No configuration, no scoring. Deliberately simple until real usage shows a
need.

### 5.3 Runners

- **Manual:** `/tsf:cycle` — one cycle; the testing and early-trust mode.
- **Continuous, v1:** `/loop /tsf:cycle` — Claude Code's self-paced loop
  re-invokes the cycle in the same session; after each cycle the model
  schedules the next wake-up itself (1 to 60 minutes) and the cycle's closing
  report says which: short after a productive cycle, long when nothing was
  actionable. This is the design's continuous mode; there is no `/tsf:run`
  (revised, §16.24 — the platform offers no wait primitive to a command,
  and the loop already exists). `/loop 5m /tsf:cycle` is the fixed-interval
  variant. Both reuse one session: the dispatcher's context accumulates
  cycle summaries and is auto-compacted, which is harmless because all state
  lives in labels + artifacts; the loop dies with the session, and after an
  idle gap of more than an hour the next turn re-reads the context uncached.
  A command flagged `disable-model-invocation: true` cannot be a `/loop`
  prompt, so `cycle` stays unflagged (§12).
- **Future:** a shell `while` loop around `claude -p "/tsf:cycle"` — each
  cycle a brand-new session. Verified against current official docs: headless
  `claude -p` under a Pro/Max login draws from the **subscription allowance**
  (API-token billing only applies with an explicit API key / `--bare`), so
  this runner is economically viable; it can later be multiplied for parallel
  factories.

**The runner session is opened in the factory clone** (§8): the clone is
the session's project directory, so the project's settings, sandbox
profile, hooks and allowlist apply to it exactly as to any checkout, every
script and agent works on the current directory, and no clone path is
configured anywhere. From the moment a factory session runs in a clone,
**the factory owns that directory** — no human edits, no second session
in it; the human works in their own working copy.

The factory is expected to run inside a sandboxed environment (network/exec
cage), with a dedicated clone (§8) — so the permission posture can be
permissive *inside that boundary*. `/tsf:init` still writes a recommended
allowlist (`gh api …`, `git` incl. push, the project's test commands) so
unattended runs never stall on a prompt. Residual risk stated honestly: an
unattended agent with push and `gh` rights; the cage, the dedicated clone,
and a machine identity the server refuses on the main branch (§9) are the
containment.

## 6. Step specifications

Each step runs as a fresh-context agent from the roster in §11; each step's
spec is its agent's system prompt. Common contract for worker agents: re-read
all input artifacts from disk in chain order (spec → research → plan) even if
an earlier cycle produced them; commit what you produce on the ticket branch;
return a **result block** — the summary comment text, the journal entry, the
next label per §4, and the question comment when the step parks the ticket.
Workers never push, comment, or label: the dispatcher performs every GitHub
write from the result block (§11.3), so where a step below says it "posts",
"labels" or "pushes", read "returns for the dispatcher to post, set or
push". Gate agents
return their report content the same way. Document skeletons (spec,
research, plan, journal entry, report, dossier, question comment, PR body)
ship as reference templates read at the point of use.

### 6.1 `/tsf:spec` (interactive, on the shell)

The one deliberately interactive command: guided spec authoring in the spirit
of a good ticket discussion — iterating WHAT and WHY with the human, pushing
for the sufficiency minimum (clear scope, observable outcome, at least one
concrete anchor into the system). Then: create the GitHub issue (title + short
human summary + link block), then create the ticket branch and commit
`spec.md` on it **over REST** — a ref from the base branch's head, then the
contents endpoint — and offer to label `tsf:queued`. No checkout is touched:
not the human's working copy (§8) and not the factory clone, which may be
mid-cycle and is the factory's alone (§5.3). The human's own login authors
both the issue and the spec commit, which is what they are.

Reasoning: spec iteration is a focused, high-bandwidth conversation; doing it
asynchronously over issue comments would mean repeated question bursts and
context-switching for the human — the worst interaction pattern for exactly
the person the factory serves. Async refinement exists (triage questions), but
authored specs are the paved road.

### 6.2 Triage

For tickets labeled `tsf:queued` without a spec: on the ticket branch (which
the prepare phase created from the base branch, §8), distill the
raw issue body into an initial `spec.md`, then test it for sufficiency (scope /
observable outcome / anchor). Insufficient → post numbered, batched questions
(one comment, everything at once — no dribbling, in the §10 question format)
→ `tsf:needs-answer`. Sufficient → journal it and set `tsf:research`.

### 6.3 Answer distillation

Whenever a step starts on a ticket labeled `tsf:answered`: read the human's
comment reply and fold it into one artifact as a commit, by a **fixed
mapping from the step that parked the ticket** (the journal's last
transition, §3.3):

- **triage** and **research** questions → `spec.md`. Research's questions
  are decisions about the change, and decisions belong in the spec; the
  research document stays a description of what exists.
- **plan-gate** feedback → `plan.md`.
- **implement** questions (§6.6) are plan-gate questions: the answer goes
  into `plan.md`, the plan is re-summarized and goes through the plan gate
  again.

So the artifact stays the single canonical input and truth never lives
scattered in a thread. Reply with a one-line confirmation, then proceed with
the actual step. At the plan gate the reply is also the approval channel: an
approving reply moves the ticket to `tsf:implement`; anything else is
feedback and the plan is revised and re-summarized.

### 6.4 Research

Codebase research producing `research.md`: existing patterns, the files and
mechanisms the change touches (file:line evidence), constraints, impact
analysis, options where genuinely open. Documentarian register — describes
what exists, does not design. Works inline (see §11). Open questions that
materially affect planning → batched comment → `tsf:needs-answer`. Otherwise
auto-continue (§4) to `tsf:plan`.

### 6.5 Plan

Produces `plan.md` from spec + research. **Format rules (agreed, deliberate
departure from tce):**

- The plan is a set of **independently verifiable increments**, not an ordered
  walkthrough. Each increment carries its own tests/verification so it is
  self-checkable by the implementing agent the moment it is built. Ordering is
  left to the implementer unless a real dependency forces it — then that
  dependency is stated on the increment, never as a global sequence.
- Every increment must state: what changes, where (anchored in research
  evidence), and how it is verified automatically. Manual-only verification is
  flagged explicitly and surfaces later in the dossier.

Ends by posting the **plan summary** comment and labeling
`tsf:needs-plan-approval`. The summary follows the question-comment shape
(§10): the informed understanding, the key findings, then the crucial
decisions taken (and alternatives rejected, one line each), anything
irregular, and — if any — the numbered questions the human must answer.
**Never the increment list.** The full plan is one click away: the summary
links `plan.md` (and `research.md`) as GitHub file links on the ticket
branch, which render as pages — there is no PR at this stage and none is
needed for review. The summary's job is to let the human approve intent and
trade-offs in under a minute, by replying to the comment.

### 6.6 Implement

Consumes the approved plan. Works increment by increment in the factory clone
(environment contract active, §8), running each increment's own verification
immediately after building it. Per-increment commits in the project's
convention. Deviations from the plan that survive contact with reality are
**written into `plan.md` as a dated addendum that restates the affected
increment's verification criteria** — exactly as rework mode does below —
and the reasoning is journaled. The plan is what the plan-compliance gate
(§7) reads; a deviation that lives only in the journal would fail the gate
on every fix round, since the gate never sees the journal. The dossier's
"plan deviations" item (§9.1) lists these addenda. A mismatch too large to
resolve by an addendum → questions → `tsf:needs-answer` (answered into the
plan, §6.3).
Ends with the implementation committed; the dispatcher then pushes and opens
the **PR** — never a draft (§9.1) — from the PR template (title
`<type>(GH-<n>): <spec title>` in the project's commit convention — the
squash commit's subject; body with the closing keyword, the spec link, the
plan summary and artifact links), records the PR number in the issue's
marker block (§3.2), and sets `tsf:verify`. CI starts on that push and is
read at the next pickup.

**Rework mode** (`tsf:rework`): the same agent with the review's comments as
additional input. It records the requested changes in the plan as an
addendum, implements them, commits, and returns the ticket to `tsf:verify`.

**Fix mode** (§4 row 8): the same agent with the failing gate reports (§7)
as additional input, plus the plan. The dispatcher enters it, never a
label: the PR exists and a gate report for the PR's current head says "not
met" or carries a blocking finding. The agent fixes exactly what the
reports evidence, commits, and returns the ticket to `tsf:verify`, where
the gates run again on the new head. Fix rounds are **bounded per
verification episode** (§6.7) by the `gate_fix_bound` constant in
`config.md` (§12; default: 3); the round counter is derived from the gate
report filenames, `reports/<gate>-<episode>-<round>.md`, exactly as the
verify-fix attempt counter is. Exhausted → `tsf:needs-human` with the last
reports linked.

### 6.7 Verification fix

The factory never watches CI — it **reads results at pickup**. This step
makes a red verification green, in either of two places:

- **Local**: the project's verification command (§8) fails in the clone
  after implementation. Diagnose from the local output, fix, commit.
- **CI**: the PR's checks on the current head are red (read at pickup; the
  PR is never a draft, so CI runs on every push). CI logs may be unreadable
  from inside a sandbox (the first consumer's proxy refuses the log host),
  so the **primary diagnosis is local reproduction** through the environment
  contract; check logs are used when reachable. CI red with local green is
  reported as such — an environment difference, escalated after the bound.

Both live under `tsf:verify`; the dispatcher tells from the scan which one
applies.

Attempts are bounded **per verification episode**, not per ticket. An
episode starts each time the ticket enters `tsf:verify` — from implement,
from rework, or from a landing whose decided head came back CI-red (§9.3
step 3) — and the bound (default: 3) starts afresh with it; exhausted →
`tsf:needs-human` with a summary of what was tried. **The episode number comes from the journal:** every transition into
`tsf:verify` is journaled with its episode number, and each run writes
`reports/verify-fix-<episode>-<attempt>.md`, so the dispatcher derives the
attempt counter from the files on the branch like every other progress
fact. (Filenames alone cannot tell "episode 1, attempt 3" from "episode 2,
attempt 1"; the journal's last transition can.) Rework rounds need no ceiling of
their own: each one is a human decision, not a factory loop.
Green verification is a hard precondition for every gate — no review effort
is spent on red builds. There is no fix commit the gates do not see: every
verify-fix commit advances the logic head (§3.5), so once the ticket is
green again row 8 re-runs the gates on the new head, and — when the episode
began after a dossier existed (rework, landing) — the dossier gets an
addendum and the approval is re-earned through row 10.

## 7. The verification pipeline (fixed in v1)

The pipeline is fixed and always on. Its precondition is **green project
verification in the factory clone** (§8) **and green CI on the PR head**:
the PR is opened as soon as the implementation is pushed and is never a
draft, so CI runs on every push and the dispatcher reads its result at
pickup (§6.7). The local run gives the factory its evidence first and
cheapest; CI confirms it on the real head before any gate spends tokens.
Projects whose environment cannot run the verification locally set the
config's verification mode to `ci`: CI green alone is then the precondition —
slower feedback, same pipeline.

Four gate agents, each a fresh-context subagent returning a report the
dispatcher writes to `reports/` (and summarizes in a one-line PR comment).
Every report starts with a `head: <sha>` line naming the **logic head**
(§3.5) it judged — never the plain PR head, which the report's own commit
moves; a report naming another logic head is stale and counts as missing
(§4 row 8), which is how a fix, rework or verify-fix push causes the gates
to re-run while journal and report commits do not. The three
post-implement reports are numbered `<gate>-<episode>-<round>.md` (§3.2,
§6.6 fix mode) and the integration report `integration-<n>.md` per landing
attempt, so nothing is ever overwritten and the fix-round counter is
derivable from the files.
The three post-implement gates run **in one cycle, dispatched in parallel
and in the foreground** — the dispatcher waits for all three verdicts before
it writes anything or ends the cycle (a turn that ends with an agent still
running is the failure mode tle documented). All four are **context-starved
by hard prompt constraint**: they receive their stated inputs only — never
the plan-production reasoning, never the implementation transcript — because
a checker that sees the implementer's reasoning rationalizes gaps (the
review's strongest practitioner lesson, already proven in tce's compliance
checker).

1. **Plan compliance** — inputs: the plan's per-increment verification criteria
   + the PR diff (§3.5). One evidenced
   verdict per criterion: met / not met / cannot verify from diff / needs
   human verification. Any "not met" → back to implementation (bounded, then
   `tsf:needs-human`).
2. **Spec coverage** — inputs: `spec.md` + the diff. Verifies the *ticket's*
   requirements independently of the plan — this is the spec-drift catcher:
   a plan can be faithfully implemented and still miss what the spec asked.
3. **Security review** — inputs: the diff + the touched files' surroundings.
   Each finding is classified **blocking** (a concrete, evidenced defect the
   implementation must fix) or **advisory** (a judgment call for the human).
   Blocking findings route exactly like a "not met" from gates 1 and 2: back
   to implementation in fix mode (bounded, then `tsf:needs-human`), and the
   gates re-run on the new diff. Advisory findings go into the dossier's open
   items. The gate itself never writes: it is a verdict function like the
   other three (§11.2).
4. **Integration** (landing time, §9.3) — inputs: the PR diff (§3.5), the
   diff the main branch took since the PR's approval, and `spec.md`. Runs
   only when main moved after the approval — on a restarted landing, since
   the main head the last integration report recorded. Answers one
   question: can the two changes
   break each other in ways the tests would not catch (a changed contract the
   PR calls, migration ordering, shared configuration, duplicated behaviour)?
   Verdict: safe / risk, with a concrete description. This is the deliberate
   token spend that covers "green individually, broken together" beyond what
   serial CI already covers.

**CI green** is not an agent but a dispatcher-checked precondition that sits
before the gates (§4 step 8) and again before the merge (§9.3).

"Needs human verification" verdicts are never silently passed — they are
collected into the dossier's checklist. Extending/configuring the gate family
(architecture conformance, regression scope, project-custom gates) is
explicitly future work; v1 ships exactly these, always on.

## 8. The environment contract

The plugin stays environment-agnostic through an **environment contract**:
a fixed set of named commands that the **project provides as its own
scripts** and registers in `.claude/tsf/config.md`. The factory never runs a
destructive or environment-specific operation as an ad-hoc command line; it
runs the project's script for it. That keeps every such operation in one
reviewable, allowlistable place under the project's control, and it is what
lets `/tsf:init` check up front that a project is factory-ready (§12).

Four commands are **mandatory** — the factory does not run without them:

- **`prepare`** — put the factory clone into a pristine state for a branch:
  discard every local change and untracked file the factory left behind
  (ignored files, which hold environment state, stay), fetch, check out the
  named ticket branch, and prune branches deleted upstream after a merge.
  **If the named branch does not exist on the remote, create it locally
  from the base branch** — this is how a triaged ticket gets its branch
  (§6.2); the dispatcher's write phase pushes it with the first commit.
  Called by every cycle's prepare phase (§5.1) with the ticket branch as
  its argument, and with the base branch when nothing is actionable (§5.1
  step 2).
- **`env_up`** — bring the environment up for the current checkout. For a
  factory clone this is typically *services only* (database, cache), not the
  application servers, unless a step needs a running app. Runs in **every
  implementation-flavored cycle** and must therefore be idempotent (a
  running environment is a no-op).
- **`env_reset`** — return the environment to a clean baseline for the
  current branch (reset/re-seed DB, re-run migrations from baseline). Run
  **on ticket switch**, not every cycle — consecutive cycles on one ticket
  keep the warm environment. A project whose verification suite manages its
  own state still provides it: the script then only records that fact, so
  the factory never has to guess whether a reset is missing or unneeded.
- **`verify`** — the project's verification suite (lint, types, tests), the
  same command its CI runs. Its exit code is the pipeline precondition (§7)
  and what verify-fix (§6.7) makes green.

One is **optional**:

- **`env_check`** — fast health probe before implementation; failure →
  `tsf:needs-human` instead of an agent flailing against a broken stack.

(A `release` command existed in v1.1 and is deferred to a later version,
§15; v1 ships no deploy step.)

Only implementation-flavored steps (implement, verify-fix, the local
verification the gates depend on) need `env_up`, `env_reset` and `verify`;
`prepare` runs in every cycle.

Execution model v1: **one dedicated factory clone, serial hands-on work.** The
factory owns a ready-made clone (never the human's working copy — a working
copy with uncommitted state must never be factory ground), and the
`/tsf:cycle` session is started *in* it (§5.3): the clone is the session's
project directory, and once a factory session runs there the directory is
the factory's alone. Every cycle's
prepare phase runs the project's `prepare` command, which **hard-resets the
clone**. Agreed reasoning: in a dedicated clone, anything the reset destroys
is something the factory itself left behind, so unconditional reset is safe
and strictly better than parking tickets over dirty state — and because the
reset is the project's script, a project can keep its usual deny rules for
raw `git reset --hard` / `git clean` in place for every session, the factory
clone included.

The clone runs inside the project's sandbox profile with the factory's own
credentials (§9.2) — a second checkout of the same repository needs the
sandbox's filesystem grant for its path; credential injection keyed on the
repository's URL (the first consumer's case) needs nothing new, injection
keyed on the checkout path would. Running the clone next to the human's working copy on one
machine is the project's `env_up` problem: fixed service ports collide, so
the project's environment must allocate per-checkout ports (or the factory
runs while the human's environment is down). Neither is the plugin's concern
beyond documenting it in `/tsf:init`.

The migration/DB-isolation problem is thereby the project's `env_reset`
implementation, where it belongs. A project on devenv can implement it as
"drop DB, migrate, seed" (acceptable when run only on ticket switches). A
project that later moves to Docker Compose can implement per-ticket stacks
(`COMPOSE_PROJECT_NAME=tsf-GH-<n>`) under the *same* contract — which is also
what later unlocks worktrees and parallel implementation. Neither migration is
a precondition of the factory. Honest fallback: if the local environment
cannot run the tests, CI remains the authoritative verifier (§7, verification
mode `ci`) — slower feedback, functioning pipeline.

## 9. Dossier, final gate, landing

### 9.1 Review dossier

After all gates are green: `reports/dossier.md`, posted to the PR. Contents:

1. **Condensed narrative** — what was built, the crucial decisions, obstacles
   worked around. Short enough to read in two minutes; written for a human
   deciding *whether* to look deeper, not documenting everything.
2. **Where to look** — a curated list of GitHub permalinks (file + line
   ranges) each with one sentence on *why* that spot deserves eyes: the risky
   part, the judgment call, the irregular bit.
3. **Open items** — gate verdicts needing human verification, security
   remarks not auto-fixed, the plan's deviation addenda (§6.6).
4. **Overlap warning** — the other open factory PRs that touch the same files
   or modules, so the human knows which order to approve in and where a
   combination deserves a second look.
5. **Closing line** — how to respond: approve or request changes with a
   native review; anything else goes on the issue, because the factory does
   not read free-text PR comments (§10).

The dossier step also validates the PR's title and body against the template
(§6.6) — the title is the squash commit's subject. The dispatcher then sets
`tsf:needs-review`. The dossier and every later addendum are comments by
the factory identity on the PR; their `created_at`, read from GitHub, is
the reference point of §4 row 10 (never a journal timestamp, §3.3).
**The PR is never a draft** (revised, §16.22): CI has been
green on its head since before the gates, and the draft flag would carry no
information the label does not — while un-drafting is a GraphQL-only
operation that would need a label bridge and an App token in a REST-only
sandbox. A PR without a dossier comment is simply not ready for review yet.

Reasoning: full line-by-line human review of every factory ticket does not
scale and degrades into rubber-stamping (the DORA/Finster failure mode); a
curated dossier concentrates scarce human attention exactly where the agent —
who knows where the bodies are buried — says it matters, while the human
retains the depth decision. **The dossier comment on the PR, with
`tsf:needs-review` on the issue, is the one signal that a final review is
expected.**

### 9.2 Final human gate: one approving review

The human's gesture is a native GitHub review on the PR — visible in the
timeline, mobile-friendly, and possible because the PR's author is the
factory's machine identity, not the human:

- **Approve** → `tsf:landing`. This is the last thing the human does for the
  ticket.
- **Request changes** (with comments) → `tsf:rework`: the implement agent
  addresses the review (§6.6), the gates re-run, the dossier gets an
  addendum, the ticket returns to `tsf:needs-review`.

The approval is **enforced by the server, not by the factory**: the
repository's ruleset requires one approving review before any merge to the
main branch, and the factory's identity is a plain write collaborator with no
bypass — the ruleset refuses it on the main branch directly (proven in the
first consumer project) but permits a PR merge that satisfies every rule.
"Dismiss stale reviews on push" and "require approval of the last push" stay
**off**, so the approval survives the factory's mechanical sync pushes; the
one thing the server cannot express — re-approval only after a
*logic-changing* push — is the factory's rule (§9.3).

### 9.3 The landing loop

After approval the factory lands the work without further human involvement.
The dispatcher keeps **at most one landing in flight, oldest approval
first**: while a landing ticket has a decision entry awaiting CI, every
other `tsf:landing` ticket is not actionable (§5.2) — non-landing work
proceeds — because every landing makes the other approved PRs "behind"
under the strict up-to-date rule and a second sync would only waste a CI
run and void the first decision. A landing spans **at least two cycles**: a
decision cycle that writes (steps 1 to 4) and a write-free merge cycle
(step 5). The split is forced by the ruleset: the required check is
evaluated on the PR head, so any push — a journal entry included — makes
the head unchecked and the merge refused. For the chosen ticket:

1. **Sync.** The dispatcher first asks GitHub to do it: the REST
   update-branch endpoint merges the main branch into the PR branch on the
   server, the same operation as the "Update branch" button's merge variant
   (never rebase, never force-push). Clean merge → the branch has moved and
   CI has started; the dispatcher runs `prepare` again so the clone holds
   the merged head before the gate and the diffs. Conflict (the call
   fails and changes nothing) → the merge-resolver agent merges in the
   clone (`git merge`), **resolves it** and classifies the resolution:
   - *mechanical* — independent hunks, imports, lockfiles, formatting,
     renames;
   - *logic* — it had to choose between behaviours, or adapt the PR to an
     API or contract that main changed.
   Either way it journals what it did and why, and returns one comment. It
   never comes back with a bare "this does not merge": if it cannot resolve,
   it describes the concrete decision the human must take →
   `tsf:needs-human`.
2. **Integration gate** (§7 gate 4) — only when main moved since the
   approval, or, on a restarted landing, since the main head the last
   `integration-<n>.md` recorded. Inputs: the PR diff (§3.5), the main
   delta, the spec. Verdict safe / risk.
3. **Verify.** The sync and the decision push (step 4) start CI on the real
   combination; the result is read at the next pickup, in the merge cycle
   (step 5). Red → the ticket leaves landing for **`tsf:verify`**, a new
   verification episode (§6.7): verify-fix, the gates on the new logic head
   (§4 row 8), a dossier addendum, `tsf:needs-review`. A verify-fix commit
   advances the logic head, so the approval is stale by §4 row 10 and the
   human re-approves from the addendum; the landing then restarts at
   step 1.
4. **Decide and record.** The factory decides for the merge only when *all*
   of: branch up to date, the resolution was mechanical (or there was
   none), the integration gate said safe (or did not run), and **the latest
   approving review's `commit_id` is at or after the logic head** (§3.5,
   §4 row 10 — a mechanical sync merge does not move it). It then
   writes the landing decision entry (§3.3) — "merge when CI on head
   `<sha>` is green" — commits it with the integration report, pushes, and
   ends the cycle. Otherwise it posts a dossier addendum that states exactly
   what was decided and why, labels `tsf:needs-review`, and waits for a
   second approval.
5. **Merge (write-free).** A later cycle finds the decided head unchanged
   and CI green on it, and first reads the PR's `mergeable_state`:
   `behind` means main moved since the decision — routine, not a failure
   under §10's retry rule — so the decision is void and step 1 starts over,
   silently; `clean` → it merges the PR over the REST merge endpoint —
   **squash**, subject from the PR title (`<type>(GH-<n>): …`), the body's
   closing keyword closes the issue. It writes nothing to the branch. If
   the head has moved since the decision (a human pushed), the decision is
   likewise void and step 1 starts over; CI red on the decided head is
   step 3's exit. After the merge its one remaining write is a label PATCH
   that removes the `tsf:*` state label (§3.4) — a GitHub write, not a
   repository write (§3.2). The server enforces the rules of §9.2; the
   factory only chooses *when*.
   *(Spike before the landing loop is planned, in the consumer project:
   confirm the sandbox and the ruleset accept the merge and the
   update-branch calls for the factory identity; if not, the fallback is a
   label-bridge workflow that merges with the App token, §16.)*

Serial landings mean every PR is verified against the main branch it actually
lands on — the merge-queue guarantee at the test level, without the merge
queue (unavailable to user-owned repositories). The integration gate adds the
semantic level on top.

**Squash reasoning (agreed):** the factory's natural atomic unit on main is
the ticket. Per-increment commits are agent checkpoints — valuable during the
process (dossier links, per-phase diffs, resumability) and permanently
readable in the PR, but not curated history. One commit per ticket keeps main
bisectable at ticket granularity and makes revert = revert one commit — the
undo semantics dossier-level review needs. It also collapses the landing
step to something boring and reliable, which is exactly what the merge step
must be. (Curated-rebase integration: future work, if tickets ever carry
meaningful sub-structure.)

### 9.4 After the merge

The merge closes the issue through the closing keyword and, with the
repository's delete-branch-on-merge setting, deletes the ticket branch; where
the setting is off the factory deletes the remote branch over REST. The
merge cycle removes the issue's `tsf:*` state label (§9.3 step 5), and the
scan reads open issues only (§5.1), so a landed ticket is never picked
again and `prepare` never re-creates its deleted branch. The next
prepare phase prunes and drops the local branch. **Nothing is written to the
repository after the merge** (§3.2): the journal's last entry and every
report already sit inside the squash.

The factory has no deploy step in v1: whatever the project does on a push to
its main branch happens, exactly as for a human's merge. A release step that
decouples deploys from landings is deferred to a later version (§15).

## 10. GitHub communication rules

- **Every write is the dispatcher's.** Agents return text; only `/tsf:cycle`
  (and, interactively, `/tsf:spec` and `/tsf:init`) talk to GitHub (§11.3).
- Every step gets **exactly one** comment: a few sentences, decisions and
  outcomes — never step lists, never transcripts — plus artifact links.
- **The issue is the single point of communication.** Questions, plan
  summaries and the human's replies are issue comments; the PR carries only
  the dossier, the gates' one-liners and the human's review (§9.2). The
  factory never reads free-text PR comments, and the dossier's last line
  tells the human to reply on the issue or use a review.
- Questions are **batched**: one numbered comment per parking, everything the
  step needs, so the human context-switches once. The question comment
  follows a fixed shape (reference template): the informed understanding,
  the key findings, then the numbered questions **in full** — never "see
  research.md". The human answers by replying to the comment; that reply is
  the only gesture (§3.4), and only replies by a configured responder count.
- The issue body's original text is never edited; the factory only maintains
  its appended marker block (`<!-- tsf:links -->` … `<!-- /tsf:links -->`)
  with current links (spec, branch, journal, PR).
- The plan summary and dossier follow their content rules (§6.5, §9.1):
  decisions, not steps; guidance, not volume.
- **REST only.** Every GitHub operation uses the REST API (`gh api …`), never
  GraphQL-backed porcelain (`gh issue …`, `gh pr checks`, `gh pr ready`,
  `gh label create`, `gh pr merge`): the first consumer's sandbox allows REST
  scoped to one repository and blocks GraphQL permanently, and REST works
  everywhere else too. tsf needs no GraphQL-only operation: PRs are never
  drafts (so nothing is un-drafted), auto-merge is not used, and the merge
  and the branch sync have REST endpoints. Should a project's sandbox refuse
  one of those two, the fallback is a **label bridge**: a label the factory
  sets over REST, consumed by a project-side workflow with an App token.
- **Every write is verified.** After a label PATCH the factory reads the label
  set back; after posting a comment it confirms the comment exists; after a
  merge or sync call it confirms the resulting state. One
  retry on a transport error; a second failure parks the ticket
  `tsf:needs-human` with the failed operation in the journal. Label updates
  send the **full** label set, since sub-resource routes may be forbidden:
  the helper re-reads the issue's labels immediately before the PATCH and
  merges its one change into that set, so non-`tsf:*` labels pass through
  unchanged and a human edit between scan and write is not lost.
- The PR title and body are generated from the template and validated by the
  dossier step (§9.1) — the title is load-bearing for the squash commit.

## 11. The agent roster

Steps execute as **plugin-defined agents** (`agents/*.md`, auto-discovered,
namespaced `tsf:*`) rather than as generic subagents reading step specs from
reference files. Reasoning:

- **Enforced tool scoping.** An agent's frontmatter restricts its toolset by
  configuration, not by prompt discipline. The verification gates are
  read-only *mechanically* — a gate cannot run `gh`, push, or edit code even
  if its reasoning drifts. (tce proved this pattern with its
  plan-compliance-checker.)
- **The step spec sits in the strongest attention position** — the agent's
  system prompt in a fresh context, immune to compaction by construction.
- **A named contract per step** — each agent file states its inputs, outputs,
  and forbidden actions in one reviewable place.

Every step agent works **inline**: no fan-out into locator/analyzer helpers.
v1 stated this as a platform limit; TP-0034 research found subagents may now
nest. Whether inline stays a deliberate choice (enforced by omitting `Agent`
from worker tools) is a planning decision; the roster below does not depend
on it, since each step owns an entire fresh context and the artifact chain
keeps every context's job narrow.

### 11.1 Workers (read-write, local only)

File tools plus Bash for local `git` (commit, diff, log — never push) and
the project's commands; no `gh`. They carry the §6 common contract: work
from the artifacts on disk, commit on the branch, return a result block.

| Agent | Step | Input artifacts (re-read from disk, chain order) |
|---|---|---|
| `tsf:triage` | §6.2 | issue body (passed in), repo conventions |
| `tsf:research` | §6.4 | spec |
| `tsf:plan` | §6.5 | spec → research (+ plan-gate feedback when present) |
| `tsf:implement` | §6.6 | spec → research → plan (+ review comments in rework mode) |
| `tsf:verify-fix` | §6.7 | plan (as context) + local verification output or CI results + diff |
| `tsf:manual-verify` | §6.7 | plan (its `**Manual**` items) + the project's own commands |
| `tsf:dossier` | §9.1 | everything on the branch: spec → research → plan → journal → reports, plus the diff and the other open factory PRs |
| `tsf:merge-resolver` | §9.3 | the approved PR whose server-side sync conflicted, the main branch's delta, the merge state |

The dossier agent is deliberately **not** context-starved — its job is honest
human-facing synthesis, which requires seeing everything, including the
journal's recorded obstacles and every gate report.

### 11.2 Gates (read-only, context-starved by configuration)

Tools: `Read, Grep, Glob` — no Bash, no Write, no network (`LS` is not a
Claude Code tool; v1 listed it by inheritance from tce's agent files).
Because a gate cannot run `git` or `gh`, it is a **pure verdict function**:
the dispatcher computes the PR diff (§3.5: three-dot against the base
branch, `thoughts/` excluded), passes the
gate exactly its §7 inputs in the spawn prompt, receives the report content
back, and itself writes the report file (§7: `head:` line first, numbered
per episode and round) and performs the writes of
§11.3. Since v1.2 every agent works this way; for the gates it additionally
buys absolute enforcement of the starvation contract.

| Agent | Inputs (nothing else) | May read | Must never see |
|---|---|---|---|
| `tsf:plan-compliance` | per-increment criteria + diff | post-change source files | `thoughts/` docs, plan prose, any transcript |
| `tsf:spec-coverage` | `spec.md` + diff | post-change source files | research, plan, any transcript |
| `tsf:security` | diff | touched files and their surroundings | `thoughts/` docs, any transcript |
| `tsf:integration` | PR diff + main delta since approval + `spec.md` | post-merge source files | research, plan, journal, any transcript |

Each gate prompt carries the hard three-part constraint envelope proven in
tce (`## CRITICAL:` / `## What NOT to Do` / `## REMEMBER:`), re-pointed at
its verdict duty: evidenced verdicts per criterion/finding only — no style
commentary, no suggestions beyond findings.

### 11.3 The dispatcher owns every write

Agents return; the dispatcher writes (revised, §16.23). After an agent
returns, `/tsf:cycle` appends the journal entry and commits it, pushes the
branch, opens the PR when the step calls for it, posts the one comment, and
sets the next label — each write verified per §10. Consequences:

- **One owner of the state machine.** The dispatch table (§4) and the label
  transitions are one description in one place; no agent prompt carries its
  own copy of the label rules, which the research flagged as the plugin's
  main drift hazard.
- **One REST helper.** Read-back verification, the full-label-set PATCH and
  the retry rule exist once, in `scripts/`, with one allowlist entry.
- **Least privilege by construction.** No worker holds `gh` or push rights;
  the gates hold neither `git` nor `gh`. The only GitHub-writing context in
  a factory run is the dispatcher's.

The dispatcher's context grows by one result block per cycle, which is
mechanical, not content work; §5.1's thin-dispatcher property holds.

### 11.4 Ambient cost and invocation hygiene

Plugin agents cannot be hidden the way flagged commands can — their
descriptions sit in context in every session of the consuming project, and
any of them could in principle be invoked ad hoc. Accepted trade-off: a tsf
project *is* a factory project, and twelve short descriptions are cheap.
Mitigation: every agent description begins "Internal to `/tsf:cycle` — not
for direct use", which both discourages spontaneous invocation and makes the
agent listing self-explanatory.

## 12. Configuration and plugin layout

`/tsf:init` (interactive, run by the human outside the sandbox where
necessary) analyzes the project and writes `.claude/tsf/config.md` — the
only project-side file. Line 1 carries a `<!-- tsf-config-version: X.Y.Z -->`
marker, stamped from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` and
compared on re-run exactly as tce's profile marker is (the marketplace's
migration convention). Contents:

- Project profile: stack, build/test/lint commands, code conventions, commit
  convention (tsf steps read this instead of ever hardcoding stack literals —
  same core rule as the rest of this marketplace; seeded from
  `.claude/tce/profile.md` when present, §2).
- The GitHub coordinates (owner/repo), the **branch pattern** (§3.1), and
  the **factory identity**: its login (so the scan can tell factory PRs
  apart) and its **credential source**. The whole review mechanism of §9.2
  rests on the PR author being a machine identity — GitHub refuses a review
  of one's own PR — so `/tsf:cycle` runs every REST call and every push
  with that identity, never with the human's: the REST helper (§11.3) and
  the push resolve the token from the configured source **explicitly, per
  call**, never from the session's ambient `gh` login. The human's
  interactive commands (`/tsf:spec`, `/tsf:init`) use the ambient login
  deliberately — issues and specs are the human's. Default source:
  `GH_TOKEN` exported in the factory clone's environment (init documents
  where it comes from); the alternative is a proxy that injects the
  credential by repository URL (the first consumer's case, §8), in which
  case the source says so and the helper passes nothing.
- The **responders**: the GitHub logins whose issue replies count as the
  human's answer (§3.4; default: the repository owner).
- The environment contract commands (§8): the paths of the project's
  `prepare`, `env_up`, `env_reset`, `verify` scripts (mandatory) and
  `env_check` (optional), and the verification mode (`local` | `ci`, §7).
- Factory constants: verify-fix attempt bound per episode (§6.7), gate-fix
  round bound per episode (`gate_fix_bound`, §6.6). No clone path: the
  runner session is opened in the clone (§5.3), so the project directory
  *is* the clone.

**Contract check.** `/tsf:init` verifies that every mandatory contract
command exists and is executable, and that the optional ones, when
registered, do too. For each missing command it explains, from the project
analysis, what the script has to do for *this* project (the git sequence
for `prepare`; the services and their start command for `env_up`; what
"clean baseline" means here for `env_reset`, including the "suite manages
its own state" case; the CI command for `verify`) and offers a skeleton
from `templates/tsf/scripts/` to start from — written only on confirmation,
like everything else init writes. Init does not finish with a mandatory
command missing; it tells the user what is still needed and how to re-run.
The same check runs at the start of every `/tsf:cycle`, and a missing
mandatory command ends the cycle with a report instead of a guess.

It also creates the `tsf:*` labels with their family colours (over REST),
verifies the **factory credential** — resolved from the configured source,
not the session's own `gh` login (which is the human's): it must
authenticate as the configured factory login, and that login must not be
one of the responders, otherwise the human would be reviewing their own
PRs — offers the permission allowlist for
unattended runs (covering the registered contract scripts), and
offers to install the one **workflow template** it ships: the comment-pickup
workflow (built-in token, responders baked in at install). It prints the
ruleset settings the design relies on — PR required, one approving review,
the required check with strict up-to-date, no bypass for the factory
identity, delete-branch-on-merge — as a checklist for the human, together
with one CI requirement: the workflow that provides the required check
**must not path-filter `thoughts/**`** (a filtered-out required check stays
"expected" and blocks the merge, and every journal and report commit
touches only `thoughts/`); ruleset changes are admin-only and stay manual.

*(TP-0034 research: whether `config.md` also needs a machine-readable
section for the constants the scripts read, and where the allowlist is
written given workspace-trust rules, are planning decisions.)*

Planned plugin layout (implementation phase):

```
plugins/tsf/
├── .claude-plugin/plugin.json   # name: tsf, version 0.1.0 → 1.0.0 (release plan below)
├── README.md                    # consumer-facing docs
├── DESIGN.md                    # this document
├── commands/                    # init.md, spec.md, cycle.md
├── agents/                      # the step agents (§11): 8 workers + 4 gates
├── references/
│   └── templates/               # spec, research, plan, journal-entry, report, dossier,
│                                #   question-comment, pr-body skeletons
├── scripts/                     # lib.sh, scan/state helpers and the one REST write helper (§11.3)
└── templates/
    ├── tsf/                     # config.md skeleton for /tsf:init
    │   └── scripts/             # skeletons of the contract commands (§8) init offers
    │                            #   when a project lacks one — copied, then project-owned
    └── github/                  # workflow template: comment pickup
```

Commands: `init`, `spec`, `cycle`. All three are user-invoked; steps run as
plugin agents via the Agent tool (§11), not via Skill delegation, so there
are no delegation targets to keep invocable. `init` and `spec` carry
`disable-model-invocation: true`. **`cycle` must not**: the `/loop` runner
(§5.3) re-invokes it as a prompt, and a flagged skill fired that way arrives
as plain text instead of executing — the same load-bearing omission as
tle's `/tle:run`.

**Release plan.** The implementation lands in three slices (TP-0034a/b/c),
each usable on its own and each listed in the marketplace from the first.
The manifest therefore starts at `0.1.0` with slice 1, bumps to `0.2.0`
with slice 2, and reaches `1.0.0` — the marketplace's usual starting
version — with slice 3, which also creates the `tsf--v1.0.0` tag. A
consumer can then tell which slice they have, and every slice is a version
change the marketplace update notices.

## 13. Decision log (why, condensed)

The v1 decisions, kept as agreed on 2026-08-11. Entries marked *(revised)*
were changed on 2026-09-15; the reasoning for each change is in §16.

1. **Standalone from tce** — tce's commands are interactive by construction;
   plugins here never call into each other. Ideas transfer, code doesn't.
   *(revised: one workflow per project — a project is on tce or on tsf;
   init may seed from a tce profile.)* (§2)
2. **One step per cycle, fresh context** — small inspectable units, cheap
   failure recovery, no context rot; the outer loop just runs more cycles.
   *(revised: the three post-implement gates share one cycle; the outer
   loop is `/loop`, there is no `/tsf:run`.)* (§5, §7)
3. **Labels = who has the ball; artifacts = content and machine progress** —
   one cheap query for dispatch, minimal label churn, no dual-writing of
   state; disagreement parks the ticket rather than guessing. *(revised: a
   full `tsf:*` namespace naming every transition; factory-side labels are a
   corrected view, human-side labels authoritative; the derived state is
   the journal's `Next step`, §16.42.)* (§3.3, §3.4)
4. **Spec as repo artifact, issue text untouched** — consistent with
   "artifacts in repo, summaries on GitHub"; spec changes become diffable
   commits; the human's idea-dump register is preserved. (§3.1, §6.1)
5. **Explicit release only (`tsf:queued`)** — the backlog doubles as an idea
   dump; nothing is factory-eligible until the human says so. (§3.4)
6. **Auto-continue when no questions** — a gate with nothing to ask is an
   idle human touchpoint; plan approval and final review remain unskippable. (§4)
7. **Plans as unordered, self-verifying increments** — the human doesn't care
   about execution order; per-increment tests give the implementing agent
   immediate verification; summaries carry decisions, not step lists. (§6.5)
8. **CI is read, never watched** — the cycle model has no waiting. *(revised
   twice: local verification is the first gate precondition; the PR is never
   a draft, so CI runs on every push and is read before the gates.)* (§6.7, §7, §9.1)
9. **Fixed verification pipeline, context-starved** — verification is the
   factory bottleneck and the moat; starving the checkers of the producer's
   reasoning is the anti-rationalization mechanism; fixed > configurable
   until real usage demands otherwise. *(revised: a fourth, landing-time
   integration gate.)* (§7)
10. **Hard reset every cycle in a dedicated clone** — the clone contains only
    factory leavings, so unconditional reset is safe and beats parking
    tickets over dirty state. *(revised: the reset is the project's
    `prepare` script, never an ad-hoc command line; the runner session is
    opened in the clone and owns it, §16.47.)* (§5.3, §8)
11. **Environment contract instead of prescribing Docker/devenv** — keeps the
    plugin project-agnostic; the hard isolation problem lives in the
    project's `env_reset`, upgradeable later without touching the plugin.
    *(revised: four mandatory commands, project-provided scripts, checked by
    init.)* (§8, §12)
12. **Dossier-guided review instead of full review** — concentrates human
    attention where the agent says it matters; avoids rubber-stamping. (§9.1)
13. **Squash merge** — ticket-atomic main, one-commit revert, boring reliable
    landing step. *(revised: the merge cycle is write-free; the decision
    entry precedes it by one CI round, §16.30; the merge cycle checks
    `mergeable_state` first and strips the state label after, §16.46,
    §16.48.)* (§9.3)
14. **Escalating integration** — hard merges re-enter verification and
    re-approval instead of being forced through. *(revised: the agent
    resolves conflicts and classifies them; only logic-changing resolutions
    need a second approval; the server enforces the approval itself; a
    landing whose combination fails CI re-enters verification and
    re-approval, §16.40.)* (§9.2, §9.3)
15. **Hard-coded priority** (landing > in-flight > priority label > oldest) and
    **GitHub-only transport** in v1 — simplicity first; abstraction when a
    second consumer exists. (§5.2)
16. **Steps as plugin-defined agents, not generic subagents + reference
    files** — tool scoping enforced by configuration (gates mechanically
    read-only), step specs in the system-prompt attention position, one
    reviewable contract file per step; the ambient description cost is
    accepted. (§11)
17. **Gates as pure verdict functions** — read-only agents receive inputs
    from the dispatcher and return report content; the dispatcher performs
    all git/GitHub I/O for them, so the starvation contract cannot leak
    through side channels. *(revised: extended to every agent — the
    dispatcher owns every GitHub write.)* (§11.2, §11.3)
18. **No release step in v1** — every landing deploys whatever the project's
    push-to-main does; a batch-release step is deferred. (§9.4, §15)

## 14. v1 scope and non-goals

In scope: everything above, single repo, single factory clone, serial
implementation, GitHub Issues + REST only.

Explicit non-goals for v1:

- Parallel ticket execution, worktrees, multiple factory instances.
- Configurable priority, configurable/extensible gate family, autonomy dials.
- Auto-pickup of unlabeled issues / auto-triage without human release.
- Telemetry and metrics (the journals are already collecting the data).
- GitHub merge queue (organization-owned repositories only) and GitHub
  auto-merge as the landing mechanism (§16).
- Ticket-backend abstraction (Jira etc.); GraphQL-dependent mechanics.
- Feedback loop (incidents/CI failures re-entering intake as tickets).
- Running tce and tsf side by side on one project's backlog (§2).
- A release/deploy step (§15); draft PRs and any GraphQL-only operation.

## 15. Future outlook

Ordered roughly by expected value:

1. **`claude -p` while-loop runner, then parallel factories** — headless
   cycles in fresh sessions (subscription-covered), multiple loops with a
   `tsf:working` lock label preventing double-pickup; requires per-ticket
   environment isolation (Compose-style stacks via `env_*`) and worktrees.
2. **Release step, decoupling deploys from landings** — expected soon.
   Deploying every push to the main branch is unsafe under fix-forward: a
   flaky test or an environment difference between CI and production goes
   live at once, and N landings in a row mean N deploys. The v1.1 shape is
   the starting point: an optional project-provided `release` command
   ("tag and push", the tag triggers the deploy) that the dispatcher runs
   when no `tsf:landing` ticket is left and the main branch's own
   verification is green, with a bounded trigger (at most N landings or M
   minutes) as the fallback if the empty state proves rare. Needs a
   verification run on the main branch, which the first consumer's CI does
   not have yet.
3. **Faster human round-trips** — the comment-pickup workflow already
   relabels on reply; a trigger that starts a cycle when it fires would let
   parked tickets resume in minutes instead of at the next scheduled cycle.
4. **Extensible gate family** — architecture-conformance, regression-scope,
   project-defined gates, all inheriting the context-starved report-writing
   contract; per-project gate configuration.
5. **Telemetry from journals** — cycle time per stage, gate-failure and
   replan rates, verify-fix frequency, human-turnaround times; the factory's
   DORA equivalent, mined from files that already exist.
6. **Spec evolution** — richer spec formats, spec templates per work type
   (feature/bug/refactor), and better async spec refinement UX.
7. **Landing refinements** — an approve-review workflow that removes even the
   label reads, the merge queue if the repository ever moves to an
   organization, and conflict-resolution wording iterated from real runs.
8. **Ticket-backend abstraction** — only if a non-GitHub consumer actually
   appears.

## 16. Revision log

### 2026-09-15 — v1.1: fit review against chat-sustainability, landing redesign

Trigger: TP-0034's research and a survey of the first consumer project
(chat-sustainability) showed that several v1 premises do not hold there, and
a discussion of four new insights about the factory's human interface
(labels, feedback loop, review signal, landing several approved PRs). The
project's current process was treated as a data point, not as fixed: where
the factory needed a better mechanism, the project changes.

1. **Labels: a full `tsf:*` namespace naming every transition, two colour
   families** (§3.4). Why: the human wants to see the factory's state on the
   board and filter "what needs me" in one search; a namespace keeps factory
   labels independent of whatever human-only labels a repository already has
   (`high`, `in progress`, a `ready` bridge label) and lets the rule "the
   factory acts only on `tsf:*` issues" be literal. The v1 fear of desync is
   handled by treating factory-side labels as a corrected view and only
   human-side labels as authoritative.
2. **Reply-is-the-gesture with automatic pickup** (§3.4, §6.3). Why: the
   human should answer questions and approve plans by replying to the
   comment, nothing else; a tiny project-side workflow turns the reply into
   the label swap the dispatcher already understands, with comment polling as
   the fallback. Answers are folded into the artifact the questions came
   from, so plan feedback lands in the plan, not the spec.
3. **Non-draft PR + `tsf:needs-review` as the single review signal; CI after
   the un-draft; local verification as the gate precondition** (§7, §9.1;
   the draft-PR and un-draft parts are superseded by §16.22).
   Why: the consumer's CI skips drafts to save budget and only runs after the
   un-draft, so the v1 "draft PR then CI-wait" region had no CI. Running the
   project's verification in the clone gives the gates the same evidence
   earlier and cheaper; CI then confirms once, on the real head, before the
   human looks. Projects without a local environment keep the v1 order via
   verification mode `ci`.
4. **One approving review is the last human action; the factory lands the
   work** (§9.2, §9.3). Why: the human explicitly wants to approve once and
   never return. GitHub's auto-merge was considered and is available on the
   consumer's plan, but it fires whenever the PR is green and would need a
   GraphQL call (or another label bridge) to *hold* a merge after a
   logic-changing resolution. The merge queue would be the purpose-built
   answer but is organization-only. Chosen instead: the ruleset requires one
   approving review, the factory identity has no bypass, and the factory
   merges over REST when its own conditions hold — the server guarantees
   "no approval, no merge", the factory decides "when". A spike must confirm
   the sandbox allows the merge endpoint; otherwise a label-bridge merge
   workflow with the App token is the fallback.
5. **Serial landing, one ticket per cycle, sync by merge** (§9.3). Why: the
   strict up-to-date rule makes every landing invalidate the other approved
   PRs; syncing them in parallel wastes a CI run per landing. One sync per
   cycle lands N approved PRs in about 2N cycles unattended (a decision
   cycle and a merge cycle each, §16.30), each verified
   against the main it actually lands on — the merge-queue guarantee without
   the queue. Rebase stays forbidden (force-push is the one thing an
   unattended agent must never do).
6. **Conflicts are resolved by the agent and classified** (§9.3). Why: the
   human does not know how to resolve a merge conflict between two factory
   branches and a bare "does not merge" is useless. The agent resolves,
   journals, and classifies: mechanical resolutions land; logic-changing ones
   get a dossier addendum and a second approval; unresolvable ones come back
   with the concrete decision the human must take. The v1 escalation wording
   is replaced by this rule.
7. **A fourth gate: integration at landing time** (§7). Why: the human is
   willing to spend tokens on detecting "green individually, broken
   together". Serial CI covers what tests cover; a context-starved agent
   comparing the PR diff with the main delta since approval covers changed
   contracts, migration order, shared config. It runs only when main moved.
8. **Overlap warning in the dossier** (§9.1). Why: when several PRs wait for
   review at once, telling the human which ones touch the same code is cheap
   and decides the approval order.
9. **No writes after the merge** (§3.2, §9.4). Why: under branch-per-ticket
   with squash merge the branch is gone after landing; a closeout commit on
   main needs a human push in the consumer project (its issue #63). The last
   journal entry is written before the merge request; the merge is visible on
   GitHub, and the PR number recorded at PR creation is all the factory ever
   needs to find the work again. (tce's counterpart is its own ticket,
   TP-0035; the two are independent.)
10. **Release decoupled from the merge** (§8, §9.4; superseded by §16.26,
    which defers the release step to §15). Why: the consumer deploys
    every push to main, which makes fix-forward unsafe. An optional
    project-defined `release` command runs when the landing region is empty
    and main is green — one deploy per batch. Bounded triggers are the
    fallback if the empty state proves rare.
11. **REST only, label bridge for GraphQL-only operations, every write
    verified** (§10; the shipped un-draft bridge template is superseded by
    §16.22). Why: the consumer's sandbox allows REST for one
    repository and blocks GraphQL permanently for security; the v1 "single
    gh query" and every porcelain `gh` command are unusable there, and REST
    works everywhere else. The consumer's own un-draft bridge (`ready` label
    + App workflow) becomes a shipped template. Observed-once REST quirks
    (label sub-resource forbidden, stdin resets) are why every write reads
    itself back.
12. **Branch pattern and environment as configuration; tce coexistence**
    (§2, §3.1, §8). Why: the consumer has a `gh-<n>` branch convention with a
    hook keyed on it, runs tce interactively next to the factory, and has
    fixed service ports that collide between checkouts. None of this is the
    plugin's to decide: branch pattern, `verify`, per-checkout ports and the
    sandbox profile are project concerns, documented by `/tsf:init`.
13. **Verify-fix diagnoses locally first** (§6.7). Why: CI job logs are
    unreadable from inside the consumer's sandbox; local reproduction through
    the environment contract is the reliable path, and CI-red-with-local-green
    is worth reporting as an environment difference rather than flailing.
14. **Platform corrections carried from TP-0034 research, decisions
    deferred** (§5.3, §11, §12; the `/tsf:run` and invocation-flag items are
    superseded by §16.24): `LS` is not a tool and is dropped from the
    gates; subagent nesting exists, so "inline" is now a choice, not a limit;
    the `disable-model-invocation` flag conflicts with the `/loop` runner and
    `/tsf:run` has no wait primitive. These are planning decisions and are
    marked as such in place rather than decided here.
15. **No mapping of a project's own priority label** (§3.4, §5.2, §12; decided
    later the same day, in the review of this revision). Why: the one
    configurable exception to "tsf reads and writes only `tsf:*`" would have
    made the rule non-literal for a saving of one label per prioritised
    ticket, and a project's scale (the consumer has `high` *and* `critical`)
    does not map onto a single modifier anyway. The human sets
    `tsf:priority`; the project's own labels stay human-only.
16. **The security gate classifies, never fixes** (§7, §4). Why: v1.1 let
    gate 3 "apply safe fixes directly" while §11.2 made every gate read-only.
    Resolved toward the gate contract: findings are blocking (routed like a
    "not met", to implement in fix mode) or advisory (dossier). One routing
    rule for all gates, and no gate ever writes.
17. **The issue is the single point of communication; responders are
    configuration** (§3.4, §9.1, §10, §12). Why: after the PR exists a human
    may reply on the PR, whose `issue_comment` payload carries the PR number
    and no `tsf:*` label, so both the pickup workflow and the polling
    fallback would miss it; and "any commenter who is not the factory" would
    let a non-technical filer's comment be distilled as the answer. The PR
    keeps native reviews only. The human never sets a label to reply.
18. **The environment contract is four mandatory, project-provided scripts,
    checked by init** (§8, §12). Why: the factory's destructive and
    environment-specific operations (the clone reset above all) must never
    run as ad-hoc command lines from plugin prose — a project cannot allowlist
    or deny those safely, and the first consumer denies raw `git reset
    --hard` / `git clean` in every session. `prepare` joins the contract,
    `env_reset` stays mandatory (a suite that manages its own state still
    provides it, trivially), and `/tsf:init` refuses to finish with a
    mandatory command missing, offering skeletons instead.
19. **No dependency on tce's closeout ticket** (§3.2, §16.9). Why: tsf's rule
    (last journal entry before the merge request, PR number recorded at PR
    creation, nothing after the merge) is complete on its own; "tsf adopts
    TP-0035's result" was an ordering dependency without content and could
    have pulled a tce-shaped mechanism into the factory.
20. **Verify-fix attempts are bounded per episode** (§6.7, §4). Why: a
    ticket enters verification several times (after implement, after every
    rework round, after every landing sync); one counter for its whole life
    would park the first red build after a rework with no attempt left. The
    episode and attempt numbers live in the report filenames, so no new
    state is needed.
21. **One workflow per project, not coexistence** (§2, §3.2, §14; supersedes
    the coexistence half of §16.12). Why: the fit review found no rule
    keeping a supervised tce session and the factory off the same ticket
    (same `gh-<n>` branch, tce's `in progress` next to a `tsf:*` state), and
    a mixed mode is not needed for a first start: the consumer switches. The
    tce profile remains useful once, as an init-time seed.

### 2026-09-15 — v1.2: simplification pass

Trigger: with the fit-review gaps closed (§16.15 to §16.21), a pass over
what v1.1 still carried that could go without losing a property the design
argues for. Each item removes mechanism; none changes the human's
interaction surface (label to release, reply to the plan summary, one
approving review).

22. **No draft PRs** (§4, §6.6, §7, §9.1, §10, §12; supersedes the draft
    and un-draft parts of §16.3 and the shipped bridge template of §16.11).
    Why: tsf opens its PR
    only when the implementation is pushed, so unlike tce there is never a PR
    during the research and plan gates — those link the artifacts on the
    branch directly. The draft flag therefore carried one thing: holding CI
    back until the dossier. Dropping it removes the label-bridge template,
    the App token and the GraphQL dependency, the `ready` re-fire handling,
    the `tsf:ci` state and the un-draft step, at the price of CI running on
    the implementation pushes — which is evidence the pipeline wants before
    the gates anyway. The review signal was always the label plus the
    dossier comment, never the draft state.
23. **The dispatcher owns every GitHub write** (§5.1, §6, §10, §11.3). Why:
    v1.1 had workers push, comment and label themselves while gates returned
    text; the research flagged the resulting split (dispatch table and
    per-agent label duties as two descriptions of one state machine) as the
    plugin's main drift hazard. Making every agent a return-text function
    puts the state machine, the REST helper and the read-back rule in one
    place and takes `gh` and push rights away from every agent.
24. **`/loop` is the runner; `/tsf:run` is deleted** (§5.3, §12; supersedes
    the `/tsf:run` and invocation-flag items of §16.14). Why: the
    platform offers a command no way to wait, and the self-paced `/loop`
    already does what `/tsf:run` promised (the model schedules the next
    wake-up after each cycle, 1 to 60 minutes, guided by the cycle's report).
    This also settles the invocation flag: `cycle` stays unflagged because
    `/loop` fires it as a prompt (tle's `/tle:run` precedent), `init` and
    `spec` carry the flag. The `claude -p` shell loop stays the future runner
    for fresh contexts per cycle.
25. **The three post-implement gates run in one cycle, in parallel and in
    the foreground** (§4, §7). Why: with the security gate routing like the
    other two (§16.16), verification is one logical step with one outcome;
    three cycles bought nothing but two more journal entries and comments.
    Foreground because a turn that ends with an agent still running skips
    the runner's evaluation (tle's documented failure mode). Trade-off
    accepted: gate 2 and 3 tokens are spent when gate 1 already fails.
26. **No release step in v1** (§8, §9.4, §14, §15; supersedes §16.10). Why:
    the "main is
    green" trigger has no data source in the first consumer (its CI is
    PR-only) and every merge deploys there anyway, as it does for the
    human's merges today. Deferred to §15 with the outage motivation intact;
    expected to return soon.
27. **Sync by the server first** (§9.3). Why: GitHub's REST update-branch
    endpoint performs exactly the merge the merge-resolver agent would, without a
    clone, a checkout or a push; the agent is needed only when the server
    reports a conflict. To verify in the consumer's spike: the ruleset and
    the proxy accept the call for the factory identity, and which identity
    the server-made merge commit carries.
28. **One `tsf:answered` label** (§3.4, §4, §6.3). Why: whether a reply
    belongs to the spec or to the plan is derivable from the branch, so the
    pickup workflow and the dispatcher need one label and one rule.
29. **Sandbox note corrected** (§8). The first consumer's proxy injects the
    credential by repository URL, not by checkout path; a second checkout
    needs a filesystem grant only. The earlier text assumed the opposite.

### 2026-09-15 — v1.3: consistency review

Trigger: a review of v1.2 and the TP-0034 tickets for internal
consistency. Two state-machine defects, several unspecified mechanisms, and
wording drift between sections. No change to the human's interaction
surface.

30. **The landing is a decision cycle plus a write-free merge cycle** (§3.3,
    §4 row 12, §9.3, §12, §16.5). Why: v1.2 wrote the last journal entry and
    pushed it immediately before requesting the merge. Under the ruleset the
    design itself requires (required check, strict up-to-date), that push
    makes the PR head a commit CI has not checked, so the server refuses the
    merge — and the next cycle would write another entry and be refused
    again. Now the sync cycle records the decision ("merge when CI on head
    `<sha>` is green") and the merge cycle writes nothing. A landing takes
    about two cycles, not one; the CI workflow must not path-filter
    `thoughts/**`.
31. **Changes-requested reviews need the same recency rule as approvals**
    (§4 row 10, §3.3, §9.1; the journal-timestamp mechanism is superseded
    by §16.41). Why: after a rework round the old
    CHANGES_REQUESTED review is still the latest review state, so an
    unqualified clause sent the ticket back to rework forever. The journal
    records every dossier and addendum timestamp as the reference point.
32. **Plan deviations are plan addenda, not journal entries** (§6.6, §9.1).
    Why: the plan-compliance gate reads only the plan's criteria and never
    the journal, so a deviation recorded only in the journal failed the gate
    on every fix round until the bound parked the ticket. Normal mode now
    records deviations the way rework mode already did.
33. **Fix mode specified; gate reports carry their head and are numbered**
    (§3.2, §4 row 8, §6.6, §7, §11.2, §12; "head" now means the logic
    head, §16.43). Why: fix mode was named in four
    places and defined in none; its bound had no constant and, with
    single-file gate reports, no derivable counter; and row 8 could not tell
    that a report was stale after a fix or rework push. Reports now start
    with `head: <sha>`, are named `<gate>-<episode>-<round>.md`, and
    `gate_fix_bound` joins the constants.
34. **Distillation is a fixed mapping from the parking step; resuming from
    `tsf:needs-human` is `tsf:queued`** (§3.4, §4 row 1, §6.3). Why: three
    steps park with questions but the v1.2 rule derived only two
    destinations, and "the artifact the questions came from" contradicted
    "otherwise the spec" for research. Triage and research answer into the
    spec, plan gate and implement into the plan. And the design never said
    how a human resumes a parked ticket; the derived-view rule already made
    `tsf:queued` the right gesture.
35. **The factory identity's credential source is configuration and init
    checks it** (§12). Why: §9.2 depends on the PR author being a machine
    identity, but nothing said how `/tsf:cycle` acquires that identity in
    the human's session, and a `/tsf:cycle` running under the human's own
    `gh` login would produce PRs the human cannot approve.
36. **`prepare` creates a missing ticket branch; `env_up` runs every
    implementation cycle** (§6.2, §8). Why: triage needed a branch that
    neither `prepare` (no create mode) nor the agent (no push) could
    provide; and `env_up`'s cadence was unstated.
37. **Episode numbers live in the journal** (§6.7). Why: report filenames
    alone cannot distinguish a new episode's first attempt from the previous
    episode's next one.
38. **Release plan: 0.1.0 → 0.2.0 → 1.0.0 across the three slices** (§12).
    Why: a manifest that says 1.0.0 for three different feature levels lets
    nobody tell which slice is installed and gives the marketplace update
    nothing to notice.
39. **Housekeeping** (§3.4, §5.1, §6, §6.6, §9.3, §10, §11, §12, §16):
    `/tsf:spec` sets `tsf:queued`, not `tsf:research`; the idle cycle runs
    `prepare` for the base branch; "pushes" joins the returns-for-the-
    dispatcher reading rule; `tsf:integrate` is renamed `tsf:merge-resolver`
    to stop colliding with the `tsf:integration` gate; §11.3/§11.4 are in
    order; the polling fallback names its two labels; the label PATCH
    re-reads before writing and passes non-`tsf:*` labels through;
    `config.md` carries a version marker; the dispatcher re-runs `prepare`
    after a server-side sync; superseded §16 entries are marked.

### 2026-09-15 — v1.4: second consistency review of the state machine

Trigger: a review of v1.3 for consistency and sensibility (tickets
excluded). Three state-machine defects, several mechanisms that could not
work as written, and the unresolved question of where the runner session
lives. No change to the human's interaction surface.

40. **A landing whose combination fails CI re-enters verification** (§4
    row 12, §6.7, §9.3 step 3). Why: v1.3 sent a landing-time red build to
    "verify-fix as usual" while row 12 had no `tsf:verify` exit and
    verify-fix was reachable only under `tsf:verify`; and §6.7's "the gates
    are not re-run for fix commits after the gates passed" contradicted
    §7's "a fix push causes the gates to re-run". Now the ticket leaves
    landing for `tsf:verify` as a new episode, the gates re-run on the new
    logic head, the dossier gets an addendum and the approval is re-earned
    through row 10 — code changed after an approval is re-gated and
    re-approved, with no second mechanism.
41. **Row 10 reads its reference points from GitHub, never from the
    journal** (§3.3, §4 row 10, §9.1, §9.3 step 4; supersedes the timestamp
    mechanism of §16.31). Why: §5.1 commits the journal entry *before* the
    cycle posts its comment or opens its PR, so a dossier timestamp or PR
    number can never be in the same cycle's entry, and under
    `tsf:needs-review` no later write happens before row 10 needs it. An
    approval is valid while no logic-changing commit follows the review's
    `commit_id`; a changes-requested review counts when its `submitted_at`
    is newer than the factory's last dossier or addendum comment's
    `created_at`; the reviewer's latest review wins. The PR number is
    recorded in the marker block at PR creation and in the next journal
    entry.
42. **The journal's `Next step` is the derived state; `tsf:queued` with a
    journal resumes there** (§3.3, §3.4, §4 row 3). Why: row 3 sent every
    `tsf:queued`-with-spec ticket to research, so a ticket re-queued after
    a park during implementation would have restarted research — and the
    artifacts alone cannot tell "plan awaiting approval" from "plan
    approved" (both are a `plan.md` without a PR). The journal already
    carried the field; it is now the source, validated against the
    artifacts.
43. **The logic head, defined once** (§3.5, §4 rows 8 and 10, §7, §9.3
    step 4). Why: "logic-changing push" was defined only for conflict
    resolutions, and the report staleness rule compared against the PR
    head — which the commit that adds the report always moves, so a report
    could never name the current head and row 8 was "always stale". The
    logic head (newest commit that is not a mechanical sync merge and
    touches a path outside `thoughts/`) serves staleness, approval
    validity and the landing decision alike, and makes every journal,
    report and dossier commit inert by construction.
44. **The PR diff is the three-dot diff against the base branch** (§3.5,
    §7, §11.2). Why: "recorded base commit → head" contains main's whole
    delta once a sync merge is on the branch, so the integration gate (and,
    after §16.40, the re-run gates) would have judged main's changes as the
    PR's. The three-dot diff is what GitHub's Files tab shows, stays correct
    after a sync, excludes `thoughts/`, and removes the recorded base
    commit and its failure class (tce's TP-0030) entirely.
45. **"Actionable" is defined; one landing in flight** (§4 rows 7 and 12,
    §5.1, §5.2, §9.3). Why: "report waiting, end" let a single pending CI
    run idle the whole factory for a cycle, and "one landing ticket per
    cycle" did not stop a second landing sync from starting while the first
    waited for CI — which §5.2's own reasoning wanted avoided. Tickets
    waiting on CI, parked tickets without a signal, and landing tickets
    behind the one in flight are skipped by the pick; the closing report
    names the pending heads so `/loop` paces short.
46. **The merge cycle checks `mergeable_state` first; integration reports
    are numbered** (§3.2, §7, §9.3 steps 2 and 5). Why: main moving
    between the decision and the merge cycle is routine, but v1.3 covered
    only a human push to the branch, and the server's refusal under strict
    up-to-date would have fallen into §10's retry-then-park rule. `behind`
    now restarts at step 1 silently; `integration-<n>.md` survives a
    restarted landing instead of being overwritten, and the gate re-runs
    only when main moved since the last report's recorded main head.
47. **The runner session is opened in the clone and owns it; identities
    are explicit; `/tsf:spec` writes over REST** (§5.3, §6.1, §8, §12).
    Why: a configured clone path implied a session in the human's working
    copy reaching into the clone, but the allowlist, sandbox profile, hooks
    and every project-directory helper resolve to the session's own
    directory and subagent file tools have no cwd override. The clone is
    now the session's project directory and the factory's alone; the clone
    path constant is gone. The REST helper resolves the factory credential
    from the configured source per call, and init checks *that* credential
    — the session's ambient `gh` login is the human's, used deliberately by
    `/tsf:spec` and `/tsf:init`. `/tsf:spec` creates the branch and the spec
    commit through the refs and contents endpoints, so it touches neither
    the human's working copy nor a clone that may be mid-cycle.
48. **Closed tickets are invisible; the merge strips the state label**
    (§3.4, §5.1, §9.3 step 5, §9.4). Why: nothing removed `tsf:landing`
    after the merge and the scan had no open-state filter, so a landed
    ticket could be picked again and `prepare` would have re-created its
    deleted branch from base. The scan reads open issues only, and the
    merge cycle's one post-merge write is the label PATCH that leaves the
    closed issue with no state — nobody's move.

### 2026-09-20 — v1.5: corrections from the first review of the shipped 1.0.0

Trigger: tsf 1.0.0 shipped without ever running end to end — all three slices
deferred their smoke test to the first real factory setup. A review of design,
tickets and implementation (TP-0036), including a stub run of `scan.sh` against
a fake `gh`, found defects that stop or loop the factory on **normal** paths.
None is an architectural flaw: they are wiring between the slices that was
never exercised. The human's interaction surface is unchanged.

49. **The runner requires a raised Bash timeout** (§5.3, §8, §12). Why: the
    Bash tool's default timeout is two minutes and a real verification suite
    outlives it. A command that reaches its timeout is moved to the background
    — which §5.3's foreground requirement forbids — or, with background tasks
    disabled, meets an outcome Claude Code does not document. Either way the
    factory reads a non-result as a verdict. `BASH_DEFAULT_TIMEOUT_MS` joins
    `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` as a checked runner requirement, and
    every contract script and `verify` run is given the maximum timeout with its
    output redirected to a file — a **failing** command returns only a truncated
    excerpt with no file path.
50. **Resuming works from every state** (§3.4, §4 row 3). Why: §3.4 said
    `tsf:queued` on a ticket with a journal resumes at the journal's `Next
    step`, but the implementation mapped four of the nine values; `implement`
    answered with a silent skip and the five later ones were unmapped. Those are
    exactly the states most parks happen in. A resume into a state that needs
    pull-request data is now a label correction that ends the cycle, because a
    `tsf:queued` record carries none — and a resume into `tsf:verify` opens a new
    episode, since the ticket was most likely parked by an exhausted bound.
51. **Review staleness is decided in the scan, for changes-requested only**
    (§4 row 10, §5.1). Why: GitHub keeps one state per reviewer, so after a
    rework the human's old CHANGES_REQUESTED review is still the latest review
    forever. §4 row 10 said to ignore it — but "ignore" was implemented as a
    journal entry, which is a commit, a push and a CI run every cycle, on a
    ticket that sorts ahead of everything queued. The scan now reports such a
    review as none, and row 10's stale outcomes write nothing at all.
    Approvals are deliberately **not** subject to the same test: the landing's
    own decision cycle posts a pull-request comment, so an age rule would stale
    the approval the landing depends on.
52. **The scan record carries the landing's review, in two fields** (§5.1,
    §9.3). Why: reviews were probed only for `tsf:needs-review` and
    `tsf:rework`, so a `tsf:landing` ticket arrived with no review data — and
    §9.3's "oldest approval first" and row 12's approval check both needed it.
    `review_commit:` and `review_at:` are separate fields because approval
    validity is measured against a commit and ordering against a time; the
    single overloaded field they replace could serve only one.
53. **A conflicted pull request is synced instead of waited on, and CI waiting
    is bounded** (§4 row 7, §12). Why: GitHub runs no `pull_request` workflow
    while a merge conflict is open, so a conflicted branch has no check runs,
    which the factory read as "not started yet" — and conflicts were only
    resolved at landing, which such a ticket can never reach. The scan now
    reports how many required checks exist on the head, a head with none is
    probed once for mergeability, and `ci_pending_bound` parks a head that has
    been waiting too long — the net under a missing workflow, a path filter or a
    stuck runner.
54. **Only the required checks decide CI** (§7, §12). Why: every check run on
    the head counted, so one failing optional check — a preview deploy, a
    coverage bot — sent a ticket into a fix round against something it cannot
    fix. The required check names are configuration because rulesets are not
    readable over the REST API tsf uses. `none` states that a project has no
    pull-request CI, which also settles the standing question of what zero
    check runs means.
55. **Rework receives the review** (§6.6, §11.1). Why: the dispatcher was told
    to pass "the review's body and its comments", but no tsf script read a pull
    request's inline review comments and the review body was discarded. The
    human's one feedback channel on finished work reached the factory empty. A
    new read writes the review and its inline comments to a file that the rework
    payload passes by path.
56. **The pull request's title and body have a write path** (§9.1). Why: the
    dossier step validates them and the title is the squash commit's subject,
    but nothing could change them.
57. **The server-side sync is observed, not assumed** (§9.3 step 1). Why: the
    update-branch endpoint returns 202 and GitHub documents no completion
    signal, so the landing ran `prepare` against a head that might not have
    moved yet, built the decision on the old head, and had the push rejected.
    The call now watches the head, reports the one it observed, and has a
    distinct outcome for a head that never moves.
58. **Bookkeeping commits get a CI fast path** (§12). Why: journal, report,
    dossier and decision commits touch only `thoughts/` yet each starts a full
    run — about ten per ticket. Path filtering is the wrong fix and breaks the
    merge outright (§9.2). tsf ships a fragment the project pastes into its own
    verification job, which inherits the parent commit's result for a
    `thoughts/`-only push and runs the full suite for every other parent state.
59. **Implementation is batched** (§6.6). Why: every increment was built in one
    agent context and nothing was pushed until it returned, so a crash or a
    usage limit lost the whole plan at the next `prepare`, and a re-run was not
    told what already existed. Fresh mode now builds `implement_batch`
    increments per cycle and pushes them; the journal records which, and a cycle
    that builds nothing new parks the ticket. The pull request still opens only
    after the last batch, so intermediate pushes cost no CI.
60. **The plan is parsed by a script** (§6.5, §7, §11.2). Why: §11.3's thin
    dispatcher may not read a plan's or spec's body, while §7's gates need the
    per-increment criteria — a contradiction the implementation resolved by
    telling the dispatcher to extract them verbatim. A model writes the plan, so
    conformance cannot be assumed, only enforced: a new script validates the
    increment fields when the plan and implement steps return, and extracts the
    criteria to a file. The gates receive paths, and the criteria file is the
    only plan-derived input any of them gets.
