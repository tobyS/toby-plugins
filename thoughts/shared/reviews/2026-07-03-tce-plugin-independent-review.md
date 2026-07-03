---
date: 2026-07-03
git_commit: 5c622ef
branch: main
ticket: N/A
review_scope: "Independent review of the tce plugin: usability, context-engineering best practices, competitive comparison"
status: complete
---

# tce review (Claude Fable 5, 2026-07-03)

> **Preamble — an intentionally unbiased review.** This review was deliberately
> conducted **without using any tce commands, skills, or agents**, to keep its
> judgment independent of the workflow under review: no `/tce:research`,
> `/tce:review`, or tce subagents were involved in producing it. It therefore
> does not follow the usual tce review structure. Evidence was gathered by
> reading every file in `plugins/tce/` directly and through independent web
> research; findings were converted into tickets TP-0015 – TP-0023 afterwards.

Independent review of the tce plugin: usability, context-engineering best
practices, and comparison against competing workflows. Based on a full read of
every file in `plugins/tce/` (all 12 commands, 6 agents, templates, hooks,
scripts), judged against Anthropic's published context-engineering guidance
and the mid-2026 competitive landscape (HumanLayer ACE/QRSPI, GitHub Spec Kit,
OpenSpec, BMAD, Task Master, Kiro, Agent OS).

## Verdict

tce is a genuinely strong implementation of the research→plan→implement
pattern — in several ways ahead of its competitors: it has a dedicated
codebase-research phase (Spec Kit, Kiro, BMAD, and Task Master all lack one;
OpenSpec added `/opsx:explore` in 2026 precisely because users demanded it),
ticket-scoped archived artifacts that sidestep the industry's unsolved "living
spec drift" problem, a ceremony escape hatch (`/tce:quickfix`) answering the
universal "waterfall in markdown" critique, and plugin-native distribution with
init/migration/refresh that even HumanLayer (still copy-in commands) doesn't
have. The TP-0013 re-read rule and the profile/tickets adapter design are
textbook context engineering.

The main weaknesses are the inverse of the strengths: the command prompts are
long and repetitive in ways that current guidance explicitly warns against,
several dead concepts inherited from the claude-template/HumanLayer lineage
still burn tokens and can mislead, the composite commands run three phases in
one context window against the ancestor's own core doctrine, and a handful of
concrete prompt bugs made it through. Details below, roughly ordered by
severity within each section.

## 1. Concrete defects (fix these regardless of anything else)

