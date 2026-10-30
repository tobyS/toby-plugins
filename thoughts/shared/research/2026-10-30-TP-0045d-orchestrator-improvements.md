---
date: 2026-10-30T11:12:19Z
git_commit: cf5dec5b8b04d63fcdf114404d6c3b34264e8019
branch: main
repository: toby-plugins
topic: "TP-0045d: settling the orchestrator improvements collector"
tags: [research, codebase, tce, work-loop, work-sh, preflight, dossier, verifier, delivery, hooks, subagents]
status: complete
last_updated: 2026-10-30
---

# Research: TP-0045d — settling the orchestrator improvements collector

**Date**: 2026-10-30T11:12:19Z
**Git Commit**: cf5dec5b8b04d63fcdf114404d6c3b34264e8019
**Branch**: main
**Repository**: toby-plugins

## Research Question

The intent `thoughts/shared/intents/2026-10-30-TP-0045d-orchestrator-improvements.md`
routes twelve items (A to L). Its "Questions for research" ask:

1. Can a foreground subagent show anything to the human before it returns, and
   does the orchestrator get a turn while the dispatch runs? (item A)
2. Who edited the pull-request body in the GH-37 run? (item C)
3. Are items E, F and G covered in behaviour as well as in text?
4. How does the verifier's item list get merged in the dossier, so the two counts
   can differ? (item D)
5. How should the profile's version marker be compared with the plugin's, given
   `work.sh preflight` does not read `plugin.json` today? (item B)

## Summary

1. **Item A.** The orchestrator gets no turn: the docs say a foreground subagent
   blocks the main conversation and the parent sees only the final result. So an
   agent cannot send a line up the chain, and nothing the orchestrator would print
   or tail can run meanwhile. Four mechanisms outside the agents exist on paper:
   the terminal's own subagent panel and transcript view, a hook's `systemMessage`
   (a hook is a shell command Claude Code runs on an event; this field is text
   shown to the user), a plugin-shipped `subagentStatusLine` (a script that draws a
   subagent's row in the panel), and a mod (a JavaScript plugin handler that can
   draw in the UI). Each piece is documented. **No source says any of them displays
   during a foreground subagent**, and the one direct report is negative for one
   event. Only an observed run settles it. None of the four touches an agent file.
2. **Item C.** The orchestrator, before posting, not after. In the resumed GH-37
   session it copied the dossier into a scratchpad file, edited four lines there to
   record the human's confirmations and a later fix, and posted that as the body.
   It was following the project's own `tickets.md` "complete" transition, not
   tce's Step 10, which had taken Direct delivery. No body write after creation
   appears in any transcript. A web-UI edit by the human cannot be excluded from
   here (`gh` is denied in this sandbox).
3. **Items E, F, G.** All three are covered in the text, and all three were
   already in the text when the 1.4.2 run missed them. Real runs since: E on 1 of
   5 runs, F on 4 of 6, G on 0 of 7.
4. **Item D.** The merge is not in the dossier. In GH-37 the verifier's own
   `## Verification` list already held two bullets, one naming two criteria; the
   dossier copied two bullets faithfully and counted bullets, while the verifier's
   return counted criteria. The unit of the verifier's count is unspecified, and
   the two files name different sources for the dossier's.
5. **Item B.** No shipped script reads a `plugin.json` or a version today. The
   manifest sits at `$SCRIPT_DIR/../.claude-plugin/plugin.json`, both in the repo
   and in the plugin cache. tce's scripts avoid `jq`. A script's output reaches the
   model, not the human, so the warning's wording lives in `work-loop.md` Step 0,
   where a verbatim-block precedent exists.

## Detailed Findings

### Item A: what can reach the human during a foreground dispatch

Sources were read on 2026-10-30 against installed Claude Code 2.1.314. Labels:
**[D]** documented, **[I]** reported in an issue, **[N]** not stated anywhere read.

**The parent**

