# TP-0017: Adopt command/agent frontmatter machinery — Implementation Plan

## Overview

Adopt the newer Claude Code command/agent frontmatter levers across the tce
plugin: `disable-model-invocation: true` on the seven commands with no inbound
Skill-tool delegation, `allowed-tools` pre-approval for the ticket.sh discovery
script in the five commands that run it, `model: haiku` for the two pure
find-and-categorize locator agents (if a parity check passes), and an
empirically grounded adopt-or-reject decision on `` !`cmd` `` dynamic context
injection. The hard constraint from the ticket is confirmed by research:
`disable-model-invocation: true` blocks Skill-tool invocation entirely, so the
five delegated-to commands (`ticket`, `research`, `plan`, `implement`,
`commit`) must never receive it.

## Current State Analysis

- Every command in `plugins/tce/commands/` and `plugins/tmt/commands/` carries
  only `description` (+ `argument-hint`) frontmatter; no invocation control,
  no `allowed-tools` (research §1).
- All six agents in `plugins/tce/agents/` pin `model: inherit`
  (`codebase-locator.md:2-5` … `web-search-researcher.md:2-6`).
- ticket.sh is instructed at 6 call sites across 5 commands
  (`research.md:84,94`, `plan.md:68`, `implement.md:48` (+`:61` restatement),
  `review.md:116`, `work.md:72`), each risking a permission prompt.
- Delegation graph (research §2): `quickfix.md:108,160,184` explicitly
  Skill-invokes `tce:ticket`, `tce:plan`, `tce:implement`; `/tce:commit` is
  prose-delegated from `work.md:95,204,236,262`, `quickfix.md:117,147,171,241`,
  `research.md:281,291`, `plan.md:440`, `implement.md:229`; `work.md:65,189,218`
  defers to the full specs of `research`/`plan`/`implement` (soft Skill-tool
  dependencies).
- Key doc gap (research §4): `${CLAUDE_PLUGIN_ROOT}` substitution inside
  frontmatter (`allowed-tools`) is undocumented — only `${CLAUDE_PROJECT_DIR}`
  is documented there (v2.1.196+). The documented plugin-native alternative is
  `bin/` (executables joining Bash's PATH as bare commands).

## Desired End State

- The seven non-delegated tce commands (`init`, `refresh`, `work`, `quickfix`,
  `review`, `discuss`, `design_explore`) carry `disable-model-invocation: true`;
  the five delegated-to commands do not, and a CLAUDE.md rule prevents future
  regressions.
- ticket.sh runs without a permission prompt inside `research`, `plan`,
  `implement`, `review`, and `work` (verified in a scratch project), via
  whichever of the two mechanisms the Phase 1 probe validates.
- `codebase-locator` and `thoughts-locator` run on `model: haiku` if the
  parity check shows no quality loss; the decision is recorded either way.
- Dynamic context injection is adopted only if the probes show it works in
  plugin commands AND simplifies the prompt without behavior change; otherwise
  the ticket carries an explicit rejection note with the probe evidence.
- `claude plugin validate` passes for the marketplace and both plugins;
  `/tce:work` and `/tce:quickfix` still work end-to-end.

### Key Discoveries:

- `disable-model-invocation: true` = "Only you can invoke the skill" +
  description removed from the model-facing listing — no carve-out for
  prompt-instructed Skill-tool delegation (research §3).
- The originating review's proposed disable-set (`init`, `implement`,
  `quickfix`, `commit`) is partly wrong: `implement` and `commit` are
  delegated to (research §7).
- Command call sites quote the script path (`"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" ARG`)
  — the permission-rule string must match the *substituted, quoted* form, so
  the probe must test the exact call-site shape (research §4).
