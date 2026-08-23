---
date: 2026-08-23T08:46:47Z
git_commit: 001c68049df0552f503f0e5a75db0d1a7c8d92de
branch: main
repository: toby-plugins
topic: "TP-0026 — improving the quality of the goals /tle:define produces"
tags: [research, codebase, tle, define, goal-file, completeness, verification-agent, prompt-design]
status: complete
last_updated: 2026-08-23
---

# Research: TP-0026 — improving the quality of the goals `/tle:define` produces

**Date**: 2026-08-23T08:46:47Z
**Git Commit**: 001c68049df0552f503f0e5a75db0d1a7c8d92de
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0026 asks how to make `/tle:define` reliably produce goal files that are complete
enough to run a loop to a genuinely finished result. The first real tle run found the
goal file, not the architecture, was the weak point: it missed criteria, was not
sceptical enough to enforce goal-definition best practice, and did not capture
everything the loop's agents needed to get going.

The ticket's Questions for Research/Planning, restated:

1. Where do comparable "interrogate the user until the spec is sound" patterns already
   exist in this repo, and what is reusable?
2. Does the fix belong in `define.md`'s discussion steps, in
   `goal-file-template.md`'s authoring guidance, or both — and how does that interact
   with the point-of-use reference read?
3. Is a fresh-context critic agent (mirroring `plan-compliance-checker`'s isolation)
   the right shape for judging a draft goal's completeness?
4. What is the minimum ops-fact set that makes a loop startable, and can it be derived
   rather than asked for?

## Summary

**What `/tle:define` does today.** It is a 175-line command with nine linear steps
(converge → survey → decompose → oracle hierarchy → ops facts → budgets → IDs → write
→ hand off), closed by five hard "Never …" rules
(`plugins/tle/commands/define.md:87-175`). Its quality machinery is real but thin:

- It has a strong **standard-setting preamble** ("Be the demanding editor of the goal",
  `define.md:51`; the four-bullet `## CRITICAL: WHAT MAKES THIS FILE WORTH WRITING`,
  `define.md:58-63`).
- It has a **ranked oracle hierarchy** applied per item (`define.md:117-124`).
- It has **exactly one omission hunt**, a single sentence at the end of Step 3:
  "Explicitly ask whether anything they consider part of 'done' is missing — a goal
  with a hole in it is a loop that stops early." (`define.md:115`). I verified by grep
  that this is the only "missing"-hunting instruction anywhere in the tle plugin.
- It has **zero "do not proceed until …" gates**. Not one of the nine steps blocks
  advancement on a quality condition. Every step's exit is "present and iterate until
  the user is satisfied".
- It has **no completeness pass over its own draft** — no second look, no category
  sweep, no critic.

**Why that is the gap.** The TP-0025 implementation plan
(`thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:385-434`)
specified `/tle:define`'s interaction contract as "converge → decompose → push
verification down the oracle hierarchy → collect ops facts → agree budgets → assign
IDs" and **recorded no scepticism or push-back requirement at all**. The command was
built exactly to spec; the spec had no completeness step. The same plan left two of
Phase 2's manual acceptance criteria unticked, one of them verbatim: "Every `Verify
by` is either a command or a selector-free user-level scenario — *(not confirmed —
goal quality was the first run's main shortcoming; see TP-0026)*"
(plan `:456-460`). The gap is documented at its origin.

**The repo already contains every pattern needed to fix it**, in commands that are not
tle's. `/tce:ticket` carries three hard "Do not proceed until …" gates
(`ticket.md:171`, `:180`, `:199`); `/tce:review` Phase 3 enumerates nine omission
categories to sweep (`review.md:167-225`); `/tce:research` runs a three-criteria
sufficiency check with an explicit "Explicitly NOT required" negative list
(`research.md:114-133`); `/tce:init` **verifies a mechanism by executing it before
recording it** (`init.md:284-293`); `/tce:refresh` refuses to write without approval
(`refresh.md:14`); `/tce:implement` delegates a criteria check to a deliberately
starved fresh-context agent (`implement.md:244-297`). Question 1's answer is that
essentially nothing new needs inventing — the patterns exist and are load-bearing
elsewhere.

**The ops-fact set is smaller and more precise than the template suggests.** Reading
the consumers rather than the template: exactly **four** ops facts have named consumers
(boot command, test command, base commit, test file locations), and each has exactly
one or two. The template's fifth bullet, `**Other:**`, is referenced by **no** consumer
— it reaches agents only because they read the goal file in full. Conversely, three
facts the loop genuinely needs come from **outside** the goal file: the commit
convention (from `.claude/tce/profile.md` or a Conventional-Commits fallback,
`loop-implementer.md:50`), browser-tool availability (discovered at runtime,
`loop-verifier.md:51-54`), and the escalation rung (from `loop-log.md`,
`run.md:132`). Question 4's answer: the minimum startable set is those four, all four
are derivable, and — critically — **none of them is currently proven before being
written down**. `/tle:define` records commands it has never run.

**A fresh-context critic is the right shape but must be adapted.** The evidence for
role separation is strong (Anthropic's harness-design post reports the exact failure
mode — an agent identifying legitimate issues then talking itself into approving;
Huang et al. show intrinsic self-correction without external feedback can degrade
output; Panickssery et al. show evaluators favour their own generations). But two
platform facts constrain the shape: **subagents can never call `AskUserQuestion`**
(filtered unconditionally, `sub-agents` docs; established in TP-0025 research
`:497-499`), so a critic can only *return findings* that `/tle:define` then puts to
the user; and the strongest published gap-finding technique is not "review this for
gaps" but **build an artifact and diff it** (perspective-based reading) or **sweep a
fixed category taxonomy** (Spec Kit's `/clarify`).

**The two-file question (Question 2) has a structural answer.** `define.md` is the
*interrogation*; `goal-file-template.md` is the *artifact contract*. Anything the
model must do **while talking to the user** must be in `define.md` — the template is
read only at Step 8, immediately before writing, so guidance placed there arrives
after every decision it could influence. Conversely, per-item quality standards that
must survive compaction belong in the reference file, which is re-read from disk.
There is real headroom: `define.md` is 11,864 bytes (≈3,000 tokens) against a
confirmed 5,000-token compaction re-attach cap, so roughly 8 KB of growth is
available before the truncation cliff bites — but truncation keeps the **start** of
the file, so anything added late in the body is what gets lost.

## Detailed Findings

### 1. `/tle:define` today — where quality control exists and where it doesn't

The nine steps and their exit conditions (`plugins/tle/commands/define.md:87-166`):

| Step | Line | What it does | Exit condition |
|---|---|---|---|
| 1 Converge on the goal | `:87-96` | restate in one sentence, establish boundary, agree slug, immutability guard | user confirms; **hard STOP if the loop dir exists** |
| 2 Survey what exists | `:98-104` | grounding pass over repo root, manifest, existing tests; optional `profile.md` read | none |
| 3 Decompose | `:106-115` | one item = one outcome = one check; write `Done when` / `Verify by` | "iterate until they are satisfied" + the one omission question |
| 4 Oracle hierarchy | `:117-124` | push each item to command-with-exit-code, browser scenario as fallback | none — reports which items ended up as scenarios |
| 5 Ops facts | `:126-136` | boot, tests, base commit, test file locations, other | "propose … and confirm them; ask for the ones you cannot determine" |
| 6 Budgets | `:138-142` | max iterations, ~2–3 per item | none |
| 7 Stable IDs | `:144-146` | number `item-01`… | none |
| 8 Write | `:148-154` | point-of-use read of the template, fill every placeholder | **never write a placeholder** |
| 9 Hand off | `:156-166` | path, condition block, next two steps | stop |

The `## Important Rules` block (`:168-175`) is the densest set of hard constraints in
the tle plugin: never edit an existing goal file, never write a placeholder, never
invent an ops fact, **never accept a subjectively-judged item**, and "All user
interaction happens here. The loop's agents can never ask the user anything."

The last rule is architecturally load-bearing and constrains every option below: the
platform filters `AskUserQuestion` out of all subagents, so any critic agent added by
this ticket returns findings to `define.md`, which asks.

**What is absent, precisely:**

- No blocking gate anywhere. `/tce:ticket` has three; `/tle:define` has zero.
- No category taxonomy to sweep for omissions — only the single Step 3 sentence.
- No verification that a stated `Verify by` command exists or runs.
- No verification that the boot or test command works. Step 5 says "propose values
  from Step 2's survey … and confirm them" — confirmation is conversational, not
  executed. `git rev-parse HEAD` (`:132`) is the **only** ops fact the command
  actually runs a command to obtain.
- No check for `chrome-devtools-mcp` availability, even though `:124` explains that an
  absent server turns browser items into `cannot-verify` — the command warns about a
  condition it never tests.
- No second look at the assembled draft before writing.

### 2. What the loop's consumers actually need from the goal file

Mapping every consumer against the template (`plugins/tle/references/goal-file-template.md:26-71`):

| Template field | Consumers | Use |
|---|---|---|
| `**Boot the app:**` | `run.md:91` (baseline check); named-only in all three agents `:12` | one-line baseline result; a non-booting app is an enumerated `cannot-verify` reason (`loop-verifier.md:64`) |
| `**Run tests:**` | `loop-implementer.md:49`, `:74` (green gate before commit); `loop-verifier.md:47` | the implementer's hard precondition for committing |
| `**Base commit:**` | `run.md:101` (passed as a scalar), `loop-verifier.md:45` (`git diff <base> -- <test globs>`) | the test-integrity diff |
| `**Test file locations:**` | `loop-verifier.md:46` **only** | the pathspec of that diff |
| `**Other:**` | **none** | referenced by no consumer; reaches agents only via the full-file read |
| `## Budgets` → Max iterations | `run.md:183` | the stop check, run *after* dispatch and logging |
| `- [Any further budget]` | **none** | `define.md:142` already says only max iterations is enforced |
| item IDs | `loop-verifier.md:70,78`; `run.md:120,130` | verdict-vector keys; stall comparison |
| `**Done when:**` | `loop-verifier.md:70` | the outcome evidence must establish |
| `**Verify by:**` | `loop-verifier.md:70,72`; `loop-spec-planner.md:68-69,91` | the only sanctioned check — both agents are forbidden from substituting an easier one |
| `## /goal condition` | `run.md:72,82` | reprinted when no goal is set |
| `# Loop Goal: [title]`, `**Slug:**`, `**Created:**` | effectively none | the runner derives paths from the goal file's own directory (`run.md:74`); the slug appears only in transcript wording (`run.md:114`) and the log title (`run.md:167`) |

**Facts the loop needs that no goal-file field supplies:**

- **Commit convention** — `loop-implementer.md:50` reads `.claude/tce/profile.md`'s
  `## Commit convention`, else Conventional Commits. In a tce-less project (tle's
  stated target) this is an unstated default.
- **Browser tooling availability** — discovered at runtime; `loop-verifier.md:51-54`
  emits `cannot-verify` with reason "browser verification unavailable".
- **Escalation rung** — read back from `loop-log.md` (`run.md:132`).

**Naming drift worth noting for any edit:** consumers refer to facts by role ("boot
command", "test command") while the template labels them `**Boot the app:**` /
`**Run tests:**`. The base-commit and test-locations labels match literally.

### 3. Interrogation and gating patterns available in this repo

This is the direct answer to the ticket's Question 1. All of these are in-repo,
proven, and consistent with the house style.

**(a) Hard "do not proceed until" gates — `/tce:ticket`.** Three, each closing a
phase (`plugins/tce/commands/ticket.md:171`, `:180`, `:199`):

> **Do not proceed until the user confirms your understanding.**
> **Do not proceed until the outcome is concrete and measurable.**
> **Do not proceed until acceptance criteria are specific, measurable, and complete.**

Phase 4 is the closest analogue to `/tle:define` Step 3 and is worth reading in full
(`ticket.md:188-199`): it demands verifiable criteria with worked bad/good examples
("Bad: 'upload works'. Good: 'user can upload a PDF up to 50 MB and see it in their
list within 5 s'"), then probes edge cases across four named dimensions.

**(b) Enumerated omission categories — `/tce:review` Phase 3**
(`review.md:167-225`). Nine lettered categories, each a *place to look for something
absent*: Completeness, Correctness, Side Effects, Consistency, **Gaps** ("Is anything
left missing from the ticket?"), Test Coverage, Cleanup, Security, Duplication. This
is the in-repo precedent for a taxonomy sweep.

**(c) A three-criteria sufficiency test with a negative list — `/tce:research`**
(`research.md:114-133`). The shape that stops a check over-firing: three numbered
criteria, then "Explicitly NOT required: business justification, formal acceptance
criteria, technical detail, or any particular section structure", then a defined
failure action (one batched clarification round) and a defined success action
("proceed without bothering the user").

**(d) Verify a mechanism by executing it before recording it — `/tce:init` Phase 3**
(`init.md:284-293`), quoted because it is the closest existing analogue to the
ops-fact problem:

> For non-file ticket systems, **verify access before writing**: ask the user for an
> existing ticket reference and try the read mechanism (e.g. `gh issue view 123`, the
> Jira CLI/MCP call). If it fails, resolve tooling/auth with the user now —
> `tickets.md` must only document mechanisms that actually work.

The parallel is exact: `goal.md` must only document ops facts that actually work.

**(e) Refuse to write on insufficient input.** Existing instances:
`define.md:93-95` (existing loop dir → STOP, "even if the user asks you to");
`define.md:152` (never write a placeholder); `refresh.md:14` ("Do not write anything
until the user approves"); `refresh.md:122` (no high-confidence drift → "stop without
writing"); `quickfix.md:19` (creation forbidden → STOP); `research.md:267` ("NEVER
write the research document with placeholder values"); `init.md:13-14` /
`tmt/init.md:11-12` ("Do not write any files until the user confirms").

**(f) Two-track ceremony scaled to size — `/tce:ticket`** (`ticket.md:96-151`).
Small/Medium collapse seven phases into at most two rounds, "you are batching the
questions, not lowering the bar" (`:120-125`), with an in-place **escalation clause**
if the work proves larger than estimated (`:114-118`). TP-0019's research established
the key structural point: quality invariance comes from the **body template being
identical across tracks** — the compressed track just has to fill the same sections.

**(g) Refusing to take the user's word — `/tce:plan`** (`plan.md:283-288`): "If the
user corrects any misunderstanding: DO NOT just accept the correction … Only proceed
once you've verified the facts yourself."

**(h) Post-write existence checks** — `quickfix.md:146` ("MANDATORY OUTPUT … If it
doesn't exist on disk, the phase failed — go back and write it") and `run.md:108`,
`:151` (same shape, but stop instead of retry).

### 4. The fresh-context critic pattern, and what it would take here

`plugins/tce/agents/plan-compliance-checker.md` is the repo's one non-research
verification agent. Its shape (99 lines):

- **Frontmatter**: `tools: Read, Grep, Glob, LS` (no Bash, no Edit/Write — read-only
  by tool omission), `model: inherit`.
- **Input contract** (`:14-26`): given a numbered criteria list and the diff; "You do
  NOT receive — and must NOT seek out — the ticket's problem statement, the plan's
  rationale, the research document, or the conversation that produced the code.
  Judging the change *without* the reasoning that produced it is the entire point of
  this check."
- **Verdict vocabulary** (`:37-47`), four literals: `met`, `not met`, `cannot verify
  from diff`, `needs human verification`, with a conservative tie-break: "When in
  doubt between met and not met, use cannot verify from diff" (`:79`).
- **Three-part envelope**: `## CRITICAL: YOUR ONLY JOB IS …` (5 DO-NOTs + 1 ONLY),
  `## What NOT to Do` (8 Don'ts), `## REMEMBER: You are a compliance checker, not a
  code reviewer` — closing with "A checker prompted to find problems always finds
  some" (`:99`).
- **Evidence requirement**: "Every 'met' carries a `file:line` — no evidence, not
  'met'" (`:75`).

Dispatch (`implement.md:268-271`): named in bold prose, foreground, payload
enumerated, "Pass it **only** the numbered criteria list and the diff". Any "not met"
**blocks** the done transition (`:280-284`).

tle's own three agents follow a variant skeleton: `disallowedTools` rather than
`tools` (all three block `Task` and `AskUserQuestion`), a `## What you receive`
section with a negative clause, a `## Verdicts` list with a conservative tie-break
("when in doubt between `pass` and `fail`, use `fail`", `loop-verifier.md:66`), a
`## Return Format` demanding exactly one line to the caller, and a re-pointed
`## REMEMBER:` identity ("You are an instrument, not a participant",
`loop-verifier.md:131`).

**Constraints on a goal-critic agent, if one is added:**

- It cannot ask the user anything (`AskUserQuestion` is filtered from all subagents).
  It returns findings; `define.md` adjudicates them with the user.
- Plugin agents are auto-discovered from `agents/`; no manifest entry, and TP-0017's
  `disable-model-invocation` classification does not apply to agents.
- Plugin agents are the **lowest** of five precedence scopes — a same-named project
  agent shadows it, arguing for a distinctive name.
- Plugin agents cannot set `permissionMode`, `hooks`, or `mcpServers`.
- The file-only-handoff invariant (`run.md:16-17`) is a *runner* rule; `/tle:define`
  is interactive and already holds the draft in context, so a critic returning
  findings inline is consistent with the plugin's design.
- Prior art on the failure mode this would address is unambiguous: OpenAI's CriticGPT
  found "hundreds of errors in ChatGPT training data rated as 'flawless'", but also
  reports critics **hallucinate** defects — so proposed gaps should be adjudicated by
  the user, not auto-inserted.

### 5. Platform facts that constrain the design

Verified against official Claude Code / Anthropic docs this session:

- **Skill compaction**: "Claude Code re-attaches the most recent invocation of each
  skill after the summary, keeping the first 5,000 tokens of each. Re-attached skills
  share a combined budget of 25,000 tokens" — and older skills can be dropped
  entirely. **Truncation keeps the start of the file.** `define.md` is 11,864 bytes
  (≈3,000 tokens), leaving roughly 8 KB of headroom; content added near the end is
  what a truncation would cost.
- **Claude Code does not re-read a skill file on later turns** — which is exactly why
  the point-of-use reference read exists, and why guidance that must apply *during*
  the discussion cannot live in a file read only at Step 8.
- **`AskUserQuestion` is filtered from every subagent**, unconditionally.
- **`/goal` conditions cap at 4,000 characters.** Not a practical risk for the current
  template, but a constraint `define.md` should not exceed.
- **`/goal` has a third verdict, `Impossible`**, which clears the goal and records a
  failed entry. A goal file containing an unsatisfiable item can therefore kill the
  loop outright — an argument for feasibility being part of the completeness pass.
- **Background work defers rather than disables evaluation.** The docs say Claude Code
  skips that turn's evaluation and "evaluates at the end of the next turn that
  finishes with no background work running", with check-ins after 30 minutes
  (`CLAUDE_CODE_GOAL_CHECKIN_MINUTES`). CLAUDE.md's phrasing ("silently disables the
  loop's driver") is stronger than the documentation supports. The foreground-dispatch
  rule remains correct; only the justification is overstated. **Out of TP-0026's
  scope** (the ticket excludes engine-model changes) — recorded for a future ticket.

### 6. External prior art on specification completeness

The single most transferable body of work is **GitHub Spec Kit**, which implements
three distinct completeness mechanisms this repo does not have:

- **`/speckit.clarify`** — a coverage interview over a **nine-category taxonomy**
  (functional scope, domain/data model, interaction/UX flow, non-functional quality
  attributes, integrations, edge cases and failure handling, constraints and
  tradeoffs, terminology, and **completion signals**), each marked Clear / Partial /
  Missing. Procedure: a hard quota of five questions, one at a time, each answerable
  by 2–5 mutually exclusive options or a ≤5-word phrase, prioritised by
  **Impact × Uncertainty**, filtered to those that "prevent misaligned acceptance
  tests". This maps almost exactly onto the repo's existing AskUserQuestion
  guidelines.
- **`/speckit.analyze`** — a defect-taxonomy audit across duplication, ambiguity,
  underspecification, constitution alignment, **coverage gaps**, and inconsistency,
  with a CRITICAL/HIGH/MEDIUM/LOW severity ladder in which "untestable criteria" is
  HIGH.
- **`/speckit.checklist`** — described as "**unit tests for requirements writing**",
  and it explicitly *prohibits* behavioural verification items in favour of
  requirements-quality questions ("**Are** the number and layout of featured episodes
  explicitly specified?" rather than "Verify the page displays 3 cards"). The
  implication for tle is sharp: **the goal file's checklist is entirely Spec Kit's
  prohibited category** — which is correct for an oracle — meaning tle has no artifact
  of the quality-question category at all.

**Anthropic's "Harness design for long-running application development"** is the
closest published analogue to tle's architecture (planner → generator → evaluator) and
contributes two ideas:

- The **sprint contract**: "Before each sprint, the generator and evaluator negotiated
  a sprint contract: agreeing on what 'done' looked like for that chunk of work before
  any code was written" — i.e. the *verifier* reviews the definition of done before it
  is frozen. Granularity reported: 27 criteria for one sprint.
- Hard thresholds with **no partial credit**, and the explicit failure report: "it
  would identify legitimate issues, then talk itself into deciding they weren't a big
  deal and approve the work anyway … Separating the agent doing the work from the
  agent judging it proves to be a strong lever."

**Requirements-engineering techniques for finding what is missing:**

- **ISO/IEC/IEEE 29148** separates *item-level* quality (necessary, unambiguous,
  singular, feasible, verifiable, …) from *set-level* quality, where completeness means
  the set "needs no further amplification" and "contains no To Be Defined (TBD), To Be
  Specified (TBS), or To Be Resolved (TBR) clauses". This is the conceptual crux:
  every check applied to a *single* checklist item is item-level, but TP-0026's failure
  is **set-level**, which by definition cannot be established by inspecting items — it
  requires an external reference (the stated goal, a domain model, a user journey).
- **Perspective-Based Reading** (Basili et al.; Porter/Votta/Basili, IEEE TSE 1995):
  reviewers read from distinct perspectives (designer / tester / user), each with an
  **active procedure** — they *build an artifact* from that perspective, and defects
  surface where the artifact cannot be built. Transferable form: "write the test-case
  list a QA engineer would run, then list every case with no corresponding checklist
  item." Honest caveat: the empirical evidence for PBR over checklist reading is
  **mixed**, with replications finding checklist readers detecting more defects per
  hour; the *mechanic* is what transfers, not a proven effectiveness claim.
- **Requirements Smells** (Femmer et al., JSS 2016): lightweight lexical indicators —
  subjective language, ambiguous adverbs/adjectives, superlatives, comparatives, vague
  pronouns, loopholes ("as far as possible"), non-verifiable terms — each mapped to a
  29148 criterion. An excellent **item-level** filter over `Done when` text;
  explicitly not a completeness technique.
- **EARS** (via Kiro's spec mode): "WHEN <event> THE SYSTEM SHALL <response>", designed
  so each statement is singular and mechanically testable. A candidate grammar for
  `Done when`. Note the repo has previously and deliberately rejected borrowing Kiro's
  and Spec Kit's *notations* while accepting their concepts (TP-0019 research).
- **Specification by Example** (Adzic): "deriving scope from goals" is the set-level
  anchor 29148 implies — judge the checklist against the *stated goal*, not against
  itself.

**On self-review versus a separate critic:** Huang et al. (ICLR 2024) find LLMs
struggle to self-correct without external feedback and sometimes degrade;
Panickssery et al. (NeurIPS 2024) find evaluators favour their own generations, with
self-preference correlating with self-recognition. Madaan et al.'s Self-Refine is
genuine counter-evidence on generation-style tasks. **No study isolates "fresh
context" as the causal variable** — the robust finding is role separation, not context
isolation. Any rationale written into the repo should say so.

### 7. Sync rules any change must satisfy

From `CLAUDE.md`, all directly triggered by this ticket:

- **"tle's engine model — one iteration per turn"**: changing the iteration steps in
  `run.md` requires updating the condition-string template in
  `goal-file-template.md` and the README flow in the same commit. TP-0026 does not
  change `run.md`, but it may change the condition-string template — the rule is
  bidirectional in spirit, so the README flow must be checked.
- **"The verdict vector is a machine contract"**: the `item-NN` ID scheme is supplied
  by `goal-file-template.md`, emitted by `loop-verifier.md`, parsed by `run.md`. Any
  change to the ID scheme touches all three. TP-0026's AC 5 forbids disturbing it.
- **The AskUserQuestion guidelines block** is byte-identical across ten files,
  including `plugins/tle/commands/define.md:19-37`. Editing it in one requires editing
  all ten.
- **TP-0017 invocation control**: `/tle:define` correctly carries
  `disable-model-invocation: true` (nothing delegates into it). A new agent carries no
  classification.
- **Reference files are part of the command contract** and must be read at the point
  of use.

## Code References

- `plugins/tle/commands/define.md:51` - "Be the demanding editor of the goal" — the standard-setting role line
- `plugins/tle/commands/define.md:58-63` - `## CRITICAL: WHAT MAKES THIS FILE WORTH WRITING` (oracle, command-preferred, immutability, permanent IDs)
- `plugins/tle/commands/define.md:93-96` - the immutability guard; the command's only hard STOP
- `plugins/tle/commands/define.md:106-115` - Step 3 decompose; line 115 is the sole omission hunt in the whole plugin
- `plugins/tle/commands/define.md:117-124` - Step 4, the two-rung oracle hierarchy
- `plugins/tle/commands/define.md:126-136` - Step 5, ops facts — proposed and confirmed, never executed
- `plugins/tle/commands/define.md:148-154` - Step 8, point-of-use template read + no-placeholder rule
- `plugins/tle/commands/define.md:168-175` - `## Important Rules`, including "All user interaction happens here"
- `plugins/tle/references/goal-file-template.md:26-71` - the goal-file skeleton
- `plugins/tle/references/goal-file-template.md:40` - `**Other:**` — the ops-fact bullet no consumer reads
- `plugins/tle/references/goal-file-template.md:73-117` - authoring guidance (oracle hierarchy, scenarios, granularity, immutability)
- `plugins/tle/agents/loop-verifier.md:45-47` - the test-integrity diff, sole consumer of test file locations
- `plugins/tle/agents/loop-verifier.md:51-54` - browser-tool availability discovered at runtime
- `plugins/tle/agents/loop-verifier.md:62-66` - verdict vocabulary and the `fail` tie-break
- `plugins/tle/agents/loop-verifier.md:78-87` - the verdict-vector machine contract
- `plugins/tle/agents/loop-spec-planner.md:68-69,91` - the plan's verification must match the goal's `Verify by`
- `plugins/tle/agents/loop-implementer.md:49-50` - test command as the green gate; commit convention from profile.md
- `plugins/tle/commands/run.md:72` - the canonical extraction list from the goal file
- `plugins/tle/commands/run.md:91` - boot command, the only baseline check
- `plugins/tle/commands/run.md:120,130-138` - convergence check and stall check over the verdict vector
- `plugins/tle/commands/run.md:183` - the max-iterations budget check
- `plugins/tce/commands/ticket.md:171,180,199` - the three "Do not proceed until …" gates
- `plugins/tce/commands/ticket.md:188-199` - Phase 4, testable acceptance criteria with bad/good examples
- `plugins/tce/commands/ticket.md:96-151` - the two-track scale-adaptive ceremony and its escalation clause
- `plugins/tce/commands/research.md:114-133` - the three-criteria sufficiency check with its negative list
- `plugins/tce/commands/review.md:167-225` - Phase 3's nine omission categories
- `plugins/tce/commands/init.md:284-293` - verify a mechanism by executing it before recording it
- `plugins/tce/commands/refresh.md:14,122` - refuse to write without approval; stop when nothing to change
- `plugins/tce/commands/plan.md:109-137` - open-questions gate ("WAIT for the user's answer")
- `plugins/tce/commands/plan.md:283-288` - do not accept a user correction without verifying it
- `plugins/tce/agents/plan-compliance-checker.md:14-26` - the input contract and its negative clause
- `plugins/tce/agents/plan-compliance-checker.md:37-47` - the four-verdict vocabulary
- `plugins/tce/agents/plan-compliance-checker.md:73-79,92-99` - evidence requirement, tie-break, closing identity
- `plugins/tce/commands/implement.md:244-297` - the Plan-Compliance Gate: assemble, dispatch, act on verdicts

## Architecture Documentation

**The goal file is a multi-consumer contract, not a document.** Four consumers read it
(`run.md` plus three agents), each re-reading it fully from disk every dispatch. Two
of its fields are machine-parsed (the `item-NN` IDs via the verdict vector; the
max-iterations value), and two are prose contracts the agents are forbidden from
reinterpreting (`Verify by`, which neither the verifier nor the planner may substitute;
`Done when`, which the evidence must establish).

**The register split between `define.md` and `goal-file-template.md`** follows
TP-0016's reference-file partition: the template holds a large stable fill-in skeleton
plus authoring guidance, read once at the point of writing; the command holds the
interaction. The consequence for this ticket is structural — guidance in the template
arrives at Step 8, after every decision it could have shaped.

**tle's agent skeleton differs from tce's** in three respects that matter for any new
agent: `disallowedTools` instead of `tools`, a `## Return Format` demanding exactly one
line to the caller, and a re-pointed `## REMEMBER: You are X, not Y` identity. A
`/tle:define`-side critic would break the one-line rule deliberately — that rule exists
to protect the *runner's* context, and `define.md` is interactive.

**The house dispatch idiom** is bold prose naming the agent (`Use the **loop-verifier**
agent (foreground)`) with an enumerated payload; no command in either plugin writes a
literal `Task(...)` call or a `subagent_type`.

## Historical Context (from thoughts/)

- `thoughts/shared/discussions/2026-08-19-tle-loop-engineering-plugin.md:115-134` — the
  settled design of what `goal.md` must contain. Ops facts were justified as "so agents
  don't rediscover them each iteration", with project groundwork explicitly manual and
  no initializer agent.
- `thoughts/shared/discussions/2026-08-19-tle-loop-engineering-plugin.md:39-45` — the
  prior-art principles the plugin was built on, including "a granular machine-checkable
  DONE checklist" and the ~29% → ~1% hacked-solution reduction from a separate monitor.
- `thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:385-434` —
  `/tle:define`'s specified interaction contract. **Records no scepticism or push-back
  requirement**; this is where the gap originates.
- `thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:456-460` —
  the two Phase 2 manual criteria left unticked, one explicitly deferring to TP-0026.
- `thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:171-181` —
  Decision 6, why no pass-state field: "a pass-state field that is never updated is dead
  machinery". AC 5 of TP-0026 protects this.
- `thoughts/shared/plans/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:100-128` —
  Decision 1, the condition string carries the restart directive and self-heals under
  compaction.
- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:497-499` —
  subagents can never use `AskUserQuestion`, "so all user interaction must live in
  `/tle:define`, never in an agent".
- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md:529-538` —
  the 5,000 / 25,000-token compaction budget and "truncation keeps the start of the file".
- `thoughts/shared/research/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md:198-230` —
  the reusable interviewing techniques: mode branching, detect-then-recommend-first,
  batched rounds, size-escalation bail-out, and the sufficiency check as the model for a
  cheap up-front judgment that selects interaction density.
- `thoughts/shared/research/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md:166-178` —
  quality invariance across tracks comes from an identical body template.
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md:232-246` —
  why the checker is denied the ticket/plan/research: "reading those would expose the
  implementation rationale and defeat the adversarial isolation"; and the
  inspector-vs-pure-judge fork, resolved toward inspector.
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md:350-358` —
  gate on every closing rather than only when criteria exist, because the latter
  "creates a silent bypass exactly where criteria are thin".
- `thoughts/shared/tickets/TP-0025-tle-loop-engineering-plugin.md:143-161` — the closing
  note recording the first run's findings and the three unexercised failure modes.

## Related Research

- `thoughts/shared/research/2026-08-19-TP-0025-tle-loop-engineering-plugin.md` — the tle plugin's platform research (`/goal`, subagents, compaction)
- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` — the fresh-context verification agent's design rationale
- `thoughts/shared/research/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md` — interaction-density design and interviewing techniques
- `thoughts/shared/research/2026-07-10-TP-0022-sufficiency-criteria-sync-rule.md` — the three-part sufficiency test and how its copies drift across registers

## Impact Analysis

The goal file is consumed by four independent readers, so any change to its structure
is a contract change. Recorded here because TP-0026's AC 5 and AC 6 turn on it.

### Existing Usages Found

- `plugins/tle/commands/run.md:72` - extracts slug, four ops facts, max iterations, item IDs, condition string
- `plugins/tle/commands/run.md:91` - boot command
- `plugins/tle/commands/run.md:101` - passes base commit to the verifier as a scalar
- `plugins/tle/commands/run.md:120,130` - parses the verdict vector, keyed on item IDs
- `plugins/tle/commands/run.md:183` - max-iterations value
- `plugins/tle/agents/loop-verifier.md:12,45-46,70,72,78` - ops facts, per-item `Done when`/`Verify by`, item IDs, goal-file order
- `plugins/tle/agents/loop-spec-planner.md:12,35,56,68-69,91` - ops facts, checklist for item selection, item ID + short name, `Verify by`
- `plugins/tle/agents/loop-implementer.md:12,39,49-50` - test command (hard dependency), base commit and test locations (informational)
- `plugins/tle/README.md:25-26,148-156,162-167` - documents the ops facts, the directory contents, and the immutability rule

### Current Contract

- **Input**: a markdown file at `thoughts/shared/loops/<goal-slug>/goal.md` with the literal headings `## Ops facts`, `## Budgets`, `## Checklist`, `## /goal condition`; item headings of the form `### item-NN — [short name]`; per-item `**Done when:**` and `**Verify by:**` lines.
- **Output/consumption**: `item-NN` IDs are the verdict vector's keys and the stall check's comparison basis; `Verify by` is the only sanctioned check and may not be substituted by either the verifier or the planner; max iterations is compared against a glob-derived iteration number.
- **Assumptions**: item IDs are permanent and never reused or renumbered; the file never changes after the loop starts; every bracketed placeholder has been filled.

### Adaptation Requirements

- Adding a **new ops fact** requires deciding its consumer. A fact no agent is told to read reaches agents only via the whole-file read — which is the current status of `**Other:**`. If a new fact should be acted on, the consuming agent's `:12` fact list must name it.
- Adding a **new per-item field** touches `loop-verifier.md:70` (what it reads per item) at minimum, and `run.md` only if it becomes machine-parsed.
- Changing the **item-ID scheme** touches `goal-file-template.md`, `loop-verifier.md` and `run.md` in the same commit (CLAUDE.md rule), and is forbidden by TP-0026's AC 5.
- Changing the **condition-string template** touches `goal-file-template.md`, `run.md` and `plugins/tle/README.md` in the same commit (CLAUDE.md rule).
- Changing the **AskUserQuestion block** in `define.md` touches all ten copies.

### Backward Compatibility Options

- **Option A — additive only**: add new sections/fields to the goal file and leave existing ones untouched. Existing goal files stay readable by every consumer; no sync rule beyond the README fires. Cheapest, and satisfies AC 5 by construction.
- **Option B — enrich `define.md` only, leave the artifact unchanged**: put the completeness machinery entirely in the command's discussion steps. Zero contract change, zero sync-rule exposure; but nothing about the improved standard survives into the file for a later reader to audit.
- **Option C — restructure the goal file**: highest cost — the verdict-vector rule, the condition-string rule and the README all fire, and any goal file from a running loop becomes historical. AC 5's immutability requirement makes this hard to justify.

## Open Questions

1. **What exactly was missing from the first run's goal file?** The ticket flags this as
   the most valuable input and as recoverable only from the user's run. This research
   could not recover it — the scratch project is not in this repo and no artifact of
   that run is in `thoughts/`. This is a planning-phase question for the user, and the
   concrete gaps should drive which of the mechanisms below are adopted.
2. **Which completeness mechanism, and in what combination?** The candidates found are:
   a fixed category taxonomy swept for Clear/Partial/Missing (Spec Kit `/clarify`,
   `/tce:review` Phase 3); an active-artifact diff (perspective-based reading: build
   the QA test-case list, diff against the checklist); a goal-anchored set-level check
   ("if every item passes, is the stated goal achieved?"); a per-item smell filter over
   `Done when`; and hard "do not proceed until …" gates. These are not mutually
   exclusive, and each has a different cost in interaction rounds.
3. **Agent or in-command pass?** A fresh-context critic has the stronger evidence base
   for the "talks itself into approving" failure, but adds an agent file, cannot ask
   the user, and hallucinates some findings. An in-command pass costs nothing
   structurally but is self-review, which Huang et al. warn about. A middle option —
   the critic agent that *already exists*, `loop-verifier`, reviewing the draft goal
   before it is frozen — mirrors Anthropic's "sprint contract" but would require the
   verifier to accept an input mode it currently forbids.
4. **How far should ops-fact verification go?** `/tce:init`'s precedent is to execute
   the mechanism before recording it. For tle that would mean actually running the boot
   command, the test command, and each `Verify by` command (expecting non-zero for
   not-yet-done items), and probing for browser tooling. This is the most direct route
   to AC 3, but it lengthens the definition session and needs a policy for a command
   that legitimately does not exist yet (the oracle hierarchy explicitly endorses
   naming a test the loop will write).
5. **Should `/tle:define` adopt a scale-adaptive two-track ceremony?** A five-item goal
   and a twenty-five-item goal do not need the same interrogation depth, and
   `/tce:ticket` has the in-repo pattern. Not required by any acceptance criterion.
6. **Does the commit convention belong in the ops facts?** `loop-implementer.md:50`
   falls back to Conventional Commits when `.claude/tce/profile.md` is absent — which
   is tle's stated target case. Recording it in the goal file would remove a silent
   default, at the cost of a fifth consumed ops fact.

## External Sources

**Claude Code / Anthropic (official)**

- https://code.claude.com/docs/en/goal — `/goal` semantics: evaluator runs at Stop and calls no tools; three verdicts including `Impossible`; 4,000-character condition cap; stall guard fires on no tool use; background work defers evaluation with 30-minute check-ins
- https://code.claude.com/docs/en/skills — skill content lifecycle: 5,000-token re-attach per skill, 25,000-token shared budget, truncation keeps the start, skills are not re-read on later turns
- https://code.claude.com/docs/en/sub-agents — `AskUserQuestion` filtered from every subagent; foreground vs background behavior
- https://code.claude.com/docs/en/plugins-reference — plugin-agent frontmatter subset; `${CLAUDE_PLUGIN_ROOT}` substitution in skill and agent content
- https://code.claude.com/docs/en/scheduled-tasks — a `disable-model-invocation` skill fired by a schedule reaches Claude as plain text
- https://platform.claude.com/docs/en/build-with-claude/define-success — specific / measurable / achievable / relevant; multidimensional success criteria
- https://platform.claude.com/docs/en/build-with-claude/develop-tests — "Don't forget to factor in edge cases"; "use a different model to evaluate than the model used to generate outputs"
- https://www.anthropic.com/engineering/harness-design-long-running-apps — the sprint contract; hard thresholds with no partial credit; the "talks itself into approving" failure and role separation as the lever

**Spec-driven tooling**

- https://github.com/github/spec-kit — the workflow
- https://raw.githubusercontent.com/github/spec-kit/main/templates/commands/clarify.md — the nine-category coverage taxonomy and the five-question quota
- https://raw.githubusercontent.com/github/spec-kit/main/templates/commands/analyze.md — the defect taxonomy and severity ladder
- https://raw.githubusercontent.com/github/spec-kit/main/templates/commands/checklist.md — "unit tests for requirements writing"
- https://kiro.dev/docs/specs/feature-specs/requirements-first/ — EARS notation for testable acceptance criteria

**Requirements engineering**

- https://www.iso.org/standard/45171.html — ISO/IEC/IEEE 29148 (paywalled); item-level vs set-level completeness, the TBD/TBS/TBR rule
- https://www.cs.umd.edu/~mvz/handouts/emp_pbr.pdf — Basili et al., perspective-based reading
- https://dl.acm.org/doi/abs/10.1109/32.391380 — Porter, Votta & Basili, IEEE TSE 1995; scenario-based detection methods
- https://link.springer.com/article/10.1023/A:1009724120285 — an extended replication finding mixed results for PBR vs checklist reading
- https://www.sciencedirect.com/science/article/abs/pii/S0164121216000789 — Femmer et al., Requirements Smells (JSS 2016)
- https://www.manning.com/books/specification-by-example — Adzic; deriving scope from goals

**LLM critique**

- https://cdn.openai.com/llm-critics-help-catch-llm-bugs-paper.pdf — CriticGPT; dedicated critics find errors in artifacts rated flawless, but hallucinate some
- https://arxiv.org/abs/2310.01798 — Huang et al., LLMs cannot self-correct reasoning without external feedback
- https://proceedings.neurips.cc/paper_files/paper/2024/file/7f1f0218e45f5414c79c0679633e47bc-Paper-Conference.pdf — Panickssery et al., evaluators favour their own generations
- https://arxiv.org/abs/2303.17651 — Madaan et al., Self-Refine (counter-evidence on generation-style tasks)

## tce Config Drift

`.claude/tce/profile.md`'s **Code map** predates the tle plugin, even though the
profile's prose below the table already mentions tle. Three rows omit directories that
exist on disk (verified this session):

- "Slash commands (long markdown prompts)" lists `plugins/tce/commands/`,
  `plugins/tmt/commands/` — missing `plugins/tle/commands/` (contains `define.md`,
  `run.md`).
- "Research subagents" lists `plugins/tce/agents/` — missing `plugins/tle/agents/`
  (contains `loop-verifier.md`, `loop-spec-planner.md`, `loop-implementer.md`).
- "Runtime reference files (command templates)" lists `plugins/tce/references/` —
  missing `plugins/tle/references/` (contains `goal-file-template.md`).

This matters here specifically because the code map is what the research agents read to
know where to look, and every file this ticket touches is in a directory the map omits.

Consider running `/tce:refresh` to reconcile the config.
