# `/tce:list` — ticket listing with tce workflow stage Implementation Plan

## Overview

Add a read-only `/tce:list` command to the tce plugin that prints one markdown
table row per ticket, carrying the backend's own status alongside the **tce
stage**: whether a research document exists, whether a plan document exists, and
how far the plan's implementation has got. Sub-tickets nest under their parent
epic, whose Implementation cell rolls up its children. A Priority column appears
only when the project's adapter declares where priority lives.

The work splits along the seam research identified: **enumeration is
backend-specific** and comes from a new `## Listing tickets` section in
`.claude/tce/tickets.md`; **stage derivation is backend-independent** and lands
in a new shipped script, `plugins/tce/scripts/stage.sh`, following the
`baseline.sh` / `branch.sh` contract.

## Current State Analysis

- **No tce-side listing exists.** `/tmt:list` (`plugins/tmt/commands/list.md`,
  22 lines) delegates to `plugins/tmt/scripts/open_tickets.sh`, which is
  tmt-specific by design, filters status against two hardcoded literals
  (`open_tickets.sh:47-49`), detects documents by presence only
  (`open_tickets.sh:68-69` — it never opens the plan), and prints `✅`/`❌`
  (`open_tickets.sh:73-81`). TP-0033 leaves it untouched.
- **The adapter has no enumeration section.** `plugins/tce/templates/tce/tickets.md`
  has eight sections; `## Status / completion` (`:51-62`) describes lifecycle
  *moments*, not a terminal-status set a lister could read.
- **A tce script cannot read tce config.** `plugins/tce/scripts/lib.sh:11-13`
  exposes only `tce_project_root()`; `CLAUDE.md` forbids a machine-readable tce
  config. Policy therefore reaches a script only as arguments — the `branch.sh`
  division of labour (`branch.sh:4-5`).
- **`ticket.sh` is single-ID and substring-matching** (`ticket.sh:25`, `:33`),
  with 8 callers depending on its bare-path output. It over-matches `TP-0100a`
  for `TP-0100`, which would make an epic inherit its children's documents.
- **Plan progress is only exactly derivable for post-TP-0023 plans** — 7 of this
  repo's 28. 20 have a legacy `.status.md` sidecar; TP-0006 has neither.

### Key Discoveries:

- Fenced code blocks must be stripped before matching headings:
  `thoughts/shared/plans/2026-09-02-TP-0030-drift-check-rewritten-history.md:345-346`
  is a column-0 `## Implementation Closeout` inside a ```` ```markdown ```` fence;
  the real one is at `:646`.
- Phase headings vary: `##` and `###` levels, `:` and `—` separators, and a
  trailing ` ✅ DONE` decoration (TP-0008). `^## Phase (\d+)` alone reports zero
  phases for TP-0005 and TP-0014.
- **Checkboxes are not a progress signal.** 9 fully-implemented plans have zero
  ticked boxes; TP-0031 is 5/5 phases complete with 8 of 31 boxes unticked
  because Manual items await human confirmation (`implement.md:148`).
- `- **Status**:` is always the log block's third line and always present, but
  its value can wrap across lines
  (`…-TP-0024-….md:154-156`), so match on the `- **Status**:` line itself.
- The adapter's register: bracketed guidance = backend-specific and replaced at
  fill time; unbracketed prose + an HTML `Backend-independent` comment ships
  as-is (`templates/tce/tickets.md:66-67`). Inapplicable backends get a
  **sentinel value** (`"none"` at `:29-30`, `"not allowed"` at `:36`).
- Frontmatter order in the newest commands is `description` → `argument-hint` →
  (`model`) → `disable-model-invocation` → `allowed-tools` (`review.md:1-6`).

## Desired End State

`/tce:list` prints a real markdown table (never inside a code fence) with
full-word headings and single-width glyphs only, plus a legend and a count line.
With no argument it lists every ticket not in a terminal status; with a free-form
prompt argument it filters/sorts/groups as asked and states in one line how it
interpreted the prompt. `plugins/tce/scripts/stage.sh` derives the stage for any
set of ticket IDs, exactly for modern plans and explicitly-marked-approximate for
legacy ones. `/tce:init` fills the new adapter section, `/tce:refresh` reconciles
it, `CLAUDE.md` records the classification and the cross-file span, and tce is
released as 1.2.0.

Verify by running `/tce:list` in this repo and seeing all 33 tickets resolve with
correct stages, and by `claude plugin validate` passing for the marketplace and
all three plugins.

## What We're NOT Doing

- **Not changing, thinning or retiring `/tmt:list`.** tmt must keep listing
  tickets without tce installed.
- **Not adding a priority field to tmt.** The Priority column simply never
  appears for tmt projects.
- **Not writing to or mutating any ticket** — `/tce:list` is strictly read-only.
- **Not changing `ticket.sh`** or its 8 callers. `stage.sh` is a new script
  (decision: "Hybrid: new script"), so the existing bare-path contract and its
  substring matching stay exactly as they are.
