# TP-0045c: the single-step commands, quickfix and ticketless runs on the shared agents — Implementation Plan

## Overview

Make `/tce:research`, `/tce:plan` and `/tce:implement` one-step orchestrators
over the TP-0045b step agents. Make `/tce:quickfix` a reduced-ceremony lane that
starts from an autonomously written, ticketless intent. Let every step command
and `/tce:work` take a ticket ID **or** an intent path. The dispatch / ask /
resume loop moves out of `work.md` into one shared reference file
(`references/work-loop.md`), so each step is described once: in its agent, plus
the loop file. The composite-tracking rule and `implement_eco.md` are retired,
and tce ships as 1.5.0.

## Current State Analysis

Every step is described twice (research `## Summary`). `research.md` (384
lines), `plan.md` (457) and `implement.md` (383) carry their full inline
working, while the five agents carry the same working for `/tce:work` only.
`quickfix.md` (291) inlines research and Skill-delegates ticket creation,
planning and implementation. `implement_eco.md` (18 lines) wraps
`tce:implement` with `model: sonnet`.

`work.md` (271 lines) holds the step sequence inline (Steps 0–12). Its
mechanism already lives in three references: `work-dispatch.md` (position
table, payloads, bounds, resume, stop rendering), `work-brief.md` and
`agent-returns.md`.

Everything is keyed on a ticket ID. Agents embed `[PREFIX]-XXXX` in filenames,
the implementer makes the start transition, the verifier's criteria start with
the ticket's, and `work.md` reads a ticket and refuses without one. Ticketless
intents already exist (`YYYY-MM-DD-<slug>.md`, `ticket: none`), but nothing
consumes them.

### Key Discoveries:

- `stage.sh <slug>` already finds `<date>-<slug>.md` documents in `intents/`,
  `research/` and `plans/` through its `*-<id>.md` / `*-<id>-*` patterns, with
  no script change. `ticket.sh <slug>` also finds the dossier (research,
  "Discovery scripts"). A shorter tail of the slug, or a ticket intent ending
  in the same slug, also matches, and the last match in glob order wins.
- `ticket-file: none` already means "hosted ticket, read via `tickets.md`"
  (`work-dispatch.md:67`), so "no ticket" has to be keyed on `ticket: none`.
- Ticket-dependent spots in the agents: `researcher.md:153` (filename),
  `planner.md:99` (mockup grep), `planner.md:127-130` (filename),
  `implementer.md:107-110` (start transition), `verifier.md:71` (criteria
  source), `verifier.md:139` and `dossier-template.md:32-40` (dossier
  filename and heading). `plan-challenger.md` has none.
- `implementer.md:135` already carries the implementation-log format, so
  `implement.md` can lose its copy without losing the format.
  `plan-document-template.md:15,195` still says the format is "owned by
  implement.md".
- `commit.md:60-71` item h) skips the branch check when "the commit is not
  about a ticket", so ticketless commits by the agents never ask.
- The stop rendering (`work-dispatch.md:144`), the design-exploration stop
  (`work.md:151-153`) and the "Stop here" / "Not yet" option texts
  (`work.md:170-171,259`) name `/tce:work` literally and must be
  parametrized.
- `branch.sh switch` reports `missing` with the detail "…; /tce:research
  creates it", which becomes wrong once only `/tce:intent` creates branches.
- Platform: an `allowed-tools` grant lasts one turn and does not reach
  subagents, so every command that runs the loop needs the script grants
  itself and asks only through AskUserQuestion (research, Platform facts).

## Desired End State

- `plugins/tce/references/work-loop.md` holds the whole loop: entry (ticket ID
  or intent path), preflight, branch switch, intent and parent, position,
  per-return handling, and the step sections Research, Planning, Implement,
  Verify, Dossier, Delivery, Closeout and Items-for-you-to-check. It also holds
  the one AskUserQuestion guidelines block for the loop's dialog sites.
- `work.md`, `research.md`, `plan.md`, `implement.md` and `quickfix.md` are
  short: frontmatter, project context, usage, and a **lane** (which steps they
  run, where they stop, what they print last). Each reads `work-loop.md` at
  point of use and contains no inline step working.
- The agents accept `ticket: none` and name ticketless documents
  `YYYY-MM-DD-<slug>.md` after the intent's slug.
- `/tce:intent --autonomous "<description>"` writes and commits a ticketless
  intent without dialogue, or returns which sufficiency criterion failed.
- `/tce:quickfix` uses that mode, creates no ticket, runs research → planning
  (no approval) → implement → verify → dossier → closeout, and stops when the
  brief shows more than 2 phases or the planner asks the design-exploration
  question.
- `implement_eco.md` and `/tce:ticket --autonomous` are gone. CLAUDE.md has no
  composite-tracking rule, and its spans point at the agents and
  `work-loop.md`.
- tce 1.5.0 is tagged.

Verify with the Automated checks per phase, then the Phase 6 real run.

## What We're NOT Doing

- `/tce:review`, `/tce:discuss`, `/tce:design_explore`, `/tce:list`,
  `/tce:commit`, `/tce:init` (except the verbatim ticket-policy dialog wording)
  and `/tce:refresh` keep their form. `/tce:review` stays ticket-only.
- No `stage.sh` / `ticket.sh` code change and no change to the six-line record
  (TP-0033 span untouched).
- No model pins (TP-0045d), no question-form change (TP-0047), no move of the
  design-exploration check into `/tce:intent` (GH-37 finding 1).
- No agent contract change beyond `ticket: none` and ticketless naming. No
  new return field and no size signal.
- No Idempotency upgrade entry for the reworded `## Creating a ticket` text.
- Free-form research questions are dropped, not re-homed.

## Implementation Approach

