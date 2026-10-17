---
date: 2026-10-17T06:14:28Z
git_commit: 7a999118d9c4298aaaaa1e2ab7718dfbc5956c5b
branch: main
repository: toby-plugins
topic: "TP-0045c: the single-step commands, quickfix and ticketless runs on the shared step agents"
tags: [research, tce, work, research, plan, implement, quickfix, intent, step-agents, stage-sh, ticketless]
status: complete
last_updated: 2026-10-17
---

# Research: TP-0045c — the single-step commands, quickfix and ticketless runs on the shared step agents

**Date**: 2026-10-17T06:14:28Z
**Git Commit**: 7a999118d9c4298aaaaa1e2ab7718dfbc5956c5b
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0045c, as agreed in its intent
(`thoughts/shared/intents/2026-10-17-TP-0045c-single-step-commands-on-agents.md`):
how do `/tce:research`, `/tce:plan`, `/tce:implement` and `/tce:quickfix`
work today, what does `/tce:work`'s dispatch / ask / resume loop consist of,
what in the five step agents, the scripts and the templates assumes a ticket,
what does `/tce:intent` offer for an autonomous ticketless mode, and which
CLAUDE.md rules and README passages name the composite, quickfix's ticket
creation or `implement_eco`. The intent's eight "Questions for research" are
answered in the Summary.

## Summary

**Today there are two descriptions of every step.** `research.md` (384
lines), `plan.md` (457) and `implement.md` (383) still carry their full inline
working, their own dialog sites and their own script calls; the five step
agents (`researcher`, `planner`, `plan-challenger`, `implementer`, `verifier`)
carry the same working for `/tce:work` only. `quickfix.md` (291) inlines the
research step and Skill-delegates ticket creation, planning and
implementation to the inline commands. `implement_eco.md` is an 18-line
`model: sonnet` wrapper that Skill-invokes `tce:implement`; nothing outside
`thoughts/` names it, and the README "Cost tuning" section it points to was
planned in TP-0024 Phase 3 and never written.

**The loop already lives mostly in reference files.** `work.md` (271 lines)
is the orchestrator; three references carry the mechanism:
`work-dispatch.md` (position table, payloads, bounds, resume, stop
rendering), `work-brief.md` (question, brief and delta layout) and
`agent-returns.md` (the `tce-return` shape and retry note). What `work.md`
itself still holds inline is the step sequence: preflight (Step 0), ticket
(1), branch `switch` (2), intent/parent refusal (3), position (4), and Steps
5–12 (research, planning with the challenger and approval, implement with the
research baseline, verify with the base-commit fallbacks and the fix loop,
dossier, delivery, closeout, the pending-items confirmation).

**Answers to the intent's questions for research:**

1. *Ticketless naming and discovery.* No ticketless research, plan or dossier
   naming exists today: the researcher, planner and verifier embed
   `[PREFIX]-XXXX` in their filenames. Ticketless intents are named
   `YYYY-MM-DD-<slug>.md` (`intent.md:337-343`). Run against a scratch project,
   `stage.sh <slug>` (bare slug, no date) already finds intent, research and
   plan named `<date>-<slug>…` through its `*-<id>.md` / `*-<id>-*` patterns;
   `stage.sh <date>-<slug>` finds nothing (no `-` precedes the date); a shorter
   tail of the slug and a ticket intent ending in the same slug also match, and
   the last match in glob order wins. `ticket.sh` with an intent *path* prints
   nothing and exits 0. Details under "Discovery scripts".
2. *Where the loop's reference splits.* `work-dispatch.md` and `work-brief.md`
   are already shared-loop material; what is `/tce:work`-specific inline in
   `work.md` is listed under "`/tce:work` and its references".
3. *"No ticket" in payloads.* Every payload's common block starts with
   `ticket:` and `ticket-file:`; `ticket-file: none` today means "a hosted
   ticket, read it via `tickets.md`", not "no ticket". The ticket-dependent
   places in each agent are listed under "The five step agents".
4. *AskUserQuestion block and branch dialog.* 13 byte-identical copies today
   (8 in tce); `implement.md` has none. The branch stop-and-ask dialog has 3
   copies (`research.md`, `intent.md`, `quickfix.md`), identical except for
   indentation. `work.md` carries the guidelines block but no branch dialog.
5. *Autonomous `/tce:intent`.* `intent.md` has no non-interactive path; both
   tracks end in a user confirmation. The precedent, `/tce:ticket
   --autonomous`, returns the ID on success and defines no failure shape.
6. *`plan.md`'s dialog surface.* Eight dialog sites (listed below); the
   planner's modes replace the understanding message, the open-questions
   round and the design-options pick; the brief replaces the outline approval
   and the Step 5 review loop.
7. *`/tce:review`.* It references none of the verifier, the gate, the dossier
   or the closeout; it greps commit messages by ticket ID and keys every
   lookup on a ticket ID.
8. *Rules and README passages to rewrite.* Listed under "CLAUDE.md, README
   and template references".

## Detailed Findings

### `/tce:work` and its references (the loop being extracted)

- `plugins/tce/commands/work.md:1-6` — frontmatter: `argument-hint:
  "[ticket-id]"`, `disable-model-invocation: true`, `allowed-tools` grants
  `ticket.sh`, `stage.sh`, `branch.sh`, `baseline.sh`, `work.sh`,
  `git rev-parse`, `git log`, `git push`, `gh pr create`, `gh pr view`.
