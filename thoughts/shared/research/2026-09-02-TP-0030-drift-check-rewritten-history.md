---
date: 2026-09-02T17:48:52Z
git_commit: 750d0c1c64382bf3d8b0ceac9e83d04b57025cf1
branch: main
repository: toby-plugins
topic: "Make tce's recorded commit SHAs survive squash merges"
tags: [research, codebase, tce, implement, plan-compliance-gate, git, composites]
status: complete
last_updated: 2026-09-02
---

# Research: Make tce's recorded commit SHAs survive squash merges

**Date**: 2026-09-02T17:48:52Z
**Git Commit**: 750d0c1c64382bf3d8b0ceac9e83d04b57025cf1
**Branch**: main
**Repository**: toby-plugins

## Research Question

TP-0030: every SHA a tce thoughts document records while on a feature branch
(`gh-<n>`) becomes unreachable from `main` after a squash merge and branch
deletion. The research `git_commit`, the plan's `**Base commit**`, and the
per-phase `**Commit**` lines each have a consumer that assumes reachability.
Where exactly are the change sites, how should the reachability probe and the
fallback actually be written, and how do the two GitHub-shaped items in the
ticket square with the plugin's project-agnosticism rule?

## Summary

The failure is real and the ticket's five change sites all exist. Research
confirms the diagnosis but **contradicts the ticket's prescribed mechanism on
one central point, and one of its five change sites does not exist as
described**:

1. **`git cat-file -e <sha>^{commit}` is the wrong probe.** It is an
   object-database *existence* check, not a *reachability* check — it succeeds
   for a dangling commit. After a squash merge, the branch's commits usually
   survive locally as dangling objects for weeks (reflog- and
   remote-tracking-protected; `gc.reflogExpireUnreachable` defaults to 30 days,
   loose-object pruning to 2 weeks). So the ticket's probe **passes on the
   machine that created the branch and fails only in a fresh clone or CI** —
   the exact environment-dependent failure the ticket's own "milder
   second-order case" describes. The correct test is
   `git merge-base --is-ancestor <sha> HEAD` (exit 0 = reachable, 1 = present
   but not an ancestor, 128 = unknown object), paired with
   `git rev-parse --verify --quiet <sha>^{commit}` for a silent existence probe
   that distinguishes the two diagnostics.
2. **The plan template does not contain a `## Implementation Closeout`
   template, and deliberately so.** `plan-document-template.md:168-176` is a
   section titled "Implementation-time additions (do not author these)" which
   explicitly disclaims the format: "Their formats are owned by implement.md. **A
   plan is always authored without them**". The ticket's third acceptance
   criterion ("both gain `- **PR**: #<n>` in `## Implementation Closeout`") would
   invert that ownership boundary. There is a way to satisfy the criterion's
   *intent* without breaking it (see Open Questions).
3. **The `--diff-filter=A` fallback needs `--first-parent`** to behave uniformly
   across squash-merge and true-merge repositories, is defeated by renames
   (path-limiting disables rename detection, so a rename surfaces as an `A` of
   the new path), and returns the *most recent* add rather than the first. It
   also returns empty — exit status 0, no error — in a shallow clone.
4. **The prior design rests on an assumption that was never generalized.** The
   TP-0020 research justified the base-commit design with "In this repo (single
   `main`, no branches) a commit range is straightforward"; the existing
   `git log --grep | tail -1` fallback was designed purely as a migration shim
   for status files predating the `**Base commit**` field. Both key on a
   *missing* SHA, never on an *unreachable* one. There is no prior decision to
   overturn here — only an unexamined assumption to replace.
5. **`work.md` genuinely does not re-describe the repository state check** — it
   asserts the same-session fast path at `work.md:225` and stops there. Given
   that `/tce:work` produces research and plan in the same session, that is
   defensible; but it also means `work.md` needs no mirror for the *research
   baseline* change, only for the *gate baseline* change.

Additional findings that shape the plan: `plan.md` reads only `last_updated`
from the research frontmatter (never `git_commit`), so it has no analogous
weakness; `review.md` records its own `git_commit` as provenance only and has no
consumer, matching the ticket's out-of-scope note; and the duplication cost of
the gate mechanics across `implement.md` + `work.md` is the strongest structural
argument in the record for putting the resolution logic in a shipped script
rather than writing the decision tree twice in prose.

