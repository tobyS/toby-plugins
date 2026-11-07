# TP-0048: Show the Human Only What Needs the Human — Implementation Plan

## Overview

tce 1.7.1 asks through AskUserQuestion to keep a run inside one turn, prints the
planner's own brief and the dossier's full text, and dumps a complete draft in
`/tce:intent`. This plan makes every tce question a prose question (the five
shipped scripts move into the `/tce:init` allowlist so a later-turn reply runs
without prompts), adds a `## Presentation` profile section with Full / Compact /
Guided presets, a fresh-context `presenter` agent that writes all human-facing
summaries, a `mode: brief` for the plan challenger that checks the presenter's
brief, rewrites `/tce:intent`'s rounds on the same principles, and grows standing
rules from counted research candidates into the project's CLAUDE.md. It ends
with the tce 1.8.0 release.

## Current State Analysis

From the research (`thoughts/shared/research/2026-11-07-TP-0048-show-the-human-only-what-needs-the-human.md`):

- Script grants live only in the step commands' `allowed-tools` and last one
  turn; `/tce:init`'s allowlist (`commands/init.md:580-652`) has no script
  entries; `/tce:refresh` never touches `settings.json`.
- `work-loop.md` asks through AskUserQuestion at Step 6 (`:212-251`) and
  Step 12 (`:337-359`); invariant 5 (`:75-76`) states the one-turn reason; the
  guidelines block (`:31-49`) plus the planner exception (`:51-55`) sit there.
- `commands/intent.md` has the block (`:52-70`), the existing-intent dialog
  (`:187-192`), the verbatim base-branch dialog (`:160-175`) and AskUserQuestion
  business questions (`:264-267`); compressed Round 1 prints a complete draft
  (`:247-262`), full-track Phase 7 a summary (`:347-351`).
- The planner writes and returns the brief (`agents/planner.md:116-172`,
  `references/work-brief.md:66-122`); Step 6 prints it verbatim; Step 11 point 4
  (`work-loop.md:333-335`) prints the dossier's text under Direct.
- `plan-challenger.md` has no `mode:`; checklist item 6 is "Brief faithful"
  (`:57-60`); it returns `step: challenge`.
- `agent-returns.md:44-46` has a closed `step:` list; only the planner writes a
  body (`:72-83`).
- Agreed profile sections share one lifecycle (template, init gather + dialog +
  fill + Idempotency, refresh's four hand-authored sites, README).
- No tce file mentions standing rules or a declined list; 7 intents and 9 plans
  carry `## Decisions`, and intent decisions are copied into plans and dossiers.

## Desired End State

- No tce command or reference asks through AskUserQuestion except `/tce:init`,
  `/tce:refresh` and `/tce:ticket`; the guidelines block exists in exactly eight
  files, byte-identical.
- `/tce:init` and `/tce:refresh` offer five script entries; a `/tce:work` run
  answered in a later turn reaches the dossier without a permission prompt
  (except, under Pull request delivery, the push and pull-request commands,
  which stay ungranted by design).
- Every human-facing summary — the plan brief and delta, the dossier summary,
  the intent summary — is the `presenter` agent's return, shaped by the
  profile's `## Presentation` section; with no section the presenter uses the
  **Full** preset, which carries the same sections 1.7.1's brief, dossier and
  intent output carried, plus exceptions and three likely push-backs.
- `plan-challenger` has `mode: plan` (five items) and `mode: brief` (five
  points), and Step 6 runs plan → challenge → fixes → presenter → brief check
  (one round) → print → prose approval.
- Research documents carry `## Practice candidates` with counted evidence; the
  planner asks about them once; accepted rules land in the project's CLAUDE.md,
  declined ones in the profile, and `/tce:refresh` offers a mined catch-up list.

Verify: the per-phase criteria below, `claude plugin validate` for the
marketplace and all four plugins, and one real `/tce:work` run in a consuming
project on the Compact preset.

### Key Discoveries:

- The intent's rule shape `…/.claude/plugins/*/tce/scripts/x.sh *` is denied;
  `/Users/<me>/.claude/plugins/cache/*/tce/*/scripts/x.sh *` matched quoted
  and unquoted on Claude Code 2.1.319 (research §2).
- A directory-sourced install resolves `${CLAUDE_PLUGIN_ROOT}` to the source
  directory — the same split `init.md:583-592` already makes for `Read`.
- After Step 6 the loop calls `stage.sh`, `work.sh artifact`, `baseline.sh`
  (`work-loop.md:189-201,255-273`); a resumed run re-enters Steps 0-3, so all
  five scripts must be covered.
- `quickfix.md:78-80` reads the brief's `Phases:` count; `stage.sh`'s
  `progress:` line (`scripts/stage.sh:16`) carries the phase total `/<m>` for
  any plan, so the count survives a Compact brief.
- `work-dispatch.md:141-148` resumes the planner by `SendMessage` "within this
  turn" — the prose round needs that wording widened to a later turn.
- Mining must strip fenced code and count once per ticket (intent decisions
  reappear in plans and dossiers; research §8).

## What We're NOT Doing

- A per-user presentation overlay; detecting or copying any highlight plugin's
  convention (the Compact formatting line points at "the reply-highlight
  convention the project's CLAUDE.md defines, if any").
- A new standing-decisions file; on-the-fly practice derivation beyond the
  researcher's pass.
- tsf, tle and tmt dialog sites — their five block copies stay.
- The three-part sufficiency test and its two copies (TP-0022).
- Allowlisting `git push` or `gh` — under Pull request delivery those may
  prompt once after a prose approval.
- Changing `work.sh preflight` — its generic "profile older" warning already
  fires after the version bump.
- Writing the ticket.
- Running `/tce:init` on this repository's own profile (that is a follow-up
  the human runs).

## Implementation Approach

Seven phases in the intent's dependency order. Every phase that changes a
CLAUDE.md same-commit span updates every file of that span and the matching
CLAUDE.md text **in the phase's own commit** — the spans (loop, return shape,
brief and question layout, AskUserQuestion block, agreed profile sections,
TP-0031 branch span, TP-0013 re-read list, refresh-tracks-init) are never left
half-updated between phases. Phase 1 switches to prose with today's planner
brief still in place, so the loop is runnable after every phase; Phases 3 and 4
then move presentation to the presenter. Rejected: one phase per touched
file — the same-commit spans would be split across commits.

