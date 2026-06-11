---
description: Set up the tce workflow in this project — analyze the repo, agree a profile and ticket system, and write .claude/tce/ config + scaffold thoughts/.
---

# Initialize tce Workflow

You are tasked with setting up the **tce** context-engineering workflow in the
current project. This means analyzing the project, agreeing on its profile and
ticket system with the user, and writing the project-local config the other tce
commands rely on.

**Do not write any files until the user confirms** (Phase 4). Analyze first,
propose, discuss, then write.

## What gets created

All tce project config lives under `.claude/tce/` (Git-tracked, shared with the
team) plus the `thoughts/` document tree:

```
.claude/tce/
├── profile.md      # stack, commands, code map, conventions, research sources (read by commands & agents)
├── tickets.md      # which ticket system the project uses and how tce works with it
└── design-system.md # optional: design tokens for /tce:design_explore
thoughts/shared/{research,plans,reviews,mockups,discussions}/   # with .gitkeep
```

The slash commands (`/tce:commit`, `/tce:create_plan`, …) read `profile.md` and
`tickets.md` at runtime, so you never hand-edit the commands themselves. tce
requires *a* ticket system (tickets are the entry point of the workflow), but it
doesn't care which one — `tickets.md` is the adapter.

Note: `thoughts/shared/tickets/` is **not** scaffolded here — it belongs to the
tmt plugin (`/tmt:init` creates it) and only applies when tmt is the chosen
ticket system.

## Phase 0: Preflight — check dependencies

Before analyzing, verify the tools the workflow relies on and report the result
to the user:

```bash
command -v git >/dev/null && echo "git: ok" || echo "git: MISSING (required)"
command -v gh  >/dev/null && echo "gh: ok"  || echo "gh: not found (optional — for GitHub permalinks in /tce:research_codebase, required if GitHub Issues is the ticket system)"
```

- If **`gh` is missing**, note it's optional for permalinks — but it becomes
  required if the user picks GitHub Issues as the ticket system below.
- Continue with setup regardless — these are warnings, not blockers.

## Phase 1: Analyze the project

Investigate the repository to draft an accurate profile. Do this yourself (use
Glob/Grep/Read/Bash); spawn the `codebase-locator`/`codebase-analyzer` agents only
if the project is large and the layout is unclear.

Gather:

1. **Stack & tooling** — look for manifests and lockfiles: `package.json`,
   `composer.json`, `go.mod`, `pyproject.toml`/`requirements.txt`, `Cargo.toml`,
   `Gemfile`, `pom.xml`, `build.gradle`, etc. Identify languages, frameworks, and
   the package manager actually in use (bun/npm/pnpm/yarn, pip/uv/poetry, …).
2. **Commands** — derive the real **test**, **typecheck**, and **lint/format**
   commands from `package.json` scripts, `composer.json` scripts, `Makefile`,
   `Taskfile`, CI config (`.github/workflows/*`), etc. Note the directory each
   must run in (important for monorepos).
3. **Layout / code map** — detect monorepo vs single app and the top-level
   apps/packages, then build a **code map** of where each kind of code lives (entry
   points, application/business logic, models/schema, migrations, interface/UI/API,
   tests, config). The research agents (`codebase-locator`/`analyzer`/`pattern-finder`)
   rely on this map, so make it accurate.
4. **Conventions** — skim an existing `CLAUDE.md`/`README.md` and a couple of
   source files for naming, structure, and any explicit do/don't rules worth
   carrying into the profile.
5. **Preferred research sources** — from the detected stack, assemble the
   authoritative documentation URLs the `web-search-researcher` agent should
   prioritize: the official docs site for each language, framework, and major
   library/dependency in use (read `package.json`/`composer.json`/etc. dependency
   lists to find the notable ones). Propose concrete URLs (e.g. the framework's docs
   domain, the language reference, key library docs) — don't invent obscure ones;
   prefer official/maintainer sites you're confident about.
