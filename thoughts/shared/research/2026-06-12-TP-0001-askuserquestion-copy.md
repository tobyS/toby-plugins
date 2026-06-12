---
date: 2026-06-12T16:32:14Z
git_commit: 4967965e89fb3368de3a8b4657b643f3212c8d1f
branch: main
repository: toby-plugins
topic: "TP-0001: Prescribed copy for AskUserQuestion dialogs — site inventory, shared-content mechanisms, tool constraints"
tags: [research, codebase, tce, tmt, commands, askuserquestion, copywriting]
status: complete
last_updated: 2026-06-12
---

# Research: TP-0001 — Prescribed copy for AskUserQuestion dialogs

**Date**: 2026-06-12T16:32:14Z
**Git Commit**: 4967965e89fb3368de3a8b4657b643f3212c8d1f
**Branch**: main
**Repository**: toby-plugins

## Research Question

From the ticket's "Questions for Research/Planning":

1. Inventory all AskUserQuestion mentions across `plugins/tce/commands/` and `plugins/tmt/commands/` — which are predictable (verbatim copy) vs dynamic (guidelines)?
2. Where should the shared copy guidelines live so both plugins' commands can follow them without cross-plugin references — repeated per command, or one block per plugin?
3. Does the AskUserQuestion tool render markdown in option descriptions, and what length limits apply (header ≤12 chars; sensible label/description lengths)?

## Summary

- **Explicit `AskUserQuestion` mentions: exactly 5**, in 3 files — `plugins/tce/commands/init.md` (3 sites: ticket-system question, policy follow-ups, ambiguity fallback), `plugins/tce/commands/work.md` (open-questions checkpoint), `plugins/tmt/commands/init.md` (ambiguous-prefix fallback). Many more sites *ask the user something* without naming the tool (plain-text "respond with" blocks, blockquote questions) — the full inventory is below.
- **The four dialogs the ticket names as predictable** map to: `tmt/init.md` prefix (today a plain-text proposal block, AskUserQuestion only as ambiguity fallback) and `tce/init.md` ticket-system / status-transitions / ticket-creation (the first has near-verbatim option copy; the other two are described only abstractly, with no question text or option labels).
- **AskUserQuestion-specific affordances are referenced only in `tce/init.md`**: "(Recommended)" once (line 128), automatic "Other" once (line 139), same-call batching once (line 141). No file anywhere mentions question headers, the 4-question/4-option limits, or multiSelect. There is **no shared copy/style guideline file** in either plugin, and no per-plugin shared instruction file of any kind (no `skills/`, no `lib.md`).
- **Existing shared-content mechanisms** (candidates for where guidelines could live): per-command repeated boilerplate (the "Project context" preamble pattern), rule-governed deliberate duplication (the composite-commands lock-step rule in `CLAUDE.md`), runtime reads of project config markdown via `${CLAUDE_PROJECT_DIR}`, and plugin templates copied at init. Commands never read other plugin-internal markdown at runtime; cross-plugin coordination is config-files-only.
- **Tool constraints** (from the tool's own in-session description in Claude Code, corroborated/extended by Agent SDK docs): 1–4 questions per call; 2–4 options each; header chip ≤12 chars; "Other" is added automatically ("There should be no 'Other' option, that will be provided automatically"); recommended option goes first with "(Recommended)" appended to its label; `multiSelect: true` exists; option previews exist but are **single-select only**; descriptions render alongside labels (plain text — no documented markdown rendering, no documented length limits for question/label/description beyond the 12-char header); the tool is **not available in subagents**. Text printed before the invocation renders above the dialog (confirmed in the dogfood run, per the ticket's Notes).

## Detailed Findings

### 1. Explicit AskUserQuestion sites (5)

