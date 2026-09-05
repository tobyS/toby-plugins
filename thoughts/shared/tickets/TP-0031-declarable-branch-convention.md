# TP-0031: Let a project declare its branch model in the tce profile

**Status:** In Progress
**Estimated Complexity:** Large
**Created:** 2026-09-03
**Updated:** 2026-09-05

## Problem Statement

tce has no concept of which branch work happens on. Every command operates on
whatever branch the session already sits on, and reads `git branch
--show-current` as metadata only (`research.md:252` for the research frontmatter,
plus `discuss.md:66`, `quickfix.md:143`, `review.md:277`). No command ever creates
or checks out a branch.

Yet tce already assumes a branch model exists downstream: `implement.md:58`
resolves a baseline via `scripts/baseline.sh` because a recorded commit "is not
guaranteed to still be part of the current history — if the work landed through a
squash or rebase merge, it isn't", and `implement.md:124` speaks of "projects that
develop on branches that are squash- or rebase-merged and then deleted" (TP-0030).
tce knows some projects work one ticket per branch; it has no way of being told,
and no step that acts on it.

A project can write the rule into its own `CLAUDE.md` — that does reach the
session. What CLAUDE.md cannot fix is the step ordering inside the commands:
`/tce:research` goes from step 6 (write the research document) to step 9 (commit
it) with nothing in between about where that commit lands, so a session following
the numbered steps puts the ticket's first artifact on the base branch. Worse,
step 5 gathers `branch:` into the research frontmatter *before* anything could
have branched — so even a session that later moves to the right branch has already
recorded the wrong one, and that frontmatter is what `implement.md` reads back.

## Desired Outcome

A project declares its branch model in `.claude/tce/profile.md`, and tce follows
it. The mechanism is copied, not invented: `## Commit convention`
(`templates/tce/profile.md:53-68`) is agreed with the user at `/tce:init`, written
into the project profile, read at runtime by `/tce:commit` (`commit.md:61`), and
has an explicit absent-section fallback (`commit.md:73`). `## Branch convention`
takes that same shape, with "current branch" as the default option and "branch per
ticket" as the other.

A project that declares nothing behaves exactly as today — no branch command, no
prompt, no difference in output.

## User Stories / Use Cases

- As a developer on a project with a one-branch-per-ticket workflow, I want tce to
  put the ticket's branch in place before it writes and commits the first
  artifact, so that research, plan and implementation land on the ticket's branch
  instead of the base branch.
- As that same developer, I want the research frontmatter to record the branch the
  work actually happens on, so that `/tce:implement` reads back a branch that
  still means something.
- As a developer whose base branch cannot be brought up to date (no network,
  offline agent), I want tce to stop and ask rather than guess, so that a branch
  never gets cut from another ticket's tip and ends up carrying that ticket's
  entire diff.
- As a maintainer of a project that branches however it likes, I want tce to
  change nothing unless I declare a convention, so that adopting a new tce version
  costs me nothing.

## Acceptance Criteria

- [ ] `plugins/tce/templates/tce/profile.md` gains a `## Branch convention`
      section modelled on `## Commit convention`: explanatory prose naming which
      commands read it, plus the bracketed option list `/tce:init` fills in.
- [ ] The option list offers at least "current branch" (today's behaviour, the
      default) and "branch per ticket".
- [ ] The branch-per-ticket option records a branch name pattern expressed with
      the canonical ticket-ID placeholder (resolved per the project's
      `tickets.md`), the base branch, and the rule for when the base cannot be
      brought up to date: stop and ask, never substitute another branch's tip.
- [ ] `/tce:init` agrees the branch convention with the user through a dialog of
      the same shape as the commit-convention dialog, and writes the chosen option
      into `profile.md`.
- [ ] Every command that reads the convention has an explicit absent-section
      fallback, and a project whose `profile.md` has no `## Branch convention`
      section produces byte-identical workflow behaviour to the current release:
      no branch step, no prompt, no extra output, same documents.
- [ ] `/tce:research` performs its branch step *before* the metadata gathering at
      step 5, so the `branch:` value written into the research frontmatter is the
      ticket's branch.
- [ ] The set of commands that act on the convention is decided (see Questions for
      Research/Planning) and each acts per the decided rule; behaviour of any
      command that only warns is stated in the profile section too.
- [ ] The shared branch logic exists in exactly one shipped location — a
      `references/` file read at the point of use, or a `scripts/` helper in the
      manner of `baseline.sh` — and each consuming command references it rather
      than restating it.
- [ ] Non-ticket work (discussions, chores, config) is explicitly covered: the
      convention does not force a commit without a ticket ID onto a ticket branch.
- [ ] Re-running `/tce:init` on a project whose `profile.md` predates the section
      offers to add it (extending the Idempotency upgrade list, per TP-0003), and
      `/tce:refresh` lists it among the hand-authored sections it preserves
      (decided at the 2026-09-04 checkpoint: a branch model is team policy, not
      something re-analysis can verify against the repo).
- [ ] No forge, host, or ticket-prefix literals are introduced anywhere in the
      plugin (CLAUDE.md core design rule); `claude plugin validate .` and the
      per-plugin validations still pass.
