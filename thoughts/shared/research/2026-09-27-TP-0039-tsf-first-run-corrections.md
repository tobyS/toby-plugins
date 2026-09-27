---
date: 2026-09-27T00:00:00+02:00
git_commit: cdf7c7a2c7857130b45215e6e1209c24a23e3eb6
branch: main
repository: toby-plugins
topic: "TP-0039: tsf — corrections from the first factory run (chat-sustainability GH-40)"
tags: [research, codebase, tsf, result-block, gate-report, gh-write, scan, verify, permissions]
status: complete
last_updated: 2026-09-27
---

# Research: TP-0039 — tsf corrections from the first factory run

**Date**: 2026-09-27T00:00:00+02:00
**Git Commit**: cdf7c7a2c7857130b45215e6e1209c24a23e3eb6
**Branch**: main
**Repository**: toby-plugins

## Research Question

Six independent corrections (C1–C6) agreed from the analysis of the first
successful tsf run (chat-sustainability GH-40, factory session `8867f1a0`,
2026-09-26). For each: where the plugin currently says and does the wrong
thing, what the same-commit span is, and what constrains the fix.

## Summary

All six findings reproduce in the current tree at `cdf7c7a`, and three of them
were verified directly against the first run's artifacts in
`/Users/toby/code/work/chat-sustainability` rather than taken on trust:

- **C1** — no worker agent's `## Return` section shows the fence names. The
  three fence names (`tsf-result`, `tsf-comment`, `tsf-journal`) and the field
  order exist in exactly **one** place in the whole plugin,
  `references/templates/result-block.md:28-50`. Every worker only names
  per-branch `outcome:`/`next-label:`/`next-step:` values and instructs a Read.
  When that Read does not happen — three of seven dispatches in the run — the
  agent has nothing to reproduce the format from.
- **C2** — confirmed as fact, not suspicion: the run's plan-compliance report
  cites `frontend/src/lib/slugify.ts:98-131` for a **45-line** file and
  `slugify.test.ts:49-79` for a **36-line** file. Both are offsets inside
  `.tsf-tmp/pr-diff.patch`. The rule that invites it is one sentence, duplicated
  in three places; `integration.md` has no citation rule at all.
- **C3** — confirmed dead: branch `gh-40` returns 404 from the API, and the
  live issue's marker block still links `blob/gh-40/…` and `tree/gh-40`. The
  fix is sound because the **squash commit contains the `thoughts/` artifacts**
  (verified: `0966ec4` carries all 9 `thoughts/factory/GH-40/` files), and
  `gh-write.sh merge` **already prints `merge_sha:`** — the value needed is in
  scope at the exact point the post-merge writes happen.
- **C4** — `cycle.md:77` is the **only** command line in the entire plugin
  where a string containing a literal `<n>` is handed to a shell.
- **C5** — the suite runs unconditionally at the top of row 6 in mode `local`;
  `pr_head:` is already an established dispatcher fact (`cycle-dispatch.md:43`)
  and nothing consults it. The ticket's sub-question about `checks: ≥ 1`
  is **answered by the code**: `scan.sh:219` emits `pending`, not `success`,
  when zero required runs match, so `ci: success` already implies `checks ≥ 1`.
  DESIGN.md §7 contains the one sentence that C5 falsifies.
- **C6** — `dangerously-skip-permissions`, `bypassPermissions` and
  `permissionMode` appear **zero** times in `plugins/tsf/`. The TODO entry
  already contains the fix almost verbatim. Web research confirms the two facts
  the wording depends on (deny survives bypass; allow does not) and surfaces
  **three things the TODO entry could not know**, including a newer `auto`
  mode that the docs now recommend *instead of* bypass for exactly this case.

Nothing about the six is entangled: they touch five largely disjoint file sets.
The only ordering constraint is that C5 and C4 both edit `cycle.md`, and C1 and
C2 both touch the agent corpus but not the same files.

## Detailed Findings

### C1 — the result-block skeleton exists in exactly one place

**Where the format lives.** `plugins/tsf/references/templates/result-block.md`
is the only file in the plugin that contains the fence names. The skeleton at
`:28-50` gives the field order:

- `tsf-result`: `step:`, `outcome:`, `next-step:`, `next-label:`, `commits:`,
  `manual:` (manual-verify only), `pr-fix:` (dossier only), `summary:`
- `tsf-comment`: free markdown
- `tsf-journal`: `- Outcome:`, `- Questions asked:`, `- Commits:`, `- Label:`,
  `- Next step:`