Bottom-up, so every phase leaves a working plugin. Phase 1 teaches the agents
ticketless input; nothing calls it yet, so `/tce:work` is unchanged. Phase 2
extracts the loop from `work.md` into `work-loop.md` and makes `/tce:work` the
first lane, now with intent-path input. Phase 3 puts the three single-step
commands on the loop as lanes. Phase 4 adds autonomous `/tce:intent` and the
quickfix lane. Phase 5 rewrites the rules and docs and releases. Phase 6 is
the real run.

`work-dispatch.md`, `work-brief.md` and `agent-returns.md` keep their names, so
the agents' `<references>/…` reads stay valid. Their headers widen from
"/tce:work" to "the commands that run work-loop.md".

**Risk — slug collisions.** Ticketless documents are found by passing the
bare slug to `stage.sh` / `ticket.sh`. Their delimited match also hits a
shorter tail of the slug, or a ticket intent ending in the same slug, and the
last match in glob order wins (Key Discoveries). Only the autonomous
`/tce:intent`'s uniqueness check (Phase 4) guards against that. Ticketless
intents written in dialogue by the interactive `/tce:intent` check only
`thoughts/shared/intents/*-<slug>.md` (`intent.md:152-169`), not research,
plans or dossiers, so a collision there goes unnoticed. This plan accepts the
risk and does not extend the interactive check; it is outside the intent's
scope.

## Decisions

- **The single-step commands require the foreground environment** — over an inline fallback when the variables are missing: a fallback is the second step description this ticket exists to remove. *(yours)*
- **`implement_eco` is deleted in this ticket** — over keeping it until the TP-0045d pins: it was never used, and after the rewire its turn-scoped pin would likely not reach the `inherit` agents anyway. *(yours)*
- **Extract today's loop as it is** — over waiting for TP-0047 and GH-37 finding 1: those then edit one reference file instead of four commands. *(yours)*
- **Quickfix authors an intent only, no ticket** — over keeping ticket creation: ticketless intents are the standard for small work; `/tce:intent` gets an autonomous mode. *(yours)*
- **`/tce:implement` standalone writes the dossier** — over stopping at the closeout: the step ends where `/tce:work`'s verification ends; only delivery stays with `/tce:work`. *(yours)*
- **All step commands and `/tce:work` accept ticketless intents** — over restricting ticketless runs to quickfix: developer-only implementations can be larger than a quickfix. *(yours)*
- **Free-form research is dropped** — over widening the researcher to accept a bare question: never used; `/tce:discuss` covers exploration. *(yours)*
- **Ticketless documents are named `YYYY-MM-DD-<slug>.md` after the intent's slug and found by passing the bare slug to the existing scripts** — over an intent-path mode in `stage.sh`: no script or `list.md` contract change; autonomous `/tce:intent` refuses a slug already in use. *(yours)*
- **`ticket: none` marks a ticketless payload; agents derive the slug from `intent:`** — over a new `id:` field: no new field in the common block or the return-shape span. *(yours)*
- **`/tce:research` refuses a ticket without an intent and only switches branches** — over keeping its sufficiency check and `branch.sh create`: `/tce:intent` stays the one sufficiency site in a command and the one branch-dialog copy. *(yours)*
- **The AskUserQuestion guidelines block for the loop lives once in `work-loop.md`** — over a copy per command: `work`, `research`, `plan` and `quickfix` drop theirs, so 13 copies become 10. *(yours)*
- **Quickfix stops as not small when the brief shows more than 2 phases or the planner asks the design-exploration question** — over a size field in the agents' returns: no contract change. *(yours)*
- **Quickfix stops when autonomous `/tce:intent` reports a failed sufficiency test, naming the missing criterion** — over a clarification round and a retry: no second dialogue path. *(yours)*
- **The ticket-creation policy is reworded for `/tce:ticket` only, and `--autonomous` is removed from `ticket.md`** — over keeping an uncalled mode: no command calls it any more; no Idempotency entry. *(yours)*
- **The loop's file is a new `references/work-loop.md`, and `work-dispatch.md`/`work-brief.md`/`agent-returns.md` keep their names** — over merging everything into one file or renaming the `work-*` family: the agents already read those three by name, and the step sequence is a separate concern from payloads and layouts. *(decided for you)*
- **Each command declares a lane (start rows, steps, stop point) in its own body; `work-loop.md` holds the steps** — over one parametrized "mode" table inside `work-loop.md`: a command stays readable on its own, and the lane is the only per-command text. *(decided for you)*
- **`/tce:plan` refuses without research and points to `/tce:research`; `plan.md`'s Step 2 (planning without research) is dropped** — over carrying it: the planner requires research, and `/tce:work` already does. *(decided for you)*
- **`implement.md`'s own design-exploration check is dropped** — over keeping it: the planner's `questions` mode asks it before any plan exists. *(decided for you)*
- **Invoking `/tce:implement` on a written but unstarted plan counts as approval** — over running the brief and approval dialog again: the human approved the plan by asking for implementation; `/tce:plan` owns approval. *(decided for you)*
- **`/tce:research` on a ticket whose research exists reports the path and the next command and stops** — over re-running the researcher: a re-run would write a second research document; deleting the old one is the human's call. *(decided for you)*
- **Standalone `/tce:implement` under Pull request delivery writes `undelivered: <branch> @ <sha>` as the merge reference, and a new first position row sends `/tce:work` to delivery for it (the old rows 1–9 become 2–10)** — over recording `direct:`: the work stays deliverable by `/tce:work` instead of being reported done. *(decided for you)*
- **A ticketless closeout's ticket line reads `none (ticketless intent)`, and the `git log --grep` base-commit fallback is skipped** — over inventing an ID: a slug in commit messages is not guaranteed. *(decided for you)*
- **Autonomous `/tce:intent` checks slug uniqueness with a Glob over `thoughts/shared/**/*<slug>*`, not with `ticket.sh`** — over calling the script: a Skill-invoked skill's `allowed-tools` reaching its caller's turn is undocumented. *(decided for you)*
- **`/tce:ticket` stays unflagged with its quickfix edge gone; `research`, `plan` and `implement` stay unflagged with no Skill caller left** — over flagging them: the intent keeps them as delegation targets, and flagging would change behaviour this ticket does not ask for. *(decided for you)*
- **`branch.sh switch`'s `missing` detail names `/tce:intent` instead of `/tce:research`** — over leaving the stale text: `/tce:research` no longer creates branches. *(decided for you)*
- **tce goes to 1.5.0** — over 1.4.4: new input form (intent paths) and a removed command. *(decided for you)*

