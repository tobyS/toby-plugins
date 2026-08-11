# tsf — Toby Software Factory: Design

**Status:** Design v1 — agreed 2026-08-11, no implementation yet.
**Background:** `thoughts/shared/research/2026-07-07-tce-software-factory-review.md`
— research on how agentic
software factories are built in 2025/26 and how tce's architecture maps onto
them. This document is the design that came out of discussing that review.

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
babysitting generation, never reading agent transcripts.

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
- tce's workflow commands are Skill-invocable delegation targets; a project
  running the factory should not have a second, interactive workflow ambiently
  available to the model. **A project uses either tce (interactive context
  engineering) or tsf (factory)** — the plugins may coexist in a marketplace,
  never as a dependency chain.
- The repo rule stands: plugins coordinate only through project config files,
  never by calling into each other. tsf re-states every step in its own words,
  written for autonomous execution from the start.

What carries over is the *design*: artifact chain, re-read discipline (every
step re-reads its input artifacts from disk, never trusting conversation
state), context starvation for verifiers, graduated ceremony, and the
project-agnostic core.

## 3. Core concepts

### 3.1 The ticket triple

A ticket exists for the factory only as three things together:

1. **A GitHub issue** — the human↔factory transport and workflow-state carrier.
2. **A ticket branch** — `tsf/GH-<n>` (canonical ticket ID: `GH-<n>`,
   filesystem-safe and greppable; normalize `#123`, bare numbers, and issue
   URLs to it).
3. **A spec artifact** — `thoughts/factory/GH-<n>/spec.md` on that branch: the
   canonical input specification the factory works from.

Both entry doors establish the full triple:

- `/tsf:spec` (interactive, primary): guided spec authoring on the shell →
  create issue → create branch → commit spec → push → offer to label ready.
- Triage (idea-dump path): the human labels an existing raw issue ready; the
  factory's triage step creates branch + initial spec from the issue body and
  asks its clarifying questions from there.

### 3.2 Artifacts in the repo, summaries on GitHub

All content lives on the ticket branch under `thoughts/factory/GH-<n>/`:

```
thoughts/factory/GH-123/
├── spec.md          # canonical input spec (what & why, scope, observable outcome)
├── research.md      # codebase research: patterns, constraints, file:line evidence
├── plan.md          # implementation plan (see §6.5 for the format rules)
├── journal.md       # append-only factory journal: one entry per cycle
└── reports/         # one file per verification/CI-fix run
    ├── plan-compliance.md
    ├── spec-coverage.md
    ├── ci-fix-01.md
    ├── security.md
    └── dossier.md   # the human-facing final review dossier (also posted to the PR)
```

GitHub carries only **summaries and links**: every step posts one short comment
(decisions, not steps — see §10), and the factory maintains a small marker
block appended to the issue body with links to the spec, branch, journal, and
PR. The issue's original human-written text is **never modified** — it stays
the idea-dump register it was written as.

The `thoughts/factory/` root (not `thoughts/shared/`) keeps the tree separable
from tce's layout, so a project can return to or coexist with tce conventions.

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

### 3.4 Who has the ball: labels

Workflow state is carried by issue labels; artifacts carry content. Labels
answer one question cheaply queryable in a single `gh` call: **whose move is
it, and at which gate?** Machine progress *within* the factory's own states is
derived from the artifacts (which files exist, PR existence, CI status) — this
minimizes label churn and desync between the two sources of truth.

| Label | Meaning | Set by | Cleared by |
|---|---|---|---|
| `tsf:ready` | Factory may work this ticket | Human (initially); factory (after human gates pass) | Factory (when parking at a gate) |
| `tsf:needs-human` | Parked: questions posted as a comment | Factory | Human (answers, relabels `tsf:ready`) |
| `tsf:awaiting-plan-approval` | Plan pushed + summarized; awaiting decision | Factory | Human (relabels `tsf:plan-approved`) |
| `tsf:plan-approved` | Human approved the plan | Human | Factory (consumes it, proceeds to implement) |
| `tsf:awaiting-final-review` | Dossier posted on PR; awaiting PR approval | Factory | Factory (on merge) / human (requesting changes) |
| `tsf:priority` | Pick before other ready tickets | Human | Human |