Note the ordering trap for an inlined copy: the skeleton orders `next-step:`
**before** `next-label:`, while the allowed-outcomes table's columns
(`:83-84`) run `step | outcome | next-label | next-step`. The agents' prose
follows the table order. A hand-written skeleton that silently reorders the
fields would be a third ordering.

A conditional fourth fence, `tsf-report` (`:68-72`), is mandatory for
`verify-fix` and `manual-verify` only, and parsing rule 4 (`:163-169`) makes
its absence an invalid return.

**What each worker's `## Return` carries today** — every one of the eight has
the point-of-use Read, none has a skeleton:

| agent | `## Return` | fences named | field values restated |
|---|---|---|---|
| triage | `:87-103` | none | outcome/next-label/next-step per branch |
| research | `:96-112` | none | same |
| plan | `:99-114` | none | same + `commits: none` |
| implement | `:145-183` | `tsf-journal` | same + the one filled example in the corpus, `- Increments: 2,3 of 7` (`:178`) |
| verify-fix | `:78-98` | `tsf-report` | same |
| manual-verify | `:76-107` | `tsf-report`, `tsf-comment` | same + `commits: none`, `manual:` shape |
| dossier | `:126-141` | `tsf-comment`, `tsf-journal` | same + `commits:`, `pr-fix:` |
| merge-resolver | `:103-114` | none | same + `commits:` |

