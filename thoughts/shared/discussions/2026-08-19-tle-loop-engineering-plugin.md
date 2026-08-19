---
date: 2026-08-19
topic: "tle (Toby Loop Engineering) plugin — design of a convergence-loop workflow"
status: complete
---

# Technical Discussion: tle (Toby Loop Engineering) plugin

## Challenge

Design a new plugin for the toby-plugins marketplace — **tle, Toby Loop
Engineering** — that runs an autonomous convergence loop toward a defined goal:
repeatedly verify how far a (greenfield, web-app) project is from the goal,
derive the next small step, and implement it, until verification reports the
goal reached. Requirements from the initial idea:

- Two commands: an interactive one to define a good loop goal, and a runner
  that executes the loop.
- The runner must stay **slim** in the loop and delegate all heavy work to
  agents.
- Verification must be real: run tests, judge test adequacy, browse the web
  app under construction.

## Research inputs

Two research passes grounded the discussion:

1. **Claude Code mechanics** (official docs): `/loop` runs every iteration in
   the **same session** — context accumulates and is auto-compacted; there is
   no fresh context per iteration. A scheduled fire cannot execute a skill
   flagged `disable-model-invocation: true` (it arrives as plain text).
   `/goal` is condition-driven: a session-scoped Stop hook where a **fresh
   small model (Haiku)** evaluates a completion condition against the
   transcript after every turn — it runs no commands and reads no files. It
   has a built-in stall guard (consecutive no-tool-use turns stop the loop),
   an "impossible" verdict, and budgets are placed in the condition text.
2. **Loop-engineering prior art**: Anthropic's "effective harnesses for
   long-running agents" and C-compiler posts, the Ralph Wiggum technique, and
   reward-hacking research (SpecBench, Verification Horizon). Converged
   principles: durable state in files/git (never conversation), one small
   step per iteration, a granular machine-checkable DONE checklist,
   fresh-context verifier architecturally separated from the implementer
   (dropped hacked-but-passing solutions from ~29% to ~1% in one study),
   end-to-end browser verification against premature victory declaration,
   hard budgets plus stall detection, commit every green increment.

## Approaches Explored

### Engine: `/loop` (original idea)

**How it works**: `/loop /tle:run`, time-paced (fixed interval or
ScheduleWakeup self-pacing), re-fires the runner command each iteration.

**Pros**: matches the original mental model; self-paced mode can end itself.

**Cons**: time-driven (≥60s between iterations) where a convergence loop is
turn-driven; the runner must not carry `disable-model-invocation: true` or
the loop silently does nothing; same-session context accumulation anyway.

### Engine: `/goal` backstop + internally looping runner (chosen)