Unlabeled issues are **invisible to the factory** — the human explicitly
releases each ticket by labeling it `tsf:ready` (the backlog is also an
idea-dump; nothing is picked up implicitly). Exactly one state label per
factory ticket at a time. On disagreement between label and artifacts (e.g.
`tsf:ready` but a dirty half-state on the branch), the factory writes a journal
entry describing the mismatch and parks the ticket `tsf:needs-human` — it never
guesses.

## 4. The state machine

Derived state → next step, evaluated by the dispatcher in order:

1. `tsf:ready`, no `spec.md` on branch (or no branch) → **triage**.
2. `tsf:ready`, spec exists, no `research.md` → **research**.
3. `tsf:ready`, research exists, no `plan.md` → **plan** (ends at the plan
   gate: `tsf:awaiting-plan-approval`).
4. `tsf:plan-approved` → **implement** (ends with draft PR; back to
   `tsf:ready`, now in the CI-wait region).
5. `tsf:ready`, PR exists, CI **red** → **ci-fix** (bounded attempts; then
   `tsf:needs-human`).
6. `tsf:ready`, PR exists, CI **green**, verification reports incomplete →
   **next verification gate** (plan-compliance → spec-coverage → security; one
   gate per cycle).
7. All gates green, no dossier → **dossier** (ends `tsf:awaiting-final-review`).
8. `tsf:awaiting-final-review` + PR approved by the human → **integrate**.
9. `tsf:needs-human` + human answers present → the *next* step (per this
   table) begins by **distilling the answers into the spec** (a commit), then
   proceeds.

Auto-continue rule (agreed): triage and research park the ticket
`tsf:needs-human` **only if they actually have questions**. A research step
with no open questions journals "gate skipped: nothing to ask" and leaves the
ticket `tsf:ready` for planning — no idle human touchpoint. The plan gate and
the final review gate are **never** skipped in v1.

The human's total interaction surface per ticket, in the best case: label it
ready, approve the plan from a short comment, approve the PR from the dossier.

## 5. The cycle

### 5.1 `/tsf:cycle` — one cycle, thin dispatcher, fresh-context step

