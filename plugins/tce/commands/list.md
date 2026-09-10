---
description: List tickets as a table with their tce workflow stage — research document, plan document, and implementation progress.
argument-hint: "[optional filter, e.g. only auth tickets | include closed | group by priority]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh":*)
---

# List Tickets with tce Workflow Stage

Print one table row per ticket, combining the ticket system's own status with
how far the ticket has got through the tce workflow: does it have a research
document, does it have a plan, and how much of that plan is implemented.

**This command is read-only.** It never creates, writes or transitions a ticket,
and it never edits `.claude/tce/` config.

## Project context

This command ships in the **tce** workflow plugin and is ticket-system-agnostic.

- Read `${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the ticket system: the
  canonical ID form, the **"Listing tickets"** section (how to enumerate tickets
  and where complexity and priority live), the terminal statuses named in
  **"Status / completion"**, and the **"Parent / epic tickets"** rule. The
  command runs those mechanisms verbatim. If the file is missing, tell the user
  to run `/tce:init` and stop.
- If `tickets.md` exists but has no `## Listing tickets` section, say so in one
  sentence and tell the user `/tce:init` adds it (it was introduced in tce
  1.2.0). Do not guess an enumeration mechanism.
- `[PREFIX]-XXXX` stands for a canonical ticket ID as defined in `tickets.md`
  (e.g. `MYAPP-0042`, `GH-123`) — you never hardcode a prefix.

---

## Step 1: Interpret the argument

`$ARGUMENTS` is free-form. There is no fixed vocabulary — read it the way a
colleague would.

- **No argument** — list every ticket **not** in a terminal status, newest first.
- **With an argument** — adjust the listing as asked. At minimum support a topic
  filter ("only tle tickets"), including terminal statuses ("include closed",
  "everything"), grouping ("group by status"), and sorting ("oldest first").
  These can combine.

**Always state the interpretation in one line before the table**, so the user can
see what they got:

```
Interpreted as: only tickets mentioning tle, including closed ones, grouped by status.
```