1. **`research.md` greets-and-waits even when given a ticket argument.** The
   "Initial Setup" block (`research.md:123-131`) says unconditionally: respond
   "I'm ready to research the codebase…" *then wait*. There is no "if an
   argument was provided, skip this" clause — `plan.md:180-184` has exactly
   that logic, and `work.md:69` explicitly overrides it ("Do NOT print 'I'm
   ready to research'"), which suggests the gap is known. As written,
   `/tce:research TP-0001` can legitimately stop and ask for a research
   question. This is the most user-visible usability bug in the plugin.

2. **Dead "thoughts sync" and "searchable/" machinery from the HumanLayer
   lineage.** `plan.md:567-569` instructs "Sync the thoughts directory — this
   ensures the plan is properly indexed" — there is no sync mechanism in tce
   (that's HumanLayer's `humanlayer thoughts sync`). Likewise
   `thoughts-locator.md` describes `thoughts/searchable/` (hard links),
   `thoughts/global/`, `thoughts/[username]/`, and `prs/` directories
   (`thoughts-locator.md:40-52`), and `research.md:458-464` carries
   path-correction rules for `searchable/` — none of which `/tce:init` ever
   creates. Cost: wasted tokens on every invocation, an agent that may waste
   turns searching nonexistent directories, and an instruction ("sync") the
   model can't execute and must silently skip — which trains it that
   instructions in this prompt are optional.

3. **Numbering bugs in `plan.md`.** Step 1's list has two items numbered 5
   (`plan.md:253` and `plan.md:260`), and Step 5 runs 1, 2, 2, 3, 4
   (`plan.md:571-599`). Harmless-looking, but cross-references like "proceed
   directly to step 5" (`plan.md:229`) become ambiguous to the model.

4. **Wrong command in `plan.md`'s example.** The Example Interaction Flow shows
   `User: /tce:implement` (`plan.md:762`) at the top of the *plan* command's
   own example dialogue. An in-prompt example contradicting the command's
   identity is exactly the kind of noise that misroutes behavior.

5. **The "Repository state guarantee" is asserted, not checked.**
   `implement.md:57` states flatly: "The research and plan were executed on the
   exact same state of the repository… No other processes modified files
   between steps 2, 3, and 4." True inside `/tce:work`, false in general —
   plans get implemented days later, teammates commit in between. The paragraph
   even names the mitigation (compare the frontmatter commit hash against HEAD)
   but frames it as unnecessary. Invert it: *check* `git_commit` from the
   research frontmatter against HEAD; if they differ, treat research claims
   about touched files as needing spot verification.

6. **Stray "plan mode" reference.** `plan.md:601` — "Do NOT leave plan mode to
   begin coding." `/tce:plan` doesn't run in Claude Code's plan mode; the
   sentence imports a concept that isn't in play and can confuse a model that
   *is* tracking real plan-mode state.

7. **`quickfix.md:243` depends on `/simplify`**, a harness built-in that isn't
   guaranteed to exist in every environment the plugin runs in. Guard it ("if a
   /simplify skill is available…") or describe the intent (remove leftover
   iteration artifacts) instead of naming the skill.

## 2. Context-engineering assessment

### What's genuinely well done

- The artifact chain with YAML frontmatter (date, commit, branch), the status
  file for resumability, and committed docs are exactly Anthropic's "structured
  note-taking" pattern, and the official best-practices doc now explicitly
  endorses spec-to-fresh-session handoff — tce had this before it was
  documented.
- The TP-0013 ordered re-read rule is a smart compensating control for
  same-session chaining, and correctly distinguished from "don't re-read source
  files research covers".
- The read-only documentarian subagents keep discovery noise out of the main
  window ("context quarantine"), and "Don't write detailed prompts about HOW to
  search — the agents already know" is the right altitude.
- profile.md/tickets.md as runtime-read project adapters is just-in-time
  retrieval done properly, and the drift detection (research advisory →
  `/tce:refresh`) closes a loop no competitor closes.

### Where it works against current best practice

1. **Command length vs. the attention budget — and the compaction cliff.**
   `plan.md` is 773 lines; research/review/init are ~470 each. Official
   guidance: keep skill bodies concise, under ~500 lines, move detail to
   reference files. More acutely: an invoked command's text stays in context
   for the whole session, and after auto-compaction only the first ~5,000
   tokens of each invoked skill are re-attached (25k combined budget). A
   `/tce:work` session invokes work + plan + implement + commit; it is
   precisely the session type that *will* compact, at which point the tails of
   these prompts (plan.md's Success Criteria Guidelines, Common Patterns,
   Sub-task Spawning sections) silently vanish. The fix isn't just aesthetic
   trimming — it's moving stable reference material (the plan template, the
   research doc template, the status-file format) into skill supporting files
   that are read from disk when needed, so they survive compaction the same way
   tickets and research docs do. That's the same insight TP-0013 already
   encodes for workflow documents; apply it to the templates themselves.

2. **Heavy intra-file repetition.** The same instruction often appears 3-4
   times per file ("read FULLY, no limit/offset" appears at `research.md:138`,
   `:452`; "wait for ALL sub-agents" at `:211` and `:455`; plan.md restates the
   "don't re-read researched files" rule in at least four places). The lineage
   here is HumanLayer's 2024-era prompts, written when repetition was the only
   reliability tool. Current guidance is the opposite: state each rule once,
   well-placed; add repetition only in response to an observed failure. The
   community post-mortem of exactly this command set (the QRSPI writeups) named
   "instruction budget overflow" — ~150-200 instructions per prompt — as the
   reason HumanLayer split their three monolithic commands into smaller
   stages. `plan.md` is well past that budget.

