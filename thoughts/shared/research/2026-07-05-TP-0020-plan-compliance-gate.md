---
date: 2026-07-05T12:40:00+02:00
git_commit: d1607b6833f44e733ab249267ff6f6f9dbb238c9
branch: main
repository: toby-plugins
topic: "TP-0020: Plan-compliance gate — fresh-context criteria check before closing a ticket"
tags: [research, codebase, tce, agents, implement-command, composites, documentarian-rules]
status: complete
last_updated: 2026-07-05
---

# Research: TP-0020 — Plan-compliance gate (fresh-context criteria check before closing a ticket)

**Date**: 2026-07-05T12:40:00+02:00
**Git Commit**: d1607b6833f44e733ab249267ff6f6f9dbb238c9
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0020 wants a **plan-compliance gate**: before `/tce:implement` (and via it
`/tce:work` and `/tce:quickfix`) transitions a ticket to done, a dedicated
fresh-context subagent receives only (a) the ticket's acceptance criteria + the
plan's success criteria and (b) the implementation diff, and returns a
per-criterion verdict (met / not met / cannot verify from diff), with unmet
criteria blocking the done transition. The agent must be hard-gated against
scope creep in the same style as the existing documentarian agents. This
research establishes: where the gate wires into `implement.md`; how to author
the new agent to match the shipped agents' structure and hard-constraint style;
how the composites mirror it; and how the agent should obtain the diff and
criteria while staying read-only.

The ticket's Questions for Research/Planning drive the investigation:
1. How the agent obtains the diff (passed in vs derived via a Bash grant).
2. How the criteria are passed (verbatim in the prompt vs the agent reading the
   ticket/plan files itself).
3. Exact placement in `implement.md` and what the blocked path looks like.
4. Whether the agent needs the project profile.

## Summary

- **The integration site is unambiguous.** `implement.md` concentrates all
  ticket-closing logic in two adjacent sections: `## Final Verification Before
  Closing a Ticket` (`implement.md:239-257`, test-suite passage only) and `##
  Ticket Status Transitions` (`implement.md:259-272`, the done-flip gated on
  line 268 "When ALL phases are complete and verified"). The gate lands **between
  them**: after final verification, before the done transition. There is
  currently **no** section that verifies the implementation against the plan's
  scope/criteria — verification today is tests/lint + per-phase checkbox ticking
  (`implement.md:216-220`), exactly the self-graded loop the ticket critiques.

- **The agent's authoring template is fully established.** Six agents live in
  `plugins/tce/agents/`. Frontmatter is `name, description, tools, model`
  (`color` optional). The three codebase-* agents carry a **three-part
  documentarian envelope** to mirror: an ALL-CAPS `## CRITICAL: YOUR ONLY JOB
  IS …` preamble of `DO NOT`/`ONLY` bullets, a trailing `## What NOT to Do`
  list, and a `## REMEMBER: You are a documentarian, not a critic or consultant`
  closer (the heading is byte-identical across the three;
  `codebase-analyzer.md:37-45,142-161`).

- **Read-only is enforced by tool omission.** No shipped agent declares `Edit`,
  `Write`, or `Bash`. The fullest read-only set in use is codebase-analyzer's
  `LSP, Read, Grep, Glob, LS` (`codebase-analyzer.md:4`). AC1 mandates
  "read-only tools", so a **Bash grant for the gate is ruled out by the
  acceptance criteria** — the diff must be computed by `implement.md` (main
  context) and passed into the delegation prompt. This resolves ticket Q1
  toward "passed in".

- **Agents are invoked by bare name, never namespaced.** Commands say "Use the
  **codebase-locator** agent" (`research.md:181`); the model maps the bold bare
  name onto the Task/Agent tool. No `tce:` prefix and no
  `${CLAUDE_PLUGIN_ROOT}/agents/...` path is ever used for agents (that variable
  is only for `scripts/` and `references/`). The new agent is referenced the
  same way.

