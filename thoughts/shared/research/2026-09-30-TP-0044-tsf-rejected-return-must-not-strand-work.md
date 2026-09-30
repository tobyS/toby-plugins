---
date: 2026-09-30T08:47:55Z
git_commit: 351daadd0959c994275cd8cde60c96069e166232
branch: main
repository: toby-plugins
topic: "TP-0044: tsf — a rejected result block must not strand pushed work"
tags: [research, codebase, tsf, implement, batching, journal, commit-trailer, pull-request]
status: complete
last_updated: 2026-09-30
---

# Research: TP-0044 — a rejected result block must not strand pushed work

**Date**: 2026-09-30T08:47:55Z
**Git Commit**: 351daadd0959c994275cd8cde60c96069e166232
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0044 asks how tsf can be made resilient and self-healing for the state
chat-sustainability GH-41 is stuck in: an implement cycle built, verified,
committed and pushed all three increments plus `pr-body.md`, its result block
was then rejected, and no cycle since has been able to advance the ticket. The
ticket proposes three corrections — derive the built set from a `Tsf-Increment:`
commit trailer (C1), split the no-progress guard into two conditions (C2), and
open the pull request whenever it is missing (C3) — and asks four questions for
research: where `Tsf-Increment:` belongs, where `built:` is composed, whether
the guard has other restatements, and what a resume does with a git-derived
built set.

## Summary

The deadlock is real and reproducible from the shipped text, but **the ticket
names the wrong proximate cause, and two of its premises do not hold.**

What the research establishes:

1. **Four mechanisms sit between GH-41 and verification, not three**, and they
   fire in a definite order. The one that parks the ticket today is
   `MANDATORY OUTPUT`'s "at least one new commit for implement"
   (`plugins/tsf/commands/cycle.md:236-243`) — an invalid-return detector in
   Step 6. The no-progress guard (`plugins/tsf/references/cycle-dispatch.md:217-222`)
   is downstream of it and has never yet been reached on this ticket. The
   journal's own wording confirms the order: *"agent returned no valid result
   twice (no new commit: …)"* is the invalid-return park, not the guard's.
2. **`plan.sh` cannot tell the dispatcher which increments a plan has.** `check`
   prints `increments: 3`, a count; the numbers exist only inside the criteria
   file, which `cycle.md` invariant 3 forbids the dispatcher to open
   (`plugins/tsf/scripts/plan.sh:294`, `:324-329`;
   `plugins/tsf/references/cycle-dispatch.md:266-267`). So C2's second condition
   — "increments remain" — is **not computable today** by any reader that is
   allowed to compute it.
3. **A commit trailer cannot heal GH-41.** Its three implementation commits
   carry only `Co-Authored-By:`; a trailer-derived built set for that branch is
   empty. Measured, not inferred (§Defect Mechanism, step 6). The ticket's
   acceptance criterion "GH-41's branch as it stands today yields `1,2,3`" is
   unachievable under C1 as written, and its own Out of Scope forbids the
   workaround.
4. **The trailer's failure direction is safe for `Tsf-Resolution` and unsafe for
   a built set.** git returns the empty string indistinguishably for "no such
   trailer", "trailer present but the block was not recognized", and "no body"
   — and a single non-trailer line in the final paragraph makes every trailer in
   it vanish silently. For the logic head, empty → `logic` → one avoidable
   re-approval. For a built set, empty → "not built" → the factory rebuilds an
   increment that is already in the branch.
5. **C3 is simpler than the ticket assumes, and simpler than the ticket's own
   framing allows.** The scan does not probe for a pull request in
   `tsf:implement` at all (`pr: skipped`, `plugins/tsf/scripts/scan.sh:192`), so
   "no pull request exists" is not a fact in hand when an implement return is
   processed. But `pr-create` is idempotent by construction — 422 → `exists`
   with the number (`plugins/tsf/scripts/gh-write.sh:432-448`) — so the
   condition never needs to be known. Opening it on *any* implement return whose
   `next-step:` is `verify`, with no mode conditional, is both correct and
   cheaper to state than the two special cases it replaces.

A fifth, smaller gap: the implement agent has **no legal return** for "the built
set already covers the plan". The only instruction covering an empty remainder
is `plugins/tsf/agents/implement.md:74-82`, which is scoped to unsatisfiable
dependencies and prescribes `outcome: blocked`.

## Detailed Findings

### The built set: where it is defined, composed and consumed

