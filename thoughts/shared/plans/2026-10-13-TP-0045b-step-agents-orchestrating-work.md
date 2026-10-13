# TP-0045b: the step agents and the orchestrating `/tce:work` — Implementation Plan

## Overview

Move the working of `/tce:research`, `/tce:plan` and `/tce:implement` into five
new tce agents (`researcher`, `planner`, `plan-challenger`, `implementer`,
`verifier`) and rewrite `/tce:work` as a foreground orchestrator. It dispatches
one agent per step, asks the human only in planning, keeps its position on disk,
runs bounded fix loops, and ends with a dossier and the delivery step from
`## Delivery`. This is an extraction, not a redesign. The six single-step
command files stay byte-identical, so the stage reverts with `git revert`.

## Current State Analysis

The research document
(`thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md`)
is the codebase context. In short:

- `work.md` (295 lines, flagged) re-describes research, plan and implement
  inline. It runs all three in one context window and delegates only
  `/tce:commit` and the checker (`work.md:65-284`).
- Step logic and dialog sites:
  - `research.md` asks in 3 places; `plan.md` in 11; `implement.md` in about 10.
  - None of these sites can execute inside an agent: `AskUserQuestion` is
    removed from subagents.
- The plan template has no `## Decisions` section
  (`plan-document-template.md:26-120`). The intent template's Decisions line
  shape is the agreed mirror (`intent-document-template.md:70-93`).
- The plan log exists and `stage.sh` reads only its first `Status:` line
  (`stage.sh:108-167`). No fix-loop counter exists, and `implement.md`'s gate
  loop is unbounded (`implement.md:312-316`).
- The checker is shell-less by design (`plan-compliance-checker.md:1-99`).
  TP-0032 records that it escalated 7 of 7 items, 6 of them doable.
- Platform facts:
  - Interactive subagents run in the background unless
    `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` is set.
  - A command's `allowed-tools` grant is turn-scoped and does not reach its
    subagents.
  - After compaction a command keeps its first 5,000 tokens.
- `init.md` never edits `.claude/settings.json` (`init.md:631`). The two
  sanctioned edits are `/tmt:init` and `/tsf:init` (`tsf/commands/init.md:352-393`).
- `## Delivery` and `## Reader` are recorded but have no reader beyond
  `/tce:intent` (`templates/tce/profile.md:99-132`).

## Desired End State

- **The agents.** `plugins/tce/agents/` holds five new agents, each:
  - showing its return shape filled in inside its own prompt;
  - returning a bounded block and naming artifacts by path;
  - never asking the user.
- **The `/tce:work <ticket>` flow:**
  1. Refuses unless the foreground and timeout environment is set.
  2. Refuses without an intent, naming `/tce:intent`.
  3. Derives its position from `stage.sh` and the plan.
  4. Runs research, then planner questions; asks the human; resumes the planner.
  5. Runs the planner's brief and the challenger, then asks for brief approval.
     A push-back resumes the planner.
  6. Implements phase by phase, then runs the verifier, which runs the gate.
  7. Runs bounded fix loops, writes the closeout and the dossier, and delivers.
- **What is on disk:**
  - research and plan documents of today's structure, plus the plan's
    `## Decisions`;
  - per-phase logs with `Fix rounds`;
  - a `## Verification` section;
  - a dossier under `thoughts/shared/dossiers/`.
- **`/tce:init`** offers an allowlist, surgically and on approval.
- **Docs and release:** CLAUDE.md, the tce README and the root catalog
  describe the new mechanism. tce is 1.4.0 and tagged.

**Verify:**

- `claude plugin validate` passes for the marketplace and all four plugins.
- `git diff --quiet 0321362 -- plugins/tce/commands/{research,plan,implement,quickfix,review,commit}.md`
  exits 0.
- One real ticket in a consuming project runs end to end through the new
  `/tce:work`.

### Key Discoveries:

- **Nested dispatch from a background agent works on 2.1.296, but the child's
  result arrives asynchronously.**
  - The parent only saw it because it kept polling (spike, 2026-10-11).
  - Foreground dispatch is therefore required for the researcher's fan-out
    (decision 1).
- **`AskUserQuestion` answers return inside the same turn.** Questions and brief
  approval go through it, so a whole run stays in one turn. That keeps
  `work.md`'s turn-scoped `allowed-tools` grant valid for the scripts it runs.
- **The orchestrator runs every plugin script** (`ticket.sh`, `stage.sh`,
  `branch.sh`, `baseline.sh`, the new `work.sh`). Agents receive paths and
  values, so they never need a grant for `${CLAUDE_PLUGIN_ROOT}` scripts that
  the turn grant would not cover.
- **tsf passes its references directory in the payload** (`templates:`,
  `tsf/agents/plan.md:33-43`). tce does the same with `references:`, rather
  than relying on `${CLAUDE_PLUGIN_ROOT}` substitution in agent bodies.
- **`stage.sh` matches `Phase N` headings and the first `Status:` per log**
  (`stage.sh:146-163`). An added `Fix rounds` line, a `## Decisions` section, a
  `## Verification` section and a new `thoughts/shared/dossiers/` directory all
  leave `progress` unchanged.
- **`ticket.sh` finds any `thoughts/` file whose name contains the ID.** A
  dossier named `YYYY-MM-DD-<ID>-<slug>.md` is discovered with no change.

## What We're NOT Doing

- **No change to the six protected commands.** `research.md`, `plan.md`,
  `implement.md`, `quickfix.md`, `review.md` and `commit.md` stay unchanged.
  Rewiring them is TP-0045c.
- **No change to a step's working** beyond what extraction requires. Anything
  else goes to TP-0045d or its own ticket.
- **Deferred to other tickets:**
  - progress heads-up lines from running agents (TP-0045d);
  - the test-meaningfulness gate (TP-0046);
  - fixing TP-0029's model-precedence statement in CLAUDE.md (observed in
    research; outside scope).
- **No change to the checker's contract or tools.** It stays shell-less
  (TP-0020/TP-0032), and only its caller changes.
- **Not enforcing Delivery's "next ticket only after the previous pull request
  is merged" rule** in `/tce:work`. It stays the human's rule as the profile
  states it; enforcement is a TP-0045d candidate.
- **No `agent-present` or HTML brief, no stacked branches, no tsf/tmt/tle
  change.**
- **`/tce:design_explore` does not run inside the orchestrated flow.** The
  planner surfaces a missing design decision as a question.
- **No model pins:** all new agents use `model: inherit` (decision 2).

## Decisions

Resolved with the user, 2026-10-11 to 2026-10-13:

- **`/tce:work` requires foreground dispatch.** It refuses unless
  `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` is set and `BASH_DEFAULT_TIMEOUT_MS`
  is at least 600000. That beats running on the background default, where the
  orchestrator ends its turn and acts on notifications. The fan-out needs
  synchronous child results, and the turn-scoped grant must survive.
- **All new agents are `model: inherit`.** That beats tsf-style
  `sonnet`/`opus` pins. Today's steps run on the session model, and pins can
  follow from real-run cost data (TP-0045d).
- **`## Decisions` and the `Fix rounds` line go into the shared plan
  template.** That beats a plan-agent-only reference. There is one plan shape,
  and `/tce:plan` gains the section through the template while its file stays
  byte-identical.
- **The fix-loop bound is 3 rounds**, with the counter as
  `- **Fix rounds**: n/3` in each phase's log. The final verify/gate loop is
  counted on the last phase's log as `- **Final fix rounds**: n/3`. That beats
  2 or 5 rounds.
- **The verifier may tick a MANUAL item it proved**, recording its evidence in
  `## Verification`. That beats ticking only on human confirmation. Items it
  cannot prove go into the dossier as "for you to check", and the ticket moves
  to Done only when none remain.
- **Under Pull request delivery, the dossier is the pull-request body.** That
  beats a ported pr-body template plus the dossier as a comment.

Decided while planning (surfaced for veto in the review summary):

- **Agent names are `researcher`, `planner`, `plan-challenger`, `implementer`
  and `verifier`.** These names don't collide with the `tce:research` /
  `tce:plan` / `tce:implement` skills.
- **The orchestrator runs every plugin script.** Agents get paths and values
  (see Key Discoveries).
- **One new script, `plugins/tce/scripts/work.sh`**, with two modes:
  `preflight` (environment check) and `artifact <path>` (exists, non-empty,
  committed). It follows the `branch.sh`/`baseline.sh` pattern: fixed
  `key: value` lines, exit 0 on every reported outcome. It parses no
  agent-authored content.
- **The verifier dispatches the compliance checker itself.** It assembles the
  criteria (ticket AC + intent AC + plan Automated/Manual, MANUAL marked), runs
  `git diff` from the baseline the orchestrator resolved, and passes only those
  two things.
  - This is the same isolation as `implement.md`, which also dispatches the
    checker from a context that has read the plan.
  - The verifier then attempts the checker's "cannot verify" and "needs human
    verification" items with the shell and the browser. That makes it TP-0032's
    attempt-before-escalate consumer.
- **The verifier writes a `## Verification` section** at the end of the plan,
  before any Closeout. The dossier is written by the verifier in a second
  dispatch (`mode: dossier`) to
  `thoughts/shared/dossiers/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`. It is
  committed, so the "exists, non-empty, committed" check applies to it.
- **The orchestrator itself appends `## Implementation Closeout` and makes the
  ticket's Done transition.** It is a few lines from data it already holds, as
  `implement.md:125-138` and `331-348` specify. The implementer makes the start
  transition (In Progress) when it begins phase 1.
- **The challenger loop has 3 rounds per session, counted in the run, not on
  disk.** A crash there re-runs the challenger from round 1. That costs a few
  dispatches, and no code has been written yet.
- **Plan approval has no on-disk marker.** If a session dies after approval and
  before phase 1's log exists, the next run re-renders the brief with the
  planner in `mode: brief` and asks again.
- **Resume uses `SendMessage`.** If the agent ID is lost, or the resumed result
  does not arrive in the turn, the orchestrator re-dispatches a fresh agent
  from disk state, passing the answers or push-back already given.
- **Agents commit through the Skill tool (`tce:commit`, unflagged).** If commit
  would ask (its branch check), the agent returns `blocked`.
- **An unreadable return gets one retry with a "show the shape" note**
  (TP-0043). The note points at `agent-returns.md` and at the agent's own
  `## Return`.
- **The dossier is ported from tsf's dossier template, minus its factory
  parts.** It also drops tsf's impact rating, because the dossier carries
  counted facts and no scores. Neither the pr-body nor the question-comment
  template is ported. The question layout lives in `work-brief.md`.
- **`/tce:init`'s allowlist entries:**
  - `Read(~/.claude/plugins/**)`;
  - `Edit(thoughts/shared/**)`;
  - local git: `add`, `commit`, `diff`, `log`, `show`, `status`, `rev-parse`,
    `branch`;
  - the profile's test/typecheck/lint commands.
  - Never `git push` or `gh`. Those are granted only in `work.md`'s
    `allowed-tools`, for delivery.

## Implementation Approach

Contracts first (references and the template), then agents that point at them,
then the orchestrator that dispatches the agents, then init, then docs and the
release. Each phase leaves the repo valid: the plugin validates, and the
protected commands are unchanged. Nothing becomes reachable until Phase 4
rewrites `work.md`, so Phases 1-3 are inert additions.

**Baseline for the byte-identity check:** `0321362` (HEAD when this plan was
written).

**Shared automated checks for every phase** (run from the repo root):

- `claude plugin validate .` plus `claude plugin validate ./plugins/tce`,
  `./plugins/tmt`, `./plugins/tle` and `./plugins/tsf` all pass.
- `git diff --quiet 0321362 -- plugins/tce/commands/research.md plugins/tce/commands/plan.md plugins/tce/commands/implement.md plugins/tce/commands/quickfix.md plugins/tce/commands/review.md plugins/tce/commands/commit.md`
  exits 0.

## Phase 1: Shared contracts — plan template and new references

### Overview

Add the shapes every later phase points at: the plan template's `## Decisions`
and log-line additions, the return-shape reference, the brief and question
layout, and the dossier template.

### Changes Required:

#### 1. Plan template

**File**: `plugins/tce/references/plan-document-template.md`

**Changes**:

- **Header comment:** name the `planner` agent (instead of "/tce:work's
  planning phase") as a reader. Name the `implementer`/`verifier` agents as
  writers of the implementation-time additions.
- **New `## Decisions` section** in the template, between `## Implementation
  Approach` and `## Phase 1`:

  ```markdown
  ## Decisions

  - **[decision]** — over [rejected alternative]: [why] *(yours)*
  - **[decision]** — over [rejected alternative]: [why] *(decided for you)*
  ```

  Add one guideline paragraph:
  - Every choice between real alternatives that shaped the plan gets a line,
    in the intent's Decisions line shape.
  - `*(yours)*` marks a decision the human made (in the intent or in planning).
    `*(decided for you)*` marks one taken on their behalf.
  - The dossier counts the second kind.
- **"Implementation-time additions"** gains three items, all "do not author":
  - the `- **Fix rounds**: n/3` log line (phase verification);
  - the `- **Final fix rounds**: n/3` line on the last phase's log;
  - the `## Verification` section the orchestrated verifier appends.

  The note keeps saying that implement.md owns the log format and that the
  orchestrated agents add these lines.

#### 2. Agent return shapes

**File**: `plugins/tce/references/agent-returns.md` (new)

**Changes**: a runtime reference with a header comment in the style of the
existing references: who reads it, and that it is a contract under the new
CLAUDE.md rule. Contents:

1. **The status vocabulary:**
   - `done`;
   - `done with concerns`;
   - `needs decision` (planner questions, or fix-loop exhaustion);
   - `blocked` (a situation the agent can neither resolve nor defer).

   Only `needs decision` and `blocked` reach the human. Concerns go to the
   dossier.
2. **The return block:** one fenced block tagged `tce-return`, with no angle
   brackets or nested fences (TP-0034a lesson), and these fields in this order:
   - `status:`
   - `step:` — `research | plan-questions | plan | brief | challenge | implement | fix | verify | dossier`
   - `artifact:` — a path, or `none`
   - `summary:` — at most 3 lines
   - `concerns:` — bullets, or `none`
   - `blocked-on:` — only with `blocked`: what, and the exact command or file
     the human needs
3. **The planner's extra body** after the block:
   - the questions in the `work-brief.md` question layout (`plan-questions`);
   - the brief (`plan` / `brief`, or a delta on push-back).
4. **Length bounds:**
   - 25 lines for the block;
   - 60 lines for a brief or a question batch;
   - the full artifact is always named by path, never inlined.
5. **The parsing rule:** the orchestrator reads the block as text. No script
   parses it. An unreadable or missing block gets one retry, with the "show the
   shape" note quoted verbatim:

   ```
   Your return did not contain a readable tce-return block. End your reply with
   exactly the block shown in your own ## Return section, fields in that order.
   ```

#### 3. Brief and question layout

**File**: `plugins/tce/references/work-brief.md` (new)

**Changes**: the terminal layout from the design discussion, adapted to the
table-collapse constraint. Three parts:

- **Questions.**
  - One decision per AskUserQuestion question, up to 4 per call.
  - Each is self-contained (never "see research.md"), with the recommended
    option first and its reasoning.
  - Each states what changes with the alternative.
  - Each is phrased per `## Reader`.
  - The planner returns them as a numbered list:
    question / header / options (label + one-line description, recommended
    first) / "if not recommended: what changes".
  - The orchestrator copies them into the dialog, with an intro under the
    AskUserQuestion block's rules.
- **The brief:**

  ```
  APPROVE?  <n> decisions need you · <m> made on your behalf · <k> risks

  Understood: <2 lines>
  Approach:   <2 lines> — rejected: <alternative, one line why>

  ## Decisions for you
  1. <question> — (a) <recommended, why> (b) <alternative> — if (b): <what changes>

  ## Decided for you (push back on any)
  - <choice> — over <alternative>: <why>

  ## Phases
  Phases: <n> · tests in <x>/<n> · files touched <f> · manual checks <c>
  1. <scope> — <files> — <tests>

  Risk: <one line>
  Full plan: <path>
  ```

  - No tables with prose cells.
  - Headings and short bullets only.
  - Counted facts, never confidence numbers.
  - "Decisions for you" is usually empty after the questions-first round.
    Anything that appears there is asked through AskUserQuestion before
    approval.
- **The push-back delta:**
  - `CHANGED:` with the takeaway line again;
  - then only the sections that changed, each line marked `+` (new) or `~`
    (changed).

#### 4. Dossier template

**File**: `plugins/tce/references/dossier-template.md` (new)

**Changes**: ported from `plugins/tsf/references/templates/dossier.md`.

- **Kept:**
  - what the dossier is for;
  - one-sentence summary;
  - "start here" with permalinks;
  - what was built;
  - where to look;
  - "never claim a verification that did not run";
  - evidence as post-change line numbers.
- **Shed:**
  - the GH paths;
  - the comment `created_at` role;
  - the landing addendum;
  - "How to respond";
  - Overlapping work;
  - the impact rating.
- **Added — a counted-facts line under the summary:**

  ```
  Criteria met <n>/<m> · fix rounds <r> · tests added <t> · decisions made for you <d> · for you to check <c>
  ```

- **New sections:**
  - `## Decided for you`, copied from the plan's `*(decided for you)*` lines;
  - `## For you to check`, each item with the exact command or step and what
    pass looks like;
  - `## Concerns`.
- **Permalinks** use the repository's forge URL at the last implementation
  commit when the remote is a known forge; otherwise `path:line` plus the
  commit SHA.
- **Filename:** `thoughts/shared/dossiers/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`.
  The file's text is posted as-is as the pull-request body under Pull request
  delivery.

### Success Criteria:

#### Automated Verification:

- [x] The shared automated checks pass (validate × 5, protected commands
      byte-identical).
- [x] `plugins/tce/references/agent-returns.md`, `work-brief.md` and
      `dossier-template.md` exist and are non-empty.
- [x] `grep -n "^## Decisions" plugins/tce/references/plan-document-template.md`
      matches inside the template fence.
- [x] `CLAUDE_PROJECT_DIR=$PWD plugins/tce/scripts/stage.sh TP-0045a` still
      prints `progress: 4/4` and `source: log`.

#### Manual Verification:

- [ ] Reading the three new references, each has a header comment naming its
      readers and its contract rule. None contains a stack or ticket-system
      literal.

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `0b2b8f8` (the plan's own commit; HEAD before any implementation commit)
- **Commit**: `273910f` feat(TP-0045b): add the shared contracts for the orchestrated work
- **Did**: plan template gains `## Decisions`, its guidelines and the three orchestrated additions; new `agent-returns.md`, `work-brief.md`, `dossier-template.md`
- **Issues**: plan expected `progress: 4/4` for TP-0045a; it has 6 phases and prints `6/6` before and after → check intent (unchanged, `source: log`) holds
- **Verification**: ✅ validate ×5, ✅ protected commands identical, ✅ `## Decisions` inside the fence, ✅ stage.sh unchanged

---

## Phase 2: The researcher and planner agents

### Overview

Extract `/tce:research` and `/tce:plan` into autonomous agents that keep their
working and turn every dialog site into data in the return.

### Changes Required:

#### 1. Researcher

**File**: `plugins/tce/agents/researcher.md` (new)

**Frontmatter**:

- `name: researcher`
- `description:` "Internal to `/tce:work` — not for direct use. Researches a
  ticket … and writes the research document. Returns a tce-return block."
- `disallowedTools: AskUserQuestion`. With no `tools` list, `Agent`, Write,
  Bash, Web and MCP tools are inherited.
- `model: inherit`

**Body** (envelope: `## CRITICAL` right after the intro, `## What NOT to Do`
and `## REMEMBER` at the end, the tsf worker shape):

- **What you receive:**
  - `ticket:`
  - `ticket-file:` (or how to read it per `tickets.md`)
  - `intent:` path
  - `parent:` paths (optional)
  - `branch:`
  - `references:` dir
  - `profile:` and `tickets:` paths
- **Process — `research.md`'s steps, in order and by name:**
  1. Re-read in chain order: ticket → intent → parent documents. The intent
     takes precedence over the ticket's wording. **No sufficiency check:**
     an intent exists by contract.
  2. Read mentioned files; decompose.
  3. Fan out to the six research agents, named exactly as `research.md:215-265`
     lists them. `web-search-researcher` is required when third-party code is
     involved. Sub-agents are told they are documentarians. Wait for all.
  4. Synthesis. Live codebase research is the primary source.
  5. The config-drift check (read-only; adds the "tce Config Drift" section).
  6. Git metadata and permalinks.
  7. Read `<references>/research-document-template.md` now, in full, and write
     the document exactly per it, including its conditional sections.
  8. Commit via the `tce:commit` skill (docs-only).
- **Dialog sites become data:**
  - "follow-up questions?" is dropped (no checkpoint, by ticket decision).
  - Anything that needs a decision goes into the document's Open Questions,
    which the planner surfaces.
  - The branch dialog is the orchestrator's.
  - A commit that would ask returns `blocked`.
- **The documentarian envelope** from `research.md:59-86` is carried into
  `## CRITICAL`, including its two sanctioned exceptions.
- **`## Return`:** a filled-in `tce-return` with `step: research`, the
  document path, a 3-line summary, the open-question count and
  "config drift: yes/no".
- **CRITICAL also says:** never ask the user; never write outside
  `thoughts/shared/research/`; never edit tce config; never branch.

#### 2. Planner

**File**: `plugins/tce/agents/planner.md` (new)

**Frontmatter**: `name: planner`, an "Internal to `/tce:work`" description,
`disallowedTools: AskUserQuestion`, `model: inherit`.

**Body**:

- **What you receive:**
  - `ticket:`, `ticket-file:`, `intent:`, `research:`, `parent:`;
  - `references:`, `profile:`, `tickets:`;
  - `mode:` — `questions | write | revise | challenge-fix | brief`;
  - `answers:` — on `write`, the human's answers verbatim;
  - `push-back:` — on `revise`, verbatim;
  - `findings:` — on `challenge-fix`, the challenger's findings verbatim;
  - `plan:` — path, for `revise`/`challenge-fix`/`brief`.
- **Every mode** starts by re-reading, in chain order: ticket → intent →
  research → (plan when it exists) (TP-0013). The research document is the
  codebase context: no agents and no re-reading of source it covers, except
  `plan.md:110-116`'s listed cases (`Agent` is available for those).
- **`mode: questions`** (writes nothing):
  1. Collect open questions from `plan.md:128-133`'s sources plus the intent's
     `## Open questions`.
  2. Run the design-exploration check (`plan.md:258-286`): a non-trivial UX
     change with no `DECISION.md` becomes a question with the two options
     "Stop and run /tce:design_explore" / "Plan directly".
  3. Return:
     - understanding (2 lines);
     - approach and the rejected alternative;
     - the questions in `work-brief.md`'s question layout, recommended first;
     - status `needs decision`, or `done` with "0 questions".

  This replaces `plan.md`'s understanding message, its open-questions round
  and its design-options pick.
- **`mode: write`:**
  1. Read `<references>/plan-document-template.md` now, in full, and shape
     the phases (`plan.md` Step 3). There is no outline approval: the brief is
     the approval surface.
  2. Make the UI/UX decisions with rationale (`plan.md:391`).
  3. Read the template again and write the plan to
     `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`, exactly per
     the template:
     - Automated/Manual split;
     - `## Decisions` listing the intent's decisions and the answers as
       `*(yours)*`, and everything chosen while planning as
       `*(decided for you)*`.
  4. Commit via `tce:commit`.
  5. Return the brief per `work-brief.md`. This replaces `plan.md` Step 5's
     summary: the decisions, riskiest assumptions and out-of-scope lines map
     onto the brief's sections.
- **`mode: revise` / `challenge-fix`:** fold in the push-back or findings,
  update `## Decisions`, commit, and return the delta brief.
- **`mode: brief`:** re-read the plan and return the full brief. No changes.
- **`## Return`:** two filled-in examples — `plan-questions` with two
  questions, and `plan` with a brief.
- **CRITICAL also says:** never implement; write only the plan document;
  never ask the user — questions are data.

### Success Criteria:

#### Automated Verification:

- [x] The shared automated checks pass.
- [x] `grep -c "AskUserQuestion" plugins/tce/agents/researcher.md plugins/tce/agents/planner.md`
      shows only the `disallowedTools` line and CRITICAL prose — no instruction
      to call it.
- [x] Both agents contain a fenced `tce-return` example in their `## Return`
      section.
- [x] `grep -n "codebase-locator\|codebase-analyzer\|codebase-pattern-finder\|thoughts-locator\|thoughts-analyzer\|web-search-researcher" plugins/tce/agents/researcher.md`
      finds all six names.

#### Manual Verification:

- [ ] Side-by-side reading of `research.md` against `researcher.md`, and of
      `plan.md` against `planner.md`: every step and every check of the
      command appears in the agent, or is listed in this plan as a dialog site
      turned into data.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: see below
- **Did**: new `agents/researcher.md` (research.md's steps 1-9, envelope, impact analysis, dialog sites as data) and `agents/planner.md` (five modes, questions-first, brief/delta returns)
- **Issues**: research.md step 7 uses `gh repo view` for permalinks → researcher derives owner/repo from the remote URL (no `gh` grant reaches agents)
- **Verification**: ✅ validate ×5, ✅ protected identical, ✅ AskUserQuestion only in `disallowedTools`, ✅ `tce-return` examples, ✅ six agent names

---

## Phase 3: The challenger, implementer and verifier agents

### Overview

The remaining three agents: the plan check against the brief, one-phase
implementation with the on-disk log, and verification with the shell, the
browser and the gate.

### Changes Required:

#### 1. Plan challenger

**File**: `plugins/tce/agents/plan-challenger.md` (new)

**Frontmatter**: `tools: Read, Grep, Glob, LS` (read-only, like the checker),
`model: inherit`.

**Inputs**: `plan:`, `intent:`, `research:`, `profile:`, plus `brief:` (the
planner's brief, verbatim and bounded).

**Closed checklist** (TP-0041):

1. Every success criterion is meaningful and either verifiable by command or
   marked Manual.
2. Every phase has a test or states why none applies.
3. Nothing contradicts the profile's stack or the research's findings.
4. Every intent acceptance criterion is covered by a phase.
5. Phases are independently verifiable in order.
6. Every `*(decided for you)*` line in `## Decisions` appears in the brief, and
   the brief claims nothing the plan does not contain.

**Rules**: one verdict per item (`pass` / `fail` + evidence `path:line`). Only
checklist items; no style or quality review (checker-style three-part
envelope). Findings that only a human can settle are marked `human`.

**`## Return`**: a `tce-return` with `step: challenge`. `done` means all pass;
`done with concerns` means human findings only; `needs decision` means
failures, listed one line each with evidence.

#### 2. Implementer

**File**: `plugins/tce/agents/implementer.md` (new)

**Frontmatter**: `disallowedTools: AskUserQuestion`, `model: inherit`.

**Inputs**: the ticket and plan paths, plus:

- `ticket:`, `intent:`, `research:`, `plan:`, `profile:`, `tickets:`;
- `phase:` N;
- `mode:` — `phase | fix`;
- `findings:` — on `fix`, the verifier's failing items verbatim, or the
  `## Verification` path;
- `base-commit:` — on the first phase only, the SHA the orchestrator read with
  `git rev-parse HEAD`.

**Process — `implement.md`'s working for one phase:**

1. Re-read ticket → intent → research → plan in full (TP-0013).
2. Apply the log rules (`implement.md:142-149`):
   - resume inside a partially logged phase;
   - on phase 1, write the log with `**Base commit**`;
   - a legacy `.status.md` is read-only.
3. Make the ticket's start transition per `tickets.md` when phase 1 begins.
4. Run the phase's changes. On a mismatch with reality, return `blocked`
   (this replaces the STOP block at `implement.md:207-214`).
5. Run the phase's Automated checks with the profile's commands:
   - use the Bash tool's maximum timeout;
   - redirect output to a file under `.git/tce/`, then read it (the TP-0036
     rule, stated verbatim).
6. **Fix loop:** at most 3 rounds, counter `- **Fix rounds**: n/3` in the
   phase's log, updated each round. Exhaustion means `needs decision` with
   the last failure's evidence.
7. Tick the Automated items and update the log (≤ 8 lines plus the counter).
8. Commit via `tce:commit` with the full pre-commit checklist, and put the
   hash on the log.

**`mode: fix`** (after the verifier):

- Fix the listed items.
- Update `- **Final fix rounds**: n/3` on the **last** phase's log.
- Re-run the affected checks.
- Commit.

**Not done here:** Manual items are not ticked (the verifier does that), and
the done transition and Closeout are the orchestrator's.

**`## Return`**: filled-in `implement` and `fix` examples. The summary carries
`phase N/M`, commit hash, fix rounds used and tests added (count).

#### 3. Verifier

**File**: `plugins/tce/agents/verifier.md` (new)

**Frontmatter**: `disallowedTools: AskUserQuestion`, `model: inherit`. No
`tools` list, so Bash and the session's MCP browser tools are inherited.

**Inputs**: the ticket, intent and plan paths, plus `profile:`, `tickets:`,
`baseline:` (resolved by the orchestrator via `baseline.sh`), `references:`
and `mode:` (`verify | dossier`).

**`mode: verify`:**

1. Re-read ticket → intent → research → plan.
2. Run every test/typecheck/lint suite from the profile: maximum timeout,
   output redirected to `.git/tce/`.
3. Assemble the numbered criteria list:
   - the ticket's acceptance criteria, the intent's acceptance criteria, and
     every phase's Automated and Manual items, verbatim, with MANUAL marked.
   - Run `git diff <baseline> -- . ':(exclude)thoughts/'` and `--stat`.
   - Dispatch `plan-compliance-checker` with **only** the criteria and the
     diff. This is the `implement.md:263-303` contract, unchanged.
4. Attempt every "cannot verify from diff", "needs human verification" and
   MANUAL item:
   - **Attempt kinds** (tsf `manual-verify.md:53-57`): an existing command, a
     throwaway script, a request against the running app, or the browser
     (`mcp__chrome-devtools__*` if available).
   - Reading the code is **not** an attempt.
   - **Escalate** only for credentials, third-party systems, visual or
     subjective judgment, or a decision. Give the exact command and what pass
     looks like (TP-0032).
5. Append or replace `## Verification` at the end of the plan, before any
   Closeout:
   - one bullet per criterion: verdict and evidence (command and result, or
     `path:line` in post-change source — never patch offsets);
   - then a `For you to check:` list.
6. Tick each MANUAL item it proved, with ` — verified by agent, see
   ## Verification` appended to the item.
7. Commit the plan via `tce:commit` (docs-only).

**`mode: verify` return**:

- `done` — tests green, all criteria met, nothing for the human;
- `done with concerns` — green, but items remain for the human;
- `needs decision` — not met or failing, listed with evidence.

**`mode: dossier`:**

1. Read `<references>/dossier-template.md` now, in full.
2. Count from disk:
   - criteria met from `## Verification`;
   - fix rounds from the logs;
   - tests added from the diff;
   - decisions made for you from `## Decisions`.
3. Write the dossier with permalinks at `git rev-parse HEAD`.
4. Commit.
5. Return its path.

**`## Return`**: filled-in `verify` and `dossier` examples.

### Success Criteria:

#### Automated Verification:

- [ ] The shared automated checks pass.
- [ ] `ls plugins/tce/agents/` lists the five new agents and the seven existing
      ones.
- [ ] `grep -n "^tools:" plugins/tce/agents/verifier.md` finds nothing: no
      explicit tools list, so MCP browser tools are inherited.
- [ ] `grep -n "Fix rounds" plugins/tce/agents/implementer.md plugins/tce/references/plan-document-template.md`
      finds the line shape in both.
- [ ] `git diff --quiet 0321362 -- plugins/tce/agents/plan-compliance-checker.md`
      exits 0.

#### Manual Verification:

- [ ] Side-by-side reading of `implement.md` against `implementer.md` plus
      `verifier.md` plus the Phase 4 orchestrator: the phase loop, log rules,
      intermediate commits, final verification, gate, Closeout and status
      transitions are each carried by exactly one of them.

---

## Phase 4: The orchestrating `/tce:work`

### Overview

Rewrite `work.md` as the orchestrator. Keep it well under 5,000 tokens and put
the per-step payloads and position table into a point-of-use reference. Add
`work.sh` for the two mechanical checks.

### Changes Required:

#### 1. Script

**File**: `plugins/tce/scripts/work.sh` (new, executable, sources `lib.sh`)

**`work.sh preflight`** prints:

```
foreground: ok | missing
timeout:    ok | low (<value or unset>)
detail:     <one line>
```

- `foreground` is `ok` iff `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`.
- `timeout` is `ok` iff `BASH_DEFAULT_TIMEOUT_MS ≥ 600000`, the
  `tsf/scripts/preflight.sh:71` floor.

**`work.sh artifact <path>`** prints:

```
exists:    yes | no
nonempty:  yes | no
committed: yes | no
```

- `committed` means `git ls-files --error-unmatch` succeeds and
  `git status --porcelain -- <path>` is empty.

Both modes exit 0 on every reported outcome; usage errors exit 2.

#### 2. Orchestrator command

**File**: `plugins/tce/commands/work.md` (rewritten)

**Frontmatter**:

- The description names the orchestration and the env vars, in one sentence.
- `argument-hint: "[ticket-id]"`
- `disable-model-invocation: true` (TP-0017, still user-only).
- `allowed-tools`:
  - the scripts: `ticket.sh`, `stage.sh`, `branch.sh`, `baseline.sh`,
    `work.sh`;
  - local git: `Bash(git rev-parse:*)`, `Bash(git push:*)`;
  - GitHub: `Bash(gh pr create:*)`, `Bash(gh pr view:*)`.

**Body** (target ≤ 220 lines). The sections, in order:

1. **Project context:**
   - profile, tickets.md and the `[PREFIX]` note, as today;
   - `${CLAUDE_PLUGIN_ROOT}/references` is passed to agents as `references:`.
2. **The AskUserQuestion dialog guidelines block**, byte-identical to the
   other twelve copies.
3. **Invariants**, short:
   - one agent per step, dispatched in the foreground (`Use the tce:<agent>
     agent`);
   - artifacts travel by path, never contents;
   - the orchestrator never edits code or the research/plan;
   - only `needs decision` and `blocked` reach the human;
   - ask through AskUserQuestion so the run stays in one turn;
   - the position is always re-derived from disk.
4. **Step 0 — preflight:** run `work.sh preflight`. On anything but two `ok`s,
   refuse with the exact export lines and stop.
5. **Step 1 — ticket and intent:**
   1. Resolve the ID and run `ticket.sh`.
   2. Run `stage.sh <ID>`. No `intent:` line value means refuse: "No intent for
      <ID> — run /tce:intent <ID> first." Then stop.
   3. Parent ticket per `tickets.md`.
6. **Step 2 — branch:**
   - Under Branch per ticket: `branch.sh create` (or `switch` when the research
     already exists), with the TP-0031 stop-and-ask dialog **verbatim**, as in
     today's `work.md:84-99`.
   - Absent section or Current branch: skip silently.
7. **Step 3 — position:** read `<references>/work-dispatch.md` now, in full,
   and derive the next step from `stage.sh`, the plan and `ticket.sh`. The
   table lives in the reference:
   - no research → research;
   - no plan → plan questions;
   - plan with no log → brief and approval;
   - `k/N` with `k<N` → implement phase `k+1`;
   - `N/N` with no `## Verification` or a failing one → verify;
   - verified but no dossier → dossier;
   - dossier but no Closeout → closeout and delivery;
   - Closeout present → report done and stop.
8. **Step 4 — the loop:** for each step, dispatch with the payload from
   `work-dispatch.md`, then read the `tce-return`:
   - unreadable → one retry with the show-the-shape note;
   - then `work.sh artifact <path>` must report yes/yes/yes, else treat it as
     `blocked` with the missing check named;
   - `blocked` → print the `blocked-on:` text per `## Reader` and stop.
9. **Step 5 — planning interaction:**
   1. Read `<references>/work-brief.md` now, in full.
   2. Planner `questions`: if there are questions, ask them (intro +
      AskUserQuestion, one decision per question, ≤4 per call). Resume the
      planner with `mode: write` and the answers.
   3. Run the challenger. On failures, resume the planner with
      `challenge-fix`, at most 3 rounds; exhaustion is `needs decision`.
   4. Render the brief and the challenger's human findings, then ask
      "Approve the plan?" — header "Plan", options:
      - **Approve (Recommended)** — implementation starts now;
      - **Stop here** — the plan stays committed; re-run `/tce:work` to
        continue.

      A free-text answer is a push-back: resume the planner with `revise`,
      re-run the challenger, and show the delta.
10. **Step 6 — implement:**
    - one `implementer` dispatch per remaining phase, with `base-commit:` on
      phase 1;
    - after each, re-run `stage.sh` and continue from what it reports.
11. **Step 7 — verify:**
    1. Grep the plan's first `**Base commit**` and run `baseline.sh <base>
       <plan>`. `source: none` means `blocked`.
    2. Dispatch `verifier` (`verify`).
    3. `needs decision` → `implementer` (`fix`), then the verifier again, at
       most 3 rounds by `Final fix rounds`; exhaustion is `needs decision`
       with the evidence.
12. **Step 8 — dossier and closeout:**
    1. Dispatch `verifier` (`dossier`) and run the artifact check.
    2. Append `## Implementation Closeout` per `implement.md:125-138`'s field
       list. The merge reference is the pull-request URL, or
       "direct: <branch> @ <sha>".
    3. If the verifier left nothing for the human, make the Done transition
       per `tickets.md`. Otherwise the dossier and the final line say the
       transition is due once those items are checked.
    4. Commit via `/tce:commit`.
13. **Step 9 — delivery:**
    - `## Delivery` absent or **Direct**: print the dossier and stop.
    - **Pull request** (Branch per ticket guaranteed by the profile):
      `git push -u <remote> <branch>`, then
      `gh pr create --base <base> --head <branch> --title "<ID>: <ticket title>" --body-file <dossier>`.
      Print the URL and the dossier's takeaway line.
    - tce never merges.

**What leaves `work.md`:**

- the sufficiency-check copy (TP-0022);
- the inline re-descriptions of research, plan and implement;
- the inline gate.

#### 3. Dispatch reference

**File**: `plugins/tce/references/work-dispatch.md` (new)

**Changes**:

- The position table (Step 3 above), with how each signal is read:
  - `stage.sh` fields;
  - `grep` for `^## Verification`, `^## Implementation Closeout`,
    `**Base commit**`;
  - `ticket.sh` for `thoughts/shared/dossiers/`.
- One payload template per agent and mode: the exact `key: value` lines from
  Phases 2-3.
- The bounds:
  - challenger: 3 rounds, in the run;
  - phase fix: 3 rounds, in the implementer, on the phase log;
  - final fix: 3 rounds, on the last phase's log.
- Resume rules: `SendMessage` to the agent ID. If the ID is lost or the result
  does not arrive in this turn, re-dispatch fresh with the same mode and the
  verbatim answers or push-back.
- The rendering rules for `blocked` and `needs decision`:
  - one takeaway line;
  - what is needed;
  - the exact command;
  - phrased per `## Reader`.

### Success Criteria:

#### Automated Verification:

- [ ] The shared automated checks pass.
- [ ] `wc -w plugins/tce/commands/work.md` reports ≤ 2,600 words, which keeps
      the file under the 5,000-token re-attach.
- [ ] The AskUserQuestion block in `work.md` is byte-identical to `research.md`'s:
      extract both (heading through last bullet) and `diff` them — empty.
- [ ] With the variable unset, `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS= BASH_DEFAULT_TIMEOUT_MS= plugins/tce/scripts/work.sh preflight`
      prints `foreground: missing` and `timeout: low (unset)`.
- [ ] `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 BASH_DEFAULT_TIMEOUT_MS=600000 plugins/tce/scripts/work.sh preflight`
      prints two `ok`s and exits 0.
- [ ] `plugins/tce/scripts/work.sh artifact thoughts/shared/plans/2026-10-11-TP-0045a-intent-reader-delivery.md`
      prints `yes`/`yes`/`yes`.
- [ ] In a scratch file, `artifact` prints `committed: no` for an untracked
      path and `exists: no` for a missing one.
- [ ] `grep -n "sufficiency" plugins/tce/commands/work.md` finds nothing.

#### Manual Verification:

- [ ] A dry read of `work.md` plus `work-dispatch.md` against the ticket's
      flow criterion finds every step, in order:
      refuse-without-intent → research → plan questions → asks → planner
      writes → challenger → approval/push-back → implement per phase →
      verifier → gate → dossier → delivery.

---

## Phase 5: `/tce:init` allowlist and profile wording

### Overview

Offer the entries a smooth run needs, as `/tsf:init` does. Update the Delivery
and Reader wording now that `/tce:work` reads them.

### Changes Required:

#### 1. Init

**File**: `plugins/tce/commands/init.md`

**Changes**:

- **A new Phase 4 step** after the files are written: **Allowlist**.
  - Compute the entries (see Decisions).
  - Show the exact entries for `${CLAUDE_PROJECT_DIR}/.claude/settings.json`
    `permissions.allow`.
  - Ask with this verbatim copy:
    - **Intro:** "These permission entries let /tce:work's agents read tce's
      reference files, commit, and run your project's test commands without
      stopping on a prompt. They are appended to .claude/settings.json; nothing
      else in that file changes."
    - **Question:** "Append these entries to .claude/settings.json?" —
      header "Allowlist".
    - **Options:**
      - **Append them (Recommended)** — "Teammates get them once you commit
        the file."
      - **Skip** — "/tce:work will stop on a permission prompt for each of
        these until you allow them."
  - **The surgical edit**, exactly as `tsf/commands/init.md:390-393`:
    create the file with only that key, or append missing entries with no
    duplicates and every other key byte-identical.
  - **Never** `git push` or `gh`.
- **Idempotency:** a new 1.4.0 bullet. Re-offer the allowlist when any entry is
  missing (no profile change is required).
- **Notes:** replace "This command never edits `.claude/settings.json`" with
  the sanctioned exception, worded as tsf's.
- **Lines 138 and 203:** only if they claim tce never touches
  `settings.json`. They refer to tmt's hook cleanup and stay as they are
  unless they contradict.

#### 2. Profile template

**File**: `plugins/tce/templates/tce/profile.md`

**Changes**:

- **`## Delivery` intro:** drop "(until a tce release acts on it, it is a
  recorded agreement only)". State that `/tce:work` ends with the dossier
  printed (Direct), or pushes the branch and opens the pull request with the
  dossier as its body (Pull request).
- **`## Reader` intro:** "`/tce:intent` today" becomes "`/tce:intent` and
  `/tce:work`'s questions, brief and dossier".
- **The options and sub-fields are unchanged.** `refresh.md`'s hand-authored
  list and `init.md`'s dialogs need no edit, because the CLAUDE.md
  span rule is triggered by option or sub-field changes only.

### Success Criteria:

#### Automated Verification:

- [ ] The shared automated checks pass.
- [ ] `grep -n "recorded agreement" plugins/tce/templates/tce/profile.md`
      finds nothing.
- [ ] `grep -n "never edits .claude/settings.json" plugins/tce/commands/init.md`
      finds nothing.
- [ ] The AskUserQuestion block in `init.md` is unchanged:
      `git diff 0321362 -- plugins/tce/commands/init.md` shows no hunk inside
      it.

#### Manual Verification:

- [ ] In a scratch project with an existing `.claude/settings.json` (holding
      unrelated keys), `/tce:init` → "Append them" adds only the missing
      entries, and `git diff` on the file shows nothing else changed.

---

## Phase 6: Repo docs and the 1.4.0 release

### Overview

Record the new mechanism and its same-commit spans in CLAUDE.md. Document the
flow, environment and allowlist in the README. Bump to 1.4.0 and tag.

### Changes Required:

#### 1. CLAUDE.md

**File**: `CLAUDE.md`

**Changes**:

- **Layout:**
  - the agents list gains the five step agents;
  - scripts gain `work.sh`;
  - references gain the four new files.
- **Composite commands must track the single-step commands:**
  - `/tce:work` is now an orchestrator and is removed from the rule; the rule
    keeps `quickfix.md`.
  - A new rule replaces work.md's part, in the same section: until TP-0045c,
    the extracted agents mirror the single-step commands. A change to
    `research.md`/`plan.md`/`implement.md` that affects anything the agents
    mirror updates `researcher.md`/`planner.md`/`implementer.md`+`verifier.md`
    in the same commit, and vice versa.
- **TP-0020 gate span:**
  - `work.md` is replaced by `verifier.md`, which runs the gate.
  - `quickfix.md` still inherits it.
  - The checker is unchanged.
- **TP-0030:** `baseline.sh` is invoked from `implement.md` and `work.md`; the
  rule stays, with the wording updated (`work.md` resolves, the verifier
  diffs).
- **TP-0031:** `work.md` still runs `create`/`switch` and carries the dialog
  copy. The bullet is reworded from "re-describe the research step" to "runs
  the branch step itself".
- **TP-0022 sufficiency:**
  - four copies become **three** (`tickets.md`, `research.md`, `intent.md`);
  - `work.md` refuses without an intent instead.
- **Settings edits:** `/tce:init`'s allowlist append is the third sanctioned
  `settings.json` edit, with the "never widen it" wording.
- **TP-0013:** the consuming list gains the agents. Each re-reads its
  documents in chain order on every dispatch.
- **TP-0017:**
  - `work` stays flagged.
  - The agents carry no classification.
  - The orchestrator dispatches via the Agent tool; agents call `tce:commit`
    via the Skill tool, so `commit` must stay unflagged (already the case).
- **New section "tce: `/tce:work` is an orchestrator (TP-0045b)":**
  - foreground required (`work.sh preflight`);
  - one turn, kept by AskUserQuestion;
  - scripts only in the orchestrator;
  - the three same-commit spans:
    - **return shape** — `agent-returns.md`, the five agents' `## Return`,
      `work.md`, `work-dispatch.md`;
    - **brief/question layout** — `work-brief.md`, `planner.md`, `work.md`;
    - **fix-loop counter** — `plan-document-template.md`, `implementer.md`,
      `verifier.md`, `work-dispatch.md`.
  - The rule that only "exists, non-empty, committed" is checked mechanically,
    never an agent-authored format.
  - The model note: all five agents are deliberately `inherit`, and pins wait
    for real-run data.

#### 2. tce README

**File**: `plugins/tce/README.md`

**Changes**:

- **Intro (line 10) and the Shortcuts row (221):** `/tce:work` runs each step
  in a fresh agent and asks only during planning.
- **A new `## Running /tce:work` section:**
  - the flow;
  - the two exports (`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`,
    `BASH_DEFAULT_TIMEOUT_MS=600000`) and why;
  - the allowlist `/tce:init` offers;
  - resume by re-running;
  - the dossier's location.
- **Agents table:** five new rows.
- **Requirements:** `gh` is also needed for Pull request delivery.
- **Branch convention bullet:** "tce still never pushes" becomes "only
  `/tce:work` under Pull request delivery pushes".
- **Delivery bullet:** drop "acts on it in a later release".
- **Reader bullet:** add `/tce:work`.

#### 3. Root README

**File**: `README.md`

**Changes**: the tce catalog row mentions the orchestrating `/tce:work` (one
clause).

#### 4. Version

**Files**: `plugins/tce/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json`

**Changes**:

- `1.3.0` → `1.4.0` in both.
- After the release commit, run `claude plugin tag ./plugins/tce`.

### Success Criteria:

#### Automated Verification:

- [ ] The shared automated checks pass.
- [ ] `git tag --list 'tce--v*'` includes `tce--v1.4.0` pointing at the
      release commit.
- [ ] `grep -n '"version": "1.4.0"' plugins/tce/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
      matches in both.
- [ ] `grep -n "BASH_DEFAULT_TIMEOUT_MS" plugins/tce/README.md` matches.
- [ ] `grep -n "four copies\|four places" CLAUDE.md` no longer describes the
      sufficiency test as four copies.

#### Manual Verification:

- [ ] **One real ticket in a consuming project runs end to end through the new
      `/tce:work`.** This is the epic's b→c gate.
  - **Setup:**
    - install tce 1.4.0 with `/plugin marketplace update toby-plugins`;
    - export the two variables;
    - run `/tce:init` and accept the allowlist;
    - author an intent with `/tce:intent <ID>`.
  - **Run:** `/tce:work <ID>`.
  - **Pass:**
    - research and plan documents land where `stage.sh` and `ticket.sh` find
      them;
    - the human was asked only during planning (and on `blocked`);
    - the dossier exists and is committed;
    - you did not open a `thoughts/` file to decide anything.
- [ ] Resume check in the same project:
  - **Run:** interrupt a run during implementation (Escape), start a new
    session and re-run `/tce:work <ID>`.
  - **Pass:** it continues at the next phase without re-researching or
    re-planning.
- [ ] Record what the run teaches in TP-0045c's ticket, or as TP-0045d items.

---

## Testing Strategy

### Unit Tests:

- `work.sh` both modes, against env combinations and against
  tracked/untracked/missing paths in a scratch git repo.
- `stage.sh` progress unchanged on an existing plan after the template gains
  `## Decisions` (Phase 1).

### Integration Tests:

- `claude plugin validate` on the marketplace and all four plugins, every
  phase.
- The byte-identity `git diff --quiet` on the six protected commands, every
  phase.

### Manual Testing Steps:

1. **Side-by-side extraction reads:** `research.md`↔`researcher.md`,
   `plan.md`↔`planner.md`, and `implement.md`↔`implementer.md`+`verifier.md`
   (Phases 2-3).
2. **The real end-to-end run and the resume check** (Phase 6). These need a
   consuming project, Claude Code restarted with the exports, and your
   judgment on the questions and the brief. That is why they can't run in this
   session.

## Performance Considerations

- **The orchestrator's context stays small:**
  - returns are bounded (25-line block, 60-line brief);
  - artifacts are never inlined;
  - `work.md` stays under the re-attach budget, with point-of-use references.

  This is the TP-0038 lesson.
- **Token cost per run rises.** It is one agent per step, plus the fan-out,
  challenger and verifier. This was accepted in the discussion; pins and
  ceremony scaling are TP-0045d/TP-0045c.

## Migration Notes

- **The old inline `/tce:work` is replaced in place.** Reverting means
  `git revert` of the TP-0045b commits; the single-step commands are untouched.
- **Projects on tce ≤1.3.0 need no profile change.** A missing `## Delivery`
  means Direct. A missing allowlist only means permission prompts, and
  `/tce:init`'s 1.4.0 Idempotency bullet re-offers it.
- **Plans written before 1.4.0 have no `## Decisions` section.** The dossier
  counts 0 decisions made for you for them; no failure.

## References

- Original ticket: `thoughts/shared/tickets/TP-0045b-step-agents-orchestrating-work.md`
- Epic: `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md`
- Related research: `thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md`
- Design discussion: `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md`
- Precedents:
  - `plugins/tsf/commands/cycle.md` (dispatch, retry);
  - `plugins/tsf/agents/plan.md` (envelope, filled-in return);
  - `plugins/tsf/commands/init.md:352-393` (allowlist);
  - `plugins/tsf/references/templates/dossier.md`;
  - `plugins/tle/agents/loop-verifier.md:49-56` (browser).