| # | Site | About | Predictable/Dynamic | Copy today |
|---|------|-------|---------------------|------------|
| A1 | `plugins/tce/commands/init.md:126-139` | Ticket-system selection (Phase 2) | **Predictable** (4 fixed options; ordering + detection reasoning vary) | Option labels/descriptions near-verbatim (4 numbered options: tmt, GitHub Issues, Jira, Linear); question sentence NOT prescribed ("ask about the **ticket system**") |
| A2 | `plugins/tce/commands/init.md:141-151` | Status-transitions + ticket-creation policy | **Predictable** (same 2 questions every run; recommended default depends on chosen system) | Abstract only — substance described, no question text or option labels |
| A3 | `plugins/tce/commands/init.md:153-155` | Ambiguity fallback in the profile proposal | Dynamic | Abstract; includes usage criterion "when a small set of concrete options exists" |
| A4 | `plugins/tmt/commands/init.md:67-68` | Ambiguous ticket prefix (fallback) | Dynamic (options = candidate prefixes found that run) | Abstract only |
| A5 | `plugins/tce/commands/work.md:107-131` | Open-questions checkpoint (Phase 2c) | Dynamic content, **prescribed framing** | Verbatim intro-block template ("I've completed research… **Context summary:**… **Questions that need your input before I create the plan:**", per-question "Context:" sub-bullet); question 3 (design-exploration) near-verbatim |

Notable details:

- A1 (`init.md:128`) is the **only "(Recommended)" mention in the repo**: "putting the detected system first with \"(Recommended)\" and noting *why* you detected it in its description" — this is the pattern the ticket says to keep.
- A1 (`init.md:139`) is the only acknowledgement of the automatic "Other": "(The user can pick \"Other\" for any custom system and describe it.)"
- A2 (`init.md:141`) is the only batching instruction: "in the same AskUserQuestion call where sensible".
- A5 prescribes a flat text block while `work.md:111` says "Use `AskUserQuestion` to present them" — the prescribed structure mixes the intro-text pattern with the dialog itself.
- The **tmt prefix question** named in the ticket is, in the current flow, a plain-text proposal block (`plugins/tmt/commands/init.md:53-65`: "**Proposed ticket prefix:** [PREFIX] … Anything to correct?") with AskUserQuestion only as the fallback when several candidates are plausible (A4).

### 2. Implicit ask sites (no tool named) — where shared guidelines would apply

Grouped by command; classification: **P** = predictable copy, **D** = dynamic content (often with prescribed framing).

**`plugins/tce/commands/research_codebase.md`**
- `:75-92` ticket sufficiency check — D, abstract ("ask the user focused clarifying questions — one batched round"). Mirrored at `work.md:54`.
- `:96-102` initial "I'm ready to research…" prompt — P, verbatim, free-text (suppressed in composites: `work.md:49`).
- `:298-302` follow-up invitation — D, abstract (suppressed: `work.md:76`, `quickfix.md:163`).

**`plugins/tce/commands/create_plan.md`**
- `:99-147` "Handling Open Questions from Research and Tickets" — D, with a verbatim *example* interaction (`:126-143`, plain text, "From Research:"/"From Ticket:" grouping, illustrative "Option A/B"). Mirrored by `work.md:84-131` (which is where `AskUserQuestion` gets named); overridden by `quickfix.md:184-185` (self-resolve, ask only on genuine ambiguity).
- `:159-175` no-parameters intake prompt — P, verbatim, free text.
- `:233-258` Step 1.5 informed understanding + focused questions — D, prescribed headings ("**Open questions that need your input:**…").
- `:260-288` Design Exploration Check — trigger D, copy P and verbatim blockquote (`:280-284`). Mirrored: `work.md:94-105` + checkpoint question 3 (`:126-129`); converted to escalation in `quickfix.md:187`. Sibling variant: `implement_plan.md:160-181` (verbatim blockquote `:175-177`).
- `:339-357` Step 2.5 findings + design options (no-research path) — D, prescribed framing incl. "Which approach aligns best with your vision?"
- `:363-379` plan-outline approval — D, verbatim closing ("Does this phasing make sense?…"); suppressed in `work.md:159`, `quickfix.md:183`.
- `:541-562` plan review round — P checklist questions, verbatim.

