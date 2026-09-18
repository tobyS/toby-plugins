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
