---
date: 2026-07-03T15:33:26Z
git_commit: 9f11dc9772f47509036c7dac7e65a6018ba65488
branch: main
repository: toby-plugins
topic: "TP-0016: Shrink command prompts — reference files for templates, deduplicated instructions"
tags: [research, codebase, tce, commands, plan, research-command, skills, compaction, plugin-root, templates]
status: complete
last_updated: 2026-07-03
---

# Research: TP-0016 — Shrink command prompts (reference files for templates, deduplicated instructions)

**Date**: 2026-07-03T15:33:26Z
**Git Commit**: 9f11dc9772f47509036c7dac7e65a6018ba65488
**Branch**: main
**Repository**: toby-plugins

## Research Question

From the ticket's "Questions for Research/Planning":

1. What is the sanctioned mechanism for plugin commands to load supporting files at runtime (plain `Read` of `${CLAUDE_PLUGIN_ROOT}/...`, skill directory conventions, or converting commands to skill-with-references layout)? Does `${CLAUDE_PLUGIN_ROOT}` substitution apply where needed?
2. What are the current, documented compaction limits for invoked skills/commands?
3. Which repeated instruction blocks are load-bearing (added in response to real failures) versus pure lineage inheritance?
4. Which sections of `plan.md`/`research.md` are per-invocation behavior (stay in the body) versus stable reference (move out)?
5. How does this interact with the repo convention "small surgical edits are safer than rewrites"?

## Summary

- **Compaction claim: confirmed verbatim by official docs.** After auto-compaction, Claude Code re-attaches each invoked skill's most recent invocation truncated to its **first 5,000 tokens**, within a **combined 25,000-token budget** filled most-recent-first (older skills can drop entirely). Invoked skill text otherwise stays in context all session and is never re-read from the file. Source: the "Skill content lifecycle" section of the skills docs. The review's figures were exact, not approximate.
- **Mechanism: commands are now officially skills.** The docs state "Custom commands have been merged into skills" — a plugin's `commands/*.md` are "skills as flat Markdown files", and `skills/` (directory + `SKILL.md` + supporting files) is the recommended layout for new plugins. The sanctioned supporting-file mechanism is exactly what the ticket hypothesizes: reference files next to the skill, read on demand with normal file tools ("no context penalty for large files … until actually read"). `${CLAUDE_PLUGIN_ROOT}` is documented to substitute "anywhere it appears in skill content" — that this covers flat `commands/*.md` is a one-step inference from commands-being-skills (never written verbatim; low risk). Migrating `commands/foo.md` → `skills/foo/SKILL.md` preserves the `/tce:foo` invocation name.
- **The official length guidance is under 500 lines**, with reference files one level deep from the skill body; `plan.md` is at 769 lines (43% of it fixed template/reference blocks), `research.md` at 475 (27% fixed blocks). Extracting just the identified stable blocks brings both under the ticket's ~400–450 target arithmetically.
- **Repetition archaeology: only two repeated blocks are deliberate.** The TP-0013 chain-order re-read clauses (commit `062edd9`) and the nine-copy AskUserQuestion block (TP-0001, commit `31e7760`) were added in response to identified failures and are protected by CLAUDE.md rules. Every other repeated instruction tested ("read FULLY / WITHOUT limit/offset", "wait for ALL sub-agents/sub-tasks", "DO NOT re-read source files it already covers", "No Open Questions in Final Plan", "The research document IS your codebase context") pickaxes back to the initial template import `fb68d34` — pure lineage. Caveat: the source-file no-re-read rule, though lineage in origin, is now load-bearing *by policy* — CLAUDE.md's TP-0013 rule explicitly says it must not be weakened.
- **There are currently zero runtime reads of plugin-internal markdown** anywhere in either plugin — `${CLAUDE_PLUGIN_ROOT}` is used only for script execution, template `cp` in the inits, and `plugin.json` version reads. Sibling ticket TP-0022 even records the (now outdated relative to current docs) assertion that "commands can't read plugin-internal markdown at runtime". TP-0016 would introduce this pattern for the first time.
- **The sync surface is well mapped and tight**: work.md names plan.md's internal step titles/numbers verbatim (`work.md:189`), both composites restate the research agent roster, drift taxonomy, and template/filename conventions, implement.md depends on the research frontmatter fields, and four CLAUDE.md rules bind any restructure. Sibling TP-0023 plans to rewrite the status-file mechanics (defined solely in implement.md) — an ordering consideration if TP-0016 were to touch that format.