## Detailed Findings

### Consumer 1 — the Repository state check (`implement.md:58`)

The check is a single physical line inside `## Context Documents: Your Primary
Knowledge Source` (heading at `implement.md:54`), sitting between the section's
opening paragraph (`:56`) and the ticket-discovery instruction (`:60`):

> **Repository state check:** The research document records the commit it was
> written at (`git_commit` and `branch` in its frontmatter). Compare that against
> the current HEAD (`git rev-parse HEAD`). If they match, the context documents
> reflect the current codebase. If they differ, the repository has moved on since
> research: run `git diff --stat <research_commit>..HEAD` to see which files
> changed, and spot-verify what the research and plan claim about any of those
> files before relying on it. Fast path: when the research and plan were produced
> earlier in this same session (e.g. by `/tce:work` or `/tce:quickfix`) and HEAD
> has only advanced by this session's own commits, the check is trivially
> satisfied — skip the spot-verification.

Three behavioural branches are defined (match / differ / same-session fast path).
There is no branch for a `git_commit` that is missing, unreachable, or invalid,
so `git diff --stat <research_commit>..HEAD` runs unconditionally in the "differ"
case and dies with `fatal: bad object` when the SHA is gone.

Two further properties matter for the plan:

- **`branch` is recorded but never compared.** `research.md:252` captures
  `git branch --show-current` into the frontmatter (`research-document-template.md:26`),
  and `implement.md:58` names it — but no instruction anywhere uses it. It is an
  existing, unexploited signal (recording `gh-<n>` would itself be evidence that
  the research was written on a since-merged branch).
- **The check shares its paragraph block with the TP-0013 ordered re-read
  instruction** at `implement.md:63`. TP-0015's research recorded that the re-read
  rule "must survive the rewrite intact" — the same constraint applies again here.
  Edit surgically.

### Consumer 2 — the Plan-Compliance Gate's diff (`implement.md:259-266`)

Gate step 2, verbatim:

> 2. **Assemble the diff.** Use the `**Base commit**` recorded in the first
>    phase's `### Implementation log` block in the plan. Compute the
>    implementation diff with
>    `git diff <base> -- . ':(exclude)thoughts/'` plus a `git diff <base> --stat`
>    summary. If the plan's log records no base commit, check a legacy
>    `.status.md` next to the plan for one; failing that, fall back to
>    `git log --grep="[PREFIX]-XXXX" --format=%H | tail -1` and diff from that
>    commit's parent.

Mechanics worth preserving verbatim through any edit:

- `git diff <base> -- . ':(exclude)thoughts/'` is a **two-arg working-tree diff**
  (one commit, so it compares `<base>` against the working tree including
  uncommitted changes), with the magic pathspec removing thoughts documents from
  what the checker sees. TP-0020 chose this deliberately.
- The `--stat` companion carries **no** `':(exclude)thoughts/'` pathspec, so the
  summary does include `thoughts/` files. That asymmetry looks unintentional but
  is out of this ticket's scope.
- The fallback chain is three-deep — plan log → legacy `.status.md` → `git log
  --grep` — and **every level keys on absence, not unreachability**. That is the
  precise gap.
- The `--grep` fallback is a **shell pipeline** (`| tail -1`), while the
  command's allowlist (`implement.md:4`) grants only
  `Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*)` — `tail` is not
  covered, and neither would `git merge-base` or `git cat-file` be.
- `git log ... | tail -1` takes the **oldest** matching commit (git logs
  newest-first), then the instruction says to diff from *that commit's parent* —
  the parent is not computed by the quoted command; the model must derive it.

### Consumer 3 — the per-phase `**Commit**` hashes

Defined in the log-block template at `implement.md:103` (`- **Commit**:
`abc1234` <commit subject…>`), recorded per phase by `implement.md:220`. These
have no *programmatic* consumer — nothing diffs from them. Their failure is
purely navigational: after branch deletion the hashes resolve to nothing in a
fresh clone. This is the one part of the ticket that cannot be fixed by a
fallback computation; it needs a durable reference recorded alongside (the
ticket proposes the PR number).

