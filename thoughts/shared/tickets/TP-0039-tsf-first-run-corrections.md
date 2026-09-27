# TP-0039: tsf — corrections from the first factory run (chat-sustainability GH-40)

**Status:** In Progress
**Estimated Complexity:** Medium
**Created:** 2026-09-27
**Updated:** 2026-09-27

Companion to TP-0038. Collects the six corrections agreed from the analysis of
the first successful tsf run (chat-sustainability GH-40, factory session
`8867f1a0`, 2026-09-26). The cost finding of the same run — the `/loop`
session's context growth — is TP-0038, because it changes the runner, not the
cycle.

## Problem Statement

The first real run of tsf landed its ticket in 55 minutes with every state
transition, script and GitHub write behaving as designed. The transcript
nevertheless shows six places where the plugin's text and its runtime
behaviour disagree, or where a documented assumption cost something it need
not have. None blocked the run; each will recur on every ticket.

## Desired Outcome

Each correction below states the finding, the agreed fix and how "done" is
observed. After them: an invalid worker return is rare rather than a coin flip,
gate evidence points at lines a human can open, the factory's links on a closed
issue still resolve, the first scan of a session succeeds, a green CI result on
the head is not followed by a redundant local suite run, and the docs state the
permission mode the factory requires.

## Corrections

### C1 — Worker returns without the result contract

**Finding.** Implement agent `abdda4bd` did all its work correctly (three
commits, verify green, `pr-body.md`) and ended with a home-made
`<result>…</result>` block; its tool log shows no Read of `result-block.md`
despite `implement.md:147` ("Read … now — in full"). Across the run's seven
worker dispatches, three skipped that Read (plan-fresh, dossier, implement);
the Opus ones still produced the format, the Sonnet one did not. The
one-retry policy recovered it at 2.3 minutes and ~2.5M tokens, including a
second full verify run.

**Fix.** Inline the three-fence skeleton (fence names, field order, one
example per fence) in every worker's `## Return` section, keeping the Read of
`result-block.md` for the outcome and vocabulary tables. The re-dispatch note
names the template path explicitly.

**Done when.** The eight worker agents carry the skeleton,
`result-block.md`'s maintenance note lists the `## Return` sections as copies
to keep in step, and a dispatch of `tsf:implement` on a scratch ticket returns
a valid block without the retry.

### C2 — Gate reports cite patch-file offsets as source lines

**Finding.** The plan-compliance report cited `slugify.ts:98-131` (a 45-line
file) and the spec-coverage report `tenant-form.test.tsx:9-15` (the case is at
25-31). The PR diff was 131 lines: those are positions inside
`.tsf-tmp/pr-diff.patch`. The evidence rule "cite `path:line` in the diff or
the post-change source" (`plan-compliance.md:51`, `spec-coverage.md:59`, and
security's `file:line`) invites it. The dossier caught and corrected it, but
the reports are committed and linked from the pull request as evidence.

**Fix.** The three gate agents cite post-change source line numbers only —
obtained by Reading the file at head, or computed from the hunk headers —
never the patch's own offsets; `report.md` states the same under Evidence.

**Done when.** The three agents and the template state the rule, and a gate
run on a scratch ticket cites lines that exist in the files at head.

### C3 — The factory's links die when the branch is deleted

**Finding.** The issue's `<!-- tsf:links -->` block (`gh-write.sh:308-309`)
and the pull request body's Artifacts section link to `blob/gh-<n>/…`; the
merge cycle deletes `gh-<n>`. The dispatcher noticed this itself at 14:29Z.

**Fix.** `gh-write.sh marker` gains `--ref <sha>`. The merge cycle, after the
merge — a GitHub write it is allowed to make — re-runs `marker --ref
<merge_sha>` so the block points at `blob/<merge_sha>/thoughts/factory/GH-<n>/…`
and the branch link at the merge commit. Per-step comments keep their branch
links (they are history; the marker block sits above them). Per CLAUDE.md the
flag change updates `cycle.md`, `cycle-write-phase.md` (merge-cycle section),
`spec.md` and `init.md` together.

**Done when.** After a scratch landing, every link in the issue's marker block
resolves.

### C4 — The scan invocation fails once per session

**Finding.** `cycle.md:77` shows `--branch-pattern <pattern>` unquoted. The
dispatcher's first attempt in all three sessions of the run ran
`--branch-pattern gh-<n>`, and zsh reported `no such file or directory: n`.

**Fix.** Quote it in the Step 2 invocation with a one-line reason.

**Done when.** The first scan of a fresh session succeeds.

### C5 — Local verify runs after CI is already green on the same commit

**Finding.** At 14:08Z the scan showed `ci: success` on `30266bd`, which was
the branch HEAD after `prepare`; row 6 ran the suite anyway (40 seconds here,
minutes on a real suite) and added nothing. Reading CI state is cheaper than a
suite run.