- [ ] `CLAUDE.md` records the same-commit span for the new shared logic, in the
      manner of the existing composite-tracking and TP-0020/TP-0030 rules, and
      `plugins/tce/README.md` documents the branch convention.

## Out of Scope

- Prescribing any branch model, name, or merge strategy to a project. TP-0030
  already states the principle: tce adapts to the repository, not the reverse.
- Pushing, opening or updating pull requests, converting drafts, deleting or
  merging branches. tce still never pushes.
- Syncing a long-lived branch with its base.
- The staleness pre-filter, the entry gate, and the reference-integrity-checker
  from the originating discussion.
- TP-0030's own baseline work.
- Enforcement: blocking a commit on the wrong branch is the consuming project's
  business via git hooks and forge rulesets, not the plugin's.

## Open Questions

None — the business decisions are settled. The remaining unknowns are technical
and listed below.

## Questions for Research/Planning

- [ ] Which commands need the branch step? `/tce:research` is certain. `/tce:plan`
      and `/tce:implement` can start in a fresh session on the base branch — do
      they check out the ticket's branch too, or only warn? What about
      `/tce:review`? And how does each answer propagate into `/tce:work` and
      `/tce:quickfix` under the composite-tracking rule?
- [ ] Where does the shared logic live? Repeating it across research/plan/
      implement plus both composites fights the composite-tracking rule — is this
      a `references/` file read at the point of use, or a shipped `scripts/`
      helper like `baseline.sh`?
- [ ] How is the base branch determined when the agent may have no network at all?
      Deriving it from `origin/HEAD` fails offline, which is the exact case the
      stop-and-ask rule exists for. And what does "freshly updated" mean when the
      human has to perform the pull?
- [ ] Where do non-ticket commits go — discussions, chores, config have no ticket
      ID and therefore no branch name?
- [ ] Should `/tce:commit` refuse a ticket-scoped commit on the base branch when
      branch-per-ticket is declared, or is that enforcement and therefore out of
      scope?
- [ ] Should the convention also record the merge strategy (squash / rebase /
      merge commit), so TP-0030's baseline fallback can key on it instead of
      probing?
- [ ] Idempotency mechanics: exactly how `/tce:init`'s upgrade list and
      `/tce:refresh`'s reconcile phase handle a profile without the section.

## References

- `plugins/tce/templates/tce/profile.md:53-68` — the `## Commit convention`
  section whose shape is to be copied.
- `plugins/tce/commands/commit.md:61,73` — runtime read plus absent-section
  fallback, the pattern to mirror.
- `plugins/tce/commands/research.md:247-296` — steps 5 (metadata, incl. `branch:`)
  through 9 (commit), the ordering gap.
- `plugins/tce/commands/refresh.md:79-98` — the reconcile precedent for a profile
  convention section.
- `plugins/tce/commands/implement.md:58,124` — the existing downstream assumption
  that some projects branch per ticket.
- TP-0030 — squash/rebase baseline resolution; states "tce adapts to the
  repository, not the reverse".
- `CLAUDE.md:60` — core design rule: no forge, host, or ticket-prefix literals.
- Originating discussion in the chat-sustainability project,
  `thoughts/shared/discussions/2026-09-02-agent-feature-branch-workflow.md`, which
  decided the workflow and assigned "Branch step at ticket start" to tce. Its
  tracking issue listed the plugin pieces as "assumed present" — they are not,
  which produced this ticket.

## Implementation Plan

[Leave empty — filled when the plan is created.]

## Notes & Updates

### 2026-09-04

Decisions at the `/tce:work` question checkpoint (plan:
`thoughts/shared/plans/2026-09-05-TP-0031-declarable-branch-convention.md`):

- Commands: `/tce:research` creates the ticket branch (or switches to it);
  `/tce:plan`, `/tce:implement`, `/tce:review` switch to the existing branch and
  stop and ask when it is missing or the tree is dirty; the composites mirror.
- Shared logic: one shipped script, `plugins/tce/scripts/branch.sh`.
- Base branch: fetch it from its remote; on any failure stop and ask, never
  branch from another tip.
- Refresh: the section is hand-authored and preserved; init's Idempotency list
  adds it to older profiles (the refresh acceptance criterion above was amended
  accordingly).
- `/tce:commit`: warns and asks before a ticket-scoped commit on the base branch;
  never refuses.
- Merge strategy: not recorded.
- Version: tce bumps to 1.1.0 in this ticket (no tag) so the upgrade bullet fires.

### 2026-09-03

- Ticket created from the chat-sustainability discussion of 2026-09-02. That
  project ships the policy as CLAUDE.md prose meanwhile, so it is not blocked on
  this work.
- Complexity assessed Large: a template section, an `/tce:init` dialog, a
  `/tce:refresh` reconcile, an as-yet-undecided plural set of workflow commands,
  both composites, a new shared-logic home, and a CLAUDE.md governance rule.
- Deliberately configuration-only: the plugin gains the ability to be *told* a
  branch model and to act on it. Choosing a model, enforcing it, and everything
  involving a remote stay with the consuming project.