**Riskiest assumption:** after a prose reply in a later turn, nothing outside
the five scripts prompts — neither the Skill call to `tce:commit` (which grants
its own `branch.sh` only inside its skill turn) nor resuming the planner by
`SendMessage` in a turn other than the one that dispatched it. Neither is
documented; Phase 1's manual run checks both. If either prompts, the fallback
is a fresh dispatch (the planner re-reads from disk) and, for the commit, a
note in the allowlist step — never a new allowlist key without a plan revision.

## Decisions

- **Prose questions everywhere, AskUserQuestion out of tce's loop and intent** — over keeping the dialog for the Approve/Stop gate: once the scripts are allowlisted there is no reason for two question mechanisms, and the box cannot render context. *(yours)*
- **The shipped scripts join the init allowlist** — over re-invoking the command after each prose reply: the "never widen" rule guards `git push` and `gh`, not read-only helpers tce ships to be used. *(yours)*
- **A fresh-context presenter decides what matters** — over the planner presenting its own plan: the context that wrote an artifact cannot judge what in it is extraordinary. *(yours)*
- **Present after challenging** — over presenting first: the challenge may change the plan and waste the brief. *(yours)*
- **Challenger brief mode as a second mode of the same agent** — over a separate faithfulness agent or folding the check into the presenter: same fresh-eyes property, and an agent cannot check its own brief. *(yours)*
- **"Most likely push-back" as the sample criterion** — over "most interesting": it targets inconsistent spots. *(yours)*
- **Overflow offered by topic with counts** — over a bare "N more lines?": the human decides without seeing them. *(yours)*
- **CLAUDE.md and the profile hold standing rules** — over a new decisions file: every session and agent already loads CLAUDE.md. *(yours)*
- **Candidates mined in research with counted evidence** — over on-the-fly extraction each run: the researcher's agents already walk the material. *(yours)*
- **Highlights by pointer** — over copying a highlight plugin's block or detecting the plugin: the block reaches every agent through CLAUDE.md and a copy would drift. *(yours)*
- **Profile only, no per-user overlay** — over a gitignored local file: one user today. *(yours)*
- **One ticket for four items** — over four tickets: the human's explicit choice. *(yours)*
- **Script rules use the corrected wildcard `<home>/.claude/plugins/cache/*/tce/*/scripts/<x>.sh *` for a marketplace install and the absolute source path for a directory-sourced one** — over moving the scripts to `bin/`: the corrected form matched on a real run and `bin/` would rewrite 48 references and block claude.ai/Cowork installs. *(yours)*
- **`/tce:intent`'s existing-intent and base-branch dialogs become prose; the guidelines block drops to eight copies** — over keeping them and nine copies: one question mechanism, as the intent's first decision says. *(yours)*
- **Questions are prose regardless of the Presentation section** — over keeping the dialog for projects without the section: no second mechanism in `work-loop.md`. *(yours)*
- **The presenter always runs; Full is a presenter preset with today's sections, and the intent's "byte-identical to 1.7.1" criterion is superseded** — over skipping the presenter under Full: one presentation path everywhere. Under Full the brief keeps its per-phase list; "no per-phase list" and "no complete draft" hold for Compact and Guided. *(yours)*
- **Compact's line budget is 20 lines** — over 12 or 35: fits the path, the decisions, the exceptions and three push-backs for a typical plan. *(yours)*
- **Step 12's closing check also becomes a prose question** — over keeping its dialog: the intent's criterion requires no AskUserQuestion site in `work-loop.md`. *(decided for you)*
- **Under Pull request delivery, `git push` and `gh pr create` may prompt once after a prose approval** — over allowlisting them: the intent keeps "never `git push`, never `gh`" as the allowlist's guard. *(decided for you)*
- **The brief drops "Decisions for you"; a question that arises while writing returns `needs decision` and is asked as a prose round** — over keeping a second in-brief ask path: the questions-first round covers it, and the presenter does not own questions. *(decided for you)*
- **On push-back the planner returns a one-line-per-change list, and the presenter renders the delta from it and the plan** — over the presenter diffing two plan versions: the presenter is read-only without `git`. *(decided for you)*
- **The planner's `mode: brief` is removed; position row 8 dispatches the presenter** — over keeping a planner-written brief for resumed runs: one author of human-facing text. *(decided for you)*
- **New `step:` values `present` and `brief-check`; the presenter may write a body** — over reusing `brief` and `challenge`: the orchestrator tells the returns apart by `step:`. *(decided for you)*
- **The brief check runs on plan briefs and deltas only, not on the intent or dossier summaries** — over checking every presentation: the intent scopes the check to the plan. *(decided for you)*
- **After the one brief-check round, the brief is printed with any remaining fail lines under "Challenger notes:"** — over stopping the run: the intent bounds the check to one round and a stop would cost an approval for a wording issue. *(decided for you)*
- **`/tce:quickfix`'s not-small stop reads the phase total from `stage.sh`'s `progress:` line** — over the brief's `Phases:` line: Compact drops it. *(decided for you)*
- **`/tce:intent` writes and commits the intent after its last question round, then presents it; corrections rewrite it in place** — over a separate "ready to write?" round: the presenter's return is the human's check. *(decided for you)*
- **`/tce:intent` dispatches the presenter without the foreground preflight** — over requiring the two environment variables: the presenter dispatches nothing itself, so a background run only delays its single result. *(decided for you)*
- **Guided asks four things — line budget, items shown per touchpoint, the sample on or off, formatting — and writes a Custom section** — over a free-form description: the presenter needs the same sub-fields under every preset. *(decided for you)*
- **The preset choice in `/tce:init` uses its existing AskUserQuestion dialog style** — over prose: init keeps its block, and three fixed options fit a dialog. *(decided for you)*
- **Practice candidates come from the documents the researcher's thoughts pass already reads for this ticket, counted once per ticket, two tickets minimum** — over scanning every intent and plan on each research run: the full scan is `/tce:refresh`'s catch-up. *(decided for you)*
- **The orchestrator appends accepted rules under a `## Standing rules` heading at the end of the project's CLAUDE.md and writes declined ones into a hand-authored `## Declined standing rules` profile section** — over agents writing them: agents write only under `thoughts/shared/`. *(decided for you)*
- **`/tce:refresh` gains an allowlist re-offer and a read-only mining pass through `tce:thoughts-analyzer`** — over leaving both to `/tce:init`: the intent assigns both to refresh, and refresh still never writes under `thoughts/`. *(decided for you)*
- **Release as tce 1.8.0** — over 2.0.0: no config file breaks; new behaviour is a minor bump, as for 1.5.0, 1.6.0 and 1.7.0. *(decided for you)*