Note the format inconsistency already present: `**Commit**` shows a short hash,
while `**Base commit**` is recorded via `git rev-parse HEAD` (full 40 chars,
`implement.md:127`) but templated as `` `<hash>` `` (`:101-102`). Nothing
normalizes either.

### The recording sites

- `implement.md:127` (Implementation Log Rules, rule 5) — "record `git rev-parse
  HEAD` as the `**Base commit**` (the tip before any implementation commit) — the
  Plan-Compliance Gate diffs from it."
- `implement.md:126` (rule 4) — legacy `.status.md` recovery, read-only.
- `work.md:228` — the composite's one-line mirror of rule 5.
- `research.md:249-253` (step 5) — `git rev-parse HEAD` → the research
  frontmatter; `quickfix.md:143` is the inlined duplicate.
- `research.md:297-301` (step 10) — follow-up research updates `last_updated`
  only; **`git_commit` is never refreshed**, so a document extended weeks later
  still carries its original (possibly stranded) SHA.

### Where the composites mirror what changes

| Site | What it mirrors | Needs updating for TP-0030? |
|------|-----------------|------------------------------|
| `work.md:225` | Repository state check — **as a skip only**; no mechanics restated | Only if the fast-path assertion needs qualifying |
| `work.md:228` | `**Base commit**` recording (`git rev-parse HEAD`) | Only if the recording changes |
| `work.md:256` | The gate inline, including `git diff <base> -- . ':(exclude)thoughts/'` verbatim — **without** the `--stat` companion and **without** any fallback chain | Yes — this is the gate-baseline mirror |
| `work.md:257` | Closeout + done transition | Yes, if the closeout gains a field |
| `quickfix.md:218,233-242` | Surfaces the gate *outcome* line only; inherits everything via the `tce:implement` Skill delegation (`quickfix.md:185`) | Only if the surfaced outcome changes |
| `quickfix.md:143` | Research metadata gathering (SHA producer) | Only if the producer changes |

`quickfix.md` declares no `allowed-tools` at all; `work.md:5` declares only
`Bash("${CLAUDE_PLUGIN_ROOT}/scripts/ticket.sh":*)` — no git verbs. If the gate
mirror in `work.md` gains git commands, that asymmetry becomes relevant.

### The plan template's ownership boundary

`plan-document-template.md` contains **neither** the `### Implementation log`
block **nor** the `## Implementation Closeout` template. It states the boundary
twice — header comment (`:8-14`) and a dedicated section (`:168-176`):

> # Implementation-time additions (do not author these)
>
> During implementation, /tce:implement appends a terse `### Implementation log`
> block as the last subsection of each phase (status, base/phase commit hashes,
> what was done, issues, verification results) and an `## Implementation
> Closeout` section at the very end of the document. Their formats are owned by
> implement.md. **A plan is always authored without them** — never include log
> blocks, a closeout section, or pre-ticked success-criteria checkboxes when
> writing a plan.

The ticket's References line cites `plan-document-template.md:13` as "the
closeout section"; line 13 is in fact the header comment's *mention* of the
closeout. The template holds one prose paraphrase of the log-block fields
(`:171`, "status, base/phase commit hashes, what was done, issues, verification
results") — that phrase is the only thing in this file that a new field could
legitimately extend.

### git semantics that determine the correct mechanism

From the official git documentation (see Code References for links):

- **`git cat-file -e <obj>`** — "Exit with zero status if `<object>` exists and
  is a valid object." Implemented as a raw ODB lookup
  (`odb_has_object(...)`); no ref or reachability involvement. **Succeeds for
  dangling commits.** With the `^{commit}` peel, an unresolvable name is fatal:
  exit **128** with `fatal: Not a valid object name` on stderr (not a quiet 1).
  In a partial clone it can also trigger a lazy fetch from the promisor remote,
  so it is not even guaranteed network-free.
- **`git merge-base --is-ancestor <a> <b>`** — documented to "exit with status 0
  if true, or with status 1 if not. Errors are signaled by a non-zero status that
  is not 1." In practice a missing or non-commit object gives 128 (verified from
  `builtin/merge-base.c` → `die()` → `exit(128)`, not from the man page). The
  three-way split is exactly the signal needed: **0 = usable baseline, 1 =
  present but squashed away, 128 = unknown here.**