3. **The composites run three phases in one window — the ancestor's
   anti-pattern.** ACE-FCA's core doctrine is fresh context per phase,
   utilization at 40-60%; Anthropic's best-practices doc says the same ("start
   a fresh session to execute it"). `/tce:work` deliberately chains
   research→plan→implement in one session, with re-reads as mitigation. That's
   a legitimate trade-off (interactivity, one checkpoint), but the plugin never
   acknowledges the context budget at all. Two cheap improvements: (a) give
   `/tce:research` (the noisiest phase — it synthesizes many subagent reports)
   `context: fork` or run it via a subagent inside the composites, so its
   synthesis happens off the main window and only the committed doc returns;
   (b) have `work.md` advise, after the plan commit, that for Large tickets
   implementation is better started in a fresh session (`/tce:implement
   TP-XXXX` — everything needed is on disk; that's the whole point of the
   artifact chain).

4. **Unused frontmatter/plugin machinery.** No command sets
   `disable-model-invocation: true` — side-effectful workflows (`init`,
   `implement`, `quickfix`, `commit`) are exactly what the docs recommend it
   for, and it also removes their descriptions from the always-on skill
   listing. No command declares `allowed-tools` for
   `${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh`, so every discovery-script call
   risks a permission prompt. Agents are all `model: inherit`;
   `codebase-locator` and `thoughts-locator` are classic Haiku work (faster,
   cheaper, no quality loss for find-and-categorize). And `` !`cmd` ``
   dynamic-context injection could replace "first run ticket.sh and read its
   output" boilerplate.

5. **No subagent output budget.** research.md tells agents *what* to return
   but never caps the size; the docs warn that fan-out with verbose returns
   "can consume significant context" and the norm is condensed ~1-2k-token
   summaries. One line in each agent's Output Format section would do it.

6. **The "documentarian, not critic" rule collides with bug tickets.** "DO NOT
   perform root cause analysis" (`research.md:62`) is the right guard against
   premature solutioning for features — but for a bug ticket (and every
   `/tce:quickfix`), locating the cause *is* the research deliverable.
   Currently the model must either violate the rule or produce research that
   describes everything around the bug without saying where it is. Carve out an
   explicit exception: for defect tickets, tracing the mechanism of the faulty
   behavior is documentation, not critique.

7. **Interaction ceremony in `/tce:ticket` is fixed-size.** Seven phases with
   three hard "do not proceed until the user confirms" gates is right for a
   Large feature and exhausting for "rename this setting and add a tooltip."
   Every surviving competitor grew scale-adaptive planning (Kiro's Quick Plan,
   BMAD's Quick Flow, Spec Kit's the-lack-thereof being its top complaint).
   There's quickfix at the bottom and full ceremony at the top, but nothing
   between; letting ticket.md compress phases 1-5 into one confirmation round
   for Small/Medium tickets would remove the most common reason users route
   around a workflow.

## 3. What competitors have that's worth stealing (and what isn't)

Worth considering, in priority order:

1. **A plan-validation step** (HumanLayer `validate_plan`, Spec Kit
   `/speckit.analyze`). Cheapest high-leverage addition: before
   `/tce:implement` finishes a ticket, a fresh-context subagent that sees only
   the diff + the plan's success criteria (not the reasoning that produced the
   code) and reports requirement gaps. Anthropic's best-practices doc
   explicitly recommends this adversarial-review-in-clean-context pattern.
   `/tce:review` exists but is heavyweight, optional, and post-hoc; this would
   be a small built-in gate at the end of implement/work/quickfix.

2. **The QRSPI lessons from tce's own lineage**: keep plans short enough that a
   human actually reads them (their finding: 1,000-line plans get
   rubber-stamped — "as many surprises as 1,000 lines of code"). plan.md's
   template encourages exhaustiveness; a sentence like "a plan a reviewer won't
   read is a failed plan — prefer 200 lines" would counterweight it. Their
   other trick — hiding the ticket's proposed solution from researchers to
   avoid bias — is interesting but probably over-engineering for tce's scope.

