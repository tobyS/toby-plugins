---
date: 2026-07-05T09:48:27Z
git_commit: d8cac107b95716260249d1e42ee6f3961a6760d7
branch: main
repository: toby-plugins
topic: "TP-0018: Permit root-cause analysis in research for defect tickets"
tags: [research, codebase, tce, research-command, agents, documentarian-rules, quickfix, work]
status: complete
last_updated: 2026-07-05
---

# Research: TP-0018 — Permit root-cause analysis in research for defect tickets

**Date**: 2026-07-05T09:48:27Z
**Git Commit**: d8cac107b95716260249d1e42ee6f3961a6760d7
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0018 asks for a bounded exception to `/tce:research`'s documentarian rules:
when the ticket describes a defect, tracing and documenting the **mechanism of
the faulty behavior** (where actual behavior diverges from intended behavior,
with file:line evidence) is in scope as documentation — while fix proposals,
code-quality critique, and refactoring suggestions stay out of scope. The
ticket's Questions for Research/Planning:

1. Where exactly the exception lands in `research.md` (the CRITICAL block, the
   sufficiency check, or both) and how the composites mirror it.
2. How research classifies a ticket as a defect — keep it simple and stated.
3. Whether the research document template needs a dedicated section (e.g.
   "Defect Mechanism") or the existing Detailed Findings structure carries it.
4. (Acceptance criterion 3) Whether the agents' documentarian blocks need the
   same carve-out, applied consistently.

## Summary

- The canonical rule text lives in exactly **four files**: the CRITICAL block in
  `plugins/tce/commands/research.md:59-74` and the three codebase agents
  (`codebase-analyzer.md`, `codebase-locator.md`, `codebase-pattern-finder.md`),
  each with a DO-NOT block, a "What NOT to Do" list, and a "REMEMBER:
  documentarian, not a critic" closer. The three other agents (`thoughts-locator`,
  `thoughts-analyzer`, `web-search-researcher`) carry **no** documentarian rules.
