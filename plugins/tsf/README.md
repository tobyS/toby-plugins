# tsf — Toby Software Factory

An agentic software factory for a single-engineer project. tsf works a
GitHub-issue backlog: it picks the most important ready ticket, advances it
exactly **one work step per cycle** in a fresh agent context, talks to you
asynchronously **on the issue**, and keeps every substantive artifact — spec,
research, plan, journal — as a versioned file on the ticket's branch.

The point is to reduce your part to the decisions only you can make, and to make
each of them well informed: you write and release specs, answer batched
questions, and approve plans from a short summary. You never babysit a run or
read an agent transcript.

tsf is standalone: it does not need tce or tmt, and a project uses either tce or
tsf for its ticket work, not both. The full design — state machine, agents,
contracts, and the reasoning behind them — is in [`DESIGN.md`](DESIGN.md).

## Install

```
/plugin marketplace add tobyS/toby-plugins
/plugin install tsf@toby-plugins
```

tsf needs `git`, `gh` (used only as a REST client, `gh api`) and `jq`, both in your
working copy and in the factory's clone.

## How it runs: two checkouts, two identities

| | Your working copy | The factory's clone |
|---|---|---|
| Who works there | you | only the factory — nobody edits it |
| GitHub identity | your own login | a **second GitHub account** (a write collaborator) |
| Commands | `/tsf:init`, `/tsf:spec` | `/tsf:cycle`, `/loop /tsf:cycle` |

The factory must be its own account: every factory comment, commit and (later)
pull request is authored by it, and GitHub refuses a review of one's own pull
request. Its token is resolved explicitly on every call — from `GH_TOKEN` in the
factory's environment, or injected by a credential proxy — never from your `gh`
login.

## `/tsf:init`

Run it once in your working copy. It analyzes the project (seeding from a tce
profile if there is one), agrees the configuration with you, and writes
`.claude/tsf/config.md` only after you confirm. It then:

- checks the **environment contract** (below) — and refuses to finish while a
  mandatory script is missing, explaining what that script must do for your
  project and offering a skeleton;
- creates the `tsf:*` labels;
- checks the factory credential authenticates as the factory account, and that
  the factory account is not a responder;
- offers to append a permission allowlist to `.claude/settings.json`, so
  unattended cycles never stop on a prompt;
- offers the **comment-pickup workflow** (`.github/workflows/tsf-comment-pickup.yml`),
  which swaps a parked issue's label to `tsf:answered` when a responder replies;
- prints two checklists you apply yourself: the repository ruleset, and the
  factory clone's setup.

Commit what it wrote and get it onto the base branch — the factory's clone reads
it from there. Re-running `/tsf:init` never clobbers the config; it offers to run
the checks again, which is also how you finish an init that stopped at the
contract check.

## `/tsf:spec`

The interactive entry door. Describe what you want built; tsf works it into a spec
with you until it has a clear scope, an observable outcome and at least one anchor
into the system. On confirmation it creates, over REST and under your login:

1. the GitHub issue (title + a short human summary),
2. the ticket branch from the base branch (per your branch pattern, e.g. `gh-42`),
3. `thoughts/factory/GH-42/spec.md` committed on that branch,
4. a links block appended to the issue body,

and offers to release the ticket with `tsf:queued`. No checkout is touched.

You can also release a raw issue: label it `tsf:queued`, and the factory's triage
step writes the spec from the issue body and asks what it needs to know.

## `/tsf:cycle` and `/loop /tsf:cycle`

In the factory's clone:

```bash
export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
export BASH_DEFAULT_TIMEOUT_MS=600000
export GH_TOKEN=...          # the factory account's token (credential source env)
claude                       # started in the clone
```

Then run `/tsf:cycle` once to see it work, and `/loop /tsf:cycle` to keep it
running. One cycle:

1. **Preflight** — contract scripts present, foreground mode on, the Bash timeout
   raised, the credential is the factory's. Any failure ends the cycle with a
   report and no write.
2. **Scan** the open issues carrying a `tsf:*` label, and **pick** one: in-flight
   before new, `tsf:priority` first, then oldest.
