---
description: Set up tmt in this project — agree a ticket prefix and write .claude/tmt/config + scaffold thoughts/shared/tickets/.
---

# Initialize tmt

You are tasked with setting up **tmt** (Toby Markdown Tickets) in the current
project: agreeing a ticket prefix with the user and writing the project-local
config the ticket scripts and hooks rely on.

**Do not write any files until the user confirms.** Analyze first, propose, then
write.

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
2. **Template scripts** — if root `scripts/*.sh` files contain a
   `TICKET_PREFIX="…"` assignment, the project was set up from the original
   [claude-template](https://github.com/tobyS/claude-template), tmt's
   predecessor. Adopt that value; if the scripts disagree, prefer
   `next-ticket.sh`'s value and mention the discrepancy in the dialog
   description.
3. **Legacy tce config** — if `${CLAUDE_PROJECT_DIR}/.claude/tce/config` contains
   a non-empty `TICKET_PREFIX=` line, the project was set up by an old tce
   version (the ticket system lived inside the tce plugin before tmt was split
   out). Adopt that prefix; this run migrates it to `.claude/tmt/config`.
4. **Fresh proposal** — otherwise derive a prefix from the repo/directory name
   (short, uppercase, e.g. `MyApp` → `MYAPP`, an order system → `ORD`).

Also record which tmt-superseded artifacts of a prior install exist — they feed
the cleanup step in Phase 3:

- root `scripts/next-ticket.sh`, `scripts/open_tickets.sh`,
  `scripts/check-ticket-status.sh`, `scripts/validate-ticket-status.sh`
  (the template's ticket scripts)
- `.claude/commands/create_ticket.md` (superseded by `/tmt:create`)
- PostToolUse entries in `.claude/settings.json` whose commands invoke
  `scripts/check-ticket-status.sh` or `scripts/validate-ticket-status.sh`
- the legacy `.claude/tce/config` (case 3 above)

And check whether `.claude/tmt/config` already exists (see "Idempotency").

## Phase 2: Propose

Ask the user to confirm the prefix with the AskUserQuestion tool, following the
AskUserQuestion dialog guidelines (above). Do **not** write anything yet. Use
this copy verbatim — print the intro, then ask:

Intro (message above the dialog):

```
I've analyzed the repo for a ticket prefix. Confirming writes
`.claude/tmt/config` and scaffolds `thoughts/shared/tickets/`; tickets are
then numbered `[PREFIX]-0001`, `[PREFIX]-0002`, …
```

Question: "Which ticket prefix should this project use?" — header: "Prefix",
options:

1. **[PREFIX] (Recommended)** — [The provenance in one sentence, e.g. "Derived
   from the repo name; no existing tickets, template scripts, or legacy config
   found." / "Matches
   the existing tickets in thoughts/shared/tickets/." / "Harvested from the
   template's scripts/*.sh." / "Migrated from legacy .claude/tce/config."]
2. **[ALTERNATE]** — [Its derivation in one sentence.]

Offer all plausible candidates from Phase 1, detected/best first. The tool
needs at least two options: if the analysis produced only one candidate, add
the next-best mechanical derivation (e.g. a different derivation of the repo
name) as option 2. A custom prefix arrives via the automatic "Other" option —
never offer one yourself.

## Phase 3: Write (only after explicit confirmation)

1. **`.claude/tmt/config`** — copy the skeleton from the plugin's `templates/tmt/`
   directory (the source of truth for its structure), then set the agreed prefix:

   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/.claude/tmt"
   cp "${CLAUDE_PLUGIN_ROOT}/templates/tmt/config" "${CLAUDE_PROJECT_DIR}/.claude/tmt/config"
   ```

   Then fill the empty `TICKET_PREFIX=` value with the agreed prefix, and fill
   `TMT_CONFIG_VERSION=` with the installed plugin version (the `version` field
   of `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`).

2. **Scaffold the tickets directory** (skip if it already exists), with a
   `.gitkeep` so the empty dir is committable:

   ```bash
   mkdir -p "${CLAUDE_PROJECT_DIR}/thoughts/shared/tickets"
   touch "${CLAUDE_PROJECT_DIR}/thoughts/shared/tickets/.gitkeep"
   ```

3. **Superseded-install cleanup** (only when Phase 1 recorded prior-install
   artifacts). Three cases; batch the ones that apply into a single
   AskUserQuestion call, following the AskUserQuestion dialog guidelines.
   First print the intro listing exactly what was detected (only the parts
   that apply), then ask. Use this copy verbatim:

   Intro (message above the dialog):

   ```
   This project contains files from a superseded install that tmt now
   replaces:

   - [the template scripts that exist, e.g. scripts/next-ticket.sh,
     scripts/open_tickets.sh, scripts/check-ticket-status.sh,
     scripts/validate-ticket-status.sh, and .claude/commands/create_ticket.md]
   - [the two PostToolUse hook entries in .claude/settings.json invoking
     scripts/check-ticket-status.sh and scripts/validate-ticket-status.sh]
   - [.claude/tce/config — its TICKET_PREFIX was just migrated to
     .claude/tmt/config]

   Removing them is safe: git history preserves every file.
   ```

   a. **Template files** — question: "Remove the superseded template files
      listed above?" — header: "Cleanup", options:

      1. **Remove them (Recommended)** — tmt's shipped scripts and hooks
         replace them; git history preserves the files.
      2. **Keep them** — They stay and the old hooks may fire alongside tmt's
         until you remove them manually.

      On approval, delete exactly the listed files; remove the `scripts/`
      directory only if it is empty afterwards.

   b. **settings.json hook entries** — only if `.claude/settings.json` has
      PostToolUse entries invoking the template's two hook scripts. Show the
      exact entries in the intro. Question: "Remove these two hook entries
      from .claude/settings.json?" — header: "Settings", options:

      1. **Remove the two entries (Recommended)** — They duplicate tmt's
         shipped hooks and will start failing once scripts/ is removed.
      2. **Leave settings.json untouched** — You get exact instructions to
         remove them manually instead.

      On approval, edit surgically: remove only those two entries (and any
      then-empty array/key they leave behind); every other key stays
      byte-identical. If declined, print the manual removal instructions.
      This is the one sanctioned exception to the settings.json rule in
      Notes.

   c. **Legacy `.claude/tce/config`** — only if the prefix came from that
      file (Phase 1 case 3). Question: "Delete the legacy .claude/tce/config?"
      — header: "Legacy", options:

      1. **Delete it (Recommended)** — Its TICKET_PREFIX now lives in
         .claude/tmt/config; current tce no longer reads the legacy file.
      2. **Keep it** — Stale but harmless; tmt reads it only as a fallback
         when .claude/tmt/config is missing.

      Deleting this one file is allowed even though it lives under
      `.claude/tce/` — its only payload is the prefix this run migrated. Do
      not touch any other tce file.

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

Also compare the config's `TMT_CONFIG_VERSION` against the installed plugin
version (`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`):

- **Same version** — report "tmt config is already up to date (v[X.Y.Z])" and
  leave the file alone (apart from any prefix change agreed above).
- **Older or missing** — tell the user the config was written by an older tmt
  (or predates version markers), walk through any config changes the newer
  version requires (adding the missing `TMT_CONFIG_VERSION` line is the only
  one today), and update the marker to the installed version. Ask before
  writing, as always.

## Notes

- Writing files under `.claude/` is an ordinary file write (it just needs the
  normal write approval). This command never edits `.claude/settings.json` —
  with one exception: the superseded-install cleanup step may remove the
  template's two PostToolUse hook entries, after explicit approval.
- `.claude/tmt/` is meant to be **committed** — it's shared project config, not
  personal settings.