```
1. Scan:    one gh query for issues carrying tsf:* labels + PR/CI state.
2. Pick:    highest-priority actionable ticket (see §5.2). None → report idle, end.
3. Decide:  next step from the state table (§4).
4. Prepare: in the factory clone — hard-reset to a pristine state, check out
            the ticket branch, run the environment contract as needed (§8).
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
what makes the continuous mode viable.

### 5.2 Priority (hard-coded in v1)

1. In-flight actionable tickets first — finish before starting (a ticket with
   any artifact progress beats an untouched one).
2. Among those, `tsf:priority`-labeled before unlabeled.
3. Then oldest first.

No configuration, no scoring. Deliberately simple until real usage shows a
need.

### 5.3 Runners

- **Manual:** `/tsf:cycle` — the testing and early-trust mode.
- **Supervised burst:** `/loop 5m /tsf:cycle` — the human watches a few cycles
  live. Works because the dispatcher context stays thin; note `/loop` reuses
  one session, so this is for bursts, not for days.
- **Continuous:** `/tsf:run` — repeats cycles in one session, self-pacing
  (short pause after productive cycles, long pause when nothing is
  actionable). Suitable for overnight runs; auto-compaction of old cycle
  summaries is harmless because all state lives in labels + artifacts.
- **Future:** a shell `while` loop around `claude -p "/tsf:cycle"` — each
  cycle a brand-new session. Verified against current official docs: headless
  `claude -p` under a Pro/Max login draws from the **subscription allowance**
  (API-token billing only applies with an explicit API key / `--bare`), so
  this runner is economically viable; it can later be multiplied for parallel
  factories.

The factory is expected to run inside a sandboxed environment (network/exec
cage), with a dedicated clone (§8) — so the permission posture can be
permissive *inside that boundary*. `/tsf:init` still writes a recommended
allowlist (`gh issue/pr/api …`, `git` incl. push, the project's test commands)
so unattended runs never stall on a prompt. Residual risk stated honestly: an
unattended agent with push and `gh` rights; the cage and the dedicated clone
are the containment.

## 6. Step specifications

Each step runs as a fresh-context agent from the roster in §11; each step's
spec is its agent's system prompt. Common contract for worker agents: re-read
all input artifacts from disk in chain order (spec → research → plan) even if
an earlier cycle produced them; commit what you produce; push; post exactly
one summary comment; append exactly one journal entry; set labels per §4.
Gate agents are exempt from the I/O half of this contract — the dispatcher
performs it for them (§11.2). Document skeletons (spec, research, plan,
journal entry, report, dossier) ship as reference templates read at the point
of use.

### 6.1 `/tsf:spec` (interactive, on the shell)

The one deliberately interactive command: guided spec authoring in the spirit
of a good ticket discussion — iterating WHAT and WHY with the human, pushing
for the sufficiency minimum (clear scope, observable outcome, at least one
concrete anchor into the system). Then: create the GitHub issue (title + short
human summary + link block), create `tsf/GH-<n>`, commit `spec.md`, push,
offer to label `tsf:ready`.

Reasoning: spec iteration is a focused, high-bandwidth conversation; doing it
asynchronously over issue comments would mean repeated question bursts and
context-switching for the human — the worst interaction pattern for exactly
the person the factory serves. Async refinement exists (triage questions), but
authored specs are the paved road.

### 6.2 Triage

For tickets labeled ready without a spec: create branch, distill the raw issue
body into an initial `spec.md`, then test it for sufficiency (scope /
observable outcome / anchor). Insufficient → post numbered, batched questions
(one comment, everything at once — no dribbling) → `tsf:needs-human`.
Sufficient → journal it and leave `tsf:ready` for research.

### 6.3 Answer distillation

Whenever a step starts on a ticket that was parked `tsf:needs-human`: read the
human's comment answers, fold them into `spec.md` as a commit (the spec stays
the single canonical input; truth never lives scattered in a thread), reply
with a one-line confirmation, then proceed with the actual step.

### 6.4 Research

Codebase research producing `research.md`: existing patterns, the files and
mechanisms the change touches (file:line evidence), constraints, impact
analysis, options where genuinely open. Documentarian register — describes
what exists, does not design. Works inline (see §11: subagents cannot fan
out further). Open questions that materially affect planning → batched
comment → `tsf:needs-human`. Otherwise auto-continue (§4).

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
`tsf:awaiting-plan-approval`. The summary contains only: what will be built
(broad strokes), the crucial decisions taken (and alternatives rejected, one
line each), and anything irregular. **Never the increment list.** The full
plan is one click away on the branch; the summary's job is to let the human
approve intent and trade-offs in under a minute.

### 6.6 Implement

Consumes the approved plan. Works increment by increment in the factory clone
(environment contract active, §8), running each increment's own verification
immediately after building it. Per-increment commits in the project's
convention. Deviations from the plan that survive contact with reality are
journaled with reasoning (mismatch too large → questions → `tsf:needs-human`).
Ends: push, open **draft PR** (body: spec link, plan summary, artifact links),
journal, back to `tsf:ready` — now in the CI-wait region.

### 6.7 CI-fix

The factory never watches CI — it **reads results at pickup** (`gh pr
checks`). Red CI → this step: diagnose from the check logs, fix, commit, push,
report (`reports/ci-fix-NN.md`). Bounded attempts (default: 3 per ticket);
exhausted → `tsf:needs-human` with a summary of what was tried. Green CI is a
hard precondition for every verification gate — no review effort is spent on
red builds.

## 7. The verification pipeline (fixed in v1)

Four gates, hard-coded, in order, each a fresh-context subagent writing a
report file and a one-line PR comment. Gates 1, 2, and 4 are **context-starved
by hard prompt constraint**: they receive their stated inputs only — never the
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
3. **CI green** — not an agent: the dispatcher-checked precondition (§6.7),
   listed here because it is part of the gate sequence semantics.
4. **Security review** — inputs: the diff + the touched files' surroundings.
   Findings classified; safe mechanical fixes applied directly (commit +
   re-enter at CI wait), judgment-requiring findings reported into the
   dossier.

"Needs human verification" verdicts are never silently passed — they are
collected into the dossier's checklist. Extending/configuring the gate family
(architecture conformance, regression scope, project-custom gates) is
explicitly future work; v1 ships exactly these, always on.

## 8. The environment contract

Only implementation-flavored steps (implement, ci-fix, gates that execute
tests) need a live dev environment. The plugin stays environment-agnostic via
three project-provided commands in `.claude/tsf/config.md`:

- **`env_up`** — bring the environment up for the current checkout.
- **`env_reset`** — return it to a clean baseline for the current branch
  (reset/re-seed DB, re-run migrations from baseline). Run **on ticket
  switch**, not every cycle — consecutive cycles on one ticket keep the warm
  environment.
- **`env_check`** (optional) — fast health probe before implementation;
  failure → `tsf:needs-human` instead of an agent flailing against a broken
  stack.

Execution model v1: **one dedicated factory clone, serial hands-on work.** The
factory owns a ready-made clone (never the human's working copy — a working
copy with uncommitted state must never be factory ground). Every cycle's
prepare phase **hard-resets the clone**: `git reset --hard` + `git clean -fd`
(not `-x` — ignored files hold env state) + checkout of the ticket branch.
Agreed reasoning: in a dedicated clone, anything the reset destroys is
something the factory itself left behind, so unconditional reset is safe and
strictly better than parking tickets over dirty state.

The migration/DB-isolation problem is thereby the project's `env_reset`
implementation, where it belongs. A project on devenv can implement it as
"drop DB, migrate, seed" (acceptable when run only on ticket switches). A
project that later moves to Docker Compose can implement per-ticket stacks
(`COMPOSE_PROJECT_NAME=tsf-GH-<n>`) under the *same* contract — which is also
what later unlocks worktrees and parallel implementation. Neither migration is
a precondition of the factory. Honest fallback: if the local environment
cannot run the tests, CI remains the authoritative verifier — slower feedback,
functioning pipeline.

## 9. Dossier, final gate, integration

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

Then `tsf:awaiting-final-review`. Reasoning: full line-by-line human review of
every factory ticket does not scale and degrades into rubber-stamping (the
DORA/Finster failure mode); a curated dossier concentrates scarce human
attention exactly where the agent — who knows where the bodies are buried —
says it matters, while the human retains the depth decision.

### 9.2 Final human gate

Native GitHub PR approval — visible in the PR timeline, mobile-friendly, and
the natural gesture. Requesting changes routes the ticket back
(`tsf:needs-human` with the review comments as input). The factory never
merges unapproved work; the "no self-merge" principle holds structurally.

### 9.3 Integration

After approval: rebase onto current main, then **squash-merge** (`gh pr merge
--squash`) with one well-formed conventional commit message referencing
`GH-<n>`; close the issue (auto via merge keywords), final journal entry,
prune the marker block's dead links, delete branch, reset the clone.

**Squash reasoning (agreed):** the factory's natural atomic unit on main is
the ticket. Per-increment commits are agent checkpoints — valuable during the
process (dossier links, per-phase diffs, resumability) and permanently
readable in the PR, but not curated history. One commit per ticket keeps main
bisectable at ticket granularity and makes revert = revert one commit — the
undo semantics dossier-level review needs. It also collapses the integration
agent's job to something boring and reliable, which is exactly what the
merge step must be. (Curated-rebase integration: future work, if tickets ever
carry meaningful sub-structure.)

**Escalation on non-trivial integration:** if the rebase required conflict
resolution with semantic risk, the agent must NOT merge. It pushes the rebased
branch and loops the ticket back to the CI-wait region — post-rebase code
re-runs CI and the verification gates, and a **dossier addendum** requests
fresh approval. The escalation bar is calibrated high, because a re-loop
delays the merge while other tickets advance:

> Escalate only when resolution required *choosing between behaviors* or
> touching logic beyond mechanically merging independent hunks. "It didn't
> rebase cleanly and I merged a few obvious lines" is NOT an escalation.
> When escalating, say concretely what was dangerous: "I had to decide X
> versus Y in `file`; I chose X because …; I am not confident this preserves
> the approved behavior — this needs re-approval."

This phrasing is a **baseline expected to be iterated** during the first real
factory runs; the design commits to the two-outcome mechanism, not the final
wording.

## 10. GitHub communication rules

- Every step posts **exactly one** comment: a few sentences, decisions and
  outcomes — never step lists, never transcripts — plus artifact links.
- Questions are **batched**: one numbered comment per parking, everything the
  step needs, so the human context-switches once.
- The issue body's original text is never edited; the factory only maintains
  its appended marker block (`<!-- tsf:links -->` … `<!-- /tsf:links -->`)
  with current links (spec, branch, journal, PR).
- The plan summary and dossier follow their content rules (§6.5, §9.1):
  decisions, not steps; guidance, not volume.

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

A constraint that shapes the roster: **subagents cannot spawn subagents.**
Every step agent therefore works inline — the tce-style fan-out into
locator/analyzer helpers is unavailable one level down. Acceptable in v1:
each step owns an entire fresh context, and the artifact chain keeps every
context's job narrow.

### 11.1 Workers (read-write)

Full toolset (file tools + Bash for `git`/`gh`/project commands). They carry
the §6 common contract in full.

| Agent | Step | Input artifacts (re-read from disk, chain order) |
|---|---|---|
| `tsf:triage` | §6.2 | issue body (passed in), repo conventions |
| `tsf:research` | §6.4 | spec |
| `tsf:plan` | §6.5 | spec → research |
| `tsf:implement` | §6.6 | spec → research → plan |
| `tsf:ci-fix` | §6.7 | plan (as context) + CI check logs + diff |
| `tsf:dossier` | §9.1 | everything on the branch: spec → research → plan → journal → reports, plus the diff |
| `tsf:integrate` | §9.3 | the approved PR + diff against current main |

The dossier agent is deliberately **not** context-starved — its job is honest
human-facing synthesis, which requires seeing everything, including the
journal's recorded obstacles and every gate report.

### 11.2 Gates (read-only, context-starved by configuration)

Tools: `Read, Grep, Glob, LS` — no Bash, no Write, no network. Because a gate
cannot run `git` or `gh`, it becomes a **pure verdict function**: the
dispatcher computes the diff (recorded base commit → head), passes the gate
exactly its §7 inputs in the spawn prompt, receives the report content back,
and itself writes `reports/<gate>.md`, commits, pushes, posts the one-line
comment, and adjusts labels. This costs the dispatcher a little mechanical
I/O and buys absolute enforcement of the starvation contract.

| Agent | Inputs (nothing else) | May read | Must never see |
|---|---|---|---|
| `tsf:plan-compliance` | per-increment criteria + diff | post-change source files | `thoughts/` docs, plan prose, any transcript |
| `tsf:spec-coverage` | `spec.md` + diff | post-change source files | research, plan, any transcript |
| `tsf:security` | diff | touched files and their surroundings | `thoughts/` docs, any transcript |

Each gate prompt carries the hard three-part constraint envelope proven in
tce (`## CRITICAL:` / `## What NOT to Do` / `## REMEMBER:`), re-pointed at
its verdict duty: evidenced verdicts per criterion/finding only — no style
commentary, no suggestions beyond findings.