## Detailed Findings

### 1. Runtime file-loading mechanism (docs, mid-2026)

Officially documented:

- **Commands/skills unification**: "Custom commands have been merged into skills. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way." Plugin file-locations table: "Commands | `commands/` | Skills as flat Markdown files. Use `skills/` for new plugins." Plugin skill naming keeps the `/plugin:name` shape (`my-plugin/skills/review/SKILL.md` → `/my-plugin:review`), so a `commands/plan.md` → `skills/plan/SKILL.md` migration preserves `/tce:plan`.
- **Supporting files**: "Skills can include multiple files in their directory. This keeps SKILL.md focused on the essentials while letting Claude access detailed reference material only when needed." Loading is just the model Reading the file when the body points at it: "Files read on-demand … No context penalty for large files … don't consume context tokens until actually read." Best practices: keep references **one level deep** from SKILL.md; files >100 lines get a table of contents.
- **Length guidance**: "Keep SKILL.md under 500 lines. Move detailed reference material to separate files." (stated in both the skills docs and the authoring best-practices checklist).
- **`${CLAUDE_PLUGIN_ROOT}` substitution scope**: substituted inline "anywhere they appear in skill content, agent content, hook commands, monitor commands, and MCP or LSP server configs". Path-traversal constraint: installed plugins cannot reference files outside the plugin root (fine — templates live inside).
- **Frontmatter** (applies to command files too — "Files in `.claude/commands/` still work and support the same frontmatter"): `allowed-tools` (grants without prompting; does not restrict), `disable-model-invocation`, `context: fork` + `agent`, and `` !`command` `` dynamic injection (explicitly available to plugin sources via the `disableSkillShellExecution` opt-out). These are TP-0017's scope, not TP-0016's.

Documented-vs-assumption ledger (record for planning):

- Assumption (low risk): the literal claim "`${CLAUDE_PLUGIN_ROOT}` expands in `commands/*.md`" — follows from commands-are-skills; never written verbatim; no counter-statement found.
- Not documented: `${CLAUDE_PLUGIN_ROOT}` inside `allowed-tools` values or inside `` !`cmd` `` injections (docs use `${CLAUDE_SKILL_DIR}`/`${CLAUDE_PROJECT_DIR}` in those positions); `${CLAUDE_SKILL_DIR}`'s value for a *flat* command file; `@file` inclusion in skill/command bodies (absent from current docs — only CLAUDE.md imports support `@path`).
- `${CLAUDE_SKILL_DIR}` exists for directory-layout skills ("the skill's subdirectory within the plugin, not the plugin root") — relevant only if commands convert to `skills/<name>/SKILL.md` layout.

### 2. Compaction behavior for invoked skills (docs)

