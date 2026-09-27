# tsf — deferred items

Things the factory does not do yet, with the reasoning for deferring them.
Each one names what would close it. Items here are not bugs: they are decisions
to ship without something, recorded so the next slice does not have to
rediscover them.

## Detect an implementation that crashes on every cycle

*(deferred 2026-09-20, TP-0036)*

Fresh-mode implementation now works in batches and pushes each one, so a crash,
a usage limit or a dead session costs one batch. But a crash that repeats every
cycle — the same increment killing the agent's context, an environment fault it
trips over immediately — leaves **no trace on disk at all**: the agent never
returns, so the write phase never runs, so there is no journal entry to count.
The no-progress guard only fires on a cycle that *returns* without having built
anything.

From the outside it looks exactly like a slow factory: each cycle picks the
ticket, prepares, dispatches, and vanishes. The `/loop` runner keeps going.

**What would close it:** a per-cycle marker the dispatcher writes *before* it
dispatches and clears after the write phase, so a cycle that finds an uncleared
marker for the same ticket knows the previous attempt died. It cannot live in
the clone — `prepare`'s `git clean -fd` deletes untracked files by design, and
an ignored path would survive a reset that is supposed to be total. A GitHub
side-channel (a label, a marker-block line) would work but adds a write per
cycle to the one path that is already the most write-heavy.

**Symptom if it bites:** the same ticket is picked every cycle, its journal
never grows, and the cycle reports never mention it because they are never
printed.

## Reduce the CI runs a landing costs

*(deferred 2026-09-20, TP-0034c)*