### 11.3 Ambient cost and invocation hygiene

Plugin agents cannot be hidden the way flagged commands can — their
descriptions sit in context in every session of the consuming project, and
any of them could in principle be invoked ad hoc. Accepted trade-off: a tsf
project *is* a factory project, and ten short descriptions are cheap.
Mitigation: every agent description begins "Internal to `/tsf:cycle` — not
for direct use", which both discourages spontaneous invocation and makes the
agent listing self-explanatory.

## 12. Configuration and plugin layout

`/tsf:init` (interactive) analyzes the project and writes
`.claude/tsf/config.md` — the only project-side file:

- Project profile: stack, build/test/lint commands, code conventions, commit
  convention (tsf steps read this instead of ever hardcoding stack literals —
  same core rule as the rest of this marketplace).
- The environment contract commands (§8).
- Factory constants: CI-fix attempt bound, factory-clone path.

It also creates the `tsf:*` labels in the GitHub repo, verifies `gh` auth, and
offers the permission allowlist for unattended runs.

Planned plugin layout (implementation phase):

```
plugins/tsf/
├── .claude-plugin/plugin.json   # name: tsf, version 1.0.0 (marketplace convention)
├── README.md                    # consumer-facing docs
├── DESIGN.md                    # this document
├── commands/                    # init.md, spec.md, cycle.md, run.md
├── agents/                      # the step agents (§11): 7 workers + 3 gates
├── references/
│   └── templates/               # spec.md, research.md, plan.md, journal-entry, report, dossier skeletons
├── scripts/                     # lib.sh, scan/state helpers (single gh query), reset helper
└── templates/tsf/               # config.md skeleton for /tsf:init
```