- **Not changing what `/tce:research`, `/tce:plan` or `/tce:implement` write.**
  The lister reads their existing artifacts as they are.
- No output formats other than the table; no caching or indexing; no epic
  Implementation cell showing the parent's own phases (decision: "Roll-up only").

## Implementation Approach

Bottom-up, so each phase is verifiable against this repo's real 33-ticket,
28-plan corpus before anything depends on it: the script first (it has the only
genuinely tricky logic and the richest test data), then the adapter template it
pairs with, then the two commands that own the adapter's lifecycle, then the
command itself, then docs/classification/release.

`stage.sh` follows the established shipped-script contract exactly — positional
arguments, keyed stdout lines with a closed enum declared in the header comment,
every reported outcome exiting 0, and semantics in the script with policy in the
command.

---

## Phase 1: `stage.sh` — backend-independent stage derivation

### Overview

A new shipped script that maps canonical ticket IDs onto their `thoughts/`
documents and derives implementation progress from the plan. It knows nothing
about ticket systems; IDs arrive as arguments.

### Changes Required:

#### 1. The script

**File**: `plugins/tce/scripts/stage.sh` (new, mode 755)
**Changes**: Header contract, argument handling, per-ID record emission.

Header comment declaring the contract verbatim:

```bash
#!/bin/bash

# Derive each ticket's tce workflow stage: its research document, its plan
# document, and how far the plan's implementation has got.
# Usage: stage.sh <ticket-id> [<ticket-id> ...]
#
# The ticket IDs are whatever canonical form the project's ticket system uses
# (see .claude/tce/tickets.md) -- this script never reads that file and knows
# nothing about ticket systems. Enumerating which tickets exist is the calling
# command's job; this script only maps IDs onto thoughts/ documents.
#
# Prints one record per ID, in the order given, separated by a blank line:
#   ticket:   <id>
#   research: <path relative to the project root, empty when none>
#   plan:     <path relative to the project root, empty when none>
#   progress: <n>/<m> | ?/<m> | <empty>
#   source:   log | sidecar | unknown | no-plan
#
# progress/source semantics:
#   log      -- exact: counted from the plan's own `### Implementation log`
#               blocks.
#   sidecar  -- approximate: the plan carries no log blocks but a legacy
#               `<plan>.status.md` sidecar exists. That format was never
#               standardized, so the caller must mark the number approximate.
#   unknown  -- a plan exists but carries no progress signal at all; progress
#               is reported as ?/<m>.
#   no-plan  -- no plan document; progress is empty.
#
# Phase counting deliberately ignores success-criteria checkboxes: completed
# plans routinely leave Manual Verification items unticked (they are ticked
# only on human confirmation), so a checkbox ratio is not a progress signal.
#
# Every reported outcome exits 0; only usage errors and a missing thoughts/
# directory exit 1.
```

Standard bootstrap and guards, mirroring `baseline.sh:24-44`:

```bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

if [ -z "$1" ]; then
    echo "Usage: $0 <ticket-id> [<ticket-id> ...]"
    echo "Example: $0 MYAPP-0042 MYAPP-0043"
    exit 1
fi

ROOT="$(tce_project_root)"
THOUGHTS_DIR="$ROOT/thoughts"

if [ ! -d "$THOUGHTS_DIR" ]; then
    echo "Error: thoughts directory not found at $THOUGHTS_DIR" >&2
    exit 1
fi
```

**Document matching** — deliberately stricter than `ticket.sh`'s substring
match, so `TP-0100` does not claim `TP-0100a`'s documents. A file belongs to an
ID when its basename contains `-<id>-` or ends with `-<id>.md`. The plan lookup
additionally excludes `*.status.md` (a sidecar's basename also contains
`-<id>-`). Search `thoughts/shared/research/` and `thoughts/shared/plans/`, take
the first match in sorted order, and emit the path relative to `$ROOT`.

**Progress derivation** — an `awk` program over the plan, with fence stripping
first. Use explicit `##`/`###` alternations rather than an interval expression
(`{2,3}`), because the `awk` shipped on macOS does not reliably support interval
expressions:

```awk
# Fence stripping: a fence opens with 3+ backticks or tildes and closes with
# at least as many of the same character. Everything between is ignored.
{
    if (match($0, /^[ \t]*(```+|~~~+)/)) {
        marker = substr($0, RSTART, RLENGTH)
        gsub(/[ \t]/, "", marker)
        ch = substr(marker, 1, 1); len = length(marker)
        if (!in_fence)                                 { in_fence = 1; fence_ch = ch; fence_len = len; next }
        else if (ch == fence_ch && len >= fence_len)   { in_fence = 0; next }
    }
    if (in_fence) next
}