With no argument, that line is simply `Showing all tickets not in a terminal
status, newest first.` If the argument is genuinely ambiguous, pick the most
likely reading and say so in that same line ("read as a topic filter on 'branch';
say the word if you meant something else."). Do not open a dialog for this.

## Step 2: Enumerate the tickets

Run the mechanism from the `## Listing tickets` section of `tickets.md`,
collecting for each ticket:

- canonical ID
- title
- the backend's own status
- complexity, if the adapter says where it lives
- priority, **only** if the adapter declares a location for it

If the adapter records priority as "none", there is no priority data — the
Priority column is omitted entirely (see Step 5). Never invent one.

Apply the terminal-status filter here: hide tickets whose status is in the
terminal set, unless Step 1 decided otherwise.

## Step 3: Group epics and sub-tickets

Use the `## Parent / epic tickets` rule from `tickets.md` to decide which tickets
are sub-tickets of which parent.

- A sub-ticket is rendered **directly beneath its parent**, in ID order.
- A parent stays grouped with its sub-tickets **even when the parent itself is in
  a terminal status** — show the parent row for context regardless of the filter,
  so children never appear orphaned.
- If the adapter says "none" for parent/epic tickets, skip this step: every
  ticket is a top-level row.

## Step 4: Derive the tce stage

Run the shipped script **once** for the whole listing, passing every listed
ticket ID:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh" [PREFIX]-XXXX [PREFIX]-XXXX ...
```

Never call it once per ticket. It prints one five-line record per ID, in the
order given, separated by blank lines:

```
ticket:   [PREFIX]-XXXX
research: <path, empty when none>
plan:     <path, empty when none>
progress: <n>/<m> | ?/<m> | <empty>
source:   log | sidecar | unknown | no-plan
```

`source:` is what tells you how much to trust `progress:`:

- `log` — **exact**, counted from the plan's own implementation log.
- `sidecar` — **approximate**, recovered from a legacy status file whose format
  was never standardized. It must be shown as approximate.
- `unknown` — a plan exists but records no progress at all.
- `no-plan` — there is no plan document.

If the script exits non-zero (for example there is no `thoughts/` directory),
report its error in one line and still print the table, with every stage cell as
`?` rather than failing outright.

## Step 5: Render the table

Columns, in this order — `Priority` present **only** when the adapter declares
where priority lives:

`Ticket` | `Title` | `Priority` | `Status` | `Research` | `Plan` |
`Implementation` | `Complexity`

### Cell rules

- **Ticket** — the canonical ID. A sub-ticket is prefixed with `└─ ` (see
  nesting, below).
- **Title** — the ticket title, **truncated to at most 45 characters**, cut at a
  word boundary where possible and marked with a trailing `…`. Long titles
  otherwise widen the table until the renderer collapses it (see "Why the table
  must stay narrow").
- **Research** / **Plan** — `✓` when the script reported a path, `–` otherwise.
- **Implementation** — from `source:` and `progress:`:
  - `no-plan` → `–`
  - `log`, every phase done → `✓`
  - `log`, partially done → `n/m phases`
  - `sidecar` → `~n/m phases` (the `~` marks it approximate)
  - `unknown` → `?/m phases`
- **Implementation for an epic** — `n/m sub-tickets`, where `n` counts the
  sub-tickets whose own Implementation cell is `✓`. The epic's **Research** and
  **Plan** cells reflect only documents the epic itself has. An epic's own plan
  phases are deliberately not shown — the roll-up is the more useful number.
- **Complexity** / **Priority** — as the backend reports them; `–` when a
  particular ticket has no value.

### Output format

These rules exist because the obvious alternatives visibly break:

- Emit a **real markdown table**, never inside a code fence. Claude Code's
  renderer lays the table out itself, so **do not hand-pad cells** — padding you
  add is discarded, and getting it wrong is what misaligns the output.
- **Full-word headings** (`Research`, `Implementation`, `Complexity`), not
  abbreviations.
- **Only single-width, text-presentation characters in cells**: `✓` (U+2713),
  `–` (U+2013), `└─` (U+2514 U+2500), `~`, `?`, `…`, digits and letters. Never
  `✅`, `❌` or any other emoji-presentation glyph — those occupy two terminal
  columns while width calculations count them as one, which is exactly the
  misalignment this format avoids.
- **Nesting uses the leading `└─ ` marker, never leading whitespace** — markdown
  renderers trim leading spaces inside table cells, so indentation silently
  disappears.

### Why the table must stay narrow

When a table exceeds the terminal width, Claude Code's renderer collapses it into
stacked key/value cards — one card per row — which destroys the skimmability that
is the whole point of this command. Keep the table as narrow as the content
allows: truncate titles as specified, and keep every other cell to a word or two.
The same flattening happens in screen-reader mode and in non-interactive
(`-p`) output, so put the ticket ID first and keep headings short enough that a
`Heading: value` reading still makes sense.

### Legend and count

Below the table, print the legend (only the markers actually used):

```
✓ done · – none · n/m phases from the plan's implementation log · ~ approximate
(from a legacy status file) · ? unknown · └─ sub-ticket
```

Then a count line, e.g.:

```
Showing 12 of 33 tickets (21 in a terminal status hidden).
```

When nothing matches, print the interpretation line and say plainly that no
tickets matched — do not print an empty table.

---

## Example shape

Illustrative only — the columns, glyphs and nesting are the contract; the IDs and
titles are not.

| Ticket | Title | Priority | Status | Research | Plan | Implementation | Complexity |
|---|---|---|---|---|---|---|---|
| MYAPP-0100 | Billing overhaul | High | In Progress | – | – | 2/4 sub-tickets | Extra Large |
| └─ MYAPP-0100a | Extract invoice model | High | Done | ✓ | ✓ | ✓ | Medium |
| └─ MYAPP-0100b | Proration engine | Medium | In Progress | ✓ | ✓ | 2/6 phases | Large |
| └─ MYAPP-0100c | Dunning emails | Low | Open | ✓ | – | – | Small |
| MYAPP-0104 | Fix CSV export encoding | High | Open | ✓ | – | – | Small |

For a backend without priorities the `Priority` column is absent entirely — no
empty column, no placeholder values.
