# tsf — Toby Software Factory: Design

**Status:** Design v1.1 — v1 agreed 2026-08-11; revised 2026-09-15 after the
fit review against the first consumer project (chat-sustainability) and the
discussion recorded in §16. No implementation yet (TP-0034).
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
  create issue → create branch → commit spec → push → offer to label
  `tsf:queued`.
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
    ├── plan-compliance.md
    ├── spec-coverage.md
    ├── security.md
    ├── verify-fix-01-01.md   # <episode>-<attempt>, see §6.7
    ├── integration.md   # landing-time gate, only when main moved (§9.3)
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
no merge reference: the PR number is journaled and linked from the issue's
marker block when the PR opens, the ticket ID is the squash commit's scope,
and the per-increment commits stay reachable through the PR after the
branch is deleted.

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

The last entry a ticket gets is written by the landing step *before* it
requests the merge (§9.3); the merge itself is visible on the PR and the
issue, so no post-merge entry is needed.

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
| `tsf:research` | factory | Spec sufficient; research is next | triage, `/tsf:spec` |
| `tsf:plan` | factory | Research done; planning is next | research |
| `tsf:plan-feedback` | factory | Human replied at the plan gate; the plan step reads the reply | comment-pickup workflow |
| `tsf:implement` | factory | Plan approved; implementation is next | plan (on approval) |
| `tsf:verify` | factory | Draft PR open; local verification and gates run | implement |
| `tsf:dossier` | factory | All gates green; dossier and un-draft are next | dispatcher (last gate) |
| `tsf:ci` | factory | PR un-drafted; CI result to read, fix loop | dossier |
| `tsf:rework` | factory | Changes requested; implementation addresses the review | dispatcher (on review) |
| `tsf:landing` | factory | Approved; sync, integration gate and merge are next | dispatcher (on review) |
| `tsf:answered` | factory | Human replied to posted questions; distillation is next | comment-pickup workflow |
| `tsf:needs-answer` | human (red) | Parked: numbered questions posted | triage, research, implement |
| `tsf:needs-plan-approval` | human | Plan pushed + summarized; awaiting the human's reply | plan |
| `tsf:needs-review` | human | PR non-draft, CI green, dossier posted; awaiting review | dispatcher |
| `tsf:needs-human` | human | Blocked: attempts exhausted, environment broken, logic conflict, state mismatch | any step |
| `tsf:priority` | modifier (yellow) | Pick before other tickets | Human |

Rules:

- **Exactly one state label per factory ticket at a time** (the modifier is
  additional).
- **Factory-side labels are a derived view.** The dispatcher derives progress
  from the artifacts (which files exist, PR existence and draft state, CI
  status, review state) and *corrects* a stale factory-side label rather than
  parking — labels are a cache for the board, not a second source of truth.
- **Human-side labels are authoritative for "whose move".** When a human-side
  label disagrees with the artifacts (e.g. `tsf:needs-plan-approval` but no
  plan on the branch), the factory writes a journal entry describing the
  mismatch and parks the ticket `tsf:needs-human` — it never guesses.
- Labels name the **next** step, set by the step that finished. No lock label
  in v1: one runner, one step per cycle. A `tsf:working` lock is the first
  thing parallel runners will need (§15).

**The issue is the only conversation channel** (§10): every question, plan
summary and human reply lives on the issue. The PR carries the dossier, the
gates' one-line comments and the human's native review, nothing else; a
free-text comment on the PR is not read by the factory (the dossier says so
in its last line). **Pickup after a human reply is automatic, and the human
never touches a label to answer.** tsf ships a small project-side workflow
template (installed by `/tsf:init`, §12) that runs on `issue_comment`: when
the payload is an issue (not a PR), the issue carries `tsf:needs-answer` and
the commenter is one of the configured **responders** (§12; default: the
repository owner), it swaps the label to `tsf:answered`; for
`tsf:needs-plan-approval` it swaps to `tsf:plan-feedback`. Comments by
anyone else (the factory identity, other collaborators) change nothing.
Labels on issues need no further workflow to fire, so the repository's
built-in token suffices. Where the workflow is not installed, the dispatcher
falls back to polling the comments of `tsf:needs-*` tickets each scan (one
REST call per parked ticket), applying the same responder rule. Review
outcomes need no workflow: the PR's review state is read directly (§9.2).

