---
date: 2026-11-07T09:03:37Z
git_commit: dbb44b8551e2349e172ffd19b8bab4d606da2ef9
branch: main
repository: toby-plugins
topic: "TP-0048: show the human only what needs the human"
tags: [research, tce, work-loop, intent, presenter, plan-challenger, allowlist, profile, askuserquestion]
status: complete
last_updated: 2026-11-07
---

# Research: TP-0048 — show the human only what needs the human

**Date**: 2026-11-07T09:03:37Z
**Git Commit**: dbb44b8551e2349e172ffd19b8bab4d606da2ef9
**Branch**: main
**Repository**: toby-plugins

## Research Question

How does tce 1.7.1 present things to the human today and how are the parts that
TP-0048 changes built? The parts are the script grants and the allowlist, the
step loop's AskUserQuestion sites, the brief and dossier output, the
`/tce:intent` dialogue, the plan challenger's contract, the profile's agreed
sections, and the `thoughts/` material that standing-rule mining would walk.
Inputs: ticket `thoughts/shared/tickets/TP-0048-intent-and-plan-approval-output.md`,
intent `thoughts/shared/intents/2026-11-07-TP-0048-show-the-human-only-what-needs-the-human.md`
(which takes precedence) and its source discussion
`thoughts/shared/discussions/2026-11-07-tce-show-the-human-only-what-needs-the-human.md`.

## Summary

- **Scripts and grants.** Five shipped scripts are called through
  `${CLAUDE_PLUGIN_ROOT}/scripts/`, granted only per command in
  `allowed-tools` (one turn). `/tce:init`'s allowlist has no script entries.
  After Step 6 the loop still calls `stage.sh` (after every step),
  `work.sh artifact` (every artifact return) and `baseline.sh` (Steps 7 and 8).
- **Real-run check of the allow rule (this session, Claude Code 2.1.319,
  `claude -p`).** The intent's candidate form
  `Bash(/Users/<me>/.claude/plugins/*/tce/scripts/stage.sh *)` **does not
  match**. The real cache path has a version segment *after* `tce`
  (`~/.claude/plugins/cache/toby-plugins/tce/1.7.1/scripts/stage.sh`). The
  form `Bash(/Users/toby/.claude/plugins/cache/*/tce/*/scripts/stage.sh *)`
  **matches**, for both the unquoted call and the quoted one the loop uses.
  A directory-sourced install (this repo) resolves `${CLAUDE_PLUGIN_ROOT}`
  to the source directory, not the cache.
- **AskUserQuestion sites.** `work-loop.md` has two: Step 6 (the planner's
  questions, "Decisions for you", "Approve the plan?") and **Step 12**
  ("Have you checked the items above?"). Invariant 5 states the one-turn
  reason. The guidelines block is byte-identical in ten files.
  `/tce:intent` has three sites, including the verbatim base-branch
  stop-and-ask dialog of the TP-0031 span.
- **Output.** The planner writes the brief and prints it verbatim, per-phase
  list included (`work-brief.md`). Under Direct delivery Step 11 prints the
  dossier's full text. The plan challenger has no `mode:`, and its item 6
  is "Brief faithful". `/tce:intent` dispatches no agent and has no Agent
  grant. Compressed Round 1 prints a complete draft; full-track Phase 7
  prints a summary.
- **Profile sections.** Branch convention, Delivery and Reader share one
  lifecycle: template options with "(The default — identical to leaving this
  section out.)", init dialogs, Phase 4 fill, Idempotency bullet, four
  hand-authored sites in refresh, and a README bullet. Nothing in tce reads
  a declined list or standing rules.
- **Mining material.** 7 intents and 9 plans carry `## Decisions` (16
  headings, plus one false positive inside a fence). The line shapes vary a
  lot, and intent decisions are copied into plans and dossiers, so a naive
  count double-counts. 18 clusters recur in 2+ documents.

## Detailed Findings

### 1. Shipped scripts: where they are called, and how they are granted

**Call sites in `plugins/tce/references/work-loop.md`:**

| Step | Call | Line |
|---|---|---|
| 0 | `work.sh preflight` | 103 |
| 2 | `branch.sh switch <branch>` | 144 |
| 2 (pre-1.6.0 ticketless intent) | `branch.sh create … --trust-local` | 155 |
| 3 | `ticket.sh <ID>`, `stage.sh <ID>`, `ticket.sh` for the parent | 171-176 |
| 4 | `stage.sh` re-run after every step | 189-190 |
| 4 | `work.sh artifact <path>` on every return naming an artifact | 199-201 |
| 7 | `baseline.sh <git_commit> <research-path>`, raw `git rev-parse HEAD`, `stage.sh` after each phase | 255-264 |
| 8 | raw `git log --grep`, then `baseline.sh <base> <plan-path>` | 271-273 |
| 10 | raw `git push`, `gh pr view`, `gh pr create` (Pull request only) | 294-297 |
| 10 (row 1), 11, 12 | `/tce:commit`, plus `git push` under Pull request | 311-312, 331-332, 352 |

**After Step 6:**

- In-loop shipped-script calls: `stage.sh`, `work.sh artifact` and `baseline.sh`.
- `/tce:commit` adds `branch.sh check` (`commands/commit.md:68`), but only under Branch per ticket.
- `branch.sh`, `ticket.sh` and `work.sh preflight` are called in Steps 0-3 only. A resumed run re-enters those steps.

**`allowed-tools` grants (exact strings):**

- `commands/work.md:5` and `quickfix.md:5`:
  - all five scripts as `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/<x>.sh:*)`
  - `Bash(git rev-parse:*)`, `Bash(git log:*)`, `Bash(git push:*)`, `Bash(gh pr create:*)`, `Bash(gh pr view:*)`