3. **Prepare** — your `prepare` script resets the clone onto the ticket branch.
4. **Dispatch** one step to a fresh agent — `tsf:triage`, `tsf:research`,
   `tsf:plan`, `tsf:implement`, `tsf:verify-fix`, `tsf:manual-verify` or
   `tsf:dossier`, or the three gates together — which commits its artifact and
   returns a result.
5. **Write** — the journal entry is committed and pushed, the issue's links block
   updated, one comment posted, the next label set.
6. **Report** — what happened, what was skipped, and a suggested wait the
   self-paced `/loop` uses to schedule the next cycle.

`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` is required: without it, agents started
from an interactive session run in the background, and a cycle cannot wait for its
step to finish.

`BASH_DEFAULT_TIMEOUT_MS=600000` is required too. The Bash tool's default timeout
is two minutes, which most verification suites outlive, and a command that reaches
its timeout is moved to the background — which the foreground requirement above
forbids — or, with background tasks disabled, meets an outcome Claude Code does
not document. Either way the factory would be reading a non-result as a verdict.
Ten minutes is the floor `/tsf:cycle` enforces; it is also the documented default
ceiling, so raising the default alone raises both (the effective ceiling is the
larger of `BASH_DEFAULT_TIMEOUT_MS` and `BASH_MAX_TIMEOUT_MS`). If your suite runs
longer than ten minutes, raise both — but note that values above
`BASH_MAX_TIMEOUT_MS`'s own 600000 default are not documented as supported, so
confirm on your project that a long run actually completes.

### Answering the factory

Everything happens on the issue. When a step needs answers it posts numbered
questions and labels the issue `tsf:needs-answer`; the plan step posts a plan
summary and labels it `tsf:needs-plan-approval`. **Reply to the comment** — you
never touch a label. Reply `approved` to approve a plan; anything else is feedback,
and the plan is revised and summarized again. Only replies by the configured
responders count.

## From an approved plan to a reviewed pull request

Once you reply `approved` to a plan summary, the factory works without you until
the dossier lands on the pull request:

1. **Implementation** builds the plan increment by increment, running each
   increment's own verification immediately and committing it. A deviation
   reality forces is written into `plan.md` as a dated addendum that restates
   that increment's verification; a mismatch too large for an addendum comes
   back to you as questions on the issue, and the revised plan goes through the
   plan gate again.
2. **The pull request** opens as soon as the work is pushed — never a draft, so
   your CI runs on every push. Its title is the squash commit's subject and its
   body closes the issue.
3. **Verification** runs your `verify` script in the factory's checkout, then
   **attempts** every plan item flagged `**Manual**` with real checks —
   project commands, throwaway scripts, an MCP server. Only what genuinely needs
   a person (visual judgment, subjective acceptance, credentials the factory
   does not have) is escalated, and it reaches you in the dossier with the
   reason. A red verification goes to a bounded fix loop
   (`verify_fix_bound`); CI red with local green is reported as an environment
   difference rather than guessed at.
4. **The gates** run in one cycle, in parallel, each in a fresh context that
   sees only its own inputs: plan-compliance judges the diff against the plan's
   criteria, spec-coverage goes back to the spec alone, security classifies
   findings blocking or advisory. Each writes a numbered report to the branch
   and one line on the pull request. Any "not met" or blocking finding sends the
   ticket back to implementation in fix mode, bounded by `gate_fix_bound`; the
   gates then re-run on the new code.
5. **The dossier** is posted to the pull request and the issue gets
   `tsf:needs-review`. It opens with a summary written for triage — one sentence
   on what the change does, an **impact rating from 1 to 5** with the reason for
   it, and, where it is earned, a "start here" line linking the spot that
   deserves your attention first. Below that: the narrative, a curated list of
   permalinks with a reason each, the open items, and which other factory pull
   requests overlap. The rating is about impact and risk, never size — a
   three-line change to an authorization check rates higher than a thousand-line
   rename — so a 1 or 2 can be approved from the summary alone.
6. **Your review is the gesture.** Approve it, or request changes — that native
   review is what the factory reads. Changes requested sends it to rework, which
   returns it with a dossier addendum and a fresh verification episode. An
   approval that the code has since moved past is treated as stale, and you are
   asked again.