- `work.md:30-48` — the AskUserQuestion guidelines block.
- `work.md:52-70` — six invariants: one foreground agent per step; artifacts
  by path, never reading the research's or plan's body; the orchestrator's
  only writes (Closeout, confirmed Manual ticks, done transition, delivery);
  only `needs decision`/`blocked` reach the human; ask through
  AskUserQuestion so the run stays in one turn; position re-derived from disk.
- `work.md:72-83` — Step 0 runs `work.sh preflight` and prints a fixed
  refusal block naming both variables.
- `work.md:85-89` — Step 1 resolves the ticket ID and reads the ticket
  ("with no argument, ask for one and stop").
- `work.md:91-102` — Step 2: under Branch per ticket, `branch.sh switch`;
  `missing` → refuse (no intent yet), never creates.
- `work.md:104-115` — Step 3: `ticket.sh` + `stage.sh`; empty `intent:` →
  refuse "No intent for [PREFIX]-XXXX — run `/tce:intent [PREFIX]-XXXX`
  first."; parent paths become `parent:`; design exploration is the planner's
  question.
- `work.md:117-136` — Step 4: read `work-dispatch.md` in full, take the first
  matching position row, print `continuing at <step>`; per-return handling
  (one retry with the `agent-returns.md` note, `work.sh artifact` check,
  stop rendering, concerns kept).
- `work.md:138-142` — Step 5 dispatches `tce:researcher`, keeps a drift line.
- `work.md:144-176` — Step 6: read `work-brief.md`; planner `questions` →
  AskUserQuestion with `Understood:`/`Approach:` intro → `write`; challenger
  up to 3 `challenge-fix` rounds; print brief + "Challenger notes:"; ask
  "Decisions for you" then `revise`; the "Approve the plan?" dialog (Approve /
  Stop here; free text = push-back → `revise`); `mode: brief` when reached
  from the position table with a plan already written; the design-exploration
  stop message names `/tce:design_explore [PREFIX]-XXXX`.
- `work.md:178-189` — Step 7: `baseline.sh <git_commit> <research-path>` →
  `research-baseline:`; one implementer per remaining phase, `base-commit:`
  from `git rev-parse HEAD` while the plan has none; continue only when
  `progress:` moved.
- `work.md:191-205` — Step 8: base commit from the plan's `**Base commit**`,
  a legacy `.status.md`, or the parent of
  `git log --grep="[PREFIX]-XXXX" … | tail -1`; `baseline.sh <base>
  <plan-path>`; no base → `blocked`; `needs decision` → implementer `fix`
  while `Final fix rounds` < 3/3.
- `work.md:207-210` — Step 9 dossier dispatch with the run's concerns.
- `work.md:212-226` — Step 10 delivery (Direct, or Pull request with
  `git push -u`, `gh pr view`, `gh pr create … --title "[PREFIX]-XXXX: <ticket
  title>" --body-file <dossier>`).
- `work.md:228-248` — Step 11: append `## Implementation Closeout` (gate,
  Manual verification, Merge reference, `Ticket: [PREFIX]-XXXX → Done`), done
  transition per `tickets.md`, commit via `/tce:commit`, print summary.
- `work.md:250-271` — Step 12: "Have you checked the items above?" (All pass /
  Not yet / free text = failure recorded `pending: … — last check failed`).
- `plugins/tce/references/work-dispatch.md:22-57` — position table, 9 rows
  (done → pending → dossier exists → dossier → verify → implement → brief +
  approval → plan questions → research); signals are `stage.sh`, `ticket.sh`
  (dossier existence = a path under `thoughts/shared/dossiers/`), and `grep
  -n` on fixed plan/research lines.
- `work-dispatch.md:59-107` — payloads: common block (`ticket:`,
  `ticket-file:`, `intent:`, `references:`, `profile:`, `tickets:`), then per
  agent and mode.
- `work-dispatch.md:109-121` — bounds (challenger 3 rounds in the run; phase
  `Fix rounds: n/3`; `Final fix rounds: n/3`), reset by setting `0/3`.
- `work-dispatch.md:123-133` — resume via `SendMessage` (planner only);
  re-dispatch fresh when the agent ID is lost.
- `work-dispatch.md:135-153` — stop rendering, whose last line is
  `Then:   /tce:work [PREFIX]-XXXX`.
- `plugins/tce/references/work-brief.md:1-131` — header says it is read by the
  planner and by `/tce:work`, and that a layout change updates this file,
  `planner.md` and `work.md`; sections: terminal constraints, questions,
  brief, delta, phrasing for the reader.
- `plugins/tce/references/agent-returns.md:1-109` — read by all five agents
  and by `/tce:work`; statuses `done | done with concerns | needs decision |
  blocked`; field order `status, step, artifact, summary, concerns,
  blocked-on`; `step` vocabulary `research | plan-questions | plan | brief |
  challenge | implement | fix | verify | dossier`; length bounds; the verbatim
  retry note.

`/tce:work`-specific text that names `/tce:work` itself inside the shared
material: the stop rendering's `Then:` line (`work-dispatch.md:144`), the
design-exploration stop message (`work.md:151-153`), the "Stop here" option
text "re-run /tce:work" (`work.md:170-171`, `259`), and `work-brief.md`'s and
`work-dispatch.md`'s header comments.

### `/tce:research` (`plugins/tce/commands/research.md`)

- `:1-5` — `argument-hint: "[ticket-id | research question]"`; grants
  `ticket.sh` and `branch.sh`; unflagged.
- `:19-37` — AskUserQuestion guidelines block.
- `:88-149` — Ticket Document Discovery: canonical ID (`:92`); read the ticket
  fully, then the intent if discovery returns one (`:93`, the TP-0013
  wording); `branch.sh create <branch> <base> <remote>` under Branch per
  ticket (`:94-113`, result handling `:107-110`); the verbatim base-branch
  dialog (`:115-130`); `ticket.sh` (`:134`) and the parent (`:139-149`).
