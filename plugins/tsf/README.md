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

## Slice 2 (0.2.0) scope

tsf is released in three slices. This version is slice 2:

- **Works:** `/tsf:init` (project setup), `/tsf:spec` (authoring a ticket), and
  `/tsf:cycle` all the way from a released ticket to a **reviewed pull
  request** — triage, research, the plan gate, implementation, verification,
  the three gates, the dossier, and your review routed to rework or landing.
- **Not implemented yet:** the landing loop — syncing an approved branch,
  the integration gate and the merge (slice 3). `/tsf:cycle` reports a ticket at
  `tsf:landing` as "landing not implemented in this slice", leaves it alone, and
  works the other tickets. Until then you merge an approved pull request
  yourself.

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
export GH_TOKEN=...          # the factory account's token (credential source env)
claude                       # started in the clone
```

Then run `/tsf:cycle` once to see it work, and `/loop /tsf:cycle` to keep it
running. One cycle:

1. **Preflight** — contract scripts present, foreground mode on, the credential is
   the factory's. Any failure ends the cycle with a report and no write.
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
| `tsf:landing` | factory | Approved; landing is next *(slice 3)* |
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
