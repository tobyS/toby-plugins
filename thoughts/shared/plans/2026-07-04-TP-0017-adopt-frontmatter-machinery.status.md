# Implementation Status: TP-0017 — Adopt command/agent frontmatter machinery

## Phase 1: Empirical probes (scratchpad only)
- **Status**: ✅ Complete
- **Started**: 2026-07-04
- **Completed**: 2026-07-04

### Steps Performed
1. Built disposable `probe` plugin in the scratchpad (plugin.json, `scripts/probe.sh` echoing a marker + `$1`, commands `allowed`/`allowed2`/`control`/`inject`/`inject2`/`inject3`/`inject4`) and a throwaway project dir; ran probes via `claude -p "/probe:<cmd> TP-42" --plugin-dir …` (flag confirmed in `claude --help`) on haiku (one sonnet cross-check).
2. **P1 (allowed-tools)**: quoted rule `Bash("${CLAUDE_PLUGIN_ROOT}/scripts/probe.sh":*)` → `RESULT: OK PROBE-MARKER arg1=[TP-42]`; unquoted rule form → same OK. Control (no allowed-tools) → `RESULT: BLOCKED This command requires approval`. Verdict: `${CLAUDE_PLUGIN_ROOT}` IS substituted in `allowed-tools` before permission matching (undocumented but working); grant is real (deny baseline confirmed). **Phase 3 → Branch A.**
3. **P2 (injection)**: combined probe (echo + script call, no grant) aborted silently — `num_turns: 0`, empty result, 30 ms, zero tokens (reproduced on sonnet/JSON). Isolation: echo-only injection worked and printed `INJ-ARGS=[TP-42]` (→ `$ARGUMENTS` substituted before injection; echo needs no grant); script-call-only without grant → 0-turn silent abort; script-call with `allowed-tools` grant → `SAW: PROBE-MARKER arg1=[TP-42]` (→ `${CLAUDE_PLUGIN_ROOT}` substituted in injected commands; grant required for script calls). New failure mode discovered: an ungranted injection silently no-ops the entire command invocation.
4. **P3 (locator parity)**: `tce:codebase-locator` ("everything referencing ticket.sh") and `tce:thoughts-locator` ("documents related to TP-0016") each run on `model: haiku` vs inherit (Fable 5) via the Agent tool's per-invocation model param. Haiku recall = 100% of the known-correct sets (all 6 command call sites with correct line numbers + script + docs; exactly the 4 primary TP-0016 docs). Inherit runs only marginally cleaner at excluding `next-ticket.sh`-substring noise (haiku listed some but labeled them "related script, not ticket.sh"). **Parity holds → Phase 4 proceeds with haiku.**

### Issues Encountered
- First `cd` to the scratchpad reset (shell cwd pinned to the project) — probes wrapped in scratchpad runner scripts instead.
- The combined inject probe's silent abort initially looked like a harness bug; isolation showed it is the (undocumented) permission behavior of `!`-injection in `-p` mode.

### Verification
- ✅ All four plan Phase-1 criteria recorded (see plan checkboxes)
- ✅ Deny baseline confirmed by control probe (rules out settings auto-allow contamination)

### Commit
- (no repo changes — results recorded here and in the plan; plan checkbox
  update committed with Phase 2)

---

## Phase 2: Invocation control + CLAUDE.md rule
- **Status**: ✅ Complete
- **Started**: 2026-07-04
- **Completed**: 2026-07-04

### Steps Performed
1. Added `disable-model-invocation: true` to the frontmatter of the seven
   non-delegated tce commands: `init.md`, `refresh.md`, `work.md`,
   `quickfix.md`, `review.md`, `discuss.md`, `design_explore.md`.
2. Added CLAUDE.md section "Invocation control: `disable-model-invocation`
   must respect the delegation graph (TP-0017)" between the composite-tracking
   and TP-0013 sections: the two-set classification (5 delegation targets
   never flagged / 7 user-only flagged), the prose-invocation rationale, the
   subagent-preload/scheduled-task side effects, and the re-derive-on-change
   rule.

### Issues Encountered
- None.

### Verification
- ✅ `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` all pass
- ✅ Flag grep: exactly the seven files; delegated-to five and all tmt
  commands clean
- ✅ CLAUDE.md section coherent with neighboring rules

### Commit
- `2a23b4c` feat(TP-0017): disable model invocation for non-delegated tce commands

---

## Phase 3: allowed-tools pre-approval for ticket.sh (Branch A)
- **Status**: ✅ Complete
- **Started**: 2026-07-04
- **Completed**: 2026-07-04

### Steps Performed
1. Branch A taken per P1 (both rule forms substitute and grant; quoted form
   chosen — it mirrors the call sites byte-for-byte).
2. Added `allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)` to
   the frontmatter of `research.md`, `plan.md`, `implement.md`, `review.md`,
   `work.md`. No body/call-site changes; script stays at
   `plugins/tce/scripts/ticket.sh`.

### Issues Encountered
- None.

### Verification
- ✅ All three `claude plugin validate` runs pass
- ✅ `grep -l allowed-tools plugins/tce/commands/*.md` = exactly the five files
- ✅ Promptless execution verified by the Phase 1 probe (identical rule/call
  shape); real-command E2E re-check deferred to Phase 6

### Commit
- (this commit)