From the skills docs, "Skill content lifecycle" (https://code.claude.com/docs/en/skills#skill-content-lifecycle):

- "When you or Claude invoke a skill, the rendered SKILL.md content enters the conversation as a single message and stays there for the rest of the session. Claude Code does not re-read the skill file on later turns."
- "Auto-compaction carries invoked skills forward within a token budget. … Claude Code re-attaches the most recent invocation of each skill after the summary, keeping the **first 5,000 tokens** of each. Re-attached skills share a **combined budget of 25,000 tokens**. Claude Code fills this budget starting from the most recently invoked skill, so older skills can be dropped entirely."
- "If the skill is large or you invoked several others after it, re-invoke it after compaction to restore the full content."

Consequences documented elsewhere (how-claude-code-works, "When context fills up"): compaction clears **older tool outputs first** — so file contents obtained via Read (tickets, research docs, templates) are *not* auto-restored either; the durable pattern is that the model re-reads them from disk at use time, which is exactly what tce's TP-0013 rule instructs for workflow documents and what reference files would get for the templates. This "re-read from disk" doctrine is an inference from the docs, not an explicit guarantee — the docs only say tool outputs are cleared and recommend not relying on conversation history.

Not verified (research halted early on these): anthropics/claude-code GitHub issues and the engineering blog were not swept; the changelog has **no entry** for the 5,000/25,000 limits; whether Skill-tool (model-invoked) and user-invoked attachments are treated identically at re-attachment is inferred from the unification statement, not stated.

Acceptance-criterion note: the ticket requires this verification to be recorded — done; the review's "~5k/25k" hypothesis is upgraded to documented fact (exact figures).

### 3. Anatomy of plan.md and research.md (current tree, commit 9f11dc9)

Command line counts: plan.md 769 (longest), init.md 479, research.md 475, review.md 468, design_explore.md 372, implement.md 306, ticket.md 291, work.md 264, quickfix.md 243, refresh.md 155, discuss.md 140, commit.md 89 (tmt: init 246, create 89, update 72, list 21).

**plan.md (769 lines)** — stable reference blocks (~330 lines, 43%):

- The plan document template: `plan.md:461-563` (~103 lines) — the single biggest artifact (Overview / Current State / Desired End State / What We're NOT Doing / phases with Automated+Manual Success Criteria / Testing Strategy / References).
- Success Criteria Guidelines: `plan.md:659-695` (taxonomy + fenced format example).
- Common Patterns: `plan.md:697-720` (DB changes / new features / refactoring checklists).
- Sub-task Spawning Best Practices: `plan.md:722-753`.
- Example Interaction Flow: `plan.md:755-769`.
- Smaller fixed artifacts inline in steps: canned no-parameter response (188-200), "present informed understanding" skeleton (262-282), design-exploration offer copy (312-316), "present findings and design options" skeleton (373-389), plan-outline proposal skeleton (397-409), UI/UX Approach skeleton (422-442), draft-plan presentation message (569-580), open-questions example (148-171), AskUserQuestion block (18-36, shared nine-copy artifact), Workflow Context table (40-57).

Per-invocation behavior: config reads (10-16), Ticket Document Discovery (59-84), Research Document Integration (86-117), Handling Open Questions (119-174), Initial Response logic (176-202), Steps 1–5 (204-597), Important Guidelines (599-657 — largely restatements, see §4).

**research.md (475 lines)** — stable reference blocks (~130 lines, 27%):

- The research document template: `research.md:266-347` (~82 lines, incl. frontmatter spec and the "tce Config Drift" conditional section).
- Impact Analysis section template: `research.md:420-440`.
- AskUserQuestion block (18-36), Workflow Context table (40-56), canned no-parameter response (137-141), Next-command block (366-369).

Per-invocation behavior: config reads (10-16), documentarian CRITICAL section (58-74), Ticket Document Discovery (76-100), Sufficiency Check (102-121), Initial Setup (123-143), Steps 1–10 (145-383), Reuse/Extension research steps (385-414), Important notes (446-475 — largely restatements).

**Cross-references that constrain restructuring** (anchors that break if lists are renumbered or headings renamed):

- plan.md internal: `:96` "Proceed directly to Step 3", `:225` "SKIP steps 3-4 below", `:228` "proceed directly to step 6" (Step 1's internal numbering), `:322/:324` skip logic, `:597` → the Next-command hint at `:579`.
- research.md internal: `:73` "(see step 4 and step 8)", `:241`, `:263`, `:342`, `:362`, `:465-467` ("Critical ordering" pins step numbers 1/4/5/6).
- Cross-file: `work.md:189` names "**Step 3 (Plan Structure Development)** and **Step 4 (Detailed Plan Writing)**" — hard coupling to plan.md's step names/numbers.

### 4. Repetition catalog (within-file)

plan.md:

- "Read FULLY / WITHOUT limit/offset / NEVER partially" — 10 occurrences (`plan.md:64, 91, 117, 183, 208, 214, 216, 224, 250, 617`).
- "Don't re-read source files the research covers / research IS your context" — 9 occurrences (`plan.md:93, 94, 98, 100, 101, 102, 226, 643, 645-648`).
- "Don't spawn redundant research agents when research exists" — 7 occurrences (`plan.md:92, 110, 225, 229, 322-324, 644, 647`).
- "Open questions discussed, not assumed / wait / none in final plan" — 7 sites (`plan.md:121-123, 138, 141-146, 227, 289-290, 635-640, 651-657`).
- Automated/manual success-criteria split — 4 sites (`plan.md:507-523, 587, 620, 659-695`).
- ticket.sh invocation — 4 occurrences (`plan.md:68, 78, 115, 220`); "Wait for ALL sub-tasks" — 2 (`plan.md:369, 737`); TodoWrite — 2 (`plan.md:337, 631`).
- `## Important Guidelines` (599-657) is structurally a restatement digest of rules stated earlier.

research.md:

- "Read FULLY / no limit/offset" — 5 occurrences (`research.md:81, 133, 149, 150, 463`).
- "Read mentioned files before spawning sub-tasks" — 3 (`research.md:151, 463, 465`).
- "Wait for ALL sub-agents" — 3 (`research.md:221, 223, 466`).
- "Documentarian, not critic / no recommendations / what IS not SHOULD BE" — 11+ occurrences (`research.md:51, 58-66, 173, 174, 176, 183, 219, 324, 442, 460, 461, 462`).
- Metadata-before-writing / no placeholders — 4 (`research.md:244-250, 263, 467, 468`); config-drift mechanism described 4 times (`research.md:68-74, 232-242, 340-346, 362-364`); parallel-agents — 3 (`research.md:165-167, 216, 448`); plus ~8 more two-site echoes between the numbered steps and `## Important notes` (446-475).
- `## Important notes` is, like plan.md's Important Guidelines, a restatement digest of the numbered steps.

Cross-file (not intra-file, noted for completeness): the canonical-ID-in-filename rule is byte-near-identical in `plan.md:451-455` and `research.md:252-256`; the sufficiency criteria appear in research.md, work.md and the tickets.md template (§6; TP-0022's scope).

### 5. Git archaeology: load-bearing vs lineage

File histories: both files originate at `fb68d34` "chore: initial Claude Code project template" (pre-plugins layout, as `create_plan.md` / `research_codebase.md`), through `62e9a81` (workflow-improvements merge), `90f88eb` (plugin conversion), `9f321ab` (monorepo), `88fc916` (TP-0005 rename to plan.md/research.md). plan.md has 12 commits total, research.md 16.

Pickaxe verdicts (`git log -S … --follow`):

| Repeated instruction | Verdict |
|---|---|
| "WITHOUT limit/offset" (both files) | **Present at import** (`fb68d34`) — lineage |
| "Wait for ALL sub-agent tasks" (research.md) / "Wait for ALL sub-tasks to complete" (plan.md) | **Present at import** (`fb68d34`) — lineage |
| "DO NOT re-read source files it already covers" (plan.md) | **Present at import** (`fb68d34`) — lineage in origin, but **protected by policy**: CLAUDE.md's TP-0013 rule forbids weakening it |
| "No Open Questions in Final Plan" (plan.md) | **Present at import** (`fb68d34`) — lineage |
| "The research document IS your codebase context" (plan.md) | **Present at import** (`fb68d34`) — lineage |
| Chain-order re-read of ticket/research/plan (context documents) | **Added by `062edd9` (TP-0013)** — deliberate, failure-motivated, per-command by design (TP-0013 research explicitly rejected a shared block because each command's input set differs) |
| AskUserQuestion dialog guidelines block | **Added by `31e7760` (TP-0001)** — deliberate nine-copy duplication with a CLAUDE.md byte-identity rule |

TP-0015 commits (all 2026-07-03, already in HEAD): `540aa8c` (research.md starts immediately with an argument), `589b608` (removed dead HumanLayer thoughts-sync/searchable machinery from research.md and thoughts-locator), `6dc55a2` (plan.md numbering/example/plan-mode/sync-step cleanup), `11f78da` (implement.md repository-state check), `9f11dc9` (quickfix /simplify removal). Note: line numbers in TP-0015's research doc predate these fixes; this document's line numbers are current at 9f11dc9.

### 6. Existing repo mechanics the change builds on

- **`${CLAUDE_PLUGIN_ROOT}` today** is used for exactly three things: executing shipped scripts (10 sites in tce commands for `scripts/ticket.sh` — `research.md:85,95`, `plan.md:68,78,115,220`, `implement.md:48,61`, `review.md:116`, `work.md:72`; 3 sites in tmt commands; 3 hook commands), template `cp` in the two inits (`tce/init.md:316-317,366`, `tmt/init.md:127`), and reading `plugin.json` for version markers (`tce/init.md:326,449`, `refresh.md:137,153`, `tmt/init.md:132,229`). **There are no runtime Reads of plugin-internal markdown anywhere** (verified repo-wide; also recorded in the TP-0001 research). All other runtime context loading targets project files via `${CLAUDE_PROJECT_DIR}`.
- **Templates convention**: `plugins/tce/templates/tce/{profile,tickets,design-system}.md` and `plugins/tmt/templates/tmt/config`, nested `templates/<plugin-name>/…` mirroring the target `.claude/<plugin-name>/` path. `init.md:310-318`: "templates/tce/ is the single source of truth for their structure, so don't reproduce it from memory" — copy, then Read the *copied project file*. `refresh.md:131-132` guards against clobbering ("never copy a template skeleton over them"). Note these existing templates are *project-config skeletons*; TP-0016's reference files would be a second, distinct kind of plugin file (command-support material never copied into projects) — where they live is a planning decision.
- **Frontmatter today**: every command has only `description` (+ `argument-hint` where relevant); agents have `name`/`description`/`tools`/`model: inherit`. No `allowed-tools`, `disable-model-invocation`, `context`, `!`-injection, or `@file` anywhere (TP-0017's territory).

### 7. Sync surface a restructure must honor

CLAUDE.md rules that bind the edit (all in repo-root `CLAUDE.md`):

1. **Composite tracking** (`CLAUDE.md:177-188`): any plan.md/research.md change requires checking work.md and quickfix.md in the same commit — explicitly naming the research agent list, research/plan templates, sufficiency/open-questions/design-exploration checks, status-file mechanics, phase ordering.
2. **TP-0013 re-read rule** (`CLAUDE.md:201-214`): the ordered re-read instructions (`plan.md:64,91`; `research.md:81`) must stay intact, and the source-file no-re-read guidance must not be weakened.
3. **AskUserQuestion nine-copy rule** (`CLAUDE.md:244-246`): research.md/plan.md each carry one of the nine byte-identical copies.
4. **refresh/init tracking** (`CLAUDE.md:229-231`): research.md's drift detection (`research.md:232-242, 340-346, 362-364`) must survive and stays mirrored in the composites.

Composite mirrors (hand-synced re-descriptions):

- **work.md** re-describes all phases inline: sufficiency check (`work.md:74`), the six-agent roster verbatim (`work.md:82`), drift taxonomy word-for-word (`work.md:85`), metadata/filename/permalinks (`work.md:86-88`), open-question types 1–4 near-verbatim from `plan.md:127-131` (`work.md:105-113`), design-exploration check (`work.md:115-126` ← `plan.md:292-320`), plan-template + success-criteria references (`work.md:195-196`), and the hard coupling `work.md:189` → plan.md Step 3/Step 4 titles.
- **quickfix.md** delegates planning/implementation to the `tce:plan`/`tce:implement` skills (`quickfix.md:160,184`) so it inherits those changes, but re-describes *research* inline (`quickfix.md:126-153`: roster, drift check, metadata, "standard /tce:research template" + Impact Analysis by name), and its autonomy overrides reference plan.md internals (`quickfix.md:162-167`: skip structure review, resolve open questions, design-exploration flag).

Downstream format dependencies:

- **implement.md** consumes the plan template's phases/checkboxes/success-criteria split (`implement.md:8, 67, 193, 215, 219, 291-299`) and the research frontmatter fields `git_commit`/`branch` for the repository-state check (`implement.md:57` ← `research.md:269-270`); `plan.md:109` consumes `last_updated` (`research.md:275`).
- **review.md** consumes the filename conventions (`review.md:124-125`) and ticket Acceptance Criteria per the template contract (`templates/tce/tickets.md:87`).
- **Status file** is defined solely in `implement.md:90-144` (mirrored at `work.md:224-227,237`; inherited by quickfix via delegation; README tree entry). Neither plan.md nor research.md mentions it. Sibling **TP-0023 plans to eliminate the status file entirely** (in-plan implementation log instead) — if TP-0016 considered moving the status-file format to a reference file, that material is scheduled to be rewritten.
- **Sufficiency criteria trio**: near-verbatim copies at `research.md:102-121` (full), `work.md:74` (one-line citing /tce:research), `templates/tce/tickets.md:64-91` (full, backend-independent, cross-referencing research.md by name at :89-91). **TP-0022 owns adding the sync rule for these** — it deliberately keeps them as copies and declares structural dedup out of its scope. TP-0022's Out-of-Scope text asserts "commands can't read plugin-internal markdown at runtime — the duplication is deliberate"; current docs (§1) show plugin-internal reads *are* sanctioned, so that assertion is stale relative to the docs (recorded here as fact about the ticket text, not a recommendation).

Current text TP-0016 respecs (quoted in full in the sync-surface excerpts below):

- **plan.md Step 5** (`plan.md:565-597`): presents the draft-plan *location* plus four generic review prompts ("Are the phases properly scoped? Are the success criteria specific enough? …"), iterate-until-satisfied, commit via /tce:commit, "Your job ends here". Nothing in the current text asks for a decision-oriented summary (decisions made, alternatives rejected, risky assumptions, out-of-scope) — that content is currently unspecified.
- **work.md checkpoint intro** (`work.md:128-179`, section 2c): intro template with "[One sentence summarizing the ticket and where research landed]" + 2–4-sentence key-findings paragraph; work.md's plan-presentation counterpart is a bare status line (`work.md:206-212`) with an explicit "Do NOT present the plan outline for user approval" (`work.md:200`).

### 8. Sibling-ticket boundaries (from the same review)

- **TP-0013** (done): per-command re-read clauses; its research explicitly rejected a shared byte-identical block ("each command's input set differs … necessarily per-command").
- **TP-0015** (done): the concrete defects; all five fix commits are in HEAD.
- **TP-0017** (open): frontmatter machinery (`disable-model-invocation`, `allowed-tools`, agent models, `!`-injection) — explicitly lists "Command body length/deduplication (TP-0016)" as out of scope; the two ticket scopes are disjoint by construction.
- **TP-0022** (open): sufficiency-criteria sync rule — keeps the trio as copies; structural dedup out of scope.
- **TP-0023** (open): merge status file into the plan — rewrites implement.md/work.md status-file mechanics; no explicit ordering with TP-0016 is stated in either ticket.

## Code References

- `plugins/tce/commands/plan.md:461-563` — the plan document template (~103 lines), largest embedded artifact
- `plugins/tce/commands/plan.md:659-695, 697-720, 722-753, 755-769` — Success Criteria Guidelines, Common Patterns, Sub-task Spawning, Example Interaction Flow (the "tail" sections past the 5k-token cliff)
- `plugins/tce/commands/plan.md:565-597` — Step 5 (Review and Commit), the presentation step TP-0016 respecs
- `plugins/tce/commands/plan.md:599-657` — Important Guidelines (restatement digest)
- `plugins/tce/commands/research.md:266-347` — the research document template (~82 lines)
- `plugins/tce/commands/research.md:420-440` — Impact Analysis template
- `plugins/tce/commands/research.md:446-475` — Important notes (restatement digest)
- `plugins/tce/commands/work.md:189` — verbatim coupling to plan.md Step 3/4 titles
- `plugins/tce/commands/work.md:128-179` — checkpoint intro (2c) mirroring the decision-presentation spirit
- `plugins/tce/commands/quickfix.md:126-153` — inline re-description of the research phase
- `plugins/tce/commands/implement.md:57` — repository-state check consuming research frontmatter `git_commit`/`branch`
- `plugins/tce/commands/implement.md:90-144` — sole status-file definition (TP-0023 target)
- `plugins/tce/commands/init.md:310-318` — "templates/tce/ is the single source of truth" copy-then-fill pattern
- `CLAUDE.md:177-188, 201-214, 229-231, 244-246` — the four sync rules binding the restructure
- `plugins/tce/templates/tce/tickets.md:64-91` — "What tce needs from a ticket" (sufficiency-trio canonical-copy candidate per TP-0022)

## Architecture Documentation

- The plugins coordinate only through project config files; commands load context at runtime from `${CLAUDE_PROJECT_DIR}` files (profile.md, tickets.md) and workflow documents on disk — never from plugin-internal markdown (as of today) or fading conversation state.
- `${CLAUDE_PLUGIN_ROOT}` is the plugin-internal path anchor (scripts, templates, plugin.json); `templates/<plugin>/` currently holds only project-config skeletons that inits copy out.
- The command chain's durability model: artifacts (ticket → research → plan) live in `thoughts/shared/` with YAML frontmatter and are re-read fully at each consuming step (TP-0013). Reference files for command templates would extend the same model to the commands' own stable material — the mechanism the docs now sanction for skills.
- Composite commands are derived artifacts: work.md re-describes all phases; quickfix.md delegates plan/implement via the Skill tool but re-describes research inline.

## Historical Context (from thoughts/)

- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` — Section 2 findings 1–2 (the origin of this ticket); Section 2's compaction figures now doc-confirmed.
- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md` + plan — the re-read rule's design; explicitly chose per-command phrasing over a shared block; defined the context-documents vs source-files distinction that must not blur.
- `thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md` — pre-fix structural map of both commands; notes step-numbering is load-bearing (`research.md` "Follow the numbered steps exactly") and that the plan template has no frontmatter.
- `thoughts/shared/tickets/TP-0017-adopt-frontmatter-machinery.md`, `TP-0022-sufficiency-criteria-sync-rule.md`, `TP-0023-merge-status-file-into-plan.md` — adjacent scopes (see §8).
- `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md` — records "no runtime reads of plugin-internal markdown" as a then-verified invariant.

## Related Research

- `thoughts/shared/research/2026-06-18-TP-0013-explicit-context-document-reads.md`
- `thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md`
- `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md`

## External Sources

- https://code.claude.com/docs/en/skills — commands-merged-into-skills note; supporting files; frontmatter reference; **Skill content lifecycle** (5,000/25,000 compaction budgets); string substitutions
- https://code.claude.com/docs/en/plugins-reference — `${CLAUDE_PLUGIN_ROOT}` substitution scope ("skill content, agent content, hook commands, monitor commands, MCP/LSP configs"); Skills component ("commands are simple markdown files"); file-locations table ("Use `skills/` for new plugins"); path-traversal limitation
- https://code.claude.com/docs/en/plugins — plugin structure table, skills quickstart
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices — under-500-lines guidance; progressive disclosure; references one level deep; TOC for files >100 lines; "no context penalty until actually read"
- https://code.claude.com/docs/en/how-claude-code-works — compaction clears older tool outputs first; CLAUDE.md persistence
- https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md — checked; silent on re-attachment limits
- Community (lower confidence, not fetched): claudefa.st notes on skill-listing budget and compaction trigger threshold

## Open Questions

1. **Reference-file placement**: `templates/` currently means "skeletons copied into projects"; command-support reference files are a different artifact class. Options observed in the ecosystem: a `references/` dir (skills convention), or extending `templates/` — a planning decision; if `skills/<name>/SKILL.md` layout is adopted, supporting files co-locate in the skill dir and `${CLAUDE_SKILL_DIR}` becomes available.
2. **Flat command + `${CLAUDE_PLUGIN_ROOT}` Read vs full skill-directory conversion**: both are sanctioned; the docs recommend `skills/` for new plugins but flat commands "keep working". Conversion preserves invocation names but changes file paths that CLAUDE.md, READMEs, and the marketplace docs reference.
3. **Reference files and the compaction win**: a reference file is only re-read if the surviving body still instructs the read at the moment of use — placement of the read instruction within the first 5,000 tokens (or at the point of use in a numbered step) matters; nothing in the docs automates re-reading.
4. **Restatement digests** (`plan.md` Important Guidelines, `research.md` Important notes): whether to delete outright or fold unique fragments upward — several digest bullets are the *only* statement of a nuance (e.g. `research.md:468` "NEVER write the research document with placeholder values" appears in full form only there and step 5/6 references).
5. **Ordering with TP-0023**: if TP-0023 (status-file merge) lands first, implement.md's mechanics shrink on their own; TP-0016 does not touch implement.md's status-file text per its own scope, but the plan template's checkbox/phase structure (which TP-0023 preserves) is what TP-0016 would externalize — no hard conflict found, but same-file traffic suggests sequencing them.
6. **Cross-file near-duplicates** (canonical-ID-in-filename rule in plan.md+research.md; sufficiency trio): in scope for TP-0016's "each rule stated once" only *within* each file; cross-file copies are governed by the composite rule and TP-0022 — the plan should state this boundary explicitly.
