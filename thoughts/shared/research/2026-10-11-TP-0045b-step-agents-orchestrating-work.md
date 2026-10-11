---
date: 2026-10-11T18:27:27Z
git_commit: 406aede651acb3bb255d4c711ac4bc6f6e8b7e19
branch: main
repository: tobyS/toby-plugins
topic: "TP-0045b: the step agents and the orchestrating /tce:work (stage 1)"
tags: [research, tce, work, agents, orchestrator, research-md, plan-md, implement-md, plan-compliance-checker, stage-sh, tsf-lessons, subagents]
status: complete
last_updated: 2026-10-11
---

# Research: TP-0045b — the step agents and the orchestrating `/tce:work` (stage 1)

**Date**: 2026-10-11T18:27:27Z
**Git Commit**: 406aede651acb3bb255d4c711ac4bc6f6e8b7e19
**Branch**: main
**Repository**: tobyS/toby-plugins

Permalinks below point at `406aede` on `github.com/tobyS/toby-plugins`. At the
time of writing `main` is 23 commits ahead of `origin/main`, so they resolve
once `main` is pushed.

## Research Question

What does TP-0045b have to extract, and from where? Specifically:

- the working of `/tce:research`, `/tce:plan` and `/tce:implement` that the new
  agents must keep: steps, dialog sites, templates, scripts and the plan log;
- what today's `/tce:work` does and what the rewrite replaces;
- which tsf/tle patterns exist for agent return shapes, dispatch, dossier,
  pull-request text and the `/tsf:init` allowlist append;
- what TP-0045a delivered for this ticket to consume;
- the platform facts that decide dispatch mode, resume, permissions, model
  pins and the compaction budget.

The ticket is sufficient: scope, outcome and anchors are all explicit. There is
no intent for TP-0045b (`ticket.sh TP-0045` finds none, and
`thoughts/shared/intents/` does not exist in this repo yet). Parent context
comes from the epic `TP-0045` and the design discussion
`thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md`, which
is untracked in the working tree at this commit.

## Summary

- **Three step commands, about 20 user-interaction sites between them.**
  - `research.md` asks in 3 places: the branch stop-and-ask dialog, the
    sufficiency round, and "follow-up questions?".
  - `plan.md` has 15 sites. 11 of them actually ask, and only one is a
    structured `AskUserQuestion` (the open-questions round). The rest are
    prose approval gates: phase outline approval, UI approach, the
    design-option pick, and "iterate until satisfied".
  - `implement.md` has about 10 prose asks: mismatch STOP, gate "not met"
    STOP, manual verification, design-exploration offer, and the merge
    reference.
  - `/tce:commit`, which all three delegate to, adds a branch-check ask.
- **The plan template has no `## Decisions` section today.**
  - Decisions surface only in `plan.md`'s Step 5 chat summary, as
    `[Decision] — over [rejected alternative]: [why]`.
  - The intent template uses the same line shape
    (`**[decision]** — over [rejected alternative]: [why]`).
  - Three existing plans added a `## Decisions` section by hand.
- **The plan log already exists and `stage.sh` already reads it.**
  - Each phase ends with a `### Implementation log` block (Status, Base commit
    on the first phase, Commit, Did, Issues, Verification).
  - `stage.sh` derives `progress: done/total` from the `Status:` lines (✅ or
    `Complete`), ignores checkboxes, and now prints a sixth `intent:` line.
  - Nothing in the log carries a fix-loop counter.
  - `implement.md`'s gate loop "fix → re-verify → re-run gate" has **no bound**
    (`implement.md:312-316`).
- **The compliance checker is shell-less by design.**
  - It has `Read, Grep, Glob, LS` and `model: inherit`, and returns one
    verdict per criterion: met / not met / cannot verify from diff / needs
    human verification.
  - TP-0032 documents the effect: 7 of 7 items escalated with zero attempts,
    6 of which were doable in-session. The ticket puts the fix in the
    consumer, never by giving the checker a shell.