## 4. The state machine

Derived state → next step, evaluated by the dispatcher in order:

1. `tsf:answered` / `tsf:plan-feedback` → **distill** the human's reply into
   the artifact the questions came from (§6.3), then continue with the step
   the artifacts imply (for `tsf:plan-feedback`: the plan step, which either
   proceeds on approval or replans).
2. `tsf:queued`, no `spec.md` on branch (or no branch) → **triage**.
3. `tsf:queued` with spec, or `tsf:research` → **research**.
4. `tsf:plan` → **plan** (ends at the plan gate: `tsf:needs-plan-approval`).
5. `tsf:implement` → **implement** (ends with a draft PR; `tsf:verify`).
6. `tsf:verify`, project verification (§8) **red** → **verify-fix** (bounded
   attempts per verification episode, §6.7; then `tsf:needs-human`).
7. `tsf:verify`, verification **green**, gate reports incomplete → **next
   verification gate** (plan-compliance → spec-coverage → security; one gate
   per cycle). Any "not met" or blocking security finding → back to
   implement in fix mode (bounded). All green → `tsf:dossier`.
8. `tsf:dossier` → **dossier** (writes and posts the dossier, validates the
   PR title/body, requests the un-draft; `tsf:ci`).
9. `tsf:ci`, CI pending → report waiting, end. CI **red** → **verify-fix**
   against CI (bounded; then `tsf:needs-human`). CI **green** →
   `tsf:needs-review`.
10. `tsf:needs-review`, an approving review newer than the last
    logic-changing push → `tsf:landing`. A "changes requested" review →
    `tsf:rework`.
11. `tsf:rework` → **implement** in rework mode (review comments as input),
    then `tsf:verify` again (gates re-run on the new diff, dossier addendum,
    CI runs on push since the PR is already non-draft).
12. `tsf:landing` → the **landing loop** (§9.3): at most one landing ticket
    per cycle. Ends with the merge, or with `tsf:needs-review` (logic-changing
    resolution, integration risk) or `tsf:needs-human` (unresolvable).
13. No `tsf:landing` ticket left and the main branch's verification green →
    the optional **release** step (§9.4).
14. `tsf:needs-*` with no new signal → skipped.

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
1. Scan:    REST calls: issues carrying tsf:* labels, the PR per ticket branch,
            check runs and review state per PR head (see §10 for the REST rule).
2. Pick:    highest-priority actionable ticket (see §5.2). None → report idle, end.
3. Decide:  next step from the state table (§4).
4. Prepare: in the factory clone — run the project's `prepare` command for
            the ticket branch (hard reset + checkout), then the rest of the
            environment contract as the step needs it (§8).
5. Execute: spawn the step's named agent (§11) with a fresh context. Worker
            agents re-read the ticket's artifacts in chain order (spec →
            research → plan, as applicable) from disk, perform the step,
            commit, push, post the summary comment, append the journal entry,
            and adjust labels themselves. Gate agents are pure verdict
            functions — the dispatcher hands them their inputs and performs
            all git/GitHub I/O on their behalf (§11.2).