*(mostly closed 2026-09-20 by TP-0036's CI fast path; what remains is below)*

A landing costs up to two CI runs per attempt: one for the server-side sync
that brings the base branch in, and one for the commit that records the merge
decision. A restart — the base branch moved again before the merge cycle got
there — repeats both. The decision run exists only because the decision has to
be *on the branch*: the journal is the ticket's state (§3.3), and the required
check is evaluated on the pull request's head.

**The fast path addresses this**, and the ten-odd other bookkeeping runs a
ticket costs, by having the required check inherit the parent commit's result
when a push touches only `thoughts/` — the third of the "record the decision
without a new run" options this item named, delivered as a fragment the project
pastes into its own job. It reports the check rather than skipping it, which is
what a path filter gets wrong.

**What remains open:** the fast path is the *project's* to install, and
`/tsf:init` can only ask whether it was. A project that declines, or installs it
wrongly, still pays the full cost, and nothing the factory can call will notice.
Closing this properly needs a way to observe that a docs-only push reported in
seconds — plausibly comparing a check run's `started_at` and `completed_at` on a
known bookkeeping commit — which is a lot of machinery for a cost problem.

**Symptom if it bites:** CI minutes dominated by bookkeeping commits, and
landings that take many attempts on a busy base branch until
`landing_attempt_bound` parks them.

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

## Tell an environment-wide prepare or push failure from a ticket's own

*(deferred 2026-09-21, final pre-first-run review)*

When the project's `prepare` script exits non-zero, `cycle-write-phase.md`
("Prepare failed") parks the picked ticket `tsf:needs-human` on GitHub, and a
failed push in the write sequence is handled the same way. That is right when
the ticket's branch is what is broken. It is wrong when the cause is shared by
every ticket — `git fetch` cannot authenticate, the token expired, GitHub's git
endpoint is down while REST still answers: the next cycle picks the next ticket
and parks it too, one per cycle, until the backlog is parked and each ticket has
to be re-queued by hand. The preflight and the scan already end a cycle with no
write on their own failures; this path is the odd one out. The write phase only
asks the dispatcher to *say* so in the report when a failure looks
environment-wide.

Deferred by user decision: accepted as a known risk for the first runs.

**What would close it:** on a `prepare` failure, run `prepare <base> <base>`
before parking. If that fails too, the cause is environment-wide — report it and
write nothing, like a failed preflight. Park the ticket only when the base
branch prepares and the ticket branch does not. For a failed push, one retry
before parking, and the same base-branch probe.

**Symptom if it bites:** several tickets labelled `tsf:needs-human` within a few
cycles, each with a "prepare script failed" comment naming the remote, the
network or authentication rather than anything about the ticket.

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

## Survive a project hook that rewrites or rejects a bookkeeping commit

*(deferred 2026-09-22, first-consumer handover review)*

The write phase commits the journal, the gate reports, the dossier and the
landing decision with a plain `git commit`, and treats a non-zero exit as a
failed write that parks the ticket. A project's pre-commit hooks run inside
that commit. A formatter hook — the first consumer runs prettier on every
staged file — rewrites a journal entry and a gate report in place (blank lines
after headings, re-aligned tables) and then fails the commit *because* it
modified files, expecting a human to re-stage and retry. The write phase has
no such path, so every bookkeeping commit in that project would fail and park
its ticket, and the rewritten files would no longer match what the plugin's
own parsers (`plan.sh`, the report's machine lines, the journal's `Next step`)
expect.

Deferred because the first consumer excludes `thoughts/factory/` from its
formatter hook instead, which is the right fix for that project and costs one
line. `/tsf:init` does not check for it, and `--no-verify` was rejected: the
agents' own rule is never to bypass hooks, and a commit hook is the project's
to keep.

**What would close it:** `/tsf:init` detecting a formatter or linter hook that
matches `thoughts/**` (a `.pre-commit-config.yaml`, a `git-hooks` block, a
`lint-staged` entry) and asking the user to exclude `thoughts/factory/` from
it, plus a line in the README and the clone checklist. A retry in the write
phase would not help — the rewritten file is the problem, not the failed
commit.

**Symptom if it bites:** the first cycle that writes a journal entry parks the
ticket with a "failed write" comment quoting the formatter, and
`git status` in the clone shows `thoughts/factory/GH-<n>/journal.md` modified
and unstaged.

## Allow tce and tsf side by side on one codebase

*(noted 2026-09-24, from chat-sustainability GH-74)*

`README.md:14-15` says "a project uses either tce or tsf for its ticket work,
not both", and `DESIGN.md` §16.21 (superseding the coexistence half of §16.12)
repeats it. The reason given is that no rule kept a supervised tce session and
the factory off the same ticket. That reason is about one ticket, not one
codebase: the `tsf:*` state labels already mark which issues are the
factory's, and the factory acts only on those.

The first consumer runs both on purpose and closes the gap on its side: tce
never researches, plans or implements an issue that carries a `tsf:*` label,
and nobody sets a `tsf:*` label on an issue tce is working.

**What would close it:** reword `README.md:14-15` and `DESIGN.md` §16.21 (and
the v1 limitation in `DESIGN.md:64-72`) to "side by side is supported when
each ticket belongs to exactly one of them", name the per-ticket exclusivity
rule as the consumer's responsibility, and have `/tsf:init` ask whether the
project also uses tce and point to that rule.

**Symptom if it bites:** a reader of the plugin docs concludes the consumer's
setup is unsupported, while it is only a per-ticket rule the docs do not name.

## Parallel factories — the next step after TP-0038, and important

*(noted 2026-09-27, from the first chat-sustainability run)*

One runner works one ticket per cycle. DESIGN.md §16 names "parallel
factories" (several runners on one repository) as the follow-up to the
`claude -p` runner, and it is the next step to take once TP-0038 has shipped
that runner: a backlog of independent tickets should not wait on one factory's
CI and review latency.

The interesting part is the pick. TP-0038 moves Step 3's actionability rules
into a script the runner calls **before** it starts a session, and a session
takes seconds to minutes to reach its own Step 3 and act. In that window the
scan still shows the ticket in its actionable state, so a second runner picks
the same ticket, and both `prepare`, dispatch an agent and race to push the
same branch. Nothing in the state machine prevents it today: the labels are a
cache, the journal is on the branch, and the first write that would reveal the
collision is the push — which the loser sees as non-fast-forward, after it has
spent a full agent dispatch.

**What would close it:** a claim that is written before the work starts and
visible to the scan — a factory-side label such as `tsf:working` set by the
runner (or the dispatcher's first act) with a read-back, so a concurrent scan
skips the ticket; the claim must expire (a runner that dies mid-cycle must not
lock its ticket forever), which means it needs a timestamp and a bound like
`ci_pending_bound`, and the write-phase must clear it. The pick script from
TP-0038 is where the skip rule lives, so it should be designed knowing this
rule is coming. Alternatives to weigh: a per-runner queue partition (runner
`k` of `n` takes tickets with `n mod k`), which avoids the claim but wastes a
runner while its partition is empty.

**Symptom if it bites:** two pull requests or two journal pushes for one
ticket, one of them rejected as non-fast-forward after its agent finished, and
a parked ticket whose journal shows a cycle that never happened.