- **tce has no test-output redirection or timeout handling today.** tsf has
  both: `preflight.sh` checks `BASH_DEFAULT_TIMEOUT_MS ≥ 600000` and
  `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, and its workers and dispatcher
  redirect verify output to a file.
- **Platform facts (live docs, 2026-10-11) refine the discussion's table:**
  - **Background by default.** In an interactive session subagents run in the
    background and Claude cannot ask for the foreground. Only
    `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` forces the foreground.
  - **Background agents may not be able to spawn agents.** They get a reduced
    set of built-in tools, and the documented list does **not** include
    `Agent`. This is in tension with the discussion's nesting spike, and it
    matters for the research agent's fan-out.
  - **Resume runs in the background.** `SendMessage` resumes a finished agent
    in the background. Subagent transcripts survive main-conversation
    compaction. Recovering a lost agent ID is undocumented beyond the
    transcript path.
  - **A command's `allowed-tools` lasts one turn.** The grant clears with the
    user's next message, and whether it reaches the command's subagents is
    undocumented. tsf verified that it does not.
  - **`CLAUDE_CODE_SUBAGENT_MODEL` no longer outranks agent frontmatter**
    (since v2.1.251).
- **Today's `/tce:work`:**
  - 295 lines, about 3.7–4k tokens, flagged `disable-model-invocation: true`.
  - It re-describes research, plan and implement inline, including the
    six-agent fan-out list and the gate. It delegates only `/tce:commit` and
    the checker.
  - Its allowed-tools do not include `stage.sh`.
  - `quickfix.md` has no textual dependency on `work.md`. They share copies:
    the AskUserQuestion block, the branch dialog and the drift wording.
- **tsf supplies precedents for most of what TP-0045b needs:**
  - filled-in return skeletons (TP-0039);
  - the `CRITICAL` / `What NOT to Do` / `REMEMBER` envelope;
  - foreground dispatch with path-only payloads and point-of-use reference
    reads;
  - the "show the shape" retry note (TP-0043);
  - the dossier, pr-body and question-comment templates;
  - the `/tsf:init` allowlist append.
  - tle supplies one-line returns and the only agent prompt that names the
    chrome-devtools browser tools.

## Detailed Findings

### 1. `/tce:research`: the working to extract

File: `plugins/tce/commands/research.md` (384 lines).

**Frontmatter (1-5)**
- `allowed-tools` grants only `ticket.sh` and `branch.sh`.
- There is no `model:` and no `disable-model-invocation`, because research is a
  delegation target.

**Step order**
- **Ticket discovery (88-137)**
  - Canonical ID (92).
  - Full ticket read, plus a full intent read when discovery returns one; the
    intent "takes precedence over the ticket's wording" (93).
  - Branch `create` and the verbatim stop-and-ask dialog (94-130).
  - `ticket.sh` (131-137).
- **Parent/epic context (139-149).**
- **Sufficiency check (151-174).** Skipped when an intent exists (153-155).
- **Read mentioned files (199-202). Decompose plus TodoWrite (204-213).**
- **Fan-out (215-265)**
  - `codebase-locator`, `codebase-analyzer`, `codebase-pattern-finder`,
    `thoughts-locator`, `thoughts-analyzer`.
  - `web-search-researcher` is **required** when third-party code is involved
    (236-256: "Do NOT wait for the user to ask").
  - Sub-agents are told they are documentarians (68).
- **Synthesis (269-275).** Live codebase research is the primary source.
- **Config-drift check (276-286).** High-confidence only, read-only.
- **Metadata (288-303). Template read at the point of use (307). Permalinks
  (311-317).**
- **Present (319-331). Commit via `/tce:commit` (333-336). Follow-up appends
  (338-345).**
- **Reuse/extension impact analysis (347-384).** It uses the template's second
  part.

**User-interaction sites**
- Branch dialog: `fetch-failed` / `no-remote` lead to `AskUserQuestion`
  (115-130), and `dirty` leads to a prose ask (109).
- The sufficiency round (170-174).
- "Ask if they have follow-up questions" (323).
- The no-argument prompt (187-195).
- `/tce:commit`'s branch check (`commit.md:60-71`).

**Template** (`plugins/tce/references/research-document-template.md`)
- Frontmatter fields: `date`, `git_commit`, `branch`, `repository`, `topic`,
  `tags`, `status`, `last_updated`.
- Conditional sections: Defect Mechanism, UI Patterns, tce Config Drift, and
  the Impact Analysis template.
- `research.md:256` names an "External Sources" section that the template
  does not contain.

**Documentarian envelope**
- The `## CRITICAL: YOUR ONLY JOB IS TO DOCUMENT…` block (59-68).
- Two sanctioned exceptions: the defect mechanism (72-80) and the config-drift
  advisory (81-86).

### 2. `/tce:plan`: the working to extract

File: `plugins/tce/commands/plan.md` (457 lines).

**Frontmatter (1-5)**
- `allowed-tools` grants `ticket.sh` and `branch.sh`.
- Unflagged, no model.

**Step order**
- **Re-read** in chain order, ticket → intent → research (60-65). The intent
  is mentioned only as a parenthetical (65).
- **Branch `switch` (66-78). `ticket.sh` (79-85). Parent context (87-98).**
- **Research integration (100-120)**
  - No agents, no re-reading of source the research covers (106).
  - Agents are allowed only in listed cases (110-116).
- **Open questions (122-150)**
  - "Open questions must be DISCUSSED, not assumed" (124).
  - One `AskUserQuestion` call; "never pick an option yourself" (141).
  - Later questions mean STOP and ask again (143-146).
- **Context gathering (181-256).** Items 3-4 spawn agents only when no research
  exists. An understanding/questions template is at 232-252.
- **Design-exploration check (258-286)**
  - `DECISION.md` grep under `thoughts/shared/mockups/` (266-272).
  - Offer `/tce:design_explore` (276-282).
  - Stop if the user wants exploration (284), otherwise note "no design
    exploration" (286).
- **Step 2, research and discovery (288-355).** Only without research. Design
  options plus "Which approach…?" (337-355).
- **Step 3, structure (357-395)**
  - Template read (361).
  - Phase outline plus "Does this phasing make sense?" (363-382).
  - "Make autonomous UI decisions with clear rationale" (391), then feedback
    on the UI approach (395).
- **Step 4, write (397-410).** "After structure approval" (399). Filename
  pattern (401-409). Template re-read and the Automated/Manual split (410).
- **Step 5, review and commit (412-457)**
  - The summary is "the human review surface", which "must surface everything
    the human might want to veto — the choices made on their behalf" (416-419).
  - **Decisions made**: `[Decision] — over [rejected alternative]: [one-line
    why]` (426).
  - Riskiest assumptions, out of scope, and phases (429-437).
  - Iterate "until the user is satisfied" (443-450).
  - Commit (452-455). "Your job ends here" (457).

**Interaction count:** 15 sites. 4 of them are notices or stops, and 11 ask.
Only the open-questions round is an `AskUserQuestion`; every other site waits
for free text.

**Template** (`plugins/tce/references/plan-document-template.md`)
- No YAML frontmatter.
- Sections, in order: Title, Overview, Current State Analysis, Desired End
  State (+ Key Discoveries), What We're NOT Doing, Implementation Approach,
  `## Phase N`, Testing Strategy, Performance Considerations, Migration Notes,
  References.
- Each phase has Overview, Changes Required (File / Changes / code), and
  Success Criteria with `#### Automated Verification:` and
  `#### Manual Verification:` (55-94).
- Automated means "run by execution agents". Manual includes "User acceptance
  criteria" (130-166).