## Phase 1: Ticketless input in the agents and templates

### Overview

Teach the five agents and the document templates that `ticket: none` means a
ticketless intent, and how to name its documents. Nothing dispatches
`ticket: none` yet, so `/tce:work` behaves exactly as before.

### Changes Required:

#### 1. The common payload block

**File**: `plugins/tce/references/work-dispatch.md`
**Changes**: In `# Payloads` (`:59-72`), document the ticketless form under the
common block:

```
ticket: [PREFIX]-XXXX            (or: none — a ticketless intent)
ticket-file: <path, or none for a hosted ticket system; none when ticket: none>
```

Add one paragraph: "With `ticket: none` the intent is the only input. The
document ID is the intent's **slug**: its filename without the leading
`YYYY-MM-DD-` and the `.md`. `stage.sh` and `ticket.sh` take the slug where
they would take a ticket ID; `parent:` is always `none`."

#### 2. researcher

**File**: `plugins/tce/agents/researcher.md`
**Changes**:
- "What you receive" (`:53-55`): add "`ticket: none` means a ticketless
  intent: there is no ticket to read; the intent is the input".
- Re-read list (`:74-81`): "the **ticket** (unless `ticket: none`) → the
  **intent** → …". Keep the TP-0013 wording intact.
- Filename (`:153-155`): add the ticketless form
  `thoughts/shared/research/YYYY-MM-DD-<slug>.md`, with the slug exactly as
  in the intent's filename and no description suffix ("the discovery script
  globs for it").
- `description:` frontmatter and the opening paragraph: replace "Internal to
  `/tce:work`" with "Internal to tce's step commands (`/tce:work`,
  `/tce:research`, `/tce:quickfix`)", and replace "exactly as `/tce:research`
  does" with a self-standing statement ("the research step of the tce
  workflow"). The command no longer describes the step.

#### 3. planner

**File**: `plugins/tce/agents/planner.md`
**Changes**:
- "What you receive" (`:34-35`) and the re-read (`:58`): the same
  `ticket: none` rules as the researcher.
- Design-exploration lookup (`:99`): grep for the ticket ID, or for the slug
  when `ticket: none`.
- Plan filename (`:127-130`): add `thoughts/shared/plans/YYYY-MM-DD-<slug>.md`.
- Description and intro (`:3`, `:9`): as for the researcher, with no
  "exactly as `/tce:plan` does".

#### 4. implementer

**File**: `plugins/tce/agents/implementer.md`
**Changes**:
- "What you receive" (`:35-36`), the re-read (`:56`): `ticket: none` rules.
- Start transition (`:107-110`) and staging the ticket file (`:143-145`):
  "skip when `ticket: none`".
- Description and intro: drop the "as `/tce:implement` does" mirror wording.
  State that this file owns the implementation-log format (`:130-140`).

#### 5. verifier and the dossier template

**File**: `plugins/tce/agents/verifier.md`
**Changes**:
- "What you receive" (`:33-34`), the re-read (`:51`): `ticket: none` rules.
- Criteria sources (`:70-77`): "the ticket's acceptance criteria (none when
  `ticket: none`)".
- Dossier filename (`:138-140`): add
  `thoughts/shared/dossiers/YYYY-MM-DD-<slug>.md`.
- Description and intro: drop the mirror wording.

**File**: `plugins/tce/references/dossier-template.md`
**Changes**: `:32-33` gains the ticketless filename. `:40` heading becomes
`# Dossier: [PREFIX]-XXXX — [ticket title]` or, ticketless,
`# Dossier: <slug> — [intent title]`.

#### 6. plan-challenger

**File**: `plugins/tce/agents/plan-challenger.md`
**Changes**: Description only: "Internal to tce's step commands". It has no
ticket dependence.

#### 7. Plan template

**File**: `plugins/tce/references/plan-document-template.md`
**Changes**:
- Header (`:1-17`): drop the composite-tracking sentence. Say it is read by
  the `planner` agent. Re-point "formats owned by implement.md" (`:15`,
  `:195`) to "owned by the `implementer` agent".
- `:134`: `- Original ticket: \`[PREFIX]-XXXX\` (or the intent path for a
  ticketless intent)`.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass
- [x] `grep -n "ticket: none" plugins/tce/agents/researcher.md plugins/tce/agents/planner.md plugins/tce/agents/implementer.md plugins/tce/agents/verifier.md plugins/tce/references/work-dispatch.md` shows a hit in each of the five files
- [x] `grep -n "YYYY-MM-DD-<slug>.md" plugins/tce/agents/researcher.md plugins/tce/agents/planner.md plugins/tce/agents/verifier.md plugins/tce/references/dossier-template.md` shows a hit in each of the four files
- [x] `grep -rn "owned by implement.md\|composite-tracking" plugins/tce/references/plan-document-template.md` returns nothing
- [x] `grep -n "unless \`ticket: none\`\|skip when \`ticket: none\`" plugins/tce/agents/researcher.md plugins/tce/agents/planner.md plugins/tce/agents/implementer.md plugins/tce/agents/verifier.md` shows the re-read skip in all four agents and the start-transition skip in `implementer.md`
- [x] `grep -n "Internal to \`/tce:work\`\|exactly as \`/tce:" plugins/tce/agents/*.md` returns nothing (no agent mirrors a command any more)

#### Manual Verification:

