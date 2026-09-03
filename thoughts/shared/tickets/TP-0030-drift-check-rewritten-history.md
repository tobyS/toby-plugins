# TP-0030: Make tce's recorded commit SHAs survive squash merges

**Status:** Done
**Estimated Complexity:** Medium
**Created:** 2026-09-02
**Updated:** 2026-09-03

## Problem Statement

Projects using tce now work each ticket on a branch `gh-<n>`, squash-merge it
into main, and delete the branch. After that, **every SHA a thoughts document
recorded while on the branch is unreachable from main**:

- the research document's frontmatter `git_commit`,
- the plan's `**Base commit**` (first phase's `### Implementation log`),
- the per-phase `**Commit**` lines.

Each of these has a consumer that assumes reachability:

- `/tce:implement`'s "Repository state check" compares the research
  `git_commit` against `HEAD` and runs
  `git diff --stat <research_commit>..HEAD`. With an unreachable SHA this fails
  with `fatal: bad object`, and the instruction has no branch for that case — so
  the staleness guard is silently lost, precisely when research is most likely
  to be stale.
- The Plan-Compliance Gate (`implement.md` step 2) diffs the implementation from
  the `**Base commit**`. Same failure: the gate that blocks the ticket's done
  transition loses the diff it judges against.
- The per-phase `**Commit**` hashes become unresolvable references, so the
  implementation log stops being navigable after the merge.

There is a milder second-order case too: where the object still exists locally
as a dangling commit, the diff *succeeds* but reports the branch's own squashed
changes as drift — noise rather than signal.

In effect, tce currently only works correctly on repositories that merge without
rewriting history. Squash merges and rebase merges both rewrite it.

## Desired Outcome

Every consumer of a recorded SHA works under a squash-merge workflow. When a
recorded SHA is not reachable, tce falls back to **the squash commit — the commit
that introduced the document into the current history** — and says in its output
which baseline it used. Phase commit hashes remain findable after branch deletion
via the PR reference recorded in the plan.

## User Stories / Use Cases

- As a developer on a squash-merge repository, I want `/tce:implement` to still
  tell me whether the research is stale, so that I don't implement against a
  description of the codebase that no longer matches.
- As a developer resuming a partly-implemented plan after its branch was merged
  and deleted, I want the Plan-Compliance Gate to still produce a real diff, so
  that the done transition stays gated on evidence rather than being waved
  through.
- As a developer reading a closed plan months later, I want the phase commits to
  still be retrievable, so that the implementation log remains navigable.

## Acceptance Criteria

- [ ] **Research baseline.** In `commands/implement.md`, "Repository state
      check": before running `git diff --stat <research_commit>..HEAD`,
      reachability is tested with `git cat-file -e <sha>^{commit}`. On failure the
      baseline becomes
      `git log --format=%H --diff-filter=A -1 -- <research-doc-path>`, and the
      command states in its output which baseline was used.
- [ ] **Gate baseline.** In `commands/implement.md`, Plan-Compliance Gate step 2:
      the same reachability test is applied to the `**Base commit**`, with the
      same introducing-commit fallback. The existing
      `git log --grep=...  | tail -1` fallback is kept, and it is documented that
      this fallback depends on the squash commit message carrying the ticket
      scope — so the PR title must follow the project's commit convention with
      the ticket ID in scope position.
- [ ] **PR reference.** `commands/implement.md`'s closeout template and
      `references/plan-document-template.md` both gain `- **PR**: #<n>` in
      `## Implementation Closeout`, so phase hashes stay findable via
      `refs/pull/<n>/head` on GitHub after branch deletion.
- [ ] **Contract note.** The header comment of
      `references/research-document-template.md` notes that `git_commit` may be
      unreachable after a squash merge and that `implement.md` handles it.
- [ ] **Composites mirrored.** Per the composite-tracking rule in `CLAUDE.md`,
      `commands/work.md` and `commands/quickfix.md` are updated in the same
      commit to match the `implement.md` changes they re-describe or inherit
      (`work.md` re-describes the gate inline at its Phase 4d and records the
      `**Base commit**`; `quickfix.md` inherits via the `tce:implement`
      delegation).
- [ ] No command path can run a git invocation that fails with `fatal: bad
      object` on an unreachable recorded SHA.
- [ ] Resolvable paths are unchanged: matching SHA ⇒ documents current;
      differing-but-reachable SHA ⇒ the existing diff-and-spot-verify flow; the
      same-session fast path still short-circuits.
- [ ] Verified in a scratch repository that reproduces the failure: documents
      committed on a `gh-<n>` branch, branch squash-merged into main and deleted,
      fresh clone, then `/tce:implement` — both the repository state check and the
      Plan-Compliance Gate produce a correct result and name the baseline used.

## Out of Scope

- Prescribing or changing any project's merge strategy — tce adapts to the
  repository, not the reverse.
- Automatically re-running research, or repairing/rewriting stale thoughts
  documents (e.g. rewriting recorded SHAs after a merge).
- Reworking `/tce:review`'s own frontmatter SHA (it records provenance and is not
  consumed as a baseline) — unless research shows it shares the same failure.
- Any tle change (tle has no drift check).

## Open Questions

None blocking. The ask-versus-warn question raised during authoring is resolved
by the fallback rule: proceed with the introducing-commit baseline and state which
baseline was used.

## Questions for Research/Planning

- [ ] **Project-agnosticism of the two GitHub-shaped items.** `CLAUDE.md`'s core
      design rule forbids ticket-system literals in tce commands (`[PREFIX]-XXXX`
      is the placeholder), yet the gate-fallback note names `GH-<n>` and the PR
      reference (`- **PR**: #<n>`, `refs/pull/<n>/head`) is GitHub-specific. How
      should these be phrased so they carry the intent without hardcoding a
      forge or a prefix — e.g. stating the requirement in terms of the project's
      commit convention from `profile.md`, and making the PR line optional/named
      generically? This needs settling before the wording is written.