- Implementation-time additions are owned by `implement.md` (168-178).
- The UI/UX section is conditional (208-233).
- **There is no `## Decisions` section.** Hand-added precedents:
  - `thoughts/shared/plans/2026-06-14-TP-0004-profile-drift-refresh.md:27`
  - `thoughts/shared/plans/2026-06-15-TP-0008-configurable-commit-convention.md:22`
  - `thoughts/shared/plans/2026-10-11-TP-0045a-intent-reader-delivery.md:127`

**Other gaps**
- **Tests:** no rule requires tests in every phase. There is only "incremental,
  testable phases" (379) and the template's example checkboxes.
- **Intent:** `plan.md` gives no instruction to carry the intent's decisions or
  acceptance criteria into the plan. The open-question sources (128-133) list
  only the ticket and the research.
- **Vocabulary:** "brief" and "challenger" do not appear.

### 3. `/tce:implement`, the gate, and `baseline.sh`

File: `plugins/tce/commands/implement.md` (383 lines).

**Frontmatter (1-5)**
- `allowed-tools` grants `ticket.sh`, `baseline.sh`, `branch.sh`, `git diff`,
  `git log` and `git rev-parse`.
- Unflagged, no model.

**Step order**
- **Discovery and branch `switch` (40-65).**
- **State check with `baseline.sh` (71).** Uses the research document's
  `git_commit`, with a fast path for the same session.
- **Ordered re-read (73-84).** Ticket → intent (2b) → research → plan.
- **Implementation log rules 1-8 (142-149)**
  - Fully done: stop.
  - Partial: resume from the first incomplete phase.
  - Legacy `.status.md`: read-only.
  - A fresh run records `**Base commit**` = `git rev-parse HEAD`.
  - The log is updated after every phase. A blocked phase is marked
    `❌ Blocked`.
  - Manual items are ticked only on human confirmation.
- **Log shape (107, 111-123).** Appended after `### Success Criteria:`, at
  most 8 lines:
  ```
  ### Implementation log
  - **Status**: ✅ Complete | ⚠️ Partial | ❌ Blocked
  - **Base commit**: `<hash>` (first phase only)
  - **Commit**: `abc1234` <subject>
  - **Did**: …
  - **Issues**: …
  - **Verification**: …
  ```
- **Design-exploration check (168-189).**
- **Phase loop (191-228)**
  - Mismatch STOP block (207-214).
  - Per-phase checks come from the profile (220-221).
  - Tick Automated items, update the log, commit (222-228).
- **Commits (230-241).** One per verified phase via `/tce:commit`. It runs the
  profile's tests, typecheck and lint again (237). The hash goes on the log.
- **Final verification (243-261).**
- **Plan-Compliance Gate (263-329)**
  - Criteria: the ticket's acceptance criteria plus every phase's Automated
    and Manual items, verbatim, with MANUAL marked (271-276).
  - Diff: `baseline.sh <base> <plan>`, then `git diff <baseline> -- .
    ':(exclude)thoughts/'` plus `--stat` (278-298). With no baseline, the gate
    cannot run and that blocks.
  - Dispatch: criteria and diff only (300-303).
  - **"not met"** loops until clear, **unbounded** (312-316).
  - **"cannot verify"** is investigated, or reclassified manual (317-319).
  - **"needs human verification"** becomes a prose ask, with deferral recorded
    in the Closeout (320-329).
- **Closeout (125-138).** Gate, Manual verification, Merge reference (asked
  for if unknown), Ticket.
- **Status transitions (331-348).** Start sets In Progress at the first phase.
  Done requires the gate plus manual confirmation, then the Closeout.

**`plan-compliance-checker.md`**
- Frontmatter: `tools: Read, Grep, Glob, LS`, `model: inherit`.
- Inputs (14-18). May read post-change source, never `thoughts/` (20-26).
- Verdicts (37-47). The tie-break is "cannot verify" (79).
- Return: `## Plan-Compliance Verdict` + `**Overall:**` + a
  `| # | Criterion | Verdict | Evidence |` table (57-71).
- Envelope sections (28-35, 81-90, 92-99).

**`baseline.sh`**
- Usage: `baseline.sh <recorded-sha> [<document-path>]`.
- Three-line stdout: `baseline:` / `source: recorded | introducing | none` /
  `detail:`. Exits 0 on every reported outcome.
- Uses a reachability probe with `merge-base --is-ancestor`, and falls back to
  the commit that introduced the document.

**`implement_eco.md`**
- Has `model: sonnet` and `disable-model-invocation: true`. It only
  Skill-invokes `tce:implement`.
- Not listed in CLAUDE.md's TP-0017 classification, as TP-0045a's research
  noted.

**Timeouts:** tce has no test-output redirection and no timeout handling.

### 4. Today's `/tce:work`, and what sits around it

**`plugins/tce/commands/work.md`** (295 lines, about 2,700-3,000 words)
- **Frontmatter (1-6)**
  - `disable-model-invocation: true`.
  - `allowed-tools`: `ticket.sh`, `baseline.sh`, `branch.sh`, `git diff`,
    `git rev-parse`. No `stage.sh`, no `Agent`.
- **Overview (50-61):** "at most TWO interaction points".
- **Phase 1 (65-125)**
  - 1a (69-103): intent read (73), branch dialog copy (84-99), sufficiency
    check skipped with an intent (102).
  - 1b (105-119): re-describes research and names the six agents (110).
  - 1c: commit the research.
- **Phase 2 (129-207):** the question checkpoint.
  - Open-question sources: ticket and research (137-141).
  - Design-exploration check (143-154).
  - The ask, with the verbatim design_explore question (184-193).
- **Phase 3 (211-241):** planning without outline approval (229).
- **Phase 4 (245-284):** implementation.
  - 4a log state and Base commit (249-256). 4b phases (258-267). 4c mismatch
    (269-275).
  - 4d: final verification and the inline gate (283, about 260 words), then
    the closeout (284).