6. **Ticket system** — detect which system the project most likely uses, to
   pre-select it in Phase 2:
   - **tmt** — `.claude/tmt/config` exists, or `thoughts/shared/tickets/` contains
     `<PREFIX>-NNNN-*.md` files, or a legacy `TICKET_PREFIX=` line sits in
     `.claude/tce/config` (projects set up by tce ≤1.x, where the ticket system
     was built in).
   - **GitHub Issues** — the `origin` remote points at github.com AND there are
     signals issues are actually used (`#NNN` references or `Fixes #NNN` in
     recent commit messages, issue templates under `.github/`).
   - **Jira** — `KEY-123`-style uppercase ticket keys in recent commit messages
     or branch names, or Jira URLs in the README/docs.
   - **Linear** — Linear-style keys (e.g. `ENG-123`) plus `linear.app` links in
     README/PRs/docs, or a `.linear` config.
   - Treat all of these as a *suggestion* — the user decides in Phase 2.
7. **Existing setup** — check whether `.claude/tce/profile.md` or
   `.claude/tce/tickets.md` already exist (see "Idempotency" below).

## Phase 2: Propose

Present your findings and proposed config for review. Do **not** write anything yet.

```
Here's what I found and what I propose for the tce setup:

**Stack:** [summary]

**Proposed commands (profile.md):**
- Test:      [command(s) + directory]
- Typecheck: [command(s) or "none"]
- Lint:      [command(s)]

**Layout / conventions to record:** [summary]

**Preferred research sources** (for /tce:research_codebase web lookups):
- [https://docs.example-framework.com] — [framework] official docs
- [https://lang-reference.example.org] — [language] reference
- [https://lib.example.com] — [notable dependency] docs
  → Add, remove, or correct any of these.

**Design system file?** [Yes if the project has a frontend you'll mock up with
/tce:design_explore — I'll seed .claude/tce/design-system.md from the template;
otherwise No.]
```

Then ask about the **ticket system** with the AskUserQuestion tool. tce requires
one — tickets are the entry point of the workflow. Offer these options, putting
the detected system first with "(Recommended)" and noting *why* you detected it
in its description:

1. **tmt (Toby Markdown Tickets)** — tickets as markdown files in the repo
   (`thoughts/shared/tickets/`), via the tmt plugin.
2. **GitHub Issues** — accessed through the `gh` CLI.
3. **Jira** — requires the user to say how Claude reaches Jira (CLI tool, MCP
   server, REST API + token).
4. **Linear** — requires the user to say how Claude reaches Linear (MCP server,
   CLI).

(The user can pick "Other" for any custom system and describe it.)

Follow up — in the same AskUserQuestion call where sensible — on the two policy
choices recorded in `tickets.md`:

- **Status transitions**: should tce update the ticket's status itself (mark in
  progress when work starts, done/closed when an implementation completes), or
  only remind the user? For tmt default to *tce updates the status*; for shared
  team systems (Jira/Linear/GitHub) lean toward *remind only* unless the user
  says otherwise.
- **Ticket creation**: may tce create tickets autonomously (used by
  `/tce:quickfix`)? If not, quickfix will refuse and point the user at creating
  the ticket manually + `/tce:work`.

For anything genuinely ambiguous in the rest of the proposal (e.g. which of
several test commands is canonical), ask the user — use AskUserQuestion when a
small set of concrete options exists.

## Phase 3: Refine

Iterate with the user until they confirm. Adjust the commands, code map,
conventions, preferred research sources, ticket-system answers, and whether to
include the design system file based on their feedback.

For non-file ticket systems, **verify access before writing**: ask the user for
an existing ticket reference and try the read mechanism (e.g. `gh issue view 123`,
the Jira CLI/MCP call). If it fails, resolve tooling/auth with the user now —
`tickets.md` must only document mechanisms that actually work.

If the user picked **tmt** and it isn't set up yet (no `.claude/tmt/config`),
tell them how to get it — do not try to set it up from here:

```
tmt isn't set up in this project yet. Install and initialize it first:
  /plugin install tmt@toby-plugins   (if not installed)
  /tmt:init                          (agrees a ticket prefix, scaffolds thoughts/shared/tickets/)
Then re-run /tce:init — I'll pick up the tmt config from there.
```

You may finish the rest of the tce setup in the same run and leave the
ticket-system section marked as pending tmt; in that case remind the user to
re-run `/tce:init` after `/tmt:init`.

## Phase 4: Write (only after explicit confirmation)

All seeded files come from the plugin's `templates/tce/` directory. **Copy the
skeletons into the project, then fill in the analyzed values** — `templates/tce/` is
the single source of truth for their structure, so don't reproduce it from memory.

