# tce — Toby Context Engineering

A context-engineering development workflow for Claude Code: a chain of context
artifacts built step-by-step — **ticket → intent → research → plan → implement** — that gives
Claude the right context at each stage of a task, so a good result is something you
can repeat on purpose instead of hope for. Also included: commands for review,
technical discussion, and design exploration, plus a set of research subagents the
commands rely on.

In a hurry? `/tce:work` takes a ticket with an intent all the way to a verified,
delivered change — each step in a fresh agent, asking you only while it plans — and
`/tce:quickfix` runs a small fix from your description to a verified change — no
ticket. Both keep the benefits of context engineering without you watching every
step.

tce is **ticket-system-agnostic**: tickets are the entry point, but where they live is
up to the project — the [tmt](../tmt/README.md) plugin (markdown tickets in your repo,
tce's native backend), GitHub Issues, Jira, Linear, or anything you can describe.
`/tce:init` configures the integration in `.claude/tce/tickets.md`. The plugin installs
once and **updates centrally** — no more copying files into each project and merging
changes by hand. Everything project-specific lives in a small `.claude/tce/` config that
`/tce:init` creates; commands are namespaced under `/tce:`.

> **Built by Toby.** These plugins come out of my daily practice helping
> engineering teams turn experimental AI use into structured, sustainable
> workflows. Need a sparring partner for the hard technical and AI-adoption calls?
> Find me at [rent-the-toby.com](https://rent-the-toby.com).

## Contents

- [See it work](#see-it-work)
- [Why context engineering?](#why-context-engineering)
- [Requirements](#requirements)
- [Install](#install)
- [Set up a project](#set-up-a-project)
- [Update](#update)
- [Commands](#commands)
- [Running the step commands](#running-the-step-commands)
- [Agents](#agents)
- [How project parameterization works](#how-project-parameterization-works)
- [Contributing](#contributing)

## See it work

Say you want to add **document tagging** to your app. Here is that one task run
through tce — and the trail it leaves behind:

1. **`/tce:ticket`** — your words go into the tracker as
   `thoughts/shared/tickets/[PREFIX]-XXXX-document-tagging.md` (or an issue in
   whatever system you use).
2. **`/tce:intent`** — you and tce agree scope, anchors into the code,
   acceptance criteria and decisions in
   `thoughts/shared/intents/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md`; the
   ticket stays untouched.
3. **`/tce:research`** — subagents fan out across your codebase and the web, and the
   findings (existing patterns, constraints, the right library) land in
   `thoughts/shared/research/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md`.
4. **`/tce:plan`** — ticket + intent + research become a phased, reviewable plan in
   `thoughts/shared/plans/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md`; you sign off
   on the approach *before* a line of code is written.
5. **`/tce:implement`** — tce works the plan phase by phase, logging progress into
   the plan itself, running your tests, and committing as it goes — then a
   fresh-context plan-compliance check confirms the diff meets the ticket + plan
   criteria before the ticket is marked done.

```
thoughts/shared/
├── tickets/[PREFIX]-XXXX-document-tagging.md                 # WHAT & WHY, in your words
├── intents/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md       # what you and tce agreed
├── research/YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md      # how the code actually works
└── plans/
    └── YYYY-MM-DD-[PREFIX]-XXXX-document-tagging.md           # the approach you approved
                                                               #   + per-phase progress log
```

**"But Claude already handles a task like that fine."** Often, yes — for one
well-specified task, in one session, it lands on the first try. tce isn't here to
dispute that; it's here for what that misses:

- **Repeatable, not lucky.** Each step spends Claude's limited attention on a single
  job — understand, then decide, then build — so quality you got by luck once becomes
  quality you get by default. By the time code is generated the thinking is already
  done, and generation is "auto-complete on steroids": translating a formed plan, not
  improvising one.
- **A trail your team inherits.** Every step is a Markdown file committed to the repo,
  so your teammates — and the next Claude session — start from the same ticket,
  research, and plan you did. Output levels up across the whole team, not just for
  whoever wrote the best prompt that day, and the repo gets *better at being worked
  on* with every ticket.
- **You stay the decision-maker.** You ride on top of the model — the "centaur" —
  owning intent and scope while it does the legwork, approving the plan up front
  instead of reviewing "AI slop" after the fact.

So solo you gain reliability and a record you'll thank yourself for later; on a team
you gain one shared standard everyone's work converges on.

## Why context engineering?

That walkthrough works because each step hands Claude exactly the context it needs for
the job in front of it, then writes that context down. LLMs perform best when given
the right context at the right time, and the workflow builds it progressively through
documents stored in `thoughts/`:

1. **Tickets** capture business requirements (the WHAT, WHY and acceptance criteria)
2. **Research** documents existing codebase patterns, constraints and finds the right
   API/library/tool documentation for proper implementation
3. **Plans** synthesize requirements + research into actionable steps
4. **Implementation** executes with full context from the previous phases

Each phase produces artifacts that persist across sessions, so Claude always has the
context it needs without repeated explanation. Because that record stays in Git, the
next ticket — and your teammates — start from it instead of from a blank prompt: the
project gets easier to work on over time, and quality stops depending on who happens
to be driving.

The plugin supersedes the previous
[Claude Code template](https://github.com/tobyS/claude-template) — installed once and
updated centrally instead of copied per project. Also read more
[on my blog](https://schlitt.info/blog/0793_context_engineering_claude_code.html)
about why I created this process.

## Requirements

The workflow itself is plain Markdown and needs nothing special, but the shipped
scripts have small external dependencies:

| Tool              | Needed for                                                                  | Required?                                                                                             |
| ----------------- | --------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `git`             | everything (the workflow lives in your repo)                                | **Required**                                                                                          |
| a ticket system   | tickets are the entry point of the workflow                                 | **Required** — tmt (markdown tickets in the repo), GitHub Issues, Jira, Linear, or custom             |
| `gh` (GitHub CLI) | GitHub permalinks in `/tce:research`; reading/creating tickets when GitHub Issues is the backend; opening the pull request under **Pull request** delivery | Optional — required only for the GitHub Issues ticket backend and for Pull request delivery |

`/tce:init` checks for these tools and helps you pick — and verify access to —
the ticket system. Hosted backends (Jira, Linear, custom) need whatever access
tooling you document for them in `.claude/tce/tickets.md`.

## Install

```bash
# Add the marketplace (once per machine), then install the plugin:
/plugin marketplace add tobyS/toby-plugins
/plugin install tce@toby-plugins
```

## Set up a project

In each project where you want the workflow:

```bash
/tce:init
```

You usually don't have to remember this. When you enable the plugin, Claude Code
shows a short "what tce is / run `/tce:init` next" greeting (the plugin's
`show_setup_reminders` user setting). And in any project that isn't set up yet, a
`SessionStart` hook detects the missing `.claude/tce/` config and prompts Claude
to introduce tce and offer to run `/tce:init` for you — so fresh clones get the
nudge too. If the project carries an install of the original
[claude-template](https://github.com/tobyS/claude-template) (the plugins'
predecessor), the nudge says so and offers the migration instead. Once the
project is initialized the hook goes quiet; you can also turn the reminders off
via the `show_setup_reminders` setting.

`/tce:init` analyzes the project, proposes a profile (stack, test/lint/typecheck
commands, conventions, the **commit convention** tce should use — Conventional
Commits, plain, or issue-reference, pre-selected from your git history — and the
**branch convention**: work on the current branch, or one branch per ticket cut from
a fetched base — plus the **delivery** rule (direct or pull request) and an
optional **reader** description) and detects the likely **ticket system** (tmt, GitHub Issues, Jira, Linear, or custom), discusses
everything with you — including whether tce may transition ticket statuses and create
tickets in your ticket system — and, once you confirm, writes:

```
.claude/tce/
├── profile.md       # stack, commands, conventions, commit + branch convention, delivery, reader (read by the commands at runtime)
├── tickets.md       # which ticket system the project uses and how tce works with it
└── design-system.md # optional, for /tce:design_explore
thoughts/shared/{intents,research,plans,reviews,mockups,discussions,dossiers}/
```

(`thoughts/shared/tickets/` belongs to the tmt plugin and is scaffolded by
`/tmt:init` when tmt is your ticket system.)

**Migrating from the original claude-template?** `/tce:init` detects the
template's files (un-namespaced `.claude/commands/*.md` and `.claude/agents/*.md`,
root `scripts/ticket.sh`, CLAUDE.md workflow boilerplate, the design-system
skeleton), proposes the migration, and removes the superseded files only after
your confirmation — a customized design-system file is moved to
`.claude/tce/design-system.md` instead. `/tmt:init` handles the ticket side
(prefix harvesting, the template's ticket scripts and settings.json hook
entries). Everything under `thoughts/shared/` carries over untouched.

Commit `.claude/tce/` — it's shared project config, not personal settings. The
commands read these files at runtime, so **you never edit the plugin** to adapt
it to a project.

## Update

```bash
/plugin marketplace update toby-plugins
```

You move to a new version of the plugin whenever you refresh the marketplace.

## Commands

Plugin commands are namespaced under `/tce:`. The core workflow is the
ticket → intent → research → plan → implement chain; the rest support and accelerate it.

**Core workflow** — the context chain, run in order:

| Command           | Purpose                                                                       |
| ----------------- | ----------------------------------------------------------------------------- |
| `/tce:ticket`     | Create a ticket in your ticket system from your own text (any backend)        |
| `/tce:intent`     | Agree with tce what the ticket means here (scope, anchors, criteria, decisions); never edits the ticket |
| `/tce:research`   | Research the codebase, find patterns & libraries                              |
| `/tce:plan`       | Resolve questions, write the plan, approve it from a short brief              |
| `/tce:implement`  | Implement every phase, verify, run the compliance gate, write the dossier     |

`/tce:research`, `/tce:plan`, `/tce:implement` and `/tce:work` each take
`<ticket ID | intent path>` and run their step(s) in fresh agents, exactly as
`/tce:work` does ([details](#running-the-step-commands)). An **intent path**
lets you run without a ticket: write a ticketless intent with `/tce:intent
"<description>"` (good for small or developer-only work) and pass its path,
e.g. `/tce:research thoughts/shared/intents/YYYY-MM-DD-<slug>.md`. The
documents are then named `YYYY-MM-DD-<slug>.md`, no branch is cut, no ticket
is closed, and `/tce:work` delivers Direct.

**Shortcuts** — run the chain with reduced interaction:

| Command          | Purpose                                                                            |
| ---------------- | --------------------------------------------------------------------------------- |
| `/tce:work`      | Take a ticket (or intent path) with an intent to a delivered change: each step in a fresh agent, questions only while planning ([details](#running-the-step-commands)) |
| `/tce:quickfix`  | Small fix from a description: writes a ticketless intent itself, then runs the same agents without plan approval to a verified change and a dossier; no ticket, no branch, no delivery. Stops and says so when the fix turns out larger (more than two phases, or a UX change) |

**Helpers** — supporting commands you reach for as needed:

| Command               | Purpose                                                             |
| --------------------- | ------------------------------------------------------------------ |
| `/tce:discuss`        | Technical discussion / sparring partner                            |
| `/tce:list`           | List tickets with their tce stage (research / plan / implementation) |
| `/tce:review`         | Review an implementation (ticket-based or custom scope)            |
| `/tce:commit`         | Commit with pre-commit checks and the profile's commit convention  |
| `/tce:design_explore` | _(Optional)_ Explore and select a visual design for non-trivial UX |

**Maintenance** — project setup & keeping config in sync:

| Command         | Purpose                                                                                 |
| --------------- | --------------------------------------------------------------------------------------- |
| `/tce:init`     | Analyze the project and write `.claude/tce/` config                                     |
| `/tce:refresh`  | Reconcile `.claude/tce/profile.md` with the repo when it drifts (per-section, approved) |

Research also watches for profile drift while it works: if the
codebase has outgrown `profile.md` (a new stack, a build/test command that no longer
exists, a moved directory), it adds a non-blocking note suggesting you run
`/tce:refresh`. `/tce:refresh` re-analyzes the repo, proposes per-section changes, and
writes only what you approve — leaving your hand-written Conventions, branch, delivery and reader
sections and research sources untouched.

## Running the step commands

`/tce:research`, `/tce:plan`, `/tce:implement`, `/tce:quickfix` and `/tce:work`
are orchestrators over the same agents and the same loop: each runs its step(s)
of the chain in a fresh agent, keeps its own context small, and talks to you in
one place — planning. `/tce:work <ID>` runs the whole chain, described below;
the single-step commands run their part of it and stop, printing the next
command. Every one of them takes a ticket ID or an intent path.

- `/tce:research` runs step 2 and stops. It refuses without an intent, and a
  free-form question is pointed to `/tce:intent` or `/tce:discuss`.
- `/tce:plan` runs step 3, including the brief and your approval.
- `/tce:implement` runs steps 4 to 7 on an approved plan — implementation,
  verification, the dossier and the closeout. It **never delivers**: under
  **Pull request** delivery it records the work as undelivered, and
  `/tce:work <ID>` then pushes and opens the pull request.
- `/tce:quickfix` runs all of it from a description, without the approval and
  without delivery.

1. **It needs an intent.** Agree one with `/tce:intent <ID>` first; without it,
   `/tce:work` refuses and says so. A ticket with a non-trivial UX change is
   asked about design exploration during planning — run `/tce:design_explore`
   before `/tce:work` if you want one.
2. **Research** runs in the `researcher` agent and is committed. No checkpoint.
3. **Planning** is where you are asked. The `planner` returns its understanding
   and its open questions *before* writing anything; you answer them in a
   dialog, one decision per question, recommended option first. It then writes
   the plan, the `plan-challenger` checks it, and you approve it from a short
   **brief** — what was understood, the approach, the decisions made on your
   behalf, the phases with counted facts. Push back in free text and you get
   only what changed.
4. **Implementation** runs one `implementer` agent per phase, each committing
   its phase and logging it in the plan. Failing checks get at most three fix
   rounds per phase.
5. **Verification** runs in the `verifier` agent: every test suite, the
   plan-compliance gate, then an attempt — with the shell and, if you have one,
   the browser — at every criterion the gate could not judge from the diff.
   Only what genuinely needs you (credentials, a third-party system, visual
   judgment, a decision) is left for you, with the exact command and what pass
   looks like. Failures go back to the implementer, at most three rounds.
6. **The dossier** — `thoughts/shared/dossiers/YYYY-MM-DD-<ID>-<slug>.md` —
   says what was built, where to look (with permalinks), what was decided for
   you, and what is left for you to check, with counted facts: criteria met,
   fix rounds, tests added. Under **Direct** delivery it is printed; under
   **Pull request** delivery `/tce:work` pushes the branch and opens a pull
   request with the dossier as its body. tce never merges.
7. **What is left for you** is listed in full at the end, and `/tce:work` asks
   whether it passes. The ticket is closed only when you confirm; answer
   "Not yet" and re-run `/tce:work <ID>` once you have checked.

The run stops early only when it needs a decision or is blocked, and then says
exactly what is needed and the command to continue.

**Start Claude Code with two variables exported** — `/tce:research`,
`/tce:plan`, `/tce:implement`, `/tce:quickfix` and `/tce:work` all check them
and refuse without them:

```bash
export CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1
export BASH_DEFAULT_TIMEOUT_MS=600000
```

The first makes agents run in the foreground, so each step's result arrives
while the command is still running (by default Claude Code runs agents in the
background). The second raises the Bash timeout to ten minutes: a real test
suite outlives the two-minute default, and with the first variable set a
command that hits its timeout is stopped rather than moved to the background.

**Accept the allowlist `/tce:init` offers.** The agents run outside
the command's own permission grant, so reading tce's reference files, writing
under `thoughts/shared/`, local git and your test commands would otherwise each
stop on a prompt. `/tce:init` appends exactly those entries to
`.claude/settings.json` on your approval (re-run it to get them in an existing
project); it never adds `git push` or `gh`.

**Headless runs (`claude -p`).** Verified on Claude Code 2.1.310, under
`claude -p` and interactively, with the command typed and with the model
invoking it through the Skill tool: from tce 1.5.1 on, each step command's own
`allowed-tools` grant covers its script calls headless, so no extra flag is
needed for them. Up to 1.5.0 the grants carried quotes inside the pattern and
matched only a call that quoted the script path; when the model wrote the path
unquoted the call was denied under `-p` (where nobody can answer a prompt) and
prompted interactively. On those versions, pass the scripts with
`--allowedTools` (the CLI flag that pre-approves tools for one run), e.g.
`--allowedTools "Bash(<plugin root>/scripts/stage.sh:*)"`, one entry per
script. The agents still need the `/tce:init` allowlist, and a project's
`.claude/settings.json` only applies once you have trusted the folder: in a
folder never opened interactively, `claude -p` denied every read of tce's
reference files despite the allowlist.

**Resume by re-running.** Every step's result is a committed document and the
plan logs each phase, so re-running the same command with the same argument in
a new session picks up at the next step without re-researching or re-planning.

## Agents

Specialized subagents bundled with the plugin (the first six research the codebase
and web for the `researcher`; the plan-compliance checker verifies criteria for
the `verifier`; the last five are the steps the step commands dispatch —
internal, not for direct use):

| Agent                     | Purpose                                     |
| ------------------------- | ------------------------------------------- |
| `codebase-locator`        | Find files and directories by topic         |
| `codebase-analyzer`       | Understand implementation details           |
| `codebase-pattern-finder` | Find similar implementations to model after |
| `thoughts-locator`        | Find documents in the `thoughts/` directory |
| `thoughts-analyzer`       | Extract insights from thought documents     |
| `web-search-researcher`   | Research external documentation             |
| `plan-compliance-checker` | Verify the diff against the ticket + plan criteria before a ticket is closed |
| `researcher`              | The research step: the research document, without questions |
| `planner`                 | The planning step: questions first, then the plan and its brief |
| `plan-challenger`         | Check a fresh plan and its brief against a fixed checklist before approval |
| `implementer`             | The implementation step: one plan phase per dispatch      |
| `verifier`                | Run the suites and the gate, attempt what the gate can't judge, write the dossier |

## How project parameterization works

The plugin is identical across projects; only `.claude/tce/` differs.

- **Ticket system** — described in `.claude/tce/tickets.md`: the canonical
  ticket ID format (used in thoughts/ filenames and commit scopes), how to read
  and create tickets, how to find parent/epic tickets, whether tce may
  transition statuses and which statuses are terminal, and how to enumerate
  tickets for `/tce:list` (including where complexity and priority live, if
  anywhere). The commands read it at runtime, so the same workflow
  runs against tmt, GitHub Issues, Jira, Linear, or anything you describe. In
  command docs, `[PREFIX]-XXXX` is just a placeholder for a canonical ID.
- **Stack, commands, conventions, commit convention** — live in
  `.claude/tce/profile.md`. Each command reads
  `${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md` at runtime, so e.g. `/tce:commit`
  runs _your_ test/lint/typecheck commands and writes messages in _your_ commit
  convention without the command being edited.
- **Branch convention** — also in `profile.md`. **Current branch** (the
  default, and what a profile without the section means) leaves tce
  branch-unaware, exactly as before. **Branch per ticket** makes `/tce:research`
  cut the ticket's branch (name pattern + base branch + remote from the profile)
  from a freshly fetched base before it writes anything, `/tce:plan`,
  `/tce:implement` and `/tce:review` switch to it in later sessions, and
  `/tce:commit` warn before a ticket-scoped commit on the base branch. When the
  base cannot be fetched (offline, no remote) tce stops and asks rather than
  branching from another tip. Non-ticket work and ticket creation are never
  moved. Only `/tce:work` under **Pull request** delivery pushes; the git steps
  live in `${CLAUDE_PLUGIN_ROOT}/scripts/branch.sh`.
- **Delivery** — also in `profile.md`. **Direct** (the default, and what a
  profile without the section means) leaves the finished work on its branch for
  you. **Pull request** requires **Branch per ticket** and reuses its base
  branch and remote: tce opens a pull request, you merge it, and the next ticket
  starts only after the merge. `/tce:work` acts on it at the end of a run:
  under Direct it prints the dossier, under Pull request it pushes the branch and
  opens the pull request with the dossier as its body. tce never merges.
- **Reader** — also in `profile.md`. Without the section tce assumes a reader
  fluent in the project's stack; with a description, `/tce:intent` and
  `/tce:work`'s questions, brief and dossier explain the terms outside your
  fluency the first time they appear. It governs vocabulary
  and depth, not length.
- **Scripts** are invoked via `${CLAUDE_PLUGIN_ROOT}/scripts/...` (substituted
  inline), so they resolve regardless of where the plugin is cached.
- **Document templates** (the intent, research and plan document skeletons) ship as
  reference files in the plugin's `references/` directory and are Read via
  `${CLAUDE_PLUGIN_ROOT}/references/...` at the moment a command writes the
  document — plugin-internal, never copied into your project, and re-read from
  disk so they survive long sessions.

## Contributing

Want to work on the plugin itself? See the repository's
[CONTRIBUTING.md](../../CONTRIBUTING.md) for the layout, how to validate changes, and
the release flow.