- **No final-summary phase.**
- The TP-0045a additions are minimal: the intent read at 73, 219 and 251, and
  the sufficiency skip at 102.

**`quickfix.md`**
- Its only references to `/tce:work` are user-facing redirects (20, 108).
- Shared copies with `work.md`: the AskUserQuestion block (26-44), the branch
  dialog (150-162) and the drift wording (170).
- It Skill-invokes `tce:ticket --autonomous`, `tce:plan` and `tce:implement`
  (110, 190, 214).

**`stage.sh`** (`plugins/tce/scripts/stage.sh`)
- Usage: `stage.sh <id> [<id> …]`.
- Record shape: six lines, with a blank line between records.
  ```
  ticket:   TP-0045a
  research: thoughts/shared/research/…
  plan:     thoughts/shared/plans/…
  progress: 3/4
  source:   log
  intent:   thoughts/shared/intents/…
  ```
- Matching is by delimited ID segment, and the newest match wins (81-104).
- `plan_progress` (108-167):
  - strips fenced blocks first;
  - counts `Phase N` headings, excluding letter-suffixed ones;
  - counts the `Status:` line of each `### Implementation log` as done when it
    starts with ✅ or `Complete`.
- `source:` is one of `log | sidecar | unknown | no-plan` (260-287).

**`ticket.sh`**
- Runs `find thoughts -type f -name "*<id>*" | sort`: substring match,
  absolute paths.

**`branch.sh`**
- Modes and results:
  - `create`: `created | switched | already | fetch-failed | no-remote |
    missing-base | dirty | blocked | invalid-name`
  - `switch`: `switched | already | missing | dirty | blocked`
  - `check`: `on-branch | on-base | elsewhere | detached`
- Three-line stdout, exit 0.

**`init.md`**
- No `allowed-tools`. It **never edits `.claude/settings.json`**; this is
  stated at 138-139, 203-204 and in the Notes at 630-632.
- **Idempotency list (590-615).** The 1.3.0 bullet (607-615) adds Delivery and
  Reader and creates `thoughts/shared/intents/.gitkeep`.
- **Delivery dialog (343-365).** Under Current branch it fills Direct silently.
- **Reader prose prompt (367-383).**
- Version marker (432-434, 579-588).

**`templates/tce/profile.md`**
- `## Delivery` (99-116):
  - Direct is the default.
  - Pull request requires Branch per ticket: "tce pushes the ticket branch and
    opens a pull request…; **you** review and merge it — tce never merges;
    the next ticket starts only after the previous ticket's pull request is
    merged". The intro still says "until a tce release acts on it, it is a
    recorded agreement only".
- `## Reader` (118-132): Not described is the default; Described takes free
  prose. "`/tce:intent` today" is its only named reader.

