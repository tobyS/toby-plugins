---
date: 2026-09-18T14:15:45Z
git_commit: 4d6e9f285f360795d3550acda78fa298fe2b5bb3
branch: main
repository: toby-plugins
topic: "TP-0034c — tsf slice 3: landing loop, integration gate, and the 1.0.0 release"
tags: [research, codebase, tsf, landing, integration-gate, github-rest, release]
status: complete
last_updated: 2026-09-18
---

# Research: TP-0034c — tsf slice 3: landing loop, integration gate, and the 1.0.0 release

**Date**: 2026-09-18T14:15:45Z
**Git Commit**: 4d6e9f285f360795d3550acda78fa298fe2b5bb3
**Branch**: main
**Repository**: toby-plugins

## Research Question

What does implementing TP-0034c require: `/tsf:cycle`'s row 12 (the landing
loop of DESIGN.md §9.3), the two new agents (`tsf:merge-resolver`,
`tsf:integration`), the REST operations the landing needs, the repo
documentation, and the 1.0.0 release — given the code slice 2 shipped and the
constraints the design imposes?

## Summary

Slice 3 is the last region of the tsf state machine: `tsf:landing` → sync →
integration gate → a recorded decision → (a later cycle) merge → strip the
state label. Everything before it exists and works as designed on paper; the
landing is the only row `cycle-dispatch.md` deliberately omits.

Four findings shape the work:

1. **The seam is clean and pre-cut.** Slice 2 left 17 explicit deferral points
   (listed under "The slice-3 seam" below), and several structures the landing
   needs already exist: `scan.sh --pr-probe` already probes `tsf:landing`
   tickets (`plugins/tsf/scripts/scan.sh:137`), the journal's `Next step`
   vocabulary already contains `landing`
   (`plugins/tsf/references/templates/journal-entry.md:60`), row 10 already
   *produces* `tsf:landing` (`plugins/tsf/references/cycle-dispatch.md:176-178`),
   and `/tsf:init` already creates the label (`plugins/tsf/commands/init.md:286`).
   The vocabulary does not need to grow; the dispatch row does.

2. **Five REST operations are missing from the scripts**, all in `gh-write.sh`
   / `gh-read.sh` / `diff.sh`, each with an obvious stylistic home: update-branch,
   PR merge, ref deletion, the single-PR read that carries `mergeable_state`,
   and a "remove the state label without a replacement" mode. A sixth gap is
   the integration gate's "main delta" input, which `diff.sh` cannot currently
   compute. Details under "What the scripts are missing".

3. **DESIGN.md is underspecified in 16 places for this slice** — most
   consequentially: how a *mechanical sync merge* is recognized when computing
   the logic head (§3.5 defines the exclusion but names no marker), where the
   integration gate's main-delta range comes from (§3.5 forbids recorded base
   commits), whether the landing's silent restart is bounded at all, and what
   the "dossier addendum" is as an artifact. These are the planning questions.