## Phase 1: Prose questions and the script allowlist

### Overview

Every tce question outside init/refresh/ticket becomes prose; the five scripts
join the allowlist so a reply in a later turn continues the run. The planner
still writes the brief in this phase.

### Changes Required:

#### 1. The loop asks in prose

**File**: `plugins/tce/references/work-loop.md`
**Changes**:
- Delete the AskUserQuestion block (`:31-49`) and the planner exception
  (`:51-55`); replace them with a short `### Asking in prose` section: context
  lines first, then numbered questions, each with its options, the recommended
  one marked "(recommended)", and "reply with the numbers and letters, or in
  your own words". End the turn after asking. A reply in a later turn
  continues the run from the step that asked; nothing about the ask is kept
  except what is on disk and the planner's agent ID.
- Header comment `:12-13` and contents `:16`: drop the block mention.
- Invariant 5 (`:75-76`) → "**Ask in prose and end the turn.** The scripts the
  loop calls are in the project's allowlist (`/tce:init`), so a reply in a
  later turn runs without prompts; without those entries a later turn prompts
  once per script."
- Step 6 point 2 (`:215-227`): print `Understood:` / `Approach:` and the
  questions as returned, in the prose layout; map the reply onto each
  question's `Header:` label for `answers:`.
- Step 6 point 4 (`:233-251`): "Decisions for you" asked in the same prose
  layout; the approval becomes: "Approve the plan? Reply **approve** to start
  implementation, **stop** to keep the plan and come back later with
  `<command> <argument>`, or write your push-back." Any other text is a
  push-back, as today.
- Step 12 (`:343-359`): "Have you checked the items above? Reply **all pass**,
  **not yet**, or describe what failed." Same three branches.

**File**: `plugins/tce/references/work-dispatch.md`
**Changes**: `:96-98` — `answers:` carries "each question's `Header:` label and
the human's answer"; `:141-148` — resume with `SendMessage` also in a later
turn; re-dispatch fresh when the ID is lost or the resume fails.

**File**: `plugins/tce/references/work-brief.md`
**Changes**: `:54-61` — drop "AskUserQuestion's limit" and the copy-into-dialog
paragraph; state that `Header:` is the short label the human's answer is filed
under, at most 4 options per question. `:93` — "asked in prose before
approval".

**File**: `plugins/tce/agents/planner.md`
**Changes**: `:45-46` — `answers:` arrive under each question's `Header:` label.

