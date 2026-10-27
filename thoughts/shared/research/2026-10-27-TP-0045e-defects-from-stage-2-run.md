---
date: 2026-10-27T09:37:27Z
git_commit: 4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988
branch: main
repository: toby-plugins
topic: "TP-0045e: defects found in the stage-2 verification run"
tags: [research, codebase, tce, intent, quickfix, work-loop, work-sh, implementer, commit, allowed-tools, headless]
status: complete
last_updated: 2026-10-27
---

# Research: TP-0045e — defects found in the stage-2 verification run

**Date**: 2026-10-27T09:37:27Z
**Git Commit**: 4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0045c's verifier ran the rewired step commands headless (`claude -p`) and
found four places where a command or agent does not behave as its own text
says. This document traces each one to the text that produces it. The intent
(`thoughts/shared/intents/2026-10-27-TP-0045e-defects-from-stage-2-run.md`)
fixes the scope. Its three research questions are:

1. Can a prompt-level "print verbatim" be made reliable, or must the fixed text
   come from script output?
2. How are `${CLAUDE_PLUGIN_ROOT}` patterns in `allowed-tools` matched after
   substitution, interactively and under `claude -p`?
3. Can the implementer record the log hash without a second commit?

## Summary

- **Defect 1 (autonomous intent prints prose before its line).** `/tce:intent`
  runs inline in `/tce:quickfix`'s own turn. It has no `context: fork`, so the
  "return line" is text that the same model writes into the same conversation.
  `intent.md:398` says the mode must "end with exactly one return line". It does
  not say "print nothing else". `quickfix.md:43-45` matches the two prefixes and
  has no rule for text around them.
- **Defect 2 (preflight refusal paraphrased).** `work-loop.md:92-101` says
  "refuse and stop:" and then a fenced block that contains a `<command>`
  placeholder. The model therefore has to render the block, not copy it, and no
  "verbatim" instruction is attached. `work.sh preflight` prints a `detail:`
  line (`work.sh:59-66`) that differs from the block, and no command or
  reference reads it.
- **Defect 3 (headless grants did not match).** The cause has not been
  established. Every tce grant has the form `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh":*)`,
  with double quotes inside the pattern. Every call has the form
  `"${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh" <args>`.
  - The docs say that `${CLAUDE_PLUGIN_ROOT}` is substituted in `allowed-tools`
    and that `allowed-tools` applies in `-p`. Their examples use unquoted
    patterns.
  - Anthropic's official ralph-loop plugin uses an unquoted pattern with a
    quoted call.
  - Open issue #14956 reports that a pattern containing quotes did not match
    in `-p`.
  - Nothing documents how a pattern with quotes inside it is matched.
  - The TP-0045c run recorded neither the attempted command strings nor the
    CLI grants that worked.
- **Defect 4 (log edit absorbed by the next feature commit).**
  - The implementer writes `**Status**: ✅ Complete` before its first commit.
    It writes the hash into a second, docs-only commit (`implementer.md:128-151`).
  - `stage.sh` counts a phase as done from the `**Status**` line in the working
    tree and never reads `**Commit**` (`stage.sh:154-159`), so after an
    interruption the position moves on to the next phase.
  - The next phase's `tce:commit` stages "the plan" as a whole file
    (`implementer.md:145-147`), and so includes the stray hash edit.
  - A commit cannot contain its own hash, so "log hash written before the phase
    commit" is impossible without amending, and the agent forbids amending
    (`implementer.md:29`).

## Detailed Findings

### The run that surfaced the defects

- Setup, as recorded at `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:860`:
  "headless `claude -p` runs (Claude Code 2.1.301, tce 1.5.0 loaded from this
  repo) in a scratch consuming project … both environment variables exported
  unless stated otherwise".
- Not recorded: the `claude -p` command lines, how the plugin was loaded, the
  values of `--allowedTools` or of other flags, and the project path.
- The dossier says none of the defects was tried interactively
  (`thoughts/shared/dossiers/2026-10-17-TP-0045c-single-step-commands-on-agents.md:55`).