**Versions and README**
- tce is `1.3.0` in `plugin.json:3` and `marketplace.json:15`.
- **README** (`plugins/tce/README.md`, 315 lines):
  - `/tce:work` appears at 10-12 and 221 (the Shortcuts row, "one
    open-questions checkpoint") and at 296-297 (Delivery "acts on it in a
    later release").
  - There is no section on permissions, allowlists or environment variables.
    `## Requirements` (119-132) lists only git, a ticket system and gh.

**`hooks.json`:** a single SessionStart → `check-init.sh` entry, in exec form.

### 5. tsf/tle precedents for agents, dispatch and templates

**Agent frontmatter**

| Plugin | Tools | Model pins |
|---|---|---|
| tsf workers | `Read, Write, Edit, Grep, Glob, Bash`, no `Agent` | triage, research, implement, verify-fix, manual-verify: `sonnet`; plan, dossier, merge-resolver: `opus` |
| tsf gates | `Read, Grep, Glob` | plan-compliance, spec-coverage: `sonnet`; security, integration: `opus` |
| tle | deny-lists (`disallowedTools: AskUserQuestion, Task, …`) | spec-planner: `opus`; implementer, verifier: `sonnet`; goal-critic: `inherit` |
| tce | read-only `tools:` lists | locators: `haiku`; others: `inherit` |

**Description conventions**
- tsf: "Internal to `/tsf:cycle` — not for direct use … Returns a result
  block."
- tle: "Returns one line."

**Return shapes**
- **tsf: three fences**, `tsf-result` / `tsf-comment` / `tsf-journal`, with
  no angle brackets or nested fences
  (`plugins/tsf/references/templates/result-block.md:31-56`).
  - The outcome table (87-113) has no wildcard row.
  - Parsing rules (165-189) include a single retry note that names the
    template **and** the agent's own `## Return`.
  - Each worker carries a filled-in copy with its own legal values, e.g.
    `plugins/tsf/agents/plan.md:99-139`.
- **tle: one line, with the artifact written to disk**
  (`loop-verifier.md:102-110`, `loop-implementer.md:55-69`,
  `loop-spec-planner.md:77-85`).
  - `run.md` Step 5 has a "MANDATORY OUTPUT … must exist on disk" check (108),
    the precedent for "exists, non-empty, committed".

**Envelope**
- tsf workers: `## CRITICAL` right after the intro, then `## What NOT to Do`
  and `## REMEMBER` at the end (e.g. `plugins/tsf/agents/plan.md:19-28`, 141,
  152-157).
- The planner's CRITICAL includes "DO NOT ask the user anything — questions
  go into the plan and its summary" and "DO NOT spawn other agents".

**Dispatch**
- **`/tsf:cycle`**
  - Invariant 2 is foreground-only, enforced by the preflight
    (`cycle.md:21-23`).
  - Invariant 3: content travels by path (24-37).
  - "Use the **tsf:<agent>** agent (foreground), passing exactly the payload
    `cycle-dispatch.md` defines" (208-243).
  - The gates are dispatched together in one message.
  - References are read "now — in full" at the point of use (192, 297, 304).
  - The payload template is at `cycle-dispatch.md:554-605`.
  - `Agent` is **not** in `/tsf:cycle`'s `allowed-tools` (4), and `/tle:run`
    has no `allowed-tools` at all. Both dispatch in prose.
- **`/tle:run`**
  - Invariants (10-17): one iteration per turn, never carry document
    contents, foreground, one agent at a time.
  - Each step reads "passing exactly: … Wait for the agent to complete"
    (95-160).
- **Retry that shows the shape (TP-0043)** (`cycle.md:250-290`). The plan
  check gets two re-dispatches, all others one.

**Templates** (`plugins/tsf/references/templates/`)

| Template | Generic parts | Factory-specific parts |
|---|---|---|
| `dossier.md` | Summary with Impact 1-5 and an optional **Start here** permalink, What was built, Where to look, Open items, the rule "never claim a verification that did not run" | GH-n paths, the comment's `created_at` role, landing-refusal causes, the native-review closing line, the no-angle-brackets rule |
| `pr-body.md` | Title on line 1, empty line 2, body from line 3; What this does, Decisions (with rejected alternatives), Artifacts | `Closes #`, the `gh-write.sh` coupling, the journal link, `--ref` re-pointing |
| `question-comment.md` | Questions batched, numbered and self-contained; a plan summary of Informed understanding / Key findings / Decisions / Irregular / Questions, never the increment list | `tsf ·` heading, responder logins, the reply mechanics |
| `report.md` | Verdict vocabulary; evidence uses post-change line numbers, never patch offsets (163-178) | `head:` / `verdict:` machine lines, episode/round naming |

**`/tsf:init` allowlist append** (`plugins/tsf/commands/init.md:352-393`)
- Entries:
  - each contract script;
  - `git add/commit/diff/log/show/status/rev-parse/branch`;
  - `Edit(thoughts/factory/**)`;
  - the profile's build/test/lint commands as `Bash(<command>:*)`;
  - `Read(~/.claude/plugins/**)`.
- **Never** `git push` or `gh` (368).
- Verbatim intro (376-380). An `AskUserQuestion` "Append these entries to
  .claude/settings.json?" with header "Allowlist" and options **Append them
  (Recommended)** / **Skip** (382-388).
- Surgical edit (390-393): create the file with just the
  `permissions.allow` key, or append missing entries with no duplicates and
  every other key byte-identical.
- Re-offered on re-run (478-482).

**Timeouts and redirects in tsf**
- `preflight.sh`: `BASH_TIMEOUT_FLOOR=600000` (71), checks at 125-150.
- The rule "run with the Bash tool's maximum timeout, output redirected to a
  file … a failing command returns only a truncated excerpt" appears in
  `cycle.md:177-183`, `cycle-dispatch.md:241-244`,
  `agents/implement.md:84-90`, `verify-fix.md:51-55` and
  `manual-verify.md:58-60`.
- README 86-143 explains it.

**Browser**
- The only agent prompt that names it is `plugins/tle/agents/loop-verifier.md:49-56`:
  `mcp__chrome-devtools__*` "if available … otherwise emit `cannot-verify`;
  never substitute a weaker check".
- tle's README (52-58) treats chrome-devtools-mcp as a documented dependency
  that agents inherit.
- tsf `manual-verify.md:53-57` lists attempt kinds (an existing command, a
  throwaway script, a request against the env, an MCP server) and says
  "Reading the code is **not** an attempt".
- tce `design_explore.md:67-69` detects browser capability at runtime.

### 6. Platform facts (live docs, fetched 2026-10-11)

**Dispatch mode** ([sub-agents](https://code.claude.com/docs/en/sub-agents),
[env-vars](https://code.claude.com/docs/en/env-vars))
- In interactive sessions fork mode is on. Subagents, forks or not, run in the
  **background**, and the Agent tool's `run_in_background` parameter is
  removed.
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` forces the foreground everywhere.
  It also disables Bash `run_in_background`, auto-backgrounding and Ctrl+B.
- `CLAUDE_CODE_FORK_SUBAGENT=0` turns fork mode off, after which Claude uses
  the foreground "when it needs the result". That is Claude's choice, not a
  guarantee.
- Background results arrive as a completion notification in a later turn.

**Background agents' built-in tools**
- Read, Grep, Glob, LSP, Bash, PowerShell, Edit, Write, NotebookEdit,
  WebFetch, WebSearch, TodoWrite, Skill, ToolSearch, Enter/ExitWorktree,
  Monitor, TaskStop, SendMessage, Artifact, plus all MCP tools.
- **`Agent` is not in this list.** Forks and resumed foreground agents are
  exceptions.
- The discussion's spike (main → general-purpose → general-purpose →
  Explore) worked on 2.1.290. The docs do not say which mode that spike
  dispatched in.

**Resume**
- `SendMessage` to an agent ID resumes it with full history, **in the
  background**.
- Explore and Plan are one-shot and return no ID.
- Subagent transcripts live in separate files, are unaffected by main
  compaction, and are kept at
  `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`.
- Recovering a lost ID is undocumented beyond that path.

**Nesting**
- Up to three layers (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, default 3 since
  v2.1.219).
- At most 20 concurrent subagents.

**Plugin agent frontmatter**
- `tools` / `disallowedTools` / `model` are honoured. `hooks`, `mcpServers` and
  `permissionMode` are ignored.
- With `tools` omitted, or only `disallowedTools` set, MCP tools such as
  chrome-devtools are inherited.
- An explicit `tools` list excludes MCP tools unless they are named, e.g.
  `mcp__<server>__*`.
- `AskUserQuestion` is removed even when listed.

**Permissions** ([skills](https://code.claude.com/docs/en/skills),
[tools-reference](https://code.claude.com/docs/en/tools-reference))
- Subagents inherit the session's rules and mode.
- A skill's `allowed-tools` is a grant "during the turn that invokes the skill
  … The grant clears when you send your next message".
- Whether it reaches dispatched subagents is undocumented. tsf verified on a
  real dispatch that it does not (CLAUDE.md, the `/tsf:init` allowlist
  section).
- Prompts from background subagents surface in the main session.

**Compaction**
- After compaction the most recent invocation of each skill is re-attached,
  first 5,000 tokens each, 25,000 tokens combined, newest first.
- The skill file is not re-read later.

**Bash timeouts**
- `BASH_DEFAULT_TIMEOUT_MS` defaults to 120000 and `BASH_MAX_TIMEOUT_MS` to
  600000. The effective ceiling is the larger of the two.
- At the timeout a foreground command is moved to the background. With
  `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` it is **stopped**.
- Commands a foreground subagent started stop when that subagent ends.

**Model precedence (current)**
1. The model passed on the Agent call.
2. The agent's `model:` frontmatter.
3. `CLAUDE_CODE_SUBAGENT_MODEL`.
4. The main model.

Before v2.1.251 the environment variable outranked frontmatter. Forcing that
now needs `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+).

## Code References

Permalink base: `https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/`

**tce commands**
- [`plugins/tce/commands/work.md:1-6`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/work.md#L1-L6): frontmatter (flagged, allowed-tools)
- [`plugins/tce/commands/work.md:283`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/work.md#L283): the inline gate re-description
- [`plugins/tce/commands/research.md:215-265`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/research.md#L215-L265): the agent fan-out
- [`plugins/tce/commands/research.md:276-286`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/research.md#L276-L286): the config-drift check
- [`plugins/tce/commands/plan.md:122-150`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/plan.md#L122-L150): open questions, the only AskUserQuestion site
- [`plugins/tce/commands/plan.md:412-457`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/plan.md#L412-L457): decision-centred summary and iterate loop
- [`plugins/tce/commands/implement.md:107-149`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/implement.md#L107-L149): implementation log shape and rules
- [`plugins/tce/commands/implement.md:263-329`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/implement.md#L263-L329): Plan-Compliance Gate (unbounded loop at 312-316)
- [`plugins/tce/commands/init.md:590-615`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/init.md#L590-L615): Idempotency upgrade list
- [`plugins/tce/commands/init.md:630-632`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/commands/init.md#L630-L632): "never edits `.claude/settings.json`"

**tce agents, references and scripts**
- [`plugins/tce/agents/plan-compliance-checker.md:1-99`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/agents/plan-compliance-checker.md): the gate agent
- [`plugins/tce/references/plan-document-template.md:26-178`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/references/plan-document-template.md#L26-L178): plan template (no `## Decisions`)
- [`plugins/tce/references/intent-document-template.md`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/references/intent-document-template.md): intent sections incl. Decisions line shape
- [`plugins/tce/scripts/stage.sh:108-167`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/scripts/stage.sh#L108-L167): `plan_progress`
- [`plugins/tce/scripts/stage.sh:289-294`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/scripts/stage.sh#L289-L294): the six-line record
- [`plugins/tce/scripts/baseline.sh`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/scripts/baseline.sh): baseline resolution
- [`plugins/tce/templates/tce/profile.md:99-132`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tce/templates/tce/profile.md#L99-L132): Delivery and Reader sections

**tsf references, agents and commands**
- [`plugins/tsf/references/templates/result-block.md:14-189`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/references/templates/result-block.md#L14-L189): return contract, outcome table, parsing, retry
- [`plugins/tsf/agents/plan.md:19-28`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/agents/plan.md#L19-L28), [`:99-139`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/agents/plan.md#L99-L139): CRITICAL envelope and filled-in return
- [`plugins/tsf/commands/cycle.md:21-37`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/commands/cycle.md#L21-L37), [`:208-290`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/commands/cycle.md#L208-L290): foreground and by-path invariants, dispatch, show-the-shape retry
- [`plugins/tsf/commands/init.md:352-393`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/commands/init.md#L352-L393): allowlist append
- [`plugins/tsf/scripts/preflight.sh:14-150`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/scripts/preflight.sh#L14-L150): foreground and timeout checks
- [`plugins/tsf/references/templates/dossier.md:72-112`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/references/templates/dossier.md#L72-L112), [`pr-body.md:26-80`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/references/templates/pr-body.md#L26-L80), [`question-comment.md:20-82`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tsf/references/templates/question-comment.md#L20-L82): templates to port

**tle**
- [`plugins/tle/commands/run.md:10-17`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tle/commands/run.md#L10-L17), [`:95-160`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tle/commands/run.md#L95-L160): orchestrator invariants, path-only dispatch, mandatory-output check
- [`plugins/tle/agents/loop-verifier.md:49-56`](https://github.com/tobyS/toby-plugins/blob/406aede651acb3bb255d4c711ac4bc6f6e8b7e19/plugins/tle/agents/loop-verifier.md#L49-L56): browser tools if available, `cannot-verify` otherwise

## Architecture Documentation

### Patterns

**The step-command shape** (research, plan, implement)
- Each command runs these in order:
  1. project context (profile + tickets);
  2. the duplicated AskUserQuestion guidelines block (research and plan;
     implement has none);
  3. ticket discovery with an unconditional full re-read in chain order;
  4. the branch step (create for research, switch for plan and implement);
  5. `ticket.sh`;
  6. the work;
  7. the template read at the point of use;
  8. a commit via `/tce:commit`;
  9. "Next command:".
- All interaction happens inline in the main conversation.

**Script contracts**
- `branch.sh`, `baseline.sh` and `stage.sh` print fixed `key: value` lines and
  exit 0 for every reported outcome.
- Commands read the `result:` / `source:` lines.
- `stage.sh` receives IDs as arguments and never reads tce config.

**Progress on disk**
- The per-phase `### Implementation log` is the single progress record.
- `stage.sh` derives `done/total` from it and ignores checkboxes.
- A Manual item is ticked only on human confirmation.

**The gate's isolation (TP-0020)**
- The checker receives only criteria and the diff, has no shell, and may not
  read `thoughts/`.
- The diff is computed by the command, with the baseline from `baseline.sh`.

**Two orchestrator precedents in the repo**
- `/tsf:cycle`: one step per cycle, foreground enforced by preflight, a
  three-fence result block, references read at the point of use.
- `/tle:run`: one iteration per turn, foreground, a one-line return, the
  artifact on disk with a mandatory-output check.
- Both dispatch agents in prose ("Use the X agent (foreground)"). Neither
  lists `Agent` in `allowed-tools`.

### Repo rules that span TP-0045b's surfaces (CLAUDE.md)

- **Composite-tracking.** `work.md` re-describes the steps today. The ticket's
  last criterion rewrites this rule for an orchestrating `work.md`.
- **TP-0020 gate span:** `plan-compliance-checker.md`, `implement.md`,
  `work.md`, `quickfix.md`. The ticket requires implement and quickfix to
  stay byte-identical.
- **TP-0030:** `baseline.sh`, `implement.md` and `work.md` change together.
- **TP-0031 branch span:** `work.md` carries the research step's branch
  dialog copy.
- **TP-0013:** every consuming command re-reads ticket → intent → research →
  plan in full.
- **TP-0017:** `work` is in the user-only (flagged) set, and nothing
  delegates into it today.
- **TP-0029:** pins as policy. Its statement "`CLAUDE_CODE_SUBAGENT_MODEL`
  outranks frontmatter" differs from the current docs (§6).
- **The AskUserQuestion block is byte-identical across thirteen files, one of
  them `work.md`.**
- **The four-copy sufficiency test (TP-0022).** One copy is `work.md` Phase 1a
  step 5.
- **TP-0003:** a version that changes required project config extends
  `init.md`'s Idempotency list.

## Impact Analysis

### Existing Usages Found
- **`plugins/tce/agents/plan-compliance-checker.md`**: dispatched by
  `implement.md:300-303` and `work.md:283`, and by quickfix through
  `tce:implement`.
- **`plugins/tce/scripts/stage.sh`**: parsed by `plugins/tce/commands/list.md`
  (six-line record, `source:` enum). It is not called by `work.md` today
  (it is not in `work.md`'s allowed-tools).
- **`plugins/tce/references/plan-document-template.md`**: read by `plan.md`
  (361, 410) and `work.md` (224).
  - Its implementation-log shape is written by `implement.md` / `work.md`.
  - `stage.sh` reads it (the `Phase N` headings and the `Status:` line).
- **`plugins/tce/references/research-document-template.md`**: read by
  `research.md` (307, 380), `work.md` (115) and `quickfix.md`. Its frontmatter
  `git_commit` is read by `implement.md:71`.
- **`plugins/tce/scripts/baseline.sh`, `branch.sh`, `ticket.sh`**: called by
  research, plan, implement, intent, work, quickfix, review and commit.
- **`plugins/tce/templates/tce/profile.md`**
  - The `## Delivery` intro states it is "a recorded agreement only" until a
    tce release acts on it.
  - The README (296-297) says the same.

### Current Contract
- **plan-compliance-checker**
  - Input: a numbered criteria list (MANUAL marked) plus the diff and stat.
  - Output: a markdown verdict table with four verdict values.
  - Assumption: the caller computes the diff and never passes
    `thoughts/` content.
- **stage.sh**
  - Input: IDs.
  - Output: six lines per ID.
  - `progress` counts phases whose log `Status:` starts with ✅ or `Complete`.
    A phase without a log counts as not done.
- **Plan log**
  - Fields: Status / Base commit (first phase) / Commit / Did / Issues /
    Verification, at most 8 lines.
  - `stage.sh` reads only `Status:`. `implement.md` reads `Base commit`.
- **Plan template:** the section list above. It has no `## Decisions` and no
  frontmatter.

### Adaptation Requirements
These are the sites a TP-0045b change would touch, depending on the planning
choices. Each is documented as "would be affected if …", not as a decision.

- **A fix-loop counter added to the log**
  - `implement.md:111-123` defines the shape that `implement.md` and the
    current `work.md` write.
  - `stage.sh:146-163` stops a log at the next heading and reads only the
    first `Status:`, so an added line inside the block does not change
    `progress`.
- **`## Decisions` added to the plan template**
  - The template is also read by `plan.md` and `quickfix.md`'s delegated
    planning. The ticket requires `plan.md` and `quickfix.md` themselves to
    stay byte-identical, but it does not list the reference file.
  - The composite-tracking rule in CLAUDE.md covers template edits.
- **`stage.sh` in `work.md`'s `allowed-tools`:** it is not there today.
- **Gate re-wiring in `work.md`**
  - The TP-0020 span names `work.md` as "re-describes the gate inline".
  - The TP-0030 span ties `work.md` to `baseline.sh`.
- **`init.md` gaining a `settings.json` edit**
  - Its Notes (630-632) and lines 138-139 / 203-204 state that it never edits
    `settings.json`.
  - CLAUDE.md names exactly two sanctioned `settings.json` edits: `/tmt:init`
    and `/tsf:init`.

### Backward Compatibility Options
- **Option A: new tce reference files for the agent contracts** (return
  shape, brief layout, dossier), leaving the existing templates untouched.
  - Pros: `research.md`, `plan.md` and `implement.md` stay byte-identical,
    and so do the templates they read.
  - Cons: until TP-0045c there are two descriptions of the plan's shape.
- **Option B: extend the existing templates** (e.g. `## Decisions` in the
  plan template, a counter line in the log).
  - Pros: one shape for both paths.
  - Cons: the single-step commands' output changes through the shared
    template while their command files stay byte-identical, and the
    composite-tracking rule applies.

## Historical Context (from thoughts/)

**Design inputs**
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md`
  (untracked at this commit) holds:
  - approach B and the staging;
  - the platform-facts table, verified on 2.1.290;
  - the brief mock-up and question ordering;
  - the verification rules: no script parses agent output; checks are only
    exists, non-empty and committed; the challenger; a verifier with shell
    and browser;
  - the status vocabulary and the seven tsf learnings.
- `thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md`: the
  epic-level cross-cutting rules, the b→c gate (one real run), and
  "Porting a tsf template means copying it into tce's `references/` and
  shedding its factory assumptions".
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`
  finding 2.3 (151-164): `/tce:work` runs three phases in one window. Its
  suggestion (a) was to run research in a subagent.

**What TP-0045a delivered** (tce 1.3.0)
- Sources: `thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md`,
  `thoughts/shared/plans/2026-10-11-TP-0045a-intent-reader-delivery.md`.
- The intent template:
  - frontmatter `ticket`, `size`, `status: agreed | open-questions`, …;
  - sections Scope, Observable outcome, Anchors, Acceptance criteria,
    Decisions, Open questions;
  - "45b's gate can read" the acceptance criteria;
  - its Decisions line shape is the one the 45a plan says 45b's plan
    `## Decisions` mirrors.
- `stage.sh`'s `intent:` line.
- Delivery and Reader are recorded but not acted on.
- Output styles do not reach subagents, so a reader profile meant for agent
  output must go into the agent's prompt.

**tsf lessons**
- **TP-0032** (Open): the shell-less checker escalated 7/7, 6 of them doable.
  Wanted:
  - attempt before escalating;
  - escalate only for credentials, third parties, visual judgment or a
    decision;
  - hand over an exact command.
  - Unresolved: whether an agent-discharged MANUAL item may be ticked.
- **TP-0036** (Done):
  - a timed-out Bash command moves to the background;
  - `BASH_DEFAULT_TIMEOUT_MS` is set as a shell export;
  - a resume opens a new fix episode.
- **TP-0038** (Open): the dispatcher was 84% of token traffic; context grew
  from 26k to 240k over 12 cycles.
- **TP-0039** (In Progress): 3/7 dispatches skipped the point-of-use read, and
  Sonnet invented a format. Fix: a filled-in skeleton in every agent, plus
  evidence as post-change line numbers.
- **TP-0041** (Open): plan challenger.
  - A fresh context with a closed checklist: criteria meaningful, verifiable
    or flagged manual, no contradiction with stack or research, spec
    covered, increments independent.
  - Fail goes back for revision, with a bound.
  - Findings only a human can settle go into the summary.
- **TP-0042 / TP-0046** (Open): test meaningfulness. TP-0046 reuses "the
  fix-loop bound; TP-0045b defines it".
- **TP-0043** (Done): rejection notes show one canonical shape.
- **TP-0044** (Open): progress recorded only in an accepted return stranded
  pushed work.
- **TP-0045c / TP-0045d**: rewiring, quickfix and `implement_eco` retirement
  are deferred to 45c. Progress heads-up lines go to 45d, which leaves open
  whether a subagent can surface anything before it finishes.

## Related Research

- `thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md`

## Open Questions

These are documented for planning. They are the ticket's "Questions for
Research/Planning", with what research established for each.

1. **Foreground vs background, and turn handling.**
   - Established:
     - background is the interactive default and cannot be refused per call;
     - `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` forces the foreground;
     - background agents' documented built-in tools exclude `Agent`, which
       bears on the research agent's fan-out;
     - `SendMessage` resumes in the background;
     - with the variable set, a Bash command that hits its timeout is
       stopped, so `BASH_DEFAULT_TIMEOUT_MS` matters.
   - Open:
     - whether a background research agent can fan out on the installed
       version (the 2.1.290 spike's dispatch mode is not recorded);
     - whether `SendMessage` resume honours the variable;
     - how the orchestrator recovers a lost agent ID (undocumented beyond the
       transcript path).
2. **Model pins.**
   - Precedents: tsf research and implement `sonnet`, plan and dossier
     `opus`; tle `loop-goal-critic` `inherit`; tce checker `inherit`.
   - Precedence now favours frontmatter over `CLAUDE_CODE_SUBAGENT_MODEL`.
3. **Fix-loop counter.** No field in the log carries one today. `stage.sh`
   reads only the first `Status:` per log, and the gate loop is unbounded.
4. **Checker vs verifier.** The checker stays shell-less (TP-0020, and TP-0032
   rules out giving it a shell). TP-0032 places the attempt-before-escalate
   behaviour in the consumer. Whether the verifier is that consumer is the
   planning question.
5. **tsf templates to port.** The generic and factory-specific parts of the
   dossier, pr-body and question-comment templates are mapped in §5.
6. **`work.md`'s budget.**
   - Today about 3.7-4k tokens, against a 5,000-token re-attach.
   - tsf keeps the dispatcher short by reading `cycle-*.md` references at the
     point of use.
7. **Permissions.**
   - The `allowed-tools` grant is turn-scoped and does not reach agents.
   - The tsf allowlist entries are mapped in §5.
   - tce `init.md` currently states it never edits `settings.json`.
8. **`## Delivery` wording.** The template and README call it "a recorded
   agreement only", wording that holds while no release acts on it.
9. **TP-0029's model-precedence statement** differs from the current docs.
   This is observed only, and outside this ticket's scope.