**Files**: `plugins/tce/commands/plan.md` (`:35-45`), `quickfix.md` (`:70-75`, "without the
approval question"), `work.md` (any "dialog" wording)
**Changes**: lane wording only.

#### 2. `/tce:intent`'s dialog sites become prose

**File**: `plugins/tce/commands/intent.md`
**Changes**:
- Delete the block (`:52-70`); add a two-line note that every question is
  asked in prose.
- Base-branch stop-and-ask (`:160-175`): keep it the one verbatim copy, as a
  prose question with the same options (reply `local` / `stop`, or the
  original option words).
- Existing intent (`:187-192`): "Reply **update** or **leave**."
- Business questions (`:264-267`): prose, recommended answer marked.

#### 3. The allowlist carries the scripts

**File**: `plugins/tce/commands/init.md`
**Changes**:
- Phase 4 step 6 (`:580-608`): new bullet "tce's scripts": one entry per
  `ticket.sh`, `stage.sh`, `branch.sh`, `baseline.sh`, `work.sh`. A marketplace
  install (`${CLAUDE_PLUGIN_ROOT}` under `~/.claude/plugins/`) →
  `Bash(<home>/.claude/plugins/cache/*/tce/*/scripts/<x>.sh *)` with `<home>`
  written out as the absolute path (`~` is not expanded in Bash rules), so the
  entry survives version updates. Otherwise → `Bash(<plugin root>/scripts/<x>.sh *)`.
  Keep "**Never** `git push` and never `gh`" and add one sentence on why the
  scripts are different (read-only or tce-scoped helpers the loop calls after a
  prose reply). Extend the verbatim intro/dialog copy (`:609-646`) to list the
  script entries.
- Idempotency: add a "tce 1.8.0" bullet: the every-re-run allowlist check
  (`:717-723`) now also offers the five script entries.

**File**: `plugins/tce/commands/refresh.md`
**Changes**: new step at the end of Phase 3: compute the same five entries
(described in its own words, per the refresh-tracks-init rule); when
`permissions.allow` holds none matching the resolved plugin root, show the
missing entries and ask (AskUserQuestion, under its own block); append
surgically on approval, no other key, no removal.

#### 4. Docs and CLAUDE.md

**File**: `plugins/tce/README.md`
**Changes**: `:288` planning "in a dialog" → in prose; allowlist section
(`:335-361`) lists the script entries and the push/gh exception.

**File**: `CLAUDE.md`
**Changes**:
- "tce: the step commands are orchestrators" — rewrite "One turn, kept by
  AskUserQuestion" (`:439-442`) as "**Prose questions, kept by the
  allowlist**"; the allowlist bullet (`~:449-457`) adds the five script entries
  and `/tce:refresh`'s re-offer, keeping "never `git push`, never `gh`".
- "The AskUserQuestion guidelines block is duplicated" (`:1368-1389`): eight
  copies, list without `intent.md` and `work-loop.md`, drop the loop-copy
  paragraph and the planner-exception sentence.
- TP-0031 section: `intent.md`'s stop-and-ask is a prose question, still the
  one verbatim copy.
- "Agreed profile sections" / tsf settings.json paragraph: name `/tce:refresh`'s
  allowlist re-offer as part of tce's sanctioned `settings.json` edit.

### Success Criteria:

#### Automated Verification:

- [x] Test: `grep -c 'AskUserQuestion' plugins/tce/references/work-loop.md plugins/tce/commands/intent.md` prints `0` for both
- [x] Test: `grep -rl '^### AskUserQuestion dialog guidelines' plugins | wc -l` prints `8`
- [x] Test: `for f in $(grep -rl '^### AskUserQuestion dialog guidelines' plugins); do sed -n '/^### AskUserQuestion dialog guidelines/,/question accordingly\./p' "$f" | shasum; done | sort -u | wc -l` prints `1`
- [x] Test: `grep -c 'scripts/\*\|cache/\*/tce/\*/scripts' plugins/tce/commands/init.md` is at least 1, and `grep -n 'git push' plugins/tce/commands/init.md` still shows the "Never" sentence
- [x] Test: `for s in ticket stage branch baseline work; do grep -q "$s\.sh" plugins/tce/commands/init.md || echo "init missing $s"; grep -q "$s\.sh" plugins/tce/commands/refresh.md || echo "refresh missing $s"; done` prints nothing, and `grep -n 'cache/\*/tce/\*/scripts' plugins/tce/commands/refresh.md` matches (refresh offers the same entries)
- [x] Test: the rule exactly as init.md now spells it matches a real call: take the marketplace entry for `stage.sh` from `grep -o 'Bash(<home>/.claude/plugins/cache/[^)]*)' plugins/tce/commands/init.md`, replace `<home>` with `/Users/toby` and `<x>` with `stage` (if init.md spells the script name literally, no `<x>` replacement), write it as the only `permissions.allow` entry of a settings file in the session scratchpad, and run `claude -p --model haiku --setting-sources user --settings <that file>` asking it to run `"/Users/toby/.claude/plugins/cache/toby-plugins/tce/1.7.1/scripts/stage.sh" FAKE-0001`; the JSON result shows `permission_denials: []`. Fails if init.md carries no such entry or spells it in a form that does not match
- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce`, `./plugins/tmt`, `./plugins/tle`, `./plugins/tsf` pass

#### Manual Verification:

- [ ] In a consuming project with the five script entries in `permissions.allow` (trusted folder, interactive), a `/tce:plan <ID>` run whose questions are answered in the next turn reaches the brief and the approval question without a permission prompt; note whether the Skill call to `tce:commit` or the planner's `SendMessage` resume in the later turn prompted (the riskiest assumption)

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `eadfb2991cc3d6fa5cee1bee1614fea38a74d560`
- **Commit**: `04979a3` feat(TP-0048): ask in prose and allowlist tce's scripts
- **Did**: prose questions in work-loop.md (Steps 6, 12, invariant 5), intent.md (block removed, 3 sites); work-brief/dispatch/planner/lanes wording; script entries in init.md (+1.8.0 Idempotency) and refresh.md; README, CLAUDE.md
- **Issues**: refresh's in-sync early stop would skip the re-offer → it now jumps to "Script allowlist" at the end of Phase 3
- **Verification**: ✅ grep/checksum criteria (0 sites, 8 copies, 1 hash), ✅ `claude -p` probe of init.md's rule (`permission_denials: []`), ✅ validate ×5
- **Fix rounds**: 0/3

---

## Phase 2: The `## Presentation` profile section

### Overview

The section, its three presets and its lifecycle across template, init, refresh
and README. Nothing reads it yet besides init and refresh.

### Changes Required:

#### 1. Template

**File**: `plugins/tce/templates/tce/profile.md`
**Changes**: insert after `## Reader` (`:123-137`) a `## Presentation` section:
intro naming its readers (the `presenter` agent, `/tce:intent`, the loop's
questions), then `[Filled by /tce:init with one of: …]` holding the three
presets as full sub-field sets:

```markdown
- **Full** — the same sections tce has always shown, plus exceptions and
  likely push-backs. (The default — identical to leaving this section out.)
  - **Questions:** prose; two lines of context per question; recommended answer marked.
  - **Line budget:** 60
  - **Intent shows:** path, Scope In and Out, outcome, acceptance criteria, decisions, exceptions, sample
  - **Plan shows:** path, understanding and approach, decisions made for you, phases, risk, exceptions, sample
  - **Dossier shows:** path, counted facts, what was built, decisions made for you, items for you to check, concerns, exceptions
  - **Sample:** the three statements a careful reviewer would most likely push back on
  - **Formatting:** headings and short bullets
- **Compact** — only what needs you.
  - **Questions:** prose; one or two lines of context per question; recommended answer marked.
  - **Line budget:** 20
  - **Intent shows:** path, Out list, exceptions, sample
  - **Plan shows:** path, decisions made for you, exceptions, sample
  - **Dossier shows:** path, counted facts, items for you to check, exceptions
  - **Sample:** the three statements a careful reviewer would most likely push back on
  - **Formatting:** the reply-highlight convention the project's CLAUDE.md defines, if any; otherwise headings and short bullets
- **Custom** — written by the Guided interview, same sub-fields.
```

#### 2. Init

**File**: `plugins/tce/commands/init.md`
**Changes**: gather item 11 (`:156-161`) adds Presentation (nothing to
detect); Phase 2 gets a verbatim Presentation dialog after the Reader prompt
(`:385-401`) — AskUserQuestion, header "Summaries", options **Compact
(Recommended)**, **Full**, **Guided** with one-line descriptions; Guided runs a
four-question prose interview (line budget; items per touchpoint, offered from
Full's lists; sample on or off; formatting) and fills **Custom**. Refine list
(`:409-412`) adds presentation. Phase 4 fill (`:461-471`) keeps the chosen
preset's bullet with its sub-fields. Idempotency: the tce 1.8.0 bullet inserts
`## Presentation` after `## Reader` and runs the dialog; declining leaves it
absent (= Full).

#### 3. Refresh and README

**File**: `plugins/tce/commands/refresh.md`
**Changes**: add `## Presentation` at the four hand-authored sites (`:32-35`,
`:93-94`, `:109-112`, `:137-138`).

**File**: `plugins/tce/README.md`
**Changes**: config tree (`:175`) and a Presentation bullet after Reader
(`:429-433`) naming the presets and "no section means Full".

**File**: `CLAUDE.md`
**Changes**: "Agreed profile sections" (`:393-409`) becomes "Delivery, Reader
and Presentation"; readers of `## Presentation` listed; the RULE covers the new
section.

### Success Criteria:

#### Automated Verification:

- [x] Test: `grep -n '^## Presentation' plugins/tce/templates/tce/profile.md` prints one line after `^## Reader`
- [x] Test: `grep -c 'Presentation' plugins/tce/commands/refresh.md` is at least 4; `grep -n 'Compact\|Guided' plugins/tce/commands/init.md` shows the dialog and the Idempotency bullet
- [x] Test: `grep -n 'Presentation' plugins/tce/README.md CLAUDE.md` shows both
- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass

#### Manual Verification:

- [ ] `/tce:init` in a scratch project offers the three presets; Compact writes the Compact sub-fields; Guided asks four questions and writes **Custom**

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `8903a5e` feat(TP-0048): add the Presentation profile section
- **Did**: `## Presentation` (Full/Compact/Custom sub-fields) in the profile template; init.md gather 11, verbatim preset dialog + Guided prose interview, refine list, Phase 4 fill, 1.8.0 Idempotency; refresh.md four sites; README bullet + tree; CLAUDE.md agreed-sections rule
- **Issues**: none
- **Verification**: ✅ grep criteria (1 heading after Reader, refresh 4, init dialog + Idempotency), ✅ validate marketplace + tce
- **Fix rounds**: 0/3

---

## Phase 3: The presenter agent and its contract

### Overview

The read-only agent and the contract it follows. It is not dispatched yet.

### Changes Required:

#### 1. Agent

**File**: `plugins/tce/agents/presenter.md` (new)
**Changes**: frontmatter `name: presenter`, `description:` "Internal to tce's
step commands and `/tce:intent` — not for direct use …", `tools: Read, Grep,
Glob, LS`, `model: inherit`. Body: the three-part envelope (`## CRITICAL:` …
read-only, never writes, never asks; `## What NOT to Do`; `## REMEMBER:`).
"What you receive": common block, `artifact:` (path), `kind: brief | delta |
intent | dossier`, `changes:` on `delta` (the planner's change lines,
verbatim), `findings:` on a re-run after the brief check, optional `note:`.
Process: re-read profile, then ticket → intent → (research) → the artifact in
full, every dispatch (TP-0013); read `## Presentation` (absent → Full's values
from `work-brief.md`) and `## Reader`; read `<references>/work-brief.md` in
full; compose. Return: the body, then a `tce-return` block with `step:
present`, `artifact:` the presented path, a filled-in example for `kind: brief`
under Compact.

#### 2. Contract

**File**: `plugins/tce/references/work-brief.md`
**Changes**: header names the presenter as the reader of sections 3-6 and the
planner as the reader of section 2. Sections:
- Questions (planner; unchanged apart from Phase 1).
- **What a decision is**: a point where a reasonable colleague might have
  chosen differently; following an existing pattern is not one.
- **The presentation**: takeaway line with counts, the artifact's path, the
  touchpoint's always-shown items from the section, **Exceptions** (what
  deviates from CLAUDE.md, the profile's recorded practice or the reader's
  likely expectation), **Likely push-backs** (three, one sentence each). Every
  line names its subject and stands alone — never "see phase 2" or a line
  number. Per-kind skeletons for brief, intent and dossier; Full's sections
  mirror 1.7.1's brief layout minus "Decisions for you".