- [ ] Reading each agent's "What you receive" alone, a ticketless dispatch is unambiguous: what to read, what to skip, what to name the document

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `c706331ef5e0a311517c8059a452fce21f1fab6c`
- **Commit**: `9755bd2` feat(TP-0045c): ticketless input in the step agents and templates
- **Did**: `ticket: none` + slug naming in researcher/planner/implementer/verifier, work-dispatch common block, dossier/plan templates; agent descriptions no longer mirror commands
- **Issues**: plan-template header and UI/UX note also re-pointed from /tce:plan/implement.md to the agents (same intent, beyond the listed lines)
- **Verification**: ✅ claude plugin validate (5 manifests), ✅ phase greps (6/6)
- **Fix rounds**: 0/3

---

## Phase 2: Extract the loop into `work-loop.md`; `/tce:work` as the first lane

### Overview

Move `work.md`'s Steps 0–12, its invariants and its AskUserQuestion block into
the new `references/work-loop.md`, parametrized by the running command.
`work.md` becomes the `/tce:work` lane. Add intent-path input and the
ticketless rules. Behaviour for tickets is unchanged.

### Changes Required:

#### 1. New shared loop reference

**File**: `plugins/tce/references/work-loop.md` (new)
**Changes**: A header comment in the house style: read at point of use, in
full, by `work.md`, `research.md`, `plan.md`, `implement.md` and
`quickfix.md`; never copied; the span it belongs to. Then, moved from
`work.md` with the step numbers kept as section names:

1. `### AskUserQuestion dialog guidelines` — byte-identical to `work.md:30-48`.
2. **Invariants** — `work.md:52-70`, with "the scripts above are granted" →
   "the running command's `allowed-tools` grant the scripts for this turn
   only".
3. **Entry** (new): the argument is a ticket reference **or** a path into
   `thoughts/shared/intents/`. For a path, grep its `ticket:` frontmatter
   line: a ticket ID → continue as for that ticket; `none` → ticketless,
   with **ID** = the slug (filename minus `YYYY-MM-DD-` and `.md`). Anything
   else (no argument, free text, another path) → refuse with the running
   command's usage line and "Write an intent first with `/tce:intent`, or
   explore with `/tce:discuss`." Throughout the file, `<ID>` is the ticket ID
   or the slug, and `<command>` is the running command's name.
4. **Step 0 — Preflight**: `work.md:72-83`, with the first line of the
   refusal block as `<command> needs foreground agents and a long Bash
   timeout. …`. Otherwise verbatim.
5. **Step 1 — Ticket**: `work.md:85-89`; ticketless → read the intent instead
   (it is the input).
6. **Step 2 — Branch**: `work.md:91-102`, plus "Ticketless: skip, print
   nothing." `missing` → refuse as Step 3.
7. **Step 3 — Intent and parent**: `work.md:104-115` with `<ID>`; the refusal
   names `/tce:intent <ID>`; ticketless → `parent: none`.
8. **Step 4 — Position**: `work.md:117-136`, with `<ID>` in the printed line.
9. **Steps 5–12**: `work.md:138-271` moved verbatim except for these
   substitutions:
   - the design-exploration stop (`:151-153`) → "Run
     `/tce:design_explore <ID>` (ticketless: describe the UX question to
     `/tce:design_explore`), then `<command> <argument>` again";
   - "Stop here — … re-run /tce:work" (`:170-171`) and "Not yet — … re-run
     /tce:work" (`:259`) → `<command>`;
   - Step 8 point 1: the `git log --grep` fallback "— ticket runs only";
   - Step 10: "Ticketless: always Direct";
   - Step 11's Ticket line: `[PREFIX]-XXXX → Done` or, ticketless,
     `none (ticketless intent)`; point 2 "skip when ticketless";
   - Step 10 gains the **lane variant** "When the lane says *no delivery*:
     Direct → `direct: <branch> @ <short sha>`; Pull request →
     `undelivered: <branch> @ <short sha>` (run `/tce:work <argument>` to
     deliver)".