- [ ] Does `git log --format=%H --diff-filter=A -1 -- <path>` reliably return the
      squash commit in the relevant cases, including when the document was
      renamed, or added in one branch and modified in another?
- [ ] Residual edge case: what if the introducing-commit lookup also returns
      nothing (document not yet committed, or present only in the working tree)?
      A defined behaviour is still needed for that path.
- [ ] How should the dangling-but-present case be treated — where
      `git cat-file -e` *succeeds* on a squashed-away commit whose objects
      survive locally, so the diff runs but reports the branch's own changes as
      drift?
- [ ] Where exactly does `work.md` need the mirror? It records the `**Base
      commit**` (line ~228) and re-describes the gate (line ~256) but does **not**
      currently re-describe the repository state check at all — is that omission
      intentional (same-session fast path) or a further gap?
- [ ] Does `plan.md`'s use of the research frontmatter `last_updated` have an
      analogous weakness?
- [ ] Prose-only edits, or does the repeated reachability-probe-then-fallback
      sequence warrant a small shipped helper under `plugins/tce/scripts/`?

## References

- `plugins/tce/commands/implement.md:58` — the Repository state check
- `plugins/tce/commands/implement.md:101-102` — the `**Base commit**` log field
- `plugins/tce/commands/implement.md:114-119` — the `## Implementation Closeout`
  template
- `plugins/tce/commands/implement.md:259-266` — Plan-Compliance Gate step 2 and
  the existing `git log --grep` fallback
- `plugins/tce/references/research-document-template.md:11,25` — the frontmatter
  contract, including the note that `implement.md` reads `git_commit` / `branch`
- `plugins/tce/references/plan-document-template.md:13` — the closeout section
- `plugins/tce/commands/work.md:228,256-257` — the composite's base-commit record
  and inline gate description
- `plugins/tce/commands/research.md:251`,
  `plugins/tce/commands/quickfix.md:143` — the producers of the recorded SHA
- `CLAUDE.md` — "Composite commands must track the single-step commands"; "The
  plan-compliance gate must stay wired across implement and the composites
  (TP-0020)"; the core design rule on project-agnosticism

## Implementation Plan

`thoughts/shared/plans/2026-09-02-TP-0030-drift-check-rewritten-history.md`
(research: `thoughts/shared/research/2026-09-02-TP-0030-drift-check-rewritten-history.md`)

## Notes & Updates

### 2026-09-02

- Reported from a live session as "squashed-away research SHA breaking
  `/tce:implement`'s drift check — after a squash merge and branch deletion, the
  `git_commit` SHA in a research document's frontmatter is unreachable from main,
  so the drift comparison silently loses its baseline."
- Widened after further context from the reporting session: the failure is not
  limited to the research `git_commit`. The same branch workflow (`gh-<n>`,
  squash-merged, deleted) also strands the plan's `**Base commit**` and the
  per-phase `**Commit**` lines, so the Plan-Compliance Gate is affected too.
- Decided rule, from the reporting session: when a recorded SHA is not
  reachable, fall back to the squash commit — the commit that introduced the
  document into the current history — and state which baseline was used. This
  also resolves the earlier open question (ask the user versus warn and
  continue): warn and continue.
- The five change sites were verified to exist before being written into the
  acceptance criteria; line numbers are recorded under References.
- **Flagged concern, not yet resolved:** two of the prescribed changes carry
  forge- and prefix-specific literals (`GH-<n>` in the gate-fallback note, `#<n>`
  / `refs/pull/<n>/head` for the PR reference) into project-agnostic plugin
  commands, which the core design rule in `CLAUDE.md` forbids. Recorded as the
  first question for research/planning rather than silently rephrased.
- Sized Medium: six files, direction fully specified, but it changes two document
  contracts (research frontmatter semantics, plan closeout) and must be mirrored
  into both composites.

### 2026-09-03

- **Two acceptance criteria were amended during the work; they no longer read as
  implemented.** Read them together with this note:
  - **AC 1 and 2 — the probe.** The prescribed `git cat-file -e <sha>^{commit}`
    is an object-*existence* test, not a *reachability* test: it succeeds on the
    dangling commits a deleted branch leaves behind (reflog-protected for weeks),
    so it would have passed on the machine that made the branch and fired only in
    a fresh clone or CI — leaving the noisy-diff case untreated. Replaced with
    `git merge-base --is-ancestor`. Confirmed empirically in the scratch repo:
    `cat-file -e` returns success on the stranded SHA there.
  - **AC 3 — where the PR reference goes.** `references/plan-document-template.md`
    contains no `## Implementation Closeout` template and says so twice ("formats
    are owned by implement.md"); adding one would have inverted that boundary. The
    field went into `implement.md`'s template, and the plan template's existing
    prose paraphrase was extended instead.
- The flagged forge/prefix concern was resolved by phrasing the closeout field
  generically (`**Merge reference**`, "pull/merge request number", `n/a`) and by
  stating the `--grep` fallback's precondition in terms of the project's commit
  convention. Research also found `refs/pull/<n>/head` to be GitHub-specific, with
  GitLab's equivalent **deleted 14 days after merge** — so no forge-specific
  retrieval path could have been baked in anyway.
- The resolution logic ships as `plugins/tce/scripts/baseline.sh` rather than as
  prompt prose, so `implement.md` and `work.md` reference one behaviour instead of
  duplicating a decision tree past the compaction boundary.
- Closed at the user's request with the six manual-verification items outstanding;
  they will be confirmed when the workflow is next used in a production repository.
  The plan's closeout lists them.