- The four concerns are recorded at dossier `:56-59`. Evidence lines are at
  plan `:914` (autonomous intent), `:924` (interruption) and `:926` (preflight).

### 1. Autonomous `/tce:intent` and quickfix's hand-off

- **`intent.md` frontmatter** (`plugins/tce/commands/intent.md:1-5`): no
  `context:` or `disable-model-invocation` key.
  - Invoked through the Skill tool, its body loads into the caller's context
    and runs in the caller's turn.
  - Its `allowed-tools` grants only `stage.sh` and `branch.sh`.
- **The mode's contract** (`intent.md:394-430`):
  - `:396-400`: "Ask nothing, print no draft, and end with exactly one return
    line to the caller — `intent: <path>` on success, `insufficient: …` on
    failure. Nothing else is written on failure."
  - Step 1 (`:402-405`) and step 2 (`:406-410`) define the `insufficient:`
    returns. Step 2's form is `insufficient: <scope | outcome | anchor> — <what
    is missing, one line>`.
  - Step 6 (`:429-430`): "Return `intent: <path>`. No hand-off message — the
    caller drives the rest."
- **The caller** (`plugins/tce/commands/quickfix.md:37-45`, section "2.
  Intent"): "Invoke the `tce:intent` skill through the Skill tool with
  `--autonomous` followed by the description, verbatim. It writes and commits a
  ticketless intent and returns one line:"
  - `intent: <path>` → continue.
  - `insufficient: <line>` → stop with "Not enough to go on: <line>. Re-run
    `/tce:quickfix` with that added, or use `/tce:intent` for a dialogue."
  - Nothing says what happens if other text surrounds the line, or if neither
    prefix appears.
- **Observed** (plan `:914`):
  - `/tce:intent --autonomous make it better` returned
    `insufficient: scope — "make it better" doesn't say what should change or where…`
    and wrote nothing.
  - A second run returned `insufficient: anchor — …`.
  - The dossier (`:57`) records that the model printed prose before the line.
    The prose itself is not quoted, and it is not recorded which run printed
    it.
- **The same pattern elsewhere in tce:** the step agents' returns are read by
  locating a fenced `tce-return` block. Text before the block is allowed and,
  for the planner, required (`plugins/tce/references/agent-returns.md:44-46`,
  `:72-83`). A missing block gets one retry with a fixed note (`:99-109`). That
  rule governs agent returns only; the intent hand-off is a Skill, not an
  agent, and has no equivalent rule.

### 2. The preflight refusal

- **Step 0** (`plugins/tce/references/work-loop.md:90-101`): run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/work.sh" preflight`. "Unless both
  `foreground:` and `timeout:` say `ok`, refuse and stop:", followed by a
  fenced block:
  - line 1: `<command> needs foreground agents and a long Bash timeout. Quit Claude Code,`
  - then `then start it again with:`, a blank line, and the two indented
    `export` lines.
  - The block contains a placeholder (`<command>`) that the running model has
    to substitute. The step uses no word such as "verbatim" or "exactly".
- **The script** (`plugins/tce/scripts/work.sh:46-68`) prints three lines. On
  failure, `detail:` reads "start Claude Code with
  CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 and BASH_DEFAULT_TIMEOUT_MS=600000
  exported" (`:62`).
  - That text is not the Step 0 block. The script takes no argument, so it
    does not know the command name.
  - No tce command or reference reads `work.sh`'s `detail:`. The `detail:`
    lines that are relayed come from `branch.sh` (`work-loop.md:123`,
    `review.md:126`, `commit.md:66`, `intent.md:133`).
- **Who runs Step 0:** every step command, through `work-loop.md`'s "Steps 0–4
  run in every lane" (`work-loop.md:324`). `quickfix.md:34-35` runs Step 0
  explicitly before it writes the intent.
