---
date: 2026-11-07
ticket: TP-0048
ticket_ref: thoughts/shared/tickets/TP-0048-intent-and-plan-approval-output.md
source: thoughts/shared/discussions/2026-11-07-tce-show-the-human-only-what-needs-the-human.md
size: Large
status: agreed
last_updated: 2026-11-07
---

# Intent: show the human only what needs the human

## Ticket

TP-0048 (`thoughts/shared/tickets/TP-0048-intent-and-plan-approval-output.md`).
The ticket is the human's; this file is the agreement on what it means here.
Written directly from the discussion of the same day, at the human's request,
without the intent dialogue. Absorbs the rejected TP-0047.

## Scope

**In:**

1. **Scripts in the allowlist, prose questions in the loop.**
   - `/tce:init`'s allowlist step adds one `Bash` entry per shipped script
     the step commands call (`ticket.sh`, `stage.sh`, `branch.sh`,
     `baseline.sh`, `work.sh`), on the same per-item approval as the existing
     entries; `/tce:refresh` re-offers them when the resolved plugin path no
     longer matches an entry. Entry form: the absolute home path with a
     mid-path `*` for the versioned cache directory (e.g.
     `Bash(/Users/<me>/.claude/plugins/*/tce/scripts/stage.sh *)`), after a
     real-run check; if that form does not match, the scripts move to the
     plugin's `bin/` directory and the entries use bare names.
   - `work-loop.md` Step 6 asks the planner's questions, the push-back
     round and the approval in prose (context, question, recommended answer
     marked, free-form reply) and no longer through AskUserQuestion. A reply
     that arrives in a later turn continues the run; position stays on disk.
   - The AskUserQuestion guidelines block leaves `work-loop.md` (the
     duplicated-block rule drops to nine copies); CLAUDE.md's "One turn, kept
     by AskUserQuestion" bullet is rewritten to the allowlist mechanism.
2. **A `## Presentation` profile section, a presenter agent, a challenger
   brief mode.**
   - `templates/tce/profile.md` gains a hand-authored `## Presentation`
     section beside `## Reader`, with sub-fields: question style, line
     budget, always-shown items per touchpoint (intent, plan, dossier), the
     sample, formatting. `/tce:init` offers three presets — **Full** (today's
     behaviour), **Compact** (exception-only), **Guided** (an interview that
     writes a custom section) — and fills the section; `/tce:refresh`
     preserves it as hand-authored; the Idempotency upgrade list and the
     README describe it. No section means Full.
   - A new fresh-context, read-only `presenter` agent (`agents/presenter.md`)
     reads one finished artifact, the intent and the Presentation section,
     and returns the human-facing text: the artifact's path, the always-shown
     items, the exceptions (what deviates from the project's recorded practice
     or from what the reader would expect), and the sample — the three
     statements a careful reviewer would most likely push back on, one
     sentence each. Every line is self-contained and carries its subject;
     never a reference into the artifact. The budget is the section's line
     count; overflow is offered by topic with its count, never as a bare
     count. It never writes.
   - `work-brief.md` becomes the presenter's contract (the brief, the delta,
     the sample, the budget and overflow rule, the tightened meaning of a
     decision: a point where a reasonable colleague might have chosen
     differently — following an existing pattern is not one). The planner's
     questions-first round and its question layout stay in it.
   - `plan-challenger.md` gains `mode: brief`: after the plan is settled and
     the presenter has returned the brief, it checks a closed list — every
     decision made on the human's behalf appears; nothing appears the plan
     does not contain; the exceptions are the real ones and nothing routine
     slipped in; each line stands on its own; the budget holds — and its
     findings go back to the presenter for at most one round. Its existing
     checklist item 6 ("Brief faithful") moves into that mode.
   - `work-loop.md` Step 6 runs plan → challenge → fixes → presenter →
     challenger brief mode → print, then asks for approval; Step 11 prints
     the presenter's return for the dossier instead of the dossier's text.