- **Budget and overflow**: the section's line budget counts every printed
  line; what does not fit is listed once as `More on request: <topic> (<n>
  lines), …`, never a bare count.
- **The delta**: `CHANGED:` takeaway, the `+`/`~`/`- (removed)` lines built
  from `changes:` and the plan.
- Phrasing for the reader (unchanged).
- Full's default values (used when the section is absent).

**File**: `plugins/tce/references/agent-returns.md`
**Changes**: `step:` adds `present` (and `brief-check`, used in Phase 4);
"The planner's extra body" becomes "Bodies before the block": planner
(questions, change list), presenter (the presentation), challenger and verifier
findings; length bound: a presentation is bounded by the profile's line budget
(60 without a section); the header lists six agents.

**File**: `plugins/tce/references/work-dispatch.md`
**Changes**: payload bullet for `presenter` (`artifact:`, `kind:`, `changes:`,
`findings:`).

**File**: `CLAUDE.md`
**Changes**: orchestrators section — the agent list becomes six (presenter),
"All six agents are `model: inherit`", the return-shape span adds
`agents/presenter.md`, the brief-layout span adds it; TP-0013's agent list adds
`presenter`; Layout block names it.

### Success Criteria:

#### Automated Verification:

- [x] Test: `sed -n '1,6p' plugins/tce/agents/presenter.md` shows `tools: Read, Grep, Glob, LS` and `model: inherit`
- [x] Test: `grep -c '^## CRITICAL\|^## What NOT to Do\|^## REMEMBER' plugins/tce/agents/presenter.md` prints `3`
- [x] Test: `grep -n 'present' plugins/tce/references/agent-returns.md` shows the new `step:` value; `grep -n 'More on request' plugins/tce/references/work-brief.md` shows the overflow rule
- [x] Test: `test -f plugins/tce/agents/presenter.md && ! grep -n 'omitClaudeMd\|Explore\|subagent_type' plugins/tce/agents/presenter.md` exits 0 (the new agent exists and neither drops CLAUDE.md nor delegates to a built-in agent)
- [x] `claude plugin validate ./plugins/tce` passes (the new agent is discovered)