- The composites (`work.md`, `quickfix.md`) contain **no documentarian text of
  their own** — they inherit the rules by deference ("Execute the full research
  workflow as defined in `/tce:research`"). Only the TP-0004 config-drift
  exception's *operational anchors* (detection bullet + surfacing line) are
  mirrored into them, at five sites.
- There is strong precedent for exactly this kind of change: TP-0004 appended
  the "**One sanctioned exception:**" paragraph to the CRITICAL block. Its
  exclusivity wording ("One sanctioned exception", "This is the only
  recommendation allowed", `research.md:70-74`) would need rewording — not just
  appending — if a second exception joins it. TP-0016 (Done) consolidated the
  documentarian identity to a single statement and set an acceptance criterion
  that no instruction is stated more than once without a documented, justified
  reason — so the new exception should live **once, in the CRITICAL block**.
- On the agents (acceptance criterion 3): **`codebase-analyzer` is the one agent
  whose own rules would block a defect-tracing request.** Its CRITICAL block
  bans are conditional ("unless the user explicitly asks", `:39-41`), but its
  Step-3 bullets (`:90-91`) and "What NOT to Do" list (`:149`, `:153`) restate
  the bans **unconditionally** ("Don't identify bugs, issues, or potential
  problems", "Don't perform root cause analysis of any issues") with no
  precedence rule between the two forms. `codebase-locator`'s ban is moot (it
  is forbidden from reading file contents at all), and
  `codebase-pattern-finder`'s root-cause ban is scoped to pattern provenance,
  not defects. Additionally, `research.md:68` instructs the orchestrator to
  remind every sub-agent to describe "without evaluating or improving" —
  wording that pushes against a defect-tracing prompt.
- Defect classification has **no machine signal available**: the tmt envelope
  has only Status/Complexity metadata and `tickets.md`'s "What tce needs from a
  ticket" imposes no type field. Classification can only come from the ticket's
  content. TP-0018 itself pre-decides the key ("keyed on the ticket describing
  a defect, not on research mood").
- For the template question, both options are viable with existing mechanisms:
  the template already has two conditional-section styles (heading qualifier
  "(only if found)" with a bracketed include/omit instruction, and a separate
  appended template block like Impact Analysis). A new conditional section
  would also require touching the composites' write-step lines (`work.md:89`,
  `quickfix.md:144`), which restate include-conditions at the point of use.

## Detailed Findings

### 1. The documentarian rule sites in `research.md`

The CRITICAL block (`plugins/tce/commands/research.md:59-74`):

- `research.md:59` — heading "CRITICAL: YOUR ONLY JOB IS TO DOCUMENT AND
  EXPLAIN THE CODEBASE AS IT EXISTS TODAY"
- `research.md:61-65` — five DO-NOT bullets; `research.md:62` is the line
  TP-0018 quotes: "DO NOT perform root cause analysis unless the user
  explicitly asks for them". Note that `:61-63` are all *conditional*
  ("unless the user explicitly asks"), while `:64-65` (critique, refactoring)
  are unconditional.
- `research.md:66-67` — the positive mandate ("ONLY describe what exists…",
  "technical map/documentation").
- `research.md:68` — "Your sub-agents are documentarians too — remind them in
  your prompts that they describe what exists, without evaluating or improving
  it". This is the propagation line: the orchestrator reinforces the
  documentarian stance in every sub-agent prompt.
- `research.md:70-74` — the TP-0004 carve-out paragraph: "**One sanctioned
  exception:** … a single, non-blocking advisory to run `/tce:refresh` …
  This is the only recommendation allowed — and it concerns tce's own config,
  not the project's code."

The **ticket sufficiency check** (`research.md:102-121`) is deliberately
scope-focused (scope determinable, outcome observable, an anchor) and contains
no documentarian language; nothing there distinguishes defect from feature
tickets today.

### 2. The agents' documentarian blocks

**`plugins/tce/agents/codebase-analyzer.md`** — heaviest concentration, and the
one internal inconsistency:

- `codebase-analyzer.md:37-45` — CRITICAL block. The root-cause and
  improvement bans are **conditional**: "DO NOT suggest improvements or changes
  unless the user explicitly asks for them" (`:39`), "DO NOT perform root cause
  analysis unless the user explicitly asks for them" (`:40`).
- `codebase-analyzer.md:90-91` — inside "Step 3: Document Key Logic",
  **unconditional**: "DO NOT evaluate if the logic is correct or optimal",
  "DO NOT identify potential bugs or issues".
- `codebase-analyzer.md:147-155` — "What NOT to Do" list, **unconditional**:
  "Don't identify bugs, issues, or potential problems" (`:149`), "Don't perform
  root cause analysis of any issues" (`:153`).
- `codebase-analyzer.md:157-161` — REMEMBER closer ("documentarian, not a
  critic or consultant … without any judgment or suggestions for change").

The tension: the agent's core mandate is precisely behavioral mechanics —
"trace data flow, and explain technical workings with precise file:line
references" (`:8`), "Trace Data Flow … Identify where and how state changes"
(`:56-61`), "Describe validations, transformations, error handling" (`:87`).
Neutrally documenting *what the code does at file:line* — including the exact
spot where a behavior arises — is inside the mandate. What `:91`, `:149`, and
`:153` forbid in their own wording is *labeling* findings as bugs/problems and
"root cause analysis" as such. The CRITICAL block's "unless the user explicitly
asks" escape (the caller's Task prompt is that user turn) is **not repeated**
in the Step-3 and What-NOT-to-Do restatements, and the file has no precedence
rule between the conditional and unconditional forms. A caller explicitly
asking the analyzer to trace a defect mechanism can therefore be refused on the
strength of `:91`/`:149`/`:153` — exactly the risk acceptance criterion 3
names.

**`plugins/tce/agents/codebase-locator.md`**:

- `codebase-locator.md:31-38` — CRITICAL block with the same conditional
  root-cause ban (`:34`).
- Largely moot for TP-0018: the agent must not read file contents at all —
  "**Don't read file contents** - Just report locations" (`:123`), "Don't
  analyze what the code does" / "Don't read files to understand implementation"
  (`:133-134`). It can *locate* files relevant to a defect but cannot trace a
  mechanism by design. (Runs on `model: haiku`, `:5`.)

**`plugins/tce/agents/codebase-pattern-finder.md`**:

- `codebase-pattern-finder.md:36-44` — CRITICAL block; its root-cause ban is
  differently scoped: "DO NOT perform root cause analysis **on why patterns
  exist**" (`:40`) — pattern provenance, not defects. The other bans target
  evaluation (good/bad/anti-pattern, `:41-43`, `:171-177`). Nothing forbids
  showing exact code with file:line — that is its output format (`:96-135`).
- One adjacent line: "Don't show broken or deprecated patterns (unless
  explicitly marked as such in code)" (`:167`).

**No documentarian rules at all** in `thoughts-locator.md` (only "Don't make
judgments about document quality", `:117`), `thoughts-analyzer.md` (its mandate
is even evaluative: "Find actionable recommendations", `:14`), and
`web-search-researcher.md` (explicitly researches error messages and fixes,
`:89-95`). No agent file mentions "defect" or "diverge" anywhere; the only
defect-adjacent language across `plugins/tce/agents/` is the prohibitions
listed above.

### 3. How the composites inherit the rules — and what they actually mirror

Neither `work.md` nor `quickfix.md` contains the words "documentarian" or
"critique", nor any restatement of the CRITICAL DO-NOT list. They inherit it by
deference:

- `work.md:24` — lock-step header; `work.md:67` "Execute the full research
  workflow as defined in `/tce:research`"; `work.md:81` "Follow all research
  steps from `/tce:research`"; `work.md:91` "Follow ALL quality guidelines from
  `/tce:research`".
- `quickfix.md:23` — lock-step header; `quickfix.md:131` "Follow the
  `/tce:research` process autonomously".

What the composites DO restate from research.md: the agent list
(`work.md:84`, `quickfix.md:136-140`), the sufficiency check (`work.md:76`),
the template-read instruction including the conditional Impact Analysis
condition (`work.md:89`, `quickfix.md:144`), metadata/commit mechanics — and
the TP-0004 drift exception's **operational anchors** at five sites:

- Detection: `work.md:87`, `quickfix.md:141` (the drift-check bullet,
  "read-only, **never edit the config**").
- Surfacing: `work.md:146-149` (intro with questions), `work.md:179-181`
  (status line without questions), `quickfix.md:231-233` (final summary).

So the composite mirroring pattern established by TP-0004 is: **the exception
paragraph itself is not copied into the composites; only its operational
anchors are** — the composites restate what research.md's numbered steps
restate. A change confined to the CRITICAL block has no verbatim composite copy
to update today; a change that adds detection/surfacing mechanics or a new
conditional template section does (at the sites above and at the write-step
lines `work.md:89` / `quickfix.md:144`).

### 4. The established bounded-exception pattern (TP-0004 precedent, TP-0016 discipline)

The TP-0004 plan (`thoughts/shared/plans/2026-06-14-TP-0004-profile-drift-refresh.md`,
Phase 2) added the config-drift exception as an amendment "attached directly to
the CRITICAL documentarian block itself", framed as "the single sanctioned
recommendation, coexisting with the 'only describe what exists' rule".
Verification was a manual coherence read ("The documentarian block still reads
coherently with the carve-out") plus `claude plugin validate ./plugins/tce`,
with composite mirrors updated in the same commit.

The resulting wording pattern (`research.md:70-74` and echoed at
`plugins/tmt/commands/init.md:189-190`): a bold lead-in label, a self-limiting
closer ("This is the only recommendation allowed"), a scoping justification
("concerns tce's own config, not the project's code"), cross-references to the
numbered steps carrying the mechanics, and an inner prohibition preserving the
parent rule's core ("read-only — **never edit the config**"). Alternative
shapes in use elsewhere: "(Exceptions below.)" pointer + "**Only … if:**"
bullet list (`plan.md:93-103`); "When you MAY …" subsections + "the exception,
not the starting point" (`implement.md:75-89`); inline "Exception: …" sentence
on a step (`init.md:370-372`).

Constraint from the current wording: `research.md:70` says "**One** sanctioned
exception" and `:73-74` says "This is the **only** recommendation allowed". A
second exception cannot simply be appended — the exclusivity phrasing must be
reworked so the two exceptions coexist coherently. (Note their natures differ:
the TP-0004 exception permits a *recommendation*; the TP-0018 exception permits
a *kind of documentation* — arguably not a recommendation at all, which is the
review's own framing: "tracing the mechanism of the faulty behavior is
documentation, not critique".)

TP-0016 (`thoughts/shared/tickets/TP-0016-shrink-command-prompts-reference-files.md`,
Status: Done) consolidated the documentarian identity from ~11 occurrences to
the single CRITICAL section and set the acceptance criterion that "no
instruction is stated more than once unless a documented, observed failure
justifies the repetition". The documentarian identity is not in the plan's
justified-repetitions table, so it has exactly one sanctioned home. A new
exception should therefore be stated **once in the CRITICAL block**, with any
step-level text limited to mechanics.

### 5. The review finding and its neighboring constraints

`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`,
Section 2 item 6 (lines 183-190): the rule is right for features but "for a bug
ticket (and every `/tce:quickfix`), locating the cause *is* the research
deliverable"; currently the model "must either violate the rule or produce
research that describes everything around the bug without saying where it is".
Suggested reframe: "for defect tickets, tracing the mechanism of the faulty
behavior is documentation, not critique". The review treats quickfix as
definitionally defect-shaped (the collision applies to every quickfix run).

Neighboring findings a fix should not collide with:

- Section 2 item 2 (intra-file repetition): state the exception once.
- Section 2 item 1 (command length / compaction): `research.md` is a
  restructure target (TP-0016 delivered part of that); additions should be
  compact, and the CRITICAL block sits early in the file — the part of an
  invoked command that survives auto-compaction.
- Section 2 item 5 (agent output budget) proposes touching each agent's Output
  Format section — if TP-0018 also edits agent files, the edits are in
  different sections and don't conflict, but both may land in the same files.
- Section 3 item 2 rejects the lineage's "hide the ticket's proposed solution
  from researchers" trick — a TP-0018 fix should not reintroduce
  solution-hiding logic.

### 6. Defect classification — available signals

There is no machine-readable ticket-type field anywhere in the system:

- The tmt envelope (`.claude/tce/tickets.md` "Ticket title & body layout") has
  only `**Status:**` / `**Estimated Complexity:**` / `**Created:**` /
  `**Updated:**` meta lines; the body structure is owned by `/tce:ticket`.
- `tickets.md`'s "What tce needs from a ticket" requires only scope, outcome,
  and an anchor — no type. Tickets from other systems may be free-form text.

Classification therefore has to be a stated judgment from ticket content.
TP-0018 itself fixes the key: "the exception is keyed on the ticket describing
a defect, not on research mood" — i.e. the ticket describes existing behavior
that diverges from intended behavior (bug report, regression, error message),
as opposed to requesting new/changed behavior. The sufficiency check
(`research.md:102-121`) is the natural place a reader might expect a
classification step, but it is scope-focused by design and adding a
defect/feature triage there would duplicate the exception's key — the
review's "state once" guidance and TP-0016's acceptance criterion both weigh
against a second statement site.

### 7. Template mechanisms available for a "Defect Mechanism" section

`plugins/tce/references/research-document-template.md` (a runtime reference,
part of the command contract — the CLAUDE.md composite-tracking rule applies to
edits) offers two existing conditional-section styles:

- In-template heading qualifier + bracketed include/omit instruction — mild
  form "## UI Patterns Available (if applicable)" (`:70-72`); strong form
  "## tce Config Drift (only if found)" with "[Include this section ONLY if …
  Omit the section entirely when …]" (`:96-102`).
- Separate template block appended after the main template with an
  include-condition sentence — "# Impact Analysis section template" (`:105-131`).

Both consuming composites restate include-conditions at their write steps:
`work.md:89` "(including the conditional Impact Analysis section when the
ticket reuses/extends shared code)" and `quickfix.md:144` "Include the
**Impact Analysis** section (templated in the same file) if the fix
reuses/extends shared code." A new conditional section would need the same
treatment. The template also encodes the descriptive stance in placeholders
("Current implementation details (without evaluation)" `:55`, "(Document
available options without making recommendations)" `:80`) — a Defect Mechanism
section, if added, would sit alongside these without contradicting them as long
as it documents divergence rather than proposing fixes.

Alternatively, the existing "## Detailed Findings" structure (`:49-59`,
free-form "### [Component/Area]" subsections) can carry the mechanism trace
without any template change — at the cost of planning having no predictable
anchor to look for.

## Code References

- `plugins/tce/commands/research.md:59-74` — the CRITICAL documentarian block + TP-0004 exception paragraph (the primary edit site)
- `plugins/tce/commands/research.md:62` — the root-cause ban TP-0018 quotes
- `plugins/tce/commands/research.md:68` — "sub-agents are documentarians too" propagation line
- `plugins/tce/commands/research.md:102-121` — ticket sufficiency check (scope-focused, no defect/feature distinction)
- `plugins/tce/agents/codebase-analyzer.md:39-41` — conditional bans ("unless the user explicitly asks")
- `plugins/tce/agents/codebase-analyzer.md:90-91` — unconditional Step-3 bans
- `plugins/tce/agents/codebase-analyzer.md:149,153` — unconditional "What NOT to Do" bans (bugs / root cause)
- `plugins/tce/agents/codebase-locator.md:34,123,133-134` — conditional RCA ban; no-content-reading rules that make it moot
- `plugins/tce/agents/codebase-pattern-finder.md:40,167` — provenance-scoped RCA ban; broken-patterns line
- `plugins/tce/commands/work.md:67,81,91` — deference lines inheriting research.md's rules
- `plugins/tce/commands/work.md:84,87,89,146-149,179-181` — restated operational anchors (agent list, drift detection/surfacing, template write step)
- `plugins/tce/commands/quickfix.md:131,136-141,144,231-233` — quickfix's equivalents
- `plugins/tce/references/research-document-template.md:49-59,70-72,96-102,105-131` — Detailed Findings structure and the two conditional-section mechanisms

## Architecture Documentation

- **Single-statement discipline**: since TP-0016, each rule in the command
  prompts has one sanctioned home; repetitions require documented
  justification. The documentarian identity's home is the CRITICAL block.
- **Bounded-exception pattern** (TP-0004): bold-labelled paragraph directly
  under the strict block; names the single permitted act, qualifies it,
  cross-references the operational steps, and carries an inner prohibition
  preserving the parent rule.
- **Composite lock-step**: composites defer to `/tce:research` for rules and
  restate only operational anchors; CLAUDE.md's composite-tracking rule
  requires checking `work.md`/`quickfix.md` in the same commit for any change
  they mirror. Reference-file edits count as command edits.
- **Agent prompting contract**: callers send what-to-find prompts
  (`research.md:210-211` "Each agent knows its job"); the agents' own files
  govern conduct. The only unlock mechanism in the agent files is the
  "unless the user explicitly asks" wording, where the caller's Task prompt is
  the user turn — and `research.md:68` currently instructs callers to push
  agents toward the documentarian stance, not away from it.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 2, finding 6: the origin of TP-0018 (framing: "documentation, not critique"); finding 6 is not in the review's priority list.
- `thoughts/shared/plans/2026-06-14-TP-0004-profile-drift-refresh.md` — precedent for adding a bounded exception to the same block, incl. verification approach.
- `thoughts/shared/plans/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md` — the 11→1 documentarian consolidation; justified-repetitions table.
- `thoughts/shared/tickets/TP-0016-shrink-command-prompts-reference-files.md` — Status: Done — the consolidation is already in effect; no pending restructure from TP-0016.
- `thoughts/shared/tickets/TP-0015-fix-review-prompt-defects.md` — sibling ticket; explicitly scopes documentarian-rule changes out, deferring to TP-0018.
- `thoughts/shared/tickets/TP-0020-plan-compliance-gate.md` — cites `codebase-analyzer.md`'s documentarian block as style precedent (a fix here becomes precedent there).
- `thoughts/shared/tickets/TP-0017-adopt-frontmatter-machinery.md` — most recent edits to the agent files (frontmatter, haiku locators).

## Related Research

- `thoughts/shared/research/2026-07-03-TP-0016-shrink-command-prompts-reference-files.md` — pre-TP-0016 inventory of documentarian-rule occurrences in research.md (historical line numbers).
- `thoughts/shared/research/2026-06-14-TP-0004-profile-drift-refresh.md` — documents the pre-carve-out documentarian block and the drift-exception reasoning.
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md` — current state of the agent files' frontmatter/models.

## Open Questions

1. **Research document template: dedicated section or not?** Two viable
   options with existing mechanisms (finding 7): (a) add a conditional
   "## Defect Mechanism (only for defect tickets)" section (strong-form
   include/omit instruction, mirrored into `work.md:89` / `quickfix.md:144`),
   giving planning a predictable anchor; or (b) no template change — the
   free-form Detailed Findings subsections carry the trace, keeping the
   template and composites untouched. Requires a judgment call on
   predictability vs surface area.
2. **Agent-side scope (acceptance criterion 3).** Research determined
   `codebase-analyzer` is the one agent whose own unconditional restatements
   (`:90-91`, `:149`, `:153`) can refuse a defect-tracing request, while its
   CRITICAL block already carries the "unless the user explicitly asks"
   escape. Two consistent resolutions exist: (a) minimally align the
   unconditional restatements with the conditional form (smallest diff,
   preserves TP-0016's shape); or (b) add an explicit defect-mechanism
   carve-out paragraph to the analyzer's CRITICAL block mirroring
   research.md's new exception (more explicit, more text, and TP-0020 cites
   this block as style precedent). `codebase-locator` and
   `codebase-pattern-finder` need no change on the evidence (moot /
   differently-scoped bans). In either case `research.md:68` (the
   "remind them … without evaluating or improving it" propagation line) needs
   a matching touch so the orchestrator's defect-tracing prompts don't
   contradict the reminder it must send.