3. **`/tce:intent` on the same principles.** Each round of both tracks is
   two lines of understanding, the questions (scope matching first, "I
   assume out" as the recommended answer), free-form replies. The compressed
   track's complete-draft message and the full track's Phase 7 summary are
   replaced by writing the intent and dispatching the presenter (path, Out
   list, exceptions, sample). The sufficiency test, sizing, the full track's
   phase gates for Large/XL and `--autonomous` keep their substance.
4. **Standing rules.**
   - The `researcher` records **practice candidates** in the research
     document (a new template section): decisions that recur across intents
     and plans with the same outcome, and code conventions the pattern finder
     sees everywhere but nobody wrote down — each with a one-line proposed
     rule and its counted evidence. One occurrence is not a candidate.
     Candidates already stated in CLAUDE.md or the profile, or listed as
     declined, are omitted.
   - The `planner`'s `mode: questions` return carries the candidates as one
     closing item ("seen repeatedly, record as standing? answer with the
     numbers you accept"); the loop asks it with the other questions.
   - Accepted rules are appended to the project's CLAUDE.md one line each,
     per-item approval, the sanctioned-edit pattern of `/tce:init`'s
     migration; declined candidates go into a profile list (one line each)
     so they are not proposed again. When the human answers any question
     with "always X", the loop offers the same promotion.
   - `/tce:refresh` (and `/tce:init` on an upgrade) mines the existing
     intents' and plans' `## Decisions` sections, clusters what recurs and
     presents a draft list to pick from.
5. tce version bump; the human creates the tag outside the sandbox.

**Out:**
- A per-user presentation overlay (machine-specific highlights) — profile
  only; revisit on demand.
- Copying any highlight plugin's convention into the profile or detecting
  such a plugin at init — the Compact preset's formatting line points at
  "the reply-highlight convention the project's CLAUDE.md defines, if any".
- A new standing-decisions file — CLAUDE.md and the profile are the places.
- Deriving practices on the fly on every run beyond the researcher's pass.
- tsf, tle and tmt dialog sites (cross-plugin rule; tmt's two copies of the
  AskUserQuestion block stay).
- Changing the three-part sufficiency test or its two copies (TP-0022).
- The ticket is never written.

## Observable outcome

In a consuming project on the Compact preset, a `/tce:work <ID>` run shows the
human, before implementation starts, only: the planner's questions (each with
one or two lines of context, answered in prose), then the plan's path, the
decisions made on their behalf, the exceptions and three likely push-backs,
within the budget; at the end, the dossier's path, its counted facts, pending
manual items and exceptions. `/tce:intent <ID>` shows the same shape after
writing. No AskUserQuestion box appears, no permission prompt interrupts a
run after a prose reply, and a project without a `## Presentation` section
behaves exactly as tce 1.7.1 does. Research documents list practice
candidates with counts, the planner asks about them once, and an accepted
rule appears in CLAUDE.md and is never proposed again.

## Anchors

- `plugins/tce/commands/intent.md` — Compressed discussion Round 1 (the
  draft dump), Full discussion Phase 7, Writing the intent
- `plugins/tce/references/work-loop.md` — Step 6 (planning, the only place
  that asks), Step 11 (closeout prints the dossier), the AskUserQuestion
  guidelines copy
- `plugins/tce/references/work-brief.md` — question layout, brief, delta,
  "Phrasing for the reader"
- `plugins/tce/agents/planner.md` (`mode: questions`),
  `agents/plan-challenger.md` (six-item checklist, item 6 "Brief faithful"),
  `agents/researcher.md`, `agents/verifier.md` (dossier mode)
- `plugins/tce/references/research-document-template.md`,
  `references/dossier-template.md`, `references/intent-document-template.md`
- `plugins/tce/templates/tce/profile.md` (`## Reader` at line 123, the
  agreed-section lifecycle), `commands/init.md` (allowlist step: the cache
  path "changes with every version"), `commands/refresh.md`
- `plugins/tce/scripts/` — `ticket.sh`, `stage.sh`, `branch.sh`,
  `baseline.sh`, `work.sh` (the five the step commands grant)
- `CLAUDE.md` — "tce: the step commands are orchestrators" (one-turn grant,
  allowlist "never widen"), "Agreed profile sections", "The AskUserQuestion
  guidelines block is duplicated"

## Acceptance criteria

- [ ] `/tce:init` and `/tce:refresh` offer the five script entries; with
      them in `permissions.allow`, a `/tce:work` run whose planner question
      was answered in a later turn reaches the dossier without a permission
      prompt (real run in a consuming project).
- [ ] `work-loop.md` contains no AskUserQuestion site; the guidelines block
      exists in exactly nine files; CLAUDE.md's orchestrator section
      describes the allowlist mechanism.
- [ ] `templates/tce/profile.md` has `## Presentation`; `/tce:init` offers
      Full, Compact and Guided and fills it; `/tce:refresh` lists it as
      hand-authored; the Idempotency list and the README mention it; a
      profile without the section produces output byte-identical to 1.7.1.
- [ ] `agents/presenter.md` exists, is read-only (`Read, Grep, Glob, LS`),
      and its return follows `work-brief.md`: path, always-shown items,
      self-contained exceptions, three push-back candidates, budget with
      topic-named overflow.
- [ ] `plan-challenger.md` has `mode: brief` with the five-point list;
      Step 6 runs it after the presenter, bounded to one round.
- [ ] Step 6 and Step 11 print the presenter's return; the printed brief
      carries no per-phase list and the dossier's text is not printed.
- [ ] `/tce:intent` prints neither a complete draft nor a Phase 7 summary;
      after writing it prints the presenter's return.
- [ ] The research template has a practice-candidates section with counted
      evidence; the planner's `mode: questions` return carries them as one
      closing item; an accepted rule is appended to CLAUDE.md on approval and
      a declined one lands in the profile's declined list; `/tce:refresh`
      presents a mined draft list.
- [ ] The step agents still receive CLAUDE.md (no `omitClaudeMd`), and no
      step uses the built-in Explore or Plan agent.
- [ ] tce version bumped in `plugin.json` and `marketplace.json`; tag
      handed over.

## Decisions

- **Prose questions everywhere, AskUserQuestion out of tce's loop and
  intent** — over keeping the dialog for the Approve/Stop gate: once the
  scripts are allowlisted there is no reason for two question mechanisms,
  and the box cannot render context.
- **The shipped scripts join the init allowlist** — over re-invoking the
  command after each prose reply (TP-0047's idea): the "never widen" rule
  guards `git push` and `gh`, not read-only helpers tce ships to be used.
- **A fresh-context presenter decides what matters** — over the planner
  presenting its own plan: the context that wrote an artifact cannot judge
  what in it is extraordinary (the plan-compliance checker's principle).
- **Present after challenging** — over presenting first: the challenge may
  change the plan and waste the brief.
- **Challenger brief mode as a second mode of the same agent** — over a
  separate faithfulness agent or folding the check into the presenter:
  same fresh-eyes property, and an agent cannot check its own brief.
- **"Most likely push-back" as the sample criterion** — over "most
  interesting": it targets inconsistent spots instead of inviting the model
  to show off.
- **Overflow offered by topic with counts** — over a bare "N more lines?":
  the human decides without seeing them.
- **CLAUDE.md and the profile hold standing rules** — over a new decisions
  file: every session and agent already loads CLAUDE.md; a standing rule is
  a promoted policy, not a compression of `thoughts/`.
- **Candidates mined in research with counted evidence** — over on-the-fly
  extraction each run: the researcher's agents already walk the material;
  anything else is the expensive non-deterministic version.
- **Highlights by pointer** — over copying colorify's block or detecting
  the plugin: the block reaches every agent through CLAUDE.md (verified
  2026-11-07) and a copy would drift.
- **Profile only, no per-user overlay** — over a gitignored local file: one
  user today; overhead until someone asks.
- **One ticket for four items** — over four tickets: the human's explicit
  choice to test a large ticket on the new tce.

## Open questions

None.

## Questions for research

- [ ] Does a `Bash` allow rule with a mid-path `*` and an absolute home path
      match the plugin's versioned cache path on a real run, and does the
      startup warning about a `*` before the subcommand fire for it? If not,
      what does moving the scripts to `bin/` entail for every
      `${CLAUDE_PLUGIN_ROOT}/scripts/` reference and `allowed-tools` grant?
- [ ] Which `work-loop.md` steps after Step 6 call which scripts (the exact
      set the allowlist must cover), and does `/tce:intent`'s closing
      `/tce:commit` need the same treatment after a prose round?
- [ ] How does the presenter receive the artifact and the intent — paths in
      the dispatch payload per `work-dispatch.md` — and which spans in
      CLAUDE.md (loop, return shape, brief layout) does the new agent join?
- [ ] Where in `plan-challenger.md`'s return shape does a `mode:` fit, and
      does `agent-returns.md` need a new status for brief findings?
- [ ] What does `/tce:init`'s Guided interview ask, and how do the three
      presets map onto the section's sub-fields in the template?
- [ ] For the research mining: which thoughts agents already read
      `## Decisions` sections, and what is the cheapest way to count
      recurrences across intents and plans?
- [ ] Which existing projects' profiles lack `## Presentation` (all), and
      does the version marker comparison in `work.sh preflight` need a new
      warning for it?

## Notes

- Size Large: four coupled changes across the loop, the profile lifecycle,
  two agents (one new) and the intent command, bundled on purpose; Extra
  Large would normally mean splitting, which the human declined.
- Platform facts the design rests on, verified 2026-11-07 and recorded in
  the discussion: subagents receive the CLAUDE.md hierarchy (exceptions:
  Explore, Plan, `omitClaudeMd`); a command's `allowed-tools` grant lasts one
  turn; `*` in a Bash rule matches any text mid-pattern, `~` is documented
  for Read/Edit only, `${CLAUDE_PLUGIN_ROOT}` is not substituted in
  permission rules; a plugin's `bin/` is on the Bash PATH.
- Dependency order for planning: item 1 unblocks the prose dialogue every
  later item relies on; item 2 before item 3 (intent uses the presenter);
  item 4 is independent of 2 and 3 but uses item 1's prose round.