#### Manual Verification:

- [ ] None beyond Phase 4's run — the agent is first dispatched there.

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `03d06ea` feat(TP-0048): add the presenter agent and its contract
- **Did**: new `agents/presenter.md` (read-only, three-part envelope); work-brief.md rewritten as the presenter's contract (decision, blocks, skeletons, budget + `More on request:`, delta, Full's values); agent-returns.md (`present`, `brief-check`, bodies, budget bound); work-dispatch.md payload; CLAUDE.md (layout, six agents, spans, TP-0013 list)
- **Issues**: planner.md still returns the brief until Phase 4 → it now follows the presentation's Full brief skeleton (no "Decisions for you" block); planner.md/work-loop.md edits stay in Phase 4 per the plan
- **Verification**: ✅ frontmatter, envelope (3), `present` + `More on request` greps, no omitClaudeMd/built-in delegation, ✅ validate marketplace + tce
- **Fix rounds**: 0/3

---

## Phase 4: Challenger brief mode and the loop wiring

### Overview

Step 6 and Step 11 present through the presenter; the challenger checks the
plan brief.

### Changes Required:

#### 1. Challenger

**File**: `plugins/tce/agents/plan-challenger.md`
**Changes**: `mode: plan | brief` in "What you receive"; `brief:` only on
`brief`. `mode: plan`: items 1-5 (item 6 removed), `step: challenge`.
`mode: brief`: the presenter's return verbatim; five points — every
`*(decided for you)*` decision appears; nothing appears the plan does not
contain; the exceptions are real and nothing routine slipped in; each line
stands on its own; the budget holds (from `## Presentation`, or 60). Return
`step: brief-check`, same status mapping. Description and "six" counts
updated; two filled-in returns.

#### 2. Planner

