<!-- tsf-config-version: FILLED-BY-INIT -->
# tsf Project Configuration

> Read by `/tsf:cycle`, `/tsf:spec` and the tsf agents at runtime. `/tsf:init`
> writes it; keep it accurate, and re-run `/tsf:init` after changing the
> environment contract or the GitHub coordinates. The tsf scripts never read
> this file: the commands read it and pass every value on as an argument.

## Project profile

The factory's agents read this instead of guessing the stack. It never
contains anything a tsf command hardcodes.

### Tech stack

[Languages, frameworks, package manager, datastore — concise.]

### Commands

Run from the project root unless a directory is given.

- **Build:** `<command>`   [or "none"]
- **Test:** `<command>`   [repeat per suite if needed]
- **Lint:** `<command>`   [or "none"]

### Code conventions

[Project-specific do/don't rules an agent must honour: directory rules, naming,
testing expectations. Where things live, briefly.]

### Commit convention

[How commit messages are formatted. The ticket scope is the canonical ID
`GH-<n>`, e.g. Conventional Commits — `<type>(GH-<n>): <description>`, first
line under 72 chars, what/why not how.]

## GitHub

- **Repository:** `<owner>/<repo>`
- **Base branch:** `<branch>`
- **Required checks:** `<check display name>`, …   [the checks the base branch's
  ruleset requires, one backticked name per entry — the **check run's display
  name**, not the job id and not the workflow name. Only these decide whether a
  pull request is green, so a failing optional check (a preview deploy, a
  coverage bot) never sends a ticket into a fix round it cannot win. Which
  checks are required is not readable over the REST API tsf uses, which is why
  it lives here. `none` means this project runs no CI on pull requests: the
  factory then never waits for a check and the gates run on local evidence
  alone]
- **Branch pattern:** `<pattern>`   [must contain `<n>`, the issue number, e.g.
  `gh-<n>`; the canonical ticket ID stays `GH-<n>` whatever the pattern]
- **Factory login:** `<login>`   [the machine account that authors every factory
  commit, comment and PR; never one of the responders]
- **Credential source:** `env` | `proxy`   [env: `GH_TOKEN` holding the factory
  login's token is exported in the environment the runner session starts from —
  it comes from: <where the token is kept>; proxy: a credential proxy injects
  the factory token by repository URL and the tsf scripts pass nothing]
- **Responders:** `<login>`, …   [replies on the issue by these logins count as
  the human's answer; default: the repository owner]
- **Comment pickup:** `workflow` | `polling`   [workflow:
  `.github/workflows/tsf-comment-pickup.yml` swaps the label on a responder's
  reply; polling: `/tsf:cycle` reads the comments of parked tickets each scan]

## Environment contract

Paths relative to the project root; each must exist and be executable. The
factory never runs a destructive or environment-specific operation as an ad-hoc
command line — it runs these scripts.

- **prepare:** `<path>`   (`prepare <branch> <base-branch>` — pristine checkout of
  the branch, created from the base branch when it does not exist yet)
- **env_up:** `<path>`   (bring services up for the current checkout; idempotent)
- **env_reset:** `<path>`   (clean baseline for the current branch; run on ticket
  switch)
- **verify:** `<path>`   (the verification suite CI runs; exit code is the verdict)
- **env_check:** `<path>` | [not registered]   (optional fast health probe)
- **Verification mode:** `local` | `ci`   [local: `verify` runs in the factory's
  checkout; ci: the CI result on the pull request alone is the verification]

## Constants

- **verify_fix_bound:** 3   [verification fix attempts per verification episode]
- **gate_fix_bound:** 3   [gate fix rounds per verification episode]
- **ci_pending_bound:** 120   [minutes a required check may stay unstarted on a
  head before the ticket parks for a human. Measured from the head commit's
  committer date, so it survives a cycle that does not run. This is the net
  under everything GitHub leaves undocumented — a workflow that was never
  installed, a path filter that excludes the head, a runner that never picked
  the job up — not a timeout on a running check]
- **implement_batch:** 3   [increments built per implementation cycle in fresh
  mode. Each cycle pushes what it built, so a crash costs at most one batch
  rather than the whole plan. Rework and fix mode are one cycle each whatever
  this says]
- **landing_attempt_bound:** 3   [landing attempts before parking. One attempt
  is one decision cycle; a landing restarts when the base branch moves again
  before the merge cycle gets to it, so this bounds a landing that cannot
  converge on a busy base branch]