- **`git rev-parse --verify --quiet <sha>^{commit}`** — "Do not output an error
  message if the first argument is not a valid object name; instead exit with
  non-zero status silently." The clean existence probe, without `cat-file`'s
  stderr noise or promisor fetch.
- **`git log --diff-filter=A -1 --format=%H -- <path>`**:
  - Works for the plain squash case (the squash commit is an ordinary
    single-parent commit whose diff shows the file as `A`).
  - **Renames defeat it**: rename detection is on by default for porcelain, but
    limiting the diff by a pathspec removes the rename's source side, so the
    rename appears as an `A` of the new path. `--follow` fixes this (single path
    only) but is documented not to follow renames across merge boundaries.
  - **True merges hide it**: merge commits produce no diff by default and
    history simplification follows a TREESAME parent, so the `A` is attributed to
    the branch commit — which may not be on the mainline at all.
    **`--first-parent` is the fix** and is documented to "change default diff
    format for merge commits to `first-parent`", which makes squash-merge and
    true-merge repositories behave uniformly.
  - `-1` yields the **most recent** add (reverse-chronological default). For a
    file that currently exists this is usually right. `--reverse -1` does **not**
    give the oldest — commit limiting is applied before `--reverse`.
  - **Shallow clones return empty with exit status 0**, not an error
    (`actions/checkout` defaults to `fetch-depth: 1`). Test for an empty string,
    not `$?`. Guard with `git rev-parse --is-shallow-repository`.
  - Always keep the `--` separator; `<path>` is a pathspec (directories match
    recursively, leading `:` is magic).

  A more robust form: `git log --first-parent --diff-filter=A --max-count=1
  --format=%H -- "$path"`, falling back to `--follow` when empty, and validating
  the result with `git merge-base --is-ancestor` before use.