**How it works**: `/tle:run` loops internally ("repeat the cycle until the
verifier reports convergence") within one session; the built-in `/goal`
pins a completion condition on the session so a fresh Haiku — not the
working model — decides when the session may stop. Fires after every turn,
no time floor.

**Pros**: condition-driven fits convergence; independent fresh-model exit
evaluator for free (the exact separation the reward-hacking literature
endorses); built-in stall guard and budget-in-condition; the
`disable-model-invocation` constraint evaporates (no re-invocation happens —
though the runner still ships unflagged in case it is ever run under
`/loop`).

**Cons**: context still accumulates in the session (only subagents get fresh
windows), so slim-loop discipline remains non-negotiable; `/goal`'s
evaluator is transcript-only, so the runner must surface the verifier's
verdict into the transcript each iteration; the flow needs one extra paste
(`/goal <condition>` before `/tle:run`), since built-ins are not
model-invocable.

### Per-iteration pipeline: 4 agents (verify → spec → plan → implement)

**Pros**: mirrors tce's proven ticket → research → plan → implement chain.

**Cons**: over-ceremony for a loop whose unit of work is deliberately tiny
("one small step per iteration" is the single most-repeated principle in the
prior art). Two handoff artifacts and an extra agent invocation per
iteration for a few-files change.

### Per-iteration pipeline: 3 agents (chosen)

**How it works**: verifier → spec+plan agent (gap → one small actionable
spec including how to verify it) → implementer. If a step proves too big to
implement in one go, the spec+plan agent should have cut it smaller — that
is the corrective, not a planning layer.

### Loop breaker as a fourth agent (original idea)

Dropped. The happy ending (verifier reports all items pass) is a verdict,
not an agent. The unhappy endings are covered by `/goal`'s stall guard and
"impossible" verdict, budgets baked into the condition string, and one cheap
deterministic check in the runner: compare each verify report with the
previous one — identical failures two iterations in a row triggers an
escalation instruction (fresh-context retry → different strategy → stop)
instead of a blind retry.

## Conclusion

Build **tle** as a third marketplace plugin with two commands and three
agents.

### Commands

- **`/tle:define`** (interactive; `disable-model-invocation: true`) —
  sparring discussion that converges on a goal, then writes
  `thoughts/shared/loops/<goal-slug>/goal.md` containing:
  - a **granular checklist with per-item pass state and a per-item
    verification method** — the checklist IS the convergence definition,
    the gap-analysis input, and the oscillation guard (done items stay done
    and are re-verified, not re-decided);
  - verification methods pushed as far down the oracle hierarchy as honestly
    possible: command-with-exit-code (tests, build) preferred; browser
    scenarios (via chrome-devtools-mcp) only for what end-to-end interaction
    alone can prove, written as **user-level scenarios** ("open /, add an
    item, reload, item persists"), never selectors — the UI drifts across
    iterations, the goal file must not;
  - **ops facts**: how to boot the app, how to run tests, the base commit —
    so agents don't rediscover them each iteration (project groundwork/dev
    env is set up manually before the loop starts; no initializer agent);
  - budgets (max iterations at minimum);
  - a ready-to-paste **`/goal` condition string**, e.g. "the tle verifier
    has reported all checklist items in <goal-slug> passing, or 30
    iterations completed".
- **`/tle:run <goal-file>`** (unflagged) — the slim loop. Opens by checking
  a goal condition is set (tells the user to paste it if not), then repeats
  until the verifier reports convergence or an escalation stop:
  1. cheap baseline check (build/boot still green?) before anything else;
  2. dispatch verifier; it writes `NNN-verify.md`, returns one line;
  3. surface the verdict into the transcript (for `/goal`'s Haiku);
  4. stall check: verify report identical to previous → escalate;
  5. dispatch spec+plan agent; writes `NNN-plan.md`, returns the path;
  6. dispatch implementer with the plan path; it implements, commits,
     returns one line;
  7. append to `loop-log.md` (iteration, verdict summary, commit hash).

User flow: `/tle:define` → paste `/goal <condition>` → `/tle:run
<goal-file>`.

### Agents

- **Verifier** — fresh-context, architecturally separated from the
  implementer, never trusts its claims. Reads the goal file, executes each
  item's stated verification method (commands, chrome-devtools-mcp browser
  scenarios), diff-reviews test files (implementer weakening/deleting tests
  is the canonical hack; "tests may not be edited to pass" is a hard rule in
  both agents' prompts), returns per-item verdicts + the gap. Same isolation
  pattern as tce's plan-compliance-checker.
- **Spec+plan agent** — reads goal checklist + latest verify report from
  disk, writes one small actionable step spec (`NNN-plan.md`) including how
  the step will be verified.
- **Implementer** — reads `NNN-plan.md` from disk (fresh context gets the
  full plan without the loop ever holding it), implements, commits the green
  increment (git is the rollback for the woke-up-to-a-broken-codebase
  failure mode), returns one line.

**File-only handoffs are the core rule**: the main loop never carries
content, only file paths and one-line statuses. All artifacts live in
`thoughts/shared/loops/<goal-slug>/` — durable, git-tracked, an audit trail
readable after the fact, and discoverable by tce's thoughts-locator agents
in the same project.

**tce coordination**: every tle agent reads
`${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` **if it exists** (optional
enrichment, never a hard dependency; fallback is the goal file's ops facts).
This is the sanctioned pattern — plugins coordinate only through project
config files, never cross-plugin calls.

### Trade-offs Accepted

- **No mid-run goal revision** — a goal file is immutable once its loop
  starts. A loop runs to its end or is killed; a changed goal means a fresh
  `/tle:define` (new slug, new folder) and a new loop. `/tle:define` never
  edits an existing goal file.
- **Same-session context accumulation** (no fresh context per iteration, the
  core premise of classic loop engineering) — accepted because subagents
  keep heavy content out of the main window and file-only handoffs keep the
  loop turn tiny; a Stop-hook engine (à la Anthropic's ralph-wiggum plugin)
  remains the fallback if accumulation bites in practice.
- **One extra manual paste** (`/goal` is a built-in and not model-invocable)
  — accepted for the free independent exit evaluator.
- **Merged spec+plan agent** gives up tce-style separation of concerns —
  accepted because the loop's unit of work is deliberately tiny.
- **Greenfield-first scope** — prior art (Huntley) is explicit that the
  technique suits new codebases; the plugin docs should say so rather than
  promise general convergence. First use case: a new private tool.
- **Partial re-description of tce's spec→implement flow** without calling it
  (cross-plugin calls forbidden) — a second drift surface, accepted because
  the loop's leaner register is intentional.
- **chrome-devtools-mcp is a project-level dependency** tle can only
  document, not ship — the goal file specifies browser verification
  declaratively, keeping the verifier agent agnostic.

## References

- `plugins/tce/agents/plan-compliance-checker.md` — the in-repo isolation
  pattern the verifier mirrors
- `CLAUDE.md` — "Core design rule: keep the plugins project-agnostic",
  cross-plugin coordination rules
- https://code.claude.com/docs/en/scheduled-tasks — `/loop`, ScheduleWakeup,
  disable-model-invocation interaction with scheduled fires
- https://code.claude.com/docs/en/goal — `/goal` condition semantics, stall
  guard, budgets in condition
- https://code.claude.com/docs/en/context-window — compaction, skill
  re-injection caps
- https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
  — feature-list-as-oracle, one feature at a time, browser verification
- https://www.anthropic.com/engineering/building-c-compiler — near-perfect
  verifier requirement, state in files/git
- https://ghuntley.com/ralph/ — Ralph Wiggum technique and failure modes
- https://github.com/anthropics/claude-code/blob/main/plugins/ralph-wiggum/README.md
  — Stop-hook loop engine, max-iterations as primary safety
- https://arxiv.org/html/2605.21384v1 (SpecBench),
  https://arxiv.org/html/2606.26300v2 (Verification Horizon) — visible-test
  overestimation, separate-monitor mitigation (~29% → ~1%)
- https://www.developersdigest.tech/blog/loop-engineering-designing-agent-loops
  — convergence-criterion hierarchy, escalation ladder