- [D] "Foreground subagents block the main conversation until complete. Permission
  prompts are passed through to you as they come up."
  ([sub-agents](https://code.claude.com/docs/en/sub-agents))
- [D] "The parent doesn't see the subagent's intermediate tool calls or outputs,
  only that final result."
  ([tools-reference](https://code.claude.com/docs/en/tools-reference))
- [D] With `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1`, "Claude waits for subagents to
  finish before it continues", and `run_in_background` is removed from Bash and the
  subagent tools. "MCP tasks and the Monitor tool still run in the background."
  ([env-vars](https://code.claude.com/docs/en/env-vars))
- [N] No sentence literally says the parent gets no model request during the run.
  That reading rests on "block" and "only that final result".

**Mechanisms, and what is known about each under foreground dispatch**

| Mechanism | Documented | Reaches | Unknown for a foreground subagent |
|---|---|---|---|
| Terminal subagent panel (`name · description · token count`), Ctrl+O transcript viewer | [D] panel and viewer exist; changelog 2.1.301: "while a long-running subagent works: its progress trail now updates incrementally" | Human | [N] whether a foreground subagent gets a row (docs speak of "a background subagent's row"); [N] whether Ctrl+O shows nested calls during the run. [I] #66646 (v2.1.170): after completion a collapsed `Done (...)` that would not expand |
| Hook `systemMessage` from `PreToolUse`/`PostToolUse` inside a subagent | [D] those hooks fire inside subagents, plugins' too, with `agent_id` and `agent_type` in the input; [D] `systemMessage`: "Warning message shown to the user", with no exception listed for these events | Human, if displayed | [N] whether it displays during the run and in which view. [I] #16289: `SubagentStop` `systemMessage` "never appears" (January 2026, bot-closed). [I] #90662 (v2.1.251, open): some subagent tool calls arrive with a stray `agent_id` and no `agent_type` |
| Plugin `subagentStatusLine` | [D] a plugin may ship it ("Two keys take effect, `agent` and `subagentStatusLine`"); [D] "renders a custom row body for each subagent shown in the agent panel", input includes `tokenCount`, `label`, `status`, `startTime` | Human | [N] whether foreground subagents are "shown in the agent panel"; [N] the tick interval |
| Mod `tool.call` plus `$.ui.status` / `$.ui.log` | [D] `tool.call` fires for "calls a subagent makes"; [D] display calls "show something without starting a turn"; on by default from v2.1.287; absent under `-p`, `--safe-mode`, `disableAllHooks` | Human | [N] no page confirms the combination; the events can change between releases |
| `SubagentStart` exit 2 | [D] "Shows stderr to user only", yet also "the notice appears in the subagent's own transcript" | Unclear | Fires once at start |
| Hook `terminalSequence` (window title, taskbar progress) | [D] for interactive sessions | Terminal chrome | [N] inside subagents |
| Monitor tool, plugin monitors | [D] runs under the variable; reaches Claude, not the human | Model | [N] delivery while the parent is blocked |
| `PushNotification` | [D] a tool the model calls; skipped on recent keyboard activity | Human | [N] availability to subagents; it would be an agent action |
| File the orchestrator tails | Parent is blocked and background Bash is gone | Nothing | — |
| `TaskOutput` | [D] "Removed in v2.1.277" | — | — |
| `--forward-subagent-text` | [D] `-p` with stream-json only | SDK consumer | Not interactive |

Links: [hooks](https://code.claude.com/docs/en/hooks),
[statusline](https://code.claude.com/docs/en/statusline#subagent-status-lines),
[plugins/components](https://code.claude.com/docs/en/plugins/components),
[mods events](https://code.claude.com/docs/en/plugins/mods/events),
[mods api](https://code.claude.com/docs/en/plugins/mods/api),
[changelog](https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md).
Issues: [#16289](https://github.com/anthropics/claude-code/issues/16289),
[#66646](https://github.com/anthropics/claude-code/issues/66646),
[#90662](https://github.com/anthropics/claude-code/issues/90662),
[#1770](https://github.com/anthropics/claude-code/issues/1770) (open request for
parent-child monitoring of Task agents),
[#103157](https://github.com/anthropics/claude-code/issues/103157) (confirms the
variable forces subagents into the foreground, blocking the main agent).

**What the agents would have to do.** The ticket words the item as "agents return
short progress lines". An agent's only channel to the parent is its final message
([`plugins/tce/references/agent-returns.md:44-46`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/agent-returns.md#L44-L46)), so agent-authored lines would need
a new agent action, such as writing a file another mechanism reads. The hook,
status-line and mod mechanisms derive progress from tool calls and leave the agent
files untouched. The intent moves item A to its own ticket if showing progress would
change an agent's contract (`thoughts/shared/intents/2026-10-30-TP-0045d-orchestrator-improvements.md:90-92`).

**What tce ships today in this area.** `plugins/tce/hooks/hooks.json` holds one
`SessionStart` entry. tce has no `settings.json`, and no plugin in this repo uses
`"modules"` or `subagentStatusLine`. A plugin hook fires in every session where the
plugin is enabled, not only during a tce run; the `agent_type` input field is how a
script would tell a tce step agent's tool call from any other. tce's scripts have no
`jq` ([`plugins/tce/scripts/check-init.sh:104`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/check-init.sh#L104), "so no jq dependency is needed"),
while tmt's hooks use it to read their stdin JSON. A `${user_config.*}` value may
only appear in a hook's exec form (CLAUDE.md, "Why per-project config").

**What the transcripts record.** `Bash` calls from subagents are not in the parent's
transcript while running; subagent records live at
`~/.claude/projects/<project>/<session>/subagents/agent-<id>.jsonl`. No run so far
had a hook emitting `systemMessage` from inside a subagent: tmt's hooks emit
`additionalContext` ([`plugins/tmt/scripts/check-ticket-status.sh:100-109`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tmt/scripts/check-ticket-status.sh#L100-L109)), so the
repo holds no evidence either way.

### Item B: the profile's version marker and `work.sh preflight`

**The marker.** Written and compared only by model-followed prose:

- Skeleton `<!-- tce-config-version: FILLED-BY-INIT -->`
  ([`plugins/tce/templates/tce/profile.md:1`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/templates/tce/profile.md#L1)); stamped from the `version` field of
  `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` ([`plugins/tce/commands/init.md:449-451`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/init.md#L449-L451)).
- `/tce:init` compares at [`plugins/tce/commands/init.md:653-659`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/init.md#L653-L659): same version →
  "already up to date"; older or missing → walk-through, update, ask before writing.
  The list's newest entry is 1.4.3 ([`plugins/tce/commands/init.md:661-694`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/init.md#L661-L694)). A marker
  newer than the plugin has no branch in the text.
- `/tce:refresh` also updates it, with no walk-through
  ([`plugins/tce/commands/refresh.md:149-151`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/refresh.md#L149-L151)).
- [`plugins/tce/scripts/check-init.sh:56-60`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/check-init.sh#L56-L60) tests only that `profile.md` exists.

Values a reader can meet: `X.Y.Z`; no comment at all, an explicitly recognised state
([`plugins/tce/commands/init.md:656`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/init.md#L656)); the literal `FILLED-BY-INIT`; and a value newer
than the plugin. Here: line 1 of `.claude/tce/profile.md` says `1.3.0`,
[`plugins/tce/.claude-plugin/plugin.json:3`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/.claude-plugin/plugin.json#L3) and [`.claude-plugin/marketplace.json:15`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/.claude-plugin/marketplace.json#L15)
say `1.6.0`.

**Reading the versions from a script.** No `.sh` under `plugins/` mentions
`plugin.json` or `.claude-plugin`, and none uses `CLAUDE_PLUGIN_ROOT` or a `../` path.
`work.sh` sets `SCRIPT_DIR` ([`plugins/tce/scripts/work.sh:32`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L32)) and sources `lib.sh`,
whose one helper `tce_project_root` gives the project root
([`plugins/tce/scripts/lib.sh:11-13`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/lib.sh#L11-L13)). The manifest is at
`$SCRIPT_DIR/../.claude-plugin/plugin.json`; the plugin cache has the same layout
(checked: `~/.claude/plugins/cache/toby-plugins/tce/1.5.0/.claude-plugin/plugin.json`).
`work.sh` runs under `set -e` ([`plugins/tce/scripts/work.sh:30`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L30)), so a `grep` without
a match stops the script unless guarded.

**Comparing them.** No script parses or compares a version today. The nearest
precedents are the numeric timeout floors ([`plugins/tce/scripts/work.sh:54`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L54),
[`plugins/tsf/scripts/preflight.sh:138-149`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tsf/scripts/preflight.sh#L138-L149)). `sort -V` gives `1.9.0` before `1.10.0`
on this macOS machine; it has no precedent in the repo. See Impact Analysis.

**How the warning reaches the human.** The script's stdout goes to the model. The
only reader of `preflight` is [`plugins/tce/references/work-loop.md:97-98`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L97-L98), which reads
`foreground:` and `timeout:`; nothing consumes `detail:`. On failure the entire reply
is a fixed verbatim block ([`plugins/tce/references/work-loop.md:98-110`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L98-L110)), wording that
TP-0045e measured: its first round fell short (a prose line, a fence), and after
tightening the instruction the output was byte-identical on all 5 step commands
(`thoughts/shared/plans/2026-10-27-TP-0045e-defects-from-stage-2-run.md:462`). On success Step 0 prints nothing, and the first
unconditional line is Step 4's position line
([`plugins/tce/references/work-loop.md:175`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L175)).

**Who runs Step 0.** `/tce:work`, `/tce:research`, `/tce:plan`, `/tce:implement`,
`/tce:quickfix` ([`plugins/tce/references/work-loop.md:355`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L355)). `/tce:quickfix` runs it
explicitly first ([`plugins/tce/commands/quickfix.md:36-37`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/quickfix.md#L36-L37)), then runs the loop "from
its Entry" ([`plugins/tce/commands/quickfix.md:66`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/quickfix.md#L66)), so its text reaches Step 0 twice
in one run. `/tce:intent`, `/tce:review`, `/tce:commit` and `/tce:list` never run it.
All five grant `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/work.sh:*)` in `allowed-tools`
([`plugins/tce/commands/work.md:5`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/work.md#L5)).

**Docs.** [`plugins/tce/README.md:315-328`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/README.md#L315-L328) documents the two variables. The README
does not mention the marker. `work.sh`'s header names only `/tce:work` as the caller
([`plugins/tce/scripts/work.sh:3`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L3), `:9`).

### Item C: the pull-request body in GH-37

All times UTC on 2026-10-14; session `c054a8a7` in
`~/.claude/projects/-Users-toby-code-work-chat-sustainability/`, main session.

- 17:39:04: dossier committed in `ea06599`.
- 17:39: the orchestrator notes delivery is Direct; that `profile.md` had no
  `## Delivery`.
- 17:47:34: the human accepts the checks (Google Docs in place of Word) and asks for
  fixes, which land in `eb3a0ec`.
- 17:49:44: "Now the **complete** transition from `tickets.md`: sync with `main`,
  push, open the PR".
- 17:49:59: `cat pr-head.md <dossier> pr-foot.md > pr-body.md`, in the scratchpad.
- 17:50:03: "The PR body copies the dossier, which still lists the checks and two
  concerns as open. I'm updating those lines in the PR body only; the committed
  dossier stays as written."
- 17:50:05-11: four `Edit` calls on the scratchpad copy.
- 17:50:14: `gh api repos/tobyS/chat-sustainability/pulls -X POST ... -F body=@.../pr-body.md`
  → PR #123.
- 17:50:18: `issues/123 -X PATCH -f "labels[]=ready"`, labels only.

What differed: dossier lines 50 and 51 (`- [ ]` → `- [x] **Confirmed by the owner...`),
lines 55 and 65 (prefixed `**Resolved in eb3a0ec:**`), plus `Closes #37`, a summary
and pointers on top, and a footer. The project's `tickets.md` prescribes the REST POST
and requires `Closes #<n>` in the body. The dossier file never changed after
`ea06599`.

The human did not ask for the edit. Finding 7's "edited after posting" traces to a
summary in session `39083fd5` ("edited after the fact"); the pasted report it
summarised said only "rewritten ... so the PR body differs".

**The same path later.** On 2026-10-29 06:36:00, session `41bd1326` in the same
project ran `gh api .../pulls/132 -X PATCH -F body=@.../pr-body-122.md`, a real edit
after posting on a different pull request, from the main session.

**What tce's own delivery does.** With Pull request delivery, Step 10 runs
`gh pr create ... --body-file <dossier-path>`, or uses an existing pull request's URL
without comparing or re-posting its body
([`plugins/tce/references/work-loop.md:275-280`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L275-L280)). `gh pr edit` appears nowhere in
`plugins/tce/`; only [`plugins/tce/commands/work.md:5`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/work.md#L5) and
[`plugins/tce/commands/quickfix.md:5`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/quickfix.md#L5) grant `gh pr create` and `gh pr view`. The
template says the text "is posted as-is"
([`plugins/tce/references/dossier-template.md:36-37`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/dossier-template.md#L36-L37)). So inside tce's Step 10 the body
equals the dossier at posting.

**After posting.** The order is dossier (Step 9), delivery (Step 10), closeout
(Step 11), human confirmation (Step 12). "All pass" ticks the plan's Manual items and
the Closeout ([`plugins/tce/references/work-loop.md:329-334`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L329-L334)); no step touches the
dossier's `- [ ]` boxes or the body. So under Pull request delivery a body stays equal
to the committed dossier and shows items open after the human confirmed them. That
staleness is what the GH-37 orchestrator worked around. Which of Delivery and the
backend's transition owns delivery is item J, which moves to its own ticket.

**Not determined.** The live body and its edit history: `gh` is denied here
(`open /Users/toby/.config/gh/config.yml: operation not permitted`). A web-UI edit
leaves no transcript trace. To settle it, outside the sandbox, read-only:

```bash
gh api graphql -f query='{repository(owner:"tobyS",name:"chat-sustainability"){pullRequest(number:123){lastEditedAt editor{login} userContentEdits(first:10){nodes{editedAt editor{login}}}}}}'
```

Empty `lastEditedAt` and `userContentEdits` mean nobody edited it after creation.

### Item D: the "for you to check" counts

**The text.**

- Verify mode writes an unnumbered list under the plain label "For you to check:", one
  `- <criterion> — run ...` per item ([`plugins/tce/agents/verifier.md:119-121`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L119-L121)). Nothing
  says one bullet per criterion or forbids grouping.
- The verify return states `For you to check: 0` in its example
  ([`plugins/tce/agents/verifier.md:164-165`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L164-L165)), and each item becomes one `concerns:`
  bullet ([`plugins/tce/agents/verifier.md:185-187`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L185-L187)). The unit of the count is not
  stated, and no filled-in example shows a non-zero value.
- Dossier mode counts "items for you to check from `## Verification`"
  ([`plugins/tce/agents/verifier.md:140-141`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L140-L141)). The template says "the items in
  `## For you to check`", the dossier's own list
  ([`plugins/tce/references/dossier-template.md:104`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/dossier-template.md#L104)).
- No instruction says to copy the items one to one. The only "copied, not composed"
  rule is for "Decided for you"
  ([`plugins/tce/references/dossier-template.md:130-131`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/dossier-template.md#L130-L131)).

**The runs.**

| Run | Verifier's return | `## Verification` list | Dossier |
|---|---|---|---|
| GH-37 (10-14) | `Criteria met 43/46. For you to check: 3 (...)` | 2 bullets: `5. / 37.` and `46.` | `43/46 ... for you to check 2`, 2 bullets: `Criteria 5 / 37`, `Criterion 46` |
| TP-0045f (10-28) | `Criteria met 33/35 ... For you to check: 2.` | 2 bullets: `34.` and `5 / 12 / 35.` | `31/35 ... for you to check 2`, 2 bullets |
| TP-0045c, TP-0045e | `For you to check: 0` | `None.` | `for you to check 0` |

So in GH-37 the verifier counted criteria and the dossier counted bullets, and the
grouping happened in verify mode, one step before the dossier: finding 7's "two items
were merged" happened earlier than the finding implies. In TP-0045f the verifier
counted bullets, so its count agreed with the dossier's, while its `33/35` disagreed
with the dossier's `31/35`, because two bullets grouped four criteria. The Closeout
there records `33/35` from the verify summary ([`plugins/tce/references/work-loop.md:302`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L302)).
The return's unit therefore varied across runs.

**Who reads the counts.** The counted-facts line is the dossier return's first summary
line ([`plugins/tce/agents/verifier.md:190-191`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L190-L191)), printed at Step 11 under Pull request
([`plugins/tce/references/work-loop.md:314-315`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L314-L315)). The position table does not read the
list ([`plugins/tce/references/work-dispatch.md:37-40`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-dispatch.md#L37-L40)). Step 12 restates pending items
"from the plan's `## Verification`" ([`plugins/tce/references/work-loop.md:321-322`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L321-L322)).
The dossier's counted-facts line and filename are a same-commit span:
`dossier-template.md`, `verifier.md`, `work-loop.md`
([`plugins/tce/references/dossier-template.md:9-12`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/dossier-template.md#L9-L12)).

### Items E, F and G: text versus behaviour

**Text history.** E and G landed in `c8bfbb7` (2026-10-13, first tagged v1.4.0) in
`commands/work.md`; `7d1d59e` (2026-10-17, v1.5.0) moved them unchanged to
`work-loop.md`. F's `answers:` line is also `c8bfbb7`, and its 12-character rule
`273910f` (2026-10-13, v1.4.0). All three were in the text under 1.4.2, when the
misses occurred.

**Coverage today.**

- **E:** "`artifact:` names a path → run `work.sh artifact <path>`"
  ([`plugins/tce/references/work-loop.md:186-188`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L186-L188)), under "Every return". Step 6 point 3
  does not restate it ([`plugins/tce/references/work-loop.md:212-215`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L212-L215)). The planner names
  the plan's path on `challenge-fix` ([`plugins/tce/agents/planner.md:248`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/planner.md#L248)); all 11 such
  returns did, so the trigger was always present.
- **F:** `answers:` carries "each question's header and the human's answer, verbatim"
  ([`plugins/tce/references/work-dispatch.md:96-97`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-dispatch.md#L96-L97)); `Header: [max 12 characters]`
  ([`plugins/tce/references/work-brief.md:46`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-brief.md#L46)); "Headers ≤12 characters"
  ([`plugins/tce/references/work-loop.md:45`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L45)). `plugins/tce/agents/planner.md` does not
  mention the length itself. Neither file says whether "each question's header" means
  the planner's or the dialog's, and [`plugins/tce/references/work-loop.md:203-205`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L203-L205)
  requires only the options to be "exactly as returned".
- **G:** "print its `Understood:` and `Approach:` lines as the intro"
  ([`plugins/tce/references/work-loop.md:203`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L203)), and
  [`plugins/tce/references/work-brief.md:57-60`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-brief.md#L57-L60).

**Behaviour.** All sessions under `~/.claude/projects/` with a top-level `tce:planner`
dispatch: 7 real, 8 scratch. Versions are inferred from `plugin.json` at the run's time.

| Item | Session (project, date, version) | Observed |
|---|---|---|
| E | `c054a8a7` (chat-sustainability, 10-14, 1.4.2) | no check |
| E | `6a810615` (toby-plugins, 10-17, 1.4.3) | no check |
| E | `2b157c1c` (chat-sustainability, 10-27, 1.5.0) | 2 fixes, no check |
| E | `9d113f2e` (toby-plugins, 10-27, 1.5.0) | 2 fixes, no check |
| E | `39ff17da` (toby-plugins, 10-28, 1.5.1) | checked: return 11:14:45, `work.sh artifact` 11:14:47 |
| E | 3 scratch runs without a dialog | 4 of 4 fixes checked |
| F | `c054a8a7` | 8 of 9 match: planner `Footnote pages`, dialog `Footnote pg`, answers `Footnote pages` |
| F | `2b157c1c` | 2 of 4 match: dialog `Disabled`, `A11y`; answers and planner `Disabled help`, `Accessibility` |
| F | `6a810615`, `9d113f2e`, `41bd1326`, `39ff17da` | all match; `Ticket policy` and `Intent branch` (13 characters) passed to the dialog unshortened |
| G | `fc6359bb`, `c054a8a7`, `6a810615`, `2b157c1c`, `9d113f2e`, `41bd1326`, `39ff17da` | no intro: no text block between the planner's return and AskUserQuestion |
| G | 3 scratch runs without a dialog | intro printed, questions in prose |

Rollup: E on 1 of 5 real runs (1 of 7 fixes). F verbatim on 4 of 6 real runs, and both
mismatches are the orchestrator shortening an over-long planner header for the dialog
and sending the original in `answers:`; the planner exceeded 12 characters on 4 of the
6. G on 0 of 7 real dialog runs; every planner return carried both lines. The
`39ff17da` G result and the verifier returns above were re-checked directly against
the transcript.

Limits: the transcripts record what was written, not what the terminal rendered; the
scratch runs may not be comparable (how they were launched was not established); and
`6a810615` fell between tags during TP-0045c's work.

### Items H to L: anchors for the stubs

- **H:** design check at [`plugins/tce/agents/planner.md:99-107`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/planner.md#L99-L107) and
  [`plugins/tce/references/work-loop.md:165-167`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L165-L167), `:206-208`. Finding 1 of
  `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md`.
- **I:** concerns kept in the orchestrator only
  ([`plugins/tce/references/work-loop.md:191`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L191), [`plugins/tce/references/work-dispatch.md:166-167`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-dispatch.md#L166-L167)).
  Finding 6. Observed in addition: the verifier's `## Concerns` also takes phase logs'
  `**Issues**` lines ([`plugins/tce/agents/verifier.md:147-148`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L147-L148)).
- **J:** Step 10's two branches ([`plugins/tce/references/work-loop.md:272-284`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L272-L284)) and the
  permalink rule ([`plugins/tce/references/dossier-template.md:108-111`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/dossier-template.md#L108-L111)). Findings 4 and
  5. The GH-37 evidence under item C applies.
- **K:** [`CLAUDE.md:460-462`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/CLAUDE.md#L460-L462) ("pins (the TP-0029 policy) wait for cost data from real
  runs (TP-0045d)") is the only `TP-0045d` mention under `CLAUDE.md`, `plugins/` and
  the root `README.md`. The findings' cost section gives the data. Today:
  `model: inherit` on the five step agents; `model: haiku` on
  [`plugins/tce/agents/codebase-locator.md:5`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/codebase-locator.md#L5) and [`plugins/tce/agents/thoughts-locator.md:5`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/thoughts-locator.md#L5).
- **L:** dropped; no anchor needed.

**Numbering.** Main tickets run to TP-0048, so the next free number is TP-0049;
`plugins/tmt/scripts/next-ticket.sh` ignores letter suffixes. Sub-tickets of the epic
run to `TP-0045g` (Open). The epic's done check names only a, b, c and d
(`thoughts/shared/tickets/TP-0045-tce-one-session-orchestrator.md:90`).

**The ticket's checklist.** `## Collected items` holds one box, item A
(`thoughts/shared/tickets/TP-0045d-orchestrator-improvements.md:38-42`), and
`## Acceptance Criteria` three (`:46-50`). The other eleven rows exist only in the
intent's table. The intent's exception to "no session writes into a ticket's body"
covers "the checklist items only"
(`thoughts/shared/intents/2026-10-30-TP-0045d-orchestrator-improvements.md:125-128`).

**Release.** [`plugins/tce/.claude-plugin/plugin.json:3`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/.claude-plugin/plugin.json#L3) and
[`.claude-plugin/marketplace.json:15`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/.claude-plugin/marketplace.json#L15) say 1.6.0, tag `tce--v1.6.0` exists. The agent
bumps and runs `claude plugin tag --dry-run ./plugins/tce`; the human creates the tag
(CLAUDE.md, "Releasing").

## Code References

- [`plugins/tce/scripts/work.sh:46-68`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L46-L68) - `preflight`
- [`plugins/tce/scripts/lib.sh:11-13`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/lib.sh#L11-L13) - `tce_project_root`
- [`plugins/tce/references/work-loop.md:97-110`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L97-L110) - Step 0 and its verbatim block
- [`plugins/tce/references/work-loop.md:186-188`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L186-L188) - the artifact check on every return
- [`plugins/tce/references/work-loop.md:203-210`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L203-L210) - Step 6 point 2, intro and answers
- [`plugins/tce/references/work-loop.md:275-284`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L275-L284) - Step 10, Pull request
- [`plugins/tce/references/work-loop.md:297-306`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L297-L306) - the Closeout
- [`plugins/tce/references/work-loop.md:321-334`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L321-L334) - Step 12
- [`plugins/tce/references/work-dispatch.md:96-97`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-dispatch.md#L96-L97) - the `answers:` payload
- [`plugins/tce/references/work-brief.md:42-60`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-brief.md#L42-L60) - question layout and intro
- [`plugins/tce/references/dossier-template.md:51`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/dossier-template.md#L51) - counted-facts line
- [`plugins/tce/references/dossier-template.md:104`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/dossier-template.md#L104) - the count of `c`
- [`plugins/tce/agents/verifier.md:119-121`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L119-L121) - the verify-mode list
- [`plugins/tce/agents/verifier.md:137-149`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/verifier.md#L137-L149) - dossier mode's counting and writing
- [`plugins/tce/agents/planner.md:248`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/agents/planner.md#L248) - the return's artifact per mode
- [`plugins/tce/commands/init.md:449-451`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/init.md#L449-L451) - stamping the marker
- [`plugins/tce/commands/init.md:653-659`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/init.md#L653-L659) - comparing the marker
- [`plugins/tce/commands/refresh.md:149-151`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/refresh.md#L149-L151) - refresh's handling of the marker
- [`plugins/tce/hooks/hooks.json:1-16`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/hooks/hooks.json#L1-L16) - tce's only hook
- [`CLAUDE.md:460-462`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/CLAUDE.md#L460-L462) - the pins pointer

## Architecture Documentation

- **Step commands are orchestrators.** Each step runs in a fresh foreground agent; a
  loop change is a `work-loop.md` edit, a step change an agent edit. Five same-commit
  spans apply (CLAUDE.md, "tce: the step commands are orchestrators"). The loop span is
  `work-loop.md`, `work-dispatch.md`, `work-brief.md` and the five lanes; the return
  span is `agent-returns.md`, the five agents' `## Return`, `work-loop.md`,
  `work-dispatch.md`.
- **Mechanical checks.** Only "exists, non-empty, committed" is checked by script;
  returns and documents are read as text ([`plugins/tce/references/agent-returns.md:95-97`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/agent-returns.md#L95-L97)).
- **Scripts run only in the orchestrator.** The `allowed-tools` grant does not reach
  subagents; a hook, by contrast, runs as Claude Code's own process and needs no grant.
- **Project-agnostic plugins.** No stack or ticket-system literals; per-project data
  lives in `.claude/tce/`. Scripts resolve the project through `lib.sh`.
- **Absent-section guards.** A project without a config element behaves
  byte-identically; the intent applies the same to a project with no marker.

## Impact Analysis

### Existing Usages Found

- [`plugins/tce/references/work-loop.md:97-98`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L97-L98) - the only caller of `work.sh preflight`,
  and the only reader; reads `foreground:` and `timeout:` by name.
- [`plugins/tce/commands/work.md:5`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/work.md#L5), `quickfix.md:5`, `research.md:4`, `plan.md:4`,
  `implement.md:4` - grant `work.sh:*`.
- [`plugins/tce/references/work-loop.md:186-188`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L186-L188) - the `artifact` mode's reader.
- No test files exist under `plugins/tce/`. Past plans smoke-tested the script
  directly (`thoughts/shared/plans/2026-10-13-TP-0045b-step-agents-orchestrating-work.md:945-947`).

### Current Contract

- Input: no arguments; reads two environment variables, not the project root.
- Output: exactly three labelled lines, pinned only in the script's header
  ([`plugins/tce/scripts/work.sh:12`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L12)); exit 0 on every outcome, 2 on usage.
- Assumptions: the reply on failure is the fixed block, with "no mention of the
  check's output" ([`plugins/tce/references/work-loop.md:98-102`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L98-L102)).

### Adaptation Requirements

- [`plugins/tce/scripts/work.sh:12`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L12) - the "exactly three lines" statement and the
  `/tce:work`-only wording, if lines are added.
- [`plugins/tce/scripts/work.sh:46-68`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/scripts/work.sh#L46-L68) - `preflight` does not use the project root today;
  `artifact` does, at `:72`.
- [`plugins/tce/references/work-loop.md:97-102`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/references/work-loop.md#L97-L102) - Step 0 prints nothing on success today.
- [`plugins/tce/commands/quickfix.md:36-37`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/commands/quickfix.md#L36-L37), `:66` - Step 0 is reached twice in the text.
- [`CLAUDE.md:429-430`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/CLAUDE.md#L429-L430) - describes what preflight checks.
- [`plugins/tce/README.md:315-328`](https://github.com/tobyS/toby-plugins/blob/cf5dec5b8b04d63fcdf114404d6c3b34264e8019/plugins/tce/README.md#L315-L328) - describes what the commands check.

### Backward Compatibility Options

- Option A: added labelled lines in `preflight`, for example `plugin:` and `profile:`.
  Pros: the reader reads by name, so existing lines keep their meaning. Cons: the header's
  "exactly three lines" changes.
- Option B: a separate `work.sh` mode. Pros: `preflight` unchanged, and the existing
  grant covers it. Cons: a second call at Step 0.
- Comparison, `sort -V`: Pros: one line. Cons: no repo precedent; the `FILLED-BY-INIT`
  literal and other non-versions need a guard first.
- Comparison, splitting on `.` with `-lt`: Pros: the `-ge` precedent, no dependency beyond
  bash. Cons: more lines; needs the same guard.
- Reading `plugin.json`: `grep`/`sed` on the `"version"` line, or `awk` (precedent
  `check-init.sh:105`). `jq` is not a dependency of tce.

## Historical Context (from thoughts/)

- `thoughts/shared/discussions/2026-10-15-tce-work-first-run-findings.md` - the source of
  items B to K. Findings 3 to 7 and the cost section.
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md:39-44` - platform
  facts: AskUserQuestion is removed from subagents; dispatch modes. Untracked in git.
- `thoughts/shared/plans/2026-10-13-TP-0045b-step-agents-orchestrating-work.md:110` -
  progress heads-up lines deferred; `:134-136` all new agents `model: inherit`, cost data
  deferred.
- `thoughts/shared/tickets/TP-0045b-step-agents-orchestrating-work.md:114-115` - the same
  deferral on the ticket.
- `thoughts/shared/tickets/TP-0029-tle-agent-model-pins.md` - the pin precedent for item K.
- `thoughts/shared/tickets/TP-0039-tsf-first-run-corrections.md:74-80` - tsf's link rewrite
  after a merge, for item J.
- `thoughts/shared/tickets/TP-0047-communication-style-in-profile.md:40-43` - loosens the
  AskUserQuestion requirement; out of scope here, and adjacent to item G.
- `thoughts/shared/tickets/TP-0048-intent-and-plan-approval-output.md` - a stub, created
  2026-10-30, about making intent and plan-approval output easier to take in; adjacent to
  item G.

## Related Research

- `thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md` -
  `:532-545` foreground and background behaviour as documented then.
- `thoughts/shared/research/2026-10-17-TP-0045c-single-step-commands-on-agents.md`
- `thoughts/shared/research/2026-10-27-TP-0045e-defects-from-stage-2-run.md`
- `thoughts/shared/research/2026-10-28-TP-0045f-ticketless-branch-and-delivery.md`

## Open Questions

1. **Item A: which mechanism is tried on the real dispatch?** Docs and issues cannot
   settle it; the acceptance criterion requires a real foreground dispatch or recorded
   evidence. Candidates, none touching an agent file: the terminal's own panel, which may
   already show enough and would need nothing built; a `PostToolUse` hook printing
   `systemMessage`, which runs a script on every tool call in every session where tce is
   enabled and has one negative report for a sibling event; a plugin `subagentStatusLine`,
   which takes over the row body for every subagent shown, not only tce's; a mod, the most
   capable and the newest surface, with events that may change between releases. Agent-written
   lines would change an agent's contract and move item A to its own ticket.
2. **Items E, F, G: tick them as the intent says, or move them to Build?** The intent's
   criterion asks for coverage "against the current text", which holds. But the text was
   already there when the run missed them, and real runs since follow it on 1 of 5 (E), 4 of
   6 (F) and 0 of 7 (G). Ticking matches the criterion's letter and closes the collector; the
   behaviour stays as observed. Moving to Build means changing the loop's text, and it sits
   beside TP-0047 and TP-0048 for G. For F, a separate point: should `answers:` carry the
   planner's header or the dialog's when the orchestrator shortens one?
3. **Item C: record the reason, or also change what happens after posting?** The criterion
   allows closing it with the recorded reason: the edit came from the orchestrator following a
   project's `tickets.md` transition, outside Step 10, whose posting is already as-is. Left
   open then: under Pull request delivery, a posted body and the committed dossier both still
   show items open after Step 12's confirmation. That concern could stay with item J's ticket
   or be built here. Note that the live edit history of #123 was not checked (command under
   item C).
4. **Item D: does the count mean criteria or list bullets, and may a bullet group several
   criteria?** Criteria keeps `Criteria met n/m` and the check count arithmetically consistent
   (GH-37: 46 − 43 = 3), but a bullet for one action can cover several criteria (TP-0045f's
   tag: 3). Bullets match what the human actually does. Settling it touches the wording of
   verify mode's list and return in `verifier.md`, not a field or status. Does that count as "an
   agent's contract", which the intent forbids changing? If it does, what remains for this ticket
   is the dossier template's wording alone.
5. **Stubs H, I, J, K: main tickets TP-0049 to TP-0052, or sub-tickets TP-0045h onward?** Main
   tickets leave the epic's done check as it is, and it names only a to d. Sub-tickets keep them
   under the epic's heading but raise whether the epic waits for them, as `TP-0045g` already does.
6. **Where is each routing row's final outcome recorded?** The ticket's checklist has one box
   for item A and the exception covers only checklist items, so the other rows cannot be written
   there. The plan's closeout and the dossier are the existing places for it.