4. **The ticket's stated dependency is not satisfied.** The consumer-side
   spike (§9.3's parenthetical, the issue #62 walk-through) has **not been
   run**: no REST merge or update-branch call has been attempted by the factory
   identity, the consumer's ruleset still requires **0** approving reviews, and
   `/tsf:init` has never been run in that project. The spike's purpose is to
   choose between REST and the label-bridge fallback per operation — a choice
   the ticket says "is recorded in this ticket's plan". Section "The unsatisfied
   dependency" sets out what is and is not blocked by this.

Independently, the web research resolves most of the ticket's first planning
question (exact endpoints, failure shapes, the full `mergeable_state` value
list) and surfaces one hazard the design does not mention: **`update-branch`
and `merge` are both GraphQL-backed in `gh` porcelain**, and the REST
`update-branch` endpoint is **merge-only** — there is no REST rebase, which
happens to match §16.5's "rebase stays forbidden".

## Detailed Findings

### The landing loop as DESIGN.md specifies it

Row 12 verbatim (`plugins/tsf/DESIGN.md:329-336`):

> `tsf:landing` → the **landing loop** (§9.3): at most one landing **in
> flight** (every other `tsf:landing` ticket is not actionable while one
> awaits CI, §5.2), and at least two cycles per landing (a decision cycle
> that writes, then a write-free merge cycle once CI on the decided head
> is green). Ends with the merge, or with `tsf:verify` (CI red on the
> decided head: a new verification episode, §6.7, and the approval is
> re-earned through row 10), `tsf:needs-review` (logic-changing
> resolution, integration risk) or `tsf:needs-human` (unresolvable).

The five steps (`DESIGN.md:841-895`), in operational terms:

1. **Sync** — `PUT /repos/{o}/{r}/pulls/{n}/update-branch` (merge, never
   rebase, never force-push). Clean → run `prepare` again so the clone holds
   the merged head. Conflict (the call "fails and changes nothing") → the
   `tsf:merge-resolver` agent merges in the clone with `git merge`, resolves,
   and classifies the resolution **mechanical** or **logic**; unresolvable →
   `tsf:needs-human` with the concrete decision.
2. **Integration gate** — only when main moved since the approval, or since
   the main head the last `integration-<n>.md` recorded. Inputs: the PR diff
   (§3.5), the main delta, `spec.md`. Verdict **safe / risk**.
3. **Verify** — the sync and the decision push start CI on the real
   combination; read at the next pickup. Red → the ticket leaves landing for
   `tsf:verify` as a **new episode** (the third episode source, after implement
   and rework).
4. **Decide and record** — merge is decided only when *all* of: branch up to
   date, resolution mechanical or none, gate safe or skipped, and the latest
   approving review's `commit_id` at or after the logic head. Then the
   **landing decision entry** ("merge when CI on head `<sha>` is green"),
   committed with the integration report and pushed; the cycle ends. Otherwise
   a dossier addendum + `tsf:needs-review`.
5. **Merge (write-free)** — a later cycle confirms the decided head is still
   the PR head (moved → decision void, restart at step 1 silently), CI green on
   it (red → step 3's exit), then reads `mergeable_state`: `behind` → void,
   restart silently, **never** the §10 retry-then-park rule; `clean` → squash
   merge over REST with the PR title as subject. Writes nothing to the
   repository. After the merge its only writes are GitHub writes: the label
   PATCH removing the `tsf:*` state label, and — where
   `delete_branch_on_merge` is off — the remote branch deletion over REST.

The two-cycle split is forced by the ruleset (`DESIGN.md:829-839`,
§16.30 at `:1529-1538`): the required check is evaluated on the PR head, so any
push — a journal entry included — makes the head unchecked and the merge
refused. This is also why **the CI workflow must not path-filter `thoughts/**`**.

The one-landing-in-flight rule (`DESIGN.md:830-834`) exists because every
landing makes the other approved PRs `behind` under the strict up-to-date rule;
a second sync would waste a CI run and void the first decision.

The pick order gains a landing tier at the top (`DESIGN.md:392-397`):
landing tickets first, then other in-flight, then `tsf:priority`, then oldest.
`cycle.md:97-99` currently implements the last three tiers only.

### Gate 4 (integration) and its report

Verbatim (`DESIGN.md:663-672`): inputs are the PR diff, "the diff the main
branch took since the PR's approval", and `spec.md`; it "Runs only when main
moved after the approval"; the question is whether "the two changes can break
each other in ways the tests would not catch (a changed contract the PR calls,
migration ordering, shared configuration, duplicated behaviour)"; verdict
**safe / risk**.

Report naming is **`integration-<n>.md` per landing attempt**
(`DESIGN.md:112-118`, `:634-636`) — deliberately *not* the
`<gate>-<episode>-<round>.md` shape the three post-implement gates use. §16.46
(`DESIGN.md:1653-1660`) explains why: `integration-<n>.md` must survive a
restarted landing instead of being overwritten, "and the gate re-runs only when
main moved since the last report's recorded main head."

The gate shares the `head:` / `verdict:` machine-line contract of
`references/templates/report.md:38-61`, and like the other three its report is
summarized by the dispatcher in a one-line PR comment (`DESIGN.md:627`).

### The slice-3 seam: where slice 2 stopped

Seventeen places name landing and defer it. The load-bearing ones:

- `plugins/tsf/commands/cycle.md:94` — the not-actionable list: `` - `tsf:landing` — "landing not implemented in this slice"; ``
- `plugins/tsf/commands/cycle.md:131-133` — Step 5's **re-pick** yield (the only backtrack in the cycle), which exists solely for `landing`
- `plugins/tsf/commands/cycle.md:195-196` — Important Rule 4: "**Later-slice states are reported, never attempted** — in this slice that is `tsf:landing` alone."
- `plugins/tsf/references/cycle-dispatch.md:17` — "rows 1–11 and 13; row 12, landing, is a later slice"
- `plugins/tsf/references/cycle-dispatch.md:34-35` — the derived-state reader restricts a readable `Next step` to `triage | research | plan | implement`; anything else is a mismatch. **This must widen** for `landing` (and, as written, already excludes `verify`/`gates`/`dossier`/`review` — worth re-reading during planning).
- `plugins/tsf/references/cycle-dispatch.md:74-75` — "The derived step `landing` in any row → **re-pick**"
- `plugins/tsf/references/cycle-dispatch.md:176-181` — row 10's approval branch, the only producer of `tsf:landing`
- `plugins/tsf/references/cycle-report.md:28`, `:44` — the skip-reason vocabulary still carries `landing not implemented in this slice`
- `plugins/tsf/scripts/diff.sh:49-50` — "(Mechanical sync merges, which §3.5 also excludes, do not exist before the landing slice.)"
- `plugins/tsf/README.md:26-30`, `:193` — the slice-2 scope box and the label table's *(slice 3)*
- `plugins/tsf/.claude-plugin/plugin.json:4` — "Slice 2: … landing excepted."

Already in place and needing no change: `scan.sh:137` (landing is in the
`--pr-probe` state list, so a landing ticket already arrives with `pr`,
`pr_head`, `ci`, `review`, `review_ref`, `factory_comment` filled),
`journal-entry.md:60` and `:114-115` (the `landing` step and the review-read
entry shape), `init.md:286` (the label).

### What the scripts are missing

Available today (see "Code References" for the subcommands): review reads with
`commit_id`, check-run reads per SHA, PR identity/head/base/title/body,
reachability (`diff.sh ancestor`), the logic head, the PR diff, changed-file
lists per branch, local commit + push, comments, label transitions, the marker
block.

Missing, with its stylistic home:

| Operation | REST | Where it would go |
|---|---|---|
| Update-branch | `PUT /repos/{o}/{r}/pulls/{n}/update-branch` | new `gh-write.sh` arm beside `pr-create` (`gh-write.sh:277-305`) |
| PR merge (squash) | `PUT /repos/{o}/{r}/pulls/{n}/merge` | new `gh-write.sh` arm |
| Remote ref deletion | `DELETE /repos/{o}/{r}/git/refs/heads/{b}` | `ref-delete`, mirroring `ref-create` (`gh-write.sh:249-275`) |
| `mergeable_state` read | `GET /repos/{o}/{r}/pulls/{n}` | `gh-read.sh pr` reads the **list** endpoint (`gh-read.sh:224`), whose objects lack `mergeable`/`mergeable_state`; needs a single-PR mode |
| Strip the state label | the existing full-set `PUT …/issues/{n}/labels` | `gh-write.sh labels` requires `--set tsf:<state>` and rejects a bare `tsf:` (`gh-write.sh:134`); needs a `--clear` mode. Slice 1's plan already recorded this as "slice 3's". |
| Main delta for the gate | local `git` | `diff.sh` has `pr-diff` and `files` but nothing that produces the base branch's movement since a given sha |
| Local merge / conflict support | local `git merge` | no script wraps it; the merge-resolver agent has `Bash` and would run it directly |

`push.sh` cannot delete a ref: it hard-codes the refspec
`refs/heads/B:refs/heads/B` (`push.sh:82`, `:88`), so the `:refs/heads/B`
delete-push form is unreachable by design.

### GitHub REST: the endpoints and their failure shapes

**Update-branch** (`PUT …/pulls/{n}/update-branch`) — documented as "merging
HEAD from the base branch into the pull request branch". `expected_head_sha` is
optional and **defaults to the current head**, so omitting it is not a guard;
a short SHA is rejected. Documented codes: **202** (accepted — *asynchronous*;
the head SHA may not have changed yet when you read it back), 403, 422.
Conflict behaviour is **not documented**: community evidence reports **422**
with a conflict message, and the same 422 for "There are no new commits on the
base branch". So 422 is a family and its `message` must be parsed. There is
**no `merge_method` / rebase parameter** — REST is merge-only; the UI's "Update
with rebase" is GraphQL-only. (This matches §16.5's "rebase stays forbidden".)

**The sync commit's identity** — committer is `web-flow` / `GitHub
<noreply@github.com>` with a GitHub OpenPGP signature; the *author* is the
acting token's identity. Both are community-observed, not documented. This is
exactly the fact §16.27 wanted the spike to establish
(`DESIGN.md:1513-1514`).

**Merge** (`PUT …/pulls/{n}/merge`) — `merge_method: squash`, `commit_title`
(the squash subject), `commit_message`, and `sha` as the head guard.
**200** merged; **405** "if merge cannot be performed" (the not-mergeable
catch-all: conflicts, failing/pending required checks, missing approvals,
method disabled, not up to date); **409** iff `sha` was provided and the head
moved; 403; 404; 422. Passing `sha` turns a concurrent push into an unambiguous
409 instead of a silent merge of unreviewed code.

**`mergeable` / `mergeable_state`** — only on the single-PR endpoint.
`mergeable` is computed in a background job and is `null` until ready; the docs
say to "resubmit the request" after giving the job time. A push or an
update-branch **resets** the computation, so a read immediately after the sync
essentially always returns `null`. `mergeable_state` is **explicitly
undocumented** (GitHub staff: "unofficial, in flux, may possibly go away");
its value list comes from the GraphQL `MergeStateStatus` enum plus community
write-ups: `clean`, `dirty`, `behind`, `blocked`, `unstable`, `draft`,
`has_hooks`, `unknown`. Mergeable among them: `clean`, `unstable` (a
*non-required* check failing/pending), `has_hooks`.

**Ref deletion** — `DELETE …/git/refs/heads/{b}` → 204, 409, 422; deleting an
already-gone ref is reported as **422 "Reference does not exist"**, not 404
(community evidence). The race-free post-merge sequence is: merge → `GET
…/git/ref/heads/{b}` (404 = already gone) → DELETE if present, accepting 204
and the 422 "does not exist" both as success. This needs no knowledge of the
`delete_branch_on_merge` setting — which matters because auto-deletion is
asynchronous and can be blocked by a rule.

**CI reads** — two independent systems. **GitHub Actions generates checks, not
commit statuses**, so the combined-status endpoint returns `pending` with
`total_count: 0` forever on an Actions-only repo; tsf already reads only
check-runs (`gh-read.sh:56-58`). A check run is finished iff `status ===
"completed"`; failure = `failure, timed_out, cancelled, action_required`;
`neutral` and `skipped` do not block. `filter=latest` (already used) is
essential or superseded re-runs are read. **`total_count: 0` remains
ambiguous** between "no CI" and "not started" — already recorded as a deferred
item in `plugins/tsf/TODO.md:8-33`, and it bites the landing too: after a sync
the client must not read zero checks as green.

**Reviews** — `GET …/pulls/{n}/reviews` returns **chronological order**, must
be paginated, and `commit_id` is the head SHA the review was given on. A bot
that opened a PR cannot approve it.

**Ruleset interactions** (the answer to "can the factory merge?"):

| Settings | Bot merges on one human approval? |
|---|---|
| Required approvals ≥ 1 only | **Yes** — GitHub has no merger ≠ approver rule |
| + dismiss stale, human approved **before** the bot's push | No — approval `DISMISSED` |
| + dismiss stale, human approved **after** the bot's push | Yes |
| + require last-push approval, human approved **after** the push | Yes |
| + require last-push approval, bot pushed **after** the approval | No |
| + strict up-to-date, base moved | No until update-branch — which re-runs checks and, with dismiss-stale, dismisses the approval |

This is precisely why §9.2 requires "dismiss stale reviews on push" and
"require approval of the last push" to stay **off**
(`DESIGN.md:811-825`). One unresolved point: whether a **server-made
update-branch merge commit** makes the caller the "most recent reviewable
pusher" is *not settled in GitHub's documentation* — GitHub staff acknowledged
a 2023 change to "last pusher" behaviour without documenting it. The design's
"keep both settings off" instruction sidesteps it.

**Porcelain is GraphQL** — verified from the `cli/cli` source: `gh pr merge`
uses `mergePullRequest`, `gh pr update-branch` uses `updatePullRequestBranch`,
`gh pr checks` uses `statusCheckRollup`. All three must be `gh api` REST calls,
which the plugin's REST-only rule already mandates.

### The two new agents

**`tsf:merge-resolver`** (worker, §9.3 step 1, §11.1): inputs are the approved
PR whose server-side sync conflicted, main's delta, and the merge state in the
clone. It runs `git merge` locally, resolves, classifies **mechanical**
(independent hunks, imports, lockfiles, formatting, renames) or **logic** (it
had to choose between behaviours, or adapt the PR to a contract main changed),
journals what it did and why, and returns one comment. "It never comes back
with a bare 'this does not merge'" — unresolvable means describing the concrete
decision a human must take. Worker frontmatter per the house pattern:
`tools: Read, Write, Edit, Grep, Glob, Bash` (no `Agent`), an alias `model:`
pin, `description` opening "Internal to `/tsf:cycle` — not for direct use" and
ending "Returns a result block." It commits the resolution locally; the
dispatcher pushes (§11.1 workers are "never push").

**`tsf:integration`** (gate 4, §7, §11.2): `tools: Read, Grep, Glob` — no
`Bash`, no `Write`, no `Agent` — the three-part `## CRITICAL:` /
`## What NOT to Do` / `## REMEMBER:` envelope, the starvation paragraph in the
house shape ("You do NOT receive — and must NOT seek out — …" + why + "You MAY
open …" + "You may NOT open anything under `thoughts/` other than the diff file
you were given"). Its §11.2 row (`DESIGN.md:1032`): inputs = PR diff + main
delta since approval + `spec.md`; may read **post-merge source files**; never
research, plan, journal or any transcript. It may read the merged source
because the clone holds the merged head — via `prepare` after a clean
server-side sync, or via the merge-resolver's local merge commit on the
conflict path (no `prepare` after the resolver, per the ticket's criterion 1).

Both are dispatched in the **foreground** like every other agent. Four gates
total remains far below the 20-subagent cap.

### The write phase, the counters, and the "write-free" cycle

`cycle-write-phase.md` already has a genuine no-repository-write path — the
"prepare failed" case (`:170-186`), which parks on GitHub only. The merge
cycle is a *second* kind of write-free cycle, and a different one: it performs
GitHub writes (merge, label strip, maybe ref delete) but no repository write
and no journal entry at all (`DESIGN.md:166-176`: "The cycle that performs the
merge writes nothing").

Counters are read from disk, never from conversation
(`cycle-dispatch.md:198-214`): the **episode** from the journal's last
`- Episode:` line, the verify-fix **attempt** and the gate **round** from report
filenames. The landing adds a third counter shape — the landing **attempt**
`<n>` in `integration-<n>.md` — which follows the same from-disk rule.

The 1-second spacing between consecutive GitHub writes (`cycle-write-phase.md:58-61`)
applies to the landing's write sequences too.

### Repo documentation and the release

- Root `README.md` has **no tsf row at all** — its intro sentence
  (`README.md:3-10`) and the `## Plugins` table (`:19-23`) name only tce, tmt
  and tle. The marketplace metadata description in
  `.claude-plugin/marketplace.json` likewise omits tsf.
- `CONTRIBUTING.md` already covers tsf (layout at `:59-67`, validation at
  `:100`); no change needed there.
- `plugins/tsf/README.md` needs the slice-2 scope box (`:18-30`) replaced by
  the v1 story, the label table's *(slice 3)* marker removed (`:193`), plus
  the landing flow, the two-cycle split, and the §9.2 ruleset settings —
  including that "dismiss stale reviews on push" and "require approval of the
  last push" stay **off**.
- `plugins/tsf/TODO.md` already holds the no-PR-CI deferral, which is adjacent
  to the ticket's "no-path-filter CI requirement" CLAUDE.md section.
- Versions: `0.2.0` → `1.0.0` in **both** `plugins/tsf/.claude-plugin/plugin.json:3`
  and the tsf entry of `.claude-plugin/marketplace.json`, then
  `claude plugin tag ./plugins/tsf` for `tsf--v1.0.0`. Note that the repo
  currently carries **no tsf tag and no tle tag** (`git tag --list`: only
  `tce--v1.0.0`, `tce--v1.0.1`, `tce--v1.2.0`, `tmt--v1.0.0`) — the 0.1.0 and
  0.2.0 tags were evidently not created, which is worth a decision during
  planning.
- The plugin.json `description` ends "Slice 2: … landing excepted." and must
  change at 1.0.0.

### The unsatisfied dependency: the consumer-side spike

The ticket's Dependencies section requires the §9.3 spike, "run in the first
consumer project's sandbox (its issue #62 walk-through)", and says its outcome
"is recorded in this ticket's plan and selects the mechanism per operation —
REST for the merge and for the update-branch sync, or, for whichever of the two
the sandbox or ruleset refuses, the label-bridge fallback with an App token
(§10)."

It has not been run. Evidence from the consumer project
(`/Users/toby/code/work/chat-sustainability`):

- `factory-design.md:63-67` (untracked, written against DESIGN v1.1) specifies
  the spike entirely in the future tense — "call `PUT /repos/tobyS/chat-sustainability/pulls/<n>/merge`
  (squash) as `tobySagent` and **record the outcome**" — and
  `:73-77` states only a *prediction* that the proxy will allow it.
- `factory-design.md:67-68` — "Test both with and without an approving review
  from the owner **once 3.2 is in place**", where 3.2 is raising required
  approvals to 1. That is still not in place:
  `infra/README.md:498` documents `pull_request` as "a PR is required; **0
  approvals**", corroborated by this repo's own slice-1 research
  (`thoughts/shared/research/2026-09-16-TP-0034a-tsf-foundation-human-gates.md:587`).
- The spike scopes **only the merge PUT** — `update-branch` is not mentioned in
  the consumer's plan at all, so that half of the dependency has no consumer-side
  plan either.
- The consumer repo's git log stops at 2026-09-11; `/tsf:init` has never been
  run there (no `.claude/tsf/`); no contract scripts exist.
- Caveat on the negative: GitHub issue #62 itself was not readable in-session,
  so if the walk-through was run and recorded only as issue comments, it left
  no trace in either repository.

Also relevant and still open from the consumer side:
`thoughts/shared/research/2026-09-10-GH-56-deploy-key-push-test-findings.md:177-182`
records that PR #64 showed `mergeable_state: "clean"` about ten minutes after
main moved, under the strict rule — i.e. **whether `behind` actually appears
there is still unverified**, and the merge cycle's `behind` branch depends on
it.

What the consumer *does* already satisfy: `verify.yml:7-9` runs on
`pull_request` with **no path filters**, so DESIGN §12's no-path-filter
requirement holds; the required check is the display name
`verify (lint, depcruise, typecheck, test)` (`infra/README.md:510-515`).

## Impact Analysis

Slice 3 extends shared code rather than adding an isolated feature. Three
extension points carry real blast radius.

### Existing Usages Found

- `plugins/tsf/scripts/diff.sh:189-203` (`logic-head`) — consumed by
  `cycle-dispatch.md:40-43` (derived state), row 8's gate staleness
  (`:142-157`), row 10's approval validity (`:172-187`), and
  `cycle-write-phase.md:97-118` (filling `head:` in gate reports).
- `plugins/tsf/scripts/gh-write.sh:164-184` (`labels`) — consumed by every
  label transition in `cycle-write-phase.md:52-53`, the stale-label correction
  in `cycle-dispatch.md:53-59`, and every park path.
- `plugins/tsf/references/cycle-dispatch.md:34-35` (the `Next step` reader) —
  consumed by the derived-state computation for every ticket, every cycle.
- `plugins/tsf/references/templates/report.md:38-61` (the two machine lines) —
  consumed by three gate agents and `cycle-write-phase.md`'s gate writes.

### Current Contract

- `logic-head` → `git rev-list -1 HEAD -- . ':(exclude)thoughts/'`; returns
  `logic_head:`, `short:`, `result: ok | none | failed`. Implements **only**
  §3.5's "touches a path outside `thoughts/`" half; the "not a mechanical sync
  merge" half has had nothing to exclude until now (`diff.sh:49-50`).
- `gh-write.sh labels --set tsf:<state>` → re-reads the issue, computes
  non-`tsf:*` + `tsf:priority` + `$SET`, `PUT …/issues/{n}/labels`, reads back
  and compares. `--set` is mandatory and a bare `tsf:` is rejected
  (`gh-write.sh:134`).
- `report.md` → `head:` is the logic head; a report naming another logic head
  is stale and counts as missing.

### Adaptation Requirements

- `diff.sh:189-203` — `logic-head` must exclude mechanical sync merges. **The
  recognition rule does not exist yet** (DESIGN.md names no marker, trailer or
  recorded SHA; §16.27 flags the server commit's identity as unverified). Every
  consumer above silently changes meaning when this changes, so it is the
  highest-risk edit in the slice: get it wrong and gate staleness and approval
  validity both break for *non-landing* tickets too.
- `gh-write.sh:164-184` — add a clear/no-replacement mode. The existing
  full-set machinery (re-read, pass through non-`tsf:*` and `tsf:priority`,
  read back, compare) already does everything else; only the `--set`
  requirement and the `+ [$set]` line change.
- `cycle-dispatch.md:34-35` — widen the readable `Next step` set. As written it
  admits only `triage | research | plan | implement`, which is narrower than
  `journal-entry.md`'s closed vocabulary; widening it for `landing` invites
  re-checking the other four values in the same edit.
- `report.md` — the integration report needs a **second** recorded head (main's)
  that the re-run rule compares against, and a different filename shape
  (`integration-<n>.md`). Both touch a file governed by the "gate report is a
  machine contract" CLAUDE.md rule, whose same-commit span is
  `references/templates/report.md` + the gate agents + `cycle-dispatch.md`.

### Backward Compatibility Options

- **Option A — extend `logic-head` in `diff.sh`** with a mechanical-merge
  exclusion rule (e.g. skip commits with two parents whose second parent is
  reachable from `origin/<base>`). Pros: one place, all consumers inherit it,
  no prose rule to drift. Cons: needs a rule that is correct for both the
  server-made merge and the resolver's local one, and the resolver's
  *mechanical* vs *logic* classification is a judgement that git cannot see.
- **Option B — record the classification** (a commit trailer the resolver
  writes, or the journal entry) and have `logic-head` consult it. Pros: makes
  the logic/mechanical distinction explicit and auditable; the resolver already
  journals its classification. Cons: a trailer is a new machine contract; the
  journal is not readable from a script that takes only arguments (the
  `config.md`-is-prose-only rule's sibling constraint).
- **Option C — leave `logic-head` alone** and have the *dispatcher* skip sync
  merges when it evaluates staleness/approval. Pros: no change to a shared
  script. Cons: contradicts "the logic head … exists exactly once, here"
  (§3.5) and puts machine logic back into prose — the failure mode TP-0030
  established a script to avoid.

## Code References

- `plugins/tsf/DESIGN.md:329-336` — row 12, the landing loop
- `plugins/tsf/DESIGN.md:841-895` — §9.3 steps 1–5 in full
- `plugins/tsf/DESIGN.md:663-672` — §7 gate 4 (integration)
- `plugins/tsf/DESIGN.md:259-282` — §3.5, the logic head and the three-dot PR diff
- `plugins/tsf/DESIGN.md:385-398` — §5.2, actionable + the pick order with the landing tier
- `plugins/tsf/DESIGN.md:811-825` — §9.2, the ruleset settings the landing relies on
- `plugins/tsf/DESIGN.md:914-926` — §9.4, after the merge
- `plugins/tsf/DESIGN.md:1128-1134` — the init ruleset checklist + the no-path-filter CI requirement
- `plugins/tsf/DESIGN.md:1168-1174` — the release plan 0.1.0 → 0.2.0 → 1.0.0
- `plugins/tsf/commands/cycle.md:1-5` — `allowed-tools` (no `gh`, no `git push`)
- `plugins/tsf/commands/cycle.md:75-102` — the pick (actionable, skip reasons, order)
- `plugins/tsf/commands/cycle.md:122-134` — Step 5 Decide, including the re-pick yield
- `plugins/tsf/references/cycle-dispatch.md:142-157` — row 8, the row-authoring style to copy
- `plugins/tsf/references/cycle-dispatch.md:172-187` — row 10, the producer of `tsf:landing`
- `plugins/tsf/references/cycle-dispatch.md:198-214` — the counters, read from disk
- `plugins/tsf/references/cycle-write-phase.md:23-61` — the six-step write sequence
- `plugins/tsf/references/cycle-write-phase.md:170-186` — the existing no-repository-write path
- `plugins/tsf/references/cycle-report.md:22-62` — the report shape and the suggested-wait table
- `plugins/tsf/references/templates/report.md:38-61` — the two machine lines
- `plugins/tsf/references/templates/journal-entry.md:45-60` — the closed `Next step` vocabulary
- `plugins/tsf/references/templates/dossier.md:114-148` — the addendum section
- `plugins/tsf/agents/spec-coverage.md:1-93` — the gate skeleton to copy
- `plugins/tsf/agents/implement.md:104-118` — the worker `## Return` shape
- `plugins/tsf/scripts/lib.sh:75-130` — `tsf_api` and the one-retry rule
- `plugins/tsf/scripts/gh-write.sh:164-184` — the label transition
- `plugins/tsf/scripts/gh-read.sh:221-291` — `pr`, `checks`, `reviews`
- `plugins/tsf/scripts/diff.sh:122-220` — `pr-diff`, `files`, `logic-head`, `ancestor`
- `plugins/tsf/scripts/scan.sh:135-206` — `--pr-probe`, already covering `tsf:landing`
- `plugins/tsf/TODO.md:8-33` — the no-PR-CI deferral

## Architecture Documentation

Patterns slice 3 must follow, all established and all governed by CLAUDE.md
rules:

- **The dispatcher owns every GitHub write** — agents return text; only
  `/tsf:cycle` talks to GitHub, through `gh-write.sh` / `push.sh`. Never add
  `gh` or `git push` to an agent's tools or a command's `allowed-tools`.
- **Scripts take arguments, never parse `config.md`** — the `branch.sh` /
  `stage.sh` division of labour.
- **The result block is a machine contract** — three fences, or **four** for a
  step that leaves a report on the branch (`verify-fix`, `manual-verify`; the
  CLAUDE.md text still says "three", a known drift).
- **Reports are the state, not labels** — fix mode is entered from the reports;
  the landing decision is likewise entered from the journal's decision entry.
- **Gates are read-only by configuration** — `tools: Read, Grep, Glob`, payload
  exactly its §11.2 inputs.
- **Point-of-use template reads** — always "now — in full", with the
  `templates:` fallback because `${CLAUDE_PLUGIN_ROOT}` is not expanded inside a
  subagent prompt.
- **Model pins are policy** — aliases only, never `inherit` for a loop agent,
  never a `model:` on a command.
- **`/tsf:cycle` must never carry `disable-model-invocation`** — the `/loop`
  runner fires it as a prompt.
- **The compaction budget** — `cycle.md` is 201 lines / 10.7 KB against the
  phase-6 criterion of ≤ 230 lines / ≤ 18 KB, so roughly 7 KB of headroom;
  everything else goes into references.

## Historical Context (from thoughts/)

- `thoughts/shared/plans/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md:126-129`
  — the canonical slice-3 scope statement: "The landing loop, the integration
  gate, the merge, the root README catalog and the `tsf--v1.0.0` tag (TP-0034c)."
- Same plan, `:140-145` — the phase-scoping principle to reuse: "Bottom-up
  again, one validatable layer per phase: scripts first …, then the templates
  …, then the agents, then the dispatcher rows …, then docs and the version
  bump." Seven phases, one commit each.
- Same plan, `:1000-1004` — **the end-to-end smoke test was never run** and was
  deferred to the first real factory setup, "and TP-0034c's smoke test inherits
  that setup". Nothing in the implement → verify → gates → dossier → review
  pipeline has been exercised against real GitHub.
- Same plan, `:975-989` — the slice-2 plan-compliance gate caught two real gaps
  on its first run, both about counters/inputs that nothing actually wrote. A
  cautionary precedent for slice 3's landing-attempt counter.
- `thoughts/shared/plans/2026-09-17-TP-0034a-tsf-foundation-human-gates.md:468-469`
  — "A `--clear` form (no state label) is **slice 3's**; do not add it now."
- `thoughts/shared/research/2026-09-18-TP-0034b-…md:513-517` — the open risk
  that **gate report content** (which the dispatcher writes verbatim) can carry
  instruction-shaped text the harness escapes; the result block's
  no-angle-brackets rule covers worker returns but the report path was never
  explicitly checked. The integration report inherits this risk.
- `thoughts/shared/research/2026-09-10-GH-56-deploy-key-push-test-findings.md:177-182`
  — `mergeable_state` did **not** show `behind` under the strict rule in the one
  observation available; still open.

## Related Research

- `thoughts/shared/research/2026-08-11-TP-0034-tsf-plugin-v1-implementation.md`
  — the epic's research. **Superseded for mechanics**: its follow-up section
  describes `gh pr merge` / `gh pr update-branch` porcelain, which §10 forbids
  and which this research confirms is GraphQL-backed. Its behavioural facts
  (conflict reporting, head-SHA guard) stand.
- `thoughts/shared/research/2026-09-16-TP-0034a-tsf-foundation-human-gates.md`
  — slice 1's platform research (identity, allowlist, label PATCH, the
  consumer's ruleset state).
- `thoughts/shared/research/2026-09-18-TP-0034b-tsf-implementation-verification-dossier.md`
  — slice 2's platform research (check runs, reviews, diff caps, foreground
  dispatch, compaction).
- `thoughts/shared/research/2026-07-07-tce-software-factory-review.md` — the
  background review that preceded the design.

## Open Questions

These need answers before planning. The first is a decision for the user; the
rest are design-gap resolutions the plan must record.

1. **The spike dependency.** It has not been run, and running it needs
   consumer-side work that is itself unbuilt (ruleset at 1 approval, a factory
   clone, contract scripts). Does slice 3 proceed on the REST path with the
   label-bridge fallback documented but unbuilt, or does it wait?

2. **How a mechanical sync merge is recognized** when computing the logic head
   (§3.5 defines the exclusion, names no mechanism). Options A/B/C under
   "Impact Analysis". This is the highest-blast-radius decision in the slice.

3. **The main-delta range** for the integration gate — from the approval's
   `commit_id` and its merge-base with main, or from the main head the last
   `integration-<n>.md` recorded? §3.5 forbids recorded base commits, so the
   integration report's recorded main head is the only durable anchor, which
   implies the report format gains a second machine line.

4. **Is the silent restart bounded?** Step 5's `behind` path "starts over,
   silently" with no ceiling, while every other loop in the design carries a
   bound. On a busy main branch this can spin indefinitely, burning a CI run
   per attempt.

5. **One journal entry or two** when the merge-resolver ran in the same
   decision cycle (§3.3 says one entry per cycle; the resolver produces its own
   entry and the decision is a second) — and, relatedly, how many comments the
   decision cycle posts (§10: exactly one per step; but the resolver returns
   one and the integration gate expects a one-liner).

6. **Post-merge write failure.** A label PATCH or branch deletion that fails
   twice would, under §10, park the ticket `tsf:needs-human` — a state label on
   a **closed** issue that the open-only scan never reads again. How is it
   surfaced instead?

7. **Which SHA the decision entry names, and how the merge cycle identifies the
   decided head.** The entry names the logic head (its own commit SHA cannot be
   known before it is written), but CI runs on the *PR* head — the commit that
   introduced the decision entry. "Head unchanged" and "CI green on it" must be
   checked against the commit the required check actually ran on.

8. **The dossier addendum as an artifact** — DESIGN.md references it
   throughout but ships no addendum template; `dossier.md:114-148` has an
   addendum *section*, and `dossier.md:147-148` says it is "committed to
   `reports/dossier.md` as an appended section as well". The ticket asks for it
   to be "extended for a step-4 refusal". Confirm the shape rather than invent
   one.

9. **Does a logic-changing resolution pass through `tsf:verify` first?** Row 12
   lists `tsf:needs-review` as its exit, but the resolution is a push that
   advances the logic head and starts CI — §16.40 requires exactly that path to
   be re-gated for the CI-red case.

10. **The missing 0.1.0 / 0.2.0 tags.** `claude plugin tag` was evidently never
    run for slices 1 and 2. Create them retroactively, or tag only
    `tsf--v1.0.0`?
