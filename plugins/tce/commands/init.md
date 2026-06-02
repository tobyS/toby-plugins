---
description: Set up the tce workflow in this project — analyze the repo, agree a profile, and write .claude/tce/ config + scaffold thoughts/.
---

# Initialize tce Workflow

You are tasked with setting up the **tce** context-engineering workflow in the
current project. This means analyzing the project, agreeing on its profile with
the user, and writing the project-local config the other tce commands rely on.

**Do not write any files until the user confirms** (Phase 4). Analyze first,
propose, discuss, then write.

## What gets created

All tce project config lives under `.claude/tce/` (Git-tracked, shared with the
team) plus the `thoughts/` document tree:

```
.claude/tce/
├── config          # machine-readable: TICKET_PREFIX=<PREFIX>  (read by the ticket scripts)
├── profile.md      # stack, commands, code map, conventions, research sources (read by commands & agents)
└── design-system.md # optional: design tokens for /tce:design_explore
thoughts/shared/{tickets,research,plans,reviews,mockups,discussions}/   # with .gitkeep
```

The slash commands (`/tce:commit`, `/tce:create_plan`, …) read `profile.md` at
runtime and resolve the ticket prefix from `config`, so you never hand-edit the
commands themselves.

## Phase 0: Preflight — check dependencies

Before analyzing, verify the tools the workflow scripts rely on and report the
result to the user:

```bash
command -v git >/dev/null && echo "git: ok" || echo "git: MISSING (required)"
command -v jq  >/dev/null && echo "jq: ok"  || echo "jq: MISSING (required for the ticket-status hooks)"
command -v gh  >/dev/null && echo "gh: ok"  || echo "gh: not found (optional — only for GitHub permalinks in /tce:research_codebase)"
```

- If **`jq` is missing**, warn the user: the ticket-status hooks parse hook JSON with
  `jq` and won't fire without it (their work isn't blocked, but they lose the
  status-update reminders). Suggest installing it (`brew install jq`, `apt install jq`, …).
- If **`gh` is missing**, just note it's optional and only affects permalink generation.
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
6. **Existing ticket prefix** — if `thoughts/shared/tickets/` already has files,
   extract the prefix from their names. Otherwise propose one derived from the
   repo/directory name (short, uppercase, e.g. `MyApp` → `MYAPP`, an order system → `ORD`).
7. **Existing setup** — check whether `.claude/tce/config` or `.claude/tce/profile.md`
   already exist (see "Idempotency" below).

## Phase 2: Propose

Present your findings and proposed config for review. Do **not** write anything yet.

```
Here's what I found and what I propose for the tce setup:

**Stack:** [summary]
**Proposed ticket prefix:** [PREFIX]   (tickets will be named [PREFIX]-0001, …)

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

Anything to correct before I write these files?
```

For anything genuinely ambiguous (e.g. the prefix, or which of several test
commands is canonical), ask the user — use the AskUserQuestion tool when a small
set of concrete options exists.

## Phase 3: Refine

Iterate with the user until they confirm. Adjust the prefix, commands, code map,
conventions, preferred research sources, and whether to include the design system
file based on their feedback.

## Phase 4: Write (only after explicit confirmation)

All seeded files come from the plugin's `templates/tce/` directory. **Copy the
skeletons into the project, then fill in the analyzed values** — `templates/tce/` is
the single source of truth for their structure, so don't reproduce it from memory.

```bash
mkdir -p "${CLAUDE_PROJECT_DIR}/.claude/tce"
cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/config"     "${CLAUDE_PROJECT_DIR}/.claude/tce/config"
cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/profile.md" "${CLAUDE_PROJECT_DIR}/.claude/tce/profile.md"
```

1. **`.claude/tce/config`** — set `TICKET_PREFIX` to the agreed prefix (fill the empty
   value left by the template).

2. **`.claude/tce/profile.md`** — fill in every section from your analysis: Tech stack,
   Commands, Code map, Conventions, and Preferred research sources. Replace the
   `[...]` / `<...>` / `https://...` placeholders with real values, and delete guidance
   lines and table rows that don't apply. (Read the copied file first to see the exact
   structure to populate.)

3. **`.claude/tce/design-system.md`** (only if agreed) — copy the template; the user
   fills in real tokens later:

   ```bash
   cp "${CLAUDE_PLUGIN_ROOT}/templates/tce/design-system.md" "${CLAUDE_PROJECT_DIR}/.claude/tce/design-system.md"
   ```

4. **Scaffold the `thoughts/` tree** (skip any that already exist), with a
   `.gitkeep` in each so empty dirs are committable:

   ```bash
   cd "${CLAUDE_PROJECT_DIR}"
   for d in tickets research plans reviews mockups discussions; do
     mkdir -p "thoughts/shared/$d"
     touch "thoughts/shared/$d/.gitkeep"
   done
   ```

5. **Confirm and hand off:**

   ```
   tce is set up:
   - .claude/tce/config        (prefix: [PREFIX])
   - .claude/tce/profile.md
   - [.claude/tce/design-system.md — remember to fill in real tokens]
   - thoughts/shared/* scaffolded

   Commit these, then start the workflow with: /tce:create_ticket
   ```

   Do **not** commit automatically — leave that to the user (or suggest `/tce:commit`).

## Idempotency

If `.claude/tce/config` or `.claude/tce/profile.md` already exist, do not clobber
them. Read them, show what differs from your fresh analysis, and ask whether to
update specific values. Treat re-running `/tce:init` as "review and amend the
existing setup," not "start over."

## Notes

- Writing files under `.claude/` is an ordinary file write (it just needs the
  normal write approval). This command never edits `.claude/settings.json`.
- `.claude/tce/` is meant to be **committed** — it's shared project config, not
  personal settings.
