---
date: 2026-11-07
topic: "tce: show the human only what needs the human"
status: complete
---

# Technical Discussion: tce — show the human only what needs the human

## Challenge

About 90% of what tce prints is irrelevant to the person reading it. The
human-facing moments are the intent dialogue, the planner's questions, the plan
brief and the closeout. What the human actually needs at each of them is small:
one or two sentences of context, one specific question, and — once an artifact
is written — its path plus whatever is *extraordinary* about it. Everything
routine (the phases a plan runs through, that tests are included, that the
standard conventions are followed) is noise the human can look up in the file.

Wanted:

- An interactive dialogue: a short question, a free-form answer, no walls of
  text and no dialog boxes.
- Questions only where the answer cannot be inferred from the code, from
  `thoughts/`, or from the project's recorded practice. Scope matching is the
  core ("logically in, but is this edge case in or out? I assume out").
- After an artifact is written: its path, and only what needs the human's eye
  ("this criterion cannot be tested automatically; fine if you test it
  yourself?") — with the context in the line itself, never "criterion 4".
- The human steers how they are asked and what they are shown, per project,
  including terminal highlights from a plugin that is *not* a tce
  precondition.

The two legitimate token spends in tce were restated and both apply here:
tokens for quality of the outcome (challenger, verifier, compliance gate) and
tokens that buy back the human's minutes. The human's time is the scarcest
resource in the project; an extra dispatch that saves reading is a good trade.

## Where the walls come from today

Checked against the shipped prompts (tce 1.7.1):

1. **`/tce:intent`, compressed track, Round 1** (`commands/intent.md`): one
   message carrying the restated understanding, the size reasoning, the
   sufficiency questions *and* a complete first-draft intent filling every
   template section. The full track adds a Phase 7 summary of everything.
2. **Planner questions** (`work-loop.md` Step 6, `work-brief.md`): already the
   right shape — one decision per item, recommended option first,
   `Understood:`/`Approach:` on top — but delivered through AskUserQuestion,
   whose box cannot render formatted context and is hostile to a
   three-sentence answer.
3. **The plan brief** (Step 6 point 4): printed in full, including one line
   per phase, plus the challenger's notes, before the approval question.
4. **Closeout** (Step 11): under Direct delivery the dossier's full text.

Research is already silent. The architecture (one agent per step, returns as
data, artifacts linked by path) is right; what the two "present" moments
choose to show is not.

## Platform facts (verified 2026-11-07)

| Question | Answer | Consequence |
|---|---|---|
| Do subagents receive CLAUDE.md? | **Yes.** Docs: a subagent's initial context contains "every level of the CLAUDE.md hierarchy the main conversation loads". Exceptions: the built-in Explore and Plan agents, and a custom agent with `omitClaudeMd: true` (none of tce's). Probe: a general-purpose agent and `tce:thoughts-locator` both quoted the headings of `~/.claude/CLAUDE.md` and this repo's CLAUDE.md verbatim, using no tools. Auto memory never reaches a subagent. | A presenter agent needs no instruction to read CLAUDE.md; a project's reply-highlight convention (colorify) reaches it. Never use the built-in Explore agent for a step that must see the rules. |
| Why does the loop ask through AskUserQuestion? | A command's `allowed-tools` grant lasts one turn. AskUserQuestion keeps the turn; a prose question ends it, and every shipped-script call after the human's reply would prompt for permission. | Prose questions are free once the scripts are in the project allowlist. |
| Can a Bash allow rule match a path that changes per plugin version? | Docs: `*` in a Bash rule "matches any text, including spaces" and may appear mid-pattern (`Bash(git log * main)`); `~` expansion is documented for Read/Edit only, **not** for Bash; `${CLAUDE_PLUGIN_ROOT}` is not substituted in settings.json; the marketplace cache path changes with every version. Alternative: a plugin's `bin/` directory is on the Bash tool's PATH while the plugin is enabled, so its files run as bare commands. | Candidate rule: `Bash(/Users/<me>/.claude/plugins/*/tce/scripts/stage.sh *)` — absolute home path, mid-path `*`, one entry per script. **Verify on a real run** (and whether the startup warning about a `*` before the subcommand fires for a `*` in a path). Fallback: move the scripts to `bin/` and allow bare names. |
| Terminal rendering | Claude Code collapses a markdown table with prose cells into key/value cards (from the 2026-10-09 discussion). Highlight tags must not sit inside code fences. | Briefs stay headings + short lines; the presenter's text is printed as markdown, never fenced. |

