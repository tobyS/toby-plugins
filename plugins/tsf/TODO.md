# tsf — deferred items

Things the factory does not do yet, with the reasoning for deferring them.
Each one names what would close it. Items here are not bugs: they are decisions
to ship without something, recorded so the next slice does not have to
rediscover them.

## Detect that a repository has no pull-request CI

*(deferred 2026-09-18, TP-0034b)*

`/tsf:cycle` reads CI state from the check-runs endpoint, where "this repository
runs no CI on pull requests" and "the checks have not been created yet" are the
same answer: `total_count: 0`. GitHub documents no field, timestamp or status
that separates them, so the factory treats zero check runs as **pending** and
waits.

That is the safe reading for a working factory — CI is a precondition of the
whole pipeline (§7 makes green CI the gate precondition, and `/tsf:init` already
prints a ruleset checklist demanding a required status check). The wrong reading
would be worse: concluding "no CI" and marching a change to the dossier without
CI ever having run.

**What would close it:** a precheck in `/tsf:init` that confirms the repository
actually runs a workflow on `pull_request` — and records the answer in
`.claude/tsf/config.md`, so the cycle can distinguish "waiting" from "this
project has none" instead of inferring it. A project genuinely without CI would
then set verification mode `local` and be told the gates run on local evidence
alone.

**Symptom if it bites:** a ticket sits at `tsf:verify` forever, its cycles
reporting `ci pending` on the same head, in a repository where nothing will ever
report a check.

## Reduce the CI runs a landing costs

*(deferred 2026-09-20, TP-0034c)*

A landing costs up to two CI runs per attempt: one for the server-side sync
that brings the base branch in, and one for the commit that records the merge
decision. A restart — the base branch moved again before the merge cycle got
there — repeats both. On an active base branch that is the factory's largest
single consumer of CI minutes.

The second run is the expensive one, and it exists only because the decision
has to be *on the branch*: the journal is the ticket's state (§3.3), and the
required check is evaluated on the pull request's head, so recording the
decision moves the head and the head must then be checked again.

**What would close it:** a way to record the decision without moving the head
that CI is evaluated on — a decision held outside the branch (which the
"journal is the state" model currently forbids), or a repository configuration
in which a `thoughts/`-only commit satisfies the required check without a new
run. Neither is available today, and the wrong fix — path-filtering the
workflow — breaks the merge outright, because a filtered-out required check
stays "expected" forever (§9.2).

**Symptom if it bites:** CI minutes dominated by landings, and landings that
take many attempts on a busy base branch until `landing_attempt_bound` parks
them.

## Detect a repository that requires signed commits

*(deferred 2026-09-20, TP-0034c)*

Commits the factory creates through the contents API are **unsigned** (verified
2026-09-19 in the first consumer's sandbox), while the commits GitHub itself
makes for the factory — the update-branch merge and the squash merge — are
GitHub-signed. A repository whose ruleset requires signed commits would
therefore reject the factory's own writes, and the factory would discover this
as an opaque rejection partway through a ticket.

**What would close it:** a precheck in `/tsf:init` that reads the branch rules
for the base branch, refuses to finish when a signature requirement is present,
and says plainly that tsf cannot sign its commits.

**Symptom if it bites:** a `rejected` result on the first push or contents
write in a repository that looked correctly configured.