Free-text comments on the pull request are not read; questions go on the issue.

## Landing: what happens after you approve

Approving is the last thing you do. The factory then lands the work itself,
across **two cycles** — and the split is not an implementation detail, it is
forced by the rules your repository enforces.

Your ruleset requires the branch to be up to date and its checks to be green,
and it evaluates those checks **on the pull request's head commit**. So any
push — a journal entry included — makes the head unchecked and the merge
refused. The factory therefore decides in one cycle and merges in another:

1. **The decision cycle.** It asks GitHub to merge the base branch into the
   ticket branch (a merge, never a rebase, never a force-push). If that
   conflicts, a dedicated agent resolves it in the factory's clone and says
   whether the resolution was **mechanical** (imports, lockfiles, independent
   hunks) or **logic** (it had to choose between behaviours). Mechanical
   resolutions land; a logic one goes back through verification and asks you to
   approve again, because your approval no longer covers the code. If the base
   branch moved, the **integration gate** runs: it sees only this pull request,
   what the base branch gained since your approval, and the spec, and answers
   whether the two can break each other in ways the tests would not catch. Then
   the decision is written into the journal — "merge when CI on this head is
   green" — and pushed. CI runs on that commit.
2. **The merge cycle.** Once that check is green, the factory confirms nothing
   has moved, squash-merges over the API with the pull request's title as the
   subject, removes the state label, and deletes the branch. It writes nothing
   to the repository — that is the whole point of the split.

Only one landing is in flight at a time, oldest approval first: each merge makes
every other approved pull request out of date, so a second sync would just waste
a CI run. While one waits for CI, the factory works other tickets.

If the base branch moves again before the merge, the landing simply starts over
— that is routine, not a failure. `landing_attempt_bound` (default 3) stops a
landing that cannot converge and parks it for you, and every restart is named
in the cycle's report so you can see it happening before that.

If the combination turns out red in CI, the ticket leaves landing and re-enters
verification as a fresh episode: it is fixed, re-gated, and comes back to you
with an addendum.

### The ruleset settings the landing relies on

`/tsf:init` prints this as a checklist; it matters most here:

- **A pull request is required, with one approving review.** The approval is
  enforced by GitHub, not by the factory. The factory is a plain write
  collaborator on no bypass list — it can merge a pull request that satisfies
  every rule, and nothing else.
- **A required status check, with "require branches to be up to date" on.**
- **"Dismiss stale pull request approvals when new commits are pushed" — OFF.**
- **"Require approval of the most recent reviewable push" — OFF.**
  These two are load-bearing. The factory's own mechanical sync push would
  otherwise dismiss your approval, and the landing could never complete without
  asking you again for a change you already approved. The one thing a ruleset
  cannot express — re-approval only after a *logic-changing* push — is exactly
  what the factory does itself.
- **The workflow providing the required check must not path-filter
  `thoughts/**`.** A required check that is filtered out stays "expected" and
  blocks the merge forever — and the decision commit touches only `thoughts/`.

## Labels

| Label | Whose move | Meaning |
|---|---|---|
| `tsf:queued` | factory | Released by the human; the factory determines the first step |
| `tsf:research` | factory | Spec sufficient; research is next |
| `tsf:plan` | factory | Research done; planning is next |
| `tsf:implement` | factory | Plan approved; implementation is next |
| `tsf:verify` | factory | Pull request open; verification, CI and the gates run |
| `tsf:dossier` | factory | All gates green; the dossier is next |
| `tsf:rework` | factory | Changes requested; implementation addresses the review |
| `tsf:landing` | factory | Approved; the branch is synced, judged and merged |
| `tsf:answered` | factory | You replied; the step that asked picks it up |
| `tsf:needs-answer` | you | Numbered questions posted |
| `tsf:needs-plan-approval` | you | Plan summary posted; awaiting your reply |
| `tsf:needs-review` | you | CI green, dossier posted; awaiting your review |
| `tsf:needs-human` | you | Blocked: state mismatch, failed write, broken environment |
| `tsf:priority` | modifier | Pick before other tickets |