Commands: `init`, `spec`, `cycle`, `run`. All four are user-invoked
(`disable-model-invocation: true` — steps run as plugin agents via the Agent
tool (§11), not via Skill delegation, so there are no delegation targets to
keep invocable).

## 13. Decision log (why, condensed)

1. **Standalone from tce** — tce's commands are interactive by construction;
   a factory project shouldn't carry a parallel interactive workflow; plugins
   here never call into each other. Ideas transfer, code doesn't. (§2)
2. **One step per cycle, fresh context** — small inspectable units, cheap
   failure recovery, no context rot; the outer loop just runs more cycles. (§5)
3. **Labels = who has the ball; artifacts = content and machine progress** —
   one cheap query for dispatch, minimal label churn, no dual-writing of
   state; disagreement parks the ticket rather than guessing. (§3.4)
4. **Spec as repo artifact, issue text untouched** — consistent with
   "artifacts in repo, summaries on GitHub"; spec changes become diffable
   commits; the human's idea-dump register is preserved. (§3.1, §6.1)
5. **Explicit release only (`tsf:ready`)** — the backlog doubles as an idea
   dump; nothing is factory-eligible until the human says so. (§3.4)
6. **Auto-continue when no questions** — a gate with nothing to ask is an
   idle human touchpoint; plan approval and final review remain unskippable. (§4)