**`plugins/tce/commands/implement_plan.md`**
- `:158` ask for plan/ticket if missing — borderline intake, abstract.
- `:160-181` design-exploration check (implement-time) — P verbatim blockquote.
- `:194-206` plan/reality mismatch escalation — D, prescribed framing ("Issue in Phase [N]: / Expected:… / Found:… / How should I proceed?"); echoed `:262`, mirrored `work.md:200-204`, pause conditions `quickfix.md:205-208`.

**`plugins/tce/commands/quickfix.md`**
- `:50-52` intake ("What issue would you like me to quickfix?") — P, verbatim.
- `:59-65` clarity questions — D, prescribed intro line ("I want to make sure I understand the fix correctly:"); `:67` explicit non-ask ("Do NOT ask for permission to proceed").
- `:182-187, 205-208, 255` autonomy overrides / pause conditions — D, abstract.

**`plugins/tce/commands/code_review.md`**
- `:95-105` no-input prompt with an explicit plain-text "Options:" list (Ticket review / Custom review) — P, verbatim; the closest plain-text analogue to a choice dialog outside init.
- `:391-407` next-steps menu (Dig deeper / Expand review / Done) — P, verbatim, plain text.

**`plugins/tce/commands/discuss.md`**
- `:37-45` intake — P, verbatim, free text. `:29, 49` clarifying questions — D, abstract.

**`plugins/tce/commands/design_explore.md`** (most dialog-dense; all plain-text/blockquote, never names the tool)
- `:25` phase-gate policy ("Always get user confirmation before moving between phases") — P, abstract.
- `:45-53` intake — P, verbatim. `:62-72` screenshot request — P, verbatim, blocking.
- `:106-115` design-system gap report — D list, fixed yes/no closing.
- `:128-134` approach-count confirmation + mockup selection — verbatim; the selection ("choose one or multiple") is a **prose multi-select over dynamic options**.
- `:241-252` rendering-verification checklist — P, verbatim.
- `:254-276` iteration feedback menu (Eliminate/Refine/Combine/Choose) — P action labels over dynamic subjects, verbatim, loops until satisfied.

**`plugins/tce/commands/init.md`** (beyond A1–A3)
- `:12, 182` "Do not write any files until the user confirms" gate — P, abstract.
- `:101-124` Phase 2 proposal block — P structure/verbatim framing, dynamic values; includes the inline design-system yes/no (`:121-123`).
- `:159-166` Phase 3 refine + ticket-access verification — abstract. `:259-262` idempotent re-run ("ask whether to update specific values") — D, abstract.

**`plugins/tmt/commands/init.md`** (beyond A4)
- `:11` no-write-until-confirm gate — P, abstract.
- `:53-65` Phase 2 prefix proposal — P framing verbatim ("**Proposed ticket prefix:** [PREFIX]… Anything to correct?"), dynamic prefix + provenance.
- `:111-116` idempotent re-run + prefix-change warning — D, abstract.

**`plugins/tmt/commands/create.md`** (fully interactive discussion; plain text throughout)
- `:30-44` intake — P, verbatim. Phase closings and probe lists `:57-79, 85-92, 112-127, 139-163, 180-199` — verbatim question stems around dynamic content.
- `:202-212` complexity estimate — a natural **fixed four-option choice** (Small/Medium/Large/XL with per-option descriptions) presented as plain text with "Does this feel right to you?"
- `:216-263` Phase 6 open-questions split (Business now vs Research/Planning later) + deferral confirmation `:260`; `:267-289` final review/confirm gate; `:469-480` empty-sections probe.

**Other surfaces**
- `plugins/tce/scripts/check-init.sh:58-73` — SessionStart `additionalContext` instructs Claude to *offer* running `/tce:init` (a predictable yes/no offer, described abstractly, no question copy). Wording is subject to the three-way sync rule (`CLAUDE.md`: check-init.sh + plugin.json `userConfig` description + `plugins/tce/README.md`).
- `plugins/tce/templates/tce/tickets.md:68-73` — descriptive cross-references to the sufficiency-clarification and open-questions dialogs (lands in consuming projects).
- `plugins/tce/agents/*.md` — **no user-asking sites** (subagents; also see tool constraint below: AskUserQuestion is unavailable in subagents anyway).