3. **A decisions layer.** Spec Kit's constitution / BMAD's decision-log record
   *why* choices were made across tickets. tce has
   `thoughts/shared/discussions/` but nothing ever routes plan-time decisions
   there; the "Notes & Updates" ticket section is per-ticket. A lightweight
   convention (plan.md appends significant cross-cutting decisions to a
   `thoughts/shared/decisions.md` or the profile's Conventions) would compound
   the "repo gets better at being worked on" promise.

4. **Not worth it:** Task Master's dependency-graph task decomposition and
   worktree parallelism (tce's phased plans + status file cover the sequential
   case; parallel orchestration is being absorbed by native features), BMAD's
   persona theater, Kiro's EARS notation. Agent OS v3's story — they deleted
   their orchestration layer because frontier models + plan mode absorbed it —
   is the cautionary tale for adding more machinery rather than less.

## 4. Smaller usability notes

1. Onboarding is best-in-class: the SessionStart nudge with the
   template-migration variant, the enable-time greeting, idempotent init with
   version markers, and `/tce:refresh` — no competitor has this maintenance
   story.

2. `design_explore` hard-blocks on user-supplied screenshots
   (`design_explore.md:62-72`). When browser tooling (Claude in Chrome,
   chrome-devtools MCP, Playwright) is available it could offer to capture the
   baseline itself, with the manual path as fallback.

3. Replacing local `file:line` references with GitHub permalinks in research
   docs (`research.md:338-344`) pins references to a commit (good) but breaks
   editor clickability for the primary consumer — later Claude sessions and
   teammates in the repo. Consider keeping the local ref and *adding* the
   permalink.

4. Double bookkeeping in implement: plan checkboxes and the status file record
   the same progress. Defensible (plan = spec state, status = session journal),
   but worth stating that intent in implement.md so the model doesn't treat one
   as redundant.

5. The ticket-sufficiency criteria now live in three places (research.md,
   work.md, tickets.md template). The repo's CLAUDE.md sync rules manage the
   AskUserQuestion block; this trio isn't covered by any stated rule yet.

## Suggested priority

1. Fix the Section 1 defects (an afternoon: the research.md argument gap, dead
   sync/searchable machinery, numbering, the state-guarantee inversion).
2. Restructure the two biggest commands (plan, research) toward
   skill-with-references: body under ~400 lines, templates as supporting files
   read at use time — this simultaneously fixes the compaction cliff, the
   instruction budget, and most repetition.
3. Adopt the frontmatter quick wins (`disable-model-invocation`,
   `allowed-tools` for ticket.sh, Haiku for the locator agents, subagent output
   caps).
4. Add the fresh-context plan-vs-diff verification step and the fresh-session
   advice in composites.
5. Then, opportunistically: scale-adaptive ticket ceremony, plan length
   counterweight, decisions layer.

## Sources

- Anthropic, "Effective context engineering for AI agents" —
  https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Claude Code docs: best practices, skills, sub-agents, features overview —
  https://code.claude.com/docs/en/best-practices ·
  https://code.claude.com/docs/en/skills ·
  https://code.claude.com/docs/en/sub-agents ·
  https://code.claude.com/docs/en/features-overview
- Skill authoring best practices —
  https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- HumanLayer ACE-FCA —
  https://github.com/humanlayer/advanced-context-engineering-for-coding-agents/blob/main/ace-fca.md
  · https://www.humanlayer.dev/blog/advanced-context-engineering
- QRSPI (community-sourced, moderately uncertain) —
  https://alexlavaee.me/blog/from-rpi-to-qrspi/ ·
  https://github.com/matanshavit/qrspi
- GitHub Spec Kit — https://github.com/github/spec-kit; critiques:
  https://marmelab.com/blog/2025/11/12/spec-driven-development-waterfall-strikes-back.html
  ·
  https://blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces-radical-idea-or-reinvented-waterfall.html
  · https://github.com/github/spec-kit/discussions/1784
- OpenSpec — https://github.com/Fission-AI/OpenSpec
- BMAD Method — https://github.com/bmad-code-org/BMAD-METHOD; critique:
  https://rywalker.com/research/bmad-method
- Claude Task Master — https://github.com/eyaltoledano/claude-task-master
- Amazon Kiro — https://kiro.dev/docs/steering/ ·
  https://kiro.dev/docs/specs/correctness/
- Agent OS — https://github.com/buildermethods/agent-os (discussions #173,
  #310)
- Chroma, "Context Rot" — https://research.trychroma.com/context-rot