- `:151-174` — Ticket Sufficiency Check; skipped when an intent exists
  (`:153-155`); one batched AskUserQuestion round otherwise.
- `:176-195` — free-form input: "a ticket reference or research question";
  without a ticket the branch step is skipped (`:97`) and the filename omits
  the ID (`:298`, `:303`); a canned message when no argument.
- `:197-345` — the inline research steps (agent fan-out `:215-265`, drift
  check `:276-286`, template read `:307`, present findings and "follow-up
  questions?" `:319-331`, commit `:333-336`, follow-up loop `:338-345`).
- `:347-384` — reuse/extension research and the Impact Analysis read.
- It calls neither `stage.sh` nor `work.sh`.

### `/tce:plan` (`plugins/tce/commands/plan.md`)

- `:1-5` — `argument-hint: "[ticket-id | path to ticket/plan file]"`; grants
  `ticket.sh` and `branch.sh`; unflagged.
- `:19-37` — AskUserQuestion guidelines block.
- `:60-98` — discovery: `branch.sh switch` (`:71`, prose on
  `missing`/`dirty`/`blocked` `:72-77`); `ticket.sh` (`:82`, `:92`, `:193`);
  TP-0013 re-read (`:65`, reinforced `:105`).
- Dialog sites (eight):
  1. branch switch outcomes in prose (`:72-77`);
  2. no-argument message (`:161-177`);
  3. open-questions resolution, one AskUserQuestion call, "WAIT … never pick
     an option yourself" (`:122-150`, applied at Step 1.6 `:230-256`);
  4. Design Exploration Check — `ls`/`grep` on
     `thoughts/shared/mockups/*/DECISION.md`, prose offer of
     `/tce:design_explore` (`:258-286`);
  5. Step 2 (only without research): corrections and "Which approach aligns
     best with your vision?" (`:296-355`);
  6. outline approval "Does this phasing make sense?" (`:363-382`);
  7. UI-approach feedback (`:395`);
  8. Step 5 decision summary and refine-until-satisfied loop (`:414-450`).
- `:361`, `:410` — reads `plan-document-template.md` in full.
- `:452-457` — commit; "Your job ends here."
- Mapping to the planner (TP-0045b plan lines 527-532): `mode: questions`
  replaces the understanding message, the open-questions round and the
  design-options pick; `mode: write` has no outline approval, the brief being
  the approval surface. The planner's `questions` mode runs the
  design-exploration check itself (`planner.md:95-104`).

### `/tce:implement` (`plugins/tce/commands/implement.md`)

- `:1-5` — `argument-hint: "[ticket-id | plan path]"`; grants `ticket.sh`,
  `baseline.sh`, `branch.sh`, `git diff`, `git log`, `git rev-parse`;
  unflagged.
- No AskUserQuestion guidelines block; every dialog is prose.
- `:40-65` — discovery with `branch.sh switch` (`:51`, outcomes `:53-56`).
- `:67-84` — repository state check with `baseline.sh <git_commit>
  <research-path>` (`:71`) and the TP-0013 chain-order re-read (`:77-84`).
- `:105-149` — implementation log format (Status, `**Base commit**` on the
  first phase only, Commit, Did, Issues, Verification) and rules (legacy
  `.status.md` read-only, etc.).
- `:168-189` — its own Design Exploration Check (prose).
- `:202-214` — the plan-mismatch STOP template.
- `:243-261` — final verification.
- `:263-329` — Plan-Compliance Gate: criteria = ticket acceptance criteria +
  plan Automated/Manual items (no intent criteria, `:271-276`); diff from the
  Base commit via `baseline.sh` (`:280`) with `.status.md` and `git log
  --grep` fallbacks (`:278-298`); dispatches `plan-compliance-checker`; "not
  met" loops "until clear" (unbounded); Manual items confirmed in prose
  (`:320-329`).
- `:128-138` — Closeout template; `:331-348` — start/done transitions.
- It does not run the verifier, write a `## Verification` section or a
  dossier, and does not use the `Fix rounds` counters.

### `/tce:implement_eco` (`plugins/tce/commands/implement_eco.md`)

- `:1-6` — `model: sonnet`, `disable-model-invocation: true`, no
  `allowed-tools`.
- `:11-12` — points to "the tce README's 'Cost tuning' section".
- `:18` — "Invoke the `tce:implement` skill (via the Skill tool) with
  `$ARGUMENTS` as args."
- Not listed in CLAUDE.md's TP-0017 classification (`CLAUDE.md:512-575`), the
  README command tables, or anywhere else outside `thoughts/`.

### `/tce:quickfix` (`plugins/tce/commands/quickfix.md`)

- `:1-6` — `argument-hint: "[bug or correction to fix]"`,
  `disable-model-invocation: true`, grants only `branch.sh`.
- `:15` — calls itself a "**composite command**".
- `:20` and `:106-108` — the ticket-creation-policy refusal: "if that section
  says ticket creation is not allowed, STOP immediately: tell the user to
  create the ticket in their ticket system themselves and run `/tce:work
  <ticket-id>` instead."
- `:26-44` — AskUserQuestion guidelines block.
- `:68-94` — Phase 1: clarity test and focused questions, confirm once.
- `:98-124` — Phase 2: Skill `tce:ticket --autonomous` with the understanding;
  commits the ticket itself.
- `:128-182` — Phase 3 inlines the research step: re-read ticket and intent
  (`:134`), `branch.sh create` (`:135-145`), the verbatim branch dialog
  (`:147-162`), the agent list (`:164-171`), template read and naming
  `YYYY-MM-DD-[PREFIX]-XXXX-description.md` (`:173`), commit.
- `:186-206` — Phase 4: Skill `tce:plan` with autonomy overrides (skip
  structure review, resolve questions from research, ask only on genuine
  ambiguity, 1–2 phases, design-exploration flag = too big).
- `:210-225` — Phase 5: Skill `tce:implement`.
- `:229-280` — Final Summary with the plan-compliance gate line (`:247`).
- `:286` — "size is always Small"; bigger → stop and point to `/tce:ticket`,
  `/tce:intent`, the normal workflow.

### `/tce:intent` (`plugins/tce/commands/intent.md`) and the intent template

- `:1-5` — `argument-hint: "[ticket ID | intent path | thoughts/ document |
  description]"`; grants `stage.sh` and `branch.sh`; unflagged.
- `:38-45` — reads `## Reader`.
- `:52-70` — AskUserQuestion guidelines block.
- `:74-109` — input classification: (a) ticket reference, (b) a path into
  `thoughts/shared/intents/` (update; fetch the ticket if `ticket:` is not
  `none`), (c) another `thoughts/` path as `source:`, (d) anything else =
  ticketless.
- `:111-150` — `branch.sh create` for (a)/(b)-with-ticket only; the verbatim
  dialog (`:135-150`).
- `:152-169` — existing intent: (a) via `stage.sh`'s `intent:` line; (c)/(d)
  by checking `thoughts/shared/intents/*-<slug>.md`; "Never create a second
  intent for a ticket."
- `:171-188` — the sufficiency test (one of the three TP-0022 copies).
- `:190-326` — size proposal, Compressed (≤2 rounds) and Full (7 phases)
  tracks; both end in a confirmation (`:244-246`, `:322-326`, `:330`). No
  `--autonomous` flag, no design-exploration handling.
- `:328-349` — writing: ticket intent
  `thoughts/shared/intents/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`, ticketless
  `thoughts/shared/intents/YYYY-MM-DD-<slug>.md`; commit via `/tce:commit`
  with no ticket scope when ticketless.
- `:351-363` — hand-off; the ticketless hand-off tells the user to create a
  ticket with `/tce:ticket` and re-run `/tce:intent <ID>`.
- `plugins/tce/references/intent-document-template.md:30-39` — frontmatter
  `ticket: [PREFIX]-XXXX  # or: none`, `ticket_ref: … # or: none`, `source:`,
  `size:`, `status:`, `last_updated`; `:45-47`, `:97-98` — ticketless:
  `ticket: none`, `ticket_ref: none`, `## Ticket` says where the input came
  from.

### `/tce:ticket --autonomous` (the autonomous-mode precedent)

- `plugins/tce/commands/ticket.md:61-62` — triggered by `--autonomous` in the
  arguments ("used by `/tce:quickfix`").
- `:197-212` — skips the discussion, the policy warning/override and the
  hand-off; complexity hardcoded Small, "Open Questions: None — well-understood
  quickfix"; for a file backend "the caller handles the commit"; "Return the
  canonical ID (and file path or URL) to the caller." No failure return shape;
  it relies on the caller having checked the policy (`:199-200`).

### The five step agents (what assumes a ticket)

All five are `model: inherit`; four use `disallowedTools: AskUserQuestion`;
`plan-challenger` has `tools: Read, Grep, Glob, LS`.

- **researcher** (`plugins/tce/agents/researcher.md`) — receives `ticket:`,
  `ticket-file:`, `intent:`, `parent:`, `branch:`, `references:`, `profile:`,
  `tickets:`, optional `note:` (`:49-64`); the only agent that checks
  `git branch --show-current` against `branch:` (`:66-67`); reads ticket →
  intent → parent (`:74-81`); filename
  `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-description.md` "the
  canonical ID exactly (the discovery script globs for it)" (`:153-155`); its
  "Dialog sites become data" section (`:177-190`) names the branch dialog as
  the orchestrator's.
- **planner** (`plugins/tce/agents/planner.md`) — receives `ticket:`,
  `ticket-file:`, `intent:`, `research:`, `parent:`, `references:`,
  `profile:`, `tickets:`, `mode:` (`questions | write | revise |
  challenge-fix | brief`), `answers:`, `push-back:`, `findings:`, `plan:`
  (`:30-52`); no `branch:`; design-exploration lookup
  `grep -rl "[PREFIX]-XXXX" thoughts/shared/mockups/*/DECISION.md` (`:99`);
  filename `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-description.md`
  (`:127-130`); the plan template's only ticket reference is "Original
  ticket: `[PREFIX]-XXXX`" (`plan-document-template.md:134`).
- **plan-challenger** (`plugins/tce/agents/plan-challenger.md`) — receives
  `plan:`, `intent:`, `research:`, `profile:`, `references:`, `brief:`
  (`:15-30`); no ticket field and no ticket dependence (checklist item 4 is
  the intent's criteria, `:52-53`).
- **implementer** (`plugins/tce/agents/implementer.md`) — receives the common
  block plus `research:`, `plan:`, `mode: phase | fix`,
  `research-baseline:`, `phase:`/`phases:`, `base-commit:`, `findings:`
  (`:31-51`); applies the **start** transition on phase 1 per `tickets.md`
  (`:107-110`) and stages the ticket file if its status changed
  (`:143-145`); forbidden to write the Closeout or the done transition
  (`:24`, `:207`).
- **verifier** (`plugins/tce/agents/verifier.md`) — receives the common block
  plus `research:`, `plan:`, `baseline:`, `baseline-source:`,
  `mode: verify | dossier`, `concerns:` (`:29-46`); criteria = the ticket's
  acceptance criteria, then the intent's, then every phase's Automated and
  Manual items (`:70-77`); dossier filename
  `thoughts/shared/dossiers/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md` (`:138-140`),
  matching `dossier-template.md:32-33`; dossier heading
  `# Dossier: [PREFIX]-XXXX — [ticket title]` (`dossier-template.md:40`).

Each of the four committing agents invokes `tce:commit` through the Skill
tool and returns `blocked` when the commit workflow "would ask anything (its
branch check) or fails". No agent reports a size signal or a "larger than
expected" signal; the nearest counted facts are the brief's `Phases: n ·
tests in x/n · files touched f · manual checks c` line, the researcher's
`Open questions: <n>`, and the implementer's `blocked` on a plan mismatch
"that changes what the phase builds" (`implementer.md:111-117`).

### Discovery scripts (`plugins/tce/scripts/`)

- `ticket.sh:33` — `find "$THOUGHTS_DIR" -type f -name "*${TICKET}*" | sort`:
  substring of the basename, recursive over all of `thoughts/`.
- `stage.sh:64-66` — searches `research/`, `plans/`, `intents/` only (no
  dossiers); `stage.sh:81-104` — delimited match
  `*-"$doc_id"-*|*-"$doc_id".md`, non-recursive, last match in glob order
  wins; `:289-294` — the six-line record. No argument validation in either
  script beyond non-empty.
- `work.sh:46-68` — `preflight` (`foreground: ok | missing`, `timeout: ok |
  low (<v>)`, `detail:`); `work.sh:70-87` — `artifact <path>` resolves
  against the project root.
- `branch.sh` — `create | switch | check`; `switch` reports `missing` with the
  detail "branch $BRANCH does not exist; /tce:research creates it".
- `baseline.sh` — `baseline:` / `source: recorded | introducing | none` /
  `detail:`.

Behaviour with ticketless names, run in a scratch project with files
`2026-10-17-fix-login-redirect.md` in `research/`, `plans/`, `intents/`,
`dossiers/`, plus `intents/2026-10-16-MYAPP-0042-fix-login-redirect.md` and
`research/2026-10-18-fix-login-redirect-v2.md`:

- `stage.sh fix-login-redirect` → intent, plan and research found;
  `research:` is the `-v2` file (last match via `*-<id>-*`); `intent:` is the
  ticketless one (it sorts after the `2026-10-16-MYAPP-0042-…` file, which
  also matches `*-fix-login-redirect.md`).
- `stage.sh 2026-10-17-fix-login-redirect` → empty record, `source: no-plan`
  (no `-` precedes the date at the start of the basename).
- `stage.sh redirect` → the same documents as the full slug (a tail of the
  slug matches `*-<id>.md`).
- `ticket.sh fix-login-redirect` → all six files, including the dossier and
  the MYAPP-0042 intent.
- `ticket.sh thoughts/shared/intents/2026-10-17-fix-login-redirect.md` → no
  output, exit 0.

### `/tce:review` (`plugins/tce/commands/review.md`)

- `:1-6` — flagged; grants `ticket.sh`, `branch.sh` (no `baseline.sh`).
- `:117-129` — `branch.sh switch` under Branch per ticket.
- `:131-148` — reads all documents `ticket.sh` finds, naming ticket, intent
  (`thoughts/shared/intents/*[PREFIX]-XXXX*.md`), research, plan, discussions.
- `:150-162` — diff from `git log --all --grep="[PREFIX]-XXXX"
  --since="3 months ago"`.
- `:183-240` — nine review questions; acceptance criteria as prose.
- `:298-300` — writes `thoughts/shared/reviews/YYYY-MM-DD-[PREFIX]-XXXX-review.md`
  (or `…-description-review.md` for a custom scope).
- No reference to the verifier, the plan-compliance checker, `## Verification`,
  the dossier, `## Implementation Closeout` or `**Base commit**`; no
  precondition on how implementation ended. A ticketless intent has no entry
  path other than the custom-scope review (`:244-255`).

### CLAUDE.md, README and template references

**CLAUDE.md** (repo root):

- `:244-285` — "Composite commands must track the single-step commands"
  (quickfix as the one composite; the temporary "agents mirror the
  single-step commands until TP-0045c" rule at `:276-285`).
- `:134` — reference-file paragraph names "the composite-tracking and TP-0013
  rules".
- `:287-344` — TP-0020 gate span (`plan-compliance-checker.md`,
  `implement.md`, `verifier.md`, `quickfix.md`), with `baseline.sh`,
  `implement.md`, `work.md`, `verifier.md` as the baseline span.
- `:346-407` — TP-0031 branch span; names `research.md` (`create`),
  `intent.md` (`create`), `work.md` (`switch`), `quickfix.md` (inline
  re-description with the dialog copy), `plan.md`/`implement.md`/`review.md`
  (`switch`), `commit.md` (`check`); the rule at `:398-405` ties quickfix and
  intent to the research step's dialog copy.
- `:409-434` — TP-0045a intent span (template, `intent.md`, `stage.sh`,
  `list.md`).
- `:453-510` — TP-0045b orchestrator section with its three spans
  (return shape, brief/question layout, fix-loop counter).
- `:512-575` — TP-0017: delegation targets `ticket, intent, research, plan,
  implement, commit`; user-only `init, refresh, work, quickfix, review,
  discuss, design_explore`; `list` deliberately unflagged; `/tce:quickfix`
  Skill-invokes `tce:ticket`/`tce:plan`/`tce:implement` (`:520-521`).
  `implement_eco` is in neither list.
- `:1321-1349` — TP-0013 re-read rule; names `research`, `plan`, `implement`,
  `review`, `quickfix` and the five agents; `quickfix.md` "inherits
  planning/implementation reads by delegating".
- `:1368-1386` — AskUserQuestion block duplication rule, "thirteen commands".
- `:1388-1423` — TP-0022 sufficiency copies (`tickets.md` template,
  `research.md`, `intent.md`).

**plugins/tce/README.md**:

- `:12` — "`/tce:quickfix` fixes small annoyances fully autonomously".
- `:204-248` — `## Commands` (core table `:211-217`, shortcuts `:221-224`
  with quickfix "Run the full chain for a small fix, fully autonomous (no
  ticket discussion)").
- `:250-312` — `## Running /tce:work`; the environment requirement at
  `:289-301` is stated for `/tce:work` only. No "Cost tuning" section, no
  `implement_eco`.

**Templates and references:**

- `plugins/tce/templates/tce/tickets.md:32-40` — "Creating a ticket"
  placeholder: used by `/tce:ticket` and `/tce:quickfix` (autonomously);
  "not allowed" → `/tce:quickfix` refuses.
- `plugins/tce/templates/tce/tickets.md:111-112` — "Without an intent,
  `/tce:research` (and `/tce:work`) apply it before researching." (the
  canonical sufficiency copy; `/tce:work` no longer applies it since
  TP-0045b, `CLAUDE.md:1407-1409`). The same sentence is in this repo's
  `.claude/tce/tickets.md:96-97`.
- `plugins/tce/commands/init.md:283-289` — the verbatim "May tce create
  tickets autonomously?" dialog: "**Allowed (Recommended)** — /tce:quickfix
  can file a small ticket itself" / "**Not allowed** — /tce:quickfix will
  refuse …".
- `plugins/tce/templates/tce/profile.md:74` (and `.claude/tce/profile.md:88`)
  — Branch convention prose names "the composites `/tce:work` /
  `/tce:quickfix`".
- `plugins/tce/references/research-document-template.md:2-9` and
  `plan-document-template.md:9` — header comments name the composite commands
  and the composite-tracking rule.
- `plugins/tce/references/intent-document-template.md:9` — names `quickfix`
  among the chain commands that read an intent.
- `plugins/tce/commands/implement.md:71`, `:77`, `:123`, `:267` — mention
  `/tce:work` / `/tce:quickfix` running steps back to back.
- `CONTRIBUTING.md:85` — mentions "composite commands must track the
  single-step commands".

## Code References

- `plugins/tce/commands/work.md:72-271` — the step sequence (Steps 0–12)
- `plugins/tce/references/work-dispatch.md:41-51` — position table
- `plugins/tce/references/work-dispatch.md:65-107` — payloads
- `plugins/tce/references/work-dispatch.md:139-145` — stop rendering
- `plugins/tce/references/agent-returns.md:93-109` — retry note
- `plugins/tce/commands/research.md:115-130` — branch dialog copy 1
- `plugins/tce/commands/intent.md:135-150` — branch dialog copy 2
- `plugins/tce/commands/quickfix.md:147-162` — branch dialog copy 3
- `plugins/tce/commands/intent.md:337-343` — intent naming
- `plugins/tce/agents/researcher.md:153-155` — research naming
- `plugins/tce/agents/planner.md:127-130` — plan naming
- `plugins/tce/agents/verifier.md:138-140` — dossier naming
- `plugins/tce/agents/planner.md:99` — mockup lookup by ticket ID
- `plugins/tce/agents/implementer.md:107-110` — start transition
- `plugins/tce/scripts/stage.sh:81-104` — delimited match
- `plugins/tce/scripts/ticket.sh:33` — substring match
- `plugins/tce/scripts/work.sh:46-68` — preflight
- `plugins/tce/commands/ticket.md:197-212` — autonomous mode
- `plugins/tce/commands/implement_eco.md:1-18` — the eco wrapper

## Architecture Documentation

- **Orchestrator / agent split (TP-0045b).** The orchestrator runs every
  plugin script (a command's `allowed-tools` grant lasts one turn and does not
  reach subagents) and passes paths and values; agents read references from
  the `references:` path, commit through the `tce:commit` Skill, and never
  ask. Position is re-derived from disk after every step.
- **Dialog sites become data.** Each agent has a section mapping its
  command's dialog sites to return data (`researcher.md:177-190`,
  `planner.md` modes); only planning asks.
- **Reference files at point of use.** Commands and agents Read
  `${CLAUDE_PLUGIN_ROOT}/references/…` (agents: `<references>/…`) in full
  where they are needed; after compaction an invoked skill keeps its first
  5,000 tokens (platform docs, below).
- **Duplicated copies by design.** The AskUserQuestion guidelines block (13
  byte-identical copies across tce, tmt, tle, tsf — the CLAUDE.md rule says
  it is duplicated because it governs every dialog site through a command
  body and cross-plugin references are forbidden) and the branch dialog
  (3 copies).
- **Current invocation classification.** Flagged: `init`, `refresh`,
  `quickfix`, `design_explore`, `review`, `discuss`, `work`, `implement_eco`.
  Unflagged: `commit`, `intent`, `list`, `research`, `plan`, `implement`,
  `ticket`.

### Platform facts (Claude Code docs)

- `allowed-tools` grants "permission for the listed tools during the turn
  that invokes the skill … The grant clears when you send your next message"
  — https://code.claude.com/docs/en/skills#pre-approve-tools-for-a-skill.
  Whether a Skill-invoked skill's grant adds to the caller's, and whether a
  grant reaches dispatched subagents, is undocumented.
- A skill's `model:` "applies for the rest of the current turn" —
  https://code.claude.com/docs/en/skills#frontmatter-reference. Subagent model
  resolution: per-invocation parameter, then frontmatter (`inherit` "selects
  the main conversation's model"), then `CLAUDE_CODE_SUBAGENT_MODEL`, then the
  main model; before v2.1.251 the env var came first, and
  `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` (v2.1.257+) now forces it —
  https://code.claude.com/docs/en/sub-agents. Whether a command's turn-scoped
  `model:` counts as "the main conversation's model" for an `inherit` agent is
  undocumented; https://code.claude.com/docs/en/model-config says inheriting
  subagents resolve "from the one your session is using when Claude starts
  them".
- `disable-model-invocation: true` — "Claude Code blocks the call";
  https://code.claude.com/docs/en/skills#control-who-invokes-a-skill.
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` runs subagents in the foreground
  and makes a Bash command that reaches its timeout stop instead of
  backgrounding; `BASH_DEFAULT_TIMEOUT_MS` defaults to 120000 —
  https://code.claude.com/docs/en/sub-agents,
  https://code.claude.com/docs/en/env-vars,
  https://code.claude.com/docs/en/tools-reference.
- Compaction re-attaches each invoked skill's first 5,000 tokens within a
  25,000-token combined budget —
  https://code.claude.com/docs/en/skills#skill-content-lifecycle.
- `$ARGUMENTS` expands to the full argument string; a path is an ordinary
  string — https://code.claude.com/docs/en/skills#pass-arguments-to-skills.

## Impact Analysis

### Existing Usages Found

- `stage.sh` — called by `work.md:106-107` (position), `intent.md:152-169`
  (existing intent), `list.md` (record parsing; TP-0033 contract).
- `ticket.sh` — called by `research.md:134,144`, `plan.md:82,92,193`,
  `implement.md:62,75`, `review.md:131-134`, `work.md:106,110`; dossier
  existence in `work-dispatch.md:31-32`.
- `work.sh preflight` — called only by `work.md:74`.
- `branch.sh create` — `research.md:103`, `intent.md:122`, `quickfix.md:135-145`;
  `switch` — `plan.md:71`, `implement.md:51`, `review.md:121`, `work.md:97`;
  `check` — `commit.md`.
- Skill delegations into `research`/`plan`/`implement`: `quickfix.md:190`
  (`tce:plan`), `:214` (`tce:implement`), `implement_eco.md:18`
  (`tce:implement`); `quickfix.md:110` (`tce:ticket --autonomous`).
- Payload common block (`ticket:`, `ticket-file:`) — consumed by
  `researcher.md:53-55`, `planner.md:34-35`, `implementer.md:35-36`,
  `verifier.md:31-32`; ignored by `plan-challenger.md`.
- `[PREFIX]-XXXX` in agent-written filenames — `researcher.md:153`,
  `planner.md:127`, `verifier.md:138`, `dossier-template.md:32,40`.

### Current Contract

- **stage.sh**: input ≥1 opaque IDs; output one six-line record per ID
  (`ticket, research, plan, progress, source, intent`); match is a delimited
  basename segment in three directories; exit 0 for every outcome.
- **ticket.sh**: input one string; output absolute paths of every
  `thoughts/` file whose basename contains it.
- **Agent payloads**: `ticket:` is always a canonical ID; `ticket-file: none`
  means "read via `tickets.md`" (hosted backend), not "no ticket".
- **Stop rendering**: `Then: /tce:work [PREFIX]-XXXX`.
- **intent naming**: ticket `YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`, ticketless
  `YYYY-MM-DD-<slug>.md`; frontmatter `ticket: none` for ticketless.
- **Assumptions**: every agent-written document carries the canonical ID so
  `stage.sh`/`ticket.sh` find it; the implementer's start transition and
  `work.md`'s done transition assume a ticket; the verifier's criteria list
  starts with "the ticket's acceptance criteria".

### Adaptation Requirements

- `researcher.md:153-155`, `planner.md:127-130`, `verifier.md:138-140`,
  `dossier-template.md:32-40` — name documents without `[PREFIX]-XXXX` when
  there is no ticket, in a form `stage.sh`/`ticket.sh` find.
- `planner.md:99` — the mockup lookup keys on the ticket ID.
- `implementer.md:107-110`, `work.md:228-248` — start/done transitions and the
  Closeout's `Ticket:` line assume a ticket.
- `verifier.md:70-77` — "the ticket's acceptance criteria" as the first
  criteria source.
- `work.md:28`, `:85-115`, `:193-197` — ticket-only usage line, ticket read,
  `missing` intent refusal by ticket ID, `git log --grep="[PREFIX]-XXXX"`
  base-commit fallback.
- `work-dispatch.md:31-32`, `:66-67`, `:144` — dossier detection via
  `ticket.sh <ID>`, the common block, the `Then:` line.
- `research.md:151-174`, `:176-195` — the sufficiency check and the free-form
  question path the intent drops.

### Backward Compatibility Options

- Option A: ticketless documents named `YYYY-MM-DD-<intent-slug>.md` and
  discovered by passing the bare slug to the existing scripts — Pros: no
  script change (verified above); Cons: a slug tail or a ticket intent ending
  in the same slug also matches, and the last match in glob order wins.
- Option B: a distinct token for ticketless documents, or a `stage.sh` mode
  that takes an intent path — Pros: exact matching; Cons: changes the
  `stage.sh` record/argument contract that `list.md` parses (TP-0033 span).
- Option C: `ticket: none` in the common block with every agent branching on
  it — Pros: one field; Cons: `ticket-file: none` already exists with a
  different meaning.

## Historical Context (from thoughts/)

- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md` —
  stage 2 makes each single-step command "a one-step orchestrator running the
  same dispatch/ask/resume loop around one agent" (lines 64-74); the agents
  cannot just invoke the commands because `/tce:plan`'s dialog sites cannot
  run inside an agent (line 43). (This file is untracked in git at the
  research commit.)
- `thoughts/shared/plans/2026-10-13-TP-0045b-step-agents-orchestrating-work.md`
  — the six single-step commands stayed byte-identical and "Rewiring them is
  TP-0045c" (lines 104-106, 226); the `## Decisions` section and `Fix rounds`
  lines went into the shared plan template, so `/tce:plan` already produces
  that shape (137-140); the 1.4.1 fixes added to `/tce:work` things the
  single-step commands lack (closing confirmation, `research-baseline:`,
  base-commit fallbacks, exhausted-counter rule, design-exploration stop)
  (line 1209).
- `thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md`
  — dialog-site inventory (lines 45-55, 182-220); `implement.md`'s gate loop
  is unbounded (68-69, 296); "rewiring, quickfix and `implement_eco`
  retirement are deferred to 45c" (849-851).
- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` —
  the b→c gate run (GH-37); finding 1 (design exploration into the intent)
  and finding 2 (question form, TP-0047) are deferred by the intent.
- `thoughts/shared/plans/2026-07-12-TP-0024-eco-implement-wrapper-sonnet.md`
  — Phase 1 `⚠️ Partial` with the Sonnet-propagation Manual items unticked;
  Phases 2–3 (CLAUDE.md TP-0017 entries, README `## Cost tuning`) never
  started; TP-0024 is still `In Progress`.
- `thoughts/shared/tickets/TP-0047-communication-style-in-profile.md` — would
  loosen `/tce:work`'s AskUserQuestion invariant and touch the 13-copy block.
- `thoughts/shared/tickets/TP-0045d-orchestrator-improvements.md` — batches
  its items after TP-0045c lands.
- `thoughts/shared/research/2026-07-05-TP-0019-scale-adaptive-ticket-ceremony.md`
  — the autonomous ticket contract quickfix depends on and the Small-only
  lane.

## Related Research

- `thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md`
- `thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md`
- `thoughts/shared/research/2026-07-12-TP-0024-eco-implement-wrapper-sonnet.md`
- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md`
- `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md`

## Open Questions

1. **Ticketless document naming and discovery.** Should ticketless research,
   plan and dossier files be named `YYYY-MM-DD-<intent-slug>.md` and found by
   passing the bare slug to the existing `stage.sh`/`ticket.sh` (works today,
   but a slug tail or a ticket intent ending in the same slug also matches),
   or should they carry a distinct marker / should `stage.sh` gain an
   intent-path input (exact, but changes the record contract `list.md`
   parses)?
2. **How a payload says "no ticket".** `ticket-file: none` already means "a
   hosted ticket, read it via `tickets.md`". Should "no ticket" be
   `ticket: none` (and `ticket-file: none`), or a separate field, and should
   the intent path be the identifier the agents name documents after?
3. **What `/tce:research <ticket>` does when the ticket has no intent.**
   `/tce:work` refuses without an intent; `research.md` today runs its own
   sufficiency check instead. Should the rewired `/tce:research` refuse and
   point to `/tce:intent` like `/tce:work`, or keep a sufficiency path (which
   is a second step description, and one of the three TP-0022 copies)?
4. **Branch creation after the rewire.** `/tce:intent` cuts the ticket branch;
   `/tce:research` also runs `branch.sh create` with the dialog copy, while
   `/tce:work` only `switch`es. Should the rewired `/tce:research` switch only
   (like `/tce:work`, dropping its dialog copy, leaving `intent.md` as the one
   copy), or keep `create`?
5. **Where the AskUserQuestion guidelines block lives for step commands.**
   Keep one copy per command that asks (count changes: `implement.md` has none
   today and would gain dialog sites — gate items, the pending-items check —
   while `research.md` might lose all of its), or move it into the shared loop
   reference for the tce step commands (which changes the CLAUDE.md
   duplication rule's reasoning and count)?
6. **The "not small" signal for quickfix.** No agent reports size today. Is
   the planner's brief line (`Phases: n · files touched f`) read against a
   threshold by quickfix, or does an agent contract gain an explicit signal
   (a contract change the intent allows only "as rewiring requires")?
7. **Autonomous `/tce:intent`'s failure report.** The `/tce:ticket
   --autonomous` precedent defines no failure shape. What does autonomous
   `/tce:intent` return to quickfix when the sufficiency test fails, and does
   quickfix then ask the user (as Phase 1 does today) or stop?
8. **Wording that names quickfix's ticket creation.** `init.md:283-289`
   (verbatim dialog), `templates/tce/tickets.md:32-40` and the sufficiency
   sentence at `templates/tce/tickets.md:111-112` describe quickfix creating
   tickets and `/tce:work` applying the test. Does the "May tce create
   tickets autonomously?" dialog keep its meaning for `/tce:ticket` only, and
   does the `## Creating a ticket` section of existing consuming projects
   need an Idempotency upgrade entry?
9. **`implement.md`'s and `plan.md`'s extra behaviour not in the agents.**
   `implement.md`'s own Design Exploration Check (`:168-189`) and
   `plan.md`'s Step 2 (planning without research, `:288-355`) have no
   counterpart in the agents. Are they dropped (research becomes mandatory
   before `/tce:plan`, as `/tce:work` requires), or carried somewhere?