**File**: `plugins/tce/agents/planner.md`
**Changes**: modes `questions | write | revise | challenge-fix`; `mode: write`
returns only the block (summary's first line `Phases: N · Commit: <sha>`);
`revise` returns one line per change (`+`/`~`/`-`, at most 15) before the
block; `challenge-fix` returns the block only; `mode: brief` removed; Return
examples and "which values go together" updated; the intro says the planner's
questions are what reaches the human, the presenter writes the rest.

#### 3. Loop

**File**: `plugins/tce/references/work-loop.md`
**Changes**: invariant 1 adds `tce:presenter`; Step 6 becomes: (1) read
`work-brief.md`; (2) questions in prose → `write`; (3) `tce:plan-challenger`
`mode: plan`, ≤3 rounds with `challenge-fix`; (4) `tce:presenter` `kind:
brief` → `tce:plan-challenger` `mode: brief` → on fail, the presenter once
more with `findings:` → print the presentation, then remaining fail lines and
the plan-mode human items under "Challenger notes:"; (5) prose approval;
push-back → `revise` → challenger `mode: plan` → presenter `kind: delta` with
`changes:` → brief check → print → ask again. Reached from row 8: start at
(4). Step 11 point 4: dispatch `tce:presenter` `kind: dossier` and print its
return; under Pull request also the URL. Step 12's restated items stay.

**File**: `plugins/tce/references/work-dispatch.md`
**Changes**: row 8 "presentation, then approval"; payloads: planner `brief`
removed, challenger `mode: plan` / `mode: brief`; bounds table adds "brief
check → presenter: 1 round".

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: lane (`:70-75`) prints the presentation and challenger notes;
not-small stop (`:78-80`) reads the total `<m>` of `stage.sh`'s `progress:`
line after the plan is written.

**File**: `plugins/tce/commands/plan.md`
**Changes**: lane wording (presentation, prose approval).

**File**: `plugins/tce/README.md` and `CLAUDE.md`
**Changes**: the workflow description names the presenter and the brief
check; CLAUDE.md's loop and brief-layout spans add `agents/plan-challenger.md`
and `agents/presenter.md`.

### Success Criteria:

#### Automated Verification:

- [x] Test: `grep -n 'mode: brief' plugins/tce/agents/plan-challenger.md` and `grep -n 'brief-check' plugins/tce/agents/plan-challenger.md plugins/tce/references/agent-returns.md` print matches
- [x] Test: `grep -n 'Brief faithful' plugins/tce/agents/plan-challenger.md` prints nothing; `grep -n 'mode: brief' plugins/tce/agents/planner.md` prints nothing
- [x] Test: `grep -n 'tce:presenter' plugins/tce/references/work-loop.md` shows Step 6 and Step 11; `grep -n "dossier's text" plugins/tce/references/work-loop.md` prints nothing
- [x] Test: `grep -n 'progress:' plugins/tce/commands/quickfix.md` shows the not-small stop
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] A `/tce:work <ID>` run in a consuming project on Compact prints, before implementation: the prose questions, then the path, decisions made for you, exceptions and three push-backs within 20 lines; at the end the dossier path, counted facts, pending items and exceptions; no AskUserQuestion box and, with the script entries allowed, no permission prompt after a prose reply (intent criterion 1)
- [ ] The same run without `## Presentation` prints the Full sections, per-phase list included

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `65aad7b` feat(TP-0048): present plans and dossiers through the presenter
- **Did**: plan-challenger `mode: plan` (5 items) + `mode: brief` (5 points, `step: brief-check`); planner without `mode: brief` (write returns the block, revise change lines); work-loop Step 6 (plan check → presenter → brief check, 1 round) and Step 11 (presenter `kind: dossier`); work-dispatch row 8, payloads, bound; agent-returns; work-brief delta lines; quickfix (`progress:` not-small stop) and plan lanes; README; CLAUDE.md spans
- **Issues**: "Decisions for you" removed from the loop and the quickfix lane, per the plan's decision; brief check re-checks once after the presenter's fix so "remaining fail lines" are real
- **Verification**: ✅ grep criteria (brief mode + brief-check, no Brief faithful / planner brief mode, presenter in Steps 6 and 11, no dossier's text, quickfix progress:), ✅ validate ×5
- **Fix rounds**: 0/3

---

## Phase 5: `/tce:intent` on the same principles

### Overview

Question rounds in the two-lines-plus-questions shape; write, then present.

### Changes Required:

#### 1. Rounds

**File**: `plugins/tce/commands/intent.md`
**Changes**:
- New short section "Round shape": two lines of understanding, then numbered
  questions (scope matching first, with "I assume this is out" as the
  recommended answer for each likely-out item), free-form reply.
- Compressed Round 1 (`:247-262`): understanding, size with override
  invitation, sufficiency and scope questions — no draft. Round 2
  (`:269-273`): fold the answers, write the intent (no "Ready?" question).
- Full track: each phase's gate (`:294`, `:303`, `:323`) is a round in the
  same shape; Phases 5-6 likewise; Phase 7 (`:347-351`) is replaced by
  "Writing the intent".
- Writing (`:353-374`): after the commit, dispatch `tce:presenter` with
  `kind: intent` and the intent path, print its return, then the hand-off
  line. A correction reply rewrites the intent in place, commits, and presents
  again.
- Autonomous mode unchanged (one-line output).
- Sufficiency test, sizing and routing keep their substance.

**File**: `plugins/tce/README.md` and `CLAUDE.md`
**Changes**: `/tce:intent` description; CLAUDE.md's intent section notes the
presenter dispatch.

### Success Criteria:

#### Automated Verification:

- [x] Test: `grep -n 'complete first-draft\|Phase 7' plugins/tce/commands/intent.md` prints nothing
- [x] Test: `grep -n 'tce:presenter' plugins/tce/commands/intent.md` prints the Writing step
- [x] Test: `grep -n 'Sufficiency test' plugins/tce/commands/intent.md` still matches, and `--autonomous`'s `insufficient:` return is unchanged (`grep -n 'insufficient:' plugins/tce/commands/intent.md`)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] `/tce:intent <ID>` on a Small ticket in a consuming project: one question round, then the intent written and the presenter's return printed (path, Out list, exceptions, sample under Compact); no draft dump

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `6407724` feat(TP-0048): ask intent questions in rounds and present the intent
- **Did**: intent.md — new "Round shape" (two lines + numbered questions, likely-out items first), compressed Round 1 without draft, Round 2 writes directly, full-track phases as rounds, Phase 7 removed, Writing step 5 dispatches `tce:presenter` `kind: intent` + corrections rewrite and re-present; README intent bullet; CLAUDE.md intent section
- **Issues**: none
- **Verification**: ✅ no draft/Phase 7, ✅ presenter in Writing, ✅ Sufficiency test + `insufficient:` unchanged, ✅ validate ×5
- **Fix rounds**: 0/3

---

## Phase 6: Standing rules

### Overview

Candidates in research, one question in planning, promotion into CLAUDE.md,
a declined list, and a mined catch-up in refresh.

### Changes Required:

#### 1. Research

**File**: `plugins/tce/references/research-document-template.md`
**Changes**: new `## Practice candidates` after `## Open Questions` (`:108`):
`1. <proposed rule, one line> — <k> tickets: <IDs>` or `None.`; guidance:
counted once per ticket, at least two tickets, fenced code ignored, omit
anything in CLAUDE.md, the profile's `## Conventions` or `## Declined standing
rules`.

**File**: `plugins/tce/agents/researcher.md`
**Changes**: Process step 3 (`:95`) asks the thoughts agents to report the
`## Decisions` lines of the documents they find and the pattern finder to
report conventions it sees everywhere but no doc states; step 4 (`:134`)
clusters them into candidates per the template.

#### 2. Planning and the loop

**File**: `plugins/tce/agents/planner.md`
**Changes**: `mode: questions` step 2 adds: when the research lists
candidates, one closing item "Seen repeatedly — record as standing rules?
Reply with the numbers you accept", header `Practices`, listing them; accepted
ones bind the plan as `*(yours)*`.

**File**: `plugins/tce/references/work-loop.md`
**Changes**: invariant 3 adds the two writes; Step 6 point 2: after the
answers, append each accepted candidate as one line under `## Standing rules`
at the end of the project's `CLAUDE.md` (create the heading if absent), and
each declined one under `## Declined standing rules` in `profile.md` (create
the section if absent); commit with `/tce:commit`. When any reply says
"always <X>", the next prose message offers "Record 'always <X>' as a standing
rule?" with the same writes.

#### 3. Profile, refresh, init

**File**: `plugins/tce/templates/tce/profile.md`
**Changes**: `## Declined standing rules` after `## Presentation`: intro
(read by the researcher, written by the loop and refresh), empty by default.

**File**: `plugins/tce/commands/refresh.md`
**Changes**: hand-authored sites add `## Declined standing rules`; new Phase
"Standing-rule catch-up": dispatch `tce:thoughts-analyzer` over
`thoughts/shared/intents/` and `thoughts/shared/plans/` `## Decisions`
sections (fenced code ignored, once per ticket, at least two), omit what
CLAUDE.md, Conventions or the declined list states, present a numbered draft
in prose, write accepted/declined as the loop does. "Never touch anything under
`thoughts/`" becomes "never write under `thoughts/`".

**File**: `plugins/tce/commands/init.md`
**Changes**: the tce 1.8.0 Idempotency bullet offers the same catch-up on an
upgrade.

**File**: `plugins/tce/README.md` and `CLAUDE.md`
**Changes**: README describes candidates and promotion; CLAUDE.md names the
`## Standing rules` append as a sanctioned CLAUDE.md edit, the declined section
in the agreed-sections lifecycle, and refresh's mining in the
refresh-tracks-init section.

### Success Criteria:

#### Automated Verification:

- [x] Test: `grep -n '^## Practice candidates' plugins/tce/references/research-document-template.md` matches
- [x] Test: `grep -n 'Practices' plugins/tce/agents/planner.md` and `grep -n 'Standing rules' plugins/tce/references/work-loop.md` match
- [x] Test: `grep -n '^## Declined standing rules' plugins/tce/templates/tce/profile.md` matches; `grep -c 'Declined standing rules' plugins/tce/commands/refresh.md` is at least 4
- [x] Test: `grep -n 'thoughts-analyzer' plugins/tce/commands/refresh.md` matches
- [x] Test: intent criterion 9 across every step agent, after the last phase that edits agents: `for a in researcher planner plan-challenger implementer verifier presenter; do f=plugins/tce/agents/$a.md; test -f "$f" || echo "missing $a"; grep -n 'omitClaudeMd\|Explore\|subagent_type\|built-in Plan' "$f"; done` prints nothing (fails if presenter.md is missing or any step agent drops CLAUDE.md or delegates to a built-in Explore/Plan agent)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] In a consuming project with two or more tickets sharing a decision, `/tce:research` lists it as a candidate with its count; the planner asks once; accepting appends one line to CLAUDE.md, declining adds it to the profile list, and the next research run does not propose it
- [ ] `/tce:refresh` in this repository presents a mined draft list

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `722cd12` feat(TP-0048): grow standing rules from practice candidates
- **Did**: research template `## Practice candidates`; researcher steps 3/4/7 + return line; planner `Practices` item + example; work-brief practices item; work-loop invariant 3 + Step 6 "Standing rules" (incl. "always" offer); profile `## Declined standing rules`; refresh 4 sites + Phase 4 catch-up (thoughts-analyzer, read-only); init fill + 1.8.0 bullet; README; CLAUDE.md
- **Issues**: none
- **Verification**: ✅ grep criteria (template, Practices, Standing rules, declined ×6 in refresh, thoughts-analyzer, criterion 9 across 6 agents), ✅ validate ×5
- **Fix rounds**: 0/3