# Phase headings: ## or ###, ":" or em-dash or nothing, tolerating a trailing
# decoration such as " ✅ DONE". Reject "Phase 1b" style sub-phases.
/^##[ \t]+Phase[ \t]+[0-9]/ || /^###[ \t]+Phase[ \t]+[0-9]/ {
    rest = $0
    sub(/^#+[ \t]+Phase[ \t]+[0-9]+/, "", rest)
    if (rest !~ /^[a-zA-Z]/) { phases++; in_log = 0; next }
}

/^###[ \t]+Implementation log/ { in_log = 1; has_log = 1; next }

in_log && /^[ \t]*-[ \t]*\*\*Status\*\*:/ {
    if (index($0, "✅") > 0 || index($0, "Complete") > 0) done++
    in_log = 0
    next
}

/^#/ { in_log = 0 }

END { printf "%d %d %d\n", done, phases, has_log }
```

**Sidecar fallback** — used only when the plan has no log blocks. Phase *total*
always comes from the plan (heading levels drift between a plan and its own
sidecar, e.g. `…-TP-0020-….md:93` vs `…-TP-0020-….status.md:20`); only the done
count comes from the sidecar, clamped to the plan's total. A phase counts as done
if its section carries a `- **Status**:` line with `✅`/`Complete`, **or** its
heading ends in `DONE` (the `…-TP-0012-….status.md:5` form):

```awk
function flush() { if (cur && cur_done) done++ }
/^#+[ \t]+Phase[ \t]+[0-9]/ { flush(); cur = 1; cur_done = ($0 ~ /DONE[ \t]*$/) ? 1 : 0; next }
cur && /^[ \t]*-[ \t]*\*\*Status\*\*:/ {
    if (index($0, "✅") > 0 || index($0, "Complete") > 0) cur_done = 1
}
END { flush(); print done + 0 }
```

**Record emission** — a `report_record` helper printing the five aligned lines,
with a blank line between records but not after the last:

- no plan → `progress:` empty, `source: no-plan`
- log blocks present → `progress: <done>/<phases>`, `source: log`
- no log, sidecar present → `progress: <min(sidecar_done,phases)>/<phases>`,
  `source: sidecar`
- neither, or `phases` is 0 → `progress: ?/<phases>` (empty when `phases` is 0),
  `source: unknown`

### Success Criteria:

#### Automated Verification:

- [x] `bash -n plugins/tce/scripts/stage.sh` passes
- [x] `plugins/tce/scripts/stage.sh` is executable (mode 755)
- [x] `CLAUDE_PROJECT_DIR=. plugins/tce/scripts/stage.sh TP-0031` reports
      `progress: 5/5` and `source: log`
- [x] `… stage.sh TP-0024` reports `progress: 0/3` and `source: log` (its only
      log block is `⚠️ Partial`, which is not done — the criterion originally
      read `1/3`, which was a mis-derivation in this plan, not a script defect)
- [x] `… stage.sh TP-0030` reports `progress: 3/3` and `source: log` — proving
      the in-fence `## Implementation Closeout` at `:346` did not corrupt the count
- [x] `… stage.sh TP-0021` reports `progress: 2/2` — proving the two in-fence
      `### Phase 1b:` headings were not counted
- [x] `… stage.sh TP-0005` and `TP-0014` report a non-zero phase total —
      proving `###`-level phase headings are counted
- [x] `… stage.sh TP-0022` reports `source: sidecar` with a non-zero done count
- [x] `… stage.sh TP-0012` reports `source: sidecar` — proving the
      heading-suffix `— DONE` form is recognized
- [x] `… stage.sh TP-0006` reports `source: unknown` and a `?/` progress
- [x] `… stage.sh TP-0033` reports `source: no-plan` before this plan existed;
      it now reports `source: unknown` (`?/5`) because the plan exists but has
      no log block yet — the same not-started signal
- [x] `… stage.sh TP-0032` reports empty `research:` and empty `plan:`
- [x] A multi-ID call emits blank-line-separated records in the order given
- [x] `… stage.sh` with no arguments prints the usage block and exits 1
- [x] `CLAUDE_PROJECT_DIR=/tmp/no-such-project … stage.sh TP-0001` errors on
      stderr and exits 1
- [x] A synthetic epic check: given fixture documents for `X-0100` and
      `X-0100a`, `stage.sh X-0100` does **not** report `X-0100a`'s documents
- [x] All 20 legacy-sidecar tickets resolve to a full `n/n` — consistent with
      the recorded fact that every sidecar belongs to a Done ticket

#### Manual Verification:

- [x] None for this phase — all criteria are shell-verifiable against the repo's
      own corpus

### Implementation log

- **Status**: ✅ Complete
- **Base commit**: `a3467ceb01491788490a7bf9f40a3131a276553d`
- **Commit**: `<phase-1>` feat(TP-0033): add stage.sh to derive a ticket's tce workflow stage
- **Did**: added `plugins/tce/scripts/stage.sh` (755) with the five-line record
  contract, strict `-<id>-`/`-<id>.md` document matching, fence-stripping phase
  counting, in-plan log derivation and a legacy sidecar fallback.