- **The composites mirror gates by two different mechanisms.** `work.md`
  **re-describes** implement inline (Phase 4, `work.md:24` lock-step note), so
  the gate must be transcribed into work.md's Phase 4 as prose. `quickfix.md`
  **Skill-delegates** implement (`quickfix.md:185` "Invoke the `tce:implement`
  skill"), so it inherits the gate automatically — but its final-summary
  section may need a surfacing line, mirroring how the config-drift gate was
  handled (`quickfix.md:231-233`).

- **Criteria come from two documents with a built-in automated/manual split.**
  The plan template separates `#### Automated Verification` from `#### Manual
  Verification` (`plan-document-template.md:69-85, 127-163`). Manual items
  ("Feature works as expected when tested via UI") are exactly what AC4 says the
  gate must report as "needs human verification" rather than guess. The ticket's
  own `## Acceptance Criteria` checkboxes are the second criteria source.

- **Ticket's cited source has a discrepancy worth recording.** The origin review
  (`2026-07-03-tce-plugin-independent-review.md`, Section 3 item 1, lines
  206-213) recommends exactly this gate and cites Anthropic's best-practices
  "adversarial-review-in-clean-context" pattern. But it does **not** contain the
  "Marmelab false security" critique the ticket's References section attributes
  to it — the only Marmelab citation there (line 299) is a Spec-Kit *waterfall*
  critique. The "false security" framing is not sourced from this review; not
  load-bearing for the design, but the ticket reference is inaccurate.

## Detailed Findings

### Integration site in `implement.md`

The file (308 lines) is organized by headings, not numbered phases. The closing
flow, in document order:

- `## Verification Approach` (`implement.md:212-224`) — per-phase checks: "Run
  the success criteria checks" (`:216`), "Run code style checks" (`:217`), "Fix
  any issues before proceeding" (`:218`), then check off plan items (`:219-220`)
  and update the status file (`:221`) and commit (`:222`).
- `## Committing Each Phase` (`implement.md:226-237`).
- `## Final Verification Before Closing a Ticket` (`implement.md:239-257`) —
  **test-suite passage only**. "Before marking a ticket as done, run ALL test
  suites that could even remotely be affected" (`:241`), a changed-component →
  suites table (`:247-253`), "When in doubt … run everything" (`:255`), "A
  ticket is only done when all potentially affected tests pass" (`:257`).
- `## Ticket Status Transitions` (`implement.md:259-272`) — defers to the
  `tickets.md` "Status / completion" policy. The done bullet is gated on
  "**When ALL phases are complete and verified**" (`:268`); the no-transition
  policy path is `:271-272`.

**Placement decision (ticket Q3):** the gate is a new section inserted
**between `:257` and `:259`** — after full-suite verification, before the status
flip. The done-transition bullet at `:268` gains a precondition: the gate must
have passed (no "not met" verdicts). This keeps the gate on the critical path of
all three flows without disturbing the per-phase loop.

**Existing "STOP + report" template to reuse for the blocked path.** The closest
precedent is `## Implementation Philosophy` (`implement.md:198-210`), a
structured STOP-and-report block for plan mismatches:

```
Issue in Phase [N]:
Expected: [what the plan says]
Found: [actual situation]
Why this matters: [explanation]

How should I proceed?
```

The gate's "not met" path should mirror this shape: report the failing criteria
with the agent's evidence, feed them back into the normal implement fix loop
(`:218` "Fix any issues before proceeding"), and re-run the gate — not flip the
status.

**No agent is spawned by implement.md today.** Its `allowed-tools`
(`implement.md:4`) lists only `ticket.sh`; agents are mentioned only as an
optional, discouraged research fallback (`:85-89`, "should be the exception").
Adding a gate that *always* spawns an agent at closing time is a new pattern for
this command, but a well-precedented one across the plugin (research/plan spawn
agents routinely).

**Success criteria are read from the plan, commands from the profile.** The plan
holds the criteria (`implement.md:9, 68, 216`); the concrete test/lint/typecheck
commands come from `profile.md` (`implement.md:15`). implement.md does **not**
today branch on the plan's Automated-vs-Manual split — it treats criteria
generically. The gate introduces that distinction (met/not-met for automated-ish
criteria evaluable from the diff; "needs human verification" for Manual items).

### Authoring the new agent — structure to match

Canonical body order (from `codebase-analyzer.md`, the fullest read-only
example):

1. One-line role statement, no heading (`codebase-analyzer.md:8`).
2. `## Project context` — reads `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md`
   (`:10-12`). **For this gate: likely omit** (ticket Q4) — a design goal is
   that the gate knows as little as possible beyond criteria + diff; the profile
   would leak project reasoning and isn't needed to check "is criterion X
   satisfied by this diff".
3. `## CRITICAL: YOUR ONLY JOB IS …` hard-constraint preamble (`:37-45`).
4. `## Core Responsibilities` (present in all six agents).
5. `## Analysis Strategy` / Step 1-2-3 walkthrough.
6. `## Output Format` — a fenced fill-in-the-blanks Markdown skeleton with
   `path/to/file.ext:NN` reference placeholders.
7. `## Important Guidelines`.
8. `## What NOT to Do` (`:142-155`).
9. `## REMEMBER: You are a documentarian, not a critic or consultant` (`:157-161`).

**Frontmatter** (exact key order `name, description, tools, model`):
`codebase-analyzer.md:1-6` is the model. For the gate:
`tools: Read, Grep, Glob, LS` (read-only, per AC1; see the diff-access decision
below for whether `Read`/`Grep` are included at all). `model: inherit` (the
judgment task warrants the session model, matching analyzer/pattern-finder;
`haiku` is used only for the two cheap locators).

**The three-part documentarian envelope, adapted from "documentarian" to
"criteria-only verifier".** The existing envelope forbids suggestions, quality
critique, root-cause analysis, security/performance commentary. The gate needs
the same envelope re-pointed: it may output **only** per-criterion verdicts +
evidence; no code-quality/style/security opinions, no suggestions, no findings
beyond the criteria list (AC2). The exact recurring shapes to reproduce:

- Preamble (`codebase-analyzer.md:37-45`): `## CRITICAL: YOUR ONLY JOB IS …`
  heading + 5-6 `DO NOT …` bullets + a closing `ONLY …` bullet.
- `## What NOT to Do` (`codebase-analyzer.md:142-155`): ~10 `Don't …` bullets.
- `## REMEMBER: …` closer (`codebase-analyzer.md:157-161`): the byte-identical
  heading + two re-tailored paragraphs (analyzer casts itself as "technical
  writer"; the gate would cast itself as e.g. "a compliance checker, not a code
  reviewer").

**Defect-exception precedent for a bounded carve-out (TP-0018).** `codebase-
analyzer.md` shows how the plugin adds a *narrow, explicitly-gated* exception to
an otherwise hard block: "(unless the user explicitly asks you to trace a
defect's mechanism)" at `:91, :149, :153`. If the gate needs any carve-out
(e.g. permitting it to note *why* a criterion cannot be verified), mirror this
mechanism — a clearly bounded qualifier, not a loosening of the whole block.

### Output contract for the gate

No shipped agent emits a machine-parsed structure; all emit a fenced Markdown
skeleton (`## Output Format`). The gate should do the same: a per-criterion
table/list where each row is `criterion → verdict (met / not met / cannot verify
from diff / needs human verification) → evidence (path/to/file.ext:NN or "not
present in diff")`. A one-line overall verdict (all met / N unmet) lets
implement.md branch cheaply. Per the review's subagent-output-budget note
(Section 2 item 5, lines 178-181), cap the report (~1-2k tokens) — verdicts +
evidence refs only, no prose narrative.

### How the gate obtains the diff and criteria (ticket Q1, Q2)

**Q1 — diff acquisition.** AC1's "read-only tools" rules out a Bash grant (no
shipped agent has Bash; `git diff` needs Bash). Therefore `implement.md` computes
the diff in the main context and passes it into the delegation prompt. The
mechanic: the code changes for a ticket are the commits made during
implementation; the base is the commit at which implementation started (the plan
commit / the research doc's `git_commit` frontmatter is the nearest recorded
anchor — `implement.md:58` already reads it) through HEAD, or `git log --grep`
for the ticket ID. In this repo (single `main`, no branches) a commit range is
straightforward.

**Q2 — criteria passing.** Fresh-context purity (the review's "sees only the
diff + criteria, not the reasoning that produced the code", lines 208-209) argues
for **passing the extracted criteria verbatim** in the prompt rather than having
the agent read the ticket/plan files — reading those would expose the
implementation rationale and defeat the adversarial isolation. So implement.md
extracts (a) the ticket's `## Acceptance Criteria` checkboxes and (b) the plan's
`#### Automated Verification` + `#### Manual Verification` items, labels the
manual ones, and passes all of them as the criteria list.

**Open design fork (see Open Questions):** whether, beyond the passed diff, the
agent may `Read` the post-change **source files** to confirm criteria the raw
diff can't show (a read-capable inspector) vs. judging **purely** from the
inlined diff text (a pure adversarial judge, more "cannot verify" verdicts).
Both are defensible; this is the one decision the acceptance criteria don't
settle.

### Composite mirroring (AC5)

Per `CLAUDE.md`'s composite-tracking rule, editing implement.md's closing flow
requires updating `work.md` and `quickfix.md` in the same commit.

- **`work.md` re-describes implement inline.** Phase 4 (`## Phase 4:
  Implementation`) restates `/tce:implement`'s flow in its own words; `work.md:24`
  declares "Phases 1, 3, and 4 mirror `/tce:research`, `/tce:plan`, and
  `/tce:implement`". Its `### 4d. Final verification` must gain the gate step in
  prose (run gate → block on "not met" → report → the passing note), mirroring
  how config-drift and the sufficiency check were transcribed inline.
- **`quickfix.md` Skill-delegates implement** (`quickfix.md:185` "Invoke the
  `tce:implement` skill (via the Skill tool)"), so it **inherits** the gate with
  no re-description of the mechanics. What it may need is a one-line surfacing in
  its final-summary section (`quickfix.md:231-233` area), matching how the
  config-drift gate got a surfacing line there while the mechanics lived in the
  delegated command. Because quickfix is fully autonomous, the gate is
  especially load-bearing there (AC-motivation: the autonomous flows removed
  intermediate human review).

### TP-0017 invocation-control classification (new delegation edge)

The gate is a **new agent invoked by implement.md** — but agents are not
Skill-invocable commands, so the `disable-model-invocation` flag (which applies
to `commands/*.md`, not `agents/*.md`) does not attach to the agent file. No
command classification changes: implement/work/quickfix keep their existing
flags. No new command is created. (Recorded so the CLAUDE.md TP-0017 rule is
visibly considered — conclusion: no change required.)

## Code References

- `plugins/tce/commands/implement.md:239-257` — `## Final Verification Before
  Closing a Ticket` (test-suite passage; gate lands after this).
- `plugins/tce/commands/implement.md:259-272` — `## Ticket Status Transitions`
  (done-flip at `:268`; gate lands before this; `:271-272` no-transition path).
- `plugins/tce/commands/implement.md:198-210` — `## Implementation Philosophy`
  STOP-and-report template to mirror for the blocked path.
- `plugins/tce/commands/implement.md:4, 85-89` — allowed-tools; agents as
  discouraged fallback (no gate agent exists yet).
- `plugins/tce/commands/implement.md:15, 68, 216` — where criteria/commands are
  read (plan for criteria, profile for commands).
- `plugins/tce/agents/codebase-analyzer.md:1-6` — frontmatter model.
- `plugins/tce/agents/codebase-analyzer.md:37-45` — `## CRITICAL:` preamble.
- `plugins/tce/agents/codebase-analyzer.md:142-161` — `## What NOT to Do` +
  `## REMEMBER:` closer.
- `plugins/tce/agents/codebase-analyzer.md:91, 149, 153` — TP-0018 bounded
  carve-out precedent.
- `plugins/tce/commands/research.md:181` — bare-name agent invocation pattern.
- `plugins/tce/commands/work.md:24, 84` — composite lock-step declaration + agent
  list (Phase 4 gets the gate inline).
- `plugins/tce/commands/quickfix.md:185, 231-233` — Skill-delegation of implement
  + final-summary surfacing site.
- `plugins/tce/references/plan-document-template.md:69-85, 127-163` —
  Automated/Manual success-criteria split the gate consumes.
- `thoughts/shared/tickets/TP-0020-plan-compliance-gate.md` — the ticket.

## Architecture Documentation

Relevant conventions this change lives within:

- **Plugins stay project-agnostic** (`CLAUDE.md` core design rule): the new agent
  must not hardcode stack/ticket literals. It reads criteria + diff handed to it;
  it deliberately does **not** read `profile.md`/`tickets.md` (ticket Q4), which
  also keeps it maximally generic.
- **Read-only by tool omission** — the read-only guarantee is enforced by leaving
  `Edit`/`Write`/`Bash` out of the `tools` list, reinforced by the prose
  envelope. The gate follows this exactly.
- **Bare-name agent invocation** — no namespacing, no `${CLAUDE_PLUGIN_ROOT}`
  for agents; agents install to the consuming project's `.claude/agents/`
  (`init.md:127`) and resolve by `name:`.
- **Composite-tracking rule** — the mechanism split (work re-describes; quickfix
  delegates) is the established pattern; both config-drift and sufficiency-check
  gates were propagated this way.
- **TP-0013 re-read rule** — the gate reads its criteria from the plan/ticket at
  the point of use (implement extracts them fresh), consistent with the chain's
  re-read discipline; it does not lean on conversation state.

## Impact Analysis

The gate extends the **implement.md closing contract**, which has two downstream
consumers by the composite-tracking rule.

### Existing consumers of the closing flow
- `plugins/tce/commands/work.md:24` (Phase 4) — re-describes implement's closing
  flow inline; **must be edited** to add the gate step in prose.
- `plugins/tce/commands/quickfix.md:185` — Skill-delegates implement; **inherits**
  the gate; may need a one-line surfacing in its final summary (`:231-233`).

### Current contract
- Input to closing: all phases complete + full test suite green (`implement.md:257`).
- Output: ticket status flips to done per `tickets.md` policy (`:268`), or a
  reminder if policy is "do not transition" (`:271-272`).

### Adaptation requirements
- `implement.md:257→259` boundary — insert the gate section; add the "gate
  passed" precondition to the `:268` done-flip; the no-transition path
  (`:271-272`) still runs the gate (it verifies criteria regardless of who flips
  the status) and reports results.
- `work.md` `### 4d` — transcribe the gate (run → block on not-met → report →
  passing note).
- `quickfix.md` final summary — add the passing/failing surfacing line.

### Backward compatibility options
- **Option A (recommended): gate on every closing.** Consistent, matches AC
  (esp. the autonomous flows). A passing run is a one-line note (AC6), so cost is
  low; a diff-only or read-capable agent run is a single subagent call.
- **Option B: gate only when acceptance/success criteria exist.** Tickets with no
  criteria (tce accepts minimal tickets — `tickets.md` "What tce needs")
  would skip the gate. Simpler-feeling but creates a silent bypass exactly where
  criteria are thin; better handled by the gate reporting "no verifiable
  criteria found" than by skipping.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` Section 3
  item 1 (lines 206-213) — the origin recommendation: "a fresh-context subagent
  that sees only the diff + the plan's success criteria (not the reasoning that
  produced the code) and reports requirement gaps … Anthropic's best-practices
  doc explicitly recommends this adversarial-review-in-clean-context pattern …
  `/tce:review` exists but is heavyweight, optional, and post-hoc". Placement:
  "a small built-in gate at the end of implement/work/quickfix" (line 213). The
  review **leaves hard-block-vs-advisory unspecified** (it says "gate" but only
  "reports") — the ticket AC resolves this toward hard-block.
- Same review, Section 3 item 2 (lines 220-221) — the bias-isolation logic
  ("hiding the ticket's proposed solution to avoid bias") the review deemed
  over-engineering for researchers but which is exactly the principle the gate
  applies to a verifier.
- `thoughts/shared/research/2026-07-05-TP-0018-root-cause-analysis-for-defect-tickets.md`
  — establishes the documentarian-block anatomy (CRITICAL block + What NOT to Do
  + REMEMBER closer across the codebase-* agents) and the bounded-exception
  mechanism this ticket's style requirement points to.

## Related Research

- `thoughts/shared/research/2026-07-05-TP-0018-root-cause-analysis-for-defect-tickets.md`
  — documentarian-rule anatomy and composite-mirroring precedent.
- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md`
  — the re-read discipline the gate's criteria-extraction respects.

## Open Questions

**Design fork for the checkpoint (research found two valid approaches):** how much
the gate agent may inspect beyond the passed diff.

- **Diff + read-only file access (inspector).** Agent tools `Read, Grep, Glob,
  LS`; it may open post-change source to confirm criteria the raw diff can't
  show, but is forbidden to read ticket/plan/research docs (adversarial
  isolation). Matches every existing tce agent; fewer "cannot verify" verdicts;
  handles large diffs (pass changed-file list + diff, agent reads as needed).
- **Diff-only text judge (pure).** Agent gets no file tools; verdicts strictly
  from the inlined diff + criteria; anything not evident → "cannot verify from
  diff". Maximally adversarial and cheapest, but more "cannot verify" verdicts
  fall to humans and large diffs must be inlined whole.

Both satisfy AC1 ("read-only tools" — the inspector's tools are all read-only).
This is surfaced to the user at the Phase 2 checkpoint.

Everything else the ticket's Questions for Research/Planning raised is resolved
by this research: Q1 (diff passed in, not Bash-derived — AC1 forbids Bash); Q2
(criteria passed verbatim, agent does not read ticket/plan — purity); Q3
(placement between `implement.md:257` and `:259`, blocked path mirrors the
`:198-210` STOP template); Q4 (no profile — the gate should know as little as
possible).

## tce Config Drift

None found. `profile.md` accurately describes this repo (markdown/bash/JSON
plugin monorepo; test = `claude plugin validate`; no typecheck; no lint) and
`tickets.md` accurately describes the tmt backend (canonical `TP-NNNN`, files in
`thoughts/shared/tickets/`, tce self-transitions status). No `/tce:refresh`
needed.