**Fix.** Row 6 treats local verification as green when the scan reports
`ci: success` on a `pr_head` equal to the branch's HEAD after prepare — same
commit, same suite, since the config declares `verify` is what CI runs — and
continues with the manual items / row 8. Every other case runs the suite as
today, and red CI still routes to `verify-fix` with `failure: ci`. Update
`cycle-dispatch.md` rows 6–7, `cycle.md` Step 5 and DESIGN.md §4/§7.

**Done when.** A `tsf:verify` cycle picked up with green CI on its head
dispatches the gates without invoking `verify.sh`, visible in the transcript.

### C6 — The permission mode is a requirement nobody wrote down

**Finding.** The run recorded `permissionMode: bypassPermissions`. The
dispatcher itself relied on it — `cat >> journal.md <<'EOF'`, `printf >`,
`tail`, `sleep 1`, `mkdir -p .tsf-tmp`, none in `cycle.md`'s `allowed-tools`
or the init allowlist — not only the workers, as the TODO entry frames it.

**Fix.** The README and `/tsf:init`'s clone checklist state that the factory
session runs only with `--dangerously-skip-permissions` inside a sandbox or
cage, name the dispatcher's own dependence on it, recommend `permissions.deny`
rules for a direct `git push` and `gh`, and the TODO item "Document and check
the factory session's permission mode" is closed.

**Done when.** The README, the checklist and DESIGN.md §5.3 agree, and the
TODO entry is removed.

## Acceptance Criteria

- [ ] C1: every worker agent's `## Return` section carries the three-fence
      skeleton; `result-block.md` names them as copies; a scratch
      `tsf:implement` dispatch returns a valid block first time.
- [ ] C2: the three gate agents and `report.md` require post-change source
      line numbers; a scratch gate run cites lines that exist at head.
- [ ] C3: `gh-write.sh marker --ref <sha>` exists, the merge cycle calls it,
      and after a scratch landing the issue's marker links resolve.
- [ ] C4: `cycle.md` Step 2 shows the pattern quoted; the first scan of a
      fresh session succeeds.
- [ ] C5: a `tsf:verify` pickup with `ci: success` on the branch head skips
      `verify.sh` and dispatches the gates; any other state runs it.
- [ ] C6: README, init checklist and DESIGN.md §5.3 state the
      `--dangerously-skip-permissions`-in-a-sandbox requirement and the
      dispatcher's dependence on it; the TODO entry is removed.
- [ ] `claude plugin validate ./plugins/tsf` passes; the CLAUDE.md same-commit
      spans touched by C3 (gh-write flag) and C5 (row change) are honoured.

## Out of Scope

- The `claude -p` runner, the script-side pick and the closing-report
  contract — TP-0038 (the "report never printed under `/loop`" observation is
  closed by it).
- Parallel factories — `plugins/tsf/TODO.md`.
- Rewriting per-step comments' branch links after landing.
- The implement agent's `rm -rf .tsf-tmp` at the end of its work — harmless,
  the dispatcher regenerates the directory; noted, not acted on.
- Making the local-verify skip depend on anything but same-head equality
  (e.g. comparing what CI ran against `verify.sh`).

## Open Questions

None — each correction was agreed on 2026-09-27.

## Questions for Research/Planning

- [ ] C1: which fields each worker's skeleton must show — the fence names and
      order are shared, the allowed `outcome`/`next-step` values are per step;
      decide how much of the table to inline without creating a second
      vocabulary copy.
- [ ] C3: whether `pr-edit --field body` should also rewrite the pull request
      body's Artifacts links in the merge cycle, or whether the merged PR page
      (files, commits) makes that redundant.
- [ ] C5: the exact equality the dispatcher checks — `pr_head` from the scan
      against `git rev-parse HEAD` after prepare — and whether `checks:` must
      be ≥ 1 alongside `ci: success` (a `no-ci` project has no green to trust).
- [ ] C6: how DESIGN.md §5.3 phrases the sandbox assumption today and whether
      the init checklist has a natural place for the mode requirement.

## References

- Run analysis of session `8867f1a0`: implement retry at 13:56Z, gate reports
  at 14:10Z (`reports/plan-compliance-1-1.md`, `spec-coverage-1-1.md` on the
  merged branch), dead links noted by the dispatcher at 14:29Z, scan failures
  at 13:12Z, 13:16Z and 13:34Z.
- `plugins/tsf/agents/{implement,plan-compliance,spec-coverage,security}.md`,
  `references/templates/{result-block,report}.md`, `scripts/gh-write.sh`
  (marker), `commands/cycle.md` Steps 2 and 5, `references/cycle-dispatch.md`
  rows 6–8, `TODO.md` "Document and check the factory session's permission
  mode".
- TP-0037 (the previous corrections ticket; same shape), TP-0038.

## Implementation Plan

## Notes & Updates

### 2026-09-27

- Six corrections agreed from the run analysis; the token-cost finding was
  split off as TP-0038 because it changes the runner, not the cycle.
- C5 decision: trust CI green on the same commit — reading CI state is cheaper
  than a second suite run.
- C6 decision: the factory only works with `--dangerously-skip-permissions`;
  document it rather than build a fallback.
