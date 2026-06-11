---
description: Set up tmt in this project — agree a ticket prefix and write .claude/tmt/config + scaffold thoughts/shared/tickets/.
---

# Initialize tmt

You are tasked with setting up **tmt** (Toby Markdown Tickets) in the current
project: agreeing a ticket prefix with the user and writing the project-local
config the ticket scripts and hooks rely on.

**Do not write any files until the user confirms.** Analyze first, propose, then
write.

## What gets created

```
.claude/tmt/
└── config                    # machine-readable: TICKET_PREFIX=<PREFIX>  (read by the ticket scripts & hooks)
thoughts/shared/tickets/      # the tickets live here, with .gitkeep
```

Both are Git-tracked, shared project config — the prefix and ticket numbering
must be identical for everyone working on the repo.

## Phase 0: Preflight — check dependencies

```bash
command -v git >/dev/null && echo "git: ok" || echo "git: MISSING (required)"
command -v jq  >/dev/null && echo "jq: ok"  || echo "jq: MISSING (required for the ticket-status hooks)"
```

If **`jq` is missing**, warn the user: the ticket-status hooks parse hook JSON
with `jq` and won't fire without it (ticket work isn't blocked, but they lose the
status-update reminders and status validation). Suggest installing it
(`brew install jq`, `apt install jq`, …). Continue with setup regardless.

## Phase 1: Analyze

Determine the right ticket prefix, in this order:

1. **Existing tickets** — if `thoughts/shared/tickets/` already has files named
   `<PREFIX>-NNNN-*.md`, extract the prefix from their names. This project is
   already using the convention; adopt it.
2. **Legacy tce config** — if `${CLAUDE_PROJECT_DIR}/.claude/tce/config` contains
   a non-empty `TICKET_PREFIX=` line, the project was set up by an old tce
   version (the ticket system lived inside the tce plugin before tmt was split
   out). Adopt that prefix; this run migrates it to `.claude/tmt/config`.
3. **Fresh proposal** — otherwise derive a prefix from the repo/directory name
   (short, uppercase, e.g. `MyApp` → `MYAPP`, an order system → `ORD`).

Also check whether `.claude/tmt/config` already exists (see "Idempotency").

## Phase 2: Propose

Present the proposal and how you arrived at it. Do **not** write anything yet.

```
Setting up tmt (Toby Markdown Tickets):

**Proposed ticket prefix:** [PREFIX]   (tickets will be named [PREFIX]-0001, …)
  [source: existing tickets / migrated from legacy .claude/tce/config / derived from repo name]

This writes .claude/tmt/config and scaffolds thoughts/shared/tickets/.
Anything to correct?
```

If the prefix is genuinely ambiguous (e.g. several plausible candidates), use the
AskUserQuestion tool with concrete options.

## Phase 3: Write (only after explicit confirmation)

1. **`.claude/tmt/config`** — copy the skeleton from the plugin's `templates/tmt/`
   directory (the source of truth for its structure), then set the agreed prefix:

   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/.claude/tmt"
   cp "${CLAUDE_PLUGIN_ROOT}/templates/tmt/config" "${CLAUDE_PROJECT_DIR}/.claude/tmt/config"
   ```

   Then fill the empty `TICKET_PREFIX=` value with the agreed prefix.

2. **Scaffold the tickets directory** (skip if it already exists), with a
   `.gitkeep` so the empty dir is committable:

   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/thoughts/shared/tickets"
   touch "${CLAUDE_PROJECT_DIR}/thoughts/shared/tickets/.gitkeep"
   ```

3. **Legacy cleanup** (only in the migration case): if the prefix came from
   `.claude/tce/config`, tell the user that file's `TICKET_PREFIX` is now
   superseded by `.claude/tmt/config` and can be removed when they next touch
   tce's config. Do not edit tce's files yourself.

4. **Confirm and hand off:**

   ```
   tmt is set up:
   - .claude/tmt/config            (prefix: [PREFIX])
   - thoughts/shared/tickets/      scaffolded

   Commit these — they're shared project config. Create your first ticket with: /tmt:create
   ```

   If the project also uses the tce workflow (`.claude/tce/` exists or the tce
   plugin is installed), suggest running `/tce:init` (or re-running it) so tce's
   ticket-system config (`.claude/tce/tickets.md`) points at tmt.

   Do **not** commit automatically — leave that to the user.

## Idempotency

If `.claude/tmt/config` already exists with a non-empty prefix, do not clobber
it. Show the current value, note anything that differs from your analysis, and
ask whether to change it — changing the prefix of a project with existing tickets
breaks numbering and lookups, so warn clearly if tickets exist.

## Notes

- Writing files under `.claude/` is an ordinary file write (it just needs the
  normal write approval). This command never edits `.claude/settings.json`.
- `.claude/tmt/` is meant to be **committed** — it's shared project config, not
  personal settings.