```bash
mkdir -p "${CLAUDE_PROJECT_DIR}/.claude/tce"
cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/profile.md" "${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md"
cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/tickets.md" "${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md"
```

1. **`.claude/tce/profile.md`** — fill in every section from your analysis: Tech stack,
   Commands, Code map, Conventions, and Preferred research sources. Replace the
   `[...]` / `<...>` / `https://...` placeholders with real values, and delete guidance
   lines and table rows that don't apply. (Read the copied file first to see the exact
   structure to populate.)

2. **`.claude/tce/tickets.md`** — fill the backend sections (System, Canonical
   ticket ID, Reading, Parent/epic, Creating, Status/completion) for the agreed
   system and policy choices. Leave the "What tce needs from a ticket" section
   untouched — it is backend-independent. Guidance per system:

   - **tmt**: tickets are files at `thoughts/shared/tickets/<PREFIX>-NNNN-slug.md`
     (prefix from `.claude/tmt/config`); canonical ID `<PREFIX>-NNNN`, sub-tickets
     `<PREFIX>-NNNNa`; *reading* = read the matching file; *parent* = strip the
     letter suffix and read that ticket; *creating* = determine the next free
     number by scanning the directory for the highest `<PREFIX>-NNNN`, then write
     the file following the structure of existing tickets (statuses: Open,
     In Progress, Done, Rejected — a tmt hook validates them); *status* = edit the
     `**Status:**` line.
   - **GitHub Issues**: canonical ID `GH-<n>` in filenames/commit scopes (the
     issue itself is `#<n>`); *reading* = `gh issue view <n> --comments`;
     *parent* = linked/tracking issues if the project uses them; *creating* =
     `gh issue create --title ... --body ...` (if allowed); *status* =
     `gh issue close <n>` or remind-only, per the policy choice.
   - **Jira / Linear / custom**: write down exactly the access mechanism the
     user confirmed in Phase 3 (CLI invocations, MCP tool names, URL patterns),
     the canonical ID form (native keys like `ABC-123` usually work as-is), and
     the agreed creation/transition policy.

3. **`.claude/tce/design-system.md`** (only if agreed) — copy the template; the user
   fills in real tokens later:

   ```bash
   cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/design-system.md" "${CLAUDE_PROJECT_DIR}/.claude/tce/design-system.md"
   ```

4. **Scaffold the `thoughts/` tree** (skip any that already exist), with a
   `.gitkeep` in each so empty dirs are committable. (`tickets` is deliberately
   absent — that's tmt's directory.)

   ```bash
   cd "${CLAUDE_PROJECT_DIR}"
   for d in research plans reviews mockups discussions; do
     mkdir -p "thoughts/shared/$d"
     touch "thoughts/shared/$d/.gitkeep"
   done
   ```

5. **Confirm and hand off:**

   ```
   tce is set up:
   - .claude/tce/profile.md
   - .claude/tce/tickets.md    (ticket system: [system])
   - [.claude/tce/design-system.md — remember to fill in real tokens]
   - thoughts/shared/* scaffolded

   Commit these, then start the workflow from a ticket:
   [tmt: /tmt:create | other systems: create a ticket there, then /tce:research_codebase <ID> or /tce:work <ID>]
   ```

   Do **not** commit automatically — leave that to the user (or suggest `/tce:commit`).

## Idempotency

If `.claude/tce/profile.md` or `.claude/tce/tickets.md` already exist, do not
clobber them. Read them, show what differs from your fresh analysis, and ask
whether to update specific values. Treat re-running `/tce:init` as "review and
amend the existing setup," not "start over."

**Legacy projects:** a `.claude/tce/config` file (with `TICKET_PREFIX=`) comes
from tce ≤1.x, where the ticket system was built into this plugin. tce no longer
reads it; the prefix now lives in `.claude/tmt/config` (the tmt plugin reads the
legacy file as a fallback until `/tmt:init` migrates it). Point the user at
`/tmt:init`, and suggest deleting `.claude/tce/config` once that has run.

## Notes

- Writing files under `.claude/` is an ordinary file write (it just needs the
  normal write approval). This command never edits `.claude/settings.json`.
- `.claude/tce/` is meant to be **committed** — it's shared project config, not
  personal settings.
