# TP-0001: Prescribed Copy for AskUserQuestion Dialogs — Implementation Plan

## Overview

Give the tce/tmt commands' AskUserQuestion dialogs fixed, versioned copy: the four
predictable init dialogs get verbatim intro + question + option copy in the command
files; every dynamic AskUserQuestion site gets a shared, per-command "dialog copy
guidelines" block; a new named sync rule in the repo `CLAUDE.md` keeps the repeated
block from drifting. All verbatim wording is drafted and approved interactively with
Toby (Phase 1) before any file is edited.

## Current State Analysis

From `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md` (read it
for full detail; line anchors below are from commit 4967965):

- Exactly **5 explicit `AskUserQuestion` mentions** exist:
  - `plugins/tce/commands/init.md:126-139` — ticket-system question. Option labels/
    descriptions near-verbatim (tmt / GitHub Issues / Jira / Linear); question text
    not prescribed. Only site mentioning "(Recommended)" (`:128`) and the automatic
    "Other" (`:139`).
  - `plugins/tce/commands/init.md:141-151` — status-transitions + ticket-creation
    policy questions. Abstract only; sole mention of same-call batching (`:141`).
  - `plugins/tce/commands/init.md:153-155` — dynamic ambiguity fallback ("small set
    of concrete options" criterion).
  - `plugins/tmt/commands/init.md:67-68` — ambiguous-prefix fallback, abstract. The
    *primary* prefix flow is a plain-text proposal block (`tmt/init.md:53-65`).
  - `plugins/tce/commands/work.md:107-131` — open-questions checkpoint: names the
    tool and prescribes a flat-text framing template.
- The dynamic dialogs the ticket names live at: `research_codebase.md:75-92`
  (sufficiency check, "one batched round"; mirrored at `work.md:54`),
  `create_plan.md:99-147, 233-258` (open-questions resolution; mirrored at
  `work.md:84-131`, overridden at `quickfix.md:184-185`), plus quickfix's own
  clarity round (`quickfix.md:59-65`).
- **No shared guideline file exists** in either plugin; no command mentions the
  tool's limits, headers, or multiSelect anywhere.
- Tool constraints (research §5): 1–4 questions/call, 2–4 options, header ≤12
  chars, labels 1–5 words, automatic "Other" (never author one), recommended option
  first with "(Recommended)" appended (official tool guidance), `multiSelect` for
  non-exclusive choices, previews single-select only, **no documented markdown
  rendering — author all copy as plain text**, tool unavailable in subagents.

## Desired End State

- Running `/tce:init` and `/tmt:init` produces the same dialog wording every run;
  the wording lives in the command files and changes via commits.
- Every dynamic AskUserQuestion site instructs Claude to follow a guidelines block
  that is byte-identical across all command files that carry it.
- `CLAUDE.md` contains a named sync rule for that block, alongside the existing
  composite lock-step and init-nudge rules.
- Verify: `claude plugin validate` passes for marketplace + both plugins; the
  guidelines block extracts identically from all carrying files; a scratch-project
  dogfood run of both init commands shows the prescribed copy.

### Key Discoveries

- The "(Recommended)"-first pattern is the tool's own documented guidance, not just
  a dogfood habit — the guidelines block can state it as a hard rule.
- Intro text printed before the invocation renders above the dialog (confirmed in
  the dogfood run; ticket Notes 2026-06-12) — prescribed copy comes as intro +
  question pairs so question text stays short.
- The repo already manages deliberate duplication with named `CLAUDE.md` sync rules
  (composites lock-step; init-nudge three-way wording rule) — the guidelines block
  follows that established mechanism, not a new runtime-read mechanism.
- Cross-plugin file sharing is ruled out (`CLAUDE.md` "Core design rule": plugins
  coordinate only through project config files), so the block is duplicated into
  tmt rather than referenced from tce.

## What We're NOT Doing

- Converting plain-text menus/prompts to AskUserQuestion (code_review's menus,
  design_explore's feedback loop, tmt create's discussion phases, intake prompts) —
  per ticket Out of Scope and the planning decision "AskUserQuestion sites only".
- Touching non-dialog prose blocks (proposal templates, hand-off messages),
  `check-init.sh` wording (governed by its own sync rule), agents (tool unavailable
  in subagents), or `implement_plan.md`'s prose design-exploration blockquote.
- Redesigning which questions the flows ask, or the flows themselves. (The tmt
  prefix question changes *medium* — plain-text proposal → prescribed dialog — per
  the planning decision; the question and flow position are unchanged.)
- Version bumps / plugin releases (separate, human-decided per `CLAUDE.md`).
- Relying on markdown rendering inside dialog copy (not documented as supported).

## Implementation Approach

Draft all copy first and get Toby's approval in chat (the ticket's mandatory
review checkpoint, acceptance criterion 4) — then apply it in two plugin-scoped
commits (tce, then tmt), each keeping composite mirrors in lock-step, and finish
with the `CLAUDE.md` sync rule plus validation. Wording is deliberately NOT in
this plan; it is produced at the Phase 1 checkpoint. The plan fixes the
*requirements and structure* of the copy.