10. **Lanes** (new, short): each command names its lane in its own body. This
    section says how to read one: *start rows* (which position-table rows
    the command acts on), *steps* (which of Steps 5–12 it runs),
    *otherwise* (what it prints for any other row — "<ID> is at <step>;
    next: `<next command> <argument>`" — and then it stops).

#### 2. Position table, stop rendering, headers

**File**: `plugins/tce/references/work-dispatch.md`
**Changes**:
- Header (`:1-12`): read by every command that runs `work-loop.md`.
- Signals (`:29-32`): `stage.sh <ID>` / `ticket.sh <ID>` with `<ID>` = ticket
  ID or slug; add a grep for the Closeout's `**Merge reference**` line.
- New **row 1**: "Closeout's Merge reference says `undelivered:` → delivery
  (Step 10), then rewrite the Merge reference line, and re-derive". The old
  rows 1–9 move to 2–10. The renumbered table, which every lane in this plan
  uses:

  | # | When | Next step |
  |---|---|---|
  | 1 | Merge reference `undelivered:` | delivery, then rewrite Merge reference |
  | 2 | Manual verification `verified by agent` / `confirmed by user` | report done, stop |
  | 3 | Manual verification `pending:` | Step 12 |
  | 4 | a dossier exists | delivery, then closeout |
  | 5 | `k = N`, `## Verification` clean | dossier |
  | 6 | `k = N` | verify |
  | 7 | `k < N`, or `source: sidecar` | implement |
  | 8 | plan exists, `source: unknown` | brief, then approval |
  | 9 | research exists, no plan | plan questions |
  | 10 | no research | research |

  The row has to come first. A standalone `/tce:implement` closeout carries
  both `undelivered:` and a final Manual verification value, so in any lower
  position the "done" row would match first and the work would never be
  delivered.
- Stop rendering `:144`: `Then:   <command> <argument>`.

**File**: `plugins/tce/references/work-brief.md`, `plugins/tce/references/agent-returns.md`
**Changes**: Header comments (`:1-12` and `:1-13`): "the orchestrated
`/tce:work`" → "the commands that run `work-loop.md`"; the span sentence names
`work-loop.md` in place of `work.md`. Body unchanged.

#### 3. `/tce:work` as a lane

**File**: `plugins/tce/commands/work.md`
**Changes**: Keep the frontmatter, with `argument-hint: "[ticket-id | intent
path]"` and a description that mentions intent paths. Keep `## Project
context`, with usage `/tce:work [PREFIX]-XXXX | <intent path>`. Delete
`:30-271` and replace it with:

```markdown
## The loop

Read `${CLAUDE_PLUGIN_ROOT}/references/work-loop.md` **now — in full** —
and run it as `<command>` = `/tce:work`, in this lane:

- **Start rows:** all.
- **Steps:** 5–12 — research, planning with approval, implement, verify,
  dossier, delivery, closeout, items for you to check.
- **Otherwise:** none.
```

Keep the `allowed-tools` line byte-identical (delivery needs `git push` / `gh`).

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -c "" plugins/tce/commands/work.md` is below 70, and `grep -n "## Step" plugins/tce/commands/work.md` returns nothing
- [x] `grep -n "Step 0\|Step 12\|undelivered:\|ticketless" plugins/tce/references/work-loop.md` shows all four
- [x] The AskUserQuestion block extracted from `plugins/tce/references/work-loop.md` (heading through its last bullet) diffs empty against the one in `plugins/tce/commands/init.md`
- [x] `grep -n "/tce:work \[PREFIX\]" plugins/tce/references/work-dispatch.md` returns nothing (the `Then:` line is parametrized)
- [x] `grep -n "<command> needs foreground agents" plugins/tce/references/work-loop.md` shows the parametrized preflight refusal, and `grep -n "needs foreground agents" plugins/tce/commands/work.md` returns nothing
- [x] `grep -n "/tce:discuss" plugins/tce/references/work-loop.md` shows the Entry's free-form refusal, and `grep -n "| 10 |" plugins/tce/references/work-dispatch.md` shows the renumbered last row

#### Manual Verification:

- [ ] Side-by-side read: every instruction in the old `work.md:52-271` appears in `work-loop.md` (parametrized where listed), so `/tce:work <ticket>` behaves exactly as before

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `7d1d59e` feat(TP-0045c): extract the step loop into work-loop.md
- **Did**: new `references/work-loop.md` (Steps 0–12, Entry, Lanes, guidelines block); work.md → 41-line lane; work-dispatch row 1 `undelivered:` + renumber, parametrized `Then:`; reference headers point at work-loop.md
- **Issues**: dossier-template header also re-pointed from work.md to work-loop.md (counted-facts reader moved); Step 4 gained the lane gating (start rows / otherwise line) the Lanes section needs
- **Verification**: ✅ claude plugin validate (5 manifests), ✅ phase greps (7/7)
- **Fix rounds**: 0/3

---

## Phase 3: `/tce:research`, `/tce:plan`, `/tce:implement` as lanes; `implement_eco` removed

### Overview

Rewrite the three single-step commands as lanes over `work-loop.md`. Their
inline working, dialog sites, sufficiency check, free-form path and branch
creation go.

### Changes Required:

#### 1. `/tce:research`

**File**: `plugins/tce/commands/research.md`
**Changes**: Replace the whole body (`:6-384`). Frontmatter:
`argument-hint: "[ticket-id | intent path]"`; `allowed-tools` grants
`ticket.sh`, `stage.sh`, `branch.sh`, `work.sh` (no `baseline.sh`, no git);
stays unflagged. Body: a one-paragraph purpose, `## Project context` (as in
`work.md`), usage, then `## The loop` with:

- **Start rows:** 10 (no research).
- **Steps:** 5. After it, print the research path, the drift line if any, and
  "Next: `/tce:plan <argument>`".