- **Squash merge + branch deletion**: GitHub documents that "intermediate
  commits from the pull request are not preserved as separate commits on the base
  branch" and that the squash commit is a new single-parent object. Server-side,
  the originals remain under `refs/pull/<n>/head` (a read-only namespace, **not**
  in a clone's default refspec; retrieved with `git fetch origin
  pull/<n>/head:pr-<n>`). GitLab's equivalent is
  `refs/merge-requests/<iid>/head` — **but GitLab deletes that ref 14 days after
  the MR is merged or closed**, so a PR/MR reference is not a durable archive
  everywhere.
- **Locally**: in a fresh clone the branch commit is simply absent. In the clone
  that created it, HEAD's reflog and remote-tracking refs keep the objects alive
  well past the merge (`gc.reflogExpire` 90 days, `gc.reflogExpireUnreachable`
  30 days, loose-object prune 2 weeks). **This asymmetry is the whole argument
  against `cat-file -e`**: it returns 0 for weeks on the author's machine while
  `merge-base --is-ancestor` returns 1 immediately, and both return "gone" in CI.

Flagged by the web research as **not verified from official documentation**: the
exit-128 values (source-derived, man pages only promise "non-zero"); GitHub's
retention of `refs/pull/<n>/head` specifically *after head-branch deletion*
(community discussion, not official docs — though it is what `gh pr checkout`
relies on); GitHub enabling `uploadpack.allowReachableSHA1InWant` (inferred from
`actions/checkout` behaviour); the `--follow` + `--first-parent` interaction; and
PR-ref conventions for Gitea/Bitbucket/Gerrit.

### Prose-versus-script: the established patterns

Every git decision in this area is currently **prompt prose** with
`allowed-tools` prefix grants — nothing has ever been scripted (TP-0020's plan
explicitly chose the allowlist route, noting it "retroactively covers the
existing drift check"). The counter-pressures are documented too:

- The independent review (`thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md`,
  Section 2 item 1) argues that after auto-compaction only the first ~5,000
  tokens of an invoked skill are re-attached, so stable material should move to
  files read at point of use. `implement.md`'s gate section sits at lines
  244-297 of a 352-line command — well past that boundary.
- CLAUDE.md's TP-0020 rule requires the agent + `implement.md` + `work.md` +
  `quickfix.md` to move together when "the diff mechanics" change, so a
  sophisticated resolution written as prose must be authored twice and kept in
  sync; a `${CLAUDE_PLUGIN_ROOT}/scripts/*.sh` helper is written once and
  referenced twice.

If a script is chosen, the established shape (from `plugins/tce/scripts/ticket.sh`
and `plugins/tmt/scripts/next-ticket.sh`) is: `#!/bin/bash`; purpose + usage
comment noting that the project root is resolved via `lib.sh`, not from the
script's own location; `set -e`; the byte-identical `SCRIPT_DIR=... ; . "$SCRIPT_DIR/lib.sh"`
incantation; usage errors to stdout, precondition errors to stderr, both
`exit 1`; plain stdout output, no JSON. Scripts appear in no manifest — the
places that enumerate them are `CLAUDE.md:34`, `CONTRIBUTING.md:41`, the
consuming command's `allowed-tools`, and (for this repo's own dogfooding)
`.claude/settings.local.json`.

Invocation from a command is always the double-quoted
`"${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh"` form, either in a bash fence
(`research.md:94-100`) or inline in a sentence (`implement.md:62`, `work.md:74`).

### The compliance-checker agent is unaffected

`plugins/tce/agents/plan-compliance-checker.md` mentions the diff repeatedly but
**never its baseline** — no `git`, no commit range anywhere in the file. It
declares `tools: Read, Grep, Glob, LS` (no Bash), so it could not compute a diff
itself even if asked. The diff arrives pre-computed; how it was derived is
entirely the caller's concern. **The agent file needs no change for this ticket**
— which narrows CLAUDE.md's four-file TP-0020 rule to three files here.

## Defect Mechanism

**Intended behaviour.** `implement.md:58` intends a staleness guard: research
recorded a commit; if HEAD has moved, show what changed and spot-verify the
research's claims about those files. `implement.md:259-266` intends the gate to
judge the implementation against a diff taken from the tip *before* implementation
began.

**Actual behaviour under a squash-merge workflow.** Work happens on `gh-<n>`;
`research.md:251` records that branch's HEAD into `git_commit`; `implement.md:127`
records a branch commit as `**Base commit**`. The branch is squash-merged: GitHub
creates a **new** single-parent commit on `main`, and the branch's own commits
are not among its ancestors. The branch is deleted. Both recorded SHAs are now
unreachable from `main`.

**Divergence point 1 — `implement.md:58`.** The comparison `git rev-parse HEAD`
vs `git_commit` takes the "differ" branch (correctly), then runs
`git diff --stat <research_commit>..HEAD`. In a fresh clone the object is absent,
so git exits 128 with `fatal: bad object`; the instruction defines no branch for
that, so the guard is silently abandoned. In the clone that created the branch the
object survives as dangling, so the diff *succeeds* but reports the branch's own
squashed-away changes as drift — noise presented as signal.

**Divergence point 2 — `implement.md:262`.** `git diff <base> -- . ':(exclude)thoughts/'`
fails identically. Because the three-level fallback chain keys on the base being
*missing* rather than *unreachable*, it never engages: the plan *does* record a
base commit, so levels 2 and 3 are skipped. The gate then either errors out or —
if the model routes around the error — feeds the checker an empty or wrong diff,
producing mass "cannot verify from diff" verdicts. `implement.md:281-284`
instructs treating those as not-yet-passed, so the done transition is blocked on
an artefact of history rewriting rather than on the implementation.

**Divergence point 3 — the per-phase `**Commit**` hashes.** No computation
depends on them, so nothing errors; they simply become unresolvable strings in a
fresh clone, and the implementation log stops being navigable.

**Why the ticket's own prescribed probe does not close divergence 1 or 2.**
`git cat-file -e <sha>^{commit}` returns 0 for the dangling object, so on the
originating machine the probe passes and the code takes the unchanged path —
straight into the noisy-diff case. It only diverts in a fresh clone or CI, where
it also emits `fatal: Not a valid object name` on stderr and exits 128 rather
than a quiet 1. The probe therefore fixes the hard-failure half of the defect and
leaves the noise half untouched, with environment-dependent behaviour.

## Impact Analysis

### Existing Usages Found

- `plugins/tce/commands/implement.md:58` — reads research `git_commit`; runs
  `git diff --stat <research_commit>..HEAD`
- `plugins/tce/commands/implement.md:126-127` — recovers / records `**Base commit**`
- `plugins/tce/commands/implement.md:259-266` — reads `**Base commit**`; runs
  `git diff <base> …` with a three-level absence-keyed fallback
- `plugins/tce/commands/implement.md:220` — records per-phase `**Commit**`
- `plugins/tce/commands/work.md:225,228,256,257` — the composite's mirrors
- `plugins/tce/commands/quickfix.md:143,185,218` — SHA producer; skill
  delegation; gate-outcome surfacing
- `plugins/tce/commands/research.md:249-253,270-276,297-301` — SHA producer;
  permalink generation consuming the commit; follow-up update that never
  refreshes `git_commit`
- `plugins/tce/commands/plan.md:101` — the **only** research-frontmatter read in
  the file, and it reads `last_updated`, not `git_commit`
- `plugins/tce/commands/review.md:276,291,304` — records its own `git_commit`
  with no consumer
- `plugins/tce/references/research-document-template.md:10-11,25-26,37` — the
  frontmatter contract and its "who consumes this" note
- `plugins/tce/references/plan-document-template.md:8-14,168-176` — the
  ownership disclaimer for log/closeout formats

### Current Contract

- **Input**: a 40-char SHA recorded in a thoughts document, assumed reachable
  from HEAD at consumption time.
- **Output**: a diff or `--stat` used as a staleness signal (`:58`) or as the
  gate's evidence (`:262`).
- **Assumptions**: linear, non-rewritten history — stated explicitly in the
  TP-0020 research as "In this repo (single `main`, no branches) a commit range
  is straightforward", and never generalized to consuming projects.

### Adaptation Requirements

- `implement.md:58` — needs a reachability branch before the `git diff --stat`,
  plus an output statement naming the baseline used. Must not disturb the
  TP-0013 re-read instruction sharing the block (`:63`).
- `implement.md:259-266` — needs the same probe applied to `**Base commit**`,
  slotted **ahead of** the existing absence-keyed chain (which stays, since it
  covers a different failure).
- `implement.md:4` — the `allowed-tools` line needs whatever new git verb is
  chosen (`git merge-base` and/or `git cat-file`), or a script entry; the
  existing `| tail -1` pipeline is already uncovered.
- `work.md:256` — mirrors the gate; `work.md:5` currently grants no git verbs.
- `research-document-template.md:10-11` — the header comment is the natural home
  for the "may be unreachable after a rewritten-history merge" note.

### Backward Compatibility Options

- **Option A — probe-then-fallback in prose, in both `implement.md` and
  `work.md`.** Matches every existing precedent, no new artefact, no allowlist
  change beyond a git verb. Cost: the decision tree is authored twice and must
  stay in sync; it lands past the compaction boundary in `implement.md`.
- **Option B — a shipped `plugins/tce/scripts/baseline.sh`** that takes the
  recorded SHA and the document path and prints the resolved baseline plus a
  one-word provenance token (`recorded` / `introducing` / `none`). Written once,
  referenced twice, testable with the repo's throwaway-project convention, and
  keeps the git subtleties (`--first-parent`, shallow-clone guard, exit-code
  triage) out of the prompt entirely. Cost: a new artefact to document
  (`CLAUDE.md:34`, `CONTRIBUTING.md:41`) and a new allowlist entry; tce has so far
  shipped only three scripts, none of them git-related.

## Code References

- `plugins/tce/commands/implement.md:4` — `allowed-tools` (git verbs granted)
- `plugins/tce/commands/implement.md:58` — Repository state check
- `plugins/tce/commands/implement.md:97-107` — `### Implementation log` template
  (`**Base commit**` at `:101-102`, `**Commit**` at `:103`)
- `plugins/tce/commands/implement.md:113-119` — `## Implementation Closeout`
  template (three fields; no SHA, no range)
- `plugins/tce/commands/implement.md:126-127` — Implementation Log Rules 4 and 5
- `plugins/tce/commands/implement.md:220` — per-phase commit-hash recording
- `plugins/tce/commands/implement.md:244-297` — the Plan-Compliance Gate
  (step 2 at `:259-266`)
- `plugins/tce/commands/work.md:222-230` — Phase 4a setup (base commit at `:228`)
- `plugins/tce/commands/work.md:250-257` — Phase 4d, inline gate at `:256`
- `plugins/tce/commands/quickfix.md:143` — research metadata gathering
- `plugins/tce/commands/quickfix.md:185` — `tce:implement` Skill delegation
- `plugins/tce/commands/quickfix.md:218,233-242` — gate-outcome surfacing
- `plugins/tce/commands/research.md:249-253` — step 5 metadata gathering
- `plugins/tce/commands/research.md:297-301` — step 10, follow-up updates
- `plugins/tce/commands/plan.md:101` — the `last_updated` staleness check
- `plugins/tce/references/research-document-template.md:1-16` — header comment
  (consumer note at `:10-11`)
- `plugins/tce/references/research-document-template.md:22-39` — frontmatter
- `plugins/tce/references/plan-document-template.md:168-176` —
  "Implementation-time additions (do not author these)"
- `plugins/tce/agents/plan-compliance-checker.md:4,18` — read-only toolset; "the
  implementation diff and a changed-file summary"
- `plugins/tce/scripts/ticket.sh:1-33` — the user-invoked script pattern
- `plugins/tmt/scripts/next-ticket.sh:1-49` — the same pattern with a
  config-missing error

External documentation consulted:

- <https://git-scm.com/docs/git-cat-file> — `-e` is an existence check
- <https://git-scm.com/docs/git-merge-base> — `--is-ancestor` exit semantics
- <https://git-scm.com/docs/git-rev-parse> — `--verify --quiet`
- <https://git-scm.com/docs/git-log> — `--diff-filter`, `--first-parent`,
  `--follow`, `-1` vs `--reverse`, history simplification
- <https://git-scm.com/docs/diff-config> — `diff.renames` defaults
- <https://git-scm.com/docs/git-gc> — reflog/prune expiry defaults
- <https://docs.github.com/en/pull-requests/reference/pull-request-merges> —
  squash-merge semantics
- <https://docs.github.com/en/pull-requests/how-tos/review-pull-requests/checking-out-pull-requests-locally>
  — `refs/pull/<n>/head`
- <https://docs.gitlab.com/user/project/merge_requests/merge_request_troubleshooting/>
  — `refs/merge-requests/<iid>/head` and its 14-day deletion

## Architecture Documentation

Three repository rules constrain any solution:

1. **Project-agnosticism** (CLAUDE.md, "Core design rule"): no stack, forge, or
   ticket-system literals in tce commands; `[PREFIX]-XXXX` is a placeholder and
   per-project facts come from `.claude/tce/profile.md` / `tickets.md` at runtime.
2. **Composite tracking** (CLAUDE.md): changing a single-step command requires
   checking `work.md` and `quickfix.md` in the same commit — and the TP-0020 rule
   names the gate's "diff mechanics" explicitly as a four-file (here three-file)
   move.
3. **Reference files are part of the command contract**: both templates carry
   header comments saying so, and instruct point-of-use re-reads.

The profile records no typecheck and no lint; the test command is
`claude plugin validate .` plus one invocation per plugin, and script changes are
smoke-tested against a throwaway project directory.

## Historical Context (from thoughts/)

- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md` — the
  gate's design. Records that the diff must be computed in the main context
  (agents have no Bash), that three anchors were considered (research
  `git_commit`, the plan commit, `git log --grep`), and the qualifier "In this
  repo (single `main`, no branches) a commit range is straightforward" — the
  unexamined assumption TP-0030 replaces.
- `thoughts/shared/plans/2026-07-05-TP-0020-plan-compliance-gate.md` — chose a
  freshly recorded `**Base commit**` over all three anchors for *precision* (the
  research SHA predates planning) and *resume-safety*. Its "Migration Notes"
  state the `git log --grep` fallback's sole intent: status files predating the
  `**Base commit**` field. Also the decision to add git verbs to `allowed-tools`
  rather than script them.
- `thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md`,
  Defect 5 — why the repository state check exists (it replaced an *assertion*
  that research/plan/implementation ran against identical state, which the
  independent review called "true inside `/tce:work`, false in general"). Records
  two acknowledged limitations: the plan template has no frontmatter, so research
  is the only anchor (a scope artefact, not a preference); and `branch` is
  captured but never compared.
- `thoughts/shared/reviews/2026-07-03-tce-plugin-independent-review.md` —
  Section 2 item 1 on the ~5,000-token compaction boundary for invoked skills;
  Section 3 item 4 rejects worktree/parallel-branch machinery as "not worth it".
- `thoughts/shared/research/2026-06-16-TP-0009-implement-intermediate-commits.md`
  — the per-phase commit contract that produces the `**Commit**` hashes.

No prior document anywhere in `thoughts/` mentions squash merges, rebases,
unreachable objects, `git gc`, or shallow clones. This axis is greenfield.

## Related Research

- `thoughts/shared/research/2026-07-05-TP-0020-plan-compliance-gate.md`
- `thoughts/shared/research/2026-07-03-TP-0015-fix-review-prompt-defects.md`
- `thoughts/shared/research/2026-06-16-TP-0009-implement-intermediate-commits.md`
- `thoughts/shared/research/2026-07-04-TP-0017-adopt-frontmatter-machinery.md`

## Open Questions

These need decisions before planning; the ticket's own "Questions for
Research/Planning" are answered inline where research settled them.

1. **The probe.** The ticket prescribes `git cat-file -e <sha>^{commit}`, which
   research shows is an existence test that passes on dangling objects — so it
   would not fire on the machine that created the branch, and would leave the
   noisy-diff case untreated. Adopt
   `git merge-base --is-ancestor <sha> HEAD` instead (exit 0/1/128), optionally
   with `git rev-parse --verify --quiet` to distinguish "squashed away" from
   "unknown here" in the message? This changes the wording of acceptance criteria
   1 and 2.
2. **Prose or script** (the ticket's last research question). Option A (prose in
   both `implement.md` and `work.md`) matches all precedent; Option B (a shipped
   `scripts/` helper) writes the git subtleties once and keeps them out of the
   compaction-vulnerable tail of a 352-line command. Research surfaces a real
   structural argument for B but no prior decision either way.
3. **The plan-template closeout criterion.** `plan-document-template.md`
   deliberately contains no closeout template ("formats are owned by
   implement.md"); adding a `- **PR**: #<n>` line there would invert that
   boundary. Satisfy the criterion's intent instead by extending the template's
   existing prose paraphrase at `:171` (which already lists the log block's
   fields), leaving the actual template solely in `implement.md`?
4. **The two forge-shaped items** (the ticket's first research question).
   Research confirms the concern is well-founded and that `refs/pull/<n>/head`
   is GitHub-specific with a *time-limited* GitLab equivalent. Phrase the closeout
   field generically — e.g. `- **Merge reference**: [PR/MR reference, if the
   project uses one]` — and state the `--grep` fallback's precondition in terms
   of "the project's commit convention from `profile.md` carrying the ticket ID"
   rather than naming a prefix or forge?
5. **The empty-result path** (the ticket's third research question). If the
   introducing-commit lookup also yields nothing (uncommitted document, shallow
   clone), what is the defined behaviour — proceed with no baseline and say so,
   or fall through to the existing `--grep` chain? Note the lookup returns an
   empty string with **exit status 0**, so the instruction must test the output,
   not the status.
6. **The `work.md` mirror scope** (the ticket's fifth research question).
   Confirmed: `work.md` does not re-describe the repository state check at all,
   only asserts the fast path. Is that omission acceptable as-is (research and
   plan are same-session by construction), or should `work.md:225` gain a
   qualifier for the resume case, where a `/tce:work` run is picked up in a later
   session after a merge?

Answered by research, no decision needed:

- **`--diff-filter=A` reliability** (ticket question 2): unreliable as written —
  needs `--first-parent` for merge uniformity, is defeated by renames unless
  `--follow` is used, returns the most recent add, and returns empty in shallow
  clones.
- **The dangling-but-present case** (ticket question 4): resolved by using
  ancestry rather than existence as the test — a dangling commit is
  non-ancestor, so it takes the fallback path like any other stranded SHA.
- **`plan.md`'s `last_updated`** (ticket question 6): no analogous weakness —
  `plan.md:101` is a date-versus-recent-changes judgement, never a commit
  lookup, and `plan.md` never reads `git_commit`.
