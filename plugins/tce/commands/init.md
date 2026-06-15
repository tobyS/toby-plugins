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

### AskUserQuestion dialog guidelines

When asking the user something, follow these rules:

- Use the AskUserQuestion tool when a small set of concrete options exists
  (2–4); ask in plain prose only when the answer is genuinely free-form.
- Print a short intro paragraph (1–3 plain sentences) as a normal message
  before invoking the tool — it carries all context. The question text contains
  only the question itself: no background, no nested parentheticals.
- Put the recommended or detected option first, append " (Recommended)" to its
  label, and give the reasoning (e.g. how it was detected) in that option's
  description.
- At most 4 questions per call — batch related questions into one call. Never
  offer an "Other" or "custom" option: the tool adds one automatically.
- Headers ≤12 characters; labels 1–5 words; descriptions 1–2 plain sentences on
  what choosing the option means. Plain text only — markdown is not rendered
  inside the dialog.
- Use multiSelect only when choices are not mutually exclusive, and phrase the
  question accordingly.

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

The slash commands (`/tce:commit`, `/tce:plan`, …) read `profile.md` and
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
command -v gh  >/dev/null && echo "gh: ok"  || echo "gh: not found (optional — for GitHub permalinks in /tce:research, required if GitHub Issues is the ticket system)"
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
8. **Template install** — detect leftovers of the original
   [claude-template](https://github.com/tobyS/claude-template), the
   plugins' predecessor. Check regardless of whether `.claude/tce/` exists —
   a migration may be half-done. Record which of these tce-superseded
   artifacts are present; they feed the cleanup step in Phase 4:
   - `.claude/commands/{research,plan,implement,commit,review,design_explore,discuss}.md`
   - `.claude/agents/{codebase-analyzer,codebase-locator,codebase-pattern-finder,thoughts-analyzer,thoughts-locator,web-search-researcher}.md`
   - root `scripts/ticket.sh`
   - `.claude/references/design-system.md` — classify it: **pristine** if it
     still contains the template's placeholder strings (e.g. "Replace this
     with your project's actual design system tokens."), otherwise
     **customized**.
   - `CLAUDE.md` workflow-boilerplate sections — candidates only; the user
     approves each edit in Phase 4: the ticket-numbering paragraph in
     `## General`, `## Git Commit Discipline`, `## Implementation Phase
     Discipline`.

   (The template's ticket scripts and its `.claude/settings.json` hook
   entries are tmt's side of the migration — `/tmt:init` cleans those up.)

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

**Preferred research sources** (for /tce:research web lookups):
- [https://docs.example-framework.com] — [framework] official docs
- [https://lang-reference.example.org] — [language] reference
- [https://lib.example.com] — [notable dependency] docs
  → Add, remove, or correct any of these.

**Design system file?** [Yes if the project has a frontend you'll mock up with
/tce:design_explore — I'll seed .claude/tce/design-system.md from the template;
otherwise No.]
```

If Phase 1 detected a template install, extend the proposal with this
subsection (list only what actually exists):

```
**Template install detected** — this project was set up from the original
claude-template, which the plugins replace:
- Files to remove (after your confirmation in the write phase): [the detected
  .claude/commands/*.md, .claude/agents/*.md, scripts/ticket.sh]
- CLAUDE.md sections proposed for removal/replacement (you approve each edit
  individually): [the detected sections]
- Design system: [pristine skeleton — remove it; say Yes above to seed a fresh
  .claude/tce/design-system.md instead | customized — I'll move it to
  .claude/tce/design-system.md]
- The template's ticket scripts and settings.json hook entries are handled by
  /tmt:init.
```

Then ask about the **ticket system** with the AskUserQuestion tool, following
the AskUserQuestion dialog guidelines (above). tce requires one. Use this copy
verbatim — print the intro, then ask:

Intro (message above the dialog):

```
tce needs a ticket system — tickets are the entry point of the workflow:
research, planning, and implementation all start from a ticket.
```

Question: "Which ticket system does this project use?" — header: "Tickets",
options:

1. **tmt (Toby Markdown Tickets)** — Tickets as markdown files in this repo
   (thoughts/shared/tickets/), managed by the tmt plugin.
2. **GitHub Issues** — Issues on this repo's GitHub, accessed through the gh
   CLI.
3. **Jira** — You'll be asked how Claude reaches Jira: a CLI tool, an MCP
   server, or the REST API with a token.
4. **Linear** — You'll be asked how Claude reaches Linear: an MCP server or a
   CLI.

Move the system detected in Phase 1 to position 1, append " (Recommended)" to
its label, and prefix its description with the detection reasoning, e.g.
"Detected: thoughts/shared/tickets/ contains tmt tickets. " or "Detected:
template install with ticket scripts — /tmt:init migrates the prefix. " (A
custom system arrives via the automatic "Other" option — never offer one
yourself.)

Follow up — in the same AskUserQuestion call where sensible — on the two policy
choices recorded in `tickets.md`. Use this copy verbatim; print the intro
(replace [system] with the chosen system):

```
Two policy choices for how tce works with [system] — both are recorded in
.claude/tce/tickets.md and can be changed there anytime. Status transitions
happen at two moments: a ticket is marked in progress when implementation
starts, and done/closed when all phases are complete and verified.
```

Question: "Should tce update ticket statuses itself?" — header: "Status". For
tmt, offer (in this order):

1. **Update automatically (Recommended)** — tce marks the ticket in progress
   when work starts and done when implementation completes, committed together
   with the work. The natural fit for tickets that live in this repo.
2. **Remind only** — tce never touches ticket status; it tells you when a
   transition is due and you make it yourself.

For shared team systems (Jira/Linear/GitHub), reverse the order and the
recommendation:

1. **Remind only (Recommended)** — Safer for a shared team system: teammates
   see status changes only when you make them yourself. tce tells you when a
   transition is due.
2. **Update automatically** — tce transitions the ticket itself when work
   starts and when implementation completes.

Question: "May tce create tickets autonomously?" — header: "Creation", same
options for every system:

1. **Allowed (Recommended)** — /tce:quickfix can file a small ticket itself
   before fixing it; every ticket remains reviewable in your ticket system.
2. **Not allowed** — /tce:quickfix will refuse and ask you to create the
   ticket manually, then use /tce:work.

For anything genuinely ambiguous in the rest of the proposal (e.g. which of
several test commands is canonical), ask the user, following the
AskUserQuestion dialog guidelines (above).

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
   structure to populate.) Fill the `tce-config-version` HTML comment on the first
   line with the installed plugin version (the `version` field of
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`).

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

   Exception: if Phase 1 classified the template's
   `.claude/references/design-system.md` as **customized**, move that file
   here instead of copying the skeleton — the user's tokens carry over.

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

5. **Template cleanup** (only when Phase 1 detected template artifacts):

   a. **Superseded files** — list the detected files again, then ask,
      following the AskUserQuestion dialog guidelines (above). Use this copy
      verbatim — print the intro, then ask:

      Intro (message above the dialog):

      ```
      These files from the original claude-template are replaced by the tce
      plugin (git history preserves them):

      [the detected list: .claude/commands/*.md, .claude/agents/*.md,
      scripts/ticket.sh, and — if pristine — .claude/references/design-system.md]
      ```

      Question: "Remove the superseded template files listed above?" —
      header: "Cleanup", options:

      1. **Remove them (Recommended)** — The tce plugin's commands and agents
         replace them; git history preserves the files.
      2. **Keep them** — The un-namespaced commands keep appearing alongside
         the /tce:* versions until you remove them manually.

      On approval, delete exactly the listed files; remove
      `.claude/commands/`, `.claude/agents/`, `.claude/references/`, and
      `scripts/` only if they are empty afterwards. A **customized**
      design-system file is not deleted — it was moved in step 3 (delete the
      old location only as part of that move).

   b. **CLAUDE.md sections** — for each workflow-boilerplate section
      identified in Phase 1, show a concrete proposal (the text to delete or
      replace, and what supersedes it) and apply only the edits the user
      approves — free-form approval per edit, since the set varies by
      project. Never touch content you can't attribute to the template.

   Never touch anything under `thoughts/shared/` — existing tickets,
   research, plans, and mockups are the project's data and carry over as-is.

6. **Confirm and hand off:**

   ```
   tce is set up:
   - .claude/tce/profile.md
   - .claude/tce/tickets.md    (ticket system: [system])
   - [.claude/tce/design-system.md — remember to fill in real tokens]
   - thoughts/shared/* scaffolded
   - [template migration: removed N superseded files, edited CLAUDE.md
     sections (…), moved/replaced the design-system file — only what ran]

   Commit these, then start the workflow from a ticket:
   [tmt: /tmt:create | other systems: create a ticket there, then /tce:research <ID> or /tce:work <ID>]
   ```

   Do **not** commit automatically — leave that to the user (or suggest `/tce:commit`).

## Idempotency

If `.claude/tce/profile.md` or `.claude/tce/tickets.md` already exist, do not
clobber them. Read them, show what differs from your fresh analysis, and ask
whether to update specific values. Treat re-running `/tce:init` as "review and
amend the existing setup," not "start over."

Also compare the `tce-config-version` HTML comment at the top of `profile.md`
against the installed plugin version (`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`):

- **Same version** — report "tce config is already up to date (v[X.Y.Z])" and
  leave it alone (apart from any amendments agreed above).
- **Older or missing** — tell the user the config was written by an older tce
  (a `profile.md` without the comment predates version markers), walk through
  any config changes the newer version requires (adding the missing comment
  line is the only one today), and update the marker to the installed version.
  Ask before writing, as always.

**Legacy projects:** a `.claude/tce/config` file (with `TICKET_PREFIX=`) comes
from tce ≤1.x, where the ticket system was built into this plugin. tce no longer
reads it; the prefix now lives in `.claude/tmt/config` (the tmt plugin reads the
legacy file as a fallback until `/tmt:init` migrates it). Point the user at
`/tmt:init`, which migrates the prefix and offers to delete the legacy file.

**Template installs:** the Phase 1 template probe runs even when `.claude/tce/`
already exists, so leftovers of the original claude-template are caught on
re-runs too — a re-run reviews, amends, and finishes any incomplete migration
via the Phase 4 cleanup step.

## Notes

- Writing files under `.claude/` is an ordinary file write (it just needs the
  normal write approval). This command never edits `.claude/settings.json` —
  the template's hook entries there are `/tmt:init`'s job.
- Template migration never touches anything under `thoughts/shared/` — the
  document tree carries over unchanged.
- `.claude/tce/` is meant to be **committed** — it's shared project config, not
  personal settings.