7. **Plans as unordered, self-verifying increments** — the human doesn't care
   about execution order; per-increment tests give the implementing agent
   immediate verification; summaries carry decisions, not step lists. (§6.5)
8. **CI is read, never watched** — the cycle model has no waiting; CI-green
   gates all review effort. (§6.7)
9. **Fixed four-gate verification, context-starved** — verification is the
   factory bottleneck and the moat; starving the checkers of the producer's
   reasoning is the anti-rationalization mechanism; fixed > configurable
   until real usage demands otherwise. (§7)
10. **Hard reset every cycle in a dedicated clone** — the clone contains only
    factory leavings, so unconditional reset is safe and beats parking
    tickets over dirty state. (§8)
11. **Environment contract instead of prescribing Docker/devenv** — keeps the
    plugin project-agnostic; the hard isolation problem lives in the
    project's `env_reset`, upgradeable later without touching the plugin. (§8)
12. **Dossier-guided review instead of full review** — concentrates human
    attention where the agent says it matters; avoids rubber-stamping. (§9.1)
13. **Squash merge** — ticket-atomic main, one-commit revert, boring reliable
    integration step. (§9.3)
14. **Escalating integration** — hard merges re-enter verification and
    re-approval instead of being forced through; bar calibrated high to
    protect throughput. (§9.3)
15. **Hard-coded priority** (in-flight > priority label > oldest) and
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
implementation, GitHub Issues + `gh` only.

Explicit non-goals for v1:

- Parallel ticket execution, worktrees, multiple factory instances.
- Configurable priority, configurable/extensible gate family, autonomy dials.
- Auto-pickup of unlabeled issues / auto-triage without human release.
- Telemetry and metrics (the journals are already collecting the data).
- GitHub Action / webhook triggers; ticket-backend abstraction (Jira etc.).
- Feedback loop (incidents/CI failures re-entering intake as tickets).

## 15. Future outlook

Ordered roughly by expected value:

1. **`claude -p` while-loop runner, then parallel factories** — headless
   cycles in fresh sessions (subscription-covered), multiple loops with the
   dispatcher's label-lock preventing double-pickup; requires per-ticket
   environment isolation (Compose-style stacks via `env_*`) and worktrees.
2. **Faster human round-trips** — a GitHub Action triggering a cycle when the
   human answers a `tsf:needs-human` comment or approves a plan, so parked
   tickets resume in minutes instead of at the next scheduled cycle.
3. **Extensible gate family** — architecture-conformance, regression-scope,
   project-defined gates, all inheriting the context-starved report-writing
   contract; per-project gate configuration.
4. **Telemetry from journals** — cycle time per stage, gate-failure and
   replan rates, CI-fix frequency, human-turnaround times; the factory's DORA
   equivalent, mined from files that already exist.
5. **Spec evolution** — richer spec formats, spec templates per work type
   (feature/bug/refactor), and better async spec refinement UX.
6. **Escalation-phrasing iteration** (§9.3) and dossier-quality iteration
   from real-run feedback — explicitly expected, the baselines are starting
   points.
7. **Ticket-backend abstraction** — only if a non-GitHub consumer actually
   appears.