- **Issues**: the sidecar format turned out to have **five** done-marker shapes,
  not the two the plan anticipated — checked-box phase lists (`- [x] Phase 1: …`,
  8 files, sometimes with no phase headings at all), plain `- Status: complete`
  without `**` markers (2 files), a bare `✅ Complete — …` line (TP-0020), a
  checked box inside a phase section (TP-0008), and the heading-suffix `— DONE`
  form (TP-0012). Rewrote `sidecar_progress` to cover all five across both a
  section layout and a list layout. Also noted that `## Phases` (plural) must not
  count as a phase heading — a digit must follow.
- **Verification**: ✅ `bash -n`, ✅ all 20 legacy tickets, ✅ all 7 modern
  tickets, ✅ fence/heading-level/epic/usage/missing-dir edge cases

---

## Phase 2: The `tickets.md` adapter gains listing inputs

### Overview

Add the `## Listing tickets` section to the adapter template and extend
`## Status / completion` with the terminal-status set the lister needs, both in
the template's established bracketed-guidance register.

### Changes Required:

#### 1. The new section

**File**: `plugins/tce/templates/tce/tickets.md`
**Changes**: Insert `## Listing tickets` after `## Status / completion` and
before `## What tce needs from a ticket` (i.e. as the last *backend* section,
keeping the backend-independent section last).

```markdown
## Listing tickets

[How `/tce:list` enumerates the project's tickets, and what metadata it can show
per ticket. Give a concrete mechanism that yields, for every ticket, at least its
canonical ID, title and status — e.g. for a file backend, the glob over the
ticket directory plus which lines carry the title and status; for an issue
tracker, a CLI or MCP call (`gh issue list --state all --limit 200 --json
number,title,state,labels`). The command runs this verbatim, so be concrete.
Also state:

- **Complexity** — where a ticket's size/estimate lives, or "none".
- **Priority** — where a ticket's priority lives and which values it takes, or
  "none". With "none" the listing's Priority column never appears at all — no
  empty column and no invented values.

`/tce:list` is read-only: it never creates, writes or transitions a ticket.]
```

#### 2. The terminal-status declaration

**File**: `plugins/tce/templates/tce/tickets.md`
**Changes**: Extend the `## Status / completion` bracketed block (currently
`:53-62`) with a terminal-status sentence, placed after the concrete-action
guidance and before the closing bracket:

```markdown
Also name the **terminal statuses** — those meaning the ticket needs no further
work (e.g. Done and Rejected; closed states in an issue tracker). `/tce:list`
hides tickets in a terminal status unless asked to include them.]
```

### Success Criteria:

#### Automated Verification:

- [x] `plugins/tce/templates/tce/tickets.md` contains a `## Listing tickets`
      heading positioned after `## Status / completion` and before
      `## What tce needs from a ticket` (headings now at `:51`, `:68`, `:85`)
- [x] The `## What tce needs from a ticket` section and its
      `Backend-independent` HTML comment are byte-identical to before (the diff's
      single deletion is the `## Status / completion` line that gained the
      terminal-status sentence)
- [x] The new section's body is entirely inside one `[...]` bracketed block, per
      the backend-section convention
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] The new section's register (imperative, backticked literals, a file-backend
      *and* an issue-tracker example, a sentinel value for inapplicable backends)
      reads consistently with the seven existing backend sections

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-2>` feat(TP-0033): add the Listing tickets adapter section
- **Did**: added `## Listing tickets` between `## Status / completion` and
  `## What tce needs from a ticket`, and extended the status section with the
  terminal-status declaration the lister needs.
- **Issues**: none.
- **Verification**: ✅ section order, ✅ backend-independent section untouched,
  ✅ `claude plugin validate ./plugins/tce`

---

## Phase 3: `/tce:init` and `/tce:refresh` learn the new section

### Overview

Per the refresh-tracks-init rule in `CLAUDE.md`, both commands must learn the
section in the same commit: init fills it and offers it as an upgrade to existing
projects; refresh reconciles it.

### Changes Required:

#### 1. Init fills it

**File**: `plugins/tce/commands/init.md`
**Changes**:

- Phase 4 step 2 (`:402-406`): add `Listing tickets` to the enumeration of
  backend sections to fill.
- The three per-system guidance bullets (`:407-416` tmt, `:417-424` GitHub,
  `:425-429` Jira/Linear/custom): add a `*listing*` clause to each, in the
  established italic-section-name style. For tmt: glob
  `thoughts/shared/tickets/<PREFIX>-*.md`, title from the `# <ID>: <title>`
  heading, status from the `**Status:**` line, complexity from
  `**Estimated Complexity:**`, priority "none". For GitHub: a
  `gh issue list --state all --json …` call, priority from labels if the project
  uses them, else "none".