### 3. Composite-mirror map (lock-step rule impact)

Per `CLAUDE.md` ("Composite commands must track the single-step commands"), any copy change to a mirrored dialog must update `work.md`/`quickfix.md` in the same commit:

| Dialog | Single-step source | Composite mirror(s) |
|---|---|---|
| Ticket sufficiency clarification | `research_codebase.md:89-92` | `work.md:36, 54` (kept, "one batched round"); quickfix has its own clarity check (`quickfix.md:54-65`) |
| Open-questions resolution | `create_plan.md:99-147, 233-258, 623-629` | `work.md:84-92 + 107-131` (**adds the `AskUserQuestion` name** — only mirrored dialog that names the tool); `quickfix.md:184-185` (self-resolve) |
| Design-exploration question | `create_plan.md:260-288`; sibling `implement_plan.md:160-181` | `work.md:94-105 + 126-129` (inlined as checkpoint question 3); `quickfix.md:187, 251` (escalation, never asked) |
| Plan-outline approval | `create_plan.md:363-379, 541-562` | suppressed: `work.md:159`, `quickfix.md:183` |
| Research presentation/follow-ups | `research_codebase.md:96-102, 298-302` | suppressed: `work.md:49, 76`, `quickfix.md:163` |
| tmt ticket template | `tmt/commands/create.md:315-370` | `quickfix.md:88-140` inlines the template, none of the discussion dialogs |

The init commands' dialogs (A1, A2, A4, prefix proposal) are **not** mirrored anywhere — verbatim copy there touches one file each. The design-exploration question exists in **three** variants (`create_plan.md`, `implement_plan.md`, `work.md`) plus a quickfix escalation.

### 4. Where could shared guidelines live — mechanisms that exist today

(Documenting existing mechanisms; the choice is for planning.)

