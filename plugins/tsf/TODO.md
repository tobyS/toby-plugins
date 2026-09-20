# tsf — deferred items

Things the factory does not do yet, with the reasoning for deferring them.
Each one names what would close it. Items here are not bugs: they are decisions
to ship without something, recorded so the next slice does not have to
rediscover them.

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

## Document and check the factory session's permission mode

*(deferred 2026-09-20, post-1.0.0 review)*

The allowlist `/tsf:init` writes covers the contract scripts, a few local git
commands, the profile's build/test/lint commands and edits under
`thoughts/factory/`. It does not — and cannot — cover what a coding agent
actually does: `tsf:implement` and `tsf:verify-fix` edit source files and run
whatever shell commands the work needs, and `tsf:merge-resolver` runs
`git merge`. In Claude Code's default permission mode each of those prompts, and
in an unattended `/loop` nobody answers, so the cycle waits forever. Neither the
README nor `/tsf:init`'s clone checklist says which permission mode the factory
session must be started in.

Deferred because the first consumer runs the factory inside a sandbox with
permissions bypassed, which is the posture DESIGN.md §5.3 assumes ("permissive
inside that boundary") — so it does not bite there.

**What would close it:** the README and `/tsf:init`'s clone checklist state the
requirement plainly — a permissive mode (bypass, or accept-edits plus a sandbox
that auto-allows shell commands) **inside** a sandbox or container — and
recommend `permissions.deny` rules for a direct `git push` and `gh`. Deny rules
match only the agent's own command line, never the child processes of the
plugin's scripts, so `push.sh` and `gh-write.sh` keep working while DESIGN.md
§11.3's "no agent pushes or calls GitHub" becomes enforced rather than prompted
for. A preflight check would be better still, but Claude Code exposes the
session's permission mode to a script in no documented way.

**Symptom if it bites:** the first `tsf:implement` cycle never returns; the
session shows a permission prompt for an `Edit` or a `Bash` call nobody is
there to answer.

## Count only responders' reviews

*(deferred 2026-09-20, post-1.0.0 review)*

`scan.sh` and `gh-read.sh reviews` reduce a pull request's reviews to the latest
decisive one **of any reviewer**. Issue replies are filtered by the configured
responders (§3.4); reviews are not. On a private single-engineer repository the
only possible reviewer is a responder, so nothing goes wrong. On a public one,
any GitHub user can submit a review: a stranger's approval would send the ticket
to `tsf:landing`, where the server refuses the merge every cycle, and a
stranger's "changes requested" would hand their text to `tsf:implement` as the
rework brief — instructions from an untrusted author to an agent with a shell
and the factory's token in its environment.

**What would close it:** filter the reviews by the responder list in both
scripts (`--responders` is already passed to the scan in polling mode; it would
become unconditional), and say in the README that a review counts only when a
responder submitted it.

**Symptom if it bites:** a ticket moves to `tsf:landing` or `tsf:rework` without
any review by you, on a repository other people can see.