- **Observed** (plan `:926`, `/tce:plan FAKE-0001` with
  `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` unset): the output began "The check
  reported `foreground: missing` …", carried the export lines, and ended
  "Then run `/tce:plan FAKE-0001` again". Nothing was written.
- **Precedent in tsf:** `plugins/tsf/scripts/preflight.sh` prints `result:` and
  a `detail:` that joins each failure's own fix text (`preflight.sh:191-197`).
  `/tsf:cycle` Step 1 carries that `detail:` line into its report
  (`plugins/tsf/commands/cycle.md:62-72`; `plugins/tsf/references/cycle-report.md:63`
  renders the Preflight line as "`ok`, or the preflight's `detail:` line"). The
  text that reaches the user is the script's output line, placed in a template
  slot.
- **Platform mechanisms for fixed text** (web research, links below):
  - Anthropic's consistency guidance (specify the format, give examples, chain
    prompts) makes no guarantee of verbatim reproduction. Prefill is
    unsupported on Claude 4.6 and later.
  - A command or skill can contain `` !`<command>` `` (or a ```` ```! ````
    fence): the command runs before the skill content is sent to the model,
    and its output replaces the placeholder. Anthropic's ralph-loop plugin
    command uses it.
  - The output lands in the model's prompt, not on the user's screen, so the
    model still has to repeat it.
  - A failed `!` command aborts the whole invocation.
  - `!` commands never prompt: a permission check that does not return allow
    aborts the invocation outside auto mode.
  - `disableSkillShellExecution` turns `!` off.
  - Not verified: whether `!` runs when the skill is invoked through the Skill
    tool rather than typed by the user.

### 3. `allowed-tools` script grants under `claude -p`

**What tce ships (all quoted, at commit 4c7fe29):**

| File | Grant form | Scripts |
|---|---|---|
| `commands/research.md:4` | `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/<n>.sh":*)` | ticket, stage, branch, work |
| `commands/plan.md:4` | same | ticket, stage, branch, work |
| `commands/implement.md:4` | same, + `Bash(git rev-parse:*)`, `Bash(git log:*)` | ticket, stage, branch, baseline, work |
| `commands/quickfix.md:5` | same, + git rev-parse/log | ticket, stage, baseline, work |
| `commands/work.md:5` | same, + git rev-parse/log, `git push`, `gh pr create`, `gh pr view` | ticket, stage, branch, baseline, work |
| `commands/intent.md:4` | same | stage, branch |
| `commands/commit.md:3`, `review.md:5`, `list.md:4` | same | branch / ticket+branch / stage |

- Every call site in prose quotes the path. Examples: `work-loop.md:92`,
  `:118`, `:127-128`, `:156`, `:207`, `:223`; `commit.md:64`; `review.md:122`;
  `intent.md:126`; `list.md:93`.
- tsf uses the same quoted form (`plugins/tsf/commands/cycle.md:4`, `spec.md:5`,
  `init.md:5`). Its factory runs with `--dangerously-skip-permissions`, where
  allow rules are inert (CLAUDE.md, TP-0039 section; `plugins/tsf/README.md:127-168`),
  so no tsf run has tested whether these patterns match.
- tle has no `allowed-tools` and calls no plugin script.

**What the platform documents** (fetched 2026-10-27; see the Web references
below):

- **`allowed-tools` in `-p`:** the grant lasts for the turn that invokes the
  skill. Command files are treated as skills. "Claude Code applies a project
  skill's `allowed-tools` even in a `-p` run in a folder you've never trusted."
  No other difference between `-p` and interactive sessions is documented.
- **What `-p` does with unmatched calls:** from v2.1.302, `-p` without a
  permission mode starts in Manual mode, and calls that need approval are
  denied unless an allow rule, hook, `canUseTool` callback or
  `--permission-prompt-tool` approves them.
  - There is no prompt to fall back to, so a pattern that does not match is a
    denial in `-p`. Interactively the same miss would be a permission prompt.
  - The TP-0045c run used 2.1.301, one release before that note.
- **Substitution:** `${CLAUDE_PLUGIN_ROOT}` is substituted in plugin skill and
  command markdown and in Bash rules in `allowed-tools`. A maintainer confirmed
  this when closing #9354 on 2026-08-17, without naming a fix version.
  - The docs' own example is unquoted:
    `Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)`.
  - The variable is not present in the environment of Bash commands, so it is
    the model that writes the substituted absolute path into the command.
- **Matching:** "Bash rules match the whole command text, with `*` standing in
  for any text" and "match the command text Claude writes, after Claude Code
  splits compound commands and strips wrappers."
  - The docs' table lists `git 'push' origin main` as not matched by
    `Bash(git push *)`, which implies quotes are not stripped before matching.
  - `:*` is equivalent to a trailing ` *`.
  - No text covers a pattern that contains quote characters.
- **Evidence from issues and plugins:**
  - Anthropic's ralph-loop plugin grants
    `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh:*)`, unquoted, and
    runs `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-ralph-loop.sh" $ARGUMENTS`
    through a `!` fence. In #16398 the fix was adding `:*` to that pattern.
  - #14956 (open, `-p`, from v2.0.75; reports through v2.1.92): the pattern
    `Bash(say -v "Samantha":*)` did not approve `say -v "Samantha" "Hello…"`.
  - #67198 (closed as a duplicate of #14956): the grant applied when the user
    typed the command, but not when the model invoked the skill through the
    Skill tool.
- **Undocumented:** whether `allowed-tools` reaches subagents. This repo
  records, as verified on a real dispatch, that it does not (TP-0034a, plan
  `:1512-1519`). That matches CLAUDE.md's "the grant does not reach subagents".

**What the tce README says today** (`plugins/tce/README.md:313-333`):
- the two exports (`:313-326`);
- "Accept the allowlist `/tce:init` offers", because the agents run outside
  the command's grant, and the allowlist "never adds `git push` or `gh`"
  (`:328-333`).

It says nothing about headless runs, `claude -p`, `--allowedTools` or
`--permission-mode`.

**Which calls run where:** scripts run only in the orchestrator. Agents receive
paths and values and never call a `${CLAUDE_PLUGIN_ROOT}` script (CLAUDE.md
"tce: the step commands are orchestrators"). So the grants at issue are the
orchestrating command's own, in the turn it was invoked.

### 4. The implementer's two commits and the resume path

**Write and commit order in `mode: phase`** (`plugins/tce/agents/implementer.md:89-151`):

1. Step 1 (`:108-109`): on a fresh phase 1, append the log block with
   `**Base commit**` now. It stays uncommitted until step 7.
2. Step 6 (`:128-143`): tick the phase's Automated items and write the full log
   block, including `**Status**: ✅ Complete` and a `**Commit**` line whose
   template value is a placeholder (`abc1234`). This happens before any commit.
3. Step 7 (`:145-151`):
   - Invoke `tce:commit`, "staging the phase's files, the plan, and the ticket
     file if its status changed".
   - Then "Put the resulting hash on the log's `**Commit**` line and commit the
     plan once more (a docs-only commit)."

After the first commit, the committed plan already says `✅ Complete`. Only the
hash edit is outstanding.

**Position derivation:**
- `plugins/tce/scripts/stage.sh:166` runs awk over the plan path in the working
  tree. No git command appears in the script.
- Inside an `### Implementation log`, the first `**Status**` line counts the
  phase as done if it starts with `✅` or `Complete` (`:154-159`).
- `**Commit**` is never examined.
- `work-dispatch.md`'s position table: row 7, `k/N` with `k < N`, leads to
  implement (`plugins/tce/references/work-dispatch.md:53-54`). No row consults
  `git status`.

**Return handling in an uninterrupted run:**
- `work-loop.md:155-157` runs `work.sh artifact <plan>` on every return that
  names an artifact.
- `committed: yes` needs the path tracked and `git status --porcelain -- <path>`
  empty (`work.sh:78-80`).
- So a plan with an uncommitted edit fails the check and the loop calls it
  `blocked`. The second commit is what makes a normal return pass.
- Step 7 continues "only when `progress:` moved" (`work-loop.md:211-214`).

**`tce:commit`'s scope** (`plugins/tce/commands/commit.md`):
- It says "Commit all changes from the current chat session to Git" (`:8`) and
  has no explicit staging step. Item e) reviews `git status` / `git diff
  --staged` for unintended files (`:45-48`).