- **Otherwise:** the `work-loop.md` "otherwise" line (for example "research
  exists at <path>; next: `/tce:plan <argument>`").

The sufficiency check (`:151-174`), the free-form path (`:176-195`), the
branch `create` and its dialog copy (`:94-130`) and the AskUserQuestion block
(`:19-37`) are deleted. The free-form refusal comes from `work-loop.md`'s
Entry.

#### 2. `/tce:plan`

**File**: `plugins/tce/commands/plan.md`
**Changes**: Replace the whole body (`:6-457`). Frontmatter:
`argument-hint: "[ticket-id | intent path]"`; grants `ticket.sh`,
`stage.sh`, `branch.sh`, `work.sh`; unflagged. Lane:

- **Start rows:** 9 (plan questions) and 8 (brief, then approval).
- **Steps:** 6 — the questions, the challenger, the brief and the
  "Approve the plan?" dialog, exactly as `/tce:work`. On Approve, print
  "Next: `/tce:implement <argument>`".
- **Otherwise:** row 10 → "No research for <ID> — run `/tce:research
  <argument>` first."; rows 1–7 → the otherwise line.

#### 3. `/tce:implement`

**File**: `plugins/tce/commands/implement.md`
**Changes**: Replace the whole body (`:6-383`). Frontmatter:
`argument-hint: "[ticket-id | intent path]"`; grants `ticket.sh`,
`stage.sh`, `branch.sh`, `baseline.sh`, `work.sh`, `git rev-parse`,
`git log` (no `git push`, no `gh`); unflagged. Lane:

- **Start rows:** 8 (treated as approved: go straight to Step 7), 7, 6, 5,
  4 (closeout without delivery) and 3 (Step 12).
- **Steps:** 7, 8, 9, then 10 in its *no delivery* variant, 11, 12.
- **Otherwise:** rows 9 and 10 → "No plan for <ID> — run `/tce:plan
  <argument>` first."; row 2 → done; row 1 (`undelivered:`) →
  "Implemented; run `/tce:work <argument>` to deliver."

The inline log format, gate, design check, mismatch template and closeout
template (`:105-348`) are deleted. The `implementer` / `verifier` agents and
`work-loop.md` carry them.

#### 4. `implement_eco` removed

**File**: `plugins/tce/commands/implement_eco.md`
**Changes**: Delete the file (`git rm`).

#### 5. `branch.sh` detail text

**File**: `plugins/tce/scripts/branch.sh`
**Changes**: The `switch` `missing` detail "…; /tce:research creates it" →
"…; /tce:intent creates it". The `result:` vocabulary is unchanged.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate ./plugins/tce` passes
- [x] `grep -c "" plugins/tce/commands/research.md plugins/tce/commands/plan.md plugins/tce/commands/implement.md` each print below 80
- [x] `grep -ln "work-loop.md" plugins/tce/commands/research.md plugins/tce/commands/plan.md plugins/tce/commands/implement.md` lists all three
- [x] `grep -n "AskUserQuestion dialog guidelines\|Sufficiency\|branch.sh\" create\|codebase-locator" plugins/tce/commands/research.md plugins/tce/commands/plan.md plugins/tce/commands/implement.md` returns nothing
- [x] `grep -n "disable-model-invocation" plugins/tce/commands/research.md plugins/tce/commands/plan.md plugins/tce/commands/implement.md` returns nothing (still unflagged)
- [x] `test ! -e plugins/tce/commands/implement_eco.md` and `grep -rn "implement_eco" plugins/ README.md CLAUDE.md` return nothing
- [x] `grep -n "tce:research creates" plugins/tce/scripts/branch.sh` returns nothing; in a scratch git repo with a Branch-per-ticket profile, `branch.sh switch nope` prints `result: missing` with the `/tce:intent` detail

#### Manual Verification:

- [ ] Each lane, read alone, says which rows it acts on and what it prints for every other row

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `f04b877` feat(TP-0045c): research, plan and implement as lanes over work-loop.md
- **Did**: research.md/plan.md/implement.md → 45–49-line lanes (start rows, steps, otherwise per row); implement_eco.md removed; branch.sh `missing` detail names /tce:intent
- **Issues**: branch.sh header comments also re-pointed (create: /tce:intent; switch: step commands via work-loop.md); quickfix.md still Skill-delegates to tce:plan/tce:implement until Phase 4 rewrites it
- **Verification**: ✅ claude plugin validate (5 manifests), ✅ phase greps (7/7), ✅ branch.sh switch smoke test
- **Fix rounds**: 0/3

---

## Phase 4: Autonomous `/tce:intent`, the quickfix lane, ticket policy wording

### Overview

Add `--autonomous` to `/tce:intent`. Rewrite `/tce:quickfix` as the
reduced-ceremony lane. Remove `/tce:ticket --autonomous` and reword the
ticket-creation policy text.

### Changes Required:

#### 1. `/tce:intent --autonomous`

**File**: `plugins/tce/commands/intent.md`
**Changes**: In input classification (`:74-109`), arguments containing
`--autonomous` go to a new `## Autonomous mode` section at the end (the
`ticket.md:197-212` precedent):

- Input: the rest of the arguments, taken as a description. A ticket
  reference or a `thoughts/` path → return
  `insufficient: autonomous mode takes a description only` (ticket intents
  are always written in dialogue).
- Apply the sufficiency test (`:171-188`) to the description. Read the code
  only to find anchors (Grep/Glob, no agents). On failure return, and write
  nothing:
  `insufficient: <scope | outcome | anchor> — <what is missing, one line>`.
- Slug: kebab-case from the description. If a Glob for
  `thoughts/shared/**/*<slug>*` matches anything, lengthen the slug with a
  distinguishing word until it matches nothing.
- Write `thoughts/shared/intents/YYYY-MM-DD-<slug>.md` per
  `intent-document-template.md`: `ticket: none`, `ticket_ref: none`,
  `source: none`, `size: Small`, `status: agreed`; `## Ticket` = "Ticketless,
  from a `/tce:quickfix` description:" plus the description verbatim; Scope,
  Observable outcome, Anchors and Acceptance criteria from the description
  and the anchors found; Decisions `None.`; Open questions `None.`
- No branch step and no confirmation. Commit through `/tce:commit` (no ticket
  scope).
- Return `intent: <path>` to the caller.

The interactive tracks are unchanged. It stays unflagged.

#### 2. `/tce:quickfix` as a lane

**File**: `plugins/tce/commands/quickfix.md`
**Changes**: Replace the body (`:7-291`). It stays flagged; `argument-hint:
"[small fix, described]"`; grants `ticket.sh`, `stage.sh`, `baseline.sh`,
`work.sh`, `git rev-parse`, `git log` (no `branch.sh`, no push). Body:
purpose, `## Project context`, then:

1. **Preflight** — `work-loop.md` Step 0 (read the file now, in full).
2. **Intent** — invoke the `tce:intent` skill through the Skill tool with
   `--autonomous` and the description. On `insufficient: …`, stop: "Not
   enough to go on: <line>. Re-run `/tce:quickfix` with that added, or use
   `/tce:intent` for a dialogue." Otherwise continue with that intent path
   as the argument.
3. **The loop**, with `<command>` = `/tce:quickfix`:
   - **Start rows:** all (a fresh intent always starts at row 10).
   - **Steps:** 5; then 6 **without** the approval dialog, but with the
     questions only when the planner returns them, the challenger rounds,
     and the brief printed. **Not-small stop:** if the planner's questions
     include the design-exploration question, or the brief's `Phases:` count
     is above 2, stop: "This is larger than a quickfix (<reason>). The
     intent and any plan stay committed. Create a ticket and run
     `/tce:intent <ID>`, or continue with `/tce:work <intent path>`."
     Then 7, 8, 9, 10 in its *no delivery* variant, 11, 12.
   - **Otherwise:** none.

The ticket-creation-policy refusal (`:20`, `:106-108`), the clarity phase,
the ticket phase, the inline research, the branch dialog copy, the
AskUserQuestion block and the Skill delegations to `tce:plan` /
`tce:implement` are deleted.

#### 3. `/tce:ticket --autonomous` removed

**File**: `plugins/tce/commands/ticket.md`
**Changes**: Delete the Autonomous bullet (`:61-62`), the "## The ticket
body (autonomous mode only)" section (`:132-…`) and "## Autonomous mode"
(`:197-212`). Change "When this command is invoked without `--autonomous`:"
(`:68`) to an unconditional lead-in.

#### 4. Ticket-creation policy wording

**File**: `plugins/tce/templates/tce/tickets.md`
**Changes**: `## Creating a ticket` placeholder (`:32-40`): name
`/tce:ticket` only. Describe "not allowed" the way `ticket.md`'s interactive
policy step actually behaves (read it while editing). `:111-112`: "Every
step command requires an intent; `/tce:intent` applies this test with you
(or, for `/tce:quickfix`, autonomously)."

**File**: `plugins/tce/commands/init.md`
**Changes**: The verbatim "May tce create tickets autonomously?" dialog
(`:283-289`): the option descriptions name `/tce:ticket` instead of
`/tce:quickfix` (TP-0001: deliberate wording change). Adjust the question so
it no longer says "autonomously" if `/tce:ticket` only ever creates after
confirmation.

**File**: `.claude/tce/tickets.md` (this repo's config)
**Changes**: `:34` drop "and `/tce:quickfix` autonomously"; `:96-97`, the
same sentence as the template's new `:111-112`.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `grep -n "## Autonomous mode\|insufficient:" plugins/tce/commands/intent.md` shows both
- [ ] `grep -n "autonomous" plugins/tce/commands/ticket.md` returns nothing
- [ ] `grep -n "tce:ticket\|tce:plan\|tce:implement\|branch.sh\|AskUserQuestion dialog guidelines" plugins/tce/commands/quickfix.md` returns nothing, and `grep -n "work-loop.md\|tce:intent" plugins/tce/commands/quickfix.md` shows both
- [ ] `grep -rn "quickfix" plugins/tce/templates/tce/tickets.md .claude/tce/tickets.md plugins/tce/commands/init.md` returns no ticket-creation mention
- [ ] `grep -c "" plugins/tce/commands/quickfix.md` prints below 90
- [ ] `grep -n "above 2" plugins/tce/commands/quickfix.md` and `grep -n "design-exploration" plugins/tce/commands/quickfix.md` both show the not-small stop, and `grep -n "Approve the plan" plugins/tce/commands/quickfix.md` returns nothing (no approval dialog)

#### Manual Verification:

- [ ] Reading `intent.md`'s Autonomous mode alone: a vague description ("make it better") yields `insufficient: anchor …` and writes nothing

---

## Phase 5: Rules, docs and release

### Overview

Rewrite the CLAUDE.md rules for the new single description, update the
READMEs and templates that named the composite, quickfix's ticket creation or
`/tce:work`-only requirements, and release tce 1.5.0.

### Changes Required:

#### 1. CLAUDE.md

**File**: `CLAUDE.md`
**Changes**:
- **Layout block**: tce's agents line ("five step agents the step commands
  dispatch"); `references/*.md` lists `work-loop.md`.
- `:134`: "the composite-tracking and TP-0013 rules" → "the loop span and
  TP-0013 rules".
- **Delete** "Composite commands must track the single-step commands"
  (`:244-285`), including the temporary agents-mirror rule.
- **TP-0020 gate** (`:287-344`): the span is `plan-compliance-checker.md`,
  `verifier.md` and `work-loop.md` (Steps 8 and 11). `implement.md` and
  `quickfix.md` leave it; the baseline span becomes `baseline.sh`,
  `work-loop.md`, `verifier.md`.
- **TP-0031 branch** (`:346-407`): `create` only in `intent.md` (the one
  dialog copy); `switch` in `work-loop.md` Step 2 for every step command;
  `review.md` `switch`; `commit.md` `check`. `research.md`, `plan.md`,
  `implement.md`, `quickfix.md` and `work.md` leave the per-command list; the
  rule names `work-loop.md` instead.
- **TP-0045b orchestrator** (`:453-510`): retitle to "the step commands are
  orchestrators". Add a **loop span** (`work-loop.md`, `work-dispatch.md`,
  `work-brief.md`, the five commands' lanes) and a **ticketless naming
  span** (`work-loop.md` Entry, `work-dispatch.md` common block,
  `researcher.md`, `planner.md`, `verifier.md`, `dossier-template.md`,
  `intent.md` Autonomous mode slug rule). Keep "foreground required" and the
  allowlist rule, now for every step command.
- **TP-0017** (`:512-575`): delegation targets keep `ticket, intent,
  research, plan, implement, commit`. The edge list: `/tce:quickfix`
  Skill-invokes `tce:intent --autonomous`; no command Skill-invokes
  `research`/`plan`/`implement` any more, and they stay unflagged by
  decision so prose requests reach them; `ticket` has no Skill caller left
  and stays unflagged for the same reason. Drop `implement_eco`.
- **TP-0013** (`:1321-1349`): consumers are `review`, `intent` and the five
  agents. The step commands pass paths and read only the ticket (as
  `work.md` did). Drop quickfix's "inherits by delegating".
- **AskUserQuestion block** (`:1368-1386`): ten copies, nine commands
  (`tce/{init,intent,refresh,ticket}`, `tmt/{init,update}`, `tle/define`,
  `tsf/{init,spec}`) plus `plugins/tce/references/work-loop.md`. Say why the
  loop copy sits in a reference: the loop's dialog sites live there.
- **TP-0022** (`:1388-1423`): two copies, the `tickets.md` template
  (canonical) and `intent.md`. `research.md`'s check is gone.
- **Testing changes**: no change.

**File**: `CONTRIBUTING.md`
**Changes**: `:85` → name the loop span instead of the composite rule.

#### 2. READMEs

**File**: `plugins/tce/README.md`
**Changes**:
- `:12`: quickfix "runs a small fix from your description to a verified
  change — no ticket".
- `## Commands` (`:204-248`): every step command takes `<ticket | intent
  path>`; quickfix's row describes the lane; add one line on ticketless
  intents.
- `## Running /tce:work` (`:250-312`): retitle to "Running the step
  commands". The environment requirement (`:289-301`) applies to
  `/tce:research`, `/tce:plan`, `/tce:implement`, `/tce:quickfix` and
  `/tce:work`. `/tce:implement` never delivers; `/tce:work` delivers.

#### 3. Templates and this repo's profile

**File**: `plugins/tce/templates/tce/profile.md` (`:74`), `.claude/tce/profile.md` (`:87-88`)
**Changes**: "the composites `/tce:work` / `/tce:quickfix`" → "`/tce:work`".
`/tce:quickfix` never branches. Repo profile `:62-65` "Composite commands
track single-step commands" → "Step working lives once, in the agents and
`work-loop.md`".

**File**: `plugins/tce/references/research-document-template.md` (`:2-9`), `plugins/tce/references/intent-document-template.md` (`:9`)
**Changes**: Header comments name the `researcher` agent and the step
commands instead of the composites; drop the composite-tracking sentence.

#### 4. Release

**File**: `plugins/tce/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
**Changes**: `1.4.3` → `1.5.0` in both. After the phase commit, run
`claude plugin tag ./plugins/tce`.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` and `claude plugin validate ./plugins/tce` pass
- [ ] `grep -n "Composite commands must track\|implement_eco" CLAUDE.md CONTRIBUTING.md` returns nothing
- [ ] `grep -rn "composite" plugins/tce/references plugins/tce/templates .claude/tce` returns nothing
- [ ] The ten AskUserQuestion copies (the nine commands named above plus `work-loop.md`) extract and diff empty pairwise, and `grep -ln "### AskUserQuestion dialog guidelines" plugins/*/commands/*.md plugins/tce/references/*.md | wc -l` prints 10
- [ ] `grep -n "BASH_DEFAULT_TIMEOUT_MS" plugins/tce/README.md` sits in a section that names all five step commands
- [ ] `git tag --list 'tce--v*'` shows `tce--v1.5.0`

#### Manual Verification:

- [ ] CLAUDE.md read top to bottom: every span names files that exist, and none names `research.md`/`plan.md`/`implement.md`/`quickfix.md` as carrying step working

---

## Phase 6: Real run in a consuming project

### Overview

Prove the rewired chain on real work, as the ticket requires.

### Changes Required:

None in this repo, unless the run finds a defect. A defect is fixed here with
its own commit, and the run repeats.

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tce` passes after any fix from the run

#### Manual Verification:

- [ ] In a consuming project with tce 1.5.0 installed and both environment variables exported, a real ticket with an intent runs `/tce:research <ID>` → `/tce:plan <ID>` → `/tce:implement <ID>`. `stage.sh <ID>` then shows research, plan and `N/N`; the plan ends with `## Verification` and `## Implementation Closeout`; a dossier exists.
- [ ] Interrupting `/tce:implement` after one phase and re-running it continues at the next phase
- [ ] `/tce:quickfix "<a real small fix>"` writes `thoughts/shared/intents/YYYY-MM-DD-<slug>.md` with `ticket: none`, creates no ticket file, and ends with a ticketless dossier; `stage.sh <slug>` finds intent, research and plan
- [ ] Without `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`, `/tce:plan <ID>` refuses with the preflight message naming `/tce:plan`
- [ ] `/tce:research "how does login work?"` (free text, no ticket ID or intent path) refuses with the pointer to `/tce:intent` or `/tce:discuss`, and writes nothing
- [ ] `/tce:quickfix` on a description that needs more than two phases (or a new UI flow) stops with the "larger than a quickfix" message, after writing only the intent, research and plan

---

## Testing Strategy

### Unit Tests:

- No test suite exists (markdown plugin). Script behaviour is smoke-tested in
  scratch projects only where this plan changes a script: Phase 3's
  `branch.sh switch`. `stage.sh`, `ticket.sh` and `work.sh` are unchanged, and
  their ticketless behaviour is exercised end to end in Phase 6.

### Integration Tests:

- `claude plugin validate` per phase. Grep assertions that inline working is
  gone and the loop reference is read. The pairwise diff of the
  AskUserQuestion copies.

### Manual Testing Steps:

1. Step-by-step run of a real ticket (Phase 6).
2. One real `/tce:quickfix` run (Phase 6).
3. Preflight refusal from a step command (Phase 6).

## Performance Considerations

Every step now runs in a fresh agent, so a standalone `/tce:research` costs
the same as the research step of `/tce:work`. The main context of each
command stays short: no inline prose, and one reference file read at point of
use.

## Migration Notes

- Projects keep working without config changes. Their `tickets.md` may still
  name `/tce:quickfix` under `## Creating a ticket`; that text is now
  descriptive only and harmless.
- Users who called `/tce:research "<question>"` get a refusal pointing to
  `/tce:discuss` or `/tce:intent`.
- Users who ran the single-step commands without the environment variables
  now get the preflight refusal. The README states the requirement.
- In-flight plans written by the old `/tce:plan` have the same structure, so
  `/tce:implement` picks them up at row 7 or 8 of the renumbered table.

## References

- Original ticket: `TP-0045c` (`thoughts/shared/tickets/TP-0045c-single-step-commands-on-agents.md`)
- Intent: `thoughts/shared/intents/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
- Related research: `thoughts/shared/research/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
- Precedent: `thoughts/shared/plans/2026-10-13-TP-0045b-step-agents-orchestrating-work.md`
- Loop source: `plugins/tce/commands/work.md:30-271`, `plugins/tce/references/work-dispatch.md`