Labels other than `tsf:*` are never read or written. To resume a
`tsf:needs-human` ticket, fix the cause, remove `tsf:needs-human` and add
`tsf:queued`: the factory continues where the journal says it stood.

## The environment contract

The factory never runs a destructive or environment-specific command line itself;
it runs your project's scripts, registered in `.claude/tsf/config.md`:

| Script | Required | Called as | Must |
|---|---|---|---|
| `prepare` | yes | `prepare <branch> <base-branch>` | reset the clone to a pristine checkout of the branch, creating it from the base branch when it does not exist yet, and prune merged branches |
| `env_up` | yes | `env_up` | bring services up for the checkout; idempotent |
| `env_reset` | yes | `env_reset` | restore a clean baseline (or state that the suite manages its own) |
| `verify` | yes | `verify` | run the same verification CI runs; the exit code is the verdict |
| `env_check` | no | `env_check` | a fast health probe |

`prepare` runs every cycle. `env_up` runs in every implementation-flavored cycle
and must be idempotent; `env_reset` runs when the factory switches to a
different ticket, so consecutive cycles on one ticket keep a warm environment;
`env_check` runs before implementation when you registered one. The preflight
checks that all of them exist and are executable, every cycle.

Two constants in `.claude/tsf/config.md` bound the loops: `verify_fix_bound`
(verification fix attempts per episode) and `gate_fix_bound` (gate fix rounds
per episode), both 3 by default. A verification **episode** starts each time the
ticket enters `tsf:verify` — from implementation or from rework — so a reworked
change gets a fresh budget. Exhausting either parks the ticket
`tsf:needs-human` with what was tried.

## Troubleshooting

- **`foreground: missing`** — start Claude Code in the clone with
  `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` exported.
- **`identity: mismatch`** — the token authenticates as another account than the
  configured factory login. Check `GH_TOKEN` in the shell that started the session.
- **`identity: unavailable`** — no token (`GH_TOKEN` unset with source `env`), or
  the call did not reach GitHub.
- **`denied`** in a result — a request was refused before it reached GitHub (no
  GitHub response headers): a credential proxy or sandbox rule, not a GitHub
  permission. A GitHub refusal shows as `rejected` (often a `404` for missing
  permissions).
- **A step returns "blocked" about reading a template** — the agents read tsf's
  reference templates from the plugin's directory, outside the project. The
  allowlist entry `Read(~/.claude/plugins/**)` from `/tsf:init` covers it; add it
  if you skipped the allowlist.
- **A reply is not picked up** — the pickup workflow only runs once it is on the
  default branch, and only for configured responders; until then set
  `Comment pickup: polling` in the config.
- **A ticket sits at `tsf:verify` reporting `ci pending` forever** — the factory
  reads zero check runs as "CI has not started yet", because GitHub does not
  distinguish that from "this repository has no CI". Confirm your repository
  runs a workflow on `pull_request` (see `TODO.md`).
- **The gates keep re-running** — a gate report names the logic head it judged;
  when code changes, the reports go stale by design and the gates run again.
  Journal, report and dossier commits do not move the logic head, so they never
  trigger a re-run.
- **Your approval was ignored** — an approval counts only while no code commit
  follows it. If the factory pushed a fix after your review, the ticket stays
  parked and a dossier addendum asks you to look again.
- **A landing keeps restarting** — the base branch is moving faster than a
  landing takes (roughly two CI runs). Each restart is named in the cycle
  report; after `landing_attempt_bound` attempts the ticket is parked for you.
  Landing it by hand, or letting the base branch settle, both work.
- **The merge reports `blocked`** — GitHub refused it, and the `reason:` line
  is GitHub's own message: a missing approval, a required check that is not
  green, or a branch that is not up to date. The factory does not retry inside
  the cycle; the next one re-evaluates from scratch.
- **A landed issue still carries a `tsf:*` label** — the label clear or the
  branch deletion failed after the merge. Both are reported in the cycle's
  report rather than parking the ticket, because a closed issue is invisible to
  the factory's scan. Remove the label yourself; nothing else is affected.
