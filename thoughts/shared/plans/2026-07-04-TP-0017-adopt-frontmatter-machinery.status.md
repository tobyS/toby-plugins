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
- `06135bf` feat(TP-0017): pre-approve the ticket.sh discovery script

---

## Phase 4: Locator agents → model: haiku
- **Status**: ✅ Complete
- **Started**: 2026-07-04
- **Completed**: 2026-07-04

### Steps Performed
1. P3 parity held (Phase 1, step 4) → changed `model: inherit` to
   `model: haiku` in `codebase-locator.md` and `thoughts-locator.md`.
2. The four synthesis/read agents (`codebase-analyzer`,
   `codebase-pattern-finder`, `thoughts-analyzer`, `web-search-researcher`)
   left on `inherit` per the plan.

### Issues Encountered
- None. Note: spot-runs via the Agent tool exercise the *installed* plugin's
  agents, so the P3 haiku runs (per-invocation model param, identical prompts)
  serve as the functional spot-check; the frontmatter-driven model selection
  is exercised by Phase 6's scratch install from this tree.

### Verification
- ✅ `claude plugin validate ./plugins/tce` passes
- ✅ haiku grep = exactly the two locator files
- ✅ P3 haiku runs: 100% recall on both fixed queries, well-categorized output

### Commit
- `eb2184c` feat(TP-0017): run the locator agents on haiku

---

## Phase 5: Decision records (ticket note; injection rejected)
- **Status**: ✅ Complete
- **Started**: 2026-07-04
- **Completed**: 2026-07-04

### Steps Performed
1. Added a dated 2026-07-04 Notes & Updates entry to the ticket: the
   12-command classification table, the ticket.sh mechanism (Branch A with P1
   evidence), the locator-model decision (P3 evidence), the injection
   **rejection** with the decision rule applied to P2 (mechanism works;
   simplification-without-behavior-change fails; silent-abort failure mode),
   and the docs-verification pointer.
2. Checked acceptance criteria 2–5 in the ticket (criterion 1 awaits Phase 6
   end-to-end verification). Filled the ticket's Implementation Plan section
   with the plan/research paths.
3. Recorded the injection outcome in the plan's Phase 5 decision-rule block.

### Issues Encountered
- None.

### Verification
- ✅ tmt status-validation hook accepted the ticket edits (status untouched)
- ✅ All four "recorded" clauses satisfied by the note

### Commit
- `a02facd` docs(TP-0017): record the frontmatter decisions, reject injection

---

## Phase 6: End-to-end verification (scratch projects)
- **Status**: ✅ Complete
- **Started**: 2026-07-04
- **Completed**: 2026-07-04

### Steps Performed
1. **Deviation from plan procedure**: used `claude -p … --plugin-dir
   plugins/tce --plugin-dir plugins/tmt` (session-scoped plugin load from
   this tree) instead of `/plugin marketplace add` + install — same coverage,
   no mutation of user-scoped plugin installs; and seeded the scratch
   projects' `.claude/tce/` + `.claude/tmt/config` by hand instead of running
   the interactive inits (init behavior is out of this ticket's scope).
2. Built two scratch git projects (`e2eproj-work`, `e2eproj-quickfix`), each
   with a seeded `FAKE-0001` typo ticket, `notes/hello.txt` (`helo world`),
   and a settings allowlist (Read/Edit/Write/git/date/ls/grep/mkdir/cat/wc —
   deliberately NOT ticket.sh and NOT Skill).
3. Targeted checks: **T1** skill listing → model sees exactly
   `tce:commit/implement/plan/research/ticket` (all seven flagged commands
   absent); **T2** Skill call to flagged `tce:review` → blocked ("not among
   the skills available"); **T3** Skill call to unflagged `tce:plan` →
   SKILL-LOADED; **T4** user-invoked flagged `/tce:discuss` → ran normally.
4. **`/tce:work FAKE-0001` E2E** (sonnet, headless): full autonomous chain —
   config + ticket reads, `ticket.sh` executed **promptless** (not in the
   run's permission_denials; only unrelated compound/`find` commands were
   denied), subagent fan-out (haiku locators via new frontmatter), research +
   plan from the reference templates, 3 conventional commits, typo fixed,
   ticket → Done, no interaction needed.
5. **`/tce:quickfix …typo…` E2E** (sonnet, headless): chain completed with
   identical final state (3 commits, fix, ticket Done). `tce:ticket` Skill
   delegation launched; the later `tce:research`/`tce:plan`/`tce:implement`
   Skill calls were **permission-denied by headless mode's Skill gate** and
   the session fell back to executing the phases manually (correct output
   anyway).
6. **Disambiguation of the denials** (D1/D2): with default permissions, two
   sequential Skill calls in one session gave plan=DENIED, commit=OK
   (inconsistent with any flag effect); with `"Skill"` added to the scratch
   allowlist, both calls succeeded. Combined with T2/T3's distinct signatures:
   the denials are pre-existing `-p` permission behavior for the Skill tool
   (interactively this is an approval prompt), independent of
   `disable-model-invocation` — TP-0017 introduces no delegation regression.

### Issues Encountered
- The headless Skill permission gate (above) initially masqueraded as a
  delegation break; resolved by the D1/D2 disambiguation. Noteworthy for any
  future headless composite runs: allowlist `Skill` (or the specific
  `Skill(tce:…)` rules) in the project settings.

### Verification
- ✅ Final `claude plugin validate .`, `./plugins/tce`, `./plugins/tmt` pass
- ✅ Acceptance criterion 1 verified: both composites ran end-to-end in
  scratch projects with correct final state; flag blocks only the seven
  intended commands
- ✅ Acceptance criterion 2 re-verified in a real command run (`/tce:work`'s
  ticket.sh call, promptless)

### Commit
- (this commit)