6. Report:  relay the agent's compact summary to the invoker. End of cycle.
```

The dispatcher itself does no content work — its context stays small, which is
what makes the continuous mode viable. The "single gh query" of v1 is
replaced by a handful of REST calls (§16): still cheap, and the only form
that works inside a sandbox that allows REST but not GraphQL.

### 5.2 Priority (hard-coded in v1)

1. Landing tickets first — approved work is finished before anything else
   moves (and each landing invalidates the other approved PRs, §9.3).
2. Then other in-flight actionable tickets — a ticket with any artifact
   progress beats an untouched one.
3. Among those, `tsf:priority`-labeled before unlabeled.
4. Then oldest first.

No configuration, no scoring. Deliberately simple until real usage shows a
need.

### 5.3 Runners

- **Manual:** `/tsf:cycle` — the testing and early-trust mode.
- **Supervised burst:** `/loop 5m /tsf:cycle` — the human watches a few cycles
  live. Works because the dispatcher context stays thin; note `/loop` reuses
  one session, so this is for bursts, not for days. *(TP-0034 research: a
  command flagged `disable-model-invocation: true` cannot be a `/loop` prompt;
  §12's flag on `cycle` and this runner cannot both hold — decision pending in
  planning.)*
- **Continuous:** `/tsf:run` — repeats cycles in one session, self-pacing
  (short pause after productive cycles, long pause when nothing is
  actionable). Suitable for overnight runs; auto-compaction of old cycle
  summaries is harmless because all state lives in labels + artifacts.
  *(TP-0034 research: there is no callable wait primitive; the pacing
  mechanism is a planning decision.)*
- **Future:** a shell `while` loop around `claude -p "/tsf:cycle"` — each
  cycle a brand-new session. Verified against current official docs: headless
  `claude -p` under a Pro/Max login draws from the **subscription allowance**
  (API-token billing only applies with an explicit API key / `--bare`), so
  this runner is economically viable; it can later be multiplied for parallel
  factories.

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
an earlier cycle produced them; commit what you produce; push; post exactly
one summary comment; append exactly one journal entry; set labels per §4.
Gate agents are exempt from the I/O half of this contract — the dispatcher
performs it for them (§11.2). Document skeletons (spec, research, plan,
journal entry, report, dossier, question comment, PR body) ship as reference
templates read at the point of use.

### 6.1 `/tsf:spec` (interactive, on the shell)

The one deliberately interactive command: guided spec authoring in the spirit
of a good ticket discussion — iterating WHAT and WHY with the human, pushing
for the sufficiency minimum (clear scope, observable outcome, at least one
concrete anchor into the system). Then: create the GitHub issue (title + short
human summary + link block), create the ticket branch, commit `spec.md`, push,
offer to label `tsf:queued`.

Reasoning: spec iteration is a focused, high-bandwidth conversation; doing it
asynchronously over issue comments would mean repeated question bursts and
context-switching for the human — the worst interaction pattern for exactly
the person the factory serves. Async refinement exists (triage questions), but
authored specs are the paved road.

### 6.2 Triage

For tickets labeled `tsf:queued` without a spec: create branch, distill the
raw issue body into an initial `spec.md`, then test it for sufficiency (scope /
observable outcome / anchor). Insufficient → post numbered, batched questions
(one comment, everything at once — no dribbling, in the §10 question format)
→ `tsf:needs-answer`. Sufficient → journal it and set `tsf:research`.

### 6.3 Answer distillation

Whenever a step starts on a ticket labeled `tsf:answered` or
`tsf:plan-feedback`: read the human's comment reply, fold it into **the
artifact the questions came from** as a commit — spec questions into
`spec.md`, plan-gate feedback into `plan.md` — so the artifact stays the
single canonical input and truth never lives scattered in a thread. Reply
with a one-line confirmation, then proceed with the actual step. At the plan
gate the reply is also the approval channel: an approving reply moves the
ticket to `tsf:implement`; anything else is feedback and the plan is revised
and re-summarized.

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
**Never the increment list.** The full plan is one click away on the branch;
the summary's job is to let the human approve intent and trade-offs in under
a minute, by replying to the comment.

### 6.6 Implement

Consumes the approved plan. Works increment by increment in the factory clone
(environment contract active, §8), running each increment's own verification
immediately after building it. Per-increment commits in the project's
convention. Deviations from the plan that survive contact with reality are
journaled with reasoning (mismatch too large → questions → `tsf:needs-answer`).
Ends: push, open a **draft PR** from the PR template (title
`<type>(GH-<n>): <spec title>` in the project's commit convention — the
squash commit's subject; body with the closing keyword, the spec link, the
plan summary and artifact links), journal, `tsf:verify`.

**Rework mode** (`tsf:rework`): the same agent with the review's comments as
additional input. It records the requested changes in the plan as an
addendum, implements them, pushes, and returns the ticket to `tsf:verify`.

### 6.7 Verification fix

The factory never watches CI — it **reads results at pickup**. This step
makes a red verification green, in either of two places:

- **Local** (`tsf:verify`): the project's verification command (§8) fails in
  the clone after implementation. Diagnose from the local output, fix,
  commit, push.
- **CI** (`tsf:ci`): the PR's checks are red. CI logs may be unreadable from
  inside a sandbox (the first consumer's proxy refuses the log host), so the
  **primary diagnosis is local reproduction** through the environment
  contract; check logs are used when reachable. CI red with local green is
  reported as such — an environment difference, escalated after the bound.

Attempts are bounded **per verification episode**, not per ticket. An
episode starts each time the ticket enters `tsf:verify` — from implement,
from rework, or from a landing sync — and the bound (default: 3) starts
afresh with it; exhausted → `tsf:needs-human` with a summary of what was
tried. Each run writes `reports/verify-fix-<episode>-<attempt>.md`, so the
dispatcher derives both counters from the files on the branch like every
other progress fact, with no extra state. Rework rounds need no ceiling of
their own: each one is a human decision, not a factory loop.
Green verification is a hard precondition for every gate — no review effort
is spent on red builds. Fix commits made after the gates passed are appended
to the dossier as an addendum; the gates are not re-run for them.

## 7. The verification pipeline (fixed in v1)

The pipeline is fixed and always on. Its precondition is **green project
verification in the factory clone** (§8) — CI is read only after the PR is
un-drafted, because the first consumer's CI skips drafts to save budget, and
because a local run gives the factory the same evidence faster (§16). Projects
whose environment cannot run the verification locally set the config's
verification mode to `ci`: the PR is then un-drafted right after
implementation and CI green replaces the local run as the precondition —
slower feedback, same pipeline.

Four gate agents, each a fresh-context subagent writing a report file (and,
via the dispatcher, a one-line PR comment). All four are **context-starved by
hard prompt constraint**: they receive their stated inputs only — never the
plan-production reasoning, never the implementation transcript — because a
checker that sees the implementer's reasoning rationalizes gaps (the review's
strongest practitioner lesson, already proven in tce's compliance checker).

1. **Plan compliance** — inputs: the plan's per-increment verification criteria
   + the full diff (base commit recorded at implement start). One evidenced
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
4. **Integration** (landing time, §9.3) — inputs: the PR's diff, the diff the
   main branch took since the PR's approval, and `spec.md`. Runs only when
   main moved after the approval. Answers one question: can the two changes
   break each other in ways the tests would not catch (a changed contract the
   PR calls, migration ordering, shared configuration, duplicated behaviour)?
   Verdict: safe / risk, with a concrete description. This is the deliberate
   token spend that covers "green individually, broken together" beyond what
   serial CI already covers.

**CI green** is not an agent but a dispatcher-checked precondition that sits
between the dossier and the human review (§4 step 9) and again before the
merge (§9.3).

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
  Called by every cycle's prepare phase (§5.1) with the ticket branch as
  its argument; also called with the base branch when nothing is actionable.
- **`env_up`** — bring the environment up for the current checkout. For a
  factory clone this is typically *services only* (database, cache), not the
  application servers, unless a step needs a running app.
- **`env_reset`** — return the environment to a clean baseline for the
  current branch (reset/re-seed DB, re-run migrations from baseline). Run
  **on ticket switch**, not every cycle — consecutive cycles on one ticket
  keep the warm environment. A project whose verification suite manages its
  own state still provides it: the script then only records that fact, so
  the factory never has to guess whether a reset is missing or unneeded.
- **`verify`** — the project's verification suite (lint, types, tests), the
  same command its CI runs. Its exit code is the pipeline precondition (§7)
  and what verify-fix (§6.7) makes green.

Two are **optional**:

- **`env_check`** — fast health probe before implementation; failure →
  `tsf:needs-human` instead of an agent flailing against a broken stack.
- **`release`** — what "deploy this state of main" means for the project
  (e.g. create and push a release tag that triggers the deploy). See §9.4.

Only implementation-flavored steps (implement, verify-fix, the local
verification the gates depend on) need `env_up`, `env_reset` and `verify`;
`prepare` runs in every cycle.

Execution model v1: **one dedicated factory clone, serial hands-on work.** The
factory owns a ready-made clone (never the human's working copy — a working
copy with uncommitted state must never be factory ground). Every cycle's
prepare phase runs the project's `prepare` command, which **hard-resets the
clone**. Agreed reasoning: in a dedicated clone, anything the reset destroys
is something the factory itself left behind, so unconditional reset is safe
and strictly better than parking tickets over dirty state — and because the
reset is the project's script, a project can keep its usual deny rules for
raw `git reset --hard` / `git clean` in place for every session, the factory
clone included.

The clone runs inside the project's sandbox profile with the factory's own
credentials (§9.2) — a second checkout of the same repository needs its own
profile entry and, if the sandbox injects credentials per path, its own
injection rule. Running the clone next to the human's working copy on one
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
   remarks not auto-fixed, plan deviations.
4. **Overlap warning** — the other open factory PRs that touch the same files
   or modules, so the human knows which order to approve in and where a
   combination deserves a second look.
5. **Closing line** — how to respond: approve or request changes with a
   native review; anything else goes on the issue, because the factory does
   not read free-text PR comments (§10).

The dossier step also validates the PR's title and body against the template
(§6.6) — the title is the squash commit's subject — and then requests the
un-draft. Un-drafting is a GraphQL-only operation on GitHub; where the
factory's transport cannot reach GraphQL it uses the **label bridge**: it adds
the project's bridge label to the PR and a project-side workflow (template
shipped with tsf, §12) performs the conversion with an App token. CI runs on
the un-drafted PR; once green the ticket is `tsf:needs-review`.

Reasoning: full line-by-line human review of every factory ticket does not
scale and degrades into rubber-stamping (the DORA/Finster failure mode); a
curated dossier concentrates scarce human attention exactly where the agent —
who knows where the bodies are buried — says it matters, while the human
retains the depth decision. **A non-draft PR carrying `tsf:needs-review` is
the one signal that a final review is expected.**

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
The dispatcher processes **at most one `tsf:landing` ticket per cycle, oldest
approval first**, because every landing makes the other approved PRs "behind"
under the strict up-to-date rule and parallel syncing would only waste CI
runs. For the chosen ticket:

1. **Sync.** The integrate agent merges the main branch into the ticket branch
   (`git merge`, never rebase, never force-push). Clean merge → continue.
   Conflict → the agent **resolves it** and classifies the resolution:
   - *mechanical* — independent hunks, imports, lockfiles, formatting,
     renames;
   - *logic* — it had to choose between behaviours, or adapt the PR to an
     API or contract that main changed.
   Either way it journals what it did and why, and posts one comment. It
   never comes back with a bare "this does not merge": if it cannot resolve,
   it describes the concrete decision the human must take →
   `tsf:needs-human`.
2. **Integration gate** (§7 gate 4) — only when main moved since the approval.
   Inputs: the PR diff, the main delta, the spec. Verdict safe / risk.
3. **Push and verify.** The sync push starts CI on the real combination. Red
   → verify-fix as usual.
4. **Decide.** The factory requests the merge only when *all* of: CI green,
   branch up to date, the resolution was mechanical (or there was none), the
   integration gate said safe (or did not run), and **the latest approving
   review is newer than the last logic-changing push**. Otherwise it posts a
   dossier addendum that states exactly what was decided and why, labels
   `tsf:needs-review`, and waits for a second approval.
5. **Merge.** The factory merges the PR over the REST merge endpoint —
   **squash**, subject from the PR title (`<type>(GH-<n>): …`), the body's
   closing keyword closes the issue. The server enforces the rules of §9.2;
   the factory only chooses *when*. *(Spike before implementation: confirm
   the sandbox proxy allows the merge endpoint for the factory identity; if
   not, the fallback is a label-bridge workflow that merges with the App
   token, §16.)*

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

### 9.4 After the merge, and release

The merge closes the issue through the closing keyword and, with the
repository's delete-branch-on-merge setting, deletes the ticket branch; where
the setting is off the factory deletes the remote branch over REST. The next
prepare phase prunes and drops the local branch. **Nothing is written to the
repository after the merge** (§3.2): the journal's last entry and every
report already sit inside the squash.

**Release** (optional, project-defined): deploying every push to the main
branch is unsafe under fix-forward, so the design decouples the two. When
the landing region is empty (no `tsf:landing` ticket left) and the main
branch's own verification is green, the dispatcher runs the project's
`release` command — typically "tag and push", where the tag triggers the
deploy. That deploys once per batch of landings rather than once per PR, and
a red main never reaches production. If the empty-region state turns out to
be rare in practice, the trigger becomes a bounded rule (after at most N
landings, or M minutes of a green main) — a one-line change in the step.

## 10. GitHub communication rules

- Every step posts **exactly one** comment: a few sentences, decisions and
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
  everywhere else too. The few operations GitHub offers only over GraphQL
  (un-drafting a PR) go through the **label bridge** (§9.1): a label the
  factory can set over REST, consumed by a project-side workflow.
- **Every write is verified.** After a label PATCH the factory reads the label
  set back; after posting a comment it confirms the comment exists; after a
  bridge request it confirms the resulting state (draft flag, merge). One
  retry on a transport error; a second failure parks the ticket
  `tsf:needs-human` with the failed operation in the journal. Label updates
  send the **full** label set, since sub-resource routes may be forbidden.
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

### 11.1 Workers (read-write)

Full toolset (file tools + Bash for `git`/`gh`/project commands). They carry
the §6 common contract in full.

| Agent | Step | Input artifacts (re-read from disk, chain order) |
|---|---|---|
| `tsf:triage` | §6.2 | issue body (passed in), repo conventions |
| `tsf:research` | §6.4 | spec |
| `tsf:plan` | §6.5 | spec → research (+ plan-gate feedback when present) |
| `tsf:implement` | §6.6 | spec → research → plan (+ review comments in rework mode) |
| `tsf:verify-fix` | §6.7 | plan (as context) + local verification output or CI results + diff |
| `tsf:dossier` | §9.1 | everything on the branch: spec → research → plan → journal → reports, plus the diff and the other open factory PRs |
| `tsf:integrate` | §9.3 | the approved PR, the main branch's delta, the merge state |

The dossier agent is deliberately **not** context-starved — its job is honest
human-facing synthesis, which requires seeing everything, including the
journal's recorded obstacles and every gate report.

### 11.2 Gates (read-only, context-starved by configuration)

Tools: `Read, Grep, Glob` — no Bash, no Write, no network (`LS` is not a
Claude Code tool; v1 listed it by inheritance from tce's agent files).
Because a gate cannot run `git` or `gh`, it becomes a **pure verdict
function**: the dispatcher computes the diff (recorded base commit → head),
passes the gate exactly its §7 inputs in the spawn prompt, receives the
report content back, and itself writes `reports/<gate>.md`, commits, pushes,
posts the one-line comment, and adjusts labels. This costs the dispatcher a
little mechanical I/O and buys absolute enforcement of the starvation
contract.

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

### 11.3 Ambient cost and invocation hygiene

Plugin agents cannot be hidden the way flagged commands can — their
descriptions sit in context in every session of the consuming project, and
any of them could in principle be invoked ad hoc. Accepted trade-off: a tsf
project *is* a factory project, and eleven short descriptions are cheap.
Mitigation: every agent description begins "Internal to `/tsf:cycle` — not
for direct use", which both discourages spontaneous invocation and makes the
agent listing self-explanatory.

## 12. Configuration and plugin layout

`/tsf:init` (interactive, run by the human outside the sandbox where
necessary) analyzes the project and writes `.claude/tsf/config.md` — the
only project-side file:

- Project profile: stack, build/test/lint commands, code conventions, commit
  convention (tsf steps read this instead of ever hardcoding stack literals —
  same core rule as the rest of this marketplace; seeded from
  `.claude/tce/profile.md` when present, §2).
- The GitHub coordinates (owner/repo), the **branch pattern** (§3.1), the
  factory identity's login (so the comment-pickup workflow can ignore it),
  and the PR bridge label.
- The **responders**: the GitHub logins whose issue replies count as the
  human's answer (§3.4; default: the repository owner).
- The environment contract commands (§8): the paths of the project's
  `prepare`, `env_up`, `env_reset`, `verify` scripts (mandatory) and
  `env_check`, `release` (optional), and the verification mode
  (`local` | `ci`, §7).
- Factory constants: verify-fix attempt bound per episode (§6.7),
  factory-clone path.

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
verifies `gh` auth, offers the permission allowlist for unattended runs
(covering the registered contract scripts), and
offers to install the two **workflow templates** it ships: the label-bridge
un-draft workflow (App token; the App setup itself is documented, not
automated) and the comment-pickup workflow (built-in token). It prints the
ruleset settings the design relies on — PR required, one approving review,
the required check with strict up-to-date, no bypass for the factory
identity, delete-branch-on-merge — as a checklist for the human; ruleset
changes are admin-only and stay manual.

*(TP-0034 research: whether `config.md` also needs a machine-readable
section for the constants the scripts read, and where the allowlist is
written given workspace-trust rules, are planning decisions.)*

Planned plugin layout (implementation phase):

```
plugins/tsf/
├── .claude-plugin/plugin.json   # name: tsf, version 1.0.0 (marketplace convention)
├── README.md                    # consumer-facing docs
├── DESIGN.md                    # this document
├── commands/                    # init.md, spec.md, cycle.md, run.md
├── agents/                      # the step agents (§11): 7 workers + 4 gates
├── references/
│   └── templates/               # spec, research, plan, journal-entry, report, dossier,
│                                #   question-comment, pr-body skeletons
├── scripts/                     # lib.sh, scan/state helpers (REST)
└── templates/
    ├── tsf/                     # config.md skeleton for /tsf:init
    │   └── scripts/             # skeletons of the contract commands (§8) init offers
    │                            #   when a project lacks one — copied, then project-owned
    └── github/                  # workflow templates: label-bridge un-draft, comment pickup