- `implement.md:4`: the five scripts, `git rev-parse`, `git log`.
- `plan.md:4` and `research.md:4`: `ticket.sh`, `stage.sh`, `branch.sh`, `work.sh`.
- `intent.md:4`: `stage.sh`, `branch.sh`, `git rev-parse`.
- `review.md:5`: `ticket.sh`, `branch.sh`.
- `commit.md:3`: `branch.sh`.
- `list.md:4`: `stage.sh`.
- No `allowed-tools` line: `init.md`, `refresh.md`, `discuss.md`, `design_explore.md`, `ticket.md`.
- No command grants `AskUserQuestion`, `Agent` or `Skill`.

**How the grants are written:**

- Grants leave the path unquoted. Bodies call `"${CLAUDE_PLUGIN_ROOT}/scripts/x.sh"`, quoted.
- `README.md:350-356` records that quoted grant patterns up to 1.5.0 only matched quoted calls.

**`/tce:init`'s allowlist** (`commands/init.md:580-652`):

- What it offers:
  - `Read(~/.claude/plugins/**)` for a marketplace install ("whose cache directory changes with every version", 585-587)
  - otherwise `Read(//<path>/**)` (588-592), plus the stale single-slash removal (593-596)
  - `Edit(thoughts/shared/**)`
  - eight local-git `Bash(...:*)` entries (598-600)
  - the profile's test, typecheck and lint commands (601)
- "**Never** `git push` and never `gh`" (603-604). Already-present entries are skipped (605-606).
- Two AskUserQuestion variants (613-646). The edit is surgical (648-652).
- No script entries. No plugin text says why. The rationale ("Scripts run only in the orchestrator… the grant does not reach subagents") exists only in the repo's `CLAUDE.md` ("tce: the step commands are orchestrators").
- `/tce:refresh` never mentions the allowlist or `settings.json`.

**This repo's own `.claude/settings.json`** allows `Edit(thoughts/shared/**)`, the eight git entries and `Bash(claude plugin validate:*)`. It has no Read entry and no script entry.

### 2. Real-run check of the Bash allow-rule forms (Question for research 1)

**Install facts:**