- Docs-only commits skip tests, typecheck and lint (`:26-29`).
- Nothing in it addresses uncommitted edits left by an earlier session.
- When the implementer calls it, the implementer names the files, and "the
  plan" is a whole file.

**Re-dispatch of a phase already `✅ Complete`:** "change nothing and return
`done` with the logged commit" (`implementer.md:101-102`). Nothing is
committed on that path.

**Git fact relevant to research question 3:** a commit's hash is computed from
its content, tree and parent. So a file cannot record the hash of the commit
that contains it.
- One commit can carry the phase and its log only if the log names something
  other than that commit's own hash: the subject line, for example, or the
  parent (`HEAD` before committing).
- Otherwise the commit has to be amended, which `implementer.md:29` forbids
  ("never amend"), or a second commit carries the hash, which is today's
  sequence.

## Defect Mechanism

### Defect 1 — prose before the autonomous return line

- **Intended:** in autonomous mode the output is exactly one line, `intent:
  <path>` or `insufficient: …`, with nothing else (ticket item 1; intent
  criterion 1). quickfix acts on that line by an explicit rule, not by luck
  (intent criterion 2).
- **Actual:** an insufficient description produced explanatory prose and then
  the `insufficient:` line (dossier `:57`).
- **Divergence:**
  1. `intent.md:398` asks the model to "end with exactly one return line". That
     constrains the end of the output, not what comes before it, and the
     section has no "print nothing else" clause for the failure path. Its
     "Nothing else is written" (`:399-400`) refers to files.
  2. Because `intent.md` carries no `context: fork` (`:1-5`), the Skill call
     runs in quickfix's turn. The "return" is the same model's chat text, with
     no boundary that keeps commentary out of it.
  3. `quickfix.md:43-45` describes the result as "returns one line" and
     branches on the two prefixes. It has no rule for locating the line among
     other text, or for output carrying neither prefix.