- `## Status / completion` fill guidance in the same bullets: name the terminal
  statuses (for tmt, Done and Rejected).
- Idempotency upgrade list (`:531-537`): add the **first `tickets.md` bullet**,
  in the established style —

  ```markdown
  - A `tickets.md` without a `## Listing tickets` section (added in tce 1.2.0)
    needs it inserted directly after `## Status / completion`, and that section
    extended with the project's terminal statuses. Fill both from the recorded
    backend rather than re-asking: the enumeration mechanism follows from the
    system already named in `## System`, and the terminal statuses from the
    status policy already recorded. Ask before writing, as always.
  ```

#### 2. Refresh reconciles it

**File**: `plugins/tce/commands/refresh.md`
**Changes**:

- Scope paragraph (`:27-35`): add `Listing` to the factual adapter list.
- Phase 1 item 4 (`:75-80`): add checking that the recorded enumeration
  mechanism still resolves, alongside access/create/status.
- Phase 2 factual list (`:98-104`): add `Listing tickets`. It is **factual**
  (a mechanism re-analysis can verify), not hand-authored — the priority
  *location* is a fact about the backend, not a policy choice.
- High-confidence drift triggers (`:116-118`): include a recorded enumeration
  mechanism that no longer resolves.

#### 3. Drift-detection prose in research and its composites

**Files**: `plugins/tce/commands/research.md` (`:272-282`),
`plugins/tce/commands/work.md` (`:113`), `plugins/tce/commands/quickfix.md`
(`:279`)
**Changes**: The drift check enumerates adapter mechanisms as
"access/create/status"; extend to include enumeration. Per the
composite-tracking rule, all three move in the same commit.

### Success Criteria:

#### Automated Verification:

- [x] `plugins/tce/commands/init.md` mentions `Listing tickets` in the Phase 4
      step-2 enumeration and in all three per-system guidance bullets
- [x] `init.md`'s Idempotency list contains a `tickets.md` bullet naming
      tce 1.2.0 and the insertion anchor `## Status / completion`
- [x] `plugins/tce/commands/refresh.md` lists `Listing` in both the scope
      paragraph and the Phase 2 factual list, and not in the hand-authored list
- [x] The drift-check phrasing in `research.md`, `work.md` and `quickfix.md` all
      mention enumeration (`access/create/status/listing`, one site each)
- [x] `claude plugin validate ./plugins/tce` passes

#### Manual Verification:

- [ ] Running `/tce:init` in a scratch project with an existing eight-section
      `tickets.md` offers the upgrade and writes the section correctly
- [ ] Running `/tce:refresh` in a project whose enumeration mechanism is stale
      proposes a correction rather than rewriting policy

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-3>` feat(TP-0033): teach init and refresh the listing adapter section
- **Did**: init.md gained `Listing` in the Phase 4 step-2 enumeration, a
  `*listing*` clause plus terminal statuses in all three per-system bullets, and
  the first `tickets.md` Idempotency upgrade bullet; refresh.md gained `Listing`
  in the scope paragraph, Phase 1 item 4, the Phase 2 factual list and the
  high-confidence drift triggers; the drift-check prose in research.md, work.md
  and quickfix.md moved together per the composite-tracking rule.
- **Issues**: none.
- **Verification**: ✅ `claude plugin validate ./plugins/tce`, ✅ grep-confirmed
  the phrasing in all four drift sites and both lifecycle commands

---

## Phase 4: The `/tce:list` command

### Overview

The command itself: read the adapter, enumerate, group epics, call `stage.sh`,
render the table.

### Changes Required:

#### 1. The command

**File**: `plugins/tce/commands/list.md` (new)
**Changes**: Frontmatter, project context, argument interpretation, the five
steps, and the output contract.

Frontmatter, in the established field order and **without**
`disable-model-invocation` (deliberate — see Phase 5):

```yaml
---
description: List tickets as a table with their tce workflow stage — research document, plan document, and implementation progress.
argument-hint: "[optional filter, e.g. only auth tickets | include closed | group by priority]"
allowed-tools: Bash("${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh":*)
---
```

Project context in the stop-if-missing register of `ticket.md:20-30`: read
`${CLAUDE_PROJECT_DIR}/.claude/tce/tickets.md` for the canonical ID form, the
`## Listing tickets` enumeration mechanism, the terminal statuses in
`## Status / completion`, and the `## Parent / epic tickets` rule; **if the file
is missing, tell the user to run `/tce:init` and stop**. If the file exists but
has no `## Listing tickets` section, say so and suggest `/tce:init` to add it.

Steps:

1. **Interpret the argument.** With no argument, list every ticket not in a
   terminal status, newest first. With free-form text, interpret it naturally —
   at minimum topic filter, include-terminal-statuses, group-by and sort-by — and
   **state the interpretation in one line before the table** (e.g. "Interpreted
   as: only tickets mentioning tle, including closed ones, grouped by status.").
   No fixed vocabulary; if the prompt is genuinely ambiguous, pick the most
   likely reading and say so in that same line.
2. **Enumerate** using the adapter's `## Listing tickets` mechanism, collecting
   ID, title, status, complexity and — only if the adapter declares a location —
   priority.
3. **Group epics** using `## Parent / epic tickets`. A sub-ticket is rendered
   directly beneath its parent and stays grouped with it **even when the parent
   is in a terminal status** (the parent row is then shown for context regardless
   of the terminal-status filter).
4. **Derive stages** with one bulk call:
   `"${CLAUDE_PLUGIN_ROOT}/scripts/stage.sh" <id> <id> …` — one invocation for
   every listed ticket, never one call per ticket.
5. **Render** the table, legend and count line.

Cell rules:

- Research / Plan: `✓` when the script reported a path, `–` otherwise.
- Implementation, from the script's `source:`/`progress:`:
  - `no-plan` → `–`
  - `log`, all phases done → `✓`
  - `log`, partial → `n/m phases`
  - `sidecar` → `~n/m phases` (the `~` marks it approximate)
  - `unknown` → `?/m phases`
- Epic Implementation cell: `n/m sub-tickets`, where `n` counts sub-tickets whose
  own Implementation cell is `✓`. The epic's Research and Plan cells reflect only
  documents the **epic itself** has. The epic's own plan phases are deliberately
  not shown.
- Priority column present **only** when the adapter declares a location.

Output-format rules, stated explicitly in the command because they are the
concrete defect being avoided:

- Emit a **real markdown table**, never inside a code fence — the renderer does
  the column padding, so do not hand-pad cells.
- Full-word headings: `Ticket`, `Title`, `Priority`, `Status`, `Research`,
  `Plan`, `Implementation`, `Complexity`.
- **Only single-width, text-presentation characters in cells**: `✓` (U+2713),
  `–` (U+2013), `└─` (U+2514 U+2500), `~`, `?`, digits and letters. Never `✅`,
  `❌` or any other emoji-presentation glyph — they occupy two terminal columns
  and break alignment.
- Nesting uses the leading `└─` marker, never leading whitespace (renderers trim
  leading spaces in table cells).
- A legend below the table explaining `✓`, `–`, `n/m phases`, `~` (approximate,
  from a legacy status file), `?` (unknown) and `└─`.
- A count line, e.g. `Showing 12 of 33 tickets (21 in a terminal status hidden).`

Error handling: if `stage.sh` exits non-zero (no `thoughts/` directory), report
its stderr and still print the table with every stage cell as `?` rather than
failing outright.

### Success Criteria:

#### Automated Verification:

- [x] `plugins/tce/commands/list.md` exists with the three frontmatter fields
      and **no** `disable-model-invocation` key
- [x] `claude plugin validate ./plugins/tce` passes
- [x] The command text contains no ticket prefix, no `thoughts/shared/tickets/`
      literal, and no other tmt specific (only `[PREFIX]-XXXX` placeholders)
- [x] The command text contains no `✅`, `❌` or other emoji-presentation glyph
      in any table-cell specification (the sole occurrence is the sentence
      prohibiting them)

#### Manual Verification:

- [ ] `/tce:list` in this repo lists all non-terminal tickets, newest first, with
      correct research/plan/implementation cells cross-checked against
      `thoughts/` (the pipeline was verified by running the adapter's
      enumeration and `stage.sh` by hand; invoking the slash command itself is
      the user's step)
- [ ] **The table renders as a padded, aligned table in the terminal.** Research
      later confirmed the renderer does lay tables out (Anthropic's accessibility
      docs describe screen-reader mode as replacing "a box-character grid"), so
      this is now a spot-check rather than an open assumption
- [ ] No cell is misaligned by a double-width character
- [ ] The table does **not** collapse into stacked key/value cards at the user's
      terminal width (8 columns is near the reported ~6-column threshold; titles
      are truncated to 45 characters to mitigate it)
- [ ] `/tce:list only tle tickets` filters and echoes its interpretation in one
      line
- [ ] `/tce:list include closed` shows terminal-status tickets
- [ ] `/tce:list group by status` groups as asked
- [ ] With `.claude/tce/tickets.md` temporarily renamed, the command tells the
      user to run `/tce:init` and stops

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-4>` feat(TP-0033): add the /tce:list command
- **Did**: added `plugins/tce/commands/list.md` — frontmatter without
  `disable-model-invocation`, stop-if-`tickets.md`-missing context, the five
  steps (interpret / enumerate / group epics / one bulk `stage.sh` call /
  render), the cell rules including the `~` approximate marker and the epic
  roll-up, and the output-format rules.
- **Issues**: the late web research changed two things. It **confirmed** the
  renderer pads real markdown tables (so the ticket's format decision is sound),
  but reported that a table wider than the terminal collapses into stacked
  key/value cards at roughly 6+ columns — and this table has 8. Raised with the
  user, who chose to keep the locked columns and truncate titles; a 45-character
  title cap and a "why the table must stay narrow" rule are in the command. The
  same research corrected the glyph analysis: `✓` is Neutral (safe everywhere)
  while `–` and `└` are Ambiguous; the user chose to keep them as locked.
- **Verification**: ✅ `claude plugin validate ./plugins/tce`, ✅ no tmt
  specifics, ✅ no emoji glyphs in cell specs, ✅ pipeline exercised by hand
  (adapter enumeration + `stage.sh` over all 33 tickets)
- **Gate fix**: the plan-compliance gate caught a real defect — the title
  truncation rule introduced `…` (U+2026) as a mandatory cell glyph, which is
  ambiguous-width and outside the set the ticket locks. Replaced with three ASCII
  periods and tightened the rule to state the non-ASCII glyph set is exactly
  three characters, with `…`/`→`/`•` named as further things not to reach for.
  Re-ran the gate on the criterion: met.

---

## Phase 5: Docs, classification, dogfooded config, release

### Overview

Record the invocation classification and the new cross-file span in `CLAUDE.md`,
document the command, fill this repo's own adapter, and release tce 1.2.0.

### Changes Required:

#### 1. `CLAUDE.md`

**File**: `CLAUDE.md`
**Changes**:

- **Layout tree**: add `stage.sh` to the tce `scripts/*.sh` line.
- **TP-0017 classification**: `/tce:list` is top-level with no inbound
  delegation, which the rule's letter would flag — but it is read-only and is the
  archetypal thing a user asks for in prose. Add a third, explicit bullet rather
  than silently omitting it:

  ```markdown
  - **Read-only, prose-requested — deliberately unflagged**: `list`. No inbound
    delegation edge, so the rule's letter would flag it; it stays unflagged
    because it is read-only and is exactly what a user asks for in prose ("show
    me the open tickets"), which a flagged skill cannot serve. tmt's `/tmt:list`
    is unflagged for the same reason. Never "tidy" the flag onto it.
  ```

- **A new governance section** for the span this feature creates, in the style of
  the TP-0020 / TP-0031 rules:

  ```markdown
  ## `/tce:list` spans a script, the adapter, and the adapter's lifecycle (TP-0033)

  `/tce:list` splits enumeration from derivation. **Enumeration is
  backend-specific** and comes from `.claude/tce/tickets.md`'s
  `## Listing tickets` section plus the terminal statuses in
  `## Status / completion`; **derivation is backend-independent** and lives in
  `plugins/tce/scripts/stage.sh`, which never reads tce config and receives
  ticket IDs as arguments (the `branch.sh` division of labour).

  `stage.sh`'s five-line record and its `source: log | sidecar | unknown |
  no-plan` enum are a machine contract that `list.md` parses. Two derivation
  rules are load-bearing and were established against this repo's own corpus:
  **fenced code blocks must be stripped before matching headings** (plans here
  quote tce's own markdown, producing real false positives), and **completion is
  never derived from success-criteria checkboxes** (completed plans routinely
  leave Manual items unticked). The `sidecar` source is approximate by nature and
  the command must mark it as such (`~n/m`) — never present it as exact.

  **RULE: When you change `stage.sh`'s record format, its `source:` vocabulary or
  its derivation rules, update `list.md` in the same commit; when you change the
  `## Listing tickets` section's shape or sub-fields, update the template,
  `init.md`'s Phase 4 fill + Idempotency bullet, `refresh.md`'s factual list and
  `plugins/tce/README.md` together** (the refresh-tracks-init rule applied to the
  adapter). `/tce:list` is not part of the ticket→research→plan→implement chain,
  so the composite-tracking rule does not reach it.
  ```

#### 2. README

**File**: `plugins/tce/README.md`
**Changes**: Add a row to the **Helpers** table (`:217-224`):

```markdown
| `/tce:list`           | List tickets with their tce stage (research / plan / implementation) |
```

Extend the adapter bullet (`:260-265`) to mention that the adapter also says how
to enumerate tickets and where priority lives.

#### 3. This repo's own adapter (dogfooding)

**Files**: `.claude/tce/tickets.md`, `.claude/tce/profile.md`
**Changes**: Add the filled `## Listing tickets` section (tmt: glob
`thoughts/shared/tickets/TP-*.md`; title from the `# TP-NNNN: <title>` heading;
status from `**Status:**`; complexity from `**Estimated Complexity:**`; priority
"none") and add the terminal statuses (Done, Rejected) to
`## Status / completion`. Bump the `tce-config-version` marker on line 1 of
`profile.md` to `1.2.0`.

#### 4. Release

**Files**: `plugins/tce/.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`
**Changes**: Bump the tce `version` to `1.2.0` in both.

### Success Criteria:

#### Automated Verification:

- [x] `claude plugin validate .` passes
- [x] `claude plugin validate ./plugins/tce` passes
- [x] `claude plugin validate ./plugins/tmt` passes
- [x] `claude plugin validate ./plugins/tle` passes
- [x] `plugins/tce/.claude-plugin/plugin.json` and the tce entry in
      `.claude-plugin/marketplace.json` both read `1.2.0`
- [x] `.claude/tce/profile.md` line 1 reads `<!-- tce-config-version: 1.2.0 -->`
- [x] `.claude/tce/tickets.md` contains a filled `## Listing tickets` section and
      terminal statuses in `## Status / completion`
- [x] `CLAUDE.md` contains the `list` classification bullet and the new
      governance section
- [x] `plugins/tce/README.md` Helpers table contains a `/tce:list` row
- [x] The AskUserQuestion guidelines block is still at exactly ten copies (the
      new command has no dialog site)

#### Manual Verification:

- [ ] `/tce:list` runs end to end in this repo against the dogfooded config
- [ ] The git tag step (`claude plugin tag ./plugins/tce`) is left to the user —
      the repo convention is never to push automatically

### Implementation log

- **Status**: ✅ Complete
- **Commit**: `<phase-5>` feat(TP-0033): document /tce:list and release tce 1.2.0
- **Did**: `CLAUDE.md` gained `stage.sh` in the layout tree, the deliberately
  unflagged `list` classification bullet, and a TP-0033 governance section
  recording the enumeration/derivation seam, the three load-bearing derivation
  rules and the renderer's collapse behaviour; README gained the Helpers row and
  an extended adapter bullet; this repo's own `tickets.md` gained the filled
  Listing section and terminal statuses with the marker bumped to 1.2.0; tce
  released as 1.2.0 in both manifests.
- **Issues**: none.
- **Verification**: ✅ all four `claude plugin validate` runs, ✅ versions
  consistent, ✅ ten AskUserQuestion copies, ✅ end-to-end pipeline over the
  repo's 33 tickets

---

## Testing Strategy

### Unit Tests:

There is no test runner in this repo (`profile.md`: Typecheck none, Lint none).
Verification is `bash -n`, `claude plugin validate`, and **assertions against the
repo's own corpus**, which is unusually good test data: 33 tickets, 28 plans
spanning all three progress eras, 20 legacy sidecars, and confirmed in-fence
false positives.

Key edge cases, each mapped to a Phase 1 criterion: in-fence headings (TP-0030,
TP-0021), `###`-level phases (TP-0005, TP-0014), partial progress (TP-0024),
sidecar with per-phase status (TP-0022), sidecar with heading-suffix `DONE`
(TP-0012), no signal at all (TP-0006), no plan (TP-0033), no documents at all
(TP-0032), and epic over-match (synthetic `X-0100` / `X-0100a` fixture).

### Integration Tests:

Run `/tce:list` in this repo after Phase 5 and cross-check every row against
`thoughts/`. Then exercise the prompt argument: a topic filter, include-closed,
and a group-by.

### Manual Testing Steps:

1. Run `/tce:list` with no argument; confirm the table renders padded and aligned
   in the terminal, with no misalignment from a double-width character.
2. Run `/tce:list only tle tickets`; confirm the one-line interpretation echo
   appears above the table and the filter is right.
3. Run `/tce:list include closed`; confirm terminal-status tickets appear and the
   count line reflects it.
4. Temporarily rename `.claude/tce/tickets.md`; confirm the command tells you to
   run `/tce:init` and stops.

## Performance Considerations

`stage.sh` opens at most two files per ticket and is called **once** for the whole
listing, so a backlog of a few hundred tickets is a few hundred file reads — well
within a single Bash call. The ticket explicitly rules out caching or indexing.
The enumeration step's cost belongs to the backend (a glob for tmt, one CLI call
for an issue tracker); the command must not issue one call per ticket.

## Migration Notes

Existing consuming projects have an eight-section `tickets.md` and will not have
`## Listing tickets`. They are handled by the new `/tce:init` Idempotency bullet
(Phase 3), which offers the section as an upgrade and fills it from the already
recorded backend rather than re-asking. Until upgraded, `/tce:list` detects the
missing section and points at `/tce:init` rather than guessing an enumeration
mechanism. `tickets.md` carries no version marker of its own — the upgrade is
reflected through `profile.md`'s `tce-config-version`.

## References

- Original ticket: `thoughts/shared/tickets/TP-0033-tce-list-workflow-stage.md`
- Related research:
  `thoughts/shared/research/2026-09-09-TP-0033-tce-list-workflow-stage.md`
- Shipped-script pattern: `plugins/tce/scripts/baseline.sh`,
  `plugins/tce/scripts/branch.sh:4-5`
- Adapter register: `plugins/tce/templates/tce/tickets.md:26-62`
- Progress format: `plugins/tce/commands/implement.md:110-120`, `:142`, `:144`
- Prior art: `plugins/tmt/commands/list.md`, `plugins/tmt/scripts/open_tickets.sh`