1. **Per-command repeated boilerplate** — the dominant pattern. Every tce command carries a near-identical "Project context" preamble (`research_codebase.md:10-16`, `create_plan.md:10-16`, `implement_plan.md:10-16`, `work.md:10-20`, `quickfix.md:10-20`, `commit.md:9-19`, `code_review.md:10-21`, `discuss.md:17-23`, `design_explore.md:10-17`) and several repeat a "Workflow Context" table. Drift control is by convention/review, plus the explicit lock-step rule for composites.
2. **Rule-governed duplication with a named sync rule** — `CLAUDE.md` already maintains two such rules (composite lock-step; init-nudge wording synced across `check-init.sh`, `plugin.json` `userConfig` description, `plugins/tce/README.md`). A copy-guidelines block repeated per plugin would fit this established pattern.
3. **Runtime reads of project config markdown** — commands read `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` / `tickets.md` / `design-system.md` at runtime (every tce command's preamble; `plugins/tce/README.md:147-160` documents the mechanism). These files are *per-project data*; plugin-owned guidance does not currently live there. tmt's only cross-plugin read is also a project-config file (`tmt/create.md:305-309` reading `.claude/tce/tickets.md`).
4. **Plugin-internal file reads via `${CLAUDE_PLUGIN_ROOT}`** — today used only for *executing scripts* (`ticket.sh`, `next-ticket.sh`, `open_tickets.sh`) and *copying templates* (`tce/init.md:190-191,227`, `tmt/init.md:77`); no command currently instructs reading a plugin-internal **markdown** file at runtime. The variable is documented as substituted inline per plugin (`plugins/tce/README.md:161-162`) and explicitly never crosses plugins (`CLAUDE.md` "Core design rule"; verified: no cross-plugin `${CLAUDE_PLUGIN_ROOT}` reference exists).
5. **No shared instruction file exists** — full inventories confirm: tce = 10 commands, 6 agents, hooks.json, 3 scripts, 3 templates, README, plugin.json; tmt = 3 commands, hooks.json, 5 scripts, 1 template, README, plugin.json. Neither has `skills/` or any conventions/`lib.md` file; neither `plugin.json` declares custom paths.

Constraint to respect (from `CLAUDE.md`): plugins coordinate **only through project config files**, never by referencing each other's internals — so a single guidelines file shared *between* tce and tmt via `${CLAUDE_PLUGIN_ROOT}` is not possible within current rules; per-plugin placement (one block per plugin, or repeated per command) is what current mechanisms support.

### 5. AskUserQuestion tool constraints and rendering behavior

Two sources, with different authority:

**(a) The tool's own description in Claude Code's interactive client** (first-hand; observed in-session 2026-06-12, Claude Code with AskUserQuestion available):
- 1–4 questions per call; **2–4 options per question**.
- `header`: "Very short label displayed as a chip/tag (**max 12 chars**)".
- **Automatic "Other"**: "Users will always be able to select 'Other' to provide custom text input. … There should be no 'Other' option, that will be provided automatically."
- **"(Recommended)" convention is in the tool description itself**: "If you recommend a specific option, make that the first option in the list and add '(Recommended)' at the end of the label" — i.e. the pattern the ticket wants to keep is the tool's own documented guidance, not just a dogfood habit.
- `multiSelect: true` supported ("Use when choices are not mutually exclusive"; phrase the question accordingly).
- **Option previews**: per-option `preview` rendered as markdown in a monospace box (for mockups/code/diagram comparisons); "previews are **only supported for single-select questions (not multiSelect)**"; not for simple preference questions.
- Labels "concise (1–5 words)"; descriptions explain "what this option means or what will happen if chosen" (trade-offs/implications). No hard length limit documented for question text, labels, or descriptions beyond the 12-char header.

**(b) Official Agent SDK documentation** (web research; links in External Sources):
- Confirms 1–4 questions, 2–4 options, 12-char header, multiSelect.
- Question text, labels, descriptions are shown as **plain text in examples; no markdown rendering is documented**. Descriptions display alongside labels (always visible, not hover/focus).
- No documented truncation/length limits beyond the header.
- **Subagent limitation (documented)**: "AskUserQuestion is not currently available in subagents spawned via the Agent tool" — relevant because tce's research agents therefore cannot ask; only main-context commands can.
- The SDK docs do **not** mention the automatic "Other", the "(Recommended)" guidance, or the multiSelect-preview restriction — those come from the interactive client's tool description (source a). The SDK's `previewFormat` is a TypeScript SDK option; the interactive client renders previews as markdown.
- Intro text: there is no intro/message field on the tool; text printed by Claude before the invocation appears in the conversation above the dialog. This matches the ticket's Notes ("text printed before the AskUserQuestion invocation renders above the dialog") from the dogfood run.

**Practical implications for prescribing copy** (facts, not recommendations): question text should carry the question only, with context in the intro message and per-option reasoning in descriptions; option labels have an effective budget of 1–5 words plus the optional " (Recommended)" suffix; headers must fit 12 characters; an "Other"/"custom" option must never be authored; markdown in descriptions cannot be relied on.

## Code References

- `plugins/tce/commands/init.md:126-139` — ticket-system AskUserQuestion (only "(Recommended)" + "Other" mentions in repo)
- `plugins/tce/commands/init.md:141-151` — status-transitions + ticket-creation policy questions (abstract; only same-call batching mention)
- `plugins/tce/commands/init.md:153-155` — dynamic ambiguity fallback ("small set of concrete options" criterion)
- `plugins/tmt/commands/init.md:53-68` — prefix proposal block (plain text) + AskUserQuestion ambiguity fallback
- `plugins/tce/commands/work.md:107-131` — open-questions checkpoint: `AskUserQuestion` + prescribed intro-block template
- `plugins/tce/commands/create_plan.md:99-147, 233-258` — open-questions handling (plain text, example interaction)
- `plugins/tce/commands/create_plan.md:260-288` / `implement_plan.md:160-181` / `work.md:94-105,126-129` — the three design-exploration question variants
- `plugins/tce/commands/research_codebase.md:75-92` — sufficiency check ("one batched round"); mirrored `work.md:54`
- `plugins/tce/commands/quickfix.md:59-67, 182-187` — clarity questions + autonomy overrides
- `plugins/tmt/commands/create.md:202-212` — complexity estimate (natural fixed four-option choice in plain text)
- `plugins/tce/scripts/check-init.sh:58-73` — SessionStart offer wording (three-way sync rule)
- `CLAUDE.md` ("Composite commands must track the single-step commands") — the lock-step rule governing mirrored copy

## Architecture Documentation

- **Current de-facto copy pattern**: verbatim fenced "respond with" blocks and blockquote questions, authored independently per command (`research_codebase.md:96-100`, `create_plan.md:159-173`, `code_review.md:95-105`, `discuss.md:37-45`, `design_explore.md:45-53`, `tmt/create.md:36-44`, init proposal blocks). AskUserQuestion sites, by contrast, are mostly abstract instructions.
- **Sharing mechanisms in use**: per-command repetition (Project-context preamble), named sync rules in `CLAUDE.md` (composites; init-nudge wording), runtime reads of project config (`${CLAUDE_PROJECT_DIR}/.claude/tce/*.md`), `${CLAUDE_PLUGIN_ROOT}` for scripts/templates only. No runtime reads of plugin-internal markdown; no cross-plugin plugin-root references (rule + verified).
- **Repo editing convention** (`CLAUDE.md`): surgical edits preserving each command's structure and altitude — relevant because copy will be inserted into long existing prompts.

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0001-askuserquestion-copy.md` — the ticket; its Notes (2026-06-12) confirm two facts used above: the "(Recommended)"-first pattern was helpful in the dogfood run, and intro text above dialogs works (prescribed copy is intended as intro + question pairs).
- A prior research document for TP-0001 (same filename) was staged and then deleted from the working tree before this session — this document replaces it with a fresh run. All other `thoughts/shared/` directories (research, plans, discussions, mockups, reviews) are empty apart from `.gitkeep` files.

## Related Research

None — this is the first (retained) research document in this repository.

## External Sources

- https://code.claude.com/docs/en/agent-sdk/user-input.md — AskUserQuestion reference (question format, limits, previews, subagent limitation): question-format, option-previews-typescript, limitations, complete-example sections
- https://code.claude.com/docs/en/tools.md — Claude Code built-in tools list (includes AskUserQuestion)
- The AskUserQuestion tool description in Claude Code's interactive client (observed in-session, 2026-06-12) — source for: automatic "Other", "(Recommended)"-first guidance, 1–5-word label guidance, previews-not-with-multiSelect, markdown preview rendering. Note: these are absent from the SDK docs above; the in-client tool description is the authoritative source for interactive-session behavior.

## Open Questions

(For the planning phase; documented, not answered, here.)

1. **Scope of "predictable" for tmt's prefix dialog**: the ticket lists "/tmt:init prefix question" as predictable, but the current primary flow is a plain-text proposal (`tmt/init.md:53-65`) with AskUserQuestion only as the ambiguity fallback (`:67-68`). Planning must decide whether prescribed copy targets the proposal block, the fallback dialog, or both — or restructures the primary flow into a dialog (the ticket's Out of Scope forbids redesigning *which* questions are asked, not necessarily their medium).
2. **Which implicit sites count as "all other AskUserQuestion sites"** (acceptance criterion 3): many ask-sites never name the tool (design_explore menus, code_review menus, tmt create phases). Planning must draw the boundary between "AskUserQuestion sites that get the guidelines reference" and plain-text conversational prompts that stay as they are.
3. **Guidelines placement trade-off**: one block per plugin (where? commands share no file today) vs repeated per command (matches existing repetition pattern + lock-step-style sync rule). Both are possible within current mechanisms; a cross-plugin shared file is not (per `CLAUDE.md`'s coordination rule).
4. **The design-exploration question exists in three variants** plus a quickfix escalation — if its copy is prescribed, all variants must change in the same commit (lock-step rule).
5. **Markdown in descriptions is not documented as supported** — verbatim copy should presumably be authored as plain text, but if any prescribed description wants emphasis/code formatting, that needs an empirical check first.
