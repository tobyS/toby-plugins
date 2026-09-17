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

## Slice 1 (0.1.0) scope

tsf is released in three slices. This version is slice 1:

- **Works:** `/tsf:init` (project setup), `/tsf:spec` (authoring a ticket), and
  `/tsf:cycle` for **triage, research and planning** — a released ticket is
  triaged or researched, planned, and parked with a plan summary for you to
  approve on the issue. Your reply is picked up; feedback revises the plan, an
  approval moves the ticket to `tsf:implement`.
- **Not implemented yet:** implementation, verification, the gates, the dossier
  and review handling (slice 2), landing (slice 3). `/tsf:cycle` reports a ticket
  at `tsf:implement` or later as "not implemented in this slice", leaves it alone,
  and works the other tickets.

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
4. **Dispatch** one step to a fresh agent — `tsf:triage`, `tsf:research` or
   `tsf:plan` — which commits its artifact and returns a result.
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

## Labels

| Label | Whose move | Meaning |
|---|---|---|
| `tsf:queued` | factory | Released by the human; the factory determines the first step |
| `tsf:research` | factory | Spec sufficient; research is next |
| `tsf:plan` | factory | Research done; planning is next |
| `tsf:implement` | factory | Plan approved; implementation is next *(slice 2)* |
| `tsf:verify`, `tsf:dossier`, `tsf:rework`, `tsf:landing` | factory | Later slices |
| `tsf:answered` | factory | You replied; the step that asked picks it up |
| `tsf:needs-answer` | you | Numbered questions posted |
| `tsf:needs-plan-approval` | you | Plan summary posted; awaiting your reply |
| `tsf:needs-review` | you | *(slice 2)* |
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

Slice 1 calls only `prepare`; the preflight checks all of them.

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
- **A reply is not picked up** — the pickup workflow only runs once it is on the
  default branch, and only for configured responders; until then set
  `Comment pickup: polling` in the config.