- Community-reported `allowed-tools` enforcement bugs (claude-code #14956,
  #18837) make empirical verification mandatory regardless of mechanism.
- Plugin agents officially support `model: haiku`; an org `availableModels`
  block degrades gracefully to inherit (research §5).
- Agent-tool invocations accept a per-invocation `model` parameter — the
  parity check needs no file edits (research §5).

## What We're NOT Doing

- No `context: fork` / composite-session restructuring (review finding 2.3 —
  explicitly out of scope in the ticket).
- No subagent output caps (review finding 2.5 — ticketed elsewhere).
- No changes to tmt commands or scripts (checkpoint decision: tce only;
  follow-up ticket if desired).
- No pre-approval of the other Bash the commands run (git metadata, `date`,
  `grep`/`ls` over mockups) — the ticket names only ticket.sh.
- No `user-invocable: false` anywhere; no command body/structure changes
  beyond frontmatter (and call-site paths if the `bin/` fallback triggers).
- No workflow behavior change; no version bump/release (the human releases).

## Implementation Approach

Probe first, edit second. Phase 1 builds a tiny disposable plugin in the
scratchpad and uses non-interactive `claude -p` runs against a throwaway
project to answer the two undocumented questions (does `${CLAUDE_PLUGIN_ROOT}`
substitute inside `allowed-tools`? how does injection interact with
`$ARGUMENTS` / plugin variables / permissions?). Phases 2–4 then apply the
frontmatter with no open questions left, Phase 5 records the decisions in the
ticket, and Phase 6 verifies end-to-end in a scratch project. Each phase
commits separately per the tce workflow.

Probe mechanics: check `claude --help` for a `--plugin-dir`-style flag to load
the probe plugin directly; if absent, add the scratchpad probe marketplace via
`claude plugin marketplace add <path>` + `claude plugin install` scoped to the
throwaway project. In `-p` (non-interactive) mode an unapproved Bash call is
denied rather than prompted, which gives a clean binary signal — pair every
probe with a control run (same script call, no `allowed-tools`) so the deny
baseline is confirmed and an auto-allowed match can't masquerade as a grant.

## Phase 1: Empirical probes (scratchpad only — no repo changes)

### Overview

Answer the three empirical questions that gate later phases: (P1) does
`allowed-tools: Bash(${CLAUDE_PLUGIN_ROOT}/…/ticket.sh:*)` grant without a
prompt in a plugin command; (P2) does `` !`cmd` `` injection work usefully for
the ticket.sh preamble (is `$ARGUMENTS` substituted before injection runs, is
`${CLAUDE_PLUGIN_ROOT}` substituted in the injected command, does injection
require a matching `allowed-tools` grant); (P3) do the locator agents lose
quality on `haiku`.

### Changes Required:

#### 1. Probe plugin + throwaway project (scratchpad)

**Location**: scratchpad directory (never the repo)
**Changes**: create `probe-plugin/` with `.claude-plugin/plugin.json`
(name `probe`), `scripts/probe.sh` (echoes a recognizable marker +
its `$1`), and commands:

- `commands/allowed.md` — `allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh":*)`
  (mirror the exact quoted call-site form used by tce; if that fails, retry
  the unquoted rule form `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh:*)`),
  body instructing: run `"${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh" $ARGUMENTS`
  and print its output verbatim.
- `commands/control.md` — same body, **no** `allowed-tools` (deny baseline).
- `commands/inject.md` — body containing
  `` !`echo "INJ-ARGS=[$ARGUMENTS]"` `` and
  `` !`"${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh" injected` ``
  plus the instruction "repeat every line above starting with INJ- or the
  probe marker verbatim". No `allowed-tools` first; re-run with the grant if
  the injected script does not execute.

Also a throwaway project dir with minimal content (the probe plugin is
self-contained).

#### 2. Probe runs

Run each probe via `claude -p "/probe:allowed TP-42"` (etc.) from the
throwaway project, capturing output. Record for each: script executed? prompt
denied? `$ARGUMENTS` value seen by injection (raw vs substituted vs literal)?

#### 3. Locator parity check (P3 — no plugin needed)

In this repo, run `tce:codebase-locator` and `tce:thoughts-locator` twice
each on two fixed queries with known-correct answers (e.g. "find everything
referencing ticket.sh" → the research §4 call-site list; "locate the
ticket-status hook scripts" → `plugins/tmt/hooks/hooks.json` +
`plugins/tmt/scripts/`), once with Agent-tool `model: haiku` and once
inheriting. Diff the returned file sets against the known-correct locations.
Parity = no known-correct file missing on haiku.

### Success Criteria:

#### Automated Verification:

- [x] P1 verdict recorded: **both** rule forms (quoted and unquoted
      `Bash(${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh…)`) substitute and grant —
      script ran promptless; Phase 3 takes **Branch A**
- [x] Control probe confirms the deny baseline ("This command requires
      approval" without `allowed-tools`)
- [x] P2 verdicts recorded: `$ARGUMENTS` **is** substituted before injection;
      `${CLAUDE_PLUGIN_ROOT}` **is** substituted in injected commands; a
      script-call injection **requires** a matching `allowed-tools` grant —
      without it the entire command invocation silently aborts (0 turns,
      no error, no output) in `-p` mode
- [x] P3 file-set diffs recorded: haiku found 100% of the known-correct sets
      for both locators (codebase: full ticket.sh call-site/doc set with
      correct line numbers; thoughts: exactly the 4 primary TP-0016 docs);
      full-model runs were only marginally cleaner at excluding
      `next-ticket.sh` noise — parity holds

#### Manual Verification:

- [x] `claude -p` signals were unambiguous (OK vs "requires approval" vs
      0-turn abort) — no interactive fallback session needed

---

## Phase 2: Invocation control (`disable-model-invocation`) + CLAUDE.md rule

### Overview

Apply `disable-model-invocation: true` to the seven commands with no inbound
delegation (checkpoint decision: all seven) and codify the delegation
constraint in CLAUDE.md so future edits can't silently break the composites.

### Changes Required:

#### 1. Seven tce command files

**Files**: `plugins/tce/commands/init.md`, `refresh.md`, `work.md`,
`quickfix.md`, `review.md`, `discuss.md`, `design_explore.md`
**Changes**: add one frontmatter line each (after `description`/
`argument-hint`):

```yaml
disable-model-invocation: true
```

Explicitly NOT touched: `ticket.md`, `research.md`, `plan.md`,
`implement.md`, `commit.md` (delegated to — research §2).

#### 2. CLAUDE.md — new invocation-control rule

**File**: `CLAUDE.md` (repo root)
**Changes**: add a short section (near the composite-tracking rule) stating:
(a) `ticket`, `research`, `plan`, `implement`, `commit` are Skill-tool
delegation targets of the composites (explicitly or via prose "use the
`/tce:commit` command") and must never get `disable-model-invocation: true`
— the flag blocks Skill-tool invocation entirely and removes the description
from Claude's context; (b) the other seven tce commands carry the flag
deliberately (user-only + context-listing hygiene); (c) side effect to know:
a flagged command also can't be preloaded into subagents or fired by a
scheduled task's prompt; (d) when adding a command or a new delegation edge,
re-derive the classification.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .`, `claude plugin validate ./plugins/tce`,
      `claude plugin validate ./plugins/tmt` all pass (run from repo root)
- [x] `grep -l "disable-model-invocation: true" plugins/tce/commands/*.md`
      lists exactly the seven files; grep over the five delegated-to files
      returns nothing (tmt commands also clean)

#### Manual Verification:

- [x] CLAUDE.md section reads correctly next to the existing composite rule
      (no contradiction, no duplication — placed between the composite-tracking
      and TP-0013 sections)

---

## Phase 3: `allowed-tools` pre-approval for ticket.sh

### Overview

Grant no-prompt execution of the discovery script in the five commands that
run it, using the mechanism Phase 1 validated. Branch A (probe P1 succeeded
with a variable rule): frontmatter-only change. Branch B (P1 failed): move the
script to `bin/` under a collision-safe name and update call sites.

### Changes Required:

#### Branch A — variable rule works (preferred, smallest diff)

**Files**: `plugins/tce/commands/research.md`, `plan.md`, `implement.md`,
`review.md`, `work.md`
**Changes**: add to each frontmatter the rule form P1 validated, e.g.:

```yaml
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)
```

(exact quoting per probe outcome). No body changes; call sites stay
`"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh"`.

#### Branch B — fallback: move script to `bin/`

1. **Move + rename**: `plugins/tce/scripts/ticket.sh` →
   `plugins/tce/bin/tce-tickets` (collision-safe bare name, executable bit);
   adjust its internal `lib.sh` sourcing for the new location
   (check how the script resolves its own dir).
2. **Call sites** (6): `research.md:84,94`, `plan.md:68`, `implement.md:48,61`,
   `review.md:116`, `work.md:72` — replace
   `"${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh" ARG` with `tce-tickets ARG`.
3. **Frontmatter** on the same five commands:
   `allowed-tools: Bash(tce-tickets:*)`.
4. **Docs that name the script**: `plugins/tce/README.md` (if it mentions
   ticket.sh), repo `CLAUDE.md` layout tree (`scripts/*.sh … ticket.sh`),
   `.claude/tce/profile.md` code map only if it names the file (it lists
   directories generically — check). Do NOT touch `init.md:127,180,398`
   (legacy claude-template filenames — frozen; see research §4) or
   `check-init.sh` (signature keys on the *project's* `scripts/next-ticket.sh`).
5. Re-test in the scratch setup that `tce-tickets` resolves on PATH and the
   rule grants without prompt.

### Success Criteria:

#### Automated Verification:

- [ ] All three `claude plugin validate` runs pass
- [ ] Branch B only: `plugins/tce/bin/tce-tickets` exists, is executable, and
      `CLAUDE_PROJECT_DIR=/tmp/fakeproj plugins/tce/bin/tce-tickets FAKE-0001`
      behaves exactly as the old script (same output on a throwaway project)
- [ ] Branch B only: `grep -rn "scripts/ticket.sh" plugins/tce/commands/`
      returns only the frozen legacy-migration mentions in `init.md`

#### Manual Verification:

- [ ] Scratch-project run of `/tce:research` (or the probe equivalent)
      executes the discovery script with **no permission prompt**
      (acceptance criterion 2)

---

## Phase 4: Locator agents → `model: haiku` (if P3 parity holds)

### Overview

Move the two pure find-and-categorize agents to `haiku` per the checkpoint
decision and the P3 comparison; record the decision either way.

### Changes Required:

#### 1. Two agent files (only if P3 showed parity)

**Files**: `plugins/tce/agents/codebase-locator.md`,
`plugins/tce/agents/thoughts-locator.md`
**Changes**: `model: inherit` → `model: haiku` (frontmatter, one line each).
The alias (not a pinned ID) tracks future Haiku releases; an org
`availableModels` block falls back to inherit gracefully (research §5).

If P3 showed a quality gap: keep `inherit`, record the negative decision and
the diff evidence in the ticket note (Phase 5) — the acceptance criterion
explicitly allows either outcome.

Untouched either way: `codebase-analyzer`, `codebase-pattern-finder`,
`thoughts-analyzer`, `web-search-researcher` (synthesis/read duties —
research §5).

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate ./plugins/tce` passes
- [ ] `grep -l "model: haiku" plugins/tce/agents/*.md` matches exactly the
      changed set (two files, or none on a negative decision)

#### Manual Verification:

- [ ] One post-change spot-run of each changed locator in this repo returns a
      sensible categorized file list

---

## Phase 5: Decision records (ticket note; injection adopt-or-reject)

### Overview

Satisfy the "decision recorded" clauses of all four acceptance criteria in one
place: a dated entry in the ticket's Notes & Updates. For injection, apply the
decision rule to the P2 probe results.

**Injection decision rule**: adopt only if (a) P2 shows the mechanism works in
plugin commands with `$ARGUMENTS` available to the injected command, AND
(b) it simplifies the preamble *without behavior change* — i.e. it must not
run ticket.sh on raw/absent ticket IDs (`/tce:research` takes free-form
questions; IDs arrive un-normalized as `42`/`tp-42`/`TP-42` — research §6) and
must not lose the conditional parent-epic lookup. Constraint (b) is expected
to fail regardless of (a) — in that case reject, citing both the probe results
and the structural mismatch.

### Changes Required:

#### 1. Ticket file

**File**: `thoughts/shared/tickets/TP-0017-adopt-frontmatter-machinery.md`
**Changes**: add a dated Notes & Updates entry recording:

- The full 12-command classification table (7 flagged / 5 delegation-locked)
  and its rationale pointer (research §2).
- The ticket.sh mechanism chosen (Branch A or B) with the P1 probe result.
- The locator-model decision with the P3 evidence summary.
- The injection adopt/reject decision with the P2 evidence and the decision
  rule above (acceptance criterion 4's "explicitly rejected with a note"
  lands here if rejected).
- Check off the acceptance-criteria boxes that are now satisfied.

### Success Criteria:

#### Automated Verification:

- [ ] tmt status-validation hook accepts the ticket edit (status line
      untouched in this phase)

#### Manual Verification:

- [ ] Every acceptance criterion's "recorded" clause is satisfied by the note

---

## Phase 6: End-to-end verification (scratch project)

### Overview

Acceptance criterion 1's verification: install both plugins from this
marketplace into a scratch project and confirm the composites still delegate,
the disabled commands behave as intended, and ticket.sh runs promptless.

### Changes Required:

None in the repo (verification only; fixes loop back into earlier phases if
something fails — and if a delegation break surfaces, STOP and reassess the
classification rather than patching ad hoc).

Procedure: in a scratch project, `/plugin marketplace add <this repo path>`,
install `tmt@toby-plugins` + `tce@toby-plugins`, run `/tmt:init` + `/tce:init`,
then exercise:

1. `/tce:quickfix` on a trivial seeded issue — must Skill-invoke `tce:ticket`,
   `tce:plan`, `tce:implement` and prose-invoke `tce:commit` without "skill
   not found/unavailable" failures (the delegation constraint, end-to-end).
2. `/tce:work` on a seeded ticket — research phase must run the discovery
   script with no permission prompt; plan/implement/commit phases complete.
3. Ask the model in a fresh session which tce skills it can invoke — the seven
   flagged commands must be absent from its listing; then type `/tce:refresh`
   (a flagged command) — user invocation must still work.

(Reverts afterwards: uninstall + `claude plugin marketplace remove`.)

### Success Criteria:

#### Automated Verification:

- [ ] `claude plugin validate .` + both plugin validates pass at final state

#### Manual Verification:

- [ ] `/tce:quickfix` end-to-end: all three Skill-tool delegations + commit
      succeed
- [ ] `/tce:work` end-to-end: no ticket.sh permission prompt; full chain
      completes
- [ ] Flagged commands: invisible to the model, still user-invocable
- [ ] No regression in `/tmt:*` commands (untouched, but same session)

---

## Testing Strategy

### Unit Tests:

- Not applicable (markdown prompts + one possibly-moved shell script).
  Branch B only: run the moved `tce-tickets` against a throwaway project
  exactly as `CLAUDE.md` "Testing changes" prescribes
  (`CLAUDE_PROJECT_DIR=/tmp/fakeproj …`) and diff its output against the
  pre-move script on the same input.

### Integration Tests:

- The Phase 1 probe matrix (grant/deny × quoted/unquoted × injection
  variants) via `claude -p`, each with a control run.
- The Phase 6 scratch-project end-to-end of both composites.

### Manual Testing Steps:

1. Phase 1 fallback: one interactive scratch session if `-p` signals are
   ambiguous.
2. Phase 6 steps 1–3 above.
3. After Phase 4: one spot-run per changed locator agent in this repo.

## Performance Considerations

- `model: haiku` on the locators reduces subagent latency/cost per research
  run (two of the six agents in every `/tce:research` fan-out).
- Seven removed skill descriptions shrink the always-on skill listing in every
  consuming-project session (budget is 1% of context window).

## Migration Notes

- No consuming-project config changes; no init/refresh Idempotency-list entry
  (plugin-internal change only — nothing about what project config must
  contain changes).
- Branch B only: consumers pick the moved script up with the next plugin
  update; `${CLAUDE_PLUGIN_ROOT}` references to it vanish from command bodies,
  so no stale-path window exists.
- Scheduled-task users: a scheduled prompt can no longer fire the seven
  flagged commands (documented side effect; noted in CLAUDE.md rule).

## References

- Original ticket: `thoughts/shared/tickets/TP-0017-adopt-frontmatter-machinery.md`
- Related research: `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md`
- Originating review: `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` (§2 finding 4)
- Docs verified: code.claude.com `/en/skills`, `/en/plugins-reference`,
  `/en/sub-agents`, `/en/model-config`, `/en/permissions`, `/en/tools-reference`