The definition lives in one place,
`plugins/tsf/references/templates/journal-entry.md:52-67` ("The increments
line"): the built set is *"the union of the `- Increments:` lines of its
`step: implement` entries since it most recently entered `tsf:implement` — that
is, since the newest entry whose `- Label:` is `tsf:implement` and whose `step:`
is not `implement`."*

`built:` is composed at exactly **one** site:
`plugins/tsf/references/cycle-dispatch.md:213-216` (row 5). `cycle.md` never
computes it; `cycle-dispatch.md:573` only lists it among row 5's payload fields.
That answers the ticket's second research question: **one site, not several.**

The consumer is the agent: `plugins/tsf/agents/implement.md:41-42` declares
`batch:` and `built:` as fresh-mode-only payload fields, and `:74` instructs
*"Skip every increment in `built:`"*.

The line is written only by an agent's `tsf-journal` block
(`plugins/tsf/agents/implement.md:200`, `:247`), and it is **fresh mode only**
(`:206-207`) — omitted in rework, fix and format-fix.

### Dispatcher-written park entries cannot carry the line

`plugins/tsf/references/templates/journal-entry.md:130-134`: *"When no agent
result exists, the dispatcher writes the whole entry."* The two relevant shapes
are the twice-invalid/failed-write entry (`:217-224`) and the format-question
entry (`:236-244`). Neither has an `- Increments:` line, and the only
agent-derived values that survive into either are `- Commits:` and, in the
format park, `- Resume at:`.

This is the mechanical fact behind the deadlock: the work is pushed before the
return is judged, and the entry written when the return is refused has no field
in which to record what was built.

### The four mechanisms, in firing order

**1. `MANDATORY OUTPUT` (`plugins/tsf/commands/cycle.md:236-243`).** Verbatim on
the point at issue: *"unless `outcome: blocked`, the step's artifact must exist
on disk under `thoughts/factory/GH-<n>/` — … at least one new commit for
implement, verify-fix, rework and merge-resolver — and, for a fresh-mode
implement that returns `next-step: verify`, a committed `pr-body.md`
(`git ls-files`; the pull request opens from it) … If it does not, treat the
return as invalid."*

A cycle with nothing left to build makes no commit, so the return is invalid
here. One re-dispatch, then park `tsf:needs-human`
(`plugins/tsf/commands/cycle.md:279-281`). The `mode: format-fix` carve-out at
`:245-248` exempts only that mode's *`pr-body.md`* requirement, not the commit
requirement — format-fix satisfies the latter with its plan-repair commit.

**2. The result-block parse.** `plugins/tsf/references/templates/result-block.md:168-180`,
rules 1-5. The row `implement | continued | tsf:verify | verify` exists (`:98`)
and `commits:` legally takes `none`
(`plugins/tsf/agents/implement.md:188`), so a "nothing left to build" return is
*syntactically* valid — it is mechanism 1 that rejects it.

**3. The no-progress guard (`plugins/tsf/references/cycle-dispatch.md:217-222`).**
*"When the return's `- Increments:` line adds no number the built set did not
already have, the cycle achieved nothing: park `tsf:needs-human` … a
plan-length loop of empty cycles is the failure this bound exists to stop."*
Restated once, at `plugins/tsf/references/templates/journal-entry.md:60-64`.
Those are the **only two** statements — answering the ticket's third research
question. Reader-facing paraphrases exist at `plugins/tsf/README.md:191-196`
(*"a cycle that builds nothing new parks the ticket"*) and
`plugins/tsf/DESIGN.md:1792-1798`.

Note that it is **not** in Step 6's validation sequence — it lives in row 5,
which is why an invalid return short-circuits before it.

**4. Opening the pull request (`plugins/tsf/references/cycle-write-phase.md:71-98`).**
Two triggers: a fresh-mode implement whose `next-step:` is `verify` (the last
batch), and *"a format-fix return whose `resume-to:` was `verify`"* — the clause
TP-0043 added. It sits between step 3 (push) and step 4 (marker), and step 4's
marker call takes `--pr <number>`.

### The pull request: what is known when

`plugins/tsf/scripts/scan.sh:192` gates the whole pull-request probe on the
state label being one of `tsf:verify`, `tsf:dossier`, `tsf:needs-review`,
`tsf:rework`, `tsf:landing`. A `tsf:implement` ticket's record therefore reads
`pr: skipped`, `pr_head: -`, `ci: skipped`. The probe is additionally gated on
`--pr-probe` (`:190`).

So at the moment an implement return is processed, the dispatcher does not know
whether a pull request exists, and cannot learn it from the scan.

It does not need to. `plugins/tsf/scripts/gh-write.sh:57-65` documents
`pr-create` as *"A 422 means a pull request for this head/base already exists:
it is looked up and reported, so a re-run is idempotent"*, with
`result: created | exists` and `number:` in both cases (implementation
`:422-450`). `plugins/tsf/references/cycle-write-phase.md:84-85` already leans
on exactly this: *"In every case `exists` below is a fine answer, which is what
makes this safe to reach twice."*

`plugins/tsf/scripts/gh-read.sh:300-335` (`pr`) is the alternative: `exists: no`
with `result: ok` — absence is a success, not an error. It costs one extra REST
read that `pr-create`'s own 422 path makes unnecessary.

Rows that presuppose an open pull request: row 6's CI-skip branch
(`cycle-dispatch.md:232-240`, needs `ci:` and `pr_head:`), row 7 entirely
(`:270-293`, routes on `ci:`), row 9 (`:316-319`, runs `gh-read.sh pr --out`).
Row 5 mentions no pull-request field at all, and row 8 uses none.

### `plan.sh` knows the increment numbers and does not print them

`plugins/tsf/scripts/plan.sh` has two subcommands. `check` prints
`increments: <n>` / `addenda: <n>` / `result:` / `detail:` (`:293-299`);
`criteria` prints `criteria: <n>` / `manual: <n>` / `result:` / `detail:`
(`:301-342`) — and `criteria:` counts *criterion lines*, not increments, because
an increment carrying both a `**Verification:**` and a `**Manual:**` field
contributes two (`:322-330`).

Increment numbers are recognized at `:174-190` and kept **as strings**, never
normalized numerically, so `01` and `1` are distinct. Uniqueness is enforced in
the shared `PROBLEM` awk (`:260-265`). The numbers themselves reach only three
places, none of them stdout: the private `$TSF_TMP/stream` (removed by
`lib.sh`'s EXIT trap), and the prose of the `--out` and `--manual-out` files
(`Increment %s (%s)`, `:324`, `:328`).

`plugins/tsf/references/cycle-dispatch.md:266-267` closes the loophole
explicitly: *"Do not open either file — the counts are all you need."*

Consequence for C2: from what the dispatcher may read, a plan numbered 1,2,3 is
indistinguishable from one numbered 1,2,7. A count-only comparison
(`|built| >= increments`) is correct only for contiguous 1..n numbering, which
nothing enforces — the template shows `### Increment <n>: <name>` and `plan.sh`
validates only uniqueness.

### `diff.sh` is the right home for a git-derived built set, and has the idiom

`plugins/tsf/scripts/diff.sh` has seven subcommands (`pr-diff`, `files`,
`logic-head`, `main-delta`, `decision-head`, `ancestor`, `clean`), one
`case "$MODE"` dispatch, records printed as aligned `key: value` lines with
`result:` + `detail:` trailers, *"Every reported outcome exits 0; only usage
errors and 'not a git repository' exit 1"* (`:119-120`). It makes no network
calls and uses only `tsf_project_root` and `tsf_tmp` from `lib.sh`.

The walk a built-set subcommand would reuse is `logic-head`'s (`:259-279`):
`git rev-list --first-parent HEAD -- . ':(exclude)thoughts/'` fed to a
`while read` loop through a here-doc (so loop state survives the loop), with
per-commit `git show -s --format=…` reads behind a cheap parent-count
precondition.

The trailer read, verbatim (`:270-274`):

```bash
        # (b) A resolution the merge-resolver classified mechanical. Anything
        # else -- logic, or no trailer at all -- counts as the logic head.
        if [ "$(git show -s --format='%(trailers:key=Tsf-Resolution,valueonly,separator=%x2C)' "$CANDIDATE" | tr -d '[:space:]')" = "mechanical" ]; then
            continue
        fi
```

A new `--base`-taking subcommand would also copy the base-ref resolution block,
which is duplicated verbatim in all three subcommands that take `--base`
(`:185-191`, `:222-225`, `:297-300`) — there is no helper for it, and `origin`
is hardcoded in each copy.

Note the domain boundary this implies: `diff.sh` may walk the branch, but
`plan.sh` is *"the only thing that parses a plan"* (CLAUDE.md). A `diff.sh`
subcommand taking `--plan` would cross it.

### The `Tsf-Resolution` precedent spans five sites in one agent file

From `plugins/tsf/agents/merge-resolver.md`: the `## CRITICAL` closing `ONLY`
bullet (`:29-30`), the classification step in `## Process` (`:73-83`), **bullet
2 of 4** in `## Commit rules` (`:94-99`), a post-skeleton sentence in
`## Return` (`:132-133` — *"Your mechanical/logic classification is **not** in
the result block — it is the `Tsf-Resolution` commit trailer, above"*), and a
`## What NOT to Do` bullet (`:148-149`).

The authority is `plugins/tsf/references/templates/result-block.md:191-219`
(`# The resolution trailer`), which states the positional requirement — *"as the
last line of its commit message after a blank line"* — and the fail-closed rule.

`plugins/tsf/agents/implement.md` contains **no** occurrence of "trailer" and no
`Tsf-*` string. Its positional equivalents are: `## Commit rules` (`:166-173`,
where a bullet would follow the convention bullet at `:169-170`), the
`## CRITICAL` `ONLY` bullet (`:28-29`), `## What NOT to Do` (`:254-264`), and the
post-skeleton slot in `## Return` (`:206-207`). Its `tools:` list is
byte-identical to merge-resolver's; only `model:` differs (`sonnet` vs `opus`).

### Git trailer mechanics (external)

Three facts bear on C1's feasibility.

**Version floor: git 2.22.0** (2019-06-07) for `key=`, `valueonly` and
`separator=`, which arrived together; the bare `%(trailers)` is much older. The
repo already depends on this through `diff.sh:272`, and the local toolchain is
git 2.54.0 — verified, and the placeholder was smoke-tested against a real
commit in the chat-sustainability clone.

**The trailer block must be the last paragraph, and must be *all* trailers
unless it also contains a git-generated trailer.** git's generated-prefix list
is closed and two elements long — `Signed-off-by: ` and
`(cherry picked from commit ` — and **`Co-authored-by:` is not one of them**. So
a single prose line in the final paragraph makes every trailer in it vanish from
`%(trailers:key=…)`, with no error. The implement agent's commits do end with a
clean all-trailer paragraph (`Co-Authored-By:`), so a `Tsf-Increment:` line
alongside it parses — but the tolerance is zero.

**Empty output is ambiguous**: it means "no such trailer", "block not
recognized", or "no body", indistinguishably. For `Tsf-Resolution` the ambiguity
is absorbed by failing closed. A built set has the opposite polarity.

Also worth recording: the existing read omits `unfold`, so a folded value would
arrive with an embedded newline; and squash merges are not a trailer-preserving
transport (three of GitHub's four message settings drop trailers, the fourth
buries them mid-message on a multi-commit pull request). The latter is out of
scope here — the built set is read on the branch, pre-merge — but it is the same
lesson as tsf's own `--ref`/merge-commit rule.

Sources: [pretty-formats](https://git-scm.com/docs/pretty-formats),
[pretty-formats 2.21.0](https://git-scm.com/docs/pretty-formats/2.21.0) vs
[2.22.0](https://git-scm.com/docs/pretty-formats/2.22.0),
[git RelNotes 2.22.0](https://github.com/git/git/blob/master/Documentation/RelNotes/2.22.0.adoc),
[git-interpret-trailers](https://git-scm.com/docs/git-interpret-trailers),
[trailer.c](https://github.com/git/git/blob/master/trailer.c),
[SubmittingPatches](https://github.com/git/git/blob/master/Documentation/SubmittingPatches),
[githooks](https://git-scm.com/docs/githooks),
[Configuring commit squashing](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/configuring-commit-squashing-for-pull-requests).
One source was 403-blocked and is flagged unverified in the agent's report (a
lore.kernel.org patch mail); the version conclusion rests on the versioned docs
and release notes instead.

## Defect Mechanism

**Intended behaviour.** An implement cycle builds at most `implement_batch`
increments, pushes them, and records which in the journal; the next cycle skips
those and takes the next batch; the batch that finishes the plan returns
`next-step: verify` and the write phase opens the pull request
(`plugins/tsf/references/templates/journal-entry.md:52-58`,
`plugins/tsf/references/cycle-dispatch.md:208-226`,
`plugins/tsf/references/cycle-write-phase.md:73-78`).

**Actual behaviour on GH-41.** The ticket has been at `tsf:implement`/
`tsf:needs-human` since 2026-09-27 with the whole plan built and pushed.

**The divergence, step by step, each step evidenced.**

1. `2026-09-27T18:07Z` — the implement agent built increments 1-3, wrote and
   committed `pr-body.md`, and pushed: `1183108 29801ed b7c2955 b81f440`. It
   also wrote an addendum whose `**Verification:**` field `plan.sh` could not
   parse.
2. `plan.sh check` returned `result: invalid`, which
   `plugins/tsf/commands/cycle.md:250-285` makes an invalid return. Under tsf
   1.1.1 this park was `tsf:needs-human` with no `- Resume at:` line.
3. The park entry was written by the dispatcher, so it recorded
   `Commits: 1183108 29801ed b7c2955 b81f440 353f939` and **no**
   `- Increments:` line — the shape at
   `plugins/tsf/references/templates/journal-entry.md:217-224` has no such
   field. **This is the point of no return**: the branch is now permanently
   ahead of the journal.
4. The built set is anchored on *"the newest entry whose `- Label:` is
   `tsf:implement` and whose `step:` is not `implement`"*. For GH-41 that is the
   `2026-09-27T18:03Z` plan entry; every `step: implement` entry after it is a
   dispatcher-written park. The union is empty **and no future cycle can make it
   non-empty**, because only an accepted agent return can add to it.
5. The human repaired the plan by hand in `f116634` (author
   `Tobias Schlitt <tobias@schlitt.info>`, 2026-09-28 09:34) — outside the
   factory, so TP-0043's reply-driven format-fix path was never entered.
   `plan.sh check --plan …` on the branch now returns `result: ok`: **the
   original cause is gone and the deadlock outlived it.**
6. `2026-09-29T13:38Z`, on tsf 1.3.0 with TP-0043's artifacts: row 5 dispatched
   `mode: fresh` with `built: none`. The agent read the plan, found all three
   increments already in the branch history, built nothing, and said so. Its
   return was rejected by `MANDATORY OUTPUT` ("at least one new commit for
   implement"), re-dispatched once, rejected again, and the ticket parked
   `tsf:needs-human`. The journal records it as *"agent returned no valid result
   twice (no new commit: …)"* — the invalid-return park, confirming the detector.
7. Had that detector passed, the no-progress guard would have parked it next: the
   return's `- Increments:` line adds nothing the (empty) built set lacks.
8. Had both passed, the pull request would still be missing: `gh pr list --head
   gh-41 --state all` returns empty after four implement cycles, and no row
   other than the two in `cycle-write-phase.md:73-85` ever opens one.

**Why a trailer-derived built set does not break the cycle for this ticket.**
Measured on the branch: the three implementation commits' messages end with
`Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` and nothing else, and
`git show -s --format='[%(trailers:key=Tsf-Resolution,valueonly,separator=%x2C)]'
1183108` prints `[]`. A `Tsf-Increment:`-derived built set for `gh-41` is
therefore empty, exactly as the journal-derived one is — so steps 6 and 7 repeat
unchanged.

**Contiguity, for the record.** GH-41's plan has increments 1, 2, 3 (`:90`,
`:134`, `:168`) and one addendum on increment 1 (`:205`), and the three `feat`
commit subjects match the three increment names in order. That mapping is
evident to a reader but is precisely the inference the ticket's Out of Scope
forbids the factory from making.

## Code References

- `plugins/tsf/commands/cycle.md:236-243` — `MANDATORY OUTPUT`; "at least one new commit for implement"
- `plugins/tsf/commands/cycle.md:245-248` — the `mode: format-fix` carve-out (`pr-body.md` only)
- `plugins/tsf/commands/cycle.md:250-290` — `THE PLAN MUST PARSE`, its note, two re-dispatches, `tsf:needs-answer` park
- `plugins/tsf/commands/cycle.md:279-281` — the single-re-dispatch bound the other three detectors share
- `plugins/tsf/commands/cycle.md:292-293` — the branch check
- `plugins/tsf/commands/cycle.md:26-37` — invariant 3 (what the dispatcher may not read)
- `plugins/tsf/commands/cycle.md:90`, `:117-140` — Step 3 decides from scan records only, plus one `pr-state` read
- `plugins/tsf/references/cycle-dispatch.md:208-226` — row 5: `batch:`, `built:`, the no-progress guard
- `plugins/tsf/references/cycle-dispatch.md:266-267` — "Do not open either file — the counts are all you need"
- `plugins/tsf/references/cycle-dispatch.md:232-240` — row 6's CI-skip branch (needs `ci:`, `pr_head:`)
- `plugins/tsf/references/cycle-dispatch.md:145-155` — row 1's `- Resume at:` override into `mode: format-fix`
- `plugins/tsf/references/cycle-dispatch.md:573` — row 5's payload field list
- `plugins/tsf/references/templates/journal-entry.md:36` — the `- Increments:` line in the entry shape
- `plugins/tsf/references/templates/journal-entry.md:52-67` — "The increments line": built set, guard, mode scope
- `plugins/tsf/references/templates/journal-entry.md:130-134` — dispatcher writes the whole entry when no result exists
- `plugins/tsf/references/templates/journal-entry.md:217-224` — the twice-invalid park shape (no `- Increments:`)
- `plugins/tsf/references/templates/journal-entry.md:236-256` — the format-park shape and `- Resume at:`
- `plugins/tsf/references/cycle-write-phase.md:71-98` — "Opening the pull request", both triggers, `--pr`
- `plugins/tsf/references/cycle-write-phase.md:55-57` — intermediate batches post no comment
- `plugins/tsf/references/cycle-write-phase.md:237-251` — parks without an agent result
- `plugins/tsf/references/templates/result-block.md:87-113` — the allowed-outcomes table
- `plugins/tsf/references/templates/result-block.md:135-144` — the two `implement | continued` rows
- `plugins/tsf/references/templates/result-block.md:165-189` — parsing rules and the one re-dispatch note
- `plugins/tsf/references/templates/result-block.md:191-219` — `# The resolution trailer`
- `plugins/tsf/agents/implement.md:40-46` — payload fields (`mode:`, `batch:`, `built:`, `resume-to:`)
- `plugins/tsf/agents/implement.md:74-82` — "Skip every increment in `built:`"; the `blocked`-if-nothing-remains clause
- `plugins/tsf/agents/implement.md:104-115` — `pr-body.md`, last batch only
- `plugins/tsf/agents/implement.md:140-163` — format-fix mode
- `plugins/tsf/agents/implement.md:166-173` — `## Commit rules`
- `plugins/tsf/agents/implement.md:206-252` — `## Return`, the `- Increments:` note, "which values go together"
- `plugins/tsf/agents/merge-resolver.md:94-99` — the trailer instruction (bullet 2 of 4)
- `plugins/tsf/agents/merge-resolver.md:132-133` — the classification is not in the result block
- `plugins/tsf/scripts/diff.sh:46-71` — `logic-head`'s header block
- `plugins/tsf/scripts/diff.sh:259-279` — the first-parent walk idiom
- `plugins/tsf/scripts/diff.sh:270-274` — the `Tsf-Resolution` trailer read
- `plugins/tsf/scripts/diff.sh:128-178` — usage, flag table, per-mode requirements, repo guard
- `plugins/tsf/scripts/plan.sh:293-299` — `check`'s record (`increments:` is a count)
- `plugins/tsf/scripts/plan.sh:174-190` — increment heading recognition and number extraction
- `plugins/tsf/scripts/plan.sh:322-330` — criteria emission; numbers appear only in prose
- `plugins/tsf/scripts/scan.sh:51-71` — the record definition
- `plugins/tsf/scripts/scan.sh:190-204` — the state-gated pull-request probe
- `plugins/tsf/scripts/gh-write.sh:57-65`, `:422-450` — `pr-create`, `created | exists`
- `plugins/tsf/scripts/gh-read.sh:300-335` — `pr`, `exists: no` as a success
- `plugins/tsf/TODO.md:8-33` — the adjacent deferred item (a cycle that never returns)
- `plugins/tsf/README.md:191-199` — the reader-facing batching and pull-request description
- `plugins/tsf/DESIGN.md:1792-1798` — decision 59, "Implementation is batched"

## Architecture Documentation

- **Counters are read from disk, never from conversation** — episode from the
  journal's last `- Episode:`, verify-fix attempt and gate round from report
  filenames, landing attempt from `step: landing` entries carrying `- Attempt:`.
  The built set was built to this pattern; the pattern itself is sound, and what
  failed is that this particular counter's only writer can be refused.
- **One source of truth, not two that must agree** — established by TP-0043 in
  `plan.sh`, where the substance flag lives in the parser so `check` and
  `criteria` agree by construction. Sibling precedents: tle's live pass state in
  the verify report rather than the goal file, and tmt's status enum existing
  only in `lib.sh`.
- **Scripts take arguments, never project config** — every tsf script receives
  what it needs on the command line; `config.md` is prose the commands read.
- **The dispatcher owns every GitHub write, and reads no artifact content**
  (invariant 3). Artefacts move between steps **by path**: the diff, the
  criteria, the review brief, `pr-body.md`.
- **Each script owns one domain** — `plan.sh` is the only plan parser, `diff.sh`
  the only place git facts are computed, `gh-write.sh`/`push.sh` the only write
  paths.
- **Idempotence is the factory's standing answer to a step reached twice** —
  `pr-create`'s 422 → `exists`, `ref-create`'s `exists`, `env_up`'s required
  idempotence. TP-0043 relied on it to make the pull-request step safe to reach
  from two routes.
- **Fail-closed where ambiguity is cheap** — the logic head treats a missing
  trailer as `logic`; the cost is one avoidable re-approval.

## Historical Context (from thoughts/)

- `thoughts/shared/tickets/TP-0036-tsf-review-corrections.md:233-239` — where
  batching was decided: *"**Progress lives in the journal**: each implement
  entry records which increments are done"* and *"**No-progress guard**: an
  implement cycle that returns without a newly done increment counts as
  `blocked` and parks the ticket. Derived from the journal alone."* Both arrive
  as already-agreed bullets.
- `thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md:458-460`
  — *"Prior research never considered this. None of the three slice research
  documents discusses batching, per-cycle scope or resumability of
  implementation — it is an unexamined premise, not a researched decision."*
  **Git-derivation of the built set was never weighed against the journal.** The
  only question handed to planning (`:369-372`) was the line's *shape*, not its
  location.
- `thoughts/shared/plans/2026-09-20-TP-0036-tsf-review-corrections.md:1165-1167`
  — the one place a repo-side progress artifact was considered and rejected, and
  it was a **marker file**, not git history: `prepare`'s `git clean -fd` deletes
  it by design.
- `thoughts/shared/plans/2026-09-20-TP-0036-tsf-review-corrections.md:1168-1170`
  — *"The batching itself has no automated test — it is prompt behaviour, and its
  criteria are the manual ones above"*, and both manual criteria were left
  unticked.
- `thoughts/shared/research/2026-09-18-TP-0034c-tsf-landing-release.md:463-479` —
  the three options for the logic-head exclusion. Option B (a trailer) records
  the reason the journal was rejected as the carrier: *"the journal is not
  readable from a script that takes only arguments"*.
- `thoughts/shared/plans/2026-09-19-TP-0034c-tsf-landing-release.md:140-146` —
  the decision: a purely git-visible rule *"would exclude a *logic* resolution
  too … silently leaving a stale approval valid"*, so the classification becomes
  a trailer. Recorded as a deliberate addition, since §3.5 named no mechanism.
- `thoughts/shared/plans/2026-09-28-TP-0043-tsf-format-problems-never-reach-a-human.md:569-581`
  — the paper walkthrough that found the pull-request gap: *"A format park on
  the last batch happens at Step 6, before the write phase reaches the
  pull-request step — so the pull request was never opened, and the resumed
  `format-fix` return, not being fresh mode, would not have opened it either.
  The ticket would have reached `tsf:verify` with `pr: none` and stalled at
  row 6."* Fixed by adding the second trigger. **The same class of gap, found by
  walkthrough rather than by a rule — and patched per-route.**
- `thoughts/shared/plans/2026-09-28-TP-0043-tsf-format-problems-never-reach-a-human.md:242-253`
  — where "one notion of empty" was established, and why the redundant guard was
  kept as belt-and-braces rather than as a second definition.

## Related Research

- `thoughts/shared/research/2026-09-28-TP-0043-tsf-format-problems-never-reach-a-human.md`
  — the same GH-41 run, one layer up (the parser and the retry paths). Contains
  nothing on batching or the pull request; those are in its plan's Phase 3 log.
- `thoughts/shared/research/2026-09-20-TP-0036-tsf-review-corrections.md` — where
  batching, the built set and the no-progress guard originate.
- `thoughts/shared/research/2026-09-18-TP-0034c-tsf-landing-release.md` — the
  `Tsf-Resolution` trailer's option analysis.

## Impact Analysis

### Existing Usages Found

- `plugins/tsf/references/cycle-dispatch.md:213-216` — the only composer of `built:`
- `plugins/tsf/agents/implement.md:41-42`, `:74` — the only consumer of `built:`
- `plugins/tsf/references/templates/journal-entry.md:52-67` — the only definition of the built set; `:60-64` the guard's second statement
- `plugins/tsf/references/cycle-dispatch.md:217-222` — the guard's primary statement
- `plugins/tsf/agents/implement.md:200`, `:247`, `:206-207`, `:251-252` — the four places the agent is told about `- Increments:`
- `plugins/tsf/references/templates/result-block.md:135-144` — the two `implement | continued` rows and the fresh-mode scope
- `plugins/tsf/scripts/diff.sh:270-274` — the sole existing trailer reader
- `plugins/tsf/references/cycle-write-phase.md:73-85` — the two pull-request triggers
- `plugins/tsf/README.md:191-199`, `plugins/tsf/DESIGN.md:1792-1798`, `plugins/tsf/templates/tsf/config.md:90-92` — reader-facing restatements

### Current Contract

- **`built:`** — input: a comma-separated increment-number list or `none`; produced from journal text; consumed only by the implement agent in fresh mode.
- **`- Increments: <list> of <total>`** — written only by an accepted fresh-mode agent return; read by the next cycle's row 5 and by the guard.
- **`plan.sh check`** — output `increments:` (count), `addenda:` (count), `result: ok | invalid`, `detail:`. Exit 0 on every reported outcome.
- **`diff.sh <sub>`** — aligned `key: value` record, `result:` + `detail:` trailer, exit 0 on every reported outcome; usage errors and "not a git repository" exit 1.
- **`gh-write.sh pr-create`** — `number:`, `url:`, `head:`, `result: created | exists`; idempotent by 422 lookup.
- **`MANDATORY OUTPUT`** — assumes every non-`blocked` implement return produces at least one new commit.
- **Implicit assumption that fails**: that an increment's built-ness is recorded by the same act that reports it.

### Adaptation Requirements

- `plugins/tsf/references/cycle-dispatch.md:213-222` — `built:`'s source and the guard's conditions both change; row 5 is one edit site for both.
- `plugins/tsf/references/templates/journal-entry.md:52-67` — the definition moves or is demoted to narrative; the guard's restatement must agree.
- `plugins/tsf/commands/cycle.md:236-248` — the commit requirement needs an exception for a legitimately empty implement cycle, or the cycle needs something to commit.
- `plugins/tsf/agents/implement.md:74-82` — needs a legal path for "the built set covers the plan"; `:166-173` and its four `- Increments:` sites change if a trailer is added; the trailer would occupy the five positional slots the merge-resolver precedent occupies.
- `plugins/tsf/scripts/plan.sh:293-299` — would need to print the increment numbers for "increments remain" to be computable at all.
- `plugins/tsf/scripts/diff.sh` — a new subcommand: one `usage()` line, one initializer, one flag arm, one per-mode requirement arm, one dispatch arm, plus the header entry.
- `plugins/tsf/references/cycle-write-phase.md:73-85` — the trigger becomes a condition rather than two routes.
- `plugins/tsf/references/templates/result-block.md` — the outcomes table and, if a trailer is added, a fifth numbered part.
- Reader-facing: `plugins/tsf/README.md:191-199`, `plugins/tsf/DESIGN.md` §6.6 and decision 59, `plugins/tsf/templates/tsf/config.md:90-92`.
- CLAUDE.md same-commit spans engaged: "the journal's `Next step` is the derived state", "implementation is batched; progress lives in the journal", "the result block is a machine contract", "the logic head and the PR diff are `diff.sh`'s job", "the plan is parsed by a script", and TP-0043's "a machine contract's error must show the shape".

### Backward Compatibility Options

- **Option A — `Tsf-Increment:` trailer + `diff.sh` subcommand (the ticket's C1).** Pros: follows a proven precedent; survives any conversation or result-block failure; the counter becomes a fact about the branch. Cons: does not heal GH-41 (no trailers on its commits); empty output is ambiguous and its failure direction here means "rebuild", not "fail closed"; depends on the final paragraph staying all-trailers, which nothing enforces; needs `plan.sh` to emit numbers anyway for the "remain" test.
- **Option B — accept the agent's report that the plan is already built.** The agent has the plan and the branch in front of it; verification and the four gates exist precisely to catch an implementation that is not actually complete. Pros: heals GH-41 with no new contract and no backfill; removes the empty-commit invalidity at its root. Cons: trusts a report the dispatcher cannot check; weakens the "never guess a state" posture; the guard's original purpose (a plan-length loop of empty cycles) needs a different bound.
- **Option C — keep the journal as the source and let a park entry carry the line.** Pros: smallest change; the dispatcher already knows the commits. Cons: the dispatcher does not know *which increments* those commits are without reading the agent's rejected output — the very thing judged invalid.
- **Option D — make the empty cycle legal and let the pull request open unconditionally (C2 + C3 without C1).** Pros: fixes the two mechanisms that actually fire, in two small edits; heals GH-41 if the "remain" test can be computed. Cons: leaves the root enabler in place, so the next rejected return after a push strands work again — just one mechanism later.
- These are not exclusive: A addresses the enabler, B or C the heal, D the firing mechanisms. The ordering question — which of them GH-41's acceptance criterion depends on — is the planning decision.

## Open Questions

1. **Does the heal come from the trailer or from trusting the agent?** A trailer
   cannot heal GH-41; option B can, at the cost of accepting a report the
   dispatcher cannot verify. The counter-argument worth weighing in planning:
   verify plus four gates already exist to catch an incomplete implementation, so
   parking at implement may be defending a line that is defended downstream.
2. **The ticket's acceptance criterion needs re-deciding.** "GH-41's branch as it
   stands today yields `1,2,3`" is unachievable under C1. Either the criterion
   changes to "GH-41 reaches `tsf:verify` with a pull request" (which option B or
   C satisfies), or the ticket accepts a one-time backfill — which its own Out of
   Scope currently forbids.
3. **How does "increments remain" get computed?** `plan.sh` must emit the
   numbers, or the comparison must be count-based and contiguity must be
   enforced. If `plan.sh check` gains a `numbers:` line, it joins the plan
   contract's same-commit span.
4. **Where does the empty-cycle exception to `MANDATORY OUTPUT` live** — a carve-out
   beside the format-fix one at `cycle.md:245-248`, or a new `outcome:` value that
   makes "nothing to do" explicit rather than exceptional?
5. **What bound replaces the guard's purpose** if a complete built set is no
   longer parked? The guard exists to stop a plan-length loop of empty cycles;
   the "remain" condition removes the terminal case but not the stalled one.
6. **Does a resume into `tsf:implement` still need the journal anchor?** The
   anchor ("since the ticket most recently entered `tsf:implement`") exists only
   to scope a journal scan. A branch-derived set has no such boundary — which is
   simpler, but it also means a rework or fix commit cannot be mistaken for an
   increment only if the trailer is what distinguishes them.
7. **Duplicate and folded trailer values** — the existing read omits `unfold` and
   defines no duplicate-key policy. Minor, but it is a contract detail if a
   second trailer key is added.