- `~/.claude/plugins/installed_plugins.json` records `installPath: /Users/toby/.claude/plugins/cache/toby-plugins/tce/1.7.1`.
- The cache holds `tce/1.5.0` and `tce/1.7.1`. Scripts sit at `<installPath>/scripts/`.
- That matches the documented layout `cache/<marketplace>/<plugin>/<version>/`. "a plugin's root path changes with every version" ([plugins/loading](https://code.claude.com/docs/en/plugins/loading.md#find-plugins-on-disk)).
- The `toby-plugins` marketplace is `"source": "directory"` at `/Users/toby/code/work/toby-plugins`. In this session `references:` resolved to `/Users/toby/code/work/toby-plugins/plugins/tce/references`, so `${CLAUDE_PLUGIN_ROOT}` is the source directory. That matches the docs: "Relative-path plugins in a marketplace you added from a local path … load in place".

**Probe setup:**

- `claude -p --model haiku --setting-sources user --settings <file>`, in scratch directories under the session scratchpad.
- Asked to run `/Users/toby/.claude/plugins/cache/toby-plugins/tce/1.7.1/scripts/stage.sh FAKE-0001`.
- The project `settings.json` route could not be used. In an untrusted scratch folder Claude Code prints "Ignoring 1 permissions.allow entry … this workspace has not been trusted", the same constraint TP-0045g recorded.

**Results:**

| Rule | Command | Result |
|---|---|---|
| `Bash(/Users/toby/.claude/plugins/cache/*/tce/*/scripts/stage.sh *)` | unquoted | ran, `permission_denials: []` |
| same | quoted (`"…/stage.sh" FAKE-0001`, confirmed in the session transcript) | ran, `permission_denials: []` |
| `Bash(/Users/toby/.claude/plugins/*/tce/scripts/stage.sh *)` (the intent's candidate shape) | unquoted | **denied** |
| none (control) | unquoted | denied, so no user-level rule masks the result |

**What the probe did not show:**

- No startup warning about "a wildcard before the rest of the command" appeared on stderr under `-p`.
- Whether the interactive startup warning (documented since v2.1.246, warning-only: "Claude Code keeps the rule and changes nothing about how it matches", [errors](https://code.claude.com/docs/en/errors.md#has-a-wildcard-before-the-rest-of-the-command)) fires for a `*` inside the program path is not documented and was not observed interactively.

**Docs** ([permissions](https://code.claude.com/docs/en/permissions#wildcard-patterns)):

- "A `*` in a Bash rule matches any text, including spaces".
- "A `*` can go anywhere in the rule".
- "`:*` … only recognized at the end of a pattern".
- `~`/`$HOME` expansion is documented for Read/Edit, not Bash.
- `${CLAUDE_PLUGIN_ROOT}` is substituted in a skill's `allowed-tools` Bash rules ([skills](https://code.claude.com/docs/en/skills.md)). settings files are absent from the "Where each variable resolves" table ([plugins-reference](https://code.claude.com/docs/en/plugins-reference#where-each-variable-resolves)).
- A skill's `allowed-tools` grant: "The grant clears when you send your next message … To pre-approve tools for the whole session … add allow rules to those permission settings instead" ([skills](https://code.claude.com/docs/en/skills.md)).

**The `bin/` fallback:**

- Docs: "Files in `bin/` at the plugin root are on the `PATH` of the Bash tool's shell while the plugin is enabled, so Claude can run them as bare commands". Plugin `bin/` comes after the user's PATH. "claude.ai and Cowork don't install a plugin that has a top-level `bin/` directory" ([plugins/components](https://code.claude.com/docs/en/plugins/components.md#executables)).
- Since v2.1.91, per a release-notes mirror ([newreleases.io](https://newreleases.io/project/github/anthropics/claude-code/release/v2.1.91)) and not the official changelog.
- `plugins/tce/bin/` does not exist.

What a move would touch:

- 48 `${CLAUDE_PLUGIN_ROOT}/scripts/` occurrences on 28 lines:
  - 29 grant occurrences on 9 frontmatter lines
  - 16 body calls: `quickfix.md:50`, `review.md:122,133`, `commit.md:68`, `intent.md:137,147,181`, `list.md:93`, `work-loop.md:103,144,155,171,172,200,257,273`
  - `hooks/hooks.json:9` (`check-init.sh`, exec form)
  - `README.md:419,434`
- Bare-name mentions: `work-loop.md:173,176,190,264`, `work-dispatch.md:33,35,66,86`, `intent.md:445`, `commit.md:106`, `review.md:466`, `agents/implementer.md:46`, `agents/verifier.md:44`, `intent-document-template.md:7,14`.
- Every script sources `lib.sh` via `$SCRIPT_DIR/lib.sh`: `branch.sh:47`, `baseline.sh:28`, `ticket.sh:17`, `check-init.sh:34`, `stage.sh:48`, `work.sh:43`.

**GitHub issues:**

- [#16389](https://github.com/anthropics/claude-code/issues/16389): a plugin `allowed-tools` script grant failing on quoting, closed "not planned".
- [#14956](https://github.com/anthropics/claude-code/issues/14956): skill `allowed-tools` not granting Bash, open.
- [#18160](https://github.com/anthropics/claude-code/issues/18160): `~` in command text against `Bash(ls *)`, open.

### 3. AskUserQuestion in the loop and the commands

**The guidelines block** (`### AskUserQuestion dialog guidelines`, 19 lines) is byte-identical in ten files:

| File | Lines |
|---|---|
| `plugins/tce/commands/init.md` | 16-34 |
| `plugins/tce/commands/intent.md` | 52-70 |
| `plugins/tce/commands/refresh.md` | 39-57 |
| `plugins/tce/commands/ticket.md` | 36-54 |
| `plugins/tce/references/work-loop.md` | 31-49 |
| `plugins/tmt/commands/init.md` | 14-32 |
| `plugins/tmt/commands/update.md` | 16-34 |
| `plugins/tle/commands/define.md` | 19-37 |
| `plugins/tsf/commands/init.md` | 31-49 |
| `plugins/tsf/commands/spec.md` | 28-46 |

The rule that names these copies is in `CLAUDE.md` at about lines 1368-1389.

**In `work-loop.md`:**

- Header comment (12-13) and contents entry (16) name the block.
- Below it sits the planner exception (51-55): `Understood:`/`Approach:` go into the first question's text. "Real runs left a message before the dialog out, however it was worded".
- Invariant 4 (72-74): what reaches the human.
- Invariant 5 (75-76): "**Ask through AskUserQuestion**, so the whole run stays in one turn — the running command's `allowed-tools` grant the scripts for this turn only."
- Step 6 (212-251):
  - point 2: questions through AskUserQuestion, four per call, headers shortened to 12
  - point 4: brief printed, "Challenger notes:", "Decisions for you" asked as in point 2, then `Question: "Approve the plan?" — header: "Plan"` with **Approve (Recommended)** / **Stop here**
  - a free-text answer is a push-back (`mode: revise`)
- **Step 12** (337-359): `Question: "Have you checked the items above?" — header: "Checked"` with **All pass** / **Not yet**. A free-text answer is a failure report. This is the loop's second AskUserQuestion site. The intent's scope names only Step 6.
- Step 2 (148, 157-158): `dirty` → "ask the user to commit or stash, then re-run" (prose, no dialog).

**`references/work-brief.md`:** AskUserQuestion appears at 54 ("At most 4 options per question (AskUserQuestion's limit)"), 57-61 (the orchestrator copies each item into one AskUserQuestion question; the header is shortened) and 93.

**`references/work-dispatch.md:96-98`:** `answers:` carries "each question's header as the dialog showed it".

**Lanes:**

- `commands/plan.md` runs Step 6 "exactly as `/tce:work`", including "Approve the plan?".
- `commands/quickfix.md:69-76` runs "6 **without the approval dialog**". It still prints the brief and the challenger notes, and asks "Decisions for you" only when not `None.`.
- `commands/implement.md:41-42` treats row 8 as approved, with no brief.

**`commands/intent.md` sites:**

- the block (52-70)
- the base-branch stop-and-ask dialog, "use this copy verbatim" (160-175), also used in autonomous mode (449), part of the TP-0031 branch-convention span
- the existing-intent dialog, header "Intent", **Update it (Recommended)** / **Leave it** (187-192)
- compressed-track business questions "following the AskUserQuestion dialog guidelines" (264-267)
- Already prose: Round 2's "Ready for me to write this intent?" (269-270), the Phase 1/2/4 gates (294, 303, 323), Phase 6 (344) and Phase 7 (351).

**`commands/commit.md`:** asks in prose on `on-base`/`elsewhere`/`detached` (69-73) and carries no block.

**Step agents:** `researcher`, `planner`, `implementer` and `verifier` carry `disallowedTools: AskUserQuestion` (line 4 each).

**`CLAUDE.md`:**

- The "One turn, kept by AskUserQuestion" bullet (about 439-442): "A prose question would end the turn and drop it."
- The allowlist bullet "**Never widen it — never `git push`, never `gh`, never any other key, never any other removal.**" (about 449-457).

### 4. The brief, the delta and the dossier output today

**`references/work-brief.md`:**

- Header (1-19): read by the planner and by `work-loop.md` Step 6. Its span is this file, `planner.md` and `work-loop.md`.
- Terminal constraints (21-32): no tables with prose cells, one takeaway line with counts, counted facts only, the artifact linked by path.
- Questions (34-64): one decision per item, self-contained, "Never write "see research.md"". `Understood:`/`Approach:` layout at 41-52; `0 questions` when none.
- Brief (66-101):
  - "The orchestrator prints it as-is and then asks for approval".
  - Layout: `APPROVE?` line, Understood/Approach, `## Decisions for you`, `## Decided for you (push back on any)`, `## Phases` with a counts line, `Risk:`, `Full plan:`.
  - "Decided for you" lists every `*(decided for you)*` line, "nothing more and nothing less".
- Delta (103-122): a `CHANGED:` line, only changed sections, `+`/`~`/`- … (removed)`.
- Phrasing for the reader (124-132): per `## Reader`. "vocabulary and depth, not length".
- The file states no line budget. The bound is in `agent-returns.md:88`: "A brief, a delta or a question batch: at most 60 lines".

**`agents/planner.md`:**

- Frontmatter: `disallowedTools: AskUserQuestion`, `model: inherit`.
- Modes `questions | write | revise | challenge-fix | brief` (44).
- `mode: questions` (79-114):
  - writes nothing
  - checks for design exploration via `thoughts/shared/mockups/*/DECISION.md` (99-109)
  - returns `Understood:`, `Approach:` and the questions
- `mode: write` (116-154): commits through `tce:commit`, then returns the brief: "the decisions made on the human's behalf, the riskiest assumption, what is explicitly out of scope … and the phases".
- revise and challenge-fix (156-166) return the delta.
- `mode: brief` (168-172) re-reads and returns the full brief.
- Filled-in returns: questions (182-208) and write (212-241). Which values go together is at 243-254.

**`agents/plan-challenger.md`:**

- `tools: Read, Grep, Glob, LS`, `model: inherit`.
- Receives `plan:`, `intent:`, `research:`, `profile:`, `references:` and `brief:` verbatim, plus an optional `note:` (15-30).
- Checklist (41-60). Item 6, "**Brief faithful.** Every `*(decided for you)*` line in the plan's `## Decisions` appears in the brief's "Decided for you", and the brief claims nothing — no decision, phase, count or risk — that the plan does not contain."
- Verdicts are `pass`/`fail`/`human` with `path:line` (62-73).
- Return (75-105): one line per item, then `step: challenge`. All pass → `done`; human items → `done with concerns`; any fail → `needs decision`.
- **No `mode:` concept.**
- The challenge-fix loop is bounded at 3 rounds (`work-dispatch.md:129`).

**`agents/verifier.md` dossier mode (138-153):**

- Counts from disk.
- Writes `thoughts/shared/dossiers/YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md`.
- Returns the counted-facts line as its summary's first line (174-195): `Criteria met n/m · fix rounds r · tests added t · decisions made for you d · for you to check c`.

**`references/dossier-template.md`:**

- "Two minutes to read" (23-28).
- Sections: Summary (with the counted-facts line at 51), What was built, Where to look, Decided for you, For you to check, Concerns, Artifacts.
- Its header (9-12) ties the counted-facts line and filename to `verifier.md` and `work-loop.md`.

**Step 11 point 4** (`work-loop.md`): "under Direct, the dossier's text; under Pull request, the URL and the dossier's counted-facts line". Step 12 then restates every pending item in full.

**`references/agent-returns.md`:**

- Four statuses (22-40). "Only `needs decision` and `blocked` reach the human" (38-40).
- `step:` is one of `research | plan-questions | plan | brief | challenge | implement | fix | verify | dossier` (44-70). There is no value for a presenter or a brief check.
- Only the planner writes a body. Besides it, only "the challenger's and verifier's one-line-per-item findings" (72-83).
- Bounds: block ≤25 lines, brief ≤60, findings ≤30 (85-91).
- "No script parses it". The retry note is verbatim (93-109).

**`references/work-dispatch.md`:**

- Common block (76-81).
- Per-agent payloads (91-120): the planner's five modes, `plan-challenger` (`plan:`, `research:`, `brief:`), implementer phase/fix, verifier verify/dossier.
- Resume via `SendMessage` (141-143).
- Position table, rows 1-10 (46-57). Row 8: "plan exists, `source: unknown`" → "brief, then approval".

### 5. `/tce:intent` today

**Frontmatter:** `allowed-tools` lists only `stage.sh`, `branch.sh` and `git rev-parse` (line 4). There is no Agent grant. The command is unflagged, and its only Skill edge is from `/tce:quickfix`.

**Order of sections:**

| Lines | Section |
|---|---|
| 26-50 | Project context; Reader at 38-45 |
| 52-70 | block |
| 74-117 | input classification |
| 119-175 | branch |
| 177-194 | existing intent |
| 196-213 | sufficiency, "do not spawn research agents" at 211-213 |
| 215-238 | sizing and routing |
| 240-273 | compressed track |
| 275-351 | full track |
| 353-374 | writing |
| 376-388 | hand off |
| 415-469 | autonomous |

**Compressed Round 1 (247-262)** is one message:

- the restated understanding
- the size and its one-line reasoning, with an override invitation
- the sufficiency questions
- "A **complete first-draft intent** filling every section of the intent template" (255-259)
- then "Ask the user to confirm or correct the draft"

Round 2 (269-273): "Ready for me to write this intent?"

**Full track:**

- Phases 1-7. The gates are at Phases 1, 2 and 4 (294, 303, 323).
- Phase 5 covers boundaries and the XL split; Phase 6 decisions and questions.
- Phase 7 (347-351): "Summarize: Scope / Outcome / Anchors / key Acceptance criteria / Decisions / Size / Out." and "Ask for explicit confirmation".

**Writing (353-374):**

- Re-reads `intent-document-template.md`.
- Names the file `YYYY-MM-DD-[PREFIX]-XXXX-<slug>.md` (ticketless `YYYY-MM-DD-<slug>.md`).
- Commits via "use the `/tce:commit` command" (371-374). This is a Skill call by prose; `Skill` is not in `allowed-tools`.

**Hand off (376-388):** prints the path and `When ready, run: /tce:research [PREFIX]-XXXX   (or /tce:work [PREFIX]-XXXX)`.

**Autonomous mode (415-469):**

- Its whole output is one line: `intent: <path>`, `insufficient: …` or `stopped: …`.
- It runs the slug-uniqueness glob plus `git rev-parse` branch checks (437-445).

**Intent template sections (`references/intent-document-template.md`):**

- Ticket; Scope (`**In:**`, `**Out:**`); Observable outcome; Anchors; Acceptance criteria; Decisions; Open questions; Questions for research; Notes.
- The Decisions shape: `- **[decision]** — over [rejected alternative]: [one-line why]` (73). The plan's `## Decisions` mirrors it (92-94).

### 6. Agreed, hand-authored profile sections (the pattern a `## Presentation` would follow)

**Template (`plugins/tce/templates/tce/profile.md`):**

- Section order:
  - line 1 is the version marker
  - Tech stack 9, Commands 13, Dev environment 21, Code map 30, Conventions 48, Commit convention 53
  - Branch convention 70, Delivery 103, Reader 123, Preferred research sources 139
- Each agreed section has an intro naming its readers, then a bracketed `[Filled by /tce:init with one of: …]` list of bold options.
- The default option carries "(The default — identical to leaving this section out.)": Current branch 82-84, Direct 113-115, Not described 133-134.
- Reader's **Described:** is a free-form placeholder (135-137).

**Runtime absent-section guards:**

- `intent.md:38-39`
- `work-brief.md:131-132`
- `work-loop.md:289-292` (Delivery)
- Other Reader readers: `planner.md:114`, `verifier.md:150`, `dossier-template.md:135`, `work-dispatch.md:165`.

**`commands/init.md`:**

- Gather items 10 (branch, 146-155) and 11 (delivery and reader, 156-161: "Both are only suggestions — … team or personal policy").
- Phase 2 verbatim dialogs:
  - Branch: 314-335, follow-ups at 337-359.
  - Delivery: 361-383. Filled **Direct** silently under Current branch.
  - Reader: 385-401, prose because free-form. "Only an explicit "skip" or "none" fills **Not described**; silence is not a skip — re-ask".
- Refine list (409-412).
- Phase 4 fill:
  - copy the skeleton (439-443)
  - stamp the version marker from `plugin.json` (450-452)
  - "replace the bracketed guidance with just the chosen bullet, keeping the intro paragraph above it" (461-471)
- Idempotency (673-727):
  - the version comparison (680-688)
  - the 1.1.0 Branch convention bullet (696-700)
  - the Delivery and Reader bullet (708-716), labelled "added in tce 1.3.0", inserted after `## Branch convention`: "an absent section behaves exactly like its default"
  - every-re-run allowlist bullets (717-723)
  - 1.4.3 (724-727)
- The sanctioned per-item CLAUDE.md edit is Phase 4 step 5b (571-575): "show a concrete proposal … and apply only the edits the user approves — free-form approval per edit … Never touch content you can't attribute to the template." The `thoughts/` rules edit (534-539) reuses that pattern.

**`commands/refresh.md` names the sections as hand-authored at four sites:**

- Scope (32-35)
- end of Phase 1 (93-94)
- Phase 2 classification (109-112)
- Phase 3 (137-138)

It does no `thoughts/` analysis: "**Never touch anything under `thoughts/`**" (160). Its one dialog site is Phase 3's batched section approvals (133-138).

**`plugins/tce/README.md`:**

- config tree (175)
- allowlist (335-345, 357-361)
- headless note (347-361)
- "How project parameterization works": Branch 406-419, Delivery 420-428, Reader 429-433
- Planning described as answering "in a dialog" (288)

**Declined lists and standing rules:** no file in `plugins/tce` mentions a declined list, standing rules, or "never offer again". The nearest mechanisms:

- The free-form `## Conventions`, read by the codebase agents, `review.md:21-22` and `discuss.md:22`.
- The allowlist's recomputed "missing entries" check. Nothing records a "Skip".

**`scripts/work.sh preflight`:**

- `profile_state` compares the profile's line-1 marker with `plugin.json` (55-91). It prints `ok` or `older <pv> <vv>`.
- When older, it prints a fixed three-line bold warning (124-130). The warning is not tied to any section. Any profile older than the plugin warns, so a project on 1.7.1 warns after a version bump whether or not it has `## Presentation`.

### 7. Agents: frontmatter, CLAUDE.md, built-in agents

| Agent | Tools | Model |
|---|---|---|
| researcher, planner, implementer, verifier | all, with `disallowedTools: AskUserQuestion` | inherit |
| plan-challenger, plan-compliance-checker, thoughts-analyzer | exactly `Read, Grep, Glob, LS` | inherit |
| codebase-analyzer, codebase-pattern-finder | add `LSP` | inherit |
| codebase-locator | `LSP, Grep, Glob, LS` | haiku |
| thoughts-locator | `Grep, Glob, LS` | haiku |

- No tce file contains `omitClaudeMd`.
- No tce file dispatches the built-in Explore or Plan agent. The one "Plan" hit is the AskUserQuestion header at `work-loop.md:240`.
- The planner may spawn "one targeted sub-task" without naming a type (`planner.md:69-71`).
- The discussion records that subagents receive the CLAUDE.md hierarchy except the built-in Explore/Plan agents and `omitClaudeMd` agents ([sub-agents](https://code.claude.com/docs/en/sub-agents.md)).

**How a `mode:` is declared in an agent:**

- One bullet in "What you receive": planner 44, implementer 44, verifier 46-48.
- Mode-only fields are tagged "on `<mode>`".
- Each mode gets its own `## Process — mode: …` or `### mode: …` section.
- `work-dispatch.md` lists one payload bullet per agent and mode.

### 8. Standing-rule mining material in `thoughts/`

**Inventory:**

- All 7 intents carry `## Decisions`.
- 9 plans carry it at level 2: TP-0004, TP-0008, TP-0045a, b, c, d, e, f, g. Two more have `###` variants: TP-0011 and TP-0034c.
- Heading variants: `## Decisions`, `## Decisions (from the TP-0004 question checkpoint)`, `## Decisions (from the question checkpoint)`, `## Decisions (resolved with the user, 2026-10-11)`.
- `^## Decisions` also hits inside a fenced template skeleton in the TP-0045a plan (about :255), a false positive. This is the same fence lesson `stage.sh` encodes.

**Line shapes:**

- Intents follow `- **…** — over …: …`, hard-wrapped, with no markers.
- Plans 0045c to 0045g end lines with `*(yours)*` / `*(decided for you)*`, with variants:
  - a marker alone on a continuation line (0045f)
  - a missing `: why` (0045f :159, 0045g :86)
  - ", since …" (0045e :137)
- Plan 0045b uses prose sub-headers and "That beats X.".
- 0045a uses non-bold bullets after a prose divider.
- 0004 and 0008 are numbered lists.

**Double counting:** for every ticket with both documents, the intent's decisions reappear as the plan's leading `*(yours)*` lines (22 duplicated lines across 0045c, d, e, f, g). The plan's `*(decided for you)*` lines reappear in the dossier (0045g plan :87-92 → dossier :23-28).

**Decision lines per file:**

- intents: 0045c 7, e 3, f 5, d 5, g 2, h 8
- plans: 0004 4, 0008 3, 0045a 10, b 20, c 26, e 17, f 23, d 22, g 9

**Clusters recurring in 2+ documents (same outcome), as counted by the thoughts-analyzer:**

1. one copy/one site for a mechanism (8 files)
2. reuse an existing contract, no new field/mode/script change (8)
3. ticketless treated like ticket runs (4)
4. version by kind of change: patch for defects, minor for new behaviour (5: 1.5.0, 1.5.1, 1.6.0, 1.7.0, 1.7.1)
5. release phase last (2)
6. no new Idempotency mechanism without a config change (5)
7. never widen the allowlist (4)
8. foreground required, no inline fallback (3)
9. `model: inherit` until cost data (5)
10. don't build what no real run asked for (4)
11. don't rely on undocumented Skill grant scoping (2)
12. verify in a scratch fixture with `--plugin-dir` + `--setting-sources project` (2)
13. stop/escalate instead of improvising a second path (3)
14. output verbatim/byte-identical (3)
15. older artifacts keep working (4)
16. ticket granularity per item (3, mixed outcomes)
17. fix stale text in sentences being rewritten anyway (2)
18. refresh/init lock-step (2)

Several of these are already stated in this repo's CLAUDE.md (e.g. 7, 8, 9, 18).

**Which agents read what:**

- No tce agent reads `## Decisions` sections specifically. `thoughts-locator` finds documents, and `thoughts-analyzer` extracts on request.
- `stage.sh` parses plans for progress headings only. It strips fenced code before matching (CLAUDE.md, TP-0033).
- `dossier-template.md:103` and `verifier.md` count `*(decided for you)*` markers, the only existing mechanical count of decision lines.

## Code References

- `plugins/tce/references/work-loop.md:31-55` — AskUserQuestion block + planner exception
- `plugins/tce/references/work-loop.md:72-76` — invariants 4 and 5 (one-turn reason)
- `plugins/tce/references/work-loop.md:212-251` — Step 6 (questions, challenger, brief print, approval)
- `plugins/tce/references/work-loop.md:314-335` — Step 11 (closeout, prints the dossier text under Direct)
- `plugins/tce/references/work-loop.md:337-359` — Step 12 (second AskUserQuestion site)
- `plugins/tce/references/work-brief.md:34-132` — questions, brief, delta, reader phrasing
- `plugins/tce/references/work-dispatch.md:46-57,76-120,129,141-148` — position table, payloads, challenge bound, resume
- `plugins/tce/references/agent-returns.md:22-109` — statuses, `step:` vocabulary, bounds, retry
- `plugins/tce/agents/planner.md:44,79-172,174-254` — modes and returns
- `plugins/tce/agents/plan-challenger.md:1-6,15-30,41-105` — read-only tools, payload, checklist, return
- `plugins/tce/agents/verifier.md:138-195` — dossier mode
- `plugins/tce/references/dossier-template.md:9-12,41-136` — skeleton, counted-facts line
- `plugins/tce/commands/intent.md:4,52-70,160-192,240-388,415-469` — grants, dialog sites, tracks, writing, autonomous
- `plugins/tce/commands/init.md:146-161,314-401,445-471,571-575,580-652,673-727` — gather, dialogs, fill, CLAUDE.md edit, allowlist, Idempotency
- `plugins/tce/commands/refresh.md:32-35,93-94,109-112,133-138,160` — hand-authored sites, dialog, thoughts boundary
- `plugins/tce/templates/tce/profile.md:70-137` — Branch convention, Delivery, Reader
- `plugins/tce/scripts/work.sh:55-130` — profile version comparison and warning
- `plugins/tce/commands/quickfix.md:66-105` — lane without approval dialog
- `plugins/tce/commands/plan.md:35-45` — lane runs Step 6 with "Approve the plan?"
- `plugins/tce/README.md:288,335-361,406-433` — dialog wording, allowlist, parameterization bullets
- `CLAUDE.md` — "tce: the step commands are orchestrators" (One turn bullet, allowlist bullet), "Agreed profile sections", "The AskUserQuestion guidelines block is duplicated"

## Architecture Documentation

- **Orchestrator plus fresh agents.** Step commands carry a lane; `work-loop.md` is the one loop description; agents return a `tce-return` block that no script parses. Only "exists, non-empty, committed" is checked mechanically (`work.sh artifact`).
- **Human-facing text is authored by the agent that produced the artifact.**
  - The planner returns questions, brief and delta.
  - The verifier writes the dossier.
  - The orchestrator prints them verbatim.
  - The challenger checks brief against plan (item 6).
  - The only fresh-context judge of an artifact for presentation purposes is that item.
- **Turn-scoped grants.** Script grants live in `allowed-tools` and last one turn. The loop keeps the turn by asking through AskUserQuestion. Agents never call shipped scripts.
- **Agreed profile sections.** Absent section = default, enforced by guards at each reader. Lifecycle spans the template, init (dialogs, fill, Idempotency), refresh (four hand-authored sites) and README.
- **Same-commit spans in CLAUDE.md the change touches:**
  - Loop: `work-loop.md`, `work-dispatch.md`, `work-brief.md`, five lanes.
  - Return shape: `agent-returns.md`, the five agents' `## Return`, `work-loop.md`, `work-dispatch.md`.
  - Brief and question layout: `work-brief.md`, `planner.md`, `work-loop.md` Step 6.
  - The AskUserQuestion-block rule (ten copies).
  - Agreed profile sections.
  - The TP-0031 branch span: `intent.md`'s verbatim stop-and-ask dialog is "the one verbatim copy".
  - The init allowlist "never widen" bullet.
  - The dossier counted-facts span (`dossier-template.md`, `verifier.md`, `work-loop.md`).
  - TP-0017: `intent` must stay unflagged.
  - TP-0013: every step agent re-reads in chain order. A new agent consuming the intent joins that rule's list.

## Impact Analysis

### Existing Usages Found

**`plan-challenger` (to gain `mode: brief`):**

- dispatched only from `work-loop.md` Step 6 point 3, with payload `work-dispatch.md:106-108`
- returns `step: challenge`
- its fail lines feed the planner's `mode: challenge-fix` (`planner.md:48-49,156-166`)
- referenced in `commands/quickfix.md:69-73` ("run the challenger rounds")

**`work-brief.md` (to become the presenter's contract):**

- read by `planner.md` (110-114, 150-154, 165-166) and by `work-loop.md` Step 6 point 1
- its question layout feeds AskUserQuestion copy rules (57-61)

**The brief print:**

- `work-loop.md` Step 6 point 4
- quickfix lane (prints the brief and challenger notes)
- `quickfix.md` not-small stop reads the brief's `Phases:` count (78-80)

**The dossier print:** `work-loop.md` Step 11 point 4. Under Pull request the dossier file is the PR body (Step 10), so it stays in full there.

**`answers:` with dialog headers:** `work-dispatch.md:96-98`, `planner.md:45-46`, `work-loop.md` Step 6 point 2.

**The `step:` vocabulary:** `agent-returns.md:44-70`, used by all five agents' Return sections.

### Current Contract

**plan-challenger:**

- input `plan:`, `intent:`, `research:`, `profile:`, `references:`, `brief:` (+ `note:`)
- output: six one-line verdicts and `step: challenge`; status maps all pass → done, human → done with concerns, fail → needs decision
- read-only tools; bounded 3 rounds in the run

**Brief:**

- at most 60 lines
- printed verbatim
- contains `## Phases` with a counts line, which the quickfix not-small stop depends on

**Dossier:** written file plus counted-facts summary line. The text is printed under Direct.

### Adaptation Requirements

These are observed dependencies, not changes.

- `quickfix.md:78-80` reads the brief's `Phases:` count for the not-small stop. A brief without a per-phase section removes that signal unless the count survives elsewhere (e.g. the planner's summary).
- `work-brief.md:57-61` and `work-dispatch.md:96-98` assume dialog headers.
- `agent-returns.md:44-70`'s closed `step:` list and `72-83`'s "No other agent writes anything outside the block except…" sentence name the agents allowed a body.
- `work-loop.md` header (12-13) and contents (16) name the block copy.
- `CLAUDE.md` rule text counts "ten places".

### Backward Compatibility Options

- **Option A: absent `## Presentation` = Full = today's text path**, as with Reader/Delivery guards.
  - Pros: matches the established guard pattern.
  - Cons: the intent's other changes (prose questions, allowlist) are not section-gated, so "byte-identical to 1.7.1" cannot hold for the questions themselves.
- **Option B: question style also gated by the section.**
  - Pros: an un-upgraded project keeps dialogs.
  - Cons: two question mechanisms stay in `work-loop.md`, which the intent's first decision rejects.

## Historical Context (from thoughts/)

- `thoughts/shared/discussions/2026-11-07-tce-show-the-human-only-what-needs-the-human.md`: the source of the intent, with platform facts, decisions 1-7, rejected alternatives and follow-up items.
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md`:
  - "`AskUserQuestion` is removed from every subagent" (:39)
  - command grants don't reach agents (:42)
  - the brief as the planner's return rendered in the terminal (:114-120)
  - "Counted facts, never confidence scores" (:150-151)
  - the terminal table constraint (:175-181)
- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md`:
  - plan approval asked in prose spanned four turns; "prose is often better when a question needs context" (:54-58)
  - no `Understood:`/`Approach:` intro was printed before the questions (:105-106)
  - the sandbox run used bypass permissions, so the allowlist was never exercised (:110-112)
- `thoughts/shared/tickets/TP-0047-communication-style-in-profile.md`: Rejected, superseded by TP-0048 (:77-80). Its criterion said a later-turn answer is re-derived from disk and the grant "renewed by re-invoking `/tce:work`" (:40-43). It also notes the dialog's question text "must be bare" (:16-17).
- `thoughts/shared/research/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md` and `thoughts/shared/dossiers/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md`:
  - single-slash Read rules never matched
  - untrusted folders ignore project allow rules under `claude -p` (research :269-271)
  - the `//` rule matched a subagent read on 2.1.316 with `--settings`; the trusted-folder interactive check is still unticked (dossier :32-33, :42)
- `thoughts/shared/tickets/TP-0001-askuserquestion-copy.md` and its research/plan (2026-06-12): the origin of the guidelines block.
- `thoughts/shared/plans/2026-10-11-TP-0045a-intent-reader-delivery.md`: how the Reader and Delivery sections were introduced (the lifecycle pattern).

## Related Research

- `thoughts/shared/research/2026-10-11-TP-0045a-intent-reader-delivery.md`
- `thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md`
- `thoughts/shared/research/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
- `thoughts/shared/research/2026-10-30-TP-0045d-orchestrator-improvements.md`
- `thoughts/shared/research/2026-11-02-TP-0045g-init-allowlist-absolute-read-path.md`
- `thoughts/shared/research/2026-06-12-TP-0001-askuserquestion-copy.md`
- `thoughts/shared/research/2026-09-09-TP-0033-tce-list-workflow-stage.md` (fence stripping when matching headings)

## Open Questions

1. **Which allow-rule form does `/tce:init` write, for which install type?**
   - The intent's example, `…/.claude/plugins/*/tce/scripts/stage.sh *`, does not match a marketplace install. The version directory sits between `tce` and `scripts`.
   - `…/.claude/plugins/cache/*/tce/*/scripts/stage.sh *` matched on a real `-p` run, quoted and unquoted.
   - A directory-sourced marketplace or `--plugin-dir` (like this repo) runs the scripts from the source path, so it would need the absolute source path instead, the same split `init.md` already makes for the Read entry.
   - Still unverified: the interactive startup warning, and the trusted-folder project-settings path.
2. **Does `/tce:intent` lose AskUserQuestion entirely?**
   - The intent's first decision says "AskUserQuestion out of tce's loop and intent".
   - Its acceptance criterion says the guidelines block exists in exactly **nine** files, which keeps `intent.md`'s copy.
   - `intent.md` has two fixed dialogs: the existing-intent dialog, and the base-branch stop-and-ask dialog, the TP-0031 span's "one verbatim copy".
   - If both become prose, the count drops to eight. Should the existing-intent and base-branch dialogs become prose, or stay dialogs?
3. **Does Step 12's "Have you checked the items above?" dialog also become prose?** The scope names only Step 6. The criterion "`work-loop.md` contains no AskUserQuestion site" requires Step 12 to change too.
4. **What does "a profile without `## Presentation` behaves exactly as tce 1.7.1" cover?**
   - Prose questions and the allowlist are not section-gated in the intent, so questions cannot stay byte-identical while AskUserQuestion leaves the loop.
   - Is the guarantee limited to the presented brief/dossier/intent text (Full = today's print), or should the question style also follow the section?
5. **Does `/tce:quickfix` use the presenter?** It prints the brief without an approval dialog. Its not-small stop reads the brief's `Phases:` count, a per-phase line the Compact brief drops. Where does that count come from under Compact?
6. **What does the presenter return, and what does the challenger's brief check return?**
   - `agent-returns.md`'s `step:` list is closed, and only the planner (plus the challenger's and verifier's findings) may write a body.
   - The presenter needs a `step:` value and permission for a body. Brief-mode findings need a `step:` distinct from `challenge` or a shared one.
   - The status vocabulary (`done` / `needs decision`) covers both.
7. **How should mining count decisions?** Shapes vary (numbered lists, prose dividers, wrapped markers), and intent decisions reappear in plans and dossiers. Should a recurrence count one per ticket, or one per document?

## tce Config Drift (only if found)

- `.claude/tce/profile.md` line 1 carries `<!-- tce-config-version: 1.7.0 -->`, while `plugins/tce/.claude-plugin/plugin.json` and the marketplace entry are `1.7.1`. `work.sh preflight` reports this as `older 1.7.0 1.7.1`. Running `/tce:init` (re-run; the 1.7.1 Idempotency bullet carries no content change) or `/tce:refresh` brings the marker up to date.