## Phase 1: Copy Drafting & Interactive Review Checkpoint

### Overview

Produce the complete "copy deck" and iterate with Toby in chat until approved.
**No file edits in this phase.** This satisfies acceptance criterion 4 before any
copy lands in a commit.

### Changes Required

None on disk. Draft and present, rendered as runtime mocks (intro paragraph, then
the dialog as the user would see it):

1. **The canonical guidelines block** (~10 lines of markdown, used verbatim in all
   carrying commands). Must cover exactly:
   - Intro-text pattern: print a short plain-prose paragraph (1–3 sentences) before
     invoking the tool; it carries all context. Question text contains only the
     question — no context, no nested parentheticals.
   - Recommended-first: detected/suggested option first, label suffixed
     " (Recommended)", the reasoning/provenance in that option's description.
   - Limits: 1–4 questions per call (batch related questions into one call), 2–4
     options per question, never offer an "Other"/custom option (added
     automatically), header chip ≤12 characters.
   - Copy style: labels 1–5 words; descriptions 1–2 plain sentences saying what
     choosing the option means/does; plain text only (no markdown); `multiSelect`
     only for non-mutually-exclusive choices, with the question phrased
     accordingly.
2. **Verbatim copy for the four predictable dialogs** — for each: intro paragraph,
   question text, header chip, all option labels, all option descriptions, and
   which parts are dynamic placeholders (e.g. detection reasoning, candidate
   prefixes):
   - `/tmt:init` ticket prefix (single question; detected prefix recommended-first,
     provenance in its description; other plausible candidates as options when
     found; intro carries "writes `.claude/tmt/config` + scaffolds
     `thoughts/shared/tickets/`").
   - `/tce:init` ticket system (4 fixed options; detected system ordered first with
     "(Recommended)" + detection reasoning in description).
   - `/tce:init` status transitions (tce updates vs remind-only; recommended side
     depends on chosen system — both orderings specified).
   - `/tce:init` ticket creation (autonomous creation allowed vs not; consequence
     for `/tce:quickfix` stated in descriptions).
3. **Prescribed framing templates for dynamic dialogs** (verbatim skeletons with
   placeholders): the restructured `work.md` checkpoint (intro-text template +
   AskUserQuestion usage per guidelines, replacing the current flat-text block at
   `work.md:113-129`), and the one-line guideline references used at the other
   dynamic sites.

### Success Criteria

#### Automated Verification

- [ ] n/a (no file changes)

#### Manual Verification

- [ ] Toby has explicitly approved the guidelines block text
- [ ] Toby has explicitly approved each of the four dialogs' full copy individually
- [ ] Toby has approved the work.md checkpoint framing template
- [ ] Every label fits 1–5 words (+" (Recommended)" where applicable); every header
      ≤12 chars; no option is an "Other"; all copy is plain text

---

## Phase 2: Apply to tce (guidelines block + init copy + dynamic sites) — one commit

### Overview

All tce edits in a single commit so composite mirrors (`work.md`, `quickfix.md`)
move together with their single-step sources (`CLAUDE.md` lock-step rule).
Surgical edits — preserve each command's structure and altitude.

### Changes Required

#### 1. Insert the guidelines block (identical bytes) into five commands

**Files**: `plugins/tce/commands/init.md`, `research_codebase.md`,
`create_plan.md`, `work.md`, `quickfix.md`
**Changes**: add the approved block as a clearly-headed subsection (consistent
heading, e.g. `### AskUserQuestion dialog guidelines`) at a consistent position
(within/near each command's preamble, before the first dialog site).

#### 2. `plugins/tce/commands/init.md` — verbatim dialog copy

- `:126-139` (ticket-system question): keep the existing structure (detected-first
  ordering instruction, "Other" note) but replace the abstract "ask about the
  ticket system" with the approved intro + question + header + the four options'
  final labels/descriptions.
- `:141-151` (policy questions): keep the same-call batching instruction; add the
  approved verbatim copy for both questions (intro, question texts, headers,
  option labels/descriptions, and the per-system recommended-side rule).
- `:153-155` (ambiguity fallback): point at the guidelines block.

#### 3. Dynamic sites reference the guidelines

- `research_codebase.md:75-92` (sufficiency check): instruct presenting the batched
  clarification round via AskUserQuestion following the guidelines block.
- `create_plan.md:99-147` and `:233-258` (open-questions resolution): same
  instruction; adjust the illustrative example (`:126-143`) only as far as needed
  to match the intro + dialog pattern.
- `work.md:54` (sufficiency mirror) and `work.md:107-131` (checkpoint): replace the
  flat-text template with the approved framing template; keep sources list
  (`:84-105`) and follow-up behavior (`:131`) intact.
- `quickfix.md:59-65` (clarity round) and `:184-185` (ask-only-on-ambiguity):
  reference the guidelines for the cases where it does ask.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .` passes (repo root)
- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] The guidelines heading appears in exactly these five tce commands (grep)

#### Manual Verification

- [ ] Applied copy matches the Phase 1 approved deck verbatim
- [ ] `work.md`/`quickfix.md` mirrors are consistent with the single-step sources
      they track (same commit)
- [ ] Commands read coherently around the insertions (structure/altitude preserved)

---

## Phase 3: Apply to tmt (guidelines block + prescribed prefix dialog) — one commit

### Overview

Replace `/tmt:init`'s plain-text prefix proposal and its ambiguity fallback with
the single prescribed dialog approved in Phase 1.

### Changes Required

#### 1. `plugins/tmt/commands/init.md`

- Insert the guidelines block (identical bytes, same heading/position convention
  as tce).
- Replace the proposal block (`:53-65`) and the fallback (`:67-68`) with the
  approved prescribed dialog: intro paragraph (carries provenance summary + what
  gets written: `.claude/tmt/config`, `thoughts/shared/tickets/` scaffold), one
  question, detected prefix first with " (Recommended)" and provenance in its
  description, additional plausible candidates as options when the analysis found
  any (2–4 options total; "Other" never authored — users type a custom prefix via
  the automatic Other).
- Keep the no-write-until-confirm gate (`:11`) and the idempotent-rerun behavior
  (`:111-116`) intact; adjust the latter's wording only if it references the
  removed proposal block.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate ./plugins/tmt` passes
- [ ] Guidelines heading present in `plugins/tmt/commands/init.md` (grep)

#### Manual Verification

- [ ] Applied copy matches the Phase 1 approved deck verbatim
- [ ] The prefix-change warning for existing-ticket projects (`:111-116`) still
      reads correctly against the new dialog flow

---

## Phase 4: CLAUDE.md sync rule + repo-wide verification — one commit

### Overview

Pin the duplication with a named rule and verify everything; close the ticket.

### Changes Required

#### 1. `CLAUDE.md` (repo root)

Add a named rule alongside "Composite commands must track the single-step
commands": the AskUserQuestion guidelines block is duplicated byte-identically
across the six carrying command files (list them); editing it means updating all
copies in the same commit; verbatim dialog copy is part of the command's contract
and changes via normal review.

#### 2. Verification + ticket close

- Extract the guidelines block from all six files (sed between its heading and the
  next heading) and diff — must be identical.
- Run all three `claude plugin validate` commands.
- Set `thoughts/shared/tickets/TP-0001-askuserquestion-copy.md` `**Status:**` to
  `Done` (policy: tce transitions statuses itself) and commit it with this phase.

### Success Criteria

#### Automated Verification

- [ ] `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` all pass
- [ ] Block-extraction diff across all six files is empty

#### Manual Verification

- [ ] Scratch-project dogfood (per `CLAUDE.md` "Testing changes"): `/tmt:init` and
      `/tce:init` present the prescribed copy; dialogs match the approved deck
- [ ] Ticket status is `Done`; acceptance criteria checkboxes in the ticket hold

---

## Testing Strategy

### Unit Tests

n/a — markdown-only changes; the profile's "test" is manifest validation
(`claude plugin validate`), run in Phases 2–4.

### Integration Tests

n/a (no scripts/hooks touched; `check-init.sh` wording explicitly untouched).

### Manual Testing Steps

1. In a scratch project: `/plugin marketplace add .`, install both plugins, run
   `/tmt:init` — verify intro paragraph renders above the dialog, detected prefix
   is first with "(Recommended)", provenance sits in the description (not in the
   question), header ≤12 chars.
2. Run `/tce:init` — verify the ticket-system dialog and the batched policy
   questions match the approved deck.
3. Run `/tce:work` on a ticket with open questions — verify the checkpoint follows
   the new framing template (intro text + dialog per guidelines).

## Performance Considerations

None — markdown prompt edits only. The repeated guidelines block adds ~10 lines of
prompt per command (negligible context cost).

## Migration Notes

None for consumers — no config formats, scripts, hooks, or templates change;
consumers pick the copy up with the next plugin update. No version bump in this
ticket (releases are decided separately).

## References

- Original ticket: `thoughts/shared/tickets/TP-0001-askuserquestion-copy.md`
- Related research: `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md`
- Lock-step rule + sync-rule precedents: `CLAUDE.md` ("Composite commands must
  track the single-step commands"; init-nudge three-way wording rule)
- Tool constraints sources: research doc "External Sources" (Agent SDK user-input
  reference + in-client tool description, observed 2026-06-12)