Two wording variants of the Read sentence already exist ("the three blocks
**it defines**" vs "the three blocks"), and `dossier`/`merge-resolver` omit
`question-comment.md` from the same sentence.

**The maintenance note that already governs this** is the HTML comment at
`result-block.md:7-12`: it *already* names every worker's `## Return` section
as part of the same-commit span. C1 extends that span's content, it does not
create a new rule.

**No prior decision argues against inlining.** The recorded rationale for
putting the skeleton in a reference file is the point-of-use/compaction
argument
(`thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md:61-63`),
and that constraint is explicitly about **skill bodies** (`cycle.md` must stay
under 5,000 tokens), not agent bodies. A robustness fallback for a failed
substitution already exists in the same spirit — the spawn payload's
`templates:` line (`:940-942`).

### C2 — patch offsets cited as source lines

**The defect is confirmed, not inferred.** From
`/Users/toby/code/work/chat-sustainability/thoughts/factory/GH-40/reports/plan-compliance-1-1.md`:

- cites `frontend/src/lib/slugify.ts:98-131` — the file is **45 lines**
- cites `frontend/src/lib/__tests__/slugify.test.ts:49-79` — the file is **36 lines**

The PR diff was 131 lines, so both are positions inside
`.tsf-tmp/pr-diff.patch`. The spec-coverage report's `tenant-form.test.tsx:9-15`
is the same class of error.

Interestingly the same report is *self-aware* about line drift — its criterion 2
evidence reasons about "shifted to `:43-59` by the 8-line insertion" — so the
agent understood the concept and still used patch coordinates for the primary
citation. That argues for an explicit rule rather than a subtler hint.

**Every citation site, and what each says:**

| file:line | text | names a coordinate system? |
|---|---|---|
| `agents/plan-compliance.md:11` | "with a `file:line` evidence reference" | no |
| `agents/plan-compliance.md:51` | "cite `path:line` **in the diff** or the post-change source" | **invites the patch** |
| `agents/plan-compliance.md:69` | "with a `file:line` evidence reference" | no |
| `agents/plan-compliance.md:96` | "with a `file:line` for every 'met'" | no |
| `agents/spec-coverage.md:59` | "cite `path:line`." | no |
| `agents/security.md:32` | "cannot point at with `file:line`" | no |
| `agents/security.md:70` | "classification and `file:line` evidence" | no |
| `references/templates/report.md:125` | "cite `path:line` **in the diff** or the post-change source" | **invites the patch** |
| `references/templates/report.md:90`, `:113` | the example cell `` `path/to/file.ext:NN` `` | no |

`report.md` has **no `## Evidence` section** — "Evidence" is only a table column
header. The ticket's phrase "`report.md` states the same under Evidence" has no
existing anchor; the natural home is the verdict bullet at `:125` (which
`:122` declares to cover both plan-compliance and spec-coverage) or a new line
beside the skeleton.

**The gates can comply.** All four have `tools: Read, Grep, Glob`, run in the
clone with the ticket branch checked out, and are already permitted to open
post-change source (`plan-compliance.md:32-35`, `spec-coverage.md:31-34`,
`security.md:23-26`, `integration.md:34-38`). The diff is a **default unified
diff** — `diff.sh:197` runs `git diff "$BASE_REF...HEAD" -- . ':(exclude)thoughts/'`
with no `--no-prefix` and no `-U` override — so `@@ -old,+new @@` headers are
present and post-change numbers are computable without opening anything.

**`integration.md` is the asymmetry.** It receives two diff paths
(`:20-29`) and writes into a table whose Evidence cell format comes from
`report.md:113`, but the file contains **no `path:line` or `file:line` rule at
all**. The ticket names three gates; a fix that states the rule only in the
three leaves the fourth citing whatever it likes, through the same template.

### C3 — the marker block's links die with the branch

**Confirmed dead.** `GET repos/tobyS/chat-sustainability/branches/gh-40` →
404 "Branch not found". The live issue #40 body still ends with:

```
<!-- tsf:links -->
**tsf:** [spec](…/blob/gh-40/thoughts/factory/GH-40/spec.md) · [branch](…/tree/gh-40) · [journal](…/blob/gh-40/thoughts/factory/GH-40/journal.md) · [PR](…/pull/89)
<!-- /tsf:links -->
```

Three of the four links 404. The PR body's Artifacts section
(`thoughts/factory/GH-40/pr-body.md`) has four more of the same shape.

**Why the fix works.** The squash commit `0966ec4` carries the artifacts:

```
thoughts/factory/GH-40/journal.md        67 ++
thoughts/factory/GH-40/plan.md           98 ++
thoughts/factory/GH-40/pr-body.md        31 ++
thoughts/factory/GH-40/reports/…          4 files
thoughts/factory/GH-40/research.md      177 ++
thoughts/factory/GH-40/spec.md           41 ++
```

A squash commit's tree is the merge result, so every artifact the branch
committed is present at `<merge_sha>`, and that commit is on the default
branch — the one case GitHub's permalink documentation actually supports
("a permanent link to the specific version of a file"). By contrast, linking
to a *branch* commit sha after a squash merge links to an unreachable commit:
GitHub publishes no retention guarantee for those (only the security-guide
observation that they stay reachable "via their SHA-1 hashes in cached views"
until a support-initiated GC).

**`merge_sha` is already in scope.** `gh-write.sh:539-543` prints
`merge_sha: <sha>` on `result: merged`, and `cycle-report.md:40-41` already
consumes it. The post-merge writes are `cycle-dispatch.md:434-448` step 5
(a: `labels --clear`, b: `ref-delete`), a second apart — a `marker --ref` call
slots in there with no new read.

**The `marker` subcommand's shape.** `gh-write.sh:306-336`, three
branch-keyed URLs built at `:308-309`:

```sh
LINKS="[spec]($BASE_URL/blob/$BRANCH/thoughts/factory/$TICKET/spec.md) · [branch]($BASE_URL/tree/$BRANCH)"
[ "$JOURNAL" = "0" ] || LINKS="$LINKS · [journal]($BASE_URL/blob/$BRANCH/thoughts/factory/$TICKET/journal.md)"
[ -z "$PR" ] || LINKS="$LINKS · [PR]($BASE_URL/pull/$PR)"
```

`--branch` is mandatory (`:233`). The replace is done by splitting on the two
literal markers in jq (`:317-327`) — deliberately not by index, "so multi-byte
text in the human's body cannot shift an offset" — followed by a read-back that
reports `mismatch` (`:332-334`). Output is trailer-only: `result: ok | mismatch`.

Note the `[branch]` link is `tree/$BRANCH`, not a blob. `tree/<merge_sha>`
renders the whole repository at the landed state, which is a different thing
from "the branch" but is at least live; `commit/<merge_sha>` would show the
landed change itself. The ticket says "the branch link at the merge commit"
without settling which.

**The write-free merge cycle permits this.** `cycle-write-phase.md:190-199`
forbids repository writes ("no journal entry, no commit, no push, no marker
call") but explicitly allows GitHub writes: "Its only writes are the GitHub
calls row 12 already performed". Row 12 already makes two.

### C4 — the unquoted branch pattern

`plugins/tsf/commands/cycle.md:77`, the Step 2 scan invocation:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/scan.sh" --repo <owner/repo> … --pr-probe --branch-pattern <pattern> --factory-login <login> (--required-check "<name>" … | --no-ci)
```

The script path is quoted and `--required-check "<name>"` is quoted (line 82
explains why: commas in display names). `--branch-pattern <pattern>` is not.
The substituted value is the one argument in the whole plugin whose **real
value still contains shell metacharacters**: `templates/tsf/config.md:50`
requires the pattern to "contain `<n>`, the issue number, e.g. `gh-<n>`", and
`scan.sh:137` rejects a pattern without a literal `<n>`. In zsh, `gh-<n>`
parses as a redirection and the command fails before the script runs — which is
exactly the observed `no such file or directory: n`, three times (13:12Z,
13:16Z, 13:34Z).

`cycle.md:77` is the **only** place `scan.sh` is invoked anywhere in the
plugin, and the only command line that hands a literal `<n>` to a shell. Every
other `<…>` on that line is a placeholder for a plain value.

### C5 — the redundant local suite run

**Where it happens.** `references/cycle-dispatch.md:188-192`, row 6's opening:

> **Row 6 — `tsf:verify`, local verification red.** Before deciding anything,
> run the project's `verify` script (verification mode `local` only; in mode
> `ci` skip straight to row 7) **with the Bash tool's maximum timeout**, and
> keep its output in a file under `.tsf-tmp/` …

The suite runs unconditionally in mode `local`. The only existing bypass is the
mode check. Nothing consults `ci:` or `pr_head:` — even though
`cycle-dispatch.md:42-45` already establishes both as dispatcher facts before
any row runs.

**The sub-question about `checks:` is answered by the code.** `scan.sh:216-222`:

```
| if ($runs | length) == 0 then "pending"
  elif ([$runs[] | select(.status != "completed")] | length) > 0 then "pending"
  elif ([$runs[] | select(.conclusion | IN("failure","timed_out","action_required","cancelled"))] | length) > 0 then "failure"
  else "success" end
```

Zero matching required runs yields **`pending`**, never `success`. So
`ci: success` already implies `checks: ≥ 1`, and a `--no-ci` project yields
`ci: no-ci` (`:205-206`), a distinct value. No extra `checks:` condition is
needed; adding one would be dead code that implies the opposite.

**What the equality must be.** The scan runs at Step 2, `prepare` at Step 4,
so a push between them is possible and must not be trusted. The check is the
scan's `pr_head:` against `git rev-parse HEAD` **after** prepare — the very
comparison the ticket proposes, and `Bash(git rev-parse:*)` is already granted
in `cycle.md:4`. A `tsf:verify` ticket does carry `pr_head:` (`scan.sh:192`
includes `tsf:verify` in the probed five-state set).

**What the skip must not break.** Row 6's green branch does more than exit: it
runs `plan.sh criteria --out … --manual-out …` (`:198-203`) and dispatches
`tsf:manual-verify` when the manual count is non-zero and no
`reports/manual-<episode>.md` exists. Row 8 re-runs `plan.sh criteria` only "if
this cycle has not already" (`:246-247`). A skip that jumps straight to row 7
would drop the manual items; the skip has to land on the green branch, not past
it.

**The one sentence C5 falsifies** is DESIGN.md §7 `:623-624`:

> The local run gives the factory its evidence first and cheapest; CI confirms
> it on the real head before any gate spends tokens.

Also touched: DESIGN.md §4 row 6 (`:302-303`) and row 7 (`:304-308`), and
`cycle.md:175-179`, whose cross-reference "(Step 5's row 6)" is the only
mention of `verify` in the dispatcher command.

**Measured cost in the run:** 40 seconds on a trivial suite at 14:08Z, with
`ci: success` on `30266bd` already in hand.

### C6 — the undocumented permission mode

**Nothing in the plugin says it.** Tree-wide grep over `plugins/tsf/`:
`dangerously-skip-permissions` — 0 hits; `bypassPermissions` — 0; `permissionMode`
— 0; `permissions.deny` — 1, inside the TODO entry itself (`TODO.md:105`).

**The TODO entry (`TODO.md:84-114`) already contains the fix** almost verbatim,
including the deny-rule reasoning ("Deny rules match only the agent's own
command line, never the child processes of the plugin's scripts, so `push.sh`
and `gh-write.sh` keep working") and the hard constraint ("Claude Code exposes
the session's permission mode to a script in no documented way" — so no
preflight check is possible).

**The dispatcher's own dependence is real, and wider than the TODO frames it.**
`cycle.md:4`'s `allowed-tools` grants the seven plugin scripts, six git verbs
and a plugin-root `Read` glob — no `Write`, no `Edit`. Not covered:

1. **The five project contract scripts** — `prepare` (three call sites:
   `cycle.md:159`, `:166`, `cycle-dispatch.md:321`), `env_up`, `env_reset`,
   `env_check` (`cycle.md:169-173`), and `verify` (`cycle-dispatch.md:188-192`).
   Only `/tsf:init`'s project-side allowlist covers these.
2. **The `verify` run's shell redirect** into `.tsf-tmp/`
   (`cycle-dispatch.md:191-192`) — a redirect changes the command string, so a
   `Bash(<path>:*)` prefix entry does not match it.
3. **Every file the dispatcher writes** — the journal entry
   (`cycle-write-phase.md:35-39`), the comment body in the scratchpad (`:51-52`),
   three gate reports (`:113-120`), the integration report (`:161-164`), the
   verify-fix/manual reports (`:92-101`), park entries (`:211-216`, `:224-229`).
   `allowed-tools` has no `Write` or `Edit` at all.
4. **Reads of project files** — `.claude/tsf/config.md` (`cycle.md:49`) and
   `journal.md` (`cycle-dispatch.md:31-32`) fall outside the plugin-root glob.
5. **Pacing between writes** — "leave at least a second between them"
   (`cycle-write-phase.md:65-68`) names no command; `sleep` appears nowhere in
   the plugin and is granted nowhere.

Also ungranted anywhere: `merge-resolver`'s `git merge` / `git merge --abort`
(`agents/merge-resolver.md:62`, `:84`).

**DESIGN.md §5.3 (`:403-441`) already assumes the posture** but never names the
flag:

> The factory is expected to run inside a sandboxed environment (network/exec
> cage), with a dedicated clone (§8) — so the permission posture can be
> permissive *inside that boundary*. `/tsf:init` still writes a recommended
> allowlist (`gh api …`, `git` incl. push, the project's test commands) so
> unattended runs never stall on a prompt.

That parenthetical is **already wrong**: the shipped `/tsf:init` explicitly
excludes both (`init.md:368`, "**Never** `git push` and never `gh`"). C6's edit
to §5.3 should correct it in passing.

**The clone checklist** is `init.md:441-450`, five items; the sandbox appears
only as a filesystem grant (`:443`), and the last item says "Start claude in the
clone" with no flag (`:449`). The README's equivalent is `:82-125`, whose shell
block ends in a bare `claude` (`:90`). Both have an obvious insertion point.

**External facts confirmed against the Claude Code docs:**

- `--dangerously-skip-permissions` is "Equivalent to `--permission-mode
  bypassPermissions`".
- **"Deny rules block in every mode, including `bypassPermissions`."** And:
  **"Allow rules have no effect in `bypassPermissions`."** The deny-rule half of
  the TODO's plan is sound; the allow-list half becomes inert in that mode
  (`/tsf:init`'s allowlist still matters for any non-bypass posture).
- Deny is a guardrail, not a boundary: `Bash(git push *)` stops
  `git push origin main` but not `git -C . push origin main`. The docs say so
  explicitly.
- Deny reaches into compound commands and past leading assignments.

Three facts the 2026-09-20 TODO entry could not have known:

1. **A project's `.claude/settings.json` cannot set
   `defaultMode: "bypassPermissions"`** — "it doesn't take effect either, and
   the session starts in Manual mode". It must come from the CLI flag,
   `--settings`, user settings or managed settings. This *validates* C6's
   documentation-only approach: there is no checked-in way to do it.
2. **Two newer modes exist**, `auto` ("Everything, with background safety
   checks" — "Long tasks, reducing prompt fatigue") and `dontAsk`. The docs now
   steer away from bypass for precisely this use: "For background safety checks
   with far fewer permission prompts, use auto mode instead."
3. **Operational gotchas**: bypass refuses to start as root/sudo outside a
   recognized sandbox, and the first interactive session shows a one-time
   acceptance dialog (a `--bg` session is refused until it has been accepted).
   Administrators can disable the mode entirely via
   `permissions.disableBypassPermissionsMode`.

Fact 2 is a genuine open question for planning — see Open Questions.

## Defect Mechanism

Three of the six are true defects; the mechanism of each:

**C2 — patch coordinates in committed evidence.** `diff.sh pr-diff` writes a
unified diff to `.tsf-tmp/pr-diff.patch` (`diff.sh:183`, `:197`) and the gate
receives only that **path** (`cycle-dispatch.md:519-527`). The gate's
instruction says to cite "`path:line` **in the diff** or the post-change
source" (`plan-compliance.md:51`, `report.md:125`). Reading the patch top to
bottom, the only line numbers immediately at hand are the reader's own
positions in the patch file; the post-change numbers require decoding
`@@ -a,b +c,d @@`. The agent takes the cheap ones. The dispatcher cannot catch
it — invariant 3 (`cycle.md:24-37`) forbids it reading a report beyond the two
machine lines — so the wrong citation is committed to the branch
(`cycle-write-phase.md:113-120`) and linked from the pull request as evidence
(`:122-126`). The dossier agent, which reads everything, caught it in the run;
that is a backstop, not a fix.

**C3 — links outliving their ref.** `gh-write.sh:308-309` builds every artifact
URL from `$BRANCH`, the only ref the subcommand accepts (`:233`). The last
`marker` call of a ticket's life happens in the landing **decision** cycle
(`cycle-write-phase.md:166`, `:183`). The **merge** cycle then deletes the
branch (`cycle-dispatch.md:437-439`) and writes no marker (`:193` — "**no
marker call**"). Nothing after the deletion rewrites the block, so the issue
that a human returns to months later carries three 404s.

**C4 — shell expansion before the script runs.** The value of
`--branch-pattern` must literally contain `<n>` (enforced at `scan.sh:137`).
`cycle.md:77` shows it unquoted. The model reproduces the command line as
written; zsh parses `gh-<n>` as an input redirection from a file named `n`,
which does not exist, and the command dies before `scan.sh` is executed — so
the script's own usage error never appears, only the shell's. The dispatcher
then retries with quotes and proceeds, costing one failed call per session.

## Code References

**C1**
- `plugins/tsf/references/templates/result-block.md:7-12` — the maintenance note already naming every `## Return` as the span
- `plugins/tsf/references/templates/result-block.md:28-50` — the three-fence skeleton (the only copy)
- `plugins/tsf/references/templates/result-block.md:68-72` — the conditional `tsf-report` fence
- `plugins/tsf/references/templates/result-block.md:83-107` — the allowed-outcomes table
- `plugins/tsf/references/templates/result-block.md:154-175` — the parsing rules, incl. the one re-dispatch
- `plugins/tsf/agents/triage.md:87-103`, `research.md:96-112`, `plan.md:99-114`, `implement.md:145-183`, `verify-fix.md:78-98`, `manual-verify.md:76-107`, `dossier.md:126-141`, `merge-resolver.md:103-114` — the eight `## Return` sections
- `plugins/tsf/commands/cycle.md:225-229` — the dispatcher's own point-of-use Read

**C2**
- `plugins/tsf/agents/plan-compliance.md:51`, `spec-coverage.md:59`, `security.md:32`, `:70` — the citation rules
- `plugins/tsf/agents/integration.md:20-29`, `:48`, `:71-73`, `:95` — receives diffs, has no citation rule
- `plugins/tsf/references/templates/report.md:88-90`, `:111-113`, `:122-131` — the Evidence column, the example cell, the shared verdict bullet
- `plugins/tsf/scripts/diff.sh:182-218` — `pr-diff`: default unified diff, hunk headers intact
- `plugins/tsf/references/cycle-dispatch.md:519-533` — the gates' payload (paths only)

**C3**
- `plugins/tsf/scripts/gh-write.sh:28-33` — `marker`'s usage block
- `plugins/tsf/scripts/gh-write.sh:233-234` — `marker`'s validation
- `plugins/tsf/scripts/gh-write.sh:306-336` — the implementation
- `plugins/tsf/scripts/gh-write.sh:533-543` — `merge` printing `merge_sha:`
- `plugins/tsf/references/cycle-write-phase.md:48-49` — the cycle's marker call
- `plugins/tsf/references/cycle-write-phase.md:190-199` — the write-free merge cycle
- `plugins/tsf/references/cycle-dispatch.md:399-448` — row 12's merge cycle, steps 4–5
- `plugins/tsf/references/templates/pr-body.md:72-77` — the Artifacts links
- `plugins/tsf/commands/spec.md:107-110` — the other `marker` caller

**C4**
- `plugins/tsf/commands/cycle.md:74-84` — Step 2, the unquoted flag at `:77`
- `plugins/tsf/scripts/scan.sh:137` — the literal-`<n>` requirement
- `plugins/tsf/scripts/lib.sh:205-209` — `tsf_branch_for`

**C5**
- `plugins/tsf/references/cycle-dispatch.md:42-45` — `pr_head:` already an established fact
- `plugins/tsf/references/cycle-dispatch.md:188-212` — row 6
- `plugins/tsf/references/cycle-dispatch.md:214-237` — row 7 (`failure: ci`, `no-ci`)
- `plugins/tsf/references/cycle-dispatch.md:239-256` — row 8 (and the `plan.sh criteria` coupling)
- `plugins/tsf/scripts/scan.sh:216-225` — `ci:`/`checks:` derivation
- `plugins/tsf/scripts/scan.sh:73-78` — the header's `checks:` rationale
- `plugins/tsf/commands/cycle.md:175-179` — the maximum-timeout rule and its row-6 cross-reference
- `plugins/tsf/DESIGN.md:302-308` (§4 rows 6–7), `:617-627` (§7 precondition)

**C6**
- `plugins/tsf/TODO.md:84-114` — the entry to remove
- `plugins/tsf/DESIGN.md:403-441` — §5.3, incl. the already-wrong allowlist parenthetical at `:437`
- `plugins/tsf/DESIGN.md:1058-1060` — §11.3 "no worker holds `gh` or push rights"
- `plugins/tsf/commands/init.md:352-393` — the allowlist append (never widened)
- `plugins/tsf/commands/init.md:423-450` — the two checklists; the clone one at `:441-450`
- `plugins/tsf/README.md:82-125` — the runner section, bare `claude` at `:90`
- `plugins/tsf/commands/cycle.md:4` — `allowed-tools`

## Impact Analysis

*(For C3's `marker --ref`, the one shared-script change with existing callers.)*

### Existing Usages Found
- `plugins/tsf/commands/spec.md:109` — `marker --as ambient … --ticket GH-<n> --branch <branch>` (no `--journal`, no `--pr`)
- `plugins/tsf/references/cycle-write-phase.md:48-49` — `marker … --branch <branch> --journal`, every cycle
- `plugins/tsf/references/cycle-write-phase.md:85` — adds `--pr <number>` from the moment the PR exists
- `plugins/tsf/references/cycle-write-phase.md:121`, `:166`, `:183`, `:225`, `:238` — the same call in the gate, landing-decision, refusal and park sequences

### Current Contract
- Input: `--repo`, `--as`, `--credential`, `--issue N`, `--ticket GH-N`, `--branch B`, optional `--journal`, optional `--pr P`. `--branch` mandatory.
- Output: trailer only — `result: ok | mismatch`, `status:`, `detail:`.
- Assumptions: all three artifact/branch URLs derive from `--branch`; the block is replaced by marker-splitting and read back.

### Adaptation Requirements
- `gh-write.sh` — an optional `--ref <sha>` that supplies the ref for the **blob** URLs (and, per the ticket, the branch link). Absent, behaviour must stay byte-identical: every existing caller passes no `--ref`.
- `cycle-dispatch.md` row 12 step 5 — one new call after the merge, using `merge_sha:` from step 4.
- `cycle-write-phase.md` — the merge-cycle section (`:190-199`) currently says "no marker call"; that sentence becomes wrong.
- Per CLAUDE.md's "dispatcher owns every GitHub write" rule, a flag change also updates `cycle.md`, `spec.md` and `init.md` in the same commit — even where the call text does not change.

### Backward Compatibility Options
- **Option A — `--ref` optional, defaults to `--branch`.** Existing callers untouched; the merge cycle passes `--ref <merge_sha>`. Smallest diff; `--branch` stays mandatory (it still names the `[branch]` link and is what `--ref` defaults to).
- **Option B — `--ref` replaces `--branch` for links, `--branch` kept only for the branch link.** Cleaner semantics, but every caller's invocation has to be re-read to confirm it still means what it did.

## Architecture Documentation

Five repo-level rules in `CLAUDE.md` bind these corrections, and each names its
own same-commit span:

- **"tsf: the result block is a machine contract"** — `result-block.md`, each
  agent's `## Return`, `cycle.md` Step 6, `cycle-write-phase.md`. C1 lives
  entirely inside this span, and `result-block.md:7-12` already states it.
- **"tsf: the gate report is a machine contract"** — `report.md`, the three gate
  agents, `cycle-dispatch.md`. C2's span; note the rule says *three* gate agents
  while `report.md:8-12` names *four*.
- **"tsf: the dispatcher owns every GitHub write"** — a `gh-write.sh` flag
  change updates `cycle.md`, `cycle-write-phase.md`, `spec.md`, `init.md`. C3.
- **"tsf: the landing is a decision cycle plus a write-free merge cycle"** — a
  change to *which of the two cycles performs a write* updates `cycle.md`,
  `cycle-dispatch.md` row 12, `cycle-write-phase.md`, `cycle-report.md`,
  `journal-entry.md`. C3 adds a GitHub write to the merge cycle, so this rule
  fires too — though not the "never write to the branch" prohibition, which is
  about repository writes.
- **"tsf: `/tsf:init`'s allowlist append is the second sanctioned
  `settings.json` edit"** — "**Never widen it**". C6 must recommend deny rules
  as *documentation for the human*, never as something `/tsf:init` writes.

House style for a corrections plan (from TP-0037 and TP-0036): one phase per
correction, dependency-ordered, plus a final governance/documentation/release
phase. Phases that change a script flag land with every caller. Success criteria
are runnable in-session — `claude plugin validate`, `bash -n`, greps, fake-`gh`
fixtures in the scratchpad — with manual criteria reserved for what needs a live
GitHub run. Phase headings: TP-0037 used `C1 — <name>`, TP-0036 used
`<name> (C1)`.

## Historical Context (from thoughts/)

- `thoughts/shared/plans/2026-09-21-TP-0037-tsf-final-review-corrections.md` —
  the immediate shape precedent: 3 corrections → 4 phases, the fourth being
  governance + release; `## Implementation Approach` explains the grouping in
  two sentences.
- `thoughts/shared/plans/2026-09-20-TP-0036-tsf-review-corrections.md` — 12
  corrections → 11 phases with an explicit dependency argument; its closeout
  ends with the recommendation that produced this ticket: "the dispatcher is
  about a thousand lines of prose executed by a model, and the first real run
  will surface more."
- `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md:61-63,
  684-688, 860-862, 940-942` — why the templates are point-of-use reference
  files, and the `templates:` fallback. The 5,000-token compaction constraint
  is scoped to skill bodies, not agents.
- TP-0036 introduced the `ci:`/`checks:` split and the required-check names;
  CLAUDE.md records why collapsing them hides a merge conflict.
- `plugins/tsf/TODO.md:84-114` — C6's deferral, with the closing conditions
  already written out.

## Related Research

- `thoughts/shared/research/2026-09-21-TP-0037-tsf-final-review-corrections.md`
- `thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md`

## Open Questions

1. **C6 — bypass or `auto`?** The ticket's recorded decision (2026-09-27) is
   "the factory only works with `--dangerously-skip-permissions`; document it
   rather than build a fallback". The docs now document an `auto` mode —
   "Everything, with background safety checks", recommended for "Long tasks,
   reducing prompt fatigue" — and explicitly steer away from bypass: "For
   background safety checks with far fewer permission prompts, use auto mode
   instead." Neither mode can come from a checked-in project settings file, so
   the documentation shape is the same either way; only the recommended flag
   differs. This needs a decision before the README and checklist wording is
   written.
2. **C3 — the pull request body's Artifacts links** (the ticket's own question).
   After landing, `pr-edit --field body` could rewrite them to `blob/<merge_sha>/…`
   — but the dossier agent owns `pr-body.md`, the dispatcher may not compose
   pull-request text, and a merged PR page already offers Files/Commits. Rewrite
   them, or accept them as dead on a merged PR?
3. **C3 — what the `[branch]` link becomes.** `tree/<merge_sha>` (the repository
   at the landed state) or `commit/<merge_sha>` (the landed change itself)?
4. **C1 — how much of the vocabulary to inline.** The fence names and field
   order are shared and safe to duplicate; the per-step `outcome`/`next-step`
   values are already restated in every agent. Does each agent's skeleton show
   its own filled-in values (most useful, most duplication), or bracketed
   placeholders plus the existing per-branch bullets (least duplication)?
5. **C2 — does the rule extend to `integration.md`?** It has no citation rule
   today but writes into the same Evidence column, from the same template.

## tce Config Drift

None found. `.claude/tce/profile.md` (version `1.2.0`) accurately describes the
four plugins, the `claude plugin validate` test commands, the absent
typecheck/lint, and the code map including every `plugins/tsf/` directory this
research touched; `.claude/tce/tickets.md` matches the tmt backend in use.