```

Commands: `init`, `spec`, `cycle`, `run`. All four are user-invoked; steps
run as plugin agents via the Agent tool (§11), not via Skill delegation, so
there are no delegation targets to keep invocable. *(Whether `cycle`/`run`
carry `disable-model-invocation: true` is decided in planning together with
the `/loop` runner, §5.3.)*

## 13. Decision log (why, condensed)

The v1 decisions, kept as agreed on 2026-08-11. Entries marked *(revised)*
were changed on 2026-09-15; the reasoning for each change is in §16.

1. **Standalone from tce** — tce's commands are interactive by construction;
   plugins here never call into each other. Ideas transfer, code doesn't.
   *(revised: one workflow per project — a project is on tce or on tsf;
   init may seed from a tce profile.)* (§2)
2. **One step per cycle, fresh context** — small inspectable units, cheap
   failure recovery, no context rot; the outer loop just runs more cycles. (§5)
3. **Labels = who has the ball; artifacts = content and machine progress** —
   one cheap query for dispatch, minimal label churn, no dual-writing of
   state; disagreement parks the ticket rather than guessing. *(revised: a
   full `tsf:*` namespace naming every transition; factory-side labels are a
   corrected view, human-side labels authoritative.)* (§3.4)
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
8. **CI is read, never watched** — the cycle model has no waiting. *(revised:
   local verification is the gate precondition; CI runs after the un-draft.)* (§6.7, §7)
9. **Fixed verification pipeline, context-starved** — verification is the
   factory bottleneck and the moat; starving the checkers of the producer's
   reasoning is the anti-rationalization mechanism; fixed > configurable
   until real usage demands otherwise. *(revised: a fourth, landing-time
   integration gate.)* (§7)
10. **Hard reset every cycle in a dedicated clone** — the clone contains only
    factory leavings, so unconditional reset is safe and beats parking
    tickets over dirty state. *(revised: the reset is the project's
    `prepare` script, never an ad-hoc command line.)* (§8)
11. **Environment contract instead of prescribing Docker/devenv** — keeps the
    plugin project-agnostic; the hard isolation problem lives in the
    project's `env_reset`, upgradeable later without touching the plugin.
    *(revised: four mandatory commands, project-provided scripts, checked by
    init.)* (§8, §12)
12. **Dossier-guided review instead of full review** — concentrates human
    attention where the agent says it matters; avoids rubber-stamping. (§9.1)
13. **Squash merge** — ticket-atomic main, one-commit revert, boring reliable
    landing step. (§9.3)
14. **Escalating integration** — hard merges re-enter verification and
    re-approval instead of being forced through. *(revised: the agent
    resolves conflicts and classifies them; only logic-changing resolutions
    need a second approval; the server enforces the approval itself.)* (§9.2, §9.3)
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
    through side channels. (§11.2)

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

## 15. Future outlook

Ordered roughly by expected value:

1. **`claude -p` while-loop runner, then parallel factories** — headless
   cycles in fresh sessions (subscription-covered), multiple loops with a
   `tsf:working` lock label preventing double-pickup; requires per-ticket
   environment isolation (Compose-style stacks via `env_*`) and worktrees.
2. **Faster human round-trips** — the comment-pickup workflow already
   relabels on reply; a trigger that starts a cycle when it fires would let
   parked tickets resume in minutes instead of at the next scheduled cycle.
3. **Extensible gate family** — architecture-conformance, regression-scope,
   project-defined gates, all inheriting the context-starved report-writing
   contract; per-project gate configuration.
4. **Telemetry from journals** — cycle time per stage, gate-failure and
   replan rates, verify-fix frequency, human-turnaround times; the factory's
   DORA equivalent, mined from files that already exist.
5. **Spec evolution** — richer spec formats, spec templates per work type
   (feature/bug/refactor), and better async spec refinement UX.
6. **Landing refinements** — an approve-review workflow that removes even the
   label reads, the merge queue if the repository ever moves to an
   organization, and conflict-resolution wording iterated from real runs.
7. **Ticket-backend abstraction** — only if a non-GitHub consumer actually
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
   the un-draft; local verification as the gate precondition** (§7, §9.1).
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
   cycle lands N approved PRs in about N cycles unattended, each verified
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
10. **Release decoupled from the merge** (§8, §9.4). Why: the consumer deploys
    every push to main, which makes fix-forward unsafe. An optional
    project-defined `release` command runs when the landing region is empty
    and main is green — one deploy per batch. Bounded triggers are the
    fallback if the empty state proves rare.
11. **REST only, label bridge for GraphQL-only operations, every write
    verified** (§10). Why: the consumer's sandbox allows REST for one
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
    deferred** (§5.3, §11, §12): `LS` is not a tool and is dropped from the
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