## Decisions

### 1. Management by exception

Every presentation after an artifact is written has three parts, in this
order, and nothing else:

1. **The path** of the artifact, one line.
2. **Always-shown items**, defined per touchpoint by the presentation section
   (e.g. for a plan: decisions made on the human's behalf; for an intent: the
   Out list; for the dossier: the counted-facts line and pending manual items).
3. **Exceptions**: what deviates from the project's recorded practice or from
   what the human would expect — a criterion that cannot be automated, a
   dependency added, a manual step, an open question left open.

Each line is **self-contained**: it carries the thing it is about, never a
reference into the artifact ("criterion 4", "see research.md"). This is the
rule the planner's questions already follow in `work-brief.md`; it now
governs every presented line. If nothing is extraordinary, the output is the
path and one line saying so.

**Decision, tightened.** A decision is a point where a reasonable colleague
in this project might have chosen differently. Following an existing pattern
is not a decision and does not appear under "Decided for you". Without this
the exception list refills with routine items and becomes a wall again.

### 2. Prose dialogue; AskUserQuestion leaves the step loop

Questions are asked as formatted text: one or two sentences of context, the
question, the recommended answer marked, and the human answers free-form.
AskUserQuestion is dropped from the loop and from `/tce:intent`. The grant
problem (platform facts) is solved by decision 3, not worked around.

Consequence for the repo's rules: the byte-identical AskUserQuestion
guidelines block loses its `work-loop.md` copy and the step commands' dialog
exception; the "One turn, kept by AskUserQuestion" paragraph in CLAUDE.md is
rewritten to "the scripts are allowlisted, so a run survives a turn
boundary". Position on disk already makes a run resumable at any point.

### 3. tce's shipped scripts join the `/tce:init` allowlist

"We ship them to be used." `/tce:init` adds one entry per script (`ticket.sh`,
`stage.sh`, `branch.sh`, `baseline.sh`, `work.sh`) on the same per-item
approval as today's entries, and `/tce:refresh` re-offers them when the
resolved plugin path no longer matches. The rule form is the mid-path `*`
candidate above, pending the real-run check; `bin/` is the fallback. The
"never widen it" rule keeps its meaning — no `git push`, no `gh` — the
plugin's own read-only helpers were never what it guarded against.

### 4. A presenter agent, and a brief mode for the challenger

The context that produced an artifact cannot judge what in it matters to the
human — the same principle the plan-compliance checker is built on. So a new
fresh-context, read-only **presenter** agent reads one finished artifact, the
intent, and the profile's presentation section, and returns the human-facing
text (path, always-shown items, exceptions, sample). It never writes. It runs
after the intent is written (dispatched by `/tce:intent`), after the plan is
settled, and for the dossier at closeout. The planner keeps the
questions-first round: that happens before any artifact exists.

Plan flow, in order:

1. Planner writes the plan. Challenger challenges it (unchanged: a second
   opinion with critical questions). Fixes.
2. Presenter returns the brief from the settled plan.
3. Challenger runs once more in **`mode: brief`** with a closed checklist:
   every decision made on the human's behalf appears; nothing appears that the
   plan does not contain; the exceptions are the real exceptions and nothing
   routine slipped in; each line stands on its own; the budget holds. Findings
   go back to the presenter, bounded to one round.

Two modes of one agent, kept separate on purpose: the plan check is open-ended
critique, the brief check is faithfulness. Presenting before challenging was
rejected (the challenge may change the plan and waste the brief).

### 5. The `## Presentation` profile section, three presets at init

A hand-authored sibling of `## Reader`: Reader says who reads, Presentation
says how. Sub-fields:

- **Question style** — prose (the default under Compact).
- **Line budget** — "before any approval the human reads at most N lines";
  overflow is offered **by topic with its count** ("12 more lines on the test
  strategy, 4 on the migration — say which"), never as a bare count. The
  overflow offer is itself a prose question.
- **Always shown** — per touchpoint (intent, plan, dossier).
- **Sample** — "the three statements a careful reviewer would most likely
  push back on", one sentence each, context included, answerable with "fine"
  or "no, because" without opening the file. "Interesting" was rejected as
  the criterion: it invites showing off; "most likely wrong" targets the
  inconsistent spots.
- **Formatting** — free-form. The Compact preset's line reads: "Highlight per
  the reply-highlight convention the project's CLAUDE.md defines, if any;
  otherwise plain markdown." No plugin name in shipped text.

`/tce:init` offers three presets, skeletons under `templates/tce/` (the source
of truth for section structure, like the profile template):

1. **Full** — today's behaviour, byte for byte. Absent section = Full, so an
   un-upgraded project changes nothing.
2. **Compact** — the exception-only style above.
3. **Guided** — an interview that writes a custom section.

Lifecycle per the agreed-sections rule: asked at init, preserved by refresh,
Idempotency bullet, README. Per project only, in the profile; a per-user
overlay (for a machine-specific highlight plugin) is deferred until someone
needs it.

**Highlights.** colorify writes its own `## Highlights in replies` block into
the project's CLAUDE.md, which reaches every agent (platform facts). Only two
of its tags apply to tce — `{!important ...}` for the one or two things to
notice before approving, `{!recommended ...}` for the recommended option —
and both are described generically in that block. So: nothing is copied into
the profile (it would drift), nothing is detected at init, the pointer
sentence above is all. The presenter's text is printed as markdown so the
tags render.

### 6. Standing rules grow from research, with counted evidence

"Anything inferable from best practice is out" only works if best practice
is written where the model is told to look. That place already exists: the
project's **CLAUDE.md** (plus the profile for tce-only matters). No new
decisions file — a standing rule is not a compression of `thoughts/`; past
intents record ticket-scoped decisions, a standing rule is one the human has
promoted to policy. Four behaviours, no new artifact:

1. **Offer to promote.** When the human answers "obviously X, always", the
   command offers to record a one-line rule in CLAUDE.md, per-item approval
   (the same sanctioned edit `/tce:init`'s migration uses).
2. **Mining in research.** The researcher's thoughts agents and the pattern
   finder already walk the material. Two sources: decisions that recur across
   intents and plans with the same outcome ("rejected X in 4 of the last 6
   plans"), and code conventions the pattern finder sees everywhere but nobody
   wrote down ("every handler validates through Y"). Candidates go into the
   research document, each with a one-line proposed rule and its counted
   evidence. A single occurrence is a decision, not a practice.
3. **One closing item in the planner's question round**: "Seen repeatedly,
   record as standing? Answer with the numbers you accept." Only candidates
   not already stated in CLAUDE.md or the profile are shown — an accepted rule
   stops recurring by itself. **Declined** candidates are listed in the
   profile, one line each, so they are not proposed again.
4. **Catch-up at init and refresh.** `/tce:refresh` (and `/tce:init` on an
   upgrade) mines the existing intents' and plans' Decisions sections,
   clusters what recurs, and presents a draft list to pick from — the
   one-time pass over a project's history.

On-the-fly extraction on every run was rejected as the expensive,
non-deterministic version of the same thing.

### 7. Intent dialogue rewritten on the same principles

`/tce:intent` keeps its sufficiency test, sizing and the full track's phase
gates for Large/XL, but every round becomes: two lines of understanding, the
questions (scope matching first, "I assume out" as the default), free-form
answers. The complete-draft dump is replaced by writing the file and
dispatching the presenter: path, Out list, exceptions, sample.

## Rejected alternatives

- **A new `decisions.md` / standing-decisions file** — CLAUDE.md already is
  that file and every session and agent loads it.
- **Deriving practices on the fly each run** — expensive, non-deterministic;
  the researcher's mining plus promotion covers it.
- **AskUserQuestion with context printed above it** — the user's own finding:
  text written in a turn that also calls AskUserQuestion is not reliably
  shown.
- **Keeping AskUserQuestion for the Approve/Stop gate only** — possible, but
  once the scripts are allowlisted there is no reason to keep two question
  mechanisms.
- **Having the challenger write the brief** — it could not then check the
  brief; and its job is critique, not presentation.
- **Copying colorify's block into the profile, or detecting colorify at
  init** — duplication that drifts; CLAUDE.md reaches the agents anyway.
- **A per-user presentation overlay** — overhead with one user; revisit on
  demand.
- **Confidence scores** in any presentation — counted facts only (carried
  over from 2026-10-09).

## Conclusion

Keep the architecture, change what the two "present" moments show, and move
the deciding of what matters into a fresh context. The human reads: a
question with its two lines of context, or a path with the exceptions and a
three-line sample. Everything else is one path away.

Follow-up tickets, in dependency order:

1. **Scripts in the allowlist + prose questions in the loop.** `/tce:init`
   and `/tce:refresh` add the five script entries (real-run check of the
   mid-path `*` rule; `bin/` fallback); `work-loop.md` Step 6 asks in prose;
   the AskUserQuestion block leaves the loop; CLAUDE.md's orchestrator section
   is updated. Unblocks everything below.
2. **`## Presentation` section, presets, presenter agent, challenger brief
   mode.** Template + `init.md` dialogs/fill/Idempotency + `refresh.md` +
   README (the agreed-sections lifecycle); `agents/presenter.md`;
   `plan-challenger.md` gains `mode: brief`; `work-brief.md` becomes the
   presenter's contract (budget, topic overflow, sample, self-contained
   lines, tightened "decision"); Step 6 and Step 11 print the presenter's
   return instead of the brief and the dossier text.
3. **`/tce:intent` dialogue rewrite** on the presenter and the prose style;
   the draft dump goes.
4. **Standing rules.** Researcher candidates with counted evidence (research
   template section), the planner's closing item, the offer-to-promote edit,
   the profile's declined list, refresh/init mining.

### Trade-offs accepted

- **Silent assumptions.** Exception-only presentation means the model decides
  routine points alone and will sometimes decide wrong. Accepted because the
  artifacts are files that can be opened and re-run, every assumption is
  listed after the fact (one push-back to fix), the challenger's brief mode
  checks faithfulness, the sample of three targets the likely-wrong spots,
  and each correction can become a standing rule.
- **One more dispatch per touchpoint** (presenter, plus one challenger
  round). Token spend of the second kind; waiting is cheaper than reading.
- **A wider project allowlist** (tce's own scripts). Read-only helpers;
  `git push`/`gh` stay command-level grants.
- **Prose questions cost a turn** per round; the run resumes from disk, as it
  already does.

## References

Codebase:

- `plugins/tce/commands/intent.md` — compressed track Round 1 (the draft
  dump), full-track phases
- `plugins/tce/references/work-brief.md` — question layout, brief, delta,
  "Phrasing for the reader"
- `plugins/tce/references/work-loop.md` — Step 6 (planning, the only place
  that asks), Step 11 (closeout prints the dossier)
- `plugins/tce/agents/planner.md` — `mode: questions`
- `plugins/tce/commands/init.md` — allowlist step (the cache path changes
  per version; `Read(~/.claude/plugins/**)`), migration edits to CLAUDE.md
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md` —
  the human-facing layer this discussion refines

External:

- https://code.claude.com/docs/en/sub-agents — "What loads at startup":
  CLAUDE.md hierarchy reaches subagents; Explore/Plan and `omitClaudeMd`
  exceptions
- https://code.claude.com/docs/en/permissions — Bash rules: `*` matches any
  text, mid-pattern allowed, `:*` only trailing; `~` documented for Read/Edit
- https://code.claude.com/docs/en/plugins-reference — `bin/` on the Bash
  PATH; `${CLAUDE_PLUGIN_ROOT}` not substituted in permission rules
- colorify's `## Highlights in replies` block (project CLAUDE.md, written by
  `/colorify:setup`; `.claude/colorify.json` holds the tag colours) — tags
  `important` and `recommended` apply to tce