---

## Phase 7: Release tce 1.8.0

### Overview

Bump and hand over the tag.

### Changes Required:

**Files**: `plugins/tce/.claude-plugin/plugin.json` (`:3`), `.claude-plugin/marketplace.json` (`:15`)
**Changes**: `1.7.1` → `1.8.0`. Run `claude plugin tag --dry-run ./plugins/tce`
and hand the human `claude plugin tag ./plugins/tce` (or the `git tag -s
tce--v1.8.0 <sha> -m "tce 1.8.0"` form when the bump is not HEAD).

### Success Criteria:

#### Automated Verification:

- [x] Test: `grep -n '"version": "1.8.0"' plugins/tce/.claude-plugin/plugin.json .claude-plugin/marketplace.json` prints two lines
- [ ] `claude plugin tag --dry-run ./plugins/tce` succeeds
- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce`, `./plugins/tmt`, `./plugins/tle`, `./plugins/tsf` pass

#### Manual Verification:

- [ ] The human creates the tag outside the sandbox; `git tag --list 'tce--v*'` shows `tce--v1.8.0`

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `pending` chore(TP-0048): release tce 1.8.0
- **Did**: `1.7.1` → `1.8.0` in `plugins/tce/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`; init.md's 1.8.0 Idempotency bullets already in place from Phases 1, 2, 6
- **Issues**: tag dry-run refuses uncommitted manifests → run after the bump commit; tag handed over, not created
- **Verification**: ✅ version grep (2 lines), ✅ validate ×5
- **Fix rounds**: 0/3

---

## Testing Strategy

### Unit Tests:

- The grep and checksum assertions per phase (the repo has no test suite; its
  Test command is `claude plugin validate`).

### Integration Tests:

- Phase 1's `claude -p` allow-rule probe against the real cache path.

### Manual Testing Steps:

1. In a consuming project: `/tce:init` (accept the script entries and
   Compact), then `/tce:intent <ID>`, answer in the next turn.
2. `/tce:work <ID>`: answer the planner's questions in the next turn, check the
   presentation is within 20 lines, approve in prose, and confirm no permission
   prompt until the dossier summary.
3. Remove `## Presentation` and re-run `/tce:plan <ID>` on a new ticket: the
   Full sections appear.

## Performance Considerations

Two more agent dispatches per plan (presenter, brief check) and one per
dossier and intent; each reads one artifact and the intent.

## Migration Notes

Projects without the new sections get Full and no declined list; the
`work.sh preflight` "profile older" warning points them to `/tce:init`, whose
1.8.0 bullet adds the script entries, `## Presentation` and the catch-up.

## References

- Ticket: `thoughts/shared/tickets/TP-0048-intent-and-plan-approval-output.md`
- Intent: `thoughts/shared/intents/2026-11-07-TP-0048-show-the-human-only-what-needs-the-human.md`
- Research: `thoughts/shared/research/2026-11-07-TP-0048-show-the-human-only-what-needs-the-human.md`
- Discussion: `thoughts/shared/discussions/2026-11-07-tce-show-the-human-only-what-needs-the-human.md`
- Agreed-section precedent: `thoughts/shared/plans/2026-10-11-TP-0045a-intent-reader-delivery.md`