- **Propagation:** whether quickfix finds the line depends on the model reading
  its own preceding prose correctly. In the observed run it did: the plan
  records the `insufficient:` evidence and a clean `git status`. The ticket
  calls the hand-off "fragile".

### Defect 2 — paraphrased preflight refusal

- **Intended:** with either variable missing, the user sees the Step 0 block
  byte for byte (ticket item 2; intent criterion 3, decision "a fixed message
  counts only if it reaches the user verbatim").
- **Actual:** the model wrote its own message. It quoted the script result
  ("The check reported `foreground: missing` …"), included the export lines,
  and added a re-run line (plan `:926`).
- **Divergence:**
  1. `work-loop.md:92-93` introduces the block with "refuse and stop:" and no
     verbatim instruction.
  2. The block's `<command>` placeholder (`:96`) means the text is a template
     the model must fill, so it is composing output in any case.
  3. The script's own `detail:` (`work.sh:62`) is different text that nobody
     relays, so no fixed string from a deterministic source reaches the model
     at the moment it writes the refusal.
- **Propagation:** the model, holding the three script lines and a template,
  writes a natural-language refusal. The export lines survived; the block's
  exact wording and layout did not.

### Defect 3 — grants not applied to the absolute-path call under `claude -p`

- **Intended:** a step command's `allowed-tools` pre-approves its own script
  calls for the turn, so the loop runs without prompts (`work-loop.md:69-70`,
  invariant 5; CLAUDE.md "One turn, kept by AskUserQuestion").
- **Actual:** under `claude -p` (2.1.301) the substituted absolute-path calls
  were not approved, and the grants had to be passed on the CLI (dossier
  `:56`).
- **Divergence: not established.** Candidates the evidence leaves open, listed
  without ranking:
  - (a) A pattern containing literal `"` characters does not match the command
    text the model writes. The model may write the path quoted or unquoted, and
    the matcher may or may not normalize quotes. Issue #14956 is the closest
    report.
  - (b) The way `/tce:plan` etc. reached the model in the `-p` run (typed in
    the prompt string, or invoked by the model through the Skill tool, see
    #67198) affected whether the grant applied.
  - (c) A `-p`-specific behaviour of 2.1.301.

  The TP-0045c records lack the data to choose between them: the denied command
  strings and the working `--allowedTools` values. Whether the same miss
  happens interactively is unknown, since there it would show as a prompt, not
  a denial.

### Defect 4 — log edit absorbed by the next feature commit

- **Intended:** an interruption between the phase commit and the log commit
  leaves nothing uncommitted, or a stray log edit that the next dispatch
  commits on its own, never inside a feature commit (ticket item 4; intent
  criterion 5).
- **Actual:** `/tce:implement FAKE-0001` was killed with `stage.sh` at `1/2`.
  Phase 1's commit `98022d7` existed and the plan's log edit was uncommitted.
  The re-run continued at phase 2 and produced `73a7f2e` (plan `:924`). The
  dossier records that the next phase's feature commit absorbed the edit
  (`:59`).
- **Divergence:**
  1. `implementer.md:128-150` puts `✅ Complete` into the first commit and the
     hash into a second one. An interruption between them leaves only the hash
     edit in the working tree.
  2. `stage.sh:154-159` reports the phase as done from the working tree's
     `**Status**` line, so the position table sends the re-run to phase `k+1`
     (`work-dispatch.md:53-54`). Neither the position nor the payload signals
     the dirty plan (`work-dispatch.md:108-112`).
  3. The phase-`k+1` implementer stages "the plan" as a whole file in its
     feature commit (`implementer.md:145-147`), and the earlier phase's hash
     edit goes with it.

  The `work.sh artifact` committed check (`work.sh:78-80`) would have caught
  the dirty plan only on the interrupted agent's own return, which never
  happened.

## Code References

Permalinks at commit 4c7fe29 (on `main`, not yet pushed when written):

- [`plugins/tce/commands/intent.md:1-5`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/commands/intent.md#L1-L5) — frontmatter (no `context:`), grants stage/branch
- [`plugins/tce/commands/intent.md:394-430`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/commands/intent.md#L394-L430) — `## Autonomous mode`, the one-line return contract
- [`plugins/tce/commands/quickfix.md:32-45`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/commands/quickfix.md#L32-L45) — preflight, then the Skill call and the two-prefix branch
- [`plugins/tce/references/work-loop.md:90-101`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/references/work-loop.md#L90-L101) — Step 0 and the fixed block
- [`plugins/tce/references/work-loop.md:149-160`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/references/work-loop.md#L149-L160) — return handling, `work.sh artifact`
- [`plugins/tce/references/work-loop.md:203-214`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/references/work-loop.md#L203-L214) — Step 7, per-phase dispatch
- [`plugins/tce/scripts/work.sh:46-68`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/scripts/work.sh#L46-L68) — `preflight`, three-line output, `detail:` text
- [`plugins/tce/scripts/work.sh:70-87`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/scripts/work.sh#L70-L87) — `artifact`, the committed check
- [`plugins/tce/scripts/stage.sh:146-166`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/scripts/stage.sh#L146-L166) — log/Status counting over the working tree
- [`plugins/tce/references/work-dispatch.md:23-67`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/references/work-dispatch.md#L23-L67) — position table (row 7 at `:53-54`)
- [`plugins/tce/references/work-dispatch.md:108-112`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/references/work-dispatch.md#L108-L112) — implementer phase payload
- [`plugins/tce/agents/implementer.md:89-151`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/agents/implementer.md#L89-L151) — phase-mode write and commit order; log format at `:133-143`; "never amend" at `:29`
- [`plugins/tce/commands/commit.md:8`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/commands/commit.md#L8) — scope "current chat session"; items a) `:26-29`, e) `:45-48`
- [`plugins/tce/references/agent-returns.md:93-109`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/references/agent-returns.md#L93-L109) — block parsing rule and verbatim retry note
- [`plugins/tce/README.md:313-333`](https://github.com/tobyS/toby-plugins/blob/4c7fe29d5f1f4f0e4a172ce86fdbbb7447998988/plugins/tce/README.md#L313-L333) — exports and allowlist; no headless note
- `plugins/tce/commands/{research,plan,implement,quickfix,work}.md` line 4/5 — the quoted `allowed-tools` grants (table above)
- `plugins/tsf/scripts/preflight.sh:191-197`, `plugins/tsf/commands/cycle.md:62-72`, `plugins/tsf/references/cycle-report.md:63` — tsf's script-sourced refusal text
- `plugins/tce/.claude-plugin/plugin.json:3` and `.claude-plugin/marketplace.json:15` — tce at `1.5.0`; tags `tce--v1.0.0` … `tce--v1.5.0` exist

## Architecture Documentation

- **Skill versus agent hand-off.**
  - Agents (researcher, planner, …) end with a fenced `tce-return` block that
    the orchestrator locates in the text, with one fixed-note retry
    (`agent-returns.md`).
  - The autonomous intent is a Skill call, not an agent. It returns a bare line
    in the caller's own turn, and quickfix is `/tce:intent`'s only Skill edge
    (CLAUDE.md TP-0017).
- **Scripts print, commands relay.** tce scripts use a fixed-line stdout
  contract with `detail:` lines that commands relay (`branch.sh`,
  `baseline.sh`). `work.sh preflight` follows the shape, but its `detail:` is
  the one that is not relayed.
- **Position is on disk.** `stage.sh` derives position from the working-tree
  plan, never from git. The only git-state check in the loop is `work.sh
  artifact`'s `committed:` line, applied to an artifact a return names.
- **Same-commit spans touched by these defects (CLAUDE.md):**
  - Loop span: `work-loop.md`, `work-dispatch.md`, `work-brief.md` and the
    five lanes.
  - Return-shape span, if a return changes.
  - TP-0017 classification (`intent` must stay unflagged).
  - "Only exists, non-empty, committed is checked mechanically" (`work.sh
    artifact`).
  - The implementation-log format is owned by `implementer.md`
    (`plan-document-template.md:185-196`); `stage.sh` parses its `**Status**`
    line (TP-0033 rule: change `stage.sh`'s derivation and you update
    `list.md`).
  - CLAUDE.md forbids widening `/tce:init`'s allowlist, and the intent rules
    it out as a workaround.

## Historical Context (from thoughts/)

- `thoughts/shared/dossiers/2026-10-17-TP-0045c-single-step-commands-on-agents.md:55-60` — the four concerns, and the note that the run was headless only
- `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:860`, `:914`, `:924`, `:926` — run setup and evidence
- `thoughts/shared/plans/2026-10-17-TP-0045c-single-step-commands-on-agents.md:60-62` — "an `allowed-tools` grant lasts one turn and does not reach subagents"
- `thoughts/shared/dossiers/2026-10-17-TP-0045c-single-step-commands-on-agents.md:33` — autonomous intent uses Glob instead of `ticket.sh`, because a skill's `allowed-tools` reaching its caller's turn is undocumented
- `thoughts/shared/discussions/2026-10-09-tce-one-session-orchestrator.md:32`, `:42` — platform facts verified on 2.1.290: a command's `allowed-tools` does not reach its agents
- `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md:1512-1519` — real-dispatch finding that a frontmatter grant does not reach subagents
- `thoughts/shared/plans/2026-09-27-TP-0039-tsf-first-run-corrections.md:812-815` — allow rules are inert under bypass, deny rules always apply
- `thoughts/shared/research/2026-06-16-TP-0009-implement-intermediate-commits.md` — origin of the per-phase commit discipline

## Related Research

- `thoughts/shared/research/2026-10-11-TP-0045b-step-agents-orchestrating-work.md` — step agents, the allowlist (`:494-497`), grant scope (`:579-580`)
- `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md` — base and phase commit hashes in the log

## Web references

- https://code.claude.com/docs/en/skills — `allowed-tools` per-turn scope; applies in `-p`; `${CLAUDE_PLUGIN_ROOT}` substituted in `allowed-tools`; `!` command injection
- https://code.claude.com/docs/en/permissions — Bash rules match the whole command text; `:*` equals a trailing ` *`; quoted `git 'push'` not matched
- https://code.claude.com/docs/en/headless and https://code.claude.com/docs/en/permission-modes — `-p` Manual mode (v2.1.302) denies unapproved calls
- https://code.claude.com/docs/en/plugins-reference — variable substitution in command content; not in the Bash environment
- https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md — v2.1.302 / v2.1.305 / v2.1.299 entries
- https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/ralph-loop/commands/ralph-loop.md — unquoted `${CLAUDE_PLUGIN_ROOT}` grant, quoted `!` call
- https://github.com/anthropics/claude-code/issues/14956 — quoted pattern not matching in `-p` (open)
- https://github.com/anthropics/claude-code/issues/67198 — grant applied on typed invocation, not via the Skill tool
- https://github.com/anthropics/claude-code/issues/16398 and https://github.com/anthropics/claude-code/issues/19240 — ralph-loop grant fix (`:*`)
- https://github.com/anthropics/claude-code/issues/9354 — `${CLAUDE_PLUGIN_ROOT}` substitution in command markdown and `allowed-tools` (closed 2026-08-17)
- https://github.com/anthropics/claude-code/issues/80696 — Desktop never applies `allowed-tools`; CLI `-p` reported working
- https://platform.claude.com/docs/en/test-and-evaluate/strengthen-guardrails/increase-consistency — consistency techniques; no verbatim guarantee; no prefill on 4.6+

## Open Questions

1. **Defect 3's cause has to be reproduced before anything else is decided.**
   The intent requires a run in both an interactive and a `claude -p` session.
   The records do not show the denied command string or the working
   `--allowedTools` value. The candidates are: quote characters inside the
   pattern, the invocation path (typed versus the Skill tool), and a 2.1.301
   behaviour. Once the cause is known, the choice is between rewriting the
   grants (for example, the unquoted form the docs and ralph-loop use) and a
   README note about headless runs. Which grant forms match, interactively and
   under `-p`, is a fact for the plan to establish first.
2. **Where the preflight's fixed text comes from.** Today it is a model-filled
   template in `work-loop.md`. tsf shows the alternative: the script prints the
   user-facing text and the command relays the script's line. `!` injection
   puts deterministic text into the prompt but still relies on the model to
   repeat it. Whether a relayed script line counts as "byte for byte" for the
   acceptance criterion, given that the model still emits it, is a decision for
   the planner.
3. **Quickfix's explicit rule for the intent hand-off.** Possible rules include
   "the last line that starts with `intent:` or `insufficient:` decides", a
   fenced block like `tce-return`, or Glob-checking the intent file on disk.
   Choosing one, and what quickfix does when neither prefix appears, is a
   design choice. Changing the return to a block would bring `intent.md` closer
   to the return-shape span, which the intent's scope limits to "beyond what a
   fix needs".
4. **How the stray log edit is kept out of the next feature commit.** A file
   cannot hold its own commit's hash, and amending is forbidden. Options the
   facts leave open:
   - the log names something other than its own commit's hash, so one commit
     carries both;
   - the implementer (or the loop) commits a dirty plan on its own before
     phase work, at dispatch or in step 1;
   - the position derivation treats a missing `**Commit**` hash as unfinished.

   The last option would touch `stage.sh`'s derivation and therefore `list.md`
   (TP-0033 span). Which option, if any, also changes the log format that
   `stage.sh` parses is the planner's call.
